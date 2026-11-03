# shellcheck shell=bash
# Fills the token file the runner's service reads before it starts. NixOS's
# module wipes the runner's state and registers again whenever that file's
# contents differ from the copy it kept in .current-token. So a registered
# runner gets its old copy back, with no call to GitHub, and only a runner
# with no credentials gets a new token.
url=$1
state=$2
file=$3

umask 077

if [ -e "$state/.runner" ] && [ -e "$state/.current-token" ]; then
  cp "$state/.current-token" "$file"
  exit 0
fi

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
