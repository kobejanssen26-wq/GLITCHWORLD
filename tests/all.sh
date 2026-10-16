#!/bin/sh
# Everything that runs without Roblox Studio:
#   LUAU=/path/to/luau LSP=/path/to/luau-lsp DEFS=/path/to/globalTypes.d.luau tests/all.sh
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
echo "### type-check + lint (luau-lsp against the Roblox API definitions)"
OUT=$("$HERE/../tools/check.sh")
[ -z "$OUT" ] && echo "clean" || { echo "$OUT"; exit 1; }
echo "### pure logic: rules + economy simulation"
"$HERE/run.sh"
echo "### mock-Roblox integration: tower geometry, server, client, layout"
"$HERE/smoke.sh"
