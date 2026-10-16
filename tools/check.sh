#!/bin/sh
# Type-check + lint all Luau sources against the real Roblox API definitions using luau-lsp (no Studio needed).
#   LSP=/path/to/luau-lsp DEFS=/path/to/globalTypes.d.luau tools/check.sh
# DEFS: https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
# Generates a throwaway sourcemap.json (Rojo's `rojo sourcemap default.project.json -o sourcemap.json` works too).
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LSP=${LSP:-luau-lsp}
cd "$ROOT"
python3 tools/mksourcemap.py .
"$LSP" analyze --platform=roblox --definitions="$DEFS" --sourcemap=sourcemap.json src tools/bake 2>&1 | grep -v '^\[INFO\]\|^\[WARN\]' | sort -u
