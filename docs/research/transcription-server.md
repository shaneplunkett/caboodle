# Transcription server

A self-hosted speech-to-text service on the Mac mini, for three jobs:

- Dictation like Wispr Flow. Push to talk on the MacBook, the Linux desktop
  or the iPhone, and the text lands at the cursor.
- YouTube transcripts from a URL.
- Any other audio or video file, with timestamps.

Shane and agents both need to reach it, over an HTTP API and a web UI.

Shane and Vex researched this in October 2026. Nothing is built yet, and
where the mini sits in the homelab is still undecided (see
[mini-server.md](mini-server.md)). Versions and benchmark numbers are a
snapshot from then. Sources are inline.

## Findings

- **mlx-audio running Parakeet is the engine to beat.** It was about nine
  times faster than Whisper on the mini, and its accuracy was in the same
  range. The same server also runs Whisper when a transcript needs to be
  verbatim.
- **The engine has to run natively, not in Docker.** Docker on macOS runs in
  a Linux VM with no access to the Apple GPU, so any containerised engine is
  CPU only.
- **Plan on two instances, one for dictation and one for long jobs.** Each
  server works through one request at a time, so a long file holds up
  dictation.
- **The OpenAI transcription API is the contract.** Every dictation client
  worth using, plus Speakr and agents, can speak
  `POST /v1/audio/transcriptions`. Pick an engine that answers it.
- **A script plus a skill covers YouTube and agents.** No MCP server is
  needed.
- **Dictation on the MacBook may stay local.** A local Parakeet model on the
  laptop is about as fast as the mini, before network time. The mini earns
  its place for the iPhone, Linux and long files.

## Bake-off on the mini

Everything ran on the mini itself, on one six-minute segment from ABC's
7.30, with a reporter and several interviewees, all Australian. The 10 s
and 30 s clips are cut from the same audio. Times are warm, after the model
had loaded once, and measured from curl to the server's OpenAI endpoint.

| Engine and model | 10 s clip | 30 s clip | 6 min | Memory |
|---|---|---|---|---|
| mlx-audio, Parakeet TDT 0.6b v2 | 0.07 s | 0.28 s | 2.5 s | about 3 GB |
| mlx-audio, Parakeet TDT 0.6b v3 | 0.07 s | 0.28 s | 2.7 s | shared |
| mlx-audio, Whisper large-v3-turbo | 0.62 s | 1.13 s | 8.5 s | shared |
| whisper.cpp, large-v3-turbo q5_0 | 0.64 s | 1.08 s | 8.2 s | about 0.9 GB |

"Shared" means all three mlx-audio models ran in one server process, which
peaked at about 3.6 GB. The first request for each mlx-audio model took
45-80 s, almost all of it downloading the model.

The clip had no human captions, so there's no true word error rate. Vex
compared the transcripts against each other instead. The four engines
disagreed on 2-4% of words. YouTube's auto captions disagreed with all of
them on 6-8%, partly because their rolling cues repeat lines.

The differences have a pattern.

