# shellcheck shell=bash
# Prints an hour-long installation token for the GitHub App on an account's
# installation. The App's client ID and private key come from the calling
# unit's LoadCredential, as client-id and private-key. An optional second
# argument is the JSON body of the token request, which narrows the token to
# some repositories or permissions.
owner=$1
request=${2:-'{}'}
key=$CREDENTIALS_DIRECTORY/private-key

b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

api() {
  curl -fsS --retry 3 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' "$@"
}

now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
claims=$(jq -nc --arg iss "$(<"$CREDENTIALS_DIRECTORY/client-id")" --argjson now "$now" \
  '{iss: $iss, iat: ($now - 60), exp: ($now + 540)}' | b64url)
signature=$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign "$key" | b64url)
jwt=$header.$claims.$signature

installation=$(api -H "Authorization: Bearer $jwt" "https://api.github.com/users/$owner/installation" | jq -er .id)
api -X POST -H "Authorization: Bearer $jwt" -d "$request" \
  "https://api.github.com/app/installations/$installation/access_tokens" | jq -er .token
