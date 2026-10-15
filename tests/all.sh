#!/bin/sh
# Everything that can run without Roblox Studio:
#   LUAU=/path/to/luau LSP=/path/to/luau-lsp DEFS=/path/to/globalTypes.d.luau tests/all.sh
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
echo "### type-check + lint (luau-lsp against Roblox API definitions)"
OUT=$("$HERE/../tools/check.sh")
[ -z "$OUT" ] && echo "clean" || { echo "$OUT"; exit 1; }
echo "### pure logic: config / rules / economy simulation"
"$HERE/run.sh"
echo "### mock-Roblox integration: world build, server, client, layout"
"$HERE/smoke.sh"
