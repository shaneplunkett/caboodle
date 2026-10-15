# SSH key in an agent

Shane's one ed25519 key, `~/.ssh/id_ed25519`, sits unencrypted on the
desktop, the MacBook and the Mac mini. It gets root on the LXCs, pushes to the
forge and GitHub, signs her commits, and is the `shane` recipient in
`modules/agenix/agenix-rules.nix`. The question is how to get it off disk and
into an agent without rotating it, and whether AI coding agents, which run a
lot of non-interactive ssh and git with no TTY, can live with that agent.

Researched in October 2026 from vendor docs and source code, plus a local
test with throwaway keys. Sources are numbered at the bottom. Nothing here is
built yet.

## Findings

- **Coding agents are only a blocker if the agent asks a human per use.**
  Bitwarden's "Always", 1Password's "each request" and `ssh-add -c` all
  stall agents. An agent that signs silently while unlocked works.
- **ControlMaster helps a lot but doesn't remove signing.** Twenty sequential
  commands went from 20 signatures to 1. A cold parallel burst still signs
  once per connection, and every signed commit or rebased commit is a
  signature that multiplexing never sees.
- **Only the password-manager agents can take the existing key.** Bitwarden
  and 1Password import an unencrypted OpenSSH ed25519 key. Secretive and
  ssh-tpm-agent can't hold ed25519 at all.
- **rbw already has an SSH agent.** Shane's rbw (1.15.0) serves SSH key items
  from her vault on a socket, with no approval prompt, unlocked by the same
  `rbw unlock` her CLI wrappers already rely on. It fits the headless mini
  better than the Bitwarden app. It works on the desktop, tested against the
  real hosts. macOS isn't tested, and rbw's maintenance is a risk.
- **age can't use any agent.** agenix needs the private key as a file, or
  through a pipe, at decrypt time. Coding agents mostly don't need it:
  piping a new value into `agenix -e` encrypts without decrypting.

## How much the agents sign

Every new SSH connection to a host costs one signature. So does every signed
commit, because `commit.gpgSign` and `tag.gpgSign` are on with
`gpg.format = "ssh"` in `home/shane/modules/common/git.nix`, and git signs
with `ssh-keygen -Y sign` through the agent when `user.signingKey` is a
public key [28].

A connection multiplexed over a live ControlMaster skips user
authentication entirely. In `ssh.c`, a successful `muxclient()` jumps past
`ssh_login()`, where all authentication happens, and the master only starts
listening after it has authenticated itself [26]. ControlPersist keeps the
master for the set idle time after its last client. Once it exits, the next
connection authenticates in full [25].

The catch is parallel starts. Every client that starts before the master is
listening finds no socket, makes its own connection and authenticates. Each
then tries to become the master, and the losers log `ControlSocket ...
already exists, disabling multiplexing` and carry on unmultiplexed [26].

## Test results

The setup: a throwaway ed25519 key and host key, an unprivileged `sshd` on
`127.0.0.1:22622`, and a separate `ssh-agent` holding the key with
`ssh-add -c`. The agent's `SSH_ASKPASS` script logged each confirmation and
then approved, denied or hung, so the log counts signatures. OpenSSH 10.5p1
on both ends, git 2.55.0, age 1.3.2, agenix 0.15.0 from the dev shell.

| Test | Signatures | Time |
| --- | --- | --- |
| 20 sequential, no multiplexing | 20 | 2.37 s |
| 20 sequential, multiplexed | 1 | 0.24 s |
| 10 parallel, no master yet | 10 | 0.17 s |
| Warm-up call, then 10 parallel | 1 | 0.14 s |
| 10 parallel, master up | 0 | 0.01 s |
| 3 calls, master expired before the third | 2 | |
| 5 signed commits | 5 | 0.17 s |
| Rebase of 4 signed commits | 4 | |

Every command exited 0. Multiplexed runs used `ControlMaster auto` and
`ControlPersist 10m`, except the expiry test, which used `ControlPersist 2s`
and a 4 s gap. The sequential tests ran three times each and the cold
parallel burst five times, with the same counts every run. Each cold burst
logged nine "disabling multiplexing" warnings. A rebase re-signs every
commit it rewrites.

Approval failures, with OpenSSH's own agent:

- **Denied:** `ssh` exits 255 in about 0.1 s with `agent refused operation`
  and `Permission denied (publickey)`. Through git, `git ls-remote` exits
  128.
