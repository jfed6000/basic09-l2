# l2basic09

A Level 2 (NitrOS-9) Basic09 development environment built from the original Microware Basic09 source.
- **Goal:** an editor process drives `l2b09run` (compiler, runtime and debugger) over pipes, and programs can use memory beyond 64K.
- **Design and roadmap:** `docs/ARCHITECTURE.md`. It records what each phase (P0–P7) did and what was found.
- **Reference specs:** `docs/PROTOCOL.md` (the editor/runtime protocol), `docs/FARMEM.md` and `docs/FARARRAYS.md`.
- **Proposals and decisions not built yet:** see "Risks and open questions" and the naming plan under "Name" in `docs/ARCHITECTURE.md`. They cover the cold-command overlay, the automatic workspace size, `runb-l2`, and the multi-language editor as a separate project.
- **Repository:** https://github.com/jfed6000/basic09-l2. Besides `main`: `p5.6` (merged) and `mouse-wip` (parked mouse work).

## Ground rules

- **6809 only.** No 6309 work. The stock `H6309` conditionals stay as they are.
- **Machine-neutral names** (`l2b09*`). Wildbits is only the first test target; a CoCo 3 port is possible. Machine-specific code goes behind conditionals.
- **Stock builds stay byte-identical.** All l2basic09 changes to `src/` sit behind `ifne L2B09` / `ifeq L2B09`. Run `make check` after touching `src/`, and also compare `build/basic09_6809` against a build from the NitrOS-9 tree.

## Build and test

- **Toolchain:** `lwasm` and `os9` (toolshed).
- **NitrOS-9 tree:** `NITROS9DIR` defaults to `~/projects/wild/joust/nitros9_complete/nitros9`. Only its `defs/`, its MAME build (`mame/mame`, machine `wbjr2`) and its Level 2 image are used.
- **Two NitrOS-9 trees until MAME catches up.** The Longview core (rc22+) moved the device pages to `$FC`-`$FF`; `~/projects/wild/main/nitros9` (tracks main) supports it, but the Wildbits MAME (`~/projects/wild/mame`) doesn't run it yet. Emulator tests stay on the joust tree; `make k2main`/`jr2main` build hardware images from the main tree through `recipes/` (`recipes/README.md`). New disk images go in a recipe there, built from the main tree's sources, not by patching a stock image. Stick to the defs: no hardware addresses in our code.

| Command | What it does |
|---|---|
| `make` | Stock variants, `build/l2b09run`, `farmem`/`syscall`/`inkey`, `build/l2b09ctl`. |
| `make check` | Byte-compare the stock builds with the NitrOS-9 tree's prebuilt copies. |
| `make p1test` … `p4test`, `p5atest` … `p5jtest`, `p6test`, `p7test` | Headless emulator tests; each prints PASS/FAIL lines. |
| `make loadtime` | Compile-speed benchmark. |
| `make k2main`, `make jr2main` | Hardware images for the new core from the main tree: `recipes/wildbits/basic09-l2/l2_basic09-l2{k2,jr2}.dsk`. |
| `make k2img`, `make jr2img` | `build/l2b09_k2.dsk` / `build/l2b09_jr2.dsk`: the stock K2 or Jr2 image plus the pipe modules in OS9Boot, the editor and runtime in CMDS, and `examples/` in `/dd/l2b09`, for real hardware. |

**Emulator harness:** `tools/emu-wildbits.sh <testdir>` copies the image into `build/emu/<test>/`, installs the test, boots MAME headless, then fetches the results.
- A test directory holds a `run` script (OS-9 shell), plus optional `modules`, `bootmods`, `fetch` and `expect` files, and a `gen` script whose output is copied in unchanged (binary).
- `expect` lines are `<file> <text>`, or `same <fileA> <fileB>`.
- Output lands in `build/emu/<test>/`, and `mame.log` ends with a text-screen snapshot.

## Code map

- **`src/`: Microware modular source.** Modules call each other through jump tables: `X$` offsets in `jmpdefs`, `J$` stubs in each file.
  - `comand.asm` (plus `editor`, which is included at its end) holds the commands, LOAD, the debugger, the decompiler and the l2basic09 additions.
  - `stmts.asm` is the statement interpreter, including code banking (`L2RSLV`/`L2MAPW`).
  - `compil`, `binder`, `exprsn` and `cnvio` are the compiler, binder, expression interpreter, and conversion/I/O.
  - Direct-page variables are in `b09defs`; `L2B09` variables go after `BufOvf`.
  - `L2B09` builds also get `-DLevel=2`.
  - The runtime's direct page is full (1 byte left). Put new tables in the workspace, as the breakpoint table at `G.DIRA+$100` is (ARCHITECTURE.md, P5.5).
- **`modules/`:** Basic09 subroutine modules (`farmem`, `syscall`, `inkey`).
- **`os9/`:** OS-9 tools. `l2b09ctl` is a scripted editor stand-in for the protocol. `basic09-l2/` is the editor, `basic09-l2` (formerly `l2b09ed`; P5, docs/EDITOR.md); it builds without `undefextern` and without `--6309`.
- **`tools/`:** host tools (the emulator runner, `bootfile-add.py`, `keys.py` for editor key scripts, `edmodel.py`, a Python model of the editor's commands used to generate expected files, and `mkkw.py`, which regenerates the editor's keyword table `os9/basic09-l2/kwtab.asm` from `KEYTAB`).

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
- **The screen snapshot** in `mame.log` puts a `|` at each end of every row, so the row starts one character after `NN: |`. Characters above `$7E` show as `#`.
- **`SS.FntChar` (Wildbits)** takes the font set from the caller's A register. For `I$SetStt` that is the path number, so path 0 means font set 0.
- **Hung tests.** A test that hangs (for example an `expect` that never matches) shows up as short or missing output files, because the files are never closed. `run.out` is empty too if any later step hangs. To watch progress, run `l2b09run -t=/term` in a scratch test: `mame.log` ends with a screen snapshot.
- **The top 8K slot is not all RAM.** On Wildbits, `$FD00-$FFFF` is fixed whatever is mapped in slot 7 (on the CoCo 3, `$FE00-$FFFF`). `F$MapBlk` returns the highest free slot, so a window there must stay below `$1D00`.
  - `F$Link` keeps a module out of slot 7 once the module passes 23,808 bytes. `l2b09run` is past that, which is why `L2GARD` exists (ARCHITECTURE.md, P7).
  - Watch `build/l2b09run`'s size: getting it back under the limit frees a slot.
  - **Hard limit: 24,576 bytes** (three 8K blocks). Past it the code takes a fourth slot, and `make p7test` fails with 207 (`#24k -b=64` has no slot left for the data window). P5.5 hit this; `make` prints a warning.
- **Record field names share the symbol table** with variables. `TYPE pt=x,y:REAL` makes `x` unusable as a variable in that procedure (error 76).
