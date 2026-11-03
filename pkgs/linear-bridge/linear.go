package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	linearScopes     = "read,issues:create,comments:create"
	linearGraphQLURL = "https://api.linear.app/graphql"
	linearTokenURL   = "https://api.linear.app/oauth/token"
	authErrorCode    = "AUTHENTICATION_ERROR"
	tokenExpiryLead  = 24 * time.Hour
)

var errAlreadyExists = errors.New("an entity with this id already exists")

type refusal struct {
	Code    string
	Message string
}

func (r *refusal) Error() string { return "linear refused: " + r.Code + ": " + r.Message }

type retryableError struct {
	err error
}

func (r *retryableError) Error() string { return r.err.Error() }

func (r *retryableError) Unwrap() error { return r.err }

func retryable(format string, args ...any) error {
	return &retryableError{err: fmt.Errorf(format, args...)}
}

type newIssue struct {
	ID          string   `json:"id"`
	TeamID      string   `json:"teamId"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	StateID     string   `json:"stateId"`
	AssigneeID  string   `json:"assigneeId"`
	LabelIDs    []string `json:"labelIds"`
	Priority    int      `json:"priority"`
}

type linear struct {
	graphqlURL   string
	tokenURL     string
	clientID     string
	clientSecret string
	http         *http.Client
	now          func() time.Time

	mu           sync.Mutex
	token        string
	tokenExpires time.Time
}

func newLinear(graphqlURL, tokenURL, clientID, clientSecret string) *linear {
	return &linear{
		graphqlURL:   graphqlURL,
		tokenURL:     tokenURL,
		clientID:     clientID,
		clientSecret: clientSecret,
		http:         &http.Client{Timeout: 30 * time.Second},
		now:          time.Now,
	}
}

type issueNode struct {
	issue
	State struct {
		Type string `json:"type"`
	} `json:"state"`
}

func (n issueNode) toIssue() issue {
	found := n.issue
	found.StateType = n.State.Type
	return found
}

func (l *linear) find(ctx context.Context, attachmentURL string) ([]issue, error) {
	issues := []issue{}
	var after *string
	for {
		page, next, err := l.findPage(ctx, attachmentURL, after)
		if err != nil {
			return nil, err
		}
		issues = append(issues, page...)
		if next == nil {
			return issues, nil
		}
		if after != nil && *next == *after {
			return nil, errors.New("linear's answer repeats its page cursor")
		}
		after = next
	}
}

func (l *linear) findPage(ctx context.Context, attachmentURL string, after *string) (page []issue, next *string, err error) {
	const query = `query Find($url: String!, $after: String) {
  attachmentsForURL(url: $url, includeArchived: true, first: 250, after: $after) {
    nodes { issue { id identifier number completedAt canceledAt state { type } } }
    pageInfo { hasNextPage endCursor }
  }
}`
	var out struct {
		AttachmentsForURL *struct {
			Nodes []struct {
				Issue issueNode `json:"issue"`
			} `json:"nodes"`
			PageInfo struct {
				HasNextPage bool    `json:"hasNextPage"`
				EndCursor   *string `json:"endCursor"`
			} `json:"pageInfo"`
		} `json:"attachmentsForURL"`
	}
	if err := l.do(ctx, query, map[string]any{"url": attachmentURL, "after": after}, &out); err != nil {
		return nil, nil, err
	}
	if out.AttachmentsForURL == nil {
		return nil, nil, errors.New("linear's answer has no attachmentsForURL")
	}
	for _, node := range out.AttachmentsForURL.Nodes {
		if node.Issue.ID == "" {
			return nil, nil, errors.New("linear's answer has an attachment with no issue")
		}
		page = append(page, node.Issue.toIssue())
	}
	if !out.AttachmentsForURL.PageInfo.HasNextPage {
		return page, nil, nil
	}
	cursor := out.AttachmentsForURL.PageInfo.EndCursor
	if cursor == nil || *cursor == "" {
		return nil, nil, errors.New("linear's answer says there is another page but gives no cursor")
	}
	return page, cursor, nil
}

func (l *linear) createIssue(ctx context.Context, input newIssue) (issue, error) {
	const query = `mutation Fire($input: IssueCreateInput!) {
  issueCreate(input: $input) { success issue { id identifier } }
}`
	var out struct {
		IssueCreate struct {
			Success bool  `json:"success"`
			Issue   issue `json:"issue"`
		} `json:"issueCreate"`
	}
	if err := l.do(ctx, query, map[string]any{"input": input}, &out); err != nil {
		return issue{}, err
	}
	if !out.IssueCreate.Success {
		return issue{}, &refusal{Code: "NOT_SUCCESSFUL", Message: "issueCreate answered success false"}
	}
	return out.IssueCreate.Issue, nil
}

func (l *linear) attach(ctx context.Context, issueID, attachmentURL, title string) (issue, error) {
	const query = `mutation Attach($input: AttachmentCreateInput!) {
  attachmentCreate(input: $input) { success attachment { issue { id identifier } } }
}`
	var out struct {
		AttachmentCreate struct {
			Success    bool `json:"success"`
			Attachment struct {
				Issue issue `json:"issue"`
			} `json:"attachment"`
		} `json:"attachmentCreate"`
	}
	input := map[string]any{"issueId": issueID, "url": attachmentURL, "title": title}
	if err := l.do(ctx, query, map[string]any{"input": input}, &out); err != nil {
		return issue{}, err
	}
	if !out.AttachmentCreate.Success {
		return issue{}, &refusal{Code: "NOT_SUCCESSFUL", Message: "attachmentCreate answered success false"}
	}
	return out.AttachmentCreate.Attachment.Issue, nil
}

func (l *linear) comment(ctx context.Context, id, issueID, body string) error {
	const query = `mutation Resolve($input: CommentCreateInput!) {
  commentCreate(input: $input) { success }
}`
	var out struct {
		CommentCreate struct {
			Success bool `json:"success"`
		} `json:"commentCreate"`
	}
	input := map[string]any{"id": id, "issueId": issueID, "body": body}
	if err := l.do(ctx, query, map[string]any{"input": input}, &out); err != nil {
		return err
	}
	if !out.CommentCreate.Success {
		return &refusal{Code: "NOT_SUCCESSFUL", Message: "commentCreate answered success false"}
	}
	return nil
}

func (l *linear) do(ctx context.Context, query string, variables map[string]any, out any) error {
	for attempt := 0; ; attempt++ {
		token, err := l.currentToken(ctx)
		if err != nil {
			return err
		}
		rejected, err := l.post(ctx, token, query, variables, out)
		if !rejected {
			return err
		}
		l.dropToken(token)
		if attempt > 0 {
			return &refusal{Code: authErrorCode, Message: "a freshly fetched token was rejected"}
		}
	}
}

func (l *linear) post(ctx context.Context, token, query string, variables map[string]any, out any) (rejected bool, err error) {
	payload, err := json.Marshal(map[string]any{"query": query, "variables": variables})
	if err != nil {
		return false, fmt.Errorf("encoding request: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, l.graphqlURL, bytes.NewReader(payload))
	if err != nil {
		return false, fmt.Errorf("building request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := l.http.Do(req)
	if err != nil {
		return false, retryable("calling linear: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusInternalServerError {
		return false, retryable("linear answered http %d", resp.StatusCode)
	}
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return false, retryable("reading linear's answer: %w", err)
	}
	var answer struct {
		Data   json.RawMessage `json:"data"`
		Errors []graphQLError  `json:"errors"`
	}
	decodeErr := json.Unmarshal(raw, &answer)
	if resp.StatusCode == http.StatusUnauthorized || (len(answer.Errors) > 0 && answer.Errors[0].Extensions.Code == authErrorCode) {
		return true, nil
	}
	if len(answer.Errors) > 0 {
		return false, answer.Errors[0].classify()
	}
	if resp.StatusCode != http.StatusOK {
		return false, &refusal{Code: fmt.Sprintf("HTTP_%d", resp.StatusCode), Message: "linear refused the request"}
	}
	if decodeErr != nil {
		return false, fmt.Errorf("decoding linear's answer: %w", decodeErr)
	}
	if len(answer.Data) == 0 || string(answer.Data) == "null" {
		return false, errors.New("linear's answer has no data")
	}
	if err := json.Unmarshal(answer.Data, out); err != nil {
		return false, fmt.Errorf("decoding linear's data: %w", err)
	}
	return false, nil
}

type graphQLError struct {
	Message    string `json:"message"`
	Extensions struct {
		Code                   string `json:"code"`
		UserPresentableMessage string `json:"userPresentableMessage"`
	} `json:"extensions"`
}

func (e graphQLError) classify() error {
	if e.Extensions.Code == "INPUT_ERROR" &&
		(strings.Contains(e.Message, "already exists") || strings.Contains(e.Extensions.UserPresentableMessage, "already exists")) {
		return errAlreadyExists
	}
	return &refusal{Code: e.Extensions.Code, Message: e.Message}
}

func (l *linear) currentToken(ctx context.Context) (string, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.token != "" && !l.tokenExpiring() {
		return l.token, nil
	}
	token, lifetime, err := l.fetchToken(ctx)
	if err != nil {
		return "", err
	}
	l.token = token
	l.tokenExpires = time.Time{}
	if lifetime > 0 {
		l.tokenExpires = l.now().Add(lifetime)
	}
	return token, nil
}

func (l *linear) tokenExpiring() bool {
	return !l.tokenExpires.IsZero() && !l.now().Before(l.tokenExpires.Add(-tokenExpiryLead))
}

func (l *linear) dropToken(rejected string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.token == rejected {
		l.token = ""
	}
}

func (l *linear) fetchToken(ctx context.Context) (string, time.Duration, error) {
	form := url.Values{
		"grant_type":    {"client_credentials"},
		"client_id":     {l.clientID},
		"client_secret": {l.clientSecret},
		"scope":         {linearScopes},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, l.tokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", 0, fmt.Errorf("building token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := l.http.Do(req)
	if err != nil {
		return "", 0, retryable("fetching token: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusInternalServerError {
		return "", 0, retryable("token endpoint answered http %d", resp.StatusCode)
	}
	if resp.StatusCode != http.StatusOK {
		return "", 0, &refusal{Code: fmt.Sprintf("TOKEN_HTTP_%d", resp.StatusCode), Message: "the token endpoint refused the client credentials"}
	}
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", 0, retryable("reading the token endpoint's answer: %w", err)
	}
	var answer struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int64  `json:"expires_in"`
	}
	if err := json.Unmarshal(raw, &answer); err != nil {
		return "", 0, errors.New("the token endpoint's answer did not decode")
	}
	if answer.AccessToken == "" {
		return "", 0, errors.New("the token endpoint's answer had no access token")
	}
	return answer.AccessToken, time.Duration(answer.ExpiresIn) * time.Second, nil
}
