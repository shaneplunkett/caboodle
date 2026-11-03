#!/bin/sh
# Tests scripts/terraform-changed.sh against a throwaway repo it builds here, so
# it needs no network and never touches this repo. Passes print to stdout and
# failures to stderr, so scripts/check.sh can stay quiet about the passes.
set -eu

script="$(cd "$(dirname "$0")" && pwd)/terraform-changed.sh"

# A pre-commit hook runs with git's variables pointing at the real repo, and a
# commit here would write to its index. Config from outside could sign or hook.
for name in $(git rev-parse --local-env-vars); do
  unset "$name"
done
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_NOSYSTEM=1
GIT_AUTHOR_NAME=tester
GIT_AUTHOR_EMAIL=test@example.com
GIT_COMMITTER_NAME=tester
GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

ok() { echo "ok - $1"; }
not_ok() {
  echo "not ok - $1" >&2
  failures=$((failures + 1))
}

write() {
  for path in "$@"; do
    mkdir -p "$(dirname "$path")"
    echo "$path" >>"$path"
  done
}
commit() {
  git add -A
  git commit --quiet --allow-empty --message "$1"
  git rev-parse HEAD
}

says() {
  wanted="$1"
  label="$2"
  got="$("$script" "$3" "$4" 2>"$work/stderr")" || got="exit $?"
  if [ "$got" != "$wanted" ]; then
    not_ok "$label (wanted $wanted, got $got)"
  elif [ -s "$work/stderr" ]; then
    not_ok "$label (said something on stderr: $(cat "$work/stderr"))"
  else
    ok "$wanted: $label"
  fi
}

# One commit on top of the base that touches the paths, then asks about it.
touching() {
  wanted="$1"
  label="$2"
  shift 2
  git checkout --quiet --detach "$base"
  write "$@"
  says "$wanted" "$label" "$base" "$(commit "$label")"
}

fails_open() {
  label="$1"
  got="$("$script" "$2" "$3" 2>"$work/stderr")" || got="exit $?"
  if [ "$got" != true ]; then
    not_ok "$label (wanted true, got $got)"
  elif ! grep -q "terraform-changed: can't get $2" "$work/stderr"; then
    not_ok "$label (stderr was: $(cat "$work/stderr"))"
  else
    ok "true and a message on stderr: $label"
  fi
}

git init --quiet --initial-branch=main "$work/repo"
cd "$work/repo"
write terraform/incus.tf hosts/plex.nix hosts/desktop/default.nix flake.nix flake.lock \
  modules/devices.nix modules/homelab.nix modules/services/plex/default.nix modules/services/plex/README.md \
  pkgs/overlays.nix pkgs/default.nix pkgs/vex-code/default.nix home/shane/home.nix \
  scripts/terraform.sh scripts/terraform-changed.sh scripts/terraform-guard.sh scripts/incus-image.sh \
  scripts/terraform-guard-test.sh scripts/deploy.sh scripts/in-dev-shell.sh \
  docs/pve/runner.md docs/modules/notes.md README.md AGENTS.md tools/minirack/server.ts \
  .github/workflows/deploy.yml
base="$(commit base)"

touching true 'a Terraform file' terraform/incus.tf
touching true 'a new Terraform file' terraform/new.tf
touching true 'a guest declaration in a host file' hosts/plex.nix
touching true 'a host that is a folder' hosts/desktop/default.nix
touching true 'a new host' hosts/new.nix
touching true 'a guest or hive entry in the flake' flake.nix
touching true 'a flake input' flake.lock
touching true 'a device' modules/devices.nix
touching true 'the homelab options' modules/homelab.nix
touching true 'a port forward in a service' modules/services/plex/default.nix
touching true 'a file under modules that no plan reads' modules/services/plex/README.md
touching true 'the overlays the flake forces' pkgs/overlays.nix
touching true 'the package list the overlays force' pkgs/default.nix
touching true 'scripts/terraform.sh' scripts/terraform.sh
touching true 'scripts/terraform-changed.sh' scripts/terraform-changed.sh
touching true 'scripts/terraform-guard.sh' scripts/terraform-guard.sh
touching true 'scripts/incus-image.sh' scripts/incus-image.sh
touching true 'docs beside a guest' docs/pve/runner.md hosts/plex.nix

