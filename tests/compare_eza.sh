#!/usr/bin/env bash
# Compares fls against eza for a set of option combinations.
# usage: tests/compare_eza.sh [DIR] [extra eza/fls args...]
F="$(cd "$(dirname "$0")/.." && pwd)/build/fls"
DIR="${1:-.}"
shift || true
cd "$DIR" || exit 1
pass=0; fail=0
while IFS= read -r args; do
    [ -z "$args" ] && continue
    N="python3 $(dirname "$F")/../tests/sgr_normalize.py"
    a=$(eval "eza $args" 2>&1 </dev/null | $N)
    b=$(eval "$F $args" 2>&1 </dev/null | $N)
    if [ "$a" == "$b" ]; then pass=$((pass+1)); else
        fail=$((fail+1)); echo "DIFF  $args"; diff <(echo "$a") <(echo "$b") | head -${DIFF_LINES:-6}
    fi
done <<'CASES'
--color=never .
--color=never -la .
--color=never -lah .
--color=never -lgHi .
--color=never -l -s size .
--color=never -l -s modified -r .
--color=never -1 --group-directories-first .
--color=never -x -w 90 .
--color=never -w 90 .
--color=never -F -w 90 .
--color=never -D .
--color=never -lb .
--color=never -lB .
--color=never -l --time-style=long-iso .
--color=never -l --time-style=iso .
--color=never -l --time-style=full-iso .
--color=never -l --time-style=relative .
--color=never -l -u .
--color=never -l -o .
--color=never -lS .
--color=never -l -n .
--color=never -s Name -1 .
--color=never -s type -1 -a .
--color=never -s ext -1 .
--color=never -T -L 2 .
--color=never -R -L 2 .
--color=never -lT -L 2 .
--color=never -1 -a .
--color=always -1 -a .
--color=always -la .
--color=always -lT -L 2 .
--color=always -w 100 .
--color=always --icons=always -w 100 .
--color=always --icons=always -1 -a .
--color=always --icons=always -lT -L 2 .
--color=always -lgHiSo .
--color=never -x -w 60 .
--color=never -w 40 .
--color=never -w 150 .
--color=never -x -w 150 .
--color=never -lh --git .
--color=always -l --git .
--color=never -l --time-style=relative -s modified .
--color=never -lb --total-size .
--color=never -1 --classify=always -a .
--color=never -1 -r -s size .
--color=never -1 -D --group-directories-last .
CASES
echo "passed $pass, failed $fail"
