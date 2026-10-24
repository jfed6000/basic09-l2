# l2b09help: the help browser

A full-screen help browser for `basic09-l2`, in its own program (`l2b09help`) and data file (`basic09-l2.hlp`). Pages cover the editor's keys and menus, every Basic09 statement and function, and the error codes. Pages are linked; there is an index and a search; F1 in the editor opens the page for the word at the cursor.

## Why a separate program

- The editor has three 8K blocks (24,576 bytes) and is close to full; the help text alone was 1.3K, and full pages for 115 keywords and 143 errors are far more.
- `l2b09help` is a separate process with its own 64K. The editor forks it on F1 and waits; it inherits the terminal and the key input, so it takes over the screen. It is built from the editor's `term.asm` and `keys.asm`, so it looks and reads keys the same way.
- It also runs on its own from the shell: `l2b09help [<topic>]`.

## Source pages (`help/*.txt`)

Plain text, one file per area (`editor.txt`, `statements.txt`, `functions.txt`, `errors.txt`, ...). `tools/mkhelp.py` compiles them into `build/basic09-l2.hlp`.

```
# a comment: a # in the first column
@category Statements

== PRINT | PRINT statement
@also ?
Writes values to the terminal or to a path.

  PRINT [#<path>,] [<expr> [, | ;] ...]
  PRINT [#<path>,] USING <format>, <expr> ...

A comma moves to the next 16-column zone; a semicolon adds nothing.
See also {INPUT}, {WRITE}, {PRINT USING|USING}.
```

- `@category <name>` sets the category of the topics that follow (it groups them in the index).
- `== <name> | <title>` starts a topic. The name is what links and context help look for, without regard to case; the title is shown in the frame. `| <title>` may be left out (the title is then the name).
- `@also <name> ...` gives other names for the same page (`ELSE` and `ENDIF` open `IF`). Names are separated by spaces; a name with a space in it is written with `_` (`END_DEFTYPE`).
- Body lines are shown as they are, at most 76 characters. Blank lines at the start and end of a page are dropped.
- `{<name>}` is a link to the topic `<name>`, shown as `<name>`; `{<text>|<name>}` shows `<text>`. `{{` is a literal `{`.

`tools/mkhelp.py` checks that every name is unique, every link has a target, every line fits, every word of the compiler's `KEYTAB` (and the editor's `DEFTYPE`, `USE`) is a name, and every error in `errmsg` has a page `Error <n>`.

Two topics are made by `mkhelp.py`:
- `Index`: every topic by category, in columns, each a link.
- The start page is the hand-written topic `Help`; F1 with no word at the cursor opens it.

## Compiled file (`basic09-l2.hlp`)

Big-endian, as the 6809 reads it.

| Offset | Size | What |
|---|---|---|
| 0 | 4 | `B9HL` |
| 4 | 1 | version, 1 |
| 5 | 2 | number of names (topics and their `@also` names) |
| 7 | 2 | size of the name table in bytes |
| 9 | ... | the name table, sorted by name |
| ... | ... | the pages |

- **Name table entry:** the name in capitals with the high bit set on its last character, then the page's offset in the file (3 bytes) and its length (2 bytes). `@also` names point at the same page.
- **Page:** the title, a carriage return, then the body lines, each ending in a carriage return. A link is `$01`, the target page's offset (3 bytes) and length (2 bytes), the text shown, then `$02`. No page is larger than `HPMAX` (12K).

## The viewer (`os9/l2b09help/l2b09help.asm`)

- **Screen:** a double frame with the page's title in the top border, the page inside it, and the hint line under it in the menu bar's grey. Links are pale cyan and the selected link black on pale cyan; with colours off (`-n`) the selected link is in reverse video. Lines are cut at the window's width.
- **Keys:** Up/Down scroll a line, Ctrl+Up/Ctrl+Down a page, Ctrl+Shift+Up/Down to the top and the end. Left/Right select the previous/next link (the page scrolls to it), and Enter follows it. Backspace goes back. F1 opens the contents (`Help`) and F2 the index. The mouse wheel scrolls 3 lines a step (`SS.MsWheel`, polled while it waits for a key; clicks are not used). Esc or Ctrl+Q leaves.
- **Search:** typing a printable character starts a search (the page shown is remembered). The hint line shows `Search: ` and what was typed; the page lists every name that starts with it, as links, the first one selected. Backspace takes a character off (with none left the search ends), Enter opens the selected name, and Esc goes back to where the search started. Names are matched in capitals.
- **Context help:** `l2b09help <word>` opens the page of that name; if there is none, the search for it; if nothing starts with it either, the contents.
- **Double spacing (`-d`, 2026-10-24):** the page on every other screen row, as the editor draws it: `term.asm`'s `t_xy` already doubles the row when `dblsp` is set, so the viewer halves its row count, clears the screen once (the editor's gap rows would show through), and `v_gap` draws the frame's sides on the gap row under the top border and under each text row. The editor passes `-d` when its own double spacing is on, so on 80×60 with double spacing the help has normal-size characters too. On its own the viewer is single-spaced unless given `-d`.
- **History:** Back remembers 16 pages (the oldest goes first).
- **Memory:** its own process: the name table (up to 6K), a page (up to 12K), the line and link tables. The file is opened once; a page is one `I$Seek` and one `I$Read`.
- **Code:** it includes the editor's `term.asm` and `keys.asm` and declares the variables they use, so the frames, the screen size, both keyboards and the key scripts work the same way. Its own colour routines replace `hl.asm`'s: run from the editor (`-e`) it leaves the palette alone on exit. `mu_wait` polls only the wheel, and `mu_new` is a stub (no clicks). It is assembled with `autobranchlength`, since its size does not matter the way the editor's does (3.5K).

## The editor's side

- **F1** (`c_help` in `menu.asm`): the word at the cursor (`word_at`, plus a `$` after it) goes to `l2b09help -e [-n] [-h] [-d] <word>`; without a word, no topic (the contents). Help ▸ Keys passes `Keys`.
- The editor flushes its output, forks the viewer (`F$Fork`, found in the execution directory), and waits for it with `F$Wait` (another child, `l2b09run`, may end meanwhile: it waits on). The viewer inherits the terminal and the key path, so a key script feeds both. Its exit status, or the error if it could not start (not installed, for one), goes on the status line.
- Then `hl_set` sends the editor's colours again and everything is redrawn (`gapdty` too, for double spacing).
- `-h` is passed on so that a test's snapshot can show the viewer, and `-d` when the editor is double-spaced.

## Installing

`make` builds `build/l2b09help` and `build/basic09-l2.hlp`. `k2img`/`jr2img` and the recipe (`make main`) put `l2b09help` in `CMDS` and the help file in `SYS`.

## Notes

- MAME's `wbjr2` keyboard has no function keys, so F1 cannot be pressed in a live (`lua`) test; the key-script tests send it (`f1`).
