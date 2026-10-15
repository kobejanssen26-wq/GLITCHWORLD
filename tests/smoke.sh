#!/bin/sh
# Runs the mock-Roblox smoke/integration tests (tests/harness/*_test.luau) in the plain Luau CLI.
#   LUAU=/path/to/luau DEFS=/path/to/globalTypes.d.luau tests/smoke.sh [test-name-filter]
# DEFS is luau-lsp's globalTypes.d.luau; it is turned into a class-member table so the mock rejects unknown
# property names / methods. See tests/harness/mock.luau for what is (and is not) simulated.
set -e
LUAU=${LUAU:-luau}
: "${DEFS:?set DEFS to globalTypes.d.luau}"
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
python3 "$HERE/harness/gen_api.py" "$DEFS" "$TMP/api_db.luau" >/dev/null
cp "$HERE/harness/mock.luau" "$TMP/mock.luau"
python3 "$HERE/harness/prepare.py" "$HERE/../src" "$HERE/harness" "$TMP"
cd "$TMP"
STATUS=0
for t in *_test.luau; do
  case "$t" in dump_test.luau) [ "$1" = dump ] || continue;; esac # geometry dump only on request (see tests/preview.sh)
  case "$t" in *"$1"*) ;; *) continue;; esac
  echo "== $t"; "$LUAU" "$t" || STATUS=1
done
rm -rf "$TMP"
exit $STATUS
