# Automatic AMDGPU crash dump collection

The desktop captures AMDGPU device dumps automatically, independently of the
graphical session. It does not change Proton, Mesa, GPU clocks, kernel driver
parameters, or GPU recovery behaviour. Nothing is uploaded.

## Where to find captures

Each event gets a unique directory under `/var/lib/amdgpu-crash-dumps/`:

- `amdgpu-devcoredump.data`: completed dump, flushed to disk before other work.
- `amdgpu-devcoredump.partial`: incomplete or empty capture, never labelled complete.
- `metadata.json`: capture time, boot ID, kernel, Nix generation and device path.
- `kernel.log`: recent kernel messages, collected after ten seconds to include recovery.

The directory is created on the first capture. Root owns the files; the `users`
group can read them, but cannot modify them. Other users have no access. Captures
are not automatically deleted. Review logs before sharing them publicly.

Proton logs are separate. Steam's per-game launch option
`PROTON_LOG=1 %command%` writes V Rising's log to `~/steam-1604030.log` by default.
The privileged collector deliberately does not follow paths in a user's home.

## Trigger and status

A udev rule starts `amdgpu-dump@devcdN.service` on the kernel's `devcoredump`
device-add event. The collector checks `failing_device/driver` and ignores
non-AMDGPU dumps. It streams sysfs data rather than trusting its reported size.
It does not clear the kernel dump or write to sysfs.

This is event-driven, not a continuously running daemon. An inactive template
with no instances is normal until a dump appears. No manual enable is needed.

```sh
systemctl cat amdgpu-dump@.service
journalctl -b -u 'amdgpu-dump@*' --no-pager
ls -l /var/lib/amdgpu-crash-dumps/
```

The system must remain capable of scheduling the service and writing to disk.
A full kernel lockup, immediate reboot, power loss or disk failure can still
prevent capture. The original sysfs dump expires after about five minutes by
default and does not survive reboot. A saved, flushed copy does survive reboot.

## Verification and changes

The collector lives in `hosts/desktop/modules/services/amdgpu-dump-collector.nix`
with its Python source and fixture tests beside it. The tests exercise the
packaged CLI with binary data, permissions, invalid devices, other drivers,
empty/failed reads, repeated captures and journal failure. Desktop builds
depend on the tests, so a failing test blocks deployment.

```sh
nix build .#nixosConfigurations.desktop.config.system.build.amdgpuDumpCollectorTest --no-link
statix check .
deadnix hosts/desktop/modules/services/amdgpu-dump-collector.nix
nh os build . -H desktop
nix flake check
```

Fixture tests do not trigger a real GPU reset or prove that Linux will remain
responsive during a future crash. The first genuine capture remains the
end-to-end hardware verification.

To remove the collector, remove its import from the desktop services module and
rebuild through the normal `nh os switch . -H desktop` path. Saved captures
remain on disk.

## Sources checked during implementation

- [Kernel devcoredump implementation](https://github.com/torvalds/linux/blob/v6.18/drivers/base/devcoredump.c): the ADD event follows creation of the data and device links.
- [Kernel dump timeout](https://github.com/torvalds/linux/blob/v6.18/include/linux/devcoredump.h): default expiry.
- Local `systemd.device(5)`, systemd 261.1: `TAG+="systemd"` and `SYSTEMD_WANTS` activate a service when its device appears.
- [Valve Proton runtime options](https://github.com/ValveSoftware/Proton#runtime-config-options): per-game logging.
