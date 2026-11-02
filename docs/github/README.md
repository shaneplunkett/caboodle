# GitHub

`github.com/shaneplunkett/caboodle` is `origin`. Changes land through pull
requests filed with `gh`, and the [mirror](../pve/mirror.md) keeps a bare
clone of every repo on the account at home in case GitHub goes.

## The check

`.github/workflows/check.yml` runs `scripts/check.sh` in the flake's dev
shell through `shaneplunkett/workflows`' shared check. `main`'s ruleset
requires `check / check` and nothing else: no review, and no rule that a
branch be up to date with `main`, so a pull request that went green stays
mergeable after something else lands.

The required check is what makes auto-merge wait. GitHub merges an
auto-merge pull request as soon as nothing required is pending, so without
it Renovate's pull requests would merge before the check had run.

The check pulls the dev shell from cache.nixos.org alone. The colmena fork,
terraform (unfree) and agenix aren't there, so every run compiles them, a
few minutes on a hosted runner. The shared workflow only adds the extra
caches when it's given an Attic endpoint, and Attic is gone; moving the
extra caches out of that step would fetch terraform and agenix from
numtide's cache and leave only colmena to compile.

## Updates

Renovate opens two pull requests early on Sunday, nobody is asked to review
them, and both merge themselves once the check passes. One holds every
dependency update. The other is lock file maintenance, which runs
`nix flake update` and so moves every input that isn't pinned in
`flake.nix`; Renovate never groups it with anything else. The check builds
nothing, so a bump that breaks a host lands anyway and shows up at the next
`scripts/deploy.sh`. Revert it then. The `flake-update` skill still triages
a lock file change when asked.

`ai-skills` doesn't wait for Sunday. Each push to its `main` dispatches
`.github/workflows/ai-skills.yml` here as the App, which bumps only that
input on `update/ai-skills`, opens the pull request as the App and turns on
auto-merge. The review happened in `ai-skills`, so a bad skill is fixed by
reverting it there, and the next push carries the revert over. The
dispatching workflow lives in the `ai-skills` repo and needs the App's
`APP_CLIENT_ID` and `APP_PRIVATE_KEY` in that repo's Actions secrets too.

## Renovate

`.github/workflows/renovate.yml` runs Renovate as the App from a hosted
runner, every day at 19:30 UTC: 06:30 in Melbourne's summer, 05:30 in
winter, so inside the Sunday batch either way. Run workflow on its Actions
page runs it now. The repo's rules are in `renovate.json`; the global ones
are the `RENOVATE_CONFIG` in the workflow. Only the Sunday run opens pull
requests; the other mornings refresh one that's still open.

- It only runs on caboodle (`autodiscoverFilter`), and onboards nothing.
- `renovate.json` extends `github>shaneplunkett/workflows` for the shared
  workflow pins.
- Commits go through GitHub's API (`platformCommit`), so GitHub signs them
  and authors them as `caboodle-agent[bot]`. The App's token also covers
  github.com's tags and releases, so the inputs token isn't needed.
- Renovate's container installs `nix`, `uv`, `pnpm`, Go and Node when a
  lock file needs them.
- Renovate reads a branch's Actions results as check runs, which needs the
  App's Checks permission on private repos. Without it a private branch
  looks pending forever and never automerges.
- Renovate skips any update whose pull request was closed unmerged, and it
  matches them by branch name. The previews it opened while GitHub was the
  forge's mirror all closed unmerged, under `renovate-github/`, which is
  why that prefix went at cutover rather than staying.

### Flake inputs

Lock file maintenance moves every input that's only in `flake.lock`. An
input whose commit is written into `flake.nix` is pinned, and Renovate bumps
it in the dependency pull request instead. To pin one, write it as one of
these, then run `nix flake lock`:

- `github:owner/repo/<commit>`
- `git+https://github.com/owner/repo?ref=<branch>&rev=<commit>` to follow a
  branch, since `github:` won't take a branch and a commit together.

`minimumReleaseAge` is off for pinned inputs, because `git-refs` has no
release dates and the wait would hold every input forever.

Only the fast movers are pinned: `llm-agents` and the Homebrew taps.
Everything else moves with the lock file, and these can't be pinned anyway:

- nixpkgs, because another input locks its own `nixpkgs` node.
- electron-nixpkgs, which a pin would turn into a clone of nixpkgs.

Moving an input between the two without moving its lock means editing its
`original` in `flake.lock` to match the new URL, adding or dropping the
`rev`. Change only `flake.nix` and `nix flake lock` relocks it at the
latest commit.

## GitHub App and inputs token

Both are in Bitwarden and in caboodle's Actions secrets.

- **The App** is `github-app-client-id` and `github-app-private-key`
  (`APP_CLIENT_ID` and `APP_PRIVATE_KEY` in Actions, and agenix for the
  mirror). It's installed on every repo on Shane's account, with read and
  write on contents, pull requests, issues, actions, workflows and commit
  statuses, and read on checks and Dependabot alerts. Jobs, Renovate and
  the mirror mint an hour-long installation token from it. Pull requests it
  opens run the check, which ones opened with `GITHUB_TOKEN` don't.
  Bitwarden holds the key base64'd, since `rbw` keeps one line:
  `rbw get github-app-private-key | base64 -d`.
- **The inputs token** is `github-inputs-token` (`INPUTS_TOKEN` in Actions),
  a fine-grained token with contents read on vex-brain, nix-config-private,
  ai-skills, noctalia-plugins and wallpapers, for fetching those inputs. A
  new private input has to be added to its repositories, or its fetch fails
  with a 404. It never expires, since it can only read.

To replace the token, regenerate it on GitHub's fine-grained tokens page,
then from `modules/agenix`:

```sh
rbw edit github-inputs-token
printf '%s' "$(rbw get github-inputs-token)" | agenix -e github-inputs-token.age
printf '%s' "$(rbw get github-inputs-token)" | gh secret set INPUTS_TOKEN --repo shaneplunkett/caboodle
```

The workstations read it from `~/.config/nix/access-tokens.conf`
([workstation](../workstation/README.md#the-inputs-token)), so rewrite that
too.
