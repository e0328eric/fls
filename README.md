# fls

A fancy `ls` written in [Glosso](../glosso): one program with two faces.

- **`fls`** (the default): an [eza](https://github.com/eza-community/eza)-style
  listing on the command line, with grids, a long view, trees, icons, colors
  and git status.
- **`fls --tui`**: an [nnn](https://github.com/jarun/nnn)-style file browser in
  the terminal, with contexts, type-to-filter, selection with copy, move and
  delete, and a preview pane.

## Building

```sh
glosso first.glo          # writes build/fls
```

`first.glo` is a compile-time build script (optimized, `-O3`). For a quick
unoptimized build, run `glosso main.glo -o build/fls`.

## The listing (`fls`)

The output matches eza 0.23 byte for byte, colors included, across the option
combinations in `tests/compare_eza.sh`. Options combine the way eza's do:
`fls -laT -L2 --git`.

```sh
fls                       # grid, sorted naturally (file2 before file10)
fls -l --git              # long view with a git status column
fls -lT -L 2 --icons      # tree inside the long view
fls -1 -s size -r         # one per line, largest first
fls -lh --time-style=relative --total-size
```

| Display | | Filtering and sorting | |
|---|---|---|---|
| `-1` `-G` `-l` | one per line, grid, long | `-a` (`-aa`) `-A` | hidden files (and `.` `..`) |
| `-x` | grid across | `-d` `-D` `-f` | dirs as files, only dirs, only files |
| `-R` `-T` `-L N` | recurse, tree, depth | `-s FIELD` `-r` | sort field, reverse |
| `-F` | type indicators | `-I 'a*\|*.o'` | ignore globs |
| `--icons` `--color` | Nerd Font icons, colors | `--group-directories-first/last` | |
| `--hyperlink` | OSC 8 links | `-X` | dereference links |
| `-w COLS` | width | | |

Long view: `-b` `-B` (binary or byte sizes), `-g` (group), `-h` (header),
`-H` (links), `-i` (inode), `-S` (blocks), `-n` (numeric ids), `-o` (octal
permissions), `-m` `-u` `-U` `--changed` / `-t FIELD` (time columns),
`--time-style default|iso|long-iso|full-iso|relative`, `--total-size`, `--git`,
and `--no-permissions`, `--no-filesize`, `--no-user`, `--no-time`.
`fls --help` lists everything.

Colors follow eza's palette, including its size scale and file categories.
`LS_COLORS` and `EZA_COLORS` override it, and `NO_COLOR` turns automatic color
off. When the output is not a terminal, the grid becomes one name per line.

Where it deliberately differs from eza:

- A bare `-F` means *always*, as in GNU `ls`. In eza it means *auto*.
- `-R -L N` counts depth from the directory given. eza counts the path
  components of the argument, so `eza -R -L2 dir` never descends.

## The browser (`fls --tui`)

```
  1  2  3  4  ~/Github/glosso
▶  ai_progress/                         │  README.md
   alpine_linux/                        │    1 # Glosso
  󱧼 build/                               │    2
   ...                                  │    3 Glosso is implemented in Rust ...
 1/24  drwxr-xr-x  -  almagest:users  2026-11-03 00:02            ↑name ? help
```

| Keys | | Keys | |
|---|---|---|---|
| `j` `k` `↑` `↓` `g` `G` | move | `/` | filter as you type (Enter on one match opens it) |
| `h` `←` `Backspace` | parent | `l` `→` `Enter` | open directory or file |
| `PgUp` `PgDn` `^U` `^D` | page | `~` `` ` `` `@` `-` | home, `/`, start dir, previous dir |
| `1`-`4` `Tab` | contexts | `c` | cd to a typed path |
| `Space` `+` | select and move down | `a` `A` `u` | select all, invert, clear |
| `p` `v` | copy or move the selection here | `x` | delete the selection or current entry (confirmed) |
| `r` `n` | rename, new file (`name/` makes a directory) | `e` `o` `!` | `$EDITOR`, open with..., `$SHELL` here |
| `.` `d` `P` `I` | hidden files, details, preview, icons | `t` | sort menu |
| `i` | file information | `^L` `F5` | refresh (also automatic) |
| `?` | help | `q` `Q` | quit (and write `--cd-file`), quit |

The mouse works too. Click to move, double-click to open, right-click to
mark, and use the wheel to scroll. Click a context number to switch to it.

Enter on a file runs `$FLS_OPENER`, `$NNN_OPENER` or `xdg-open`. `e`, `o` and
`!` suspend the browser, give the terminal to the program, and come back to
the browser when it exits. To make the shell follow the browser:

```sh
f() {
    rm -f /tmp/fls-cd
    fls --tui --cd-file /tmp/fls-cd "$@"
    [ -f /tmp/fls-cd ] && cd "$(cat /tmp/fls-cd)"
}
```

Command-line options carry over: `fls --tui -a -l -s size ~/Downloads` opens
with hidden files, details and size order. Icons are on in the browser unless
`--no-icons` is given, or you press `I`.

## Taking off (`fls --lol`)

In the spirit of `sl`: an airliner spools up its engines beside the control
tower, rolls down the runway, lifts off a third of the way across, tucks its
gear away and climbs out of the terminal. Ctrl-C and Ctrl-D do nothing until it is gone; the terminal is in
raw mode and SIGINT is ignored for the duration. `fls --lol=signal` installs
no handler and lets Ctrl-C or Ctrl-D end it early, with the terminal restored
and exit status 0.

## Tests

```sh
GLOSSO=glosso tests/run.sh   # everything below
glosso --run -o build/unit_test tests/unit_test.glo
tests/tui_test.sh            # drives the browser through --snapshot/--keys
tests/lol_test.py            # --lol in a pseudo-terminal: ^C, ^D and SIGINT
tests/compare_eza.sh DIR     # diffs fls against eza for ~50 option sets
tests/compare_kinds.sh       # the same per file kind, under fixed LS_COLORS/EZA_COLORS
```

`fls --snapshot -w 100 --keys 'jj<Enter>/src<Enter>' DIR` replays keys and
prints the browser's frame as text, which is how the TUI is tested without a
terminal. `fls --lol --snapshot -w 100` likewise prints every frame of the
takeoff. Build with `GLOSSO_DEBUG_ALLOCATOR=1` to check for leaks; the CLI and
the TUI paths above run clean.

## Layout

| File | Contents |
|---|---|
| `main.glo` | entry point: options, then the listing or the browser |
| `src/options.glo` | eza-compatible argument parsing and help |
| `src/entry.glo` | a listed file: stat, link targets, classification, filtering, eza's sort rules |
| `src/theme.glo` | file categories, colors (`LS_COLORS`/`EZA_COLORS`), SGR output, icons |
| `src/util.glo` | natord ordering, globs, sizes as eza prints them, users and groups, time styles |
| `src/git.glo` | per-file git status from `git status --porcelain -z` |
| `src/cli.glo` | grid (eza's term_grid fitting), long view, tree, recursion |
| `src/tui.glo` | the browser |
| `src/lol.glo` | `--lol`: the takeoff animation |

## Notes

One change was made to the Glosso compiler (`../glosso`) along the way:
`src/checker/derive.rs` kept losing the parenthesized flag of binary
expressions when a `for` loop body was rebuilt for its expansion. As a result,
every `(a & b) != c` inside `for x: collection` triggered a bogus precedence
warning. Older compilers still build fls; they only print that warning.
