# shellcheck shell=bash
mode=$1
clients=$2
key=$(<"$CREDENTIALS_DIRECTORY/api-key")
failed=0

request() {
  local args=(-sS -g -X "$1" -H "X-API-Key: $key" -w '\n%{http_code}'
    --retry 10 --retry-connrefused --retry-delay 2)
  if [[ -n ${3:-} ]]; then
    args+=(-H 'Content-Type: application/json' --data "$3")
  fi
  curl "${args[@]}" "$POCKET_ID_URL/api$2"
}

call() {
  local response status
  response=$(request "$@")
  status=${response##*$'\n'}
  if [[ $status != 2* ]]; then
    echo "$1 $2 failed with $status: ${response%$'\n'*}" >&2
    return 1
  fi
  printf '%s' "${response%$'\n'*}"
}

applying() {
  [[ $mode == apply ]]
}

if ! applying; then
  echo "Report only: listing what would change, and changing nothing."
fi

groups=$(call GET '/user-groups?pagination[limit]=1000' | jq '.data')

for name in $(jq -r '[.[].groups[]] | unique[]' "$clients"); do
  if [[ -z $(jq -r --arg name "$name" '.[] | select(.name == $name) | .id' <<<"$groups") ]]; then
    echo "group $name: creating"
    if applying; then
      group=$(call POST /user-groups "$(jq -n --arg name "$name" '{name: $name, friendlyName: $name}')")
      groups=$(jq --argjson group "$group" '. + [$group]' <<<"$groups")
    fi
  fi
done

for id in $(jq -r 'keys[]' "$clients"); do
  want=$(jq --arg id "$id" '.[$id]' "$clients")
  desired=$(jq '{
    name,
    callbackURLs,
    launchURL,
    pkceEnabled: .pkce,
    isPublic: false,
    skipConsent: true,
    isGroupRestricted: true
  }' <<<"$want")

  response=$(request GET "/oidc/clients/$id")
  status=${response##*$'\n'}
  current=${response%$'\n'*}

  if [[ $status == 404 ]]; then
    secret=$(jq -r '.secret // empty' <<<"$want")
    if [[ -z $secret ]]; then
      echo "$id: doesn't exist, and declares no secret to create it with" >&2
      failed=1
      continue
    fi
    echo "$id: creating"
    applying || continue
    created=$(call POST /oidc/clients "$(jq --arg id "$id" '. + {id: $id}' <<<"$desired")")
    generated=$(jq -r '.createdSecret.id // empty' <<<"$created")
    call POST "/oidc/clients/$id/secrets" \
      "$(jq -n --rawfile secret "$CREDENTIALS_DIRECTORY/$secret" '{secret: ($secret | rtrimstr("\n"))}')" >/dev/null
    if [[ -n $generated ]]; then
      call DELETE "/oidc/clients/$id/secrets/$generated" >/dev/null
    fi
    current=$(jq 'del(.createdSecret)' <<<"$created")
  elif [[ $status != 200 ]]; then
    echo "$id: GET failed with $status: $current" >&2
    failed=1
    continue
  fi

  drift=$(jq -r --argjson current "$current" \
    'to_entries[] | select($current[.key] != .value) | "  \(.key): \($current[.key] | tojson) -> \(.value | tojson)"' \
    <<<"$desired")
  if [[ -n $drift ]]; then
    echo "$id: updating"
    echo "$drift"
    if applying; then
      call PUT "/oidc/clients/$id" "$(jq --argjson desired "$desired" '. + $desired' <<<"$current")" >/dev/null
    fi
  fi

  have=$(jq -c '[.allowedUserGroups[]?.name] | sort' <<<"$current")
  need=$(jq -c '.groups | sort' <<<"$want")
  if [[ $have != "$need" ]]; then
    echo "$id: groups $have -> $need"
    if applying; then
      ids=$(jq -c --argjson names "$need" '[.[] | select(.name as $name | $names | index($name)) | .id]' <<<"$groups")
      call PUT "/oidc/clients/$id/allowed-user-groups" "$(jq -n --argjson ids "$ids" '{userGroupIds: $ids}')" >/dev/null
    fi
  fi

  if [[ -z $drift && $have == "$need" ]]; then
    echo "$id: up to date"
  fi
done

exit "$failed"
