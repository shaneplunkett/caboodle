#!/usr/bin/env bash
# Dumps every repo's issues, pull requests, comments and reviews from the forge
# as JSON, since none of it moves to GitHub. Run it from the dev shell with rbw
# unlocked: tools/forgejo-dump.sh <dir>. docs/pve/mirror.md says where it goes.
set -euo pipefail
out=${1:?usage: forgejo-dump.sh <dir>}
api=https://git.shaneplunkett.com/api/v1
token=$(rbw get forge_token_shane)

get() {
  curl -fsS --retry 3 -H "Authorization: token $token" "$api/$1"
}

pages() {
  local sep='?' page=1 batch
  if [[ $1 == *\?* ]]; then
    sep='&'
  fi
  while :; do
    batch=$(get "$1${sep}limit=50&page=$page")
    if [ "$(jq length <<<"$batch")" -eq 0 ]; then
      break
    fi
    printf '%s\n' "$batch"
    page=$((page + 1))
  done | jq -s 'add // []'
}

mkdir -p "$out"

repos=()
page=1
while :; do
  batch=$(get "repos/search?limit=50&page=$page" | jq -r '.data[].full_name')
  if [ -z "$batch" ]; then
    break
  fi
  mapfile -t -O "${#repos[@]}" repos <<<"$batch"
  page=$((page + 1))
done

for repo in "${repos[@]}"; do
  dir=$out/$repo
  mkdir -p "$dir"
  echo "$repo" >&2
  get "repos/$repo" >"$dir/repo.json"
  pages "repos/$repo/issues?state=all&type=issues" >"$dir/issues.json"
  if jq -e .empty "$dir/repo.json" >/dev/null; then
    echo '[]' >"$dir/pulls.json"
  else
    pages "repos/$repo/pulls?state=all" >"$dir/pulls.json"
  fi
  pages "repos/$repo/issues/comments" >"$dir/comments.json"
  for number in $(jq -r '.[].number' "$dir/pulls.json"); do
    reviews=$(pages "repos/$repo/pulls/$number/reviews")
    for id in $(jq -r '.[] | select(.comments_count > 0) | .id' <<<"$reviews"); do
      comments=$(pages "repos/$repo/pulls/$number/reviews/$id/comments")
      reviews=$(jq --argjson id "$id" --argjson comments "$comments" \
        'map(if .id == $id then . + {comments: $comments} else . end)' <<<"$reviews")
    done
    jq -n --argjson number "$number" --argjson reviews "$reviews" '{pull: $number, reviews: $reviews}'
  done | jq -s '.' >"$dir/reviews.json"
done

cat >"$out/README.md" <<EOF
# Forgejo dump

Every repo's issues, pull requests, comments and reviews from the forge at
git.shaneplunkett.com, taken $(TZ=Australia/Melbourne date '+%-d %B %Y at %H:%M %Z') with
tools/forgejo-dump.sh from caboodle, ahead of retiring the forge. The git
history itself is in the mirror beside this folder; this is the metadata
that didn't move to GitHub.

Each \`<owner>/<repo>\` folder holds the API's own JSON:

- \`repo.json\`: the repo's settings and description.
- \`issues.json\`: issues, open and closed, with their bodies.
- \`pulls.json\`: pull requests, open, closed and merged, with their bodies.
- \`comments.json\`: every comment on its issues and pull requests, matched
  to one by \`issue_url\` or \`pull_request_url\`.
- \`reviews.json\`: each pull request's reviews, and each review's line
  comments under \`comments\`.

\`jq -r '.[] | "\(.number) \(.title)"' shane/caboodle/pulls.json\` lists a
repo's pull requests.
EOF
