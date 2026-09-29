# l2b09ed — the l2basic09 editor

`l2b09ed` is a full-screen editor for Basic09 source, modeled on the DOS Borland Turbo C IDE and reworked for Basic09. It edits one whole `.b09` text file and, from P5.3 on, drives `l2b09run` over the pipe protocol ([PROTOCOL.md](PROTOCOL.md)) to load, run and debug the program.

It is written in 6809 assembly (`os9/l2b09ed/`, built as `build/l2b09ed`). Only the key tables and a few screen details are machine-specific, so a CoCo 3 port is possible.

    l2b09ed [-c=<pages>] [-t=<term>] [-b=<kb>] [-m=<kb>] [-l=<log>] [-h] [<file>]

- **`-c=<pages>`:** number of 2K pages cached in memory, 3–24 (default 12). If memory is short it uses fewer, down to 3.
- **`-t=<term>`:** the terminal the program runs on. The default is a free window from the `/vt` factory (loaded by the stock startup). A file works too; there is then no user screen.
- **`-b=<kb>`:** passed on to `l2b09run`, which banks procedure code into that much far memory (ARCHITECTURE.md, P6).
- **`-m=<kb>`:** `l2b09run`'s data size, like the shell's `#<kb>k` (at most 63).
- **`-l=<log>`:** write the protocol traffic to a file: `> ` for what the editor sends, `< ` for what comes back, and `# ` for the parameters `l2b09run` was started with.
- **`-h`:** at the end of the key input, sleep instead of quitting. Tests use it to take a screen snapshot of a menu or dialog.
- **`<file>`:** the file to edit. A missing file starts empty and is created on the first save. With no name, the first save asks for one.

## Status

