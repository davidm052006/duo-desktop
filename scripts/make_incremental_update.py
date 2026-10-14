#!/usr/bin/env python3
"""Build a verified, per-file incremental ZIP from two full launcher ZIPs.

Each archive has app/, service/ (and optionally launcher/) at its root.
The incremental archive includes changed files and an index for the complete
target tree. The updater never trusts a reused file without checking its SHA256.
"""
import argparse
import hashlib
import json
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def entries(archive):
    return {
        entry.filename: archive.read(entry)
        for entry in archive.infolist()
        if not entry.is_dir()
    }


def create(previous, current, destination, base_version):
    with zipfile.ZipFile(previous) as old_zip, zipfile.ZipFile(current) as new_zip:
        old, new = entries(old_zip), entries(new_zip)
    if not {"app/", "service/"} <= {
        name.split("/", 1)[0] + "/" for name in new
    }:
        raise ValueError("Full update is missing app/ or service/")
    expected = {path: digest(data) for path, data in new.items()}
    reused = {path: expected[path] for path, data in new.items()
              if old.get(path) == data}
    changed = {path: data for path, data in new.items()
               if path not in reused}
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as out:
        for name, data in changed.items():
            out.writestr(name, data)
        out.writestr("delta-index.json", json.dumps({
            "baseVersion": base_version,
            "files": expected,
            "reused": reused,
        }, sort_keys=True))
    return len(changed), len(reused)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("previous")
    parser.add_argument("current")
    parser.add_argument("output")
    parser.add_argument("base_version")
    args = parser.parse_args()
    changed, reused = create(args.previous, args.current, args.output, args.base_version)
    print(f"Incremental files: changed={changed}, reused={reused}")
