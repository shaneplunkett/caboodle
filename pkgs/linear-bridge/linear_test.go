package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

const testSecret = "client-secret-value"

type apiStub struct {
	mu        sync.Mutex
	tokens    int
	authSeen  []string
	queries   []string
	variables []map[string]any
	tokenForm map[string]string
	token     http.HandlerFunc
	graphql   http.HandlerFunc
}

func newAPIStub(t *testing.T, graphql http.HandlerFunc) (*apiStub, *linear) {
	t.Helper()
	stub := &apiStub{graphql: graphql}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /oauth/token", func(w http.ResponseWriter, r *http.Request) {
		stub.mu.Lock()
		stub.tokens++
		count := stub.tokens
		if err := r.ParseForm(); err != nil {
			t.Error(err)
		}
		stub.tokenForm = map[string]string{}
		for key := range r.PostForm {
			stub.tokenForm[key] = r.PostForm.Get(key)
		}
		stub.mu.Unlock()
		if stub.token != nil {
			stub.token(w, r)
			return
		}
		fmt.Fprintf(w, `{"access_token":"token-%d","token_type":"Bearer","expires_in":2591999}`, count)
	})
	mux.HandleFunc("POST /graphql", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Query     string         `json:"query"`
			Variables map[string]any `json:"variables"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Error(err)
		}
		stub.mu.Lock()
		stub.authSeen = append(stub.authSeen, r.Header.Get("Authorization"))
		stub.queries = append(stub.queries, body.Query)
		stub.variables = append(stub.variables, body.Variables)
		stub.mu.Unlock()
		stub.graphql(w, r)
	})
	server := httptest.NewServer(mux)
	t.Cleanup(server.Close)
	return stub, newLinear(server.URL+"/graphql", server.URL+"/oauth/token", "client-id-value", testSecret)
}

func respond(body string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, body) }
}

const emptyFind = `{"data":{"attachmentsForURL":{"nodes":[]}}}`

func TestTokenIsFetchedOnFirstNeedWithTheAgreedScopes(t *testing.T) {
	stub, client := newAPIStub(t, respond(emptyFind))
	if stub.tokens != 0 {
		t.Fatal("nothing should fetch a token before it is needed")
	}
	for range 2 {
		if _, err := client.find(context.Background(), "https://alert"); err != nil {
			t.Fatal(err)
		}
	}
	if stub.tokens != 1 {
		t.Errorf("fetched %d tokens, want the one reused", stub.tokens)
	}
	if got := stub.authSeen[1]; got != "Bearer token-1" {
		t.Errorf("Authorization = %q", got)
	}
	want := map[string]string{
		"grant_type":    "client_credentials",
		"client_id":     "client-id-value",
		"client_secret": testSecret,
		"scope":         "read,issues:create,comments:create",
	}
	for key, value := range want {
		if stub.tokenForm[key] != value {
			t.Errorf("form %s = %q, want %q", key, stub.tokenForm[key], value)
		}
	}
}

func TestTokenIsRefetchedWithinADayOfExpiring(t *testing.T) {
	stub, client := newAPIStub(t, respond(emptyFind))
	stub.token = func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintf(w, `{"access_token":"token-%d","expires_in":172800}`, stub.tokens)
	}
	clock := time.Date(2026, 11, 3, 0, 0, 0, 0, time.UTC)
	client.now = func() time.Time { return clock }
	use := func() {
		t.Helper()
		if _, err := client.find(context.Background(), "https://alert"); err != nil {
			t.Fatal(err)
		}
	}

	use()
	clock = clock.Add(24*time.Hour - time.Second)
	use()
	if stub.tokens != 1 {
		t.Fatalf("fetched %d tokens with more than a day left", stub.tokens)
	}
	clock = clock.Add(time.Second)
	use()
	if stub.tokens != 2 {
		t.Fatalf("fetched %d tokens with a day left", stub.tokens)
	}
	if got := stub.authSeen[2]; got != "Bearer token-2" {
		t.Errorf("Authorization = %q", got)
	}
	clock = clock.Add(24*time.Hour - time.Second)
	use()
	if stub.tokens != 2 {
		t.Errorf("fetched %d tokens, the new token's expiry should count from when it was fetched", stub.tokens)
	}
}

func TestATokenWithNoStatedExpiryWaitsForThe401(t *testing.T) {
	stub, client := newAPIStub(t, respond(emptyFind))
	stub.token = func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, `{"access_token":"token"}`) }
	clock := time.Date(2026, 11, 3, 0, 0, 0, 0, time.UTC)
	client.now = func() time.Time { return clock }
	for range 2 {
		if _, err := client.find(context.Background(), "https://alert"); err != nil {
			t.Fatal(err)
		}
		clock = clock.Add(365 * 24 * time.Hour)
	}
	if stub.tokens != 1 {
		t.Errorf("fetched %d tokens", stub.tokens)
	}
}

func TestStaleTokenIsRefetchedAndTheCallRetriedOnce(t *testing.T) {
	authErrorBody := `{"errors":[{"message":"Authentication required","extensions":{"code":"AUTHENTICATION_ERROR"}}]}`
	for name, reject := range map[string]func(w http.ResponseWriter){
		"http 401": func(w http.ResponseWriter) {
			w.WriteHeader(http.StatusUnauthorized)
			fmt.Fprint(w, authErrorBody)
		},
		"http 200 with AUTHENTICATION_ERROR": func(w http.ResponseWriter) { fmt.Fprint(w, authErrorBody) },
	} {
		t.Run(name, func(t *testing.T) {
			calls := 0
			stub, client := newAPIStub(t, func(w http.ResponseWriter, _ *http.Request) {
				calls++
				if calls == 1 {
					reject(w)
					return
				}
				fmt.Fprint(w, emptyFind)
			})
			if _, err := client.find(context.Background(), "https://alert"); err != nil {
				t.Fatal(err)
			}
			if stub.tokens != 2 || calls != 2 {
				t.Errorf("tokens = %d, calls = %d", stub.tokens, calls)
			}
			if got := stub.authSeen[1]; got != "Bearer token-2" {
				t.Errorf("retry used %q", got)
			}
		})
	}
}

func TestAuthFailureAfterTheRetryIsARefusal(t *testing.T) {
	calls := 0
	stub, client := newAPIStub(t, func(w http.ResponseWriter, _ *http.Request) {
		calls++
		w.WriteHeader(http.StatusUnauthorized)
	})
	_, err := client.find(context.Background(), "https://alert")
	var refused *refusal
	if !errors.As(err, &refused) {
		t.Fatalf("err = %v", err)
	}
	if calls != 2 || stub.tokens != 2 {
		t.Errorf("calls = %d, tokens = %d, want one retry", calls, stub.tokens)
	}
}

func TestGraphQLErrorsAreRefusalsEvenOnHTTP200(t *testing.T) {
	calls := 0
	_, client := newAPIStub(t, func(w http.ResponseWriter, _ *http.Request) {
		calls++
		fmt.Fprint(w, `{"errors":[{"message":"usage limit","extensions":{"code":"USAGE_LIMIT_EXCEEDED"}}]}`)
	})
	_, err := client.createIssue(context.Background(), newIssue{Title: "t"})
	var refused *refusal
	if !errors.As(err, &refused) {
		t.Fatalf("err = %v", err)
	}
	if refused.Code != "USAGE_LIMIT_EXCEEDED" {
		t.Errorf("code = %q", refused.Code)
	}
	if calls != 1 {
		t.Errorf("calls = %d, a refusal is never retried here", calls)
	}
}

func isRetryable(err error) bool {
	var retry *retryableError
	return errors.As(err, &retry)
}

func TestServerErrorsAndNetworkFailuresAreRetryable(t *testing.T) {
	_, client := newAPIStub(t, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
		fmt.Fprint(w, `<html>bad gateway</html>`)
	})
	if _, err := client.find(context.Background(), "https://alert"); !isRetryable(err) {
		t.Errorf("502: err = %v", err)
	}

	gone := newLinear("http://127.0.0.1:1/graphql", "http://127.0.0.1:1/oauth/token", "id", testSecret)
	if _, err := gone.find(context.Background(), "https://alert"); !isRetryable(err) {
		t.Errorf("network: err = %v", err)
	}
}

func TestAnAnswerItCantReadIsNotRetryable(t *testing.T) {
	for name, body := range map[string]string{
		"not json":           `<html>not graphql</html>`,
		"wrong shape":        `{"data":{"attachmentsForURL":"nope"}}`,
		"null data":          `{"data":null}`,
		"missing field":      `{"data":{}}`,
		"node with no issue": `{"data":{"attachmentsForURL":{"nodes":[{"issue":null}]}}}`,
	} {
		t.Run(name, func(t *testing.T) {
			_, client := newAPIStub(t, respond(body))
			_, err := client.find(context.Background(), "https://alert")
			if err == nil {
				t.Fatal("wanted an error, an empty lookup would file a twin")
			}
			if isRetryable(err) {
				t.Errorf("err = %v", err)
			}
		})
	}
}

func TestTokenEndpointFailuresSplitTheSameWayWithoutLeakingTheSecret(t *testing.T) {
	notRetryable := map[string]http.HandlerFunc{
		"http 400": func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusBadRequest)
			fmt.Fprintf(w, `{"error":"invalid_client","echo":%q}`, testSecret)
		},
		"http 200 not json": func(w http.ResponseWriter, _ *http.Request) {
			fmt.Fprintf(w, `not json %s`, testSecret)
		},
		"http 200 no access token": func(w http.ResponseWriter, _ *http.Request) {
			fmt.Fprintf(w, `{"echo":%q}`, testSecret)
		},
	}
	for name, handler := range notRetryable {
		t.Run(name, func(t *testing.T) {
			stub, client := newAPIStub(t, respond(emptyFind))
			stub.token = handler
			_, err := client.find(context.Background(), "https://alert")
			if err == nil || isRetryable(err) {
				t.Errorf("err = %v", err)
			}
			if err != nil && strings.Contains(err.Error(), testSecret) {
				t.Error("the error carries the client secret")
			}
		})
	}

	stub, client := newAPIStub(t, respond(emptyFind))
	stub.token = func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusServiceUnavailable) }
	if _, err := client.find(context.Background(), "https://alert"); !isRetryable(err) {
		t.Errorf("503: err = %v", err)
	}
}

func TestFindReadsEveryIssueAttachedToTheURL(t *testing.T) {
	stub, client := newAPIStub(t, respond(`{"data":{"attachmentsForURL":{"nodes":[
		{"issue":{"id":"a","identifier":"SHA-1","number":1,"completedAt":"2026-11-03T10:00:00Z","canceledAt":null,"state":{"type":"completed"}}},
		{"issue":{"id":"b","identifier":"SHA-2","number":2,"completedAt":null,"canceledAt":null,"state":{"type":"triage"}}}
	]}}}`))
	issues, err := client.find(context.Background(), "https://alert")
	if err != nil {
		t.Fatal(err)
	}
	if len(issues) != 2 {
		t.Fatalf("got %d issues", len(issues))
	}
	if got := issues[0]; got.Identifier != "SHA-1" || got.Number != 1 || got.StateType != "completed" || got.CompletedAt == nil {
		t.Errorf("first = %+v", got)
	}
	if got := issues[1]; got.ID != "b" || got.StateType != "triage" || got.closedAt() != nil {
		t.Errorf("second = %+v", got)
	}
	if got := stub.variables[0]["url"]; got != "https://alert" {
		t.Errorf("url = %v", got)
	}
}

func findNode(identifier string, number int) string {
	return fmt.Sprintf(`{"issue":{"id":%q,"identifier":%q,"number":%d,"state":{"type":"triage"}}}`, identifier, identifier, number)
}

func TestFindWalksEveryPage(t *testing.T) {
	stub, client := newAPIStub(t, nil)
	stub.graphql = func(w http.ResponseWriter, _ *http.Request) {
		switch len(stub.variables) {
		case 1:
			fmt.Fprintf(w, `{"data":{"attachmentsForURL":{"nodes":[%s],"pageInfo":{"hasNextPage":true,"endCursor":"page-2"}}}}`, findNode("SHA-1", 1))
		case 2:
			fmt.Fprintf(w, `{"data":{"attachmentsForURL":{"nodes":[%s],"pageInfo":{"hasNextPage":true,"endCursor":"page-3"}}}}`, findNode("SHA-2", 2))
		default:
			fmt.Fprintf(w, `{"data":{"attachmentsForURL":{"nodes":[%s],"pageInfo":{"hasNextPage":false,"endCursor":"page-3"}}}}`, findNode("SHA-3", 3))
		}
	}
	issues, err := client.find(context.Background(), "https://alert")
	if err != nil {
		t.Fatal(err)
	}
	got := []string{}
	for _, found := range issues {
		got = append(got, found.Identifier)
	}
	if strings.Join(got, ",") != "SHA-1,SHA-2,SHA-3" {
		t.Errorf("issues = %v", got)
	}
	if len(stub.variables) != 3 {
		t.Fatalf("made %d calls", len(stub.variables))
	}
	for call, want := range []any{nil, "page-2", "page-3"} {
		if stub.variables[call]["after"] != want {
			t.Errorf("call %d after = %v, want %v", call, stub.variables[call]["after"], want)
		}
		if stub.variables[call]["url"] != "https://alert" {
			t.Errorf("call %d url = %v", call, stub.variables[call]["url"])
		}
	}
}

func TestFindStopsOnACursorThatDoesntMove(t *testing.T) {
	for name, cursor := range map[string]string{"no cursor": `null`, "same cursor": `"page-2"`} {
		t.Run(name, func(t *testing.T) {
			calls := 0
			_, client := newAPIStub(t, func(w http.ResponseWriter, _ *http.Request) {
				calls++
				more := calls <= 3
				if !more {
					t.Error("still walking pages")
				}
				fmt.Fprintf(w, `{"data":{"attachmentsForURL":{"nodes":[],"pageInfo":{"hasNextPage":%t,"endCursor":%s}}}}`, more, cursor)
			})
			_, err := client.find(context.Background(), "https://alert")
			if err == nil || isRetryable(err) {
				t.Errorf("err = %v", err)
			}
		})
	}
}

func TestCreateIssueSendsTheChosenID(t *testing.T) {
	stub, client := newAPIStub(t, respond(`{"data":{"issueCreate":{"success":true,"issue":{"id":"chosen","identifier":"SHA-7"}}}}`))
	created, err := client.createIssue(context.Background(), newIssue{
		ID:          "chosen",
		TeamID:      "team",
		Title:       "title",
		Description: "body",
		StateID:     "triage",
		AssigneeID:  "shane",
		LabelIDs:    []string{"bug"},
		Priority:    3,
	})
	if err != nil {
		t.Fatal(err)
	}
	if created.Identifier != "SHA-7" {
		t.Errorf("created = %+v", created)
	}
	want := `{"assigneeId":"shane","description":"body","id":"chosen","labelIds":["bug"],"priority":3,"stateId":"triage","teamId":"team","title":"title"}`
	got, _ := json.Marshal(stub.variables[0]["input"])
	if string(got) != want {
		t.Errorf("\n got %s\nwant %s", got, want)
	}
}

const alreadyExists = `{"errors":[{"message":"Entity Issue with id chosen already exists.","extensions":{"code":"INPUT_ERROR"}}]}`

func TestCreatingAnIDThatExistsIsNotARefusal(t *testing.T) {
	_, client := newAPIStub(t, respond(alreadyExists))
	_, err := client.createIssue(context.Background(), newIssue{ID: "chosen"})
	if !errors.Is(err, errAlreadyExists) {
		t.Errorf("err = %v", err)
	}
}

func TestAttachSaysWhichIssueItLandedOn(t *testing.T) {
	stub, client := newAPIStub(t, respond(`{"data":{"attachmentCreate":{"success":true,"attachment":{"issue":{"id":"chosen","identifier":"SHA-7"}}}}}`))
	attached, err := client.attach(context.Background(), "chosen", "https://alert", "A on b")
	if err != nil {
		t.Fatal(err)
	}
	if attached.Identifier != "SHA-7" {
		t.Errorf("attached = %+v", attached)
	}
	want := `{"issueId":"chosen","title":"A on b","url":"https://alert"}`
	got, _ := json.Marshal(stub.variables[0]["input"])
	if string(got) != want {
		t.Errorf("\n got %s\nwant %s", got, want)
	}
}

func TestCommentSendsTheChosenID(t *testing.T) {
	stub, client := newAPIStub(t, respond(`{"data":{"commentCreate":{"success":true}}}`))
	if err := client.comment(context.Background(), "comment-id", "issue-id", "words"); err != nil {
		t.Fatal(err)
	}
	want := `{"body":"words","id":"comment-id","issueId":"issue-id"}`
	got, _ := json.Marshal(stub.variables[0]["input"])
	if string(got) != want {
		t.Errorf("\n got %s\nwant %s", got, want)
	}
}

func TestSuccessFalseIsARefusal(t *testing.T) {
	_, client := newAPIStub(t, respond(`{"data":{"commentCreate":{"success":false}}}`))
	var refused *refusal
	if err := client.comment(context.Background(), "c", "i", "w"); !errors.As(err, &refused) {
		t.Errorf("err = %v", err)
	}
}
