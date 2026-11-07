#!/bin/sh
# What a bump changed on each host, as nix store diff-closures prints it: every
# package whose version moved between the system the host ran before the bump
# and the one it runs now, or will run once Shane switches it. The flake-update
# skill reads this for its release notes.
#
#   scripts/release-diff.sh <merged-at> <host>...
#
# <merged-at> is when the bump landed on main, as gh pr view prints mergedAt.
# A host with a system generation newer than that was deployed by the merge,
# and its diff runs on the host, from its newest generation before the bump to
# the one it runs. A host with none is switched by hand, so its diff is from
# what it runs to what main builds for it: that closure is evaluated here and
# the two are compared on the runner, which built it, or on this Mac for a Mac,
# then through the cache, and when the host's system is in no store but its
# own, by the names in the two closures, which drops the sizes and pairs
# nothing. The Deck and the MacBook are often asleep; a host that doesn't
# answer is reported and skipped.
set -eu

merged_at="$1"
shift
root="$(git rev-parse --show-toplevel)"
main="$(git -C "$root" rev-parse origin/main)"
cache="http://cache.home.arpa:5000"
me="$(hostname -s)"
since="$(date -u -d "$merged_at" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$merged_at" +%s)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ssh_target() {
  case "$1" in
    macbook) echo "shane@$1" ;;
    *) echo "root@$1" ;;
  esac
}

run_on() {
  host="$1"
  shift
  if [ "$host" = "$me" ] || { [ "$host" = mini ] && [ "$me" = mini-server ]; }; then
    sh -c "$*"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=8 "$(ssh_target "$host")" "$*"
  fi
}

# Where a hand-switched host's two closures can be compared: its store if it's
# this Mac, else the runner's.
compare_on() {
  if [ "$1" = local ]; then
    shift
    sh -c "$*"
  else
    shift
    ssh -o BatchMode=yes root@runner "$*"
  fi
}

# The newest system generation made before the bump, and whether any came after.
cat >"$tmp/generations" <<EOF
  cd /nix/var/nix/profiles
  old=""; oldt=0; after=no
  for g in system-*-link; do
    t=\$(stat -c %Y "\$g" 2>/dev/null || stat -f %m "\$g")
    if [ "\$t" -le $since ]; then
      if [ "\$t" -gt "\$oldt" ]; then old=\$g; oldt=\$t; fi
    else after=yes; fi
  done
  echo "\$after /nix/var/nix/profiles/\$old \$(readlink /run/current-system) \$(uname -s)"
EOF

names="sed 's|^/nix/store/[a-z0-9]*-||' | grep -v -e '\\.drv\$' -e '-source\$' | sort -u"

for host in "$@"; do
  echo "# $host"
  if ! state="$(run_on "$host" "$(cat "$tmp/generations")" 2>/dev/null)"; then
    echo "$host didn't answer, so no diff."
    echo
    continue
  fi
  read -r after old current kernel <<EOF
$state
EOF
  if [ "$after" = yes ]; then
    run_on "$host" "nix store diff-closures $old $current"
    echo
    continue
  fi
  case "$kernel" in
    Darwin) attr="darwinConfigurations.$host.system" where=local ;;
    *) attr="nixosConfigurations.$host.config.system.build.toplevel" where=runner ;;
  esac
  new="$("$root/scripts/quietly.sh" nix eval --raw "github:shaneplunkett/caboodle/$main#$attr")"
  echo "(not switched yet: $current -> $new)"
  if compare_on "$where" "nix store diff-closures $current $new 2>/dev/null || nix store diff-closures --store $cache $current $new 2>/dev/null"; then
    echo
    continue
  fi
  echo "(by name only: $host's system is in no store but its own)"
  run_on "$host" "nix path-info -r $current | $names" >"$tmp/old"
  compare_on "$where" "nix path-info -r $new | $names" >"$tmp/new"
  diff "$tmp/old" "$tmp/new" | grep '^[<>]' | sed 's/^</-/; s/^>/+/' || true
  echo
done
