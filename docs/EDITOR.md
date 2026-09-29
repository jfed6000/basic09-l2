# l2b09ed — the l2basic09 editor

`l2b09ed` is a full-screen editor for Basic09 source, modeled on the DOS Borland Turbo C IDE and reworked for Basic09. It edits one whole `.b09` text file and, from P5.3 on, drives `l2b09run` over the pipe protocol ([PROTOCOL.md](PROTOCOL.md)) to load, run and debug the program.

It is written in 6809 assembly (`os9/l2b09ed/`, built as `build/l2b09ed`). Only the key tables and a few screen details are machine-specific, so a CoCo 3 port is possible.

    l2b09ed [-c=<pages>] [<file>]

- **`-c=<pages>`:** number of 2K pages cached in memory, 3–24 (default 12). If memory is short it uses fewer, down to 3.
- **`<file>`:** the file to edit. A missing file starts empty and is created on the first save. With no name, the first save asks for one.

## Status

| Phase | What | State |
|---|---|---|
| P5.0 | Key and screen survey, this document | done |
| P5.1 | Paged buffer, plain full-screen view, open, edit, save | done |
| P5.2 | Turbo UI: menu bar, drop-down menus, dialogs, message window, block operations, find/replace, undo | |
| P5.3 | Runtime: Make (only changed procedures), Run, error jump, user screen | |
| P5.4 | Debugger UI: current line, step, continue, evaluate, watches | |
| P5.5 | `l2b09run`: line breakpoints, run to cursor, step over | |

## Keys

The editor has to work with two Wildbits keyboards, and later a CoCo 3 keyboard. Every command can be reached with Ctrl, Alt, F1/F2 and the arrows.

