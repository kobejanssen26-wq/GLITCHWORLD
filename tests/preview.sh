#!/bin/sh
# Renders PNG previews (target sheet, Echo sheet, valley map) from the mock world build, since there is no Studio:
#   LUAU=... DEFS=... tests/preview.sh <output-dir>        (needs python3 + Pillow)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:?output dir}
mkdir -p "$OUT"
"$HERE/smoke.sh" dump > "$OUT/dump.txt"
python3 "$HERE/harness/preview.py" "$OUT" < "$OUT/dump.txt"
rm -f "$OUT/dump.txt"
