#!/usr/bin/env python3
"""Tiny read-only accessor for packages/<pkg>.toml manifests.

Used by the shell scripts so we never hand-parse TOML in bash. Relies only on
the standard library (tomllib, Python >= 3.11 — always present on Arch, and
pulled in by namcap/nvchecker inside the CI container).

Subcommands:
  get FILE KEY            print data[KEY] (dotted keys allowed), error if missing
  get-or FILE KEY DEFAULT print data[KEY] or DEFAULT if missing
  has-nvchecker FILE      print "true"/"false"
  nvchecker-toml FILE     print a self-contained nvchecker config: one [<name>]
                          section built from the manifest's [nvchecker] table
"""
import sys
import tomllib


def load(path):
    with open(path, "rb") as fh:
        return tomllib.load(fh)


def dig(data, dotted):
    cur = data
    for part in dotted.split("."):
        cur = cur[part]
    return cur


def toml_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        return "[" + ", ".join(toml_value(x) for x in v) + "]"
    s = str(v)
    # Prefer a TOML *literal* string (single quotes, no escaping) so regexes with
    # backslashes survive verbatim. Fall back to a basic string when needed.
    if "'" not in s and "\n" not in s:
        return "'" + s + "'"
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main(argv):
    cmd = argv[1]
    path = argv[2]
    data = load(path)

    if cmd == "get":
        print(dig(data, argv[3]))
    elif cmd == "get-or":
        try:
            print(dig(data, argv[3]))
        except (KeyError, TypeError):
            print(argv[4])
    elif cmd == "has-nvchecker":
        print("true" if isinstance(data.get("nvchecker"), dict) else "false")
    elif cmd == "nvchecker-toml":
        name = data["name"]
        nv = data.get("nvchecker", {})
        if not isinstance(nv, dict) or not nv:
            sys.exit(f"manifest {path} has no [nvchecker] table")
        print(f"[{name}]")
        for k, v in nv.items():
            print(f"{k} = {toml_value(v)}")
    else:
        sys.exit(f"unknown subcommand: {cmd}")


if __name__ == "__main__":
    main(sys.argv)
