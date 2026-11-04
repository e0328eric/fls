#!/usr/bin/env bash
# Drives the browser through --snapshot/--keys and checks what it draws and
# what it does to the file system. usage: tests/tui_test.sh
set -u
F="$(cd "$(dirname "$0")/.." && pwd)/build/fls"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
expect() { # expect NAME KEYS PATTERN  -- the snapshot must contain PATTERN
    out=$(cd "$T" && "$F" --snapshot --no-icons -w 100 --keys "$2" . 2>&1)
    if grep -qF -- "$3" <<<"$out"; then ok; else bad "$1: no '$3' in"; echo "$out" | head -8; fi
}

mkdir -p "$T/alpha/sub" "$T/beta" "$T/.hidden"
printf 'line one\n\tindented\n' > "$T/alpha/notes.txt"
printf '\x00\x01binary' > "$T/alpha/blob.bin"
echo data > "$T/alpha/sub/deep.txt"

expect "lists directories first" "" "alpha/"
expect "hides dotfiles" "." ".hidden/"
expect "enters a directory" "l" "alpha"
expect "previews text with line numbers" "ljj" "1 line one"
expect "expands tabs in previews" "ljj" "2     indented"
expect "detects binary files" "lj" "binary data"
expect "filters as you type" "l/note" "1 match"
expect "opens a single filter match" "/bet<Enter>" "empty directory"
expect "shows details" "ld" ".rw-r--r--"
expect "opens help" "?" "SELECTION AND FILES"
expect "opens the sort menu" "t" "sort by"
expect "shows file info" "li" "inode"
expect "a new context starts in the current directory" "l2h" "alpha/"
expect "status shows position" "" " 1/2 "

# Copy, rename, create, move and delete.
(cd "$T" && "$F" --snapshot -w 100 --keys "ljj<Space>hjlp" . >/dev/null)
[ -f "$T/beta/notes.txt" ] && ok || bad "copy into beta"
(cd "$T" && "$F" --snapshot -w 100 --keys "jlr<C-u><End><C-u>renamed.txt<Enter>" . >/dev/null)
[ -f "$T/beta/renamed.txt" ] && ok || bad "rename"
(cd "$T" && "$F" --snapshot -w 100 --keys "jlnnewdir/<Enter>nnew.md<Enter>" . >/dev/null)
[ -d "$T/beta/newdir" ] && [ -f "$T/beta/new.md" ] && ok || bad "create"
(cd "$T" && "$F" --snapshot -w 100 --keys "jlG<Space>hklv" . >/dev/null)
[ -f "$T/alpha/renamed.txt" ] && [ ! -e "$T/beta/renamed.txt" ] && ok || bad "move"
(cd "$T" && "$F" --snapshot -w 100 --keys "jljxn" . >/dev/null)
[ -f "$T/beta/new.md" ] && ok || bad "delete can be cancelled"
(cd "$T" && "$F" --snapshot -w 100 --keys "jljxy" . >/dev/null)
[ ! -e "$T/beta/new.md" ] && ok || bad "delete"

echo "tui: passed $pass, failed $fail"
[ "$fail" -eq 0 ]