- **Nobody answers:** the client blocked for the full 300 s until `timeout`
  killed it. The server gave up at its 120 s `LoginGraceTime` and logged
  `Timeout before authentication`, but the client didn't notice, because it
  was waiting on the agent and not the network. The server also logged a
  10 s `grace-exceeded` penalty against the source address.
- **One pending prompt blocks the whole agent.** While a prompt hung,
  `ssh-add -l` and a second `ssh` both hit a 10 s timeout. With five
  parallel requests and a 2 s approval each, prompts ran one at a time and
  the last client finished after 10.1 s. `ssh-agent` runs askpass and waits
  on it synchronously [26].

The penalty matters beyond the test. `sshd` refuses a source address for 5 s
after a failed authentication and 10 s after `LoginGraceTime` runs out, and
starts enforcing once 15 s has piled up [27]. An agent firing refused or
hung connections at an LXC can lock the workstation out of it for a while.

## Bitwarden desktop

Read at `desktop-v2026.9.1` (commit `8246ae9c`, 2026-09-29). The agent code
was identical on `main` at `57e52fcc` (2026-10-14).

- **Import:** "Import key from clipboard" takes OpenSSH or PKCS#8 keys [2].
  An unencrypted OpenSSH key is parsed without a password, and a password is
  only asked for if the key is encrypted [9].
- **Approval setting:** "Ask for authorization when using SSH agent" has
  three values: `Always` (the default), `Never` and `RememberUntilLock` [3].
  The approval is a plain Authorize or Deny dialog. Biometrics only unlock
  the vault [4].
- **What "remember" remembers:** each key plus a scope: `local:<host key
  fingerprint>` for an ssh connection, taken from OpenSSH's
  `session-bind@openssh.com`, or plain `local` for signing with no host, like
  git commits. The requesting process only appears in the dialog [4]. So
  with Remember, it's one click per key per host per unlock: roughly one per
  LXC, the forge, GitHub and commit signing. That's an estimate from the
  code, not counted.
- **Pending prompts:** the native side waits 60 s for the app's answer, then
  returns a failure to the client [5]. Waiting for an unlock has its own
  60 s limit [4]. A locked vault takes priority over `Never`: the app shows
  "Please unlock your vault to approve the SSH key request." and waits [4].
