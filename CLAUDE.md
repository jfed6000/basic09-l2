# l2basic09

A Level 2 (NitrOS-9) Basic09 development environment built from the original Microware Basic09 source.
- **Goal:** an editor process drives `l2b09run` (compiler, runtime and debugger) over pipes, and programs can use memory beyond 64K.
- **Design and roadmap:** `docs/ARCHITECTURE.md`. It records what each phase (P0–P7) did and what was found.
- **Reference specs:** `docs/PROTOCOL.md` (the editor/runtime protocol), `docs/FARMEM.md` and `docs/FARARRAYS.md`.
- **Proposals and decisions not built yet:** see "Risks and open questions" and the naming plan under "Name" in `docs/ARCHITECTURE.md`. They cover the cold-command overlay, the automatic workspace size, `runb-l2`, and the multi-language editor as a separate project.
- **Repository:** https://github.com/jfed6000/basic09-l2. Besides `main`: `p5.6` (merged) and `mouse-wip` (the first mouse attempt, superseded by P5.7); the separate compiler was built on the local branch `separate_compiler`, merged 2026-10-20.

## Ground rules

- **6809 only.** No 6309 work. The stock `H6309` conditionals stay as they are.
- **Machine-neutral names** (`l2b09*`). Wildbits is only the first test target; a CoCo 3 port is possible. Machine-specific code goes behind conditionals.
- **Old programs must run on basic09-l2 (the compatibility rule).** Basic09 source files load, compile and run unchanged, and PACKed I-Code modules from stock Basic09 or built for stock RunB run under `l2b09run`, by name and with arguments. New programs on stock Basic09 are best effort: PACK output without new features should still run under stock RunB, and PACK refuses what it cannot. Keep the I-Code and module formats compatible. Tests: p1 and p4 (the image's stock basic09/runb), p8a, p8d. (ARCHITECTURE.md.)
- **`src/` is basic09-l2's own source,** forked from Microware's on 2026-10-20 (`src/MICROWARE.md`, `tools/l2fork.py`). There are no stock builds and no `make check` any more; the pristine source is in the NitrOS-9 tree. Conditionals that remain: `L2B09RT` (runtime), `L2B09CC` (compiler), `INCLUDED`/`EDITOR`, `H6309`, machine.

## Build and test

- **Toolchain:** `lwasm` and `os9` (toolshed).
- **NitrOS-9 tree:** `NITROS9DIR` defaults to `build/main/src/nitros9`, an export of the nitros9project clones in `~/projects/wild/main` that every `make` refreshes when a clone's HEAD changes (`recipes/export-main.sh`). Its defs, pipe modules, stock Level 2 image (`build/main/l2_wildbitsjr2.dsk`, the tests' `BASEIMG`) are used (the image has the stock basic09 and runb that p1 and p4 run). MAME is `~/projects/wild/mame/mame` (machine `wbjr2`, Longview core).
- **The main clones stay pristine.** The Longview core (rc22+) moved the device pages to `$FC`-`$FF`; the clones in `~/projects/wild/main` (`nitros9`, `-languages`, `-apps`, `-games`) support it. Never build in them or write to them: everything builds in the export (`recipes/README.md`). The old-core joust tree (`~/projects/wild/joust/nitros9_complete/nitros9`) still works with `NITROS9DIR=` and `BASEIMG=` overrides, but MAME no longer shows its screen. New disk images go in a recipe under `recipes/`, built in the export, not by patching a stock image. Stick to the defs: no hardware addresses in our code.

| Command | What it does |
|---|---|
| `make` | `build/l2b09run`, `l2b09cc`, `l2b09ovl`, `farmem`/`syscall`/`inkey`, the editor, the help browser, `build/l2b09ctl`. |
| `make p1test` … `p4test`, `p5atest` … `p5xtest`, `p6test`, `p7test`, `p8atest` … `p8dtest` | Headless emulator tests; each prints PASS/FAIL lines. `p8atest` is the reference for the separate compiler (docs/COMPILER.md); `p8btest` checks `l2b09cc`'s frames; `p8ctest` checks that its procedures are byte-identical to LOAD's. |
| `make loadtime` | Compile-speed benchmark. |
| `make main` (`k2main`, `jr2main`) | New-core images built in an export of the main repos: `build/main/l2_wildbits{k2,jr2}.dsk` (stock, for tests) and `l2_basic09-l2{k2,jr2}.dsk` (for hardware). |
| `make k2img`, `make jr2img` | `build/l2b09_k2.dsk` / `build/l2b09_jr2.dsk`: the same as `l2_basic09-l2{k2,jr2}.dsk` from `make main`, made by patching the stock image's OS9Boot instead of the recipe. |

