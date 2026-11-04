#!/usr/bin/env python3
"""merge-config.py CONFIG OVERLAY: deep-merge OVERLAY into CONFIG in place.

Every key in the overlay must already exist in the config with the same kind
of value, so a setting renamed or removed upstream fails the build instead of
being silently ignored.
"""

import json
import sys


def merge(base, overlay, path=""):
    for key, value in overlay.items():
        where = f"{path}.{key}" if path else key
        if key not in base:
            sys.exit(f"error: overlay key {where} does not exist in upstream config.json")
        if isinstance(value, dict):
            if not isinstance(base[key], dict):
                sys.exit(f"error: overlay key {where} is an object, upstream is not")
            merge(base[key], value, where)
        else:
            if isinstance(base[key], dict):
                sys.exit(f"error: overlay key {where} is a value, upstream is an object")
            base[key] = value


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    config_path, overlay_path = sys.argv[1:]
    with open(config_path) as f:
        config = json.load(f)
    with open(overlay_path) as f:
        overlay = json.load(f)
    merge(config, overlay)
    with open(config_path, "w") as f:
        json.dump(config, f, indent=4)
        f.write("\n")


if __name__ == "__main__":
    main()
