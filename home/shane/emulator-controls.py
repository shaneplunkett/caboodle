"""Set an emulator's [Controls] keys in its Qt config, leaving every other line alone."""

import json
import sys
from pathlib import Path


def set_controls(path: Path, controls: dict[str, str]) -> None:
    lines = path.read_text().splitlines() if path.exists() else []
    if "[Controls]" not in lines:
        lines += ["[Controls]"]
    start = lines.index("[Controls]") + 1
    end = next(
        (i for i in range(start, len(lines)) if lines[i].startswith("[")),
        len(lines),
    )
    managed = {name for key in controls for name in (key, f"{key}\\default")}
    kept = [line for line in lines[start:end] if line.split("=", 1)[0] not in managed]
    added = [
        line
        for key, value in controls.items()
        for line in (f"{key}\\default=false", f"{key}={value}")
    ]
    lines[start:end] = added + kept
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    set_controls(Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text()))
