# basic09-l2 — the l2basic09 editor

`basic09-l2` is a full-screen editor for Basic09 source, modeled on the DOS Borland Turbo C IDE and reworked for Basic09. It edits one whole `.b09` text file and, from P5.3 on, drives `l2b09run` over the pipe protocol ([PROTOCOL.md](PROTOCOL.md)) to load, run and debug the program.

It is written in 6809 assembly (`os9/basic09-l2/`, built as `build/basic09-l2`). Only the key tables and a few screen details are machine-specific, so a CoCo 3 port is possible.

    basic09-l2 [-c=<pages>] [-t=<term>] [-b=<kb>] [-m=<kb>] [-l=<log>] [-h] [<file>]

- **`-c=<pages>`:** number of 2K pages cached in memory, 3–24 (default 12). If memory is short it uses fewer, down to 3.
- **`-t=<term>`:** the terminal the program runs on. The default is a free window from the `/vt` factory (loaded by the stock startup). A file works too; there is then no user screen.
- **`-b=<kb>`:** passed on to `l2b09run`, which banks procedure code into that much far memory (ARCHITECTURE.md, P6).
- **`-m=<kb>`:** `l2b09run`'s workspace, like the shell's `#<kb>k` (at most 63; default 16, the module's own 8K was too small for a 14K-source procedure). Options ▸ Memory... changes it while the editor runs, and Make grows it by itself when a load runs out of memory (see Make and Run).
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
| P5.4 | Debugger UI: current line, step, continue, evaluate, watches | done |
| P5.5 | Line breakpoints, run to cursor, step over (`l2b09run` and the editor) | done |
| P5.6 | Syntax colours and pretty print | done |
| P5.7 | Mouse: click, drag select, right-click extend, menus, dialogs, message window, breakpoint border | done |
| — | Global TYPE lines: `DEFTYPE` blocks and `USE` (2026-10-15) | done |

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
| Ctrl+Shift+L | Find previous (Search ▸ Find previous) | P5.7 |
| Ctrl+1 / Ctrl+2 | Single / double line spacing (Options ▸ Double spacing toggles) | P5.7 |
| Search ▸ Replace | Replace, asking Y / N / A (all) / Esc at each match | P5.2c |
| Options ▸ Match case | Searches match case (off by default) | P5.2c |
| Esc | Cancel (menu, dialog, selection) | P5.2a/b |
| ^B | Make (load the changed procedures) | P5.3 |
| ^R | Run (Make, then run the first procedure); continue when stopped | P5.3/P5.4 |
| ^N | Next message (and its line) | P5.3 |
| F5 | User screen (the program's window) | P5.3 |
| F6 | Into the message window, and back | P5.3 |
| F7 | Step (into a called procedure); starts the program if it is not running | P5.4/P5.5 |
| ^P | Program reset | P5.4 |
| ^E | Evaluate / modify | P5.4 |
| ^W | Add a watch | P5.4 |
| Debug ▸ Delete watch, Until return | Delete a watch (or all); stop when the program returns to a procedure | P5.4 |
| F4 | Run to the cursor | P5.5 |
| F8 | Step over (a `RUN` runs the whole call) | P5.5 |
| ^T | Breakpoint on the cursor line, on or off | P5.5 |
| Debug ▸ Clear breakpoints | Clear them all | P5.5 |
| Options ▸ Syntax colours | Syntax colours on or off (on by default) | P5.6 |
| Options ▸ Keyword case | Pretty print writes keywords in lower case (the default) or in capitals | P5.6 |
| Compile ▸ Pretty print, All: pretty print (Ctrl+Space) | Pretty print the procedure at the cursor, or every procedure | P5.6 |

## Mouse

The pointer is the hardware one that `mousedrv_ps2` moves. The editor reads it with `SS.Mouse` on its own terminal, which since nitros9 `8562e60d` gives the buttons only to the terminal on the screen. There are no mouse events, so while it waits for a key the editor polls: `SS.Ready` on the key path, then `SS.Mouse`, then a one-tick sleep (`mouse.asm`). A change of the buttons, or a move to another cell with the left button held, comes back from `getkey` as `EK.MOUSE`. Pixels become cells by the cell size worked out from the screen size (8 or 16 pixels). On a CoCo 3 build `SS.Mouse` is a different call, so the mouse is left out there.

| Where | Left button | Right button |
|---|---|---|
| Text | Press: the cursor there (ends a selection). Drag: select to the pointer; above or below the window it scrolls a line, and again every 4 ticks while held there. | Press: extend the selection to the pointer (Shift+click cannot be seen: `SS.KySns` is buffered with the keys) |
| Right border (the scroll bar; when it scrolls, only the thumb's old and new cells are drawn) | ▲ / ▼: scroll a line (the cursor moves with the window). The track above or below the thumb: a page towards the pointer. Both repeat every 4 ticks while held. Dragging the thumb moves the window through the text, with the cursor on its top line. | — |
| Left border | Press: breakpoint on that line, on or off (^T) | — |
| Menu bar | Press: open that menu | — |
| Open menu | Press or drag over a title: that menu; a press on its own title closes it. Over an item: select it; release on it: run it. A press anywhere else closes the menu. | — |
| Message window | Press: select that message and move into the window (F6); a double click (within 30 ticks) goes to its line. In the window, a press elsewhere goes back to the text. | — |
| Dialog | A press outside it is Esc. In a Y/N question, a press on the `Y` or the `N` answers it. A message or help box closes on a press. | — |

The hint line has no buttons, and there is no double-click word select.

**The wheel** (2026-10-18, nitros9 `23b18b69`): `SS.MsWheel` (`$E8`) returns the wheel steps since the last call, signed, negative away from the user (0 without a wheel mouse, and 0 on a terminal that is not on the screen). If it answers at start, the editor asks it after `SS.Mouse` in every poll. Steps come back from `getkey` as the key `EK.WHEEL` (the count in `muwst`), not as a mouse event, so the menus, dialogs and the message window, which do not scroll, ignore it. In the text window each step scrolls 3 lines (at most a window's worth), the cursor moving with the window as with the scroll bar's arrows; away from the user scrolls up. The help browser scrolls its page by 3 lines a step too. A key script sends the wheel as `$FD <steps>` (`wheel:N` in `tools/keys.py`). MAME's `wbjr2` mouse has no wheel, so the real call is only tried on hardware.

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

The screen uses the CoCo/Wildbits VTIO control codes: `$02` cursor XY, `$0C` clear, `$1F $20/$21` reverse video (only with colours off), `$05 $20/$21` cursor off/on. The size comes from `SS.ScSiz` (80×30 on Wildbits), and the default is 80×30.

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

With watches (P5.4), a watch window of 2 rows plus one per watch sits directly under the text window, above the message window if that is open:

    ┌──────────────────── Watch ────────────────────┐
    │ 1 k: 2                                         │
    │ 2 s: hello                                     │
    └───────────────────────────────────────────────┘

- **Text window:** the rows and columns inside the frame. Tabs expand to every 8th column. A line wider than the window scrolls the whole window sideways.
- **Menus:** Alt+letter opens a menu under its title in a single-line box. Up/Down move (skipping separators), Left/Right go to the next menu, Enter or an item's first letter runs it, and Esc closes the menu.
- **Dialogs:** a centered double-line box for a line of text (Open, Save as, Go to line), for a Y/N question (Esc cancels), or for a message.
- **Help:** F1 runs the help browser `l2b09help` (docs/HELP.md) on the page for the word at the cursor (with a `$` after it: `LEFT$`), or on the contents. Help ▸ Contents and Help ▸ Keys open those pages. The editor waits while it runs, then redraws everything.
- **Syntax colours:** keywords, functions, strings, comments (`REM` to the end of the line, `(* ... *)`) and numbers (with `$hex` and a leading line number) each have a colour, set with VTIO's `$1B $32 <n>`. See "Syntax colours" below.
- **Breakpoints:** a line with a breakpoint has a mark (a dot on the frame, or `*`) in the left border.
- **Frame glyphs:** fonts differ, so the editor installs its own 15 glyphs (double frame, single frame, ├ ┤, the breakpoint mark) over characters `$F1`–`$FF` of font set 0 with `SS.FntChar`, and puts the originals back on exit. te uses `$F2`–`$FF`. `SS.FntChar` takes the font set from the caller's A register, which for `I$SetStt` is the path number, so the calls go through path 0. When the keys come from a file, or the call fails (no `SS.FntChar`, e.g. a CoCo 3), the frames are ASCII (`+ - = |`).

## Line spacing

- **Why:** the 8×8 font has no space between its rows. As in `te`, Ctrl+2 draws the text on every other screen row, and Ctrl+1 goes back. The screen's size never changes: on 80×30 double spacing gives 15 rows (11 lines of text), and on 80×60 it gives 30 rows of normal-height characters with a blank row under each.
- **How:** the editor lays itself out for half the screen's rows (`scrh`; `phrows` keeps the screen's own), and `t_xy` doubles the row. Everything (text, frames, menus, dialogs, the message and watch windows, the mouse) keeps working in those logical rows. The mouse's row shift comes from `scrh` too (`mu_rows`), so a pixel lands on the right logical row.
- **The gap rows:** only what crosses them is drawn there: the side borders and the scroll bar (`v_gaps`, `sb_upd`), the menu bar's grey, and the inside of a box (`bx_draw`). A box sets `gapdty`, and the next full redraw clears the gaps in the text window again.
- **Room:** switching to double spacing hides the message window if the text window would have fewer than 3 rows, and refuses if it still would.
- **Keys:** the K2 driver sends Ctrl+1 / Ctrl+2 as the digit with the Ctrl bit, the PS/2 driver as the digit minus `$60` (`$D1`, `$D2`).
- **Screen size:** Options ▸ 80x60 screen switches the editor's terminal between 80×30 and 80×60, separately from the spacing. It uses VTIO's DWSet (`$1B $20 <type> …`, `t_dwset`), which changes the terminal's own width, height and scroll size along with the display mode; `SS.DScrn` (`SS.MCR`) would only flip the double-height bit and leave the terminal at 30 rows. DWSet clears the screen in the colours it is given (the terminal's own), so the editor clears again in its colours and redraws. On exit it puts back the type it started with (worked out from `SS.ScSiz` at start, since `SS.ScTyp` is only set by a DWSet). It needs a terminal whose colours are known; from a key file it says it cannot.

## Syntax colours

- **Per line:** Basic09 has nothing that spans lines, so `v_line` colours each line as it draws it, from the line's start (`hl.asm`). There is no state between lines and no extra pass over the text.
- **Keywords** come from the compiler's own table (`KEYTAB` in `src/comand.asm`). `tools/mkkw.py` turns it into `os9/basic09-l2/kwtab.asm` (115 words, plus the editor's `DEFTYPE` and `USE`; per first letter the keywords, then the functions), so the two agree. Statements, reserved words and operator words are keywords, and the rest are functions. Case is ignored, as in the compiler.
- **Colours:** the editor uses its own, as Turbo C did: yellow text (7) on blue (6), with keywords white (1), functions pale cyan (3), strings green (5), comments light grey (15) and numbers orange (8), in the Wildbits text palette. On Wildbits, when the screen is a terminal, the editor also changes two palette entries at start: background slot 6 to `#000050` and foreground slot 7 to `#E6D67A`, because the default `#0000AA`/`#DDDD77` came out too bright and pale on the K2's video output. The text palette belongs to the screen, so other terminals' slot 6 and 7 change too while the editor runs. It cannot be read back, so on exit the editor puts back the palette module's defaults (`hl_pal`). Window frames (the text, message and watch windows, with their titles and the line:column) are white (1). The menu bar, the drop-down menus and the hint line are black on light grey (15), with the open menu's title and the selected item on green (5); with colours off they are in reverse video as before. A highlight (the selection, the line the program stopped at) is a colour pair of its own, not VTIO's reverse video: that swaps the colours in force, so a syntax colour sent inside a reversed run changed the background, and the swap back left the wrong pair for the rows after it. The terminal's own colours are read with `SS.FBRgs` at start and put back on exit, and also when colours are turned off. A colour is sent only when it changes, and each row ends in the normal colour, so the frame, menus and dialogs never set one. `$0A` and `$0D` are not used as colour numbers.
- **Cost:** `make p5itest` pages through a 5,000-line file 150 times: 81 s with colours and 67 s without (+21%). Options ▸ Syntax colours turns them off.

## Pretty print

- **Where the text comes from:** Basic09 keeps no source, only I-code, and `LIST` decompiles it with the keywords in capitals, standard spacing and the control structures indented. That is stock Basic09's pretty print. `SAVE` writes the same text without the indent.
- **Compile ▸ Pretty print** (the procedure at the cursor):
  1. Make, so that the procedure is loaded as it stands. A procedure with errors, or a program stopped in the debugger, is refused with a message.
  2. `list <procedure>`. Each line comes back as a marker, the I-code offset, a line number if there is one, and the text from column 11 on, two columns more per level of indent. The editor keeps the line number and the text, and makes the indent two spaces a level. It joins lines that `LIST` wrapped at its margin (an LF in the line), and drops trailing spaces.
  3. The result replaces the procedure's lines, the `PROCEDURE` line included (it comes back as `PROCEDURE <name>`). The body is indented two spaces under it, and a line number sits in that gutter (`10 k=0`). An `END` at the top level lines up with `PROCEDURE`; one inside a structure keeps its indent. If it is the same text already, nothing changes.
- **Compile ▸ All: pretty print** (Ctrl+Space) does the same for every procedure, and stops at the first one that has errors. The PS/2 driver sends Ctrl+Space as `$C0` (space minus `$60`) and the K2 driver as a space; both come with the Ctrl bit.
- **Keyword case:** keywords come out in lower case (`procedure`, `for`, `left$`), which reads more easily; Options ▸ Keyword case switches to capitals, as `LIST` writes them. Basic09 reads either. Strings, comments, numbers and names are not touched.
- **What changes:** keyword case, spacing, the indent and number formats (`1.50` becomes `1.5`, `1E3` becomes `1000.`). Comments stay as written. Names ignore case in Basic09, which keeps each one as it was first entered, so a name typed in another case elsewhere comes back in that first spelling.
- **What stays:** the number of lines, because every source line is one I-code line. So the cursor, the window and the breakpoints stay on their lines, and the procedure counts as loaded: its text came from the loaded code, so the next Make does not recompile it.
- **Undo:** one ^Z takes a whole pretty print back, and ^Y redoes it. Its undo records carry `UF.LINK` ("goes with the record before"). Undo and redo of such a group also put the breakpoints back on their lines.

## The paged buffer

The text is paged, so a file can be far larger than the editor's 64K.

- **Pages:** a doubly linked chain of up to 512 pages, each at most 2K. Every page owns a 2K slot in the swap file `basic09-l2.swp`, which sits in the current data directory and is deleted on exit. A page descriptor (13 bytes) holds the links, the byte count, the number of carriage returns, the slot, the cache entry and flags.
- **Cache:** only `-c` pages are in memory, in an LRU cache. A dirty page is written to its slot when its buffer is reused. The page mapped last is never the one evicted, so code can hold two page pointers at a time.
- **Loading:** the file is read into pages 1,536 bytes full, so typing rarely splits a page right away. Saving walks the chain.
- **Editing:**
  - inserting into a full page splits it in half;
  - a page that drops below 512 bytes is joined to a neighbour when the two fit in 1,536 bytes;
  - an empty page is removed.
- **Positions** are (page, offset) pairs. The cursor, the window's top line, the selection anchor and a scratch position are tracked: splits, joins, inserts and deletes keep them on the same text. Positions are canonical: an offset equal to the page's byte count only occurs at the end of the text.
- **Line numbers:** the per-page carriage-return counts make "go to line" a walk over the descriptors, followed by a scan of one page.

## Selection and clipboard

- **Selection:** it runs between an anchor (a tracked position, with its line and display column) and the cursor, and is drawn black on pale cyan (3), or in reverse video with colours off. A selected line end shows as one highlighted space. Any edit ends the selection first, so the anchor's line and column stay valid while it is active. A plain move, a go-to or Esc ends it.
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
- **Result:** a match becomes the selection, with the cursor at its end, so typing replaces it and ^L finds the next one. Ctrl+Shift+L finds the previous one: it searches back from the selection's start (or the cursor), counting the carriage returns it passes to keep the line number, and goes from page to page by `DS.PREV`. The K2 driver sends Ctrl+Shift+L as `$0C`, the PS/2 driver as `$EC` (`'L'-$60`); both come with the Ctrl and Shift bits.
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
- **Procedures:** a line `PROCEDURE <name>` (any case, spaces before it) starts a procedure, which runs to the next such line or the next `DEFTYPE` block (see "Global TYPE lines"). Text before the first one is not sent.
- **What Make sends:** a table holds each procedure `l2b09run` has, with a signature of the text it was loaded from: two 16-bit sums (of the bytes, and of those sums) and the length. Make scans the text and compares.
  - A procedure whose signature changed, a new one, or one with a compile or bind error last time is written to `basic09-l2.tmp` (in the current directory, deleted on exit), and all of them go in one `load basic09-l2.tmp`.
  - A name that is no longer in the text gets `kill <name>` first.
  - The scan reads the page buffers directly and looks for `PROCEDURE` only at the start of each line. It does not depend on which pages were edited, so undoing an edit makes the procedure unchanged again.
  - If a load fails without an event (an `ERROR #` line with no `%CERR` or `%BERR`), every procedure in it is sent again next time, and the message window says so.
- **Messages:** each `%CERR`, `%BERR` and `%ERROR` becomes a message: `Line <n>, <proc>: Error <code> <text>`. The file line is the line of the procedure's `PROCEDURE` line plus the event's line. The text comes from `/dd/sys/errmsg`, which has the Basic09 errors. Up to 32 messages are kept.
- **After a Make with errors:** the message window opens (7 rows at the bottom, taken from the text window) and the cursor goes to the first error. ^N goes to the next one. F6 (or Compile ▸ Messages) moves into the window: Up/Down choose a message, Enter goes to its line, F6 goes back, and Esc closes the window. A clean Make closes it and says how many procedures it loaded, or "up to date".
- **Run:** Make, then `run <first procedure in the text>`. A new run (Run, or F7/F8/F4 starting the program) clears the program's terminal first, so what an earlier run left there is gone; Continue does not. When the program ends (not when it stops at a breakpoint, `PAUSE`, an error or BREAK), the editor writes `Press any key` under its output and waits for a key on that terminal before showing its own window again; Options ▸ Pause after run turns that off (it is on at start). (Only a real terminal is cleared or paused: with `-t` a file, nothing is written to it and nothing waits.) While it runs, the program's terminal is shown (`$1B $21` written to a path the editor keeps open to it); when `%READY` or a debugger stop comes back, the editor's own window is shown again.
  - A runtime error (`%ERROR`) becomes a message and the cursor goes to its line. The program stays stopped there in the debugger (see below).
- **BREAK:** SCF sends the keyboard interrupt to the last process that used the terminal. That is `l2b09run` once the program has done I/O there, but it can be the editor, which selected the window. So the editor has a signal handler that passes BREAK and abort on to `l2b09run` while a program runs.
  - A signal ends a waiting pipe read with `E$EOF` (pipeman returns the 0 bytes read so far). The handler sets a flag so the read is tried again instead of taken for the end of the pipe.
- **Known: `WILD("BMStatus")` and the 16K default (2026-10-18).** NitrOS-9's `WILD` module starts `BMStatus` with an `F$ClrBlk` on an uninitialised stack word, so it unmaps a block it never mapped. In `l2b09run`'s 16K workspace that block is a live one, and a program that calls it (Basic09's `samples/paint` on `q`) crashes the machine; with 8K it happens to be harmless. Use `-m=8` or Options ▸ Memory… 8 for such programs until `WILD` is fixed; the editor's default stays 16K.
- **Workspace size:** when a load prints `ERROR #032` (memory full, at any point: Basic09 reports it from the compiler as a bare error, or from the binder as `%BERR 32`), Make sends `mem <8K more>` and loads again; every procedure it sent is sent again. It stops when `mem` gets less than it asked for (it prints the size it has) or at 56K. A procedure cut short by memory full also brings error-74 "Undefined Line Number" noise for the lines past the cut; the retry clears it. Options ▸ Memory... asks for a size in KB and sends `mem` too, or keeps it for the next start if `l2b09run` is not running; not while a program is stopped (`mem` moves the workspace's top). `mem` runs from the overlay `l2b09ovl`.
- **User screen:** F5 (Run ▸ User screen) shows the program's terminal until a key is pressed there.

## Global TYPE lines

Basic09 has no global variables, and every procedure that shares a record (a context record passed as `PARAM g:ctx`) has to repeat its `TYPE` by hand. The editor supplies the TYPE lines from one place instead. `l2b09run` is unchanged.

```
DEFTYPE shapes
TYPE pt=x,y:REAL           (* a point *)
TYPE box=corner:pt; w,h:REAL
END DEFTYPE

PROCEDURE main
USE shapes
DIM p:pt
```

- **`DEFTYPE <name>` … `END DEFTYPE`:** a block of `TYPE` lines anywhere in the file: before the first procedure or between procedures. It is not a procedure: Make never sends it, Run never starts it, and pretty print, breakpoints and `kill` leave it alone. A `DEFTYPE` line ends the procedure before it, as a `PROCEDURE` line does. Lines after `END DEFTYPE` up to the next `PROCEDURE` belong to nothing (like text before the first procedure). The lines in a block are not compiled on their own, so a `TYPE` line may carry a comment without a backslash. Its name must not be a procedure's: both are in Make's table (`PF.DEF` marks a block).
- **`USE <name>`:** a line of its own in a procedure that needs the types, before its `DIM` and `PARAM` lines. Any case; spaces before it are allowed.
- **What Make sends:** the `USE` line goes to `l2b09run` as every `TYPE` line of the block, joined by backslashes and without their comments, then `(* ` and the line itself: `TYPE pt=x,y:REAL \ TYPE box=… \ (* USE shapes`. The comment has to come last, because a `(*` comment runs to the end of the line. One line keeps every source line one I-code line, so error lines, breakpoints, debugger stops and pretty print stay right; an error in the TYPE text shows on the `USE` line. The TYPE text is cut at 200 characters (`TYMAX`) so that the line fits `l2b09run`'s 256; more types go in a second block with its own `USE` line. If there is no such block, the line goes as it is, and the compiler reports it.
- **Changes:** a block has a signature like a procedure's. When a block changes (or goes), the procedures that `USE` it are sent again (`mk_uses`).
- **Pretty print:** `LIST` shows the joined line, so for a procedure with `USE` lines pretty print follows the text line by line and puts the user's `USE` line back in place of `LIST`'s, indented like the body (`pp_use`). It replaces a procedure's lines only up to the next `PROCEDURE` or `DEFTYPE` line.
- **Colours:** `DEFTYPE` and `USE` are keywords (`tools/mkkw.py`, `EXTRA`).
- **Not handled:** `l2b09ctl` and stock Basic09 do not know `DEFTYPE` or `USE`; a file that uses them needs the editor.

## The debugger

- **Stops:** a program stops in the debugger at a breakpoint, a `PAUSE` statement, a BREAK, a runtime error, or (with Until return) on its way back to a procedure. `l2b09run` then sends `%DEBUG <proc> <line>`, and the editor stays in the debugger until the program ends or is reset:
  - the line it stopped at is drawn white on red (1 on 2) across the window, or in reverse video with colours off, and the cursor goes there (the window moves only if that line is not in it);
  - the hint line lists the debugger keys;
  - a stop in a procedure that is not in the text says `Stopped in <proc> line <n>`.
- **Step (F7, Debug ▸ Trace into):** `step`. A step on a `RUN` line stops at the called procedure's first statement, and stepping through its END stops back in the caller. The first stop at a `PAUSE` is on the `PAUSE` line itself, so the first step only moves on. If the program is not running, F7 (and F8) Make, then start it with `step <first procedure>`, which stops before its first statement.
- **Step over (F8, Debug ▸ Step over):** `over`. Like step, but a `RUN` runs the whole call and stops at the next statement of the caller, unless a breakpoint (or a `PAUSE`, BREAK or error) stops it inside first.
- **Continue (^R, Run ▸ Run):** `cont`. The program's terminal is shown while it runs, as for Run.
- **Program reset (^P, Run ▸ Program reset):** `q`. The program ends and `l2b09run` is back in command mode.
- **Make while stopped:** Make (and ^R) sends nothing while the text matches what was loaded. If the text changed, it asks "reset the program (Y/N)?":
  - **Y** resets (`q`), then loads, and ^R then starts the program again;
  - **N** loads nothing (the changed procedures are sent at the next Make), and ^R continues the old code;
  - **Esc** does neither.
  Step and evaluate always use the code that is loaded.
- **Evaluate (^E, Debug ▸ Evaluate):** asks for an expression, starting with the word at the cursor (or the last expression), sends `print <expr>`, and shows `<expr> = <value>`. `<name>:=<value>` sends `let` first, then shows the new value. An error shows its text from `/dd/sys/errmsg`.
- **Watches (^W, Debug ▸ Add watch):** up to 6 expressions, printed again at every stop. They are shown numbered in a watch window above the message window, as `<n> <expr>: <value>`. Values are cleared when the program ends. An expression that is not valid where the program stopped (a variable of another procedure) shows its error, for example `Error 49 Undefined Variable`. Debug ▸ Delete watch asks for a watch's number, or 0 for all of them.
- **Breakpoints (^T):** ^T sets or clears a breakpoint on the cursor line; at most 8.
  - **Moving with the text:** each is a tracked position at the carriage return that ends its line, so edits move it with the text. Enter at the end of the line leaves it on that line, Enter at its start moves it down with the text, and joining the line to the next one keeps it on the joined line. Open and New clear them.
  - **In `l2b09run`:** the runtime keeps its own table, by procedure and line (`bp`/`bc`, PROTOCOL.md), and a load or kill clears it. So before the program next runs, continues or steps, the editor sends them all again if anything changed: it scans the text for the procedures' lines as they are now, sends `bc` if the runtime holds any, then `bp <procedure> <line>` for each.
  - **Not sent:** a breakpoint outside a procedure, on a `PROCEDURE` line, or past its end (`l2b09run` answers `What?`), or in a procedure changed since it was loaded (after N at "reset the program?").
  - A breakpoint on a line that never runs (`DIM`, `PARAM`, `TYPE`) never stops the program.
- **Run to the cursor (F4, Run ▸ Go to cursor):** Make, then a breakpoint on the cursor line for this run only, then `cont` (or `run <first procedure>`). `l2b09run` can only clear all its breakpoints, so after the stop the editor sends them again (`bc`, then the real ones) before the program next runs. If the line is not a statement of a loaded procedure, the hint line says so and nothing runs.
- **Until return (Debug ▸ Until return):** asks for the name of a procedure in the call chain and sends the debugger's `BREAK <proc>`. The next ^R runs until the program returns to that procedure. It works as a "step out" when given the caller's name.
- **Protocol:** `print` and `let` output comes back on the channel before the next `%DEBUG`. The editor keeps the last text line as the answer, and ignores the `%ERROR` event an invalid `print` can cause. The `ERROR #<n>` line says the same.
- **Quitting** while stopped sends `q` before `bye`.

## Testing

- **Scripted keys:** `tools/keys.py` compiles a readable key script (`"text"`, `up`, `^g`, `pgdn*3`, …) into the bytes the editor reads. When path 0 is not a terminal, `SS.KySns` fails, so keys that need modifier bits are sent as `$FF <kysns> <char>`. The mouse is sent as `$FE <buttons> <column> <row>` (`click:C,R`, `press:`, `drag:`, `release:`, `rclick:`, `mouse:B,C,R`); the script's clock does not run, so a second press on the same cell is a double click.
- **Live input:** a test directory's `lua` file is a MAME autoboot script. It can type with `natkeyboard:post` and move the mouse and press its buttons through the `MOUSEX`, `MOUSEY` and `MOUSE_BUTTONS` ports. The pointer moves by PS/2 deltas, so the script sends it home to 0,0 before each move, and keeps the axis values positive (MAME clamps them at 0).
- **Test data:** a test directory's `gen` script writes generated files, which are copied into the image unchanged (see `tools/emu-wildbits.sh`).
- **`make p5atest` (P5.1):** `test/p5a/gen` builds a 3,000-line, 129 KB file and a key script. It also runs the same operations through a Python model of the editor's commands to produce the expected file. The editor runs with `-c=3` (so it swaps constantly), with keys from the script and the screen on `/vt3`. It saves, and the result must match the model byte for byte.
  - **Covered:** go to line, typing, Enter with indent, Backspace joining lines, Delete, delete line (200 in a row: page joins and removals), 40 inserted lines (page splits), vertical moves keeping the column, word moves, start/end of the line, top/bottom, page down, save and quit.
- **Model:** `tools/edmodel.py` holds the Python model of the editing commands, selection and clipboard included. A `Session` records the key script alongside the model, so p5a and p5c build both from one list of operations.
- **`make p5ctest` (P5.2b):** a 64 KB file with a 4-page cache. It covers typing over a selection, cut and paste of lines, word selection, a selection across lines deleted, an upward selection, Esc and plain moves ending a selection, a 300-line cut pasted inside a line, and select all, copy and two pastes (the result is 196 KB). The saved file must match the model.
- **`make p5dtest` (P5.2c):** a match across a page boundary, typing over a match, find next, Match case on and off, Replace answered Y/N/Esc, then Replace answered A (1,443 replacements), and a search that finds nothing. The result must match the model.
- **`make p5etest` (P5.2d):** undo and redo of grouped typing, Delete and Backspace, ^D, cut and paste, 1,500 replacements undone 60 times (only 50 records are kept), select-all delete undone and redone, and an edit that ends redo. The result must match the model, which follows the same grouping rules.
- **`make p5itest` (P5.6):** `test/p5i`. A small file is drawn with the screen going to a file, and `test/p5i/check` finds the blue background, the grey menu bar, the white frame and the expected colour codes around a keyword, a string, `REM`, `FOR`/`TO`, a number, `$hex`, a function, a real and `(* *)`. Then the benchmark: 150 page-downs through a 5,000-line file with colours on and off, timed with `date -t`. Last, a `-h` session presses Enter at the start of a line, and the snapshot must show that row empty (the row above the cursor is redrawn too).
- **`make p5jtest` (P5.6):** `test/p5j`. A procedure with no indent, lower-case keywords, odd spacing, a line number, a line longer than `LIST`'s margin and a breakpoint is pretty printed (keywords in lower case) and saved; the other one has a lower-case `procedure` line. Pretty printing it again changes nothing. One ^Z brings back the original exactly, and ^Y redoes it. ^R then sends nothing (it counts as loaded) and stops at the breakpoint on the same statement. With Keyword case switched to capitals, Ctrl+Space (All: pretty print) does both procedures, and a real reload compiles the pretty text without errors. Four saved files and the whole protocol log must match.
- **`make p5htest` (P5.5):** `test/p5h`. F7 starts the program (`step`), F8 steps over, a breakpoint in a called procedure stops a Continue and then an F8 over its `RUN`, ^T clears it at the stop, F4 runs to the cursor from a program that is not running and again from a stop, and a line inserted above a breakpoint moves it (it is sent again with the new line after Make). The whole protocol log must match `log.exp`, and the saved file must match. A second session with `-h` sets two breakpoints and checks their marks in the snapshot.
- **`make p5gtest` (P5.4):** `test/p5g`. A session steps from a `PAUSE` into a called procedure and back, with three watches (one of them invalid in the callee), sets a variable with ^E and evaluates an invalid one, deletes a watch, continues into a subscript error (55), resets, runs again, and uses Until return. The whole protocol log must match `log.exp`, and the program's output must show the value that was set. A second session with `-h` leaves the screen up, and the checks read the watch window and the hint line from the snapshot in `mame.log`.
- **`make p5ftest` (P5.3):** `l2b09run` with `-t=` a file and `-l=` a log. A three-procedure program with two compile errors: Make, fix the first at the cursor, ^N to the second and fix it, Make again (only those two are sent), Run, add a call that fails with error 45, Run (only `main` is sent; the cursor goes to the failing line), then rename a procedure and Make: the program is stopped at the error, so Make asks, and Y resets it before the `kill` and the load. The saved file and the whole protocol log must match. A second session uses the `/vt` factory and a program that sends BREAK (`S$Intrpt`) to its parent, the editor, which passes it on; the program stops, ^P resets it, a second Run sends nothing new and stops again, and quitting sends `q` before `bye`.
- **`make p5ktest` (P5.7):** `test/p5k`, the mouse from a key script. A press on the left border sets a breakpoint that Run then stops at. A click and typing place text, a drag selects for a cut, and a right press extends a selection. A press outside the ^G dialog cancels it, File ▸ Save as is chosen by the mouse, a double click on a Make error goes to its line, and ^Q is answered by a press on the `Y`. Two saved files and the log are checked. A second session with `-h` drags past the bottom of the window (it scrolls two lines) and sets and clears breakpoints by the mouse; the snapshot shows the marks.
- **`make p5ltest` (P5.7):** `test/p5l`, the real keyboard and mouse on `/term`, driven by the MAME script `test/p5l/lua`. It types after clicks on two lines, sets a breakpoint on the left border, and runs the program from the Run menu by pressing on its title, dragging down and releasing on Run. The snapshot must show the edits and the stop on the breakpoint's line.
- **`make p5qtest` (P5.7):** `test/p5q`, the workspace size. A generated procedure too big for 8K, with `-m=8`: Make's load runs out of memory twice, the editor grows the workspace to 16K and then 24K and the load succeeds; then Options ▸ Memory... sets 24K. The protocol log must show the `mem` commands and what they got.
- **`make p5rtest`:** `test/p5r`, the help browser. On its own with the screen going to a file: a word with no page lists the names that start with it and Enter opens the first; Right, Enter follows a link and Backspace comes back; a word with no match opens the contents. From the editor (screen to a file): F1 in `LEFT$` opens its page and Esc returns. Then with `-h` (passed on to the viewer): after F1 and Esc the snapshot shows the editor drawn again, the cursor where it was.
- **`make p5stest`:** `test/p5s`, global TYPE lines. A `DEFTYPE` block comes before `main` (Run must still start `main`) and another, unused, between `main` and `show`; both procedures `USE` the first (one in lower case, indented). Make sends only the procedures, and Run prints the record's size, 10. A field is added to the block alone; the next Make sends both procedures again and Run prints 15. Pretty print keeps the `USE` lines and leaves both blocks alone, and a last Make sends nothing. The protocol log (with the joined lines in `LIST`) and the saved file must match.
- **`make p5ttest`:** `test/p5t`, the mouse wheel from a key script. In the help browser, two steps down on the Errors page bring in its 33rd line. In the editor, on a 60-line text, two steps down and one up leave line 4 at the top of the window with the cursor on it.
- **`make p5utest`:** `test/p5u`, a program that prints `it` on a `/vt` terminal, run twice, Esc answering each pause; F5 shows that terminal (`-h`): `it` once on the top row, `Press any key` under it.
- **`make p5vtest`:** `test/p5v`, the same with Options ▸ Pause after run turned off: `it` once, and no prompt.
- **`make p5ptest` (P5.7):** `test/p5p`, the screen switch live in MAME. The script counts the grey pixel rows down one column (menu bar, its gap row, hint line), which tell 80×30 from 80×60 and single from double spacing, through four switches; then quits on 80×60 and checks the shell is back on 80×30.
- **`make p5otest` (P5.7):** `test/p5o`, double spacing from a key script on the 80×30 screen. The snapshot must show the text on the even rows, the borders and the scroll bar's track on the gap rows, the gap rows clean after a dialog, and a press on logical row 5 typing on line 4.
- **`make p5ntest` (P5.7):** `test/p5n`, the scroll bar from a key script (drawn in ASCII: `^` `v` arrows, `:` track, `#` thumb). Two clicks on ▼, a click on the track, the thumb dragged to the bottom and a click on ▲, each followed by a letter typed; the saved file shows where the cursor went, and the snapshot the window and thumb.
- **`make p5mtest` (P5.7):** `test/p5m`, the highlights in colour, which the text snapshot cannot show: the MAME script reads the pixels of a cell's blank top row. A Shift+arrow selection, Esc ending it, the ^F dialog opening and closing on Enter with the match selected, and Run ▸ Go to cursor stopping on its line in white on red.
- **`make p5btest` (P5.2a):** File commands through keys, menus and dialogs. It covers Save with no name (Save as), Open, File ▸ Save by its letter, New, Options ▸ Auto indent, Quit answered with Esc and then Y, and File ▸ Save as chosen with the arrows. Three saved files must match.
