#!/bin/sh
# Regenerates world/World.rbxm (the baked map: tower, hub, plots, sky) from tools/bake/*.luau.
#   LUAU=/path/to/luau DEFS=/path/to/globalTypes.d.luau ROJO=/path/to/rojo tools/bake.sh
# The baker runs inside the mock runtime only for CFrame/Vector3 math; it records plain tables and writes XML.
set -e
LUAU=${LUAU:-luau}
ROJO=${ROJO:-rojo}
: "${DEFS:?set DEFS to globalTypes.d.luau}"
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT="$HERE/.."
TMP=$(mktemp -d)
python3 "$ROOT/tests/harness/gen_api.py" "$DEFS" "$TMP/api_db.luau" >/dev/null
cp "$ROOT/tests/harness/mock.luau" "$TMP/mock.luau"
python3 "$ROOT/tests/harness/prepare.py" "$ROOT/src" "$ROOT/tests/harness" "$TMP"
( cd "$TMP" && "$LUAU" bake_main.luau > out.txt )
grep '^#' "$TMP/out.txt" || true
grep -v '^#' "$TMP/out.txt" > "$TMP/World.rbxmx"
echo '{"name":"World","tree":{"$path":"World.rbxmx"}}' > "$TMP/world.project.json"
( cd "$TMP" && "$ROJO" build world.project.json -o World.rbxm )
cp "$TMP/World.rbxm" "$ROOT/world/World.rbxm"
ls -la "$TMP/World.rbxmx" "$ROOT/world/World.rbxm"
[ -n "$KEEP_XML" ] && cp "$TMP/World.rbxmx" "$KEEP_XML"
rm -rf "$TMP"
