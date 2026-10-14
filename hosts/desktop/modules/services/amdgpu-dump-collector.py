"""Copy an AMDGPU devcoredump to persistent storage without touching GPU state."""

import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def capture(device, destination):
    """Return the saved directory, or None for a non-AMDGPU device."""
    if not re.fullmatch(r"devcd[0-9]+", device.name):
        raise ValueError(f"Invalid devcoredump name: {device.name}")
    driver = (device / "failing_device" / "driver").resolve(strict=True)
    if driver.name != "amdgpu":
        print(f"Ignoring {device.name}: driver {driver.name}", flush=True)
        return None

    destination.mkdir(mode=0o750, parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    saved = Path(tempfile.mkdtemp(prefix=f"{stamp}-{device.name}-", dir=destination))
    saved.chmod(0o750)
    sync_directory(destination)

    # sysfs can report a zero file size for a nonempty dump. Stream to EOF,
    # then fsync before naming it complete. Never write to sysfs to release it.
    partial = saved / "amdgpu-devcoredump.partial"
    with (device / "data").open("rb") as source, partial.open("xb") as target:
        shutil.copyfileobj(source, target, length=1024 * 1024)
        target.flush()
        os.fsync(target.fileno())
        if target.tell() == 0:
            raise OSError(f"Empty device dump; retained {partial}")
    partial.rename(saved / "amdgpu-devcoredump.data")
    sync_directory(saved)
    print(f"Saved GPU dump: {saved}", flush=True)

    metadata = {
        "captured_at_utc": stamp,
        "device": str(device),
        "failing_device": str((device / "failing_device").resolve()),
        "kernel": os.uname().release,
        "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
        "system_generation": str(Path("/run/current-system").resolve()),
    }
    with (saved / "metadata.json").open("x") as target:
        json.dump(metadata, target, indent=2)
        target.write("\n")
        target.flush()
        os.fsync(target.fileno())
    sync_directory(saved)
    return saved


def capture_journal(saved, delay):
    # The dump is already durable. Allow time for reset/compositor fallout.
    time.sleep(delay)
    with (saved / "kernel.log").open("xb") as target:
        try:
            result = subprocess.run(
                ["journalctl", "--dmesg", "--boot", "--since", "5 minutes ago",
                 "--no-pager", "--output=short-iso-precise"],
                stdout=target, stderr=subprocess.STDOUT, timeout=15, check=False,
            )
            if result.returncode:
                print(f"Journal capture failed ({result.returncode}); GPU dump is saved", file=sys.stderr)
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"Journal capture failed; GPU dump is saved: {error}", file=sys.stderr)
        finally:
            target.flush()
            os.fsync(target.fileno())
    sync_directory(saved)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--journal-delay", type=float, default=10)
    args = parser.parse_args()
    if not 0 <= args.journal_delay <= 30:
        parser.error("journal delay must be between 0 and 30 seconds")
    os.umask(0o027)
    try:
        saved = capture(args.device, args.destination)
        if saved is not None:
            capture_journal(saved, args.journal_delay)
    except (OSError, ValueError) as error:
        print(f"GPU dump collection failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
