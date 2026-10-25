#!/usr/bin/env python3
"""Check fixture integrity and the documented C++ source snapshot without building."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

CORE_COMMIT = "60aa253c074e69922084a66fea67a73aa2c93531"
ROOT = Path(__file__).resolve().parents[1]


def verify_fixtures():
    folder = ROOT / "Tests/QyooDetectorTests/Fixtures"
    manifest = json.loads((folder / "manifest.json").read_text())
    if manifest["core_commit"] != CORE_COMMIT:
        raise ValueError("Fixture core commit differs from documented snapshot")
    for fixture in manifest["fixtures"]:
        path = folder / fixture["file"]
        if path.parent != folder:
            raise ValueError("Fixture path must stay in the fixture directory")
        data = path.read_bytes()
        if path.suffix.lower() in (".jpg", ".jpeg") and b"Exif\0\0" in data:
            raise ValueError(f"Unreviewed EXIF metadata in fixture: {path.name}")
        actual = hashlib.sha256(data).hexdigest()
        if actual != fixture["sha256"]:
            raise ValueError(f"Fixture digest differs: {path.name}")
        payload = fixture["expected_payload"]
        if payload is not None and (type(payload) is not int or not 0 <= payload < 2**36):
            raise ValueError(f"Invalid expected payload: {path.name}")
    print(f"PASS: {len(manifest['fixtures'])} fixture hashes and payload ranges")


def verify_core(cpp):
    vendored = ROOT / "Sources/CQyooDetectorCore"
    count = 0
    for local_dir, upstream_dir in [("core", "src"), ("include", "include"), ("cml", "cml")]:
        for local in sorted((vendored / local_dir).rglob("*")):
            if not local.is_file():
                continue
            upstream_path = upstream_dir + "/" + local.relative_to(vendored / local_dir).as_posix()
            expected = subprocess.check_output([
                "git", "-C", str(cpp), "show", f"{CORE_COMMIT}:{upstream_path}"
            ])
            actual = local.read_bytes()
            if local_dir == "core" and local.name == "QyooModel.cpp":
                actual = actual.replace(
                    b'#if defined(__clang__)\n#pragma clang diagnostic push\n#pragma clang diagnostic ignored "-Wshorten-64-to-32"\n#endif\n\n', b''
                ).replace(b'\n#if defined(__clang__)\n#pragma clang diagnostic pop\n#endif\n', b'')
            if actual != expected:
                raise ValueError(f"Vendored source differs: {local.relative_to(vendored)}")
            count += 1
    print(f"PASS: {count} vendored files match {CORE_COMMIT} (documented diagnostic scopes excepted)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpp", type=Path, help="Local C++ repository containing the documented commit")
    args = parser.parse_args()
    verify_fixtures()
    if args.cpp is not None:
        verify_core(args.cpp)
