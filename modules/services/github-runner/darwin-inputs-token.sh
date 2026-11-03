# shellcheck shell=bash
# Writes the inputs token as a file nix.conf can include and only the runner's
# user can read, from the agenix copy, which stays root's. The directory has to
# stay open: Nix skips an include it can't read, but it can't stat one inside a
# closed directory, and that fails every Nix command for everyone else on the
# Mac. Root owns the directory so a job can't plant a symlink for this script,
# which runs as root, to write through.
secret=$1
file=$2
user=$3

token=$(<"$secret")

dir=$(dirname "$file")
umask 077
install -d -m 755 "$dir"
tmp=$(mktemp "$dir/.conf.XXXXXX")
trap 'rm -f "$tmp"' EXIT

printf 'access-tokens = github.com=%s\n' "$token" >"$tmp"
chown "$user" "$tmp"
mv "$tmp" "$file"
