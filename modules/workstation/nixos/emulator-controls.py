"""Set keys in one section of an emulator's ini file, leaving every other line alone.

Usage: emulator-controls.py <ini> <section> <values.json> [--qt]

--qt also marks each key as changed from its default, as Qt's settings files do.
"""

import json
import sys
from pathlib import Path


def set_keys(path: Path, section: str, values: dict[str, str], qt: bool) -> None:
    lines = path.read_text(encoding="utf-8-sig").splitlines() if path.exists() else []
    header = f"[{section}]"
    if header not in (line.strip() for line in lines):
        lines += [header]
    start = next(i for i, line in enumerate(lines) if line.strip() == header) + 1
    end = next(
        (i for i in range(start, len(lines)) if lines[i].lstrip().startswith("[")),
        len(lines),
    )
    managed = set(values) | {f"{key}\\default" for key in values}
    kept = [line for line in lines[start:end] if line.split("=", 1)[0].strip() not in managed]
    added = [
        line
        for key, value in values.items()
        for line in ([f"{key}\\default=false"] if qt else []) + [f"{key}={value}"]
    ]
    lines[start:end] = added + kept
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    ini, section, values = sys.argv[1:4]
    set_keys(
        Path(ini),
        section,
        json.loads(Path(values).read_text()),
        qt="--qt" in sys.argv[4:],
    )
