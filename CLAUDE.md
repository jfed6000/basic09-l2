# l2basic09

A Level 2 (NitrOS-9) Basic09 development environment built from the original Microware Basic09 source.
- **Goal:** an editor process drives `l2b09run` (compiler, runtime and debugger) over pipes, and programs can use memory beyond 64K.
- **Design and roadmap:** `docs/ARCHITECTURE.md`. It records what each phase (P0–P7) did and what was found.
- **Reference specs:** `docs/PROTOCOL.md` (the editor/runtime protocol) and `docs/FARMEM.md`.

## Ground rules

- **6809 only.** No 6309 work. The stock `H6309` conditionals stay as they are.
- **Machine-neutral names** (`l2b09*`). Wildbits is only the first test target; a CoCo 3 port is possible. Machine-specific code goes behind conditionals.
- **Stock builds stay byte-identical.** All l2basic09 changes to `src/` sit behind `ifne L2B09` / `ifeq L2B09`. Run `make check` after touching `src/`, and also compare `build/basic09_6809` against a build from the NitrOS-9 tree.

## Build and test

- **Toolchain:** `lwasm` and `os9` (toolshed), from `~/projects/coco-shelf/bin`.
- **NitrOS-9 tree:** `NITROS9DIR` defaults to `~/projects/wild/joust/nitros9_complete/nitros9`. Only its `defs/`, its MAME build (`mame/mame`, machine `wbjr2`) and its Level 2 image are used.

| Command | What it does |
|---|---|
| `make` | Stock variants, `build/l2b09run`, `farmem`/`syscall`/`inkey`, `build/l2b09ctl`. |
| `make check` | Byte-compare the stock builds with the NitrOS-9 tree's prebuilt copies. |
| `make p1test` … `p4test`, `p6test` | Headless emulator tests; each prints PASS/FAIL lines. |
| `make loadtime` | Compile-speed benchmark. |

**Emulator harness:** `tools/emu-wildbits.sh <testdir>` copies the image into `build/emu/<test>/`, installs the test, boots MAME headless, then fetches the results.
- A test directory holds a `run` script (OS-9 shell), plus optional `modules`, `bootmods`, `fetch` and `expect` files.
- `expect` lines are `<file> <text>`, or `same <fileA> <fileB>`.
- Output lands in `build/emu/<test>/`, and `mame.log` ends with a text-screen snapshot.

## Code map

- **`src/`: Microware modular source.** Modules call each other through jump tables: `X$` offsets in `jmpdefs`, `J$` stubs in each file.
  - `comand.asm` (plus `editor`, which is included at its end) holds the commands, LOAD, the debugger, the decompiler and the l2basic09 additions.
  - `stmts.asm` is the statement interpreter, including code banking (`L2RSLV`/`L2MAPW`).
  - `compil`, `binder`, `exprsn` and `cnvio` are the compiler, binder, expression interpreter, and conversion/I/O.
  - Direct-page variables are in `b09defs`; `L2B09` variables go after `BufOvf`.
  - `L2B09` builds also get `-DLevel=2`.
- **`modules/`:** Basic09 subroutine modules (`farmem`, `syscall`, `inkey`).
- **`os9/`:** OS-9 tools. `l2b09ctl` is a scripted editor stand-in for the protocol.
- **`tools/`:** host tools (the emulator runner, and `bootfile-add.py`).

## Gotchas learned the hard way

- **Branch range.** Inserting code inline often pushes 8-bit branches (`bsr`, `beq`, ...) out of range ("Byte overflow"). Put new code in a subroutine somewhere else and call it with `lbsr`, or make that one branch long under `ifne L2B09`.
- **Hidden undefined symbols.** The build uses the `undefextern` pragma, which hides undefined symbols. After changing `src/`, reassemble the touched files with `lwasm.orig` without `undefextern` (see the git history for the exact command) to catch them.
- **The lwasm wrapper** writes `.map`/`.list` files into the current directory, so run it inside `build/`.
- **Pipes:**
  - The pipe modules must be in OS9Boot (use `bootmods`); loading them at runtime fails with 237.
  - Named pipes don't work on NitrOS-9's IOMan.
  - Pipes can't be polled.
- **OS-9 shell:**
  - `>>` redirects stderr; it does not append.
  - `!` is a pipe, even inside `echo`.
  - `#mem` must come straight after the command name.
  - Basic09 `PRINT a;b` adds no spaces, so write `expect` text to match.
- **Stock Basic09 quirks:**
  - A second PACK fails with 51, because PACK strips the workspace copy.
  - `DATE$` prints 2026 as `<6`.
- **Hung tests.** A test that hangs (for example an `expect` that never matches) shows up as short or missing output files, because the files are never closed.