| Phase | What | State |
|---|---|---|
| P5.0 | Key and screen survey, this document | done |
| P5.1 | Paged buffer, plain full-screen view, open, edit, save | done |
| P5.2a | Turbo layout, menu bar and drop-down menus, dialog boxes, help, File commands | done |
| P5.2b | Selection and clipboard | done |
| P5.2c | Find and replace | done |
| P5.2d | Undo and redo | done |
| P5.3 | Runtime: Make (only changed procedures), Run, error jump, user screen | done |
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
| ^S, F2 | Save (asks for a name if there is none) | P5.1 |
| ^Q | Quit (asks to save changes) | P5.1 |
| Alt+letter | Open a menu (File, Edit, Search, Run, Compile, Debug, Options, Help) | P5.2a |
| F1 | Help | P5.2a |
| F3, ^O | Open | P5.2a |
| Shift+arrows, Ctrl+Shift+Left/Right | Select (typing, Enter or paste replaces the selection; Backspace/Delete remove it) | P5.2b |
| ^A ^C ^X ^V | Select all, copy, cut, paste | P5.2b |
| ^Z / ^Y | Undo / redo (50 steps) | P5.2d |
| ^F / ^L | Find / find next (the match is selected) | P5.2c |
| Search ▸ Replace | Replace, asking Y / N / A (all) / Esc at each match | P5.2c |
| Options ▸ Match case | Searches match case (off by default) | P5.2c |
| Esc | Cancel (menu, dialog, selection) | P5.2a/b |
| ^B | Make (load the changed procedures) | P5.3 |
| ^R | Run (Make, then run the first procedure) | P5.3 |
| ^N | Next message (and its line) | P5.3 |
| F5 | User screen (the program's window) | P5.3 |
| F6 | Into the message window, and back | P5.3 |
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

    row 0        File  Edit  Search  Run  Compile  Debug  Options  Help     menu bar (reverse)
    row 1        ╔══════════════════ name.b09 ══════════════════╗          title: the file name
    rows 2..h-3  ║ text                                          ║
    row h-2      ╚*═ 1234:56 ═══════════════════════════════════╝          * = modified, line:column
    row h-1       F1 Help  ^S Save  ...                                     hints or a message (reverse)

With the message window open, the text window ends 7 rows higher, and the message window fills those rows above the hint line:

    row h-9      ╚*═ 1234:56 ═══════════════════════════════════╝
    row h-8      ┌─────────────────── Message ───────────────────┐          double frame while it has the focus
    rows h-7..h-3│ Line 9, sub: Error 12 Illegal Statement ...    │          the selected message is reversed
    row h-2      └───────────────────────────────────────────────┘

- **Text window:** the rows and columns inside the frame. Tabs expand to every 8th column. A line wider than the window scrolls the whole window sideways.
- **Menus:** Alt+letter opens a menu under its title in a single-line box. Up/Down move (skipping separators), Left/Right go to the next menu, Enter or an item's first letter runs it, and Esc closes the menu. Commands that come in later phases are in the menus already and say "Not available yet".
- **Dialogs:** a centered double-line box for a line of text (Open, Save as, Go to line), for a Y/N question (Esc cancels), or for a message.
- **Help:** F1 (Help ▸ Keys) shows the key list over the whole screen.
- **Frame glyphs:** fonts differ, so the editor installs its own 14 glyphs (double frame, single frame, ├ ┤) over characters `$F2`–`$FF` of font set 0 with `SS.FntChar`, and puts the originals back on exit. te uses the same range. `SS.FntChar` takes the font set from the caller's A register, which for `I$SetStt` is the path number, so the calls go through path 0. When the keys come from a file, or the call fails (no `SS.FntChar`, e.g. a CoCo 3), the frames are ASCII (`+ - = |`).

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

## Selection and clipboard

- **Selection:** it runs between an anchor (a tracked position, with its line and display column) and the cursor, and is drawn in reverse video. A selected line end shows as one reversed space. Any edit ends the selection first, so the anchor's line and column stay valid while it is active. A plain move, a go-to or Esc ends it.
- **Deleting a selection** (`ed_delto`) works a page at a time. The first and last pages are cut with one move each, and whole pages in between are dropped without being read from the swap file.
- **The clipboard** is a page chain of its own in the swap file (1,536 bytes per page), so it can hold any amount.
- **Paste:**
  - splits the cursor page once at the cursor;
  - links copies of the clipboard pages in between;
  - leaves the cursor after the pasted text;
  - keeps the window's top line in place when the paste lands on it.

## Find and replace

- **Direction:** searches run forward from the cursor and do not wrap.
- **Case:** letters match either case unless Options ▸ Match case is on.
- **Result:** a match becomes the selection, with the cursor at its end, so typing replaces it and ^L finds the next one.
- **Dialogs:** they start with the last search (or replacement) text, and typing a character first replaces it.
- **Replace:** asks on the hint line at each match (Y, N, A = all the rest, Esc), then reports how many it replaced.
- **Speed:** the search scans page buffers directly for the first character (counting line ends on the way) and compares only candidates a character at a time, so matches can span pages.

## Undo and redo

- **Records:** each undo record is a range of the text: an absolute 24-bit start and length, because pages split and join and the text can pass 64K. Its text is either in the buffer or out of it, in a page chain in the swap file.
  - An insertion starts with its text in the buffer and a deletion with its text out.
  - Undo and redo both move the text to the other side, with the page-wise delete and the paste code.
- **Grouping:**
  - typing (and Enter) extends the last insertion if it continues it;
  - Delete and ^D add to the end of the last deletion, and Backspace adds to its start;
  - a paste, a deleted or cut selection, and each replacement are records of their own.
- **History:** there are 50 records, and the oldest goes first. An edit after an undo drops what could have been redone. Open and New clear the history.
- **Cursor:** after an undo or redo the cursor is at the change and the window is centred on it.
- **Page budget:** undo text shares the 512 pages with the text and the clipboard. If an edit needs a page and none is left, the undo history is given up to free its pages. If a deletion's text does not fit, the deletion still happens without a record.

## Make and Run

- **The runtime:** the first Make forks `l2b09run -t=<term> [-b=<kb>]` with two pipes (PROTOCOL.md, "Connecting"). It keeps running until the editor quits, which sends `bye` and waits for it to exit. If it ends on its own (a program's `BYE`), the bottom line says so, with its exit status, and the next Make starts a new one.
- **Blocking:** pipes cannot be polled, so the editor waits for each reply. Make shows "Making..." while `l2b09run` compiles.
- **Procedures:** a line `PROCEDURE <name>` (any case, spaces before it) starts a procedure, which runs to the next such line. Text before the first one is not sent.
- **What Make sends:** a table holds each procedure `l2b09run` has, with a signature of the text it was loaded from: two 16-bit sums (of the bytes, and of those sums) and the length. Make scans the text and compares.
  - A procedure whose signature changed, a new one, or one with a compile or bind error last time is written to `l2b09ed.tmp` (in the current directory, deleted on exit), and all of them go in one `load l2b09ed.tmp`.
  - A name that is no longer in the text gets `kill <name>` first.
  - The scan reads the page buffers directly and looks for `PROCEDURE` only at the start of each line. It does not depend on which pages were edited, so undoing an edit makes the procedure unchanged again.
  - If a load fails without an event (an `ERROR #` line with no `%CERR` or `%BERR`), every procedure in it is sent again next time, and the message window says so.
- **Messages:** each `%CERR`, `%BERR` and `%ERROR` becomes a message: `Line <n>, <proc>: Error <code> <text>`. The file line is the line of the procedure's `PROCEDURE` line plus the event's line. The text comes from `/dd/sys/errmsg`, which has the Basic09 errors. Up to 32 messages are kept.
- **After a Make with errors:** the message window opens (7 rows at the bottom, taken from the text window) and the cursor goes to the first error. ^N goes to the next one. F6 (or Compile ▸ Messages) moves into the window: Up/Down choose a message, Enter goes to its line, F6 goes back, and Esc closes the window. A clean Make closes it and says how many procedures it loaded, or "up to date".
- **Run:** Make, then `run <first procedure in the text>`. While it runs, the program's terminal is shown (`$1B $21` written to a path the editor keeps open to it); when `%READY` comes back, the editor's own window is shown again.
  - A runtime error (`%ERROR`) becomes a message and the cursor goes to its line. The debugger stop that follows (`%DEBUG`) is left with `q` until P5.4 adds the debugger.
  - A break with no error is shown as `Line <n>, <proc>: Stopped`.
- **BREAK:** SCF sends the keyboard interrupt to the last process that used the terminal. That is `l2b09run` once the program has done I/O there, but it can be the editor, which selected the window. So the editor has a signal handler that passes BREAK and abort on to `l2b09run` while a program runs.
  - A signal ends a waiting pipe read with `E$EOF` (pipeman returns the 0 bytes read so far). The handler sets a flag so the read is tried again instead of taken for the end of the pipe.
- **User screen:** F5 (Run ▸ User screen) shows the program's terminal until a key is pressed there.

## Testing

- **Scripted keys:** `tools/keys.py` compiles a readable key script (`"text"`, `up`, `^g`, `pgdn*3`, …) into the bytes the editor reads. When path 0 is not a terminal, `SS.KySns` fails, so keys that need modifier bits are sent as `$FF <kysns> <char>`.
- **Test data:** a test directory's `gen` script writes generated files, which are copied into the image unchanged (see `tools/emu-wildbits.sh`).
- **`make p5atest` (P5.1):** `test/p5a/gen` builds a 3,000-line, 129 KB file and a key script. It also runs the same operations through a Python model of the editor's commands to produce the expected file. The editor runs with `-c=3` (so it swaps constantly), with keys from the script and the screen on `/vt3`. It saves, and the result must match the model byte for byte.
  - **Covered:** go to line, typing, Enter with indent, Backspace joining lines, Delete, delete line (200 in a row: page joins and removals), 40 inserted lines (page splits), vertical moves keeping the column, word moves, start/end of the line, top/bottom, page down, save and quit.
- **Model:** `tools/edmodel.py` holds the Python model of the editing commands, selection and clipboard included. A `Session` records the key script alongside the model, so p5a and p5c build both from one list of operations.
- **`make p5ctest` (P5.2b):** a 64 KB file with a 4-page cache. It covers typing over a selection, cut and paste of lines, word selection, a selection across lines deleted, an upward selection, Esc and plain moves ending a selection, a 300-line cut pasted inside a line, and select all, copy and two pastes (the result is 196 KB). The saved file must match the model.
- **`make p5dtest` (P5.2c):** a match across a page boundary, typing over a match, find next, Match case on and off, Replace answered Y/N/Esc, then Replace answered A (1,443 replacements), and a search that finds nothing. The result must match the model.
- **`make p5etest` (P5.2d):** undo and redo of grouped typing, Delete and Backspace, ^D, cut and paste, 1,500 replacements undone 60 times (only 50 records are kept), select-all delete undone and redone, and an edit that ends redo. The result must match the model, which follows the same grouping rules.
- **`make p5ftest` (P5.3):** `l2b09run` with `-t=` a file and `-l=` a log. A three-procedure program with two compile errors: Make, fix the first at the cursor, ^N to the second and fix it, Make again (only those two are sent), Run, add a call that fails with error 45, Run (only `main` is sent; the cursor goes to the failing line), then rename a procedure and Make (`kill` plus one load). The saved file and the whole protocol log must match. A second session uses the `/vt` factory and a program that sends BREAK (`S$Intrpt`) to its parent, the editor, which passes it on; the program stops, the editor leaves the debugger, and a second Run sends nothing new.
- **`make p5btest` (P5.2a):** File commands through keys, menus and dialogs. It covers Save with no name (Save as), Open, File ▸ Save by its letter, New, Options ▸ Auto indent, Quit answered with Esc and then Y, and File ▸ Save as chosen with the arrows. Three saved files must match.
