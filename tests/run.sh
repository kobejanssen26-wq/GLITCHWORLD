#!/bin/sh
# Runs the pure-Luau unit tests + economy simulation (no Roblox needed). Needs the `luau` CLI: LUAU=/path/to/luau.
# Shared modules use Roblox-style requires (script.Parent.X); they are rewritten to relative requires in a temp dir.
set -e
LUAU=${LUAU:-luau}
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
mkdir -p "$TMP/shared"
for f in "$HERE"/../src/shared/*.luau; do
  case "$(basename "$f")" in Remotes.luau|EchoModel.luau) continue;; esac  # Roblox-instance modules
  { echo 'local Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }'; sed -E 's#require\(script\.Parent\.([A-Za-z]+)\)#require("./\1")#g' "$f"; } > "$TMP/shared/$(basename "$f")"
done
cp "$HERE"/*_test.luau "$TMP/" 2>/dev/null || true
cd "$TMP"
STATUS=0
for t in *_test.luau; do echo "== $t"; "$LUAU" "$t" || STATUS=1; done
rm -rf "$TMP"
exit $STATUS