| Key | Command | Since |
|---|---|---|
| Arrows | Move | P5.1 |
| Ctrl+Left / Ctrl+Right | Word left / right | P5.1 |
| Ctrl+Up / Ctrl+Down | Page up / down | P5.1 |
| Ctrl+Shift+Up / Down | Top / end of the file | P5.1 |
| ^J / ^K (K2: Home) | Start / end of the line | P5.1 |
| Backspace | Delete the character before the cursor | P5.1 |
| Shift+Backspace | Delete the character at the cursor | P5.1 |
| Enter | New line, indented like the current one | P5.1 |
| ^D | Delete the line | P5.1 |
| ^G | Go to line | P5.1 |
| ^S, F2 | Save | P5.1 |
| ^Q | Quit (asks to save changes) | P5.1 |
| Shift+arrows, Ctrl+Shift+Left/Right | Select | P5.2 |
| ^A ^C ^X ^V | Select all, copy, cut, paste | P5.2 |
| ^Z / ^Y | Undo / redo | P5.2 |
| ^F / ^L | Find / find next | P5.2 |
| Esc | Cancel (menu, dialog, selection) | P5.2 |
| Alt+letter | Open a menu (File, Edit, Search, Run, Compile, Debug, Options, Help) | P5.2 |
| F1 | Help | P5.2 |
| F3, ^O | Open | P5.2 |
| ^B | Make (load the changed procedures) | P5.3 |
| ^R | Run | P5.3 |
| ^N | Next error | P5.3 |
| F5 | User screen (the program's window) | P5.3 |
| F6 | Switch between the edit and message windows | P5.3 |
| F7 | Step | P5.4 |
| ^E | Evaluate / modify | P5.4 |
| ^W | Add a watch | P5.4 |
| F4 | Run to the cursor | P5.5 |
| F8 | Step over | P5.5 |
| ^T | Toggle a breakpoint | P5.5 |

The base bindings follow the user's `te` editor (`~/projects/f256/jfed/te`), and the Turbo roles sit on F1–F8.

### What the keyboard drivers send

Both drivers send a character. The modifier and arrow state comes from `SS.KySns`, which is buffered with each character, so it describes that key exactly.

| Key | Jr2 PS/2 (`keydrv_ps2`) | K2 (`keydrv_k2`) |
|---|---|---|
| ↑ ↓ ← → | `$0C` `$0A` `$08` `$09`, plus the UP/DOWN/LEFT/RIGHT bit | same |
| Backspace | `$08` without the LEFT bit | same |
| Shift+Backspace | `$18` with SHIFT | same |
| Tab | nothing | `$09` without the RIGHT bit |
| Esc / BREAK | `$05` | `$05` |
| F-keys | F1 `$B1`, F2 `$B2`, Shift+F1/F2 `$B3`/`$B4`; nothing for F3–F12 (F7 sends a stray byte) | F1–F8 `$A1`–`$A8` (F2/4/6/8 are Shift+F1/3/5/7) |
| Home | nothing | `$01` without CTRL |
| End, PgUp, PgDn, Ins, Del | nothing | not on the keyboard |
| Ctrl+letter | `$01`–`$1A` with CTRL | same |
| Alt+letter | the letter with ALT | letter+`$40` with ALT |
| Alt+← / Alt+→ | switch terminal | same |

`keys.asm` folds all of this into one set of editor key codes (`EK.*`). F3–F8 work on the K2 only, until `keydrv_ps2` sends them. That driver change is the user's call, and every F-key command has a Ctrl or menu equivalent.

## Screen

The screen uses the CoCo/Wildbits VTIO control codes: `$02` cursor XY, `$0C` clear, `$1F $20/$21` reverse video, `$05 $20/$21` cursor off/on. The size comes from `SS.ScSiz` (80×30 on Wildbits), and the default is 80×30.

The text window is every row but the last. The status line (file name, `*` if modified, line and column) and prompts use the last row. Tabs expand to every 8th column. A line wider than the window scrolls the whole window sideways.

## The paged buffer

The text is paged, so a file can be far larger than the editor's 64K.

- **Pages:** a doubly linked chain of up to 512 pages, each at most 2K. Every page owns a 2K slot in the swap file `l2b09ed.swp`, which sits in the current data directory and is deleted on exit. A page descriptor (13 bytes) holds the links, the byte count, the number of carriage returns, the slot, the cache entry and flags.
- **Cache:** only `-c` pages are in memory, in an LRU cache. A dirty page is written to its slot when its buffer is reused. The page mapped last is never the one evicted, so code can hold two page pointers at a time.
- **Loading:** the file is read into pages 1,536 bytes full, so typing rarely splits a page right away. Saving walks the chain.
- **Editing:**
  - inserting into a full page splits it in half;
  - a page that drops below 512 bytes is joined to a neighbour when the two fit in 1,536 bytes;
  - an empty page is removed.
- **Positions** are (page, offset) pairs. The cursor, the window's top line, the selection anchor and a scratch position are tracked: splits, joins, inserts and deletes keep them on the same text. Positions are canonical: an offset equal to the page's byte count only occurs at the end of the text.
- **Line numbers:** the per-page carriage-return counts make "go to line" a walk over the descriptors, followed by a scan of one page.

## Testing

- **Scripted keys:** `tools/keys.py` compiles a readable key script (`"text"`, `up`, `^g`, `pgdn*3`, …) into the bytes the editor reads. When path 0 is not a terminal, `SS.KySns` fails, so keys that need modifier bits are sent as `$FF <kysns> <char>`.
- **Test data:** a test directory's `gen` script writes generated files, which are copied into the image unchanged (see `tools/emu-wildbits.sh`).
- **`make p5atest` (P5.1):** `test/p5a/gen` builds a 3,000-line, 129 KB file and a key script. It also runs the same operations through a Python model of the editor's commands to produce the expected file. The editor runs with `-c=3` (so it swaps constantly), with keys from the script and the screen on `/vt3`. It saves, and the result must match the model byte for byte.
  - **Covered:** go to line, typing, Enter with indent, Backspace joining lines, Delete, delete line (200 in a row: page joins and removals), 40 inserted lines (page splits), vertical moves keeping the column, word moves, start/end of the line, top/bottom, page down, save and quit.
