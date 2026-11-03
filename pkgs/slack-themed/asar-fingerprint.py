"""Check or update the fingerprint a macOS Electron app keeps of its app.asar.

The fingerprint is the SHA-256 of the asar's JSON header, stored in Info.plist
and compared at launch by the EnableEmbeddedAsarIntegrityValidation fuse.
"""

import hashlib
import plistlib
import struct
import sys
from pathlib import Path

ENTRY = "Resources/app.asar"


def header_hash(asar: Path) -> str:
    with asar.open("rb") as file:
        prefix = file.read(16)
        size = struct.unpack("<I", prefix[12:16])[0]
        return hashlib.sha256(file.read(size)).hexdigest()


def main() -> int:
    action, app = sys.argv[1], Path(sys.argv[2])
    plist_path = app / "Contents/Info.plist"
    plist = plistlib.loads(plist_path.read_bytes())
    integrity = plist["ElectronAsarIntegrity"][ENTRY]
    actual = header_hash(app / "Contents" / ENTRY)

    if action == "check":
        if integrity["algorithm"] != "SHA256" or integrity["hash"] != actual:
            print(f"{ENTRY}: fingerprint scheme changed: {integrity}", file=sys.stderr)
            return 1
        return 0

    integrity["hash"] = actual
    plist_path.write_bytes(plistlib.dumps(plist))
    return 0


if __name__ == "__main__":
    sys.exit(main())