**Emulator harness:** `tools/emu-wildbits.sh <testdir>` copies the image into `build/emu/<test>/`, installs the test, boots MAME headless, then fetches the results.
- A test directory holds a `run` script (OS-9 shell), plus optional `modules`, `bootmods`, `fetch` and `expect` files, a `gen` script whose output is copied in unchanged (binary), and a `lua` MAME autoboot script for live keyboard and mouse input (`test/p5l`); it can read colours from the screen's pixels (`test/p5m`).
- `expect` lines are `<file> <text>`, or `same <fileA> <fileB>`.
- Output lands in `build/emu/<test>/`, and `mame.log` ends with a text-screen snapshot.

## Code map

- **`src/`: Microware modular source.** Modules call each other through jump tables: `X$` offsets in `jmpdefs`, `J$` stubs in each file.
  - `comand.asm` (plus `editor`, which is included at its end) holds the commands, LOAD, the debugger, the decompiler and the l2basic09 additions.
  - `stmts.asm` is the statement interpreter, including code banking (`L2RSLV`/`L2MAPW`).
  - `compil`, `binder`, `exprsn` and `cnvio` are the compiler, binder, expression interpreter, and conversion/I/O.
  - Direct-page variables are in `b09defs`; l2basic09's go after `BufOvf`.
  - The builds get `-DLevel=2`.
  - The runtime's direct page is full (the last byte, `$FF`, is `L2CCP`). Put new tables in the workspace, as the breakpoint table at `G.DIRA+$100` is (ARCHITECTURE.md, P5.5).
- **`l2b09cc`** (docs/COMPILER.md): the separate compiler, `l2b09run`'s source built with `-DL2B09CC=1`; LOAD sends each bound procedure to stdout as `%PROC <bytes> <name>` plus the bytes. In `l2b09run`, `ccload`/`cccmp <file>` fork it and load or compare through it (step 2; the two pipe paths are in the last direct-page byte, `L2CCP`). `tools/ccframes.py` checks that output; in a test's `fetch` file, `raw:<file>` fetches a binary file unchanged.
- **`modules/`:** Basic09 subroutine modules (`farmem`, `syscall`, `inkey`).
- **`os9/`:** OS-9 tools. `l2b09ctl` is a scripted editor stand-in for the protocol. `basic09-l2/` is the editor, `basic09-l2` (formerly `l2b09ed`; P5, docs/EDITOR.md); it builds without `undefextern` and without `--6309`. `l2b09help/` is the help browser (docs/HELP.md); it includes the editor's `term.asm` and `keys.asm`.
- **`help/`:** the help pages (`*.txt`), compiled by `tools/mkhelp.py` into `build/basic09-l2.hlp`, which checks that every Basic09 keyword and error has a page.
- **`tools/`:** host tools (the emulator runner, `bootfile-add.py`, `keys.py` for editor key scripts, `edmodel.py`, a Python model of the editor's commands used to generate expected files, `mkkw.py`, which regenerates the editor's keyword table `os9/basic09-l2/kwtab.asm` from `KEYTAB`, and `b09prof.py`, a MAME read-tap profiler for `l2b09run`: `b09prof.py lua <counts> > <testdir>/lua`, run the test, then `b09prof.py report <counts>`).

## Gotchas learned the hard way

- **`TFR` sets no flags.** Use `leax ,y` (or a compare) when the next branch needs Z.
- **`LEAU`/`LEAS` don't set Z** (only `LEAX`/`LEAY` do). A `leau -1,u` / `bne` loop never ends, so count with X or Y, or add `cmpu #0`.
- **Branch range.** Inserting code inline often pushes 8-bit branches (`bsr`, `beq`, ...) out of range ("Byte overflow"). Put new code in a subroutine somewhere else and call it with `lbsr`, or make that one branch long under `ifne L2B09`.
- **`J$` calls clobber registers.** Cross-module calls through the jump tables keep nothing, so hold values on the stack across them (`L2BSTM` once lost `P.STAT` in B this way).
- **Symbols are case-insensitive** (`nosymbolcase`), so a constant `NWATCH` clashes with a variable `nwatch`.
- **Hidden undefined symbols.** The build uses the `undefextern` pragma, which hides undefined symbols. After changing `src/`, reassemble the touched files with `lwasm.orig` without `undefextern` (see the git history for the exact command) to catch them.
- **The lwasm wrapper** writes `.map`/`.list` files into the current directory, so run it inside `build/`.
- **Pipes:**
  - The pipe modules must be in OS9Boot (use `bootmods`); loading them at runtime fails with 237.
  - Named pipes don't work on NitrOS-9's IOMan.
  - Pipes can't be polled.
  - A signal that arrives during a waiting pipe read ends it with `E$EOF`, just like the real end of the pipe.