- Parakeet tidies speech. It drops "you know" and false starts, which suits
  dictation. It also garbled one phrase ("left-versue" for "left-right
  issue") and spelt the party "Labour".
- Whisper is closer to verbatim and got "Labor" right. That suits
  transcripts of real conversations, where the exact words matter.

Two more results from the same run:

- A 10 s Parakeet request sent while a long Whisper job was running took
  7.3 s instead of 0.07 s. mlx-audio queues requests through one worker, so
  dictation needs its own instance.
- Parakeet makes word timestamps, but mlx-audio's `verbose_json` drops them.
  It only passes segments through for Whisper. They're in the native
  `ndjson` response as `sentences[].tokens[]`, so a small patch or shim
  would expose them.

## Engines

| Engine | OpenAI endpoint | Runs on | Speaker labels | Packaging |
|---|---|---|---|---|
| mlx-audio | Yes | MLX on the GPU | Has models, untested over HTTP | PyPI |
| whisper.cpp | With `--inference-path` | Metal | Experimental only | nixpkgs |
| WhisperKit | Yes, `json` and `verbose_json` only | Neural Engine | Library only | Homebrew |
| speaches | Yes | CPU only on a Mac | No | uv or Docker |
| FluidAudio | No server | Neural Engine | Yes | SwiftPM |

**mlx-audio** ([repo](https://github.com/Blaizzy/mlx-audio)) runs Whisper,
Parakeet v2 and v3, Canary, Voxtral and others behind one server, plus
Sortformer diarisation models and WebSocket realtime endpoints
([server.py](https://github.com/Blaizzy/mlx-audio/blob/main/mlx_audio/server.py)).
Its gotchas:

- The default `response_format` is `ndjson`, so clients must ask for `json`,
  `text` or `verbose_json`.
- `model` is a required field.
- It has no SRT or VTT output, so subtitles have to be built from segments.
- Whisper needs the `mlx-community/whisper-large-v3-turbo-asr-fp16` repo.
  The plain `whisper-large-v3-turbo` repo has no processor files and fails
  with "Processor not found".
- Its Studio web UI isn't in the PyPI package. It's a Next.js app in the
  repo that runs `npm install` and `next dev` at startup, and it keeps
  history in the browser's localStorage. It's a demo, not something to run
  for real.

**Packaging mlx-audio with Nix** looks doable. nixpkgs' own
`python3Packages.mlx` builds with Metal off
([default.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/python-modules/mlx/default.nix)),
but nixpkgs also has `mlx-bin` and `mlx-metal`, the prebuilt wheels with
Metal. mlx-audio itself isn't in nixpkgs, so it would be a
`buildPythonPackage` on top of those, or a uv2nix build of its lockfile.

**Parakeet models.** [v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2)
is English only, with 6.05% average WER on the Open ASR leaderboard.
[v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) adds 24 more
European languages at 6.34%. Both are CC-BY-4.0.

**whisper.cpp** ([server README](https://github.com/ggml-org/whisper.cpp/blob/master/examples/server/README.md))
is the boring option. It's in nixpkgs with Metal on by default
([package.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/wh/whisper-cpp/package.nix)),
returns `srt` and `vtt` as well as JSON, and has Silero VAD built in. It
listens on `/inference` unless started with
`--inference-path /v1/audio/transcriptions`, ignores the `model` field, and
needs ffmpeg on `PATH` for `--convert`. On darwin the nixpkgs build isn't
wrapped with ffmpeg. A `parakeet-server` is an
[open PR](https://github.com/ggml-org/whisper.cpp/pull/3904). If that lands,
whisper.cpp gets Parakeet's speed without Python.

**WhisperKit** ([argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift#local-server))
has a clean OpenAI server, but it's Homebrew only and not measured here.

**speaches** ([repo](https://github.com/speaches-ai/speaches)) is fully
OpenAI-compatible, but its engine is CTranslate2, which has no Metal
support ([hardware support](https://github.com/OpenNMT/CTranslate2/blob/master/docs/hardware_support.md)).
On a Mac it's CPU only.

**FluidAudio** ([benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md))
is probably the fastest engine of all, running Parakeet on the Neural
Engine. It has no HTTP server of its own. Local Mac dictation apps use it.

## Web UIs

No UI does everything. Shane wants one that sends audio to a native engine,
takes YouTube URLs and labels speakers.

| UI | External engine | YouTube | Speaker labels | Sign-in |
|---|---|---|---|---|
| Speakr | Yes | No | If the engine returns them | Multi-user, OIDC |
| Scriberr | No | Yes | pyannote | Single user |
| OpenTranscribe | No | Yes | Yes | Multi-user |
| mlx-audio Studio | Its own server | No | No | None |

**Speakr** ([repo](https://github.com/murtaza-nasir/speakr)) is the pick. It
only supports Docker, which is fine because the heavy work happens in the
engine. Set `TRANSCRIPTION_CONNECTOR=openasr`. That connector posts
`verbose_json` to `{BASE_URL}/v1/audio/transcriptions` and keeps segment
timestamps and speaker labels
([openasr.py](https://github.com/murtaza-nasir/speakr/blob/master/src/services/transcription/connectors/openasr.py)).
The default `openai_whisper` connector keeps only the text. Speakr has OIDC,
so it fits the Pocket ID rule without the gate. It has no YouTube support,
but it watches a folder for new audio, so a YouTube script can drop files
there.

**Scriberr** ([repo](https://github.com/rishikanthc/Scriberr)) has YouTube
built in and installs natively, but its OpenAI adapter hardcodes
api.openai.com
([openai_adapter.go](https://github.com/rishikanthc/Scriberr/blob/main/internal/transcription/adapters/openai_adapter.go)),
so on the mini it would transcribe on the CPU. Its maintenance stalled in
2026.

## Dictation clients

Most dictation apps only run models locally. These can send audio to a
server.

| Client | Platforms | Server URL format | Cleanup step |
|---|---|---|---|
| VoiceInk | macOS | Full `/v1/audio/transcriptions` URL | Any OpenAI chat URL or Ollama |
| OpenWhispr | macOS, Windows, Linux, iOS keyboard | Base URL | Custom base URL |
| voxtype | Linux | Base URL without `/v1` | Shell command |
| hyprwhspr | Linux | Full URL, with failover | Shell hook |

- **MacBook: [VoiceInk](https://github.com/Beingpax/VoiceInk).** It's GPL,
  has push to talk and pastes at the cursor. It can use local Parakeet or a
  server per mode, so local and the mini can be compared side by side.
- **Linux desktop: [voxtype](https://github.com/peteonrails/voxtype).** It's
  Wayland-first and types with `wtype`. OpenWhispr can't auto-paste on
  Wayland.
- **iPhone: OpenWhispr's keyboard.** Its source allows custom servers,
  including `*.ts.net` addresses. Whether the App Store build has that yet is
  unverified. A Shortcut on the Action button that posts the recording and
  copies the text is the fallback.
- **Ruled out: [Handy](https://github.com/cjpais/Handy).** The maintainer
  won't add remote endpoints
  ([PR #1435](https://github.com/cjpais/Handy/pull/1435)). Superwhisper and
  Wispr Flow don't take a custom speech-to-text server either.

## YouTube

nixpkgs' yt-dlp already bundles Deno and yt-dlp-ejs, which YouTube has
needed since late 2025 ([EJS wiki](https://github.com/yt-dlp/yt-dlp/wiki/EJS)).

The plan is to use uploader captions if they exist, otherwise download the
audio and transcribe it. Auto captions are worse than every engine above,
and Parakeet does an hour of audio in well under a minute, so they aren't
worth using.

```sh
yt-dlp --skip-download --write-subs --sub-langs "en.*" --convert-subs srt URL
yt-dlp -f ba -o audio.%(ext)s URL
```

During the bake-off, `-x --audio-format wav` got an HTTP 403 and
`-f ba` worked straight after. That's the PO token blocking described in
the [PO Token Guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide).
Download audio-only with `-f ba` and convert with ffmpeg afterwards. Add
[bgutil-ytdlp-pot-provider](https://github.com/Brainicism/bgutil-ytdlp-pot-provider)
only if 403s keep coming. A home IP is less likely to be blocked than a
datacenter one
([#12475](https://github.com/yt-dlp/yt-dlp/issues/12475)).

## Agent access

Agents call the same OpenAI endpoint with curl
([API reference](https://platform.openai.com/docs/api-reference/audio/createTranscription)).
For YouTube, a `transcribe` script does the captions-then-audio logic, and a
skill teaches agents to use it. That works in any agent with a shell. The
existing YouTube MCP servers only fetch captions and never fall back to
transcribing.

## Fitting it into the homelab

These are the parts that depend on how the mini joins the homelab.

- **Routing.** Ingress reaches devices outside the hive through
  `externalRoutes` in `modules/services/nginx-ingress`, and the mini already
  has an entry in `modules/devices.nix`. Each app would be one line there.
  The app has to listen on the LAN, not on loopback.
- **The macOS firewall.** nix-config turns on the application firewall with
  stealth mode on every Mac. It silently drops connections to binaries that
  aren't properly signed, which includes everything built by Nix. During the
  bake-off, a server listening on the mini's tailnet address accepted the
  TCP connection and then never answered. Tailscale Serve worked, because
  Tailscale itself is allowed. Ingress will hit the same wall.
- **Sign-in.** mlx-audio has no login, so its UI would go behind the
  oauth2-proxy gate. Dictation clients and agents can't do a browser
  sign-in, so `/v1/` has to be an open path on the gate with its own key.
  mlx-audio has no API key support, so the key check would live in nginx.
  The gate only admits `media_admins`, which is an odd group for this.
  Speakr has its own OIDC login, so it wouldn't need the gate.
- **Dictation latency.** Through ingress, a request goes from the client to
  ingress to the mini, plus a TLS handshake. VoiceInk opens a new connection
  per request. That's still small next to 0.07 s of compute on a LAN, but
  it's unmeasured from outside the house.

## Open questions

- How does the mini join the homelab? See [mini-server.md](mini-server.md).
- Does mlx-audio's diarisation return speaker labels over HTTP?
- Is the gap between Parakeet's tidying and Whisper's accuracy acceptable
  for transcripts, or do long files go to Whisper?
- Does local dictation on the MacBook beat the mini enough to skip the mini
  for that? Measure it with VoiceInk's two modes.
