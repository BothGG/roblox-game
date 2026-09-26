#!/usr/bin/env python3
"""
Test runner for pure game logic (no Roblox Studio needed).

It packs src/ and tests/specs/ into one Luau file that fakes a tiny part of
Roblox (instances, require, Color3, Enum, an in-memory DataStore), then runs
it with the `luau` command line tool.

Usage:  python3 tests/run.py            (luau must be on PATH, or set LUAU=path)
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = os.environ.get("LUAU", "luau")

# Where each folder lives in the fake game tree (mirrors default.project.json).
MOUNTS = [
    ("src/shared", ["ReplicatedStorage", "Shared"]),
    ("src/server", ["ServerScriptService", "Server"]),
    ("tests/specs", ["ServerScriptService", "Specs"]),
]


def module_name(filename):
    """Rojo naming: foo.lua -> (foo, ModuleScript), foo.server.lua -> Script."""
    for suffix, cls in ((".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript"), (".luau", "ModuleScript")):
        if filename.endswith(suffix):
            return filename[: -len(suffix)], cls
    return None, None


def collect(directory, path):
    """Returns a list of (instance path list, class, source or None)."""
    entries = []
    init = None
    for name in ("init.lua", "init.luau"):
        if os.path.exists(os.path.join(directory, name)):
            init = os.path.join(directory, name)
    entries.append((path, "ModuleScript" if init else "Folder", open(init).read() if init else None))
    for filename in sorted(os.listdir(directory)):
        full = os.path.join(directory, filename)
        if os.path.isdir(full):
            entries.extend(collect(full, path + [filename]))
        elif filename not in ("init.lua", "init.luau"):
            name, cls = module_name(filename)
            if name:
                entries.append((path + [name], cls, open(full).read()))
    return entries


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


def main():
    entries = []
    for folder, path in MOUNTS:
        full = os.path.join(ROOT, folder)
        if os.path.isdir(full):
            entries.extend(collect(full, path))
    lines = ["local __ENTRIES = {"]
    for path, cls, source in entries:
        path_lua = "{" + ", ".join('"%s"' % p for p in path) + "}"
        src = long_string(source) if source is not None else "nil"
        lines.append("\t{ Path = %s, Class = \"%s\", Source = %s }," % (path_lua, cls, src))
    lines.append("}")
    harness = open(os.path.join(ROOT, "tests", "harness.luau")).read()
    bundle = "\n".join(lines) + "\n" + harness
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write(bundle)
        bundle_path = f.name
    try:
        result = subprocess.run([LUAU, bundle_path])
    finally:
        os.unlink(bundle_path)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
