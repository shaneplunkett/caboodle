#!/bin/sh
# Runs scripts/build-linux-hosts.sh against a fake repo, so it costs no
# evaluation and no build, and never waits on the real scripts/quietly.sh's lock.
# A fake git points the script at the sandbox, a fake quietly.sh records each call
# and plays the hosts, and a fake nix on the PATH catches a call that skips
# quietly.sh. FAIL_HOST makes one host's build fail, and INT_HOST interrupts the
# script during one host's build. FAIL_HOST takes several names, separated by
# spaces. scripts/check.sh runs this.
set -eu

script="$(cd "$(dirname "$0")" && pwd)/build-linux-hosts.sh"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

mkdir -p "$sandbox/bin" "$sandbox/scripts"

cat >"$sandbox/bin/git" <<EOF
#!/bin/sh
echo "$sandbox"
EOF

cat >"$sandbox/bin/nix" <<EOF
#!/bin/sh
echo "\$*" >>"$sandbox/bare"
exit 1
EOF

cat >"$sandbox/scripts/quietly.sh" <<EOF
#!/bin/sh
echo "\$*" >>"$sandbox/calls"
case "\$*" in
  *"nix eval"*)
    echo "cube deck plex"
    exit 0
    ;;
  *--dry-run*) exit 0 ;;
esac
link=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    --out-link)
      link="\$2"
      shift
      ;;
    .#hydraJobs.*) host="\${1#.#hydraJobs.}" ;;
  esac
  shift
done
if [ "\$host" = "\${INT_HOST:-}" ]; then
  kill -INT "\$PPID"
  exit 1
fi
case " \${FAIL_HOST:-} " in
  *" \$host "*)
    echo "error: build of \$host failed" >&2
    exit 1
    ;;
esac
if [ -n "\$link" ]; then
  ln -s "/nix/store/fake-\$host" "\$link"
fi
EOF

chmod +x "$sandbox/bin/git" "$sandbox/bin/nix" "$sandbox/scripts/quietly.sh"

failures=0

check() {
  if [ "$2" = "$3" ]; then
    echo "ok: $1"
  else
    echo "FAILED: $1"
    echo "  wanted: $2"
    echo "  got:    $3"
    failures=$((failures + 1))
  fi
}

# Runs the script with the given environment, leaving status, out and err behind.
run() {
  rm -rf "$sandbox/calls" "$sandbox/bare" "$sandbox/closures"
  status=0
  out="$(env PATH="$sandbox/bin:$PATH" "$@" "$script" 2>"$sandbox/err")" || status=$?
  err="$(cat "$sandbox/err")"
}

calls() {
  sed 1,2d "$sandbox/calls"
}

links() {
  for link in "$sandbox/closures"/*; do
    echo "${link##*/} -> $(readlink "$link")"
  done
}

all_built="nix build --out-link $sandbox/closures/cube --keep-going .#hydraJobs.cube
nix build --out-link $sandbox/closures/deck --keep-going .#hydraJobs.deck
nix build --out-link $sandbox/closures/plex --keep-going .#hydraJobs.plex"

all_linked="cube -> /nix/store/fake-cube
deck -> /nix/store/fake-deck
plex -> /nix/store/fake-plex"

echo "every host builds, with links"
run CLOSURE_LINKS="$sandbox/closures"
check "exits zero" 0 "$status"
check "prints the host list" "cube deck plex" "$out"
check "evaluates the host list first" "nix eval --raw .#linuxHosts --apply toString" "$(sed -n 1p "$sandbox/calls")"
check "one dry run over every host" "nix build --dry-run .#hydraJobs.cube .#hydraJobs.deck .#hydraJobs.plex" "$(sed -n 2p "$sandbox/calls")"
check "one build per host, each with its own link" "$all_built" "$(calls)"
check "every link survives" "$all_linked" "$(links)"
check "nothing skips quietly.sh" "no" "$([ -e "$sandbox/bare" ] && echo yes || echo no)"

echo
echo "every host builds, without links"
run CLOSURE_LINKS=
check "exits zero" 0 "$status"
check "prints the host list" "cube deck plex" "$out"
check "one build per host, none linked" "nix build --no-link --keep-going .#hydraJobs.cube
nix build --no-link --keep-going .#hydraJobs.deck
nix build --no-link --keep-going .#hydraJobs.plex" "$(calls)"

echo
echo "the first host fails"
run CLOSURE_LINKS="$sandbox/closures" FAIL_HOST=cube
check "exits non-zero" 1 "$status"
check "prints nothing on stdout" "" "$out"
check "attempts every host after it" "$all_built" "$(calls)"
check "names the host on stderr" "build-linux-hosts: these hosts didn't build: cube" "$(tail -n 1 "$sandbox/err")"
check "the hosts that built keep their links" "deck -> /nix/store/fake-deck
plex -> /nix/store/fake-plex" "$(links)"

echo
echo "the host in the middle fails"
run CLOSURE_LINKS="$sandbox/closures" FAIL_HOST=deck
check "exits non-zero" 1 "$status"
check "attempts every host" "$all_built" "$(calls)"
check "names only that host" "build-linux-hosts: these hosts didn't build: deck" "$(tail -n 1 "$sandbox/err")"

echo
echo "two hosts fail"
run CLOSURE_LINKS="$sandbox/closures" FAIL_HOST="cube plex"
check "exits non-zero" 1 "$status"
check "prints nothing on stdout" "" "$out"
check "attempts every host" "$all_built" "$(calls)"
check "names both hosts on stderr" "build-linux-hosts: these hosts didn't build: cube plex" "$(tail -n 1 "$sandbox/err")"
check "the host that built keeps its link" "deck -> /nix/store/fake-deck" "$(links)"

echo
echo "the build is interrupted"
if sh -c 'trap "exit 7" INT; kill -INT $$; exit 0'; then
  echo "skipped: this shell started with INT ignored, so no trap can catch it"
else
  run CLOSURE_LINKS="$sandbox/closures" INT_HOST=cube
  check "exits with INT's status" 130 "$status"
  check "starts no more hosts" "nix build --out-link $sandbox/closures/cube --keep-going .#hydraJobs.cube" "$(calls)"
  check "prints nothing on stdout" "" "$out"
fi

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures checks failed"
  echo "stderr of the last run:"
  echo "$err"
  exit 1
fi
echo "all checks passed"
