# shellcheck shell=bash
# Signs a JWT with the App's key, mints an installation token narrowed to this
# repo and administration: write, and writes a new registration token to a file.
# It reads nothing from the runner's state, and each platform's script decides
# whether a token is needed.
url=$1
file=$2

umask 077

owner=$(basename "$(dirname "$url")")
repo=$(basename "$url")
token=$(github-app-token "$owner" "$(jq -nc --arg repo "$repo" \
  '{repositories: [$repo], permissions: {administration: "write"}}')")

curl -fsS --retry 3 -X POST \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  -H "Authorization: Bearer $token" \
  "https://api.github.com/repos/$owner/$repo/actions/runners/registration-token" |
  jq -je .token >"$file"
