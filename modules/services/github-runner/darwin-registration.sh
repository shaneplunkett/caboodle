# shellcheck shell=bash
# Keeps the runner's registration token where its launchd job can read it, and
# only while it needs one. launchd has no ExecStartPre, so this runs on its own
# timer rather than before the runner: nix-darwin's module only registers when
# .runner is missing, and otherwise never looks at the file. A registered runner
# gets the file removed, since every job runs as the user who could read it.
#
# This runs as root and every file in the state directory is a job's to plant, so
# it only ever tests for .runner and never reads anything out of there. Everything
# written lands in a directory root owns, so a job can't plant a symlink for this
# script to write through either.
url=$1
state=$2
file=$3
user=$4

if [ -e "$state/.runner" ]; then
  rm -f "$file"
  exit 0
fi

dir=$(dirname "$file")
install -d -m 755 "$dir"
tmp=$(mktemp "$dir/.token.XXXXXX")
trap 'rm -f "$tmp"' EXIT

github-runner-registration-token "$url" "$tmp"
chown "$user" "$tmp"
mv "$tmp" "$file"
