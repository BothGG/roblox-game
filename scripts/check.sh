#!/usr/bin/env bash
# Runs every check CI runs. Usage: scripts/check.sh
# Needs on PATH (or set env vars): rojo, luau-lsp, luau, stylua, python3.
# Roblox type definitions: set DEFS=path/to/globalTypes.d.luau (downloaded if missing).
set -euo pipefail
cd "$(dirname "$0")/.."

ROJO=${ROJO:-rojo}
LUAU_LSP=${LUAU_LSP:-luau-lsp}
STYLUA=${STYLUA:-stylua}
export LUAU=${LUAU:-luau}
DEFS=${DEFS:-globalTypes.d.luau}

if [ ! -f "$DEFS" ]; then
	curl -sSL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.RobloxScriptSecurity.d.luau
fi

echo "== format"
"$STYLUA" --check src tests

echo "== build"
mkdir -p build
"$ROJO" build default.project.json -o build/KaijuKeepers.rbxlx

echo "== type check"
"$ROJO" sourcemap default.project.json -o sourcemap.json
OUTPUT=$("$LUAU_LSP" analyze --definitions="$DEFS" --sourcemap=sourcemap.json src 2>&1 | grep -v '^\[' || true)
if [ -n "$OUTPUT" ]; then
	echo "$OUTPUT"
	echo "type check failed"
	exit 1
fi

echo "== tests"
python3 tests/run.py

echo "All checks passed."