touching false 'docs only' docs/pve/runner.md
touching false 'docs under a folder called modules' docs/modules/notes.md
touching false 'a README at the root' README.md
touching false 'AGENTS.md' AGENTS.md
touching false 'a new file at the root' unrelated.txt
touching false 'a root file whose name starts like a path' hosts.md terraform.md flake.nix.bak modules-old/x.nix
touching false 'a home-manager config' home/shane/home.nix
touching false 'one package' pkgs/vex-code/default.nix
touching false 'a tool' tools/minirack/server.ts
touching false 'a script the plan does not run' scripts/deploy.sh
touching false 'the guard test, not the guard' scripts/terraform-guard-test.sh
touching false 'the dev shell wrapper the job skips' scripts/in-dev-shell.sh
touching false 'the workflow' .github/workflows/deploy.yml

git checkout --quiet --detach "$base"
git rm --quiet modules/services/plex/default.nix
says true 'a file deleted from modules' "$base" "$(commit 'delete')"

git checkout --quiet --detach "$base"
git mv hosts/plex.nix docs/plex.nix
says true 'a host moved out of hosts' "$base" "$(commit 'move')"

git checkout --quiet --detach "$base"
chmod +x scripts/terraform.sh
says true 'only a script mode' "$base" "$(commit 'mode')"

git checkout --quiet --detach "$base"
write docs/pve/runner.md
commit 'docs' >/dev/null
write hosts/plex.nix
commit 'guest' >/dev/null
write README.md
says true 'a rebase merge with the change in the middle' "$base" "$(commit 'readme')"

git checkout --quiet --detach "$base"
write docs/pve/runner.md
commit 'docs' >/dev/null
write README.md
commit 'readme' >/dev/null
write tools/minirack/server.ts
says false 'a rebase merge with nothing a plan reads' "$base" "$(commit 'tool')"

git checkout --quiet --detach "$base"
write hosts/plex.nix
changed="$(commit 'guest')"
says true 'the change on its own, before its revert' "$base" "$changed"
git revert --no-edit "$changed" >/dev/null
says false 'a change reverted within the push' "$base" "$(git rev-parse HEAD)"

git checkout --quiet --detach "$base"
write terraform/incus.tf
changed="$(commit 'tf')"
write docs/pve/runner.md
commit 'docs' >/dev/null
git revert --no-edit "$changed" >/dev/null
says false 'a change reverted within the push, beside docs' "$base" "$(git rev-parse HEAD)"

git checkout --quiet --detach "$base"
write terraform/incus.tf
abandoned="$(commit 'abandoned')"
git checkout --quiet --detach "$base"
write README.md
says true 'a force push that drops a Terraform change' "$abandoned" "$(commit 'replacement')"

git checkout --quiet --detach "$base"
write docs/pve/runner.md
abandoned="$(commit 'abandoned docs')"
git checkout --quiet --detach "$base"
write README.md
says false 'a force push that only swaps docs' "$abandoned" "$(commit 'replacement')"

says false 'the same commit twice' "$base" "$base"

missing=1111111111111111111111111111111111111111
zeros=0000000000000000000000000000000000000000
fails_open 'a before commit that does not exist, with no remote' "$missing" "$base"
fails_open "a new branch's all-zero before" "$zeros" "$base"

got="$("$script" "$base" "$missing" 2>/dev/null)" || got="exit $?"
if [ "$got" = true ]; then
  ok 'true: an after commit it cannot read'
else
  not_ok "an after commit it cannot read (wanted true, got $got)"
fi

# The job's shape: a one-commit checkout, where the before commit has to be fetched.
git config uploadpack.allowAnySHA1InWant true
git checkout --quiet --detach "$base"
write hosts/plex.nix
moved="$(commit 'guest')"
git branch --quiet moved "$moved"
git checkout --quiet --detach "$base"
write README.md
unrelated="$(commit 'readme')"
git branch --quiet unrelated "$unrelated"

shallow() {
  wanted="$1"
  label="$2"
  branch="$3"
  after="$4"
  rm -rf "$work/clone"
  git clone --quiet --depth=1 --branch "$branch" "file://$work/repo" "$work/clone" 2>/dev/null
  cd "$work/clone"
  if git cat-file -e "$base^{commit}" 2>/dev/null; then
    not_ok "$label (the clone already holds the before commit)"
  else
    says "$wanted" "$label" "$base" "$after"
  fi
  cd "$work/repo"
}
shallow true 'a one-commit checkout, fetching the before commit, guest changed' moved "$moved"
shallow false 'a one-commit checkout, fetching the before commit, nothing a plan reads' unrelated "$unrelated"

git clone --quiet --depth=1 --branch moved "file://$work/repo" "$work/gone" 2>/dev/null
cd "$work/gone"
fails_open 'a one-commit checkout whose remote does not have the before commit' "$missing" "$moved"

if [ "$failures" -gt 0 ]; then
  echo "$failures failed" >&2
  exit 1
fi
