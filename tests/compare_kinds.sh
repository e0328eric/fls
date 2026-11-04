#!/usr/bin/env bash
# Compares fls against eza for every file kind under fixed LS_COLORS and
# EZA_COLORS values, so color-key handling (file kinds, the type letter of the
# permissions column, broken links, read errors, GNU-only keys that eza reads
# as file names, and EZA_COLORS=reset) is checked whatever the caller's
# environment holds.
# usage: tests/compare_kinds.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
F="$ROOT/build/fls"
N="python3 $ROOT/tests/sgr_normalize.py"
FIXTURE="$(mktemp -d)"
trap 'chmod 700 "$FIXTURE/locked" 2>/dev/null; rm -rf "$FIXTURE"' EXIT
cd "$FIXTURE" || exit 1
echo text > file
echo text > exe && chmod +x exe
echo text > setuid && chmod 4755 setuid
echo text > setuid_noexec && chmod 4644 setuid_noexec
echo text > setgid && chmod 2755 setgid
mkdir specialdir && chmod 3777 specialdir
mkdir dir sticky otherw locked
chmod 1777 sticky
chmod 777 otherw
ln -s file link
ln -s dir dirlink
ln -s nowhere broken
ln -s /dev/null chardev
mkfifo fifo
# A relative name keeps the socket path under the AF_UNIX length limit.
python3 -I -c 'import socket; socket.socket(socket.AF_UNIX).bind("sock")'
# Named like GNU-only LS_COLORS keys, which eza matches as file names.
for name in su sg tw ow st mi; do echo text > "$name"; done
# File categories, for EZA_COLORS=reset.
touch a.png main.rs Makefile x.zip x.tmp x.c x.o
# Fixed, distinct old times keep relative times and time sorts stable.
when=1577934000
for entry in *; do
    touch -h -d "@$when" "$entry"
    when=$((when + 60))
done
touch -d "@$when" .
chmod 000 locked
# Device nodes cannot be created without root; use the system's.
DEVICES=(/dev/null)
block="$(find /dev -maxdepth 1 -type b 2>/dev/null | head -1)"
[ -n "$block" ] && DEVICES+=("$block")

status=0
check() {
    # $1 describes the colors; the rest is the environment to run under.
    local name="$1"; shift
    result=$(env -u LS_COLORS -u EZA_COLORS -u EXA_COLORS "$@" "$ROOT/tests/compare_eza.sh" "$FIXTURE" 2>&1)
    for device in "${DEVICES[@]}"; do
        a=$(env -u LS_COLORS -u EZA_COLORS -u EXA_COLORS "$@" eza --color=always -ld "$device" 2>&1 | $N)
        b=$(env -u LS_COLORS -u EZA_COLORS -u EXA_COLORS "$@" "$F" --color=always -ld "$device" 2>&1 | $N)
        if [ "$a" != "$b" ]; then
            result+=$'\n'"DIFF  -ld $device"$'\n'"$(diff <(echo "$a") <(echo "$b"))"
        fi
    done
    echo "kinds $name: $(grep '^passed' <<<"$result")$(grep -c '^DIFF  -ld' <<<"$result" | sed 's/^0$//; s/^[1-9].*/, device diffs/')"
    if ! grep -q 'failed 0' <<<"$result" || grep -q '^DIFF  -ld' <<<"$result"; then
        status=1
        echo "$result" | head -20
    fi
}
KINDS='di=01;35:fi=04;33:ln=01;32:pi=01;31:so=04;35:bd=07;36:cd=01;33:or=40;31;01:ex=04;32'
GNU='su=37;41:sg=30;43:tw=30;42:ow=34;42:st=37;44:mi=05;31'
check "defaults"
check "LS_COLORS" LS_COLORS="$KINDS:$GNU"
check "EZA_COLORS" EZA_COLORS="$KINDS:$GNU:im=01;36:da=35:sf=01;36"
check "ln=target" LS_COLORS="ln=target"
check "reset" LS_COLORS="$KINDS:*.png=01;35" EZA_COLORS="reset:ln=01;34:sc=04;32"
check "reset alone" EZA_COLORS="reset"
check "reset=1" EZA_COLORS="reset=1"
check "late reset" EZA_COLORS="di=01;35:reset"
exit $status
