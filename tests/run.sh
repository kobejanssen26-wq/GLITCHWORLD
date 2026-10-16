#!/bin/sh
# Pure-Luau unit tests + economy simulation (no Roblox needed). LUAU=/path/to/luau tests/run.sh
set -e
LUAU=${LUAU:-luau}
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
mkdir -p "$TMP/shared"
for f in "$HERE"/../src/shared/*.luau; do
  sed -E 's#require\(script\.Parent\.([A-Za-z]+)\)#require("./\1")#g' "$f" > "$TMP/shared/$(basename "$f")"
done
cp "$HERE"/*_test.luau "$TMP/"
cd "$TMP"
STATUS=0
for t in *_test.luau; do echo "== $t"; "$LUAU" "$t" || STATUS=1; done
rm -rf "$TMP"
exit $STATUS
