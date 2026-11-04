#!/usr/bin/env bash
# Runs every fls test: unit tests, the TUI script and (when eza is installed)
# the eza comparison on this repository and a few system directories.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GLOSSO="${GLOSSO:-glosso}"
status=0
"$GLOSSO" --run -o "$ROOT/build/unit_test" "$ROOT/tests/unit_test.glo" 2>&1 | grep -v '^glosso:' || status=1
"$ROOT/tests/tui_test.sh" || status=1
if command -v eza >/dev/null; then
    "$ROOT/tests/compare_kinds.sh" || status=1
    for dir in "$ROOT" "$ROOT/src" /etc; do
        result=$("$ROOT/tests/compare_eza.sh" "$dir" 2>&1)
        echo "eza $dir: $(tail -1 <<<"$result")"
        grep -q 'failed 0' <<<"$result" || { status=1; echo "$result" | head -20; }
    done
fi
exit $status