- **OS-9 shell:**
  - `>>` redirects stderr; it does not append. It also fails with 218 if the file already exists.
  - `!` is a pipe, even inside `echo`.
  - `#mem` must come straight after the command name.
  - Basic09 `PRINT a;b` adds no spaces, so write `expect` text to match.
- **Stock Basic09 quirks:**
  - A second PACK fails with 51, because PACK strips the workspace copy.
  - `DATE$` prints 2026 as `<6`.
- **MAME's `wbjr2` keyboard has no function keys, and its mouse no wheel:** F1-F8 and the wheel can only be sent from key scripts (`f1`, `wheel:N`), not from a `lua` test.
- **`WILD("BMStatus")` unmapped a stray block before nitros9 `1e1e20e3` (PR #459, 2026-10-19):** with an older NitrOS-9 and `l2b09run`'s 16K workspace (the editor's default), Basic09's `samples/paint` crashes the machine on `q`; `-m=8` avoids it. MAME cannot run `paint` (it hangs in `BMLoad`, stock `basic09` too), so it was found on hardware by crossing old and new editor, runtime and NitrOS-9 images.
- **The screen snapshot** in `mame.log` puts a `|` at each end of every row, so the row starts one character after `NN: |`. Characters above `$7E` show as `#`.
- **`SS.FntChar` (Wildbits)** takes the font set from the caller's A register. For `I$SetStt` that is the path number, so path 0 means font set 0.
- **Hung tests.** A test that hangs (for example an `expect` that never matches) shows up as short or missing output files, because the files are never closed. `run.out` is empty too if any later step hangs. To watch progress, run `l2b09run -t=/term` in a scratch test: `mame.log` ends with a screen snapshot.
- **The top 8K slot is not all RAM.** On Wildbits, `$FD00-$FFFF` is fixed whatever is mapped in slot 7 (on the CoCo 3, `$FE00-$FFFF`). `F$MapBlk` returns the highest free slot, so a window there must stay below `$1D00`.
  - `F$Link` keeps a module out of slot 7 once the module passes 23,808 bytes. `l2b09run` is past that, which is why `L2GARD` exists (ARCHITECTURE.md, P7).
  - Watch `build/l2b09run`'s size: getting it back under the limit frees a slot.
  - **Hard limit: 24,576 bytes** (three 8K blocks). Past it the code takes a fourth slot, and `make p7test` fails with 207 (`#24k -b=64` has no slot left for the data window). P5.5 hit this; `make` prints a warning.
- **`l2b09run` has no compiler** (built with `-DL2B09RT=1`; compil and binder in RunB form). It forks `l2b09cc` at start-up; every test that runs `l2b09run` needs `l2b09cc /CMDS/l2b09cc` in `modules` and the pipe modules in `bootmods`. `HALT` must not close the pipes (`L2CCPA`); see docs/COMPILER.md, "How it works now".
- **PACK is in an overlay; `l2b09run` has no DIR or RENAME.** `l2b09run` loads `l2b09ovl` (`src/overlay.asm` around `src/pack`) from the execution directory when PACK is typed, and at start-up for `-b` (the far store, `L2STOR`) and the banner (skipped if the overlay cannot be linked). MEM is resident (the editor grows the workspace with it). Every test that runs `l2b09run` has `l2b09ovl /CMDS/l2b09ovl` in its `modules` file, so the banner is there for the logs. The overlay needs a free 8K slot while it runs. The overlay reaches the runtime through `X$` exports; adding a command to it means an entry `LBRA` there, a `ldb #n` stub before `DUMP` in `comand.asm`, and exports for what it calls (or a copy, if it is small).
- **Record field names share the symbol table** with variables. `TYPE pt=x,y:REAL` makes `x` unusable as a variable in that procedure (error 76).
