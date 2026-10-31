# shellcheck shell=bash
owner=$1
dir=$2
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
token=$(api -X POST -H "Authorization: Bearer $jwt" \
  "https://api.github.com/app/installations/$installation/access_tokens" | jq -er .token)

names=()
page=1
while :; do
  batch=$(api -H "Authorization: Bearer $token" \
    "https://api.github.com/installation/repositories?per_page=100&page=$page" | jq -r '.repositories[].name')
  if [ -z "$batch" ]; then
    break
  fi
  mapfile -t -O "${#names[@]}" names <<<"$batch"
  page=$((page + 1))
done

if [ "${#names[@]}" -eq 0 ]; then
  echo "The installation lists no repositories." >&2
  exit 1
fi

export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.https://github.com/.extraHeader
GIT_CONFIG_VALUE_0="Authorization: Basic $(printf 'x-access-token:%s' "$token" | base64 -w0)"
export GIT_CONFIG_VALUE_0

failed=0
for name in "${names[@]}"; do
  repo=$dir/$name.git
  if [ -d "$repo" ]; then
    git -C "$repo" remote update --prune || failed=1
  else
    rm -rf "$repo.partial"
    if git clone --mirror "https://github.com/$owner/$name.git" "$repo.partial"; then
      mv "$repo.partial" "$repo"
    else
      failed=1
    fi
  fi
done

echo "Fetched ${#names[@]} repositories into $dir."
exit "$failed"
