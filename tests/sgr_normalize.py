#!/usr/bin/env python3
"""Rewrites text with SGR escapes as runs of (style)text, so outputs that
draw the same thing with different escape sequences compare equal."""
import re, sys

def apply(state, params):
    codes = [int(p) if p else 0 for p in params.split(';')] if params else [0]
    i = 0
    while i < len(codes):
        c = codes[i]
        if c == 0: state = {}
        elif c in (1,2,3,4,5,7,8,9): state = {**state, f'a{c}': True}
        elif 30 <= c <= 37 or 90 <= c <= 97: state = {**state, 'fg': c}
        elif 40 <= c <= 47 or 100 <= c <= 107: state = {**state, 'bg': c}
        elif c == 39: state = {k: v for k, v in state.items() if k != 'fg'}
        elif c == 49: state = {k: v for k, v in state.items() if k != 'bg'}
        elif c in (38, 48):
            if codes[i+1] == 5: state = {**state, ('fg' if c == 38 else 'bg'): f'5;{codes[i+2]}'}; i += 2
            else: state = {**state, ('fg' if c == 38 else 'bg'): f'2;{codes[i+2]};{codes[i+3]};{codes[i+4]}'}; i += 4
        i += 1
    return state

def normalize(line):
    state = {}
    out = []
    cur = None
    for tok in re.split(r'(\x1b\[[0-9;]*m)', line):
        if tok.startswith('\x1b['):
            state = apply(state, tok[2:-1])
            continue
        for ch in tok:
            st = ','.join(f'{k}={v}' for k, v in sorted(state.items(), key=str)) if ch != ' ' else ''
            if st != cur:
                out.append(f'[{st}]')
                cur = st
            out.append(ch)
    return ''.join(out)

for line in sys.stdin:
    print(normalize(line.rstrip('\n')))
