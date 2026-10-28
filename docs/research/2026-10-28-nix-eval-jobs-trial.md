# A bounded evaluator produced the same host derivations

On 28 October 2026, one nix-eval-jobs worker with an 8192 MiB budget
evaluated all 22 hosts at caboodle revision
`5d0135c44e1a79b4aab21db0b5c519a1f00f6fb6`. Every derivation path matched
the plain-Nix reference. Peak memory was 8.073 GiB against 13.002 GiB,
37.9% lower in these samples.

This makes bounded evaluation a candidate for the CI redesign without
changing cross-host configuration. It does not establish a production
budget or a guaranteed speed improvement. The evaluator libraries differed,
and each mode ran once with warm caches.

## Results

The [measurement artifact](2026-10-28-nix-eval-jobs-trial.json) retains
the source identity, versions, exact measurements, reference manifest and
comparison hashes.

| Evaluation | Successful hosts | Peak memory | Wall time | CPU time | Error rows |
| --- | --- | --- | --- | --- | --- |
| Plain nix eval | 22/22 | 13.002 GiB | 129.61 s | 153.26 s | 0 |
| One worker, 4096 MiB | 18/22 | 4.226 GiB | 136.85 s | 129.75 s | 4 |
| One worker, 8192 MiB | 22/22 | 8.073 GiB | 115.44 s | 109.79 s | 0 |

Peak memory is systemd's cgroup MemoryPeak, which includes the sample's
processes and charged cache. CPU time is cgroup CPUUsageNSec. GNU Time RSS
is retained separately in the artifact and is not the same measure.

At 4096 MiB, deck, desktop, macbook and mini exceeded the budget even on
isolated retries. The 18 successful paths matched the reference. This
incomplete run cannot demonstrate equivalent-work memory savings.

At 8192 MiB, three workers hit the budget while evaluating desktop, gym
and monitoring. The tool retried those attributes automatically, and all
22 hosts completed. There were no manual retries or final error rows.
Budget enforcement samples worker memory, so the observed peak can exceed
the nominal worker budget slightly.

## Exit status is insufficient

The 4096 MiB run exited zero despite four host error records. A CI wrapper
must reject error records, duplicate or unexpected hosts, missing hosts,
and missing derivation paths. It must require complete coverage of the
expected host set before producing a derivation diff or build matrix.

For the successful run, the raw JSON rows were checked independently:
22 rows, zero errors, no duplicates, exact host-set equality and exact
derivation-path equality. The normalized complete manifest hashes match.

## Method

All evaluations ran on builder from the same clean checkout and explicit
Git revision. The tested tree was
`b40c26554ca94f552d7288f2eb8bdddaa1809e60`.

The initial sequence was metadata, expected host names, a dns1 smoke
evaluation, the 4096 MiB whole-hive run and the plain-Nix reference. The
8192 MiB follow-up ran later, after a deployment had finished. Caches were
never cleared.

The evaluation payloads were:

```sh
trial_flake="git+file://$trial_checkout?rev=5d0135c44e1a79b4aab21db0b5c519a1f00f6fb6"

nix-eval-jobs --flake "$trial_flake#hydraJobs" \
  --workers 1 --max-memory-size 8192 \
  --option allow-import-from-derivation false \
  --option max-jobs 0 --option builders '' \
  --option substitute false --option fallback false \
  --option eval-cache false

nix eval "$trial_flake#hydraJobs" --json \
  --apply 'builtins.mapAttrs (_: value: value.drvPath)' \
  --no-write-lock-file \
  --option allow-import-from-derivation false \
  --option max-jobs 0 --option builders '' \
  --option substitute false --option fallback false \
  --option eval-cache false
```

These payloads ran inside a supervised transient service, not as bare
commands. The 4096 MiB trial used the same evaluator flags with that smaller
budget. No import-from-derivation errors occurred and no builds ran.

Each sample acquired the existing CI evaluation lock and required quiet
runner and daemon activity. Both evaluator modes had a two-CPU quota.
The cgroup caps were 8 GiB for the first worker trial, 12 GiB for the
follow-up and 20 GiB for the plain reference. These were backstops above
the evaluator's own budget, with separate runtime limits.

A supervisor outside the sample cgroup checked builder and PVE headroom,
memory pressure and competing work, and could terminate the sample. It
required at least 28 GiB available on builder and 40 GiB on PVE before
starting. Abort thresholds were 16 GiB and 32 GiB respectively, with
additional pressure and near-cap checks. The Nix daemon was monitored
separately because the client cgroup did not contain it.

The minimum available memory across the whole trial was 35.32 GiB on
builder and 73.16 GiB on PVE. Memory-pressure averages stayed zero,
daemon CPU did not increase, and no sample cgroup reported an OOM event.
The transient units and sample processes were removed and the lock
released. No packages, service settings, builds or deployments were changed
by the trial.

## Limits of the comparison

- nix-eval-jobs 2.35.4 linked against Nix 2.35.3, while the plain reference
  used Nix 2.34.9. A matching CLI was not already available; no package was
  installed to obtain one. Some of the measured difference may come from
  evaluator versions or their configuration.
- These are single samples at different times, with warm source, store and
  filesystem caches. The Nix evaluation cache was explicitly disabled.
- The plain reference experienced CPU throttling under the shared two-CPU
  quota; the successful worker trial showed none in the monitoring samples.
  The shorter wall time is provisional, not a promised CI speedup.
- The test covers one revision and one evaluation at a time. It does not
  establish safe concurrency with builds, a safe base/head pairing, or the
  budget needed as hosts grow. An individual host can still exceed a worker
  budget.
- No persistent GC roots were added for the trial's emitted derivations.
  Their names in the artifact do not guarantee continued store retention.

## Evidence retained

Raw manifests, stderr, commands, monitoring records and the supervisor are
in these scratch directories, copied locally and retained on builder:

- `/tmp/caboodle-eval-trial-20261028-0702/`
- `/tmp/caboodle-eval-followup-20261028-0717/`

The committed measurement artifact is the durable summary; scratch files
may be cleaned up. Production CI still uses the existing evaluator and
lock. This trial does not select the rest of the CI architecture.