- **Concurrency:** one task per connection, and up to 32 connections queued
  [6]. Approval dialogs queue one at a time [4]. A bug where parallel
  requests hung for 60 s (#21839) was fixed by PR #21881 in July 2026 [7].
  Reading the code, two cases still look bad, though neither is tested here.
  While the vault is locked, a newer request cancels older ones, which then
  fail after 60 s. With Always or Remember, one unanswered dialog holds up
  every request behind it.
- **Linux:** the socket is `$BITWARDEN_SSH_AUTH_SOCK`, or
  `~/.bitwarden-ssh-agent.sock` by default, created with mode 0600 [6]. The
  app has to be running with an account logged in [1]. Nothing in the agent
  code is Wayland-specific. nixpkgs has `bitwarden-desktop` 2026.9.1 for
  Linux and aarch64-darwin. There's no NixOS or home-manager module, so the
  socket variable is set by hand [11]. Issue #20089, still open, says the
  Linux agent doesn't serve keys when `IdentityFile` points at a `.pub` file
  [8].
- **macOS:** `~/.bitwarden-ssh-agent.sock` for the DMG build, and
  `~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock`
  for the App Store build [1].
- **Unattended:** the desktop app offers a `Never` vault timeout [10].
  Together with the `Never` prompt setting, that's the only fully hands-off
  setup. After a restart the vault is locked, and on the mini someone has to
  unlock it in the GUI, through Screen Sharing.

## rbw's built-in agent

Read at rbw 1.15.0 (2025-12-31), the version in nixpkgs and the one Shane
runs. Her config sets `lock_timeout = 604800` (a week) and `pinentry-tty`
(`home/shane/modules/common/rbw.nix`).

- **What it is:** since 1.14.0, `rbw-agent` also serves SSH key items from
  the vault [14]. Point ssh at `$XDG_RUNTIME_DIR/rbw/ssh-agent-socket`
  after `rbw unlock` [12]. On macOS there's no runtime dir, so the code falls
  back to `$TMPDIR/rbw-<uid>/ssh-agent-socket` [13]. That path comes from the
  code and isn't tested.
- **Import:** it reads the vault's SSH key items, so the key goes in through
  Bitwarden's import [2]. It signs ed25519 and RSA keys [13].
- **Approval:** none. `sign()` finds the matching private key and signs. If
  rbw is locked, it first tries to unlock through pinentry in the
  environment of the last rbw client [13]. With `pinentry-tty` and no
  terminal, that should fail rather than hang. On the desktop it did.
- **Lock timer:** each request resets rbw's lock timer [13], so busy agents
  keep it unlocked.
- **Concurrency:** the agent library starts a task per connection [15], and
  each request briefly takes rbw's state lock [13].
- **Tested on the desktop:** the key is already in the vault as an SSH Key
  item, and rbw serves it with the same fingerprint as
  `~/.ssh/id_ed25519.pub`, so it syncs from her server (#267 doesn't bite).
  With only rbw's socket as `IdentityAgent`, ssh to plex and
  `git ls-remote` against the forge both signed with no prompt, and ten
  parallel logins to different LXCs all succeeded. After `rbw lock`,
  `ssh-add -l` got "agent refused operation" and ssh failed in under a
  second with exit 255. rbw didn't try to unlock itself and stayed locked.
- **Risks:** rbw's maintainer has been inactive since early 2026, and a
  thread from May 2026 asks who will keep it going (#338) [16]. Issue #267
  reports SSH key items not syncing from some servers [16]. A fork adds
  per-use confirmation, but it isn't merged [16].

## 1Password

1Password is closed source, so this rests on its docs, read 2026-10-15.

- **Import:** existing Ed25519 and RSA keys in OpenSSH, PKCS#1 or PKCS#8
  format, from a file or pasted [19].
- **Approval:** "Ask approval for each new" application (the default),
  application and terminal session, or request. Approvals last until
  1Password locks (the default), until it quits, or for 4, 12 or 24 hours.
  There's no setting that never asks [17].
- **Who's asking:** an approval covers an application "including all of its
  subprocesses" [18]. So a coding agent launched from a terminal counts as
  that terminal. How it decides on a "terminal session" isn't documented.
- **Background requests:** if the requesting app isn't in the foreground,
  1Password hides the prompt and shows "SSH request waiting" in the tray
  [17] [20]. That's the normal case for a coding agent. The timeout exists,
  but its length isn't documented anywhere official. A user-posted log shows
  "ssh authorization prompt timed out" (unverified, community source [35]).
- **Sockets:** `~/.1password/agent.sock` on Linux, which doesn't work with
  Flatpak or Snap installs, and
  `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` on
  macOS [21].
- **Unattended:** at least one human approval per app per key, after every
  lock. Not workable on the mini.

## Secretive

v4.0.0 (2026-09-21), source at `9edc8799`.

- **Import: no.** "The secure enclave doesn't allow import or export of
  private keys" [22]. Secure Enclave keys are ECDSA P-256, plus ML-DSA on
  macOS 26 [23]. It can't hold this ed25519 key.
- **Approval, for reference:** set per key when it's created: not required,
  presence (Touch ID, Watch or password), or current biometry. After a
  signature, the notification offers to skip prompts for that key for 1
  minute, 5 minutes, 1 hour or 24 hours. Every signature posts a notification
  naming the app, key and host. It identifies the requester by walking up
  the parent processes to a signed GUI app [23].

## ssh-tpm-agent

v0.9.0 (2026-05-04), source at `5d1974b9`.

- **Import: not for ed25519.** `ssh-tpm-keygen --import` accepts only ECDSA
  keys and 2048-bit RSA, and anything else stops with "unsupported key type"
  [24].
- **Proxying:** `-A` falls back to other agent sockets [24], so the ed25519
  key could sit in another agent behind it. That adds nothing over using the
  other agent directly.
- nixpkgs has it, and home-manager has `services.ssh-tpm-agent` [24].

## agenix

- **age doesn't support ssh-agent,** and there are no plans to add it [29]
  [31].
- **A passphrase on the key file works, but only with a terminal.** age
  reads the passphrase from `/dev/tty`, or from stdin if that's a terminal
  [30]. There's no askpass or environment variable route. Tested: with no
  TTY, `age -d` and `agenix -d` on a passphrase-protected key fail at once
  with `standard input is not a terminal, and /dev/tty is not available`.
  In a pty, both prompt and decrypt.
- **agenix's identity:** it passes `~/.ssh/id_rsa` and `~/.ssh/id_ed25519`
  to age if they exist, unless `-i` is given [32]. With the key gone from
  disk, `-i` becomes required.
- **Encrypting needs no private key.** With piped stdin, `agenix -e`
  replaces the secret without decrypting first [32]. AGENTS.md has agents
  pipe rbw values into `agenix -e`, so that flow keeps working with no key
  file.
- **Reading the key from the vault works for one file.** Tested with a
  throwaway key: `agenix -d a.age -i <(cat key)` decrypts. `agenix -r` with
  the same process substitution fails on the second file with `no
  identities found`, because the pipe is empty after the first age run. For
  a rekey, the key needs a short-lived file, for example in
  `$XDG_RUNTIME_DIR`. `rbw get --field=private_key` prints an SSH key item's
  private key [14]. Whether the key Bitwarden stores is in a format age
  accepts isn't tested.
- **Activation is unaffected.** Hosts decrypt with their own host keys.
- **Hardware plugins all need a new recipient.** age-plugin-se (Secure
  Enclave), age-plugin-tpm and age-plugin-yubikey each generate a new key
  and can't import the existing one [33]. Two small plugins derive an age
  identity from an ssh-agent signature, but that's still a new `age1...`
  recipient, so every secret gets re-encrypted. Both are a few months old
  with almost no users [34].

## Recommendation

**Try rbw's agent first, on all three machines.** It's already installed,
unlocks the same way her CLI wrappers do, and works over SSH on the mini
with no GUI. Coding agents get no prompts while rbw is unlocked, and the
key leaves the disk. Both checks passed on the desktop: the key item syncs
into rbw, and a locked rbw fails fast instead of hanging. Repeat them on a
Mac before switching it.

**Fall back to the Bitwarden app with prompts set to `Never`** on the
desktop and MacBook if rbw doesn't hold up. It's better maintained and has
the 60 s timeouts, but it needs the GUI unlocked, which is awkward on the
mini.

Either way:

- Import the key as an SSH key item, keep `~/.ssh/id_ed25519.pub`, and
  delete the private file once ssh, git and signing work.
- Set `IdentityAgent` in `programs.ssh` rather than relying on
  `SSH_AUTH_SOCK`. Apps launched from the GUI or launchd, like Vex Code on
  the mini, don't get the shell's environment. `IdentityAgent` accepts
  environment variables [25].
- Point the `github.com` block's `IdentityFile` at the `.pub`. With
  `IdentitiesOnly yes`, ssh needs that file to pick the agent's key [25].
- Keep `ControlMaster`. Where an agent is about to fan out to one host,
  one warm-up call first turns N signatures into 1.
- For agenix, decrypt with `-i <(rbw get --field=private_key ...)`, and use
  a temporary file in `$XDG_RUNTIME_DIR` for `agenix -r`.

The trade-off: any process running as Shane can still use the key silently
while the vault is unlocked, the same as today. What changes is that nothing
can copy the key off the disk, and it stops working when the vault locks.

## Open questions

- How rbw's agent behaves on macOS, including the `$TMPDIR` socket path.
  Not tested.
- Whether rbw gets a new maintainer, or the confirmation fork lands.
- 1Password's prompt timeout and how it handles parallel requests aren't
  documented.

## Sources

1. Bitwarden, SSH agent: https://bitwarden.com/help/ssh-agent/
2. Bitwarden, SSH keys and import: https://bitwarden.com/help/about-ssh/
3. Bitwarden prompt setting, `desktop-v2026.9.1`: https://github.com/bitwarden/clients/blob/desktop-v2026.9.1/apps/desktop/src/autofill/models/ssh-agent-setting.ts
4. Bitwarden approval and remember logic: https://github.com/bitwarden/clients/blob/desktop-v2026.9.1/apps/desktop/src/autofill/services/ssh-agent.service.ts
5. Bitwarden 60 s approval timeout: https://github.com/bitwarden/clients/blob/desktop-v2026.9.1/apps/desktop/desktop_native/napi/src/sshagent.rs
6. Bitwarden agent server and socket: https://github.com/bitwarden/clients/tree/desktop-v2026.9.1/apps/desktop/desktop_native/ssh_agent/src/server
7. Bitwarden parallel request bug and fix: https://github.com/bitwarden/clients/issues/21839, https://github.com/bitwarden/clients/pull/21881
8. Bitwarden `.pub` IdentityFile issue: https://github.com/bitwarden/clients/issues/20089
9. Bitwarden key import parser: https://github.com/bitwarden/sdk-internal/blob/main/crates/bitwarden-ssh/src/import.rs
10. Bitwarden vault timeout types: https://github.com/bitwarden/clients/blob/desktop-v2026.9.1/libs/common/src/key-management/vault-timeout/types/vault-timeout.type.ts
11. nixpkgs `bitwarden-desktop`: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/bi/bitwarden-desktop/package.nix
12. rbw README, SSH agent: https://github.com/doy/rbw/blob/1.15.0/README.md#ssh-agent
13. rbw agent code: https://github.com/doy/rbw/blob/1.15.0/src/bin/rbw-agent/ssh_agent.rs, https://github.com/doy/rbw/blob/1.15.0/src/bin/rbw-agent/actions.rs, https://github.com/doy/rbw/blob/1.15.0/src/dirs.rs
14. rbw changelog: https://github.com/doy/rbw/blob/1.15.0/CHANGELOG.md
15. ssh-agent-lib 0.5.1 `listen`: https://github.com/wiktor-k/ssh-agent-lib/blob/v0.5.1/src/agent.rs
16. rbw issues: https://github.com/doy/rbw/issues/338, https://github.com/doy/rbw/issues/267, https://github.com/doy/rbw/issues/353
17. 1Password, authorization: https://developer.1password.com/docs/ssh/agent/authorization
18. 1Password, security model: https://developer.1password.com/docs/ssh/agent/security
19. 1Password, managing keys: https://developer.1password.com/docs/ssh/manage-keys
20. 1Password, compatibility: https://developer.1password.com/docs/ssh/agent/compatibility
21. 1Password, getting started: https://developer.1password.com/docs/ssh/get-started
22. Secretive FAQ: https://github.com/maxgoedjen/secretive/blob/main/FAQ.md, v4.0.0 release: https://github.com/maxgoedjen/secretive/releases/tag/v4.0.0
23. Secretive source at `9edc8799`: https://github.com/maxgoedjen/secretive/tree/9edc8799/Sources
24. ssh-tpm-agent: https://github.com/Foxboron/ssh-tpm-agent (README, `cmd/ssh-tpm-keygen/main.go` at `5d1974b9`); home-manager module: https://github.com/nix-community/home-manager/blob/master/modules/services/ssh-tpm-agent.nix
25. ssh_config(5): https://man.openbsd.org/ssh_config
26. OpenSSH source at `75ef208b` (`ssh.c`, `mux.c`, `readpass.c`, `ssh-agent.c`): https://github.com/openssh/openssh-portable/tree/75ef208b; ssh-add(1): https://man.openbsd.org/ssh-add
27. sshd_config(5), `LoginGraceTime` and `PerSourcePenalties`: https://man.openbsd.org/sshd_config
28. git-config, `user.signingKey`: https://git-scm.com/docs/git-config#Documentation/git-config.txt-usersigningKey
29. age README and man page: https://github.com/FiloSottile/age#readme, https://github.com/FiloSottile/age/blob/main/doc/age.1.ronn
30. age passphrase handling at `b74dce4c`: https://github.com/FiloSottile/age/blob/b74dce4c/cmd/age/parse.go, https://github.com/FiloSottile/age/blob/b74dce4c/internal/term/term.go
31. age ssh-agent requests: https://github.com/FiloSottile/age/issues/662, https://github.com/FiloSottile/age/discussions/244
32. agenix CLI: https://github.com/ryantm/agenix/blob/main/pkgs/agenix.sh (behaviour checked against 0.15.0 in this repo's dev shell)
33. age plugins: https://github.com/remko/age-plugin-se, https://github.com/Foxboron/age-plugin-tpm, https://github.com/str4d/age-plugin-yubikey
34. ssh-agent-backed age plugins: https://github.com/eszio/age-plugin-sshagent, https://github.com/kaysond/age-plugin-ssh-agent
35. 1Password community thread with a prompt timeout log (not a primary source): https://www.1password.community/developers-69/ssh-request-waiting-for-foreground-application-20344
