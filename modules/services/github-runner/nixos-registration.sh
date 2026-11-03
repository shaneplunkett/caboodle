# shellcheck shell=bash
# Fills the token file the runner's service reads before it starts. NixOS's
# module wipes the runner's state and registers again whenever that file's
# contents differ from the copy it kept in .current-token. So a registered
# runner gets its old copy back, with no call to GitHub, and only a runner
# with no credentials gets a new token.
#
# This runs as root and reads from a directory the job's user owns. A job can't
# plant anything at that path, because the module's InaccessiblePaths mounts over
# it in the job's view and the kernel refuses to unlink or replace a mount point.
# The symlink test keeps root from following one if that mount ever goes away.
url=$1
state=$2
file=$3
current=$state/.current-token

umask 077

if [ -e "$state/.runner" ] && [ -f "$current" ] && [ ! -L "$current" ]; then
  cp "$current" "$file"
  exit 0
fi

github-runner-registration-token "$url" "$file"
