"""Swap Claude Code's house writing rules for a pointer at the persona.

Every replacement keeps the original byte length, padded with spaces, so the
Bun executable's embedded offsets stay valid and nothing needs relinking.
"""

import re
import sys
from pathlib import Path
from typing import NoReturn

BLOCK = re.compile(rb"`(# Writing for the user\n[^`]*)`")
BLOCK_NEW = (
    b"# Writing for the user\n"
    b"Talk to the user the way the persona in CLAUDE.md talks; "
    b"her voice and shape win here. No em-dashes."
)

RECAP = re.compile(
    rb"Before you start, say in a line what you're about to do;"
    rb".*?has the full picture\.",
    re.DOTALL,
)
RECAP_NEW = b"Match the persona in CLAUDE.md for how to open and close a message."

MUST_BE_GONE = [b"about 20 words, with a verb", b"Close with a short recap"]


def fail(message: str) -> NoReturn:
    sys.exit(f"claude-code prompts: {message}")


def swap(data: bytes, old: bytes, new: bytes, what: str) -> bytes:
    if len(new) > len(old):
        fail(f"{what}: replacement is {len(new) - len(old)} bytes too long")
    count = data.count(old)
    if count == 0:
        fail(f"{what}: not found")
    print(f"claude-code prompts: {what}: {count} copies of {len(old)} bytes")
    return data.replace(old, new.ljust(len(old)))


def main(path: Path) -> None:
    data = path.read_bytes()
    block = BLOCK.search(data)
    if block is None:
        fail("writing block: template literal not found")
    data = swap(data, block.group(1), BLOCK_NEW, "writing block")
    recap = RECAP.search(data)
    if recap is None:
        fail("recap sentence: not found")
    data = swap(data, recap.group(0), RECAP_NEW, "recap sentence")
    for phrase in MUST_BE_GONE:
        if phrase in data:
            fail(f"{phrase!r} survived the swap")
    path.write_bytes(data)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
