# l2basic09 Architecture and Roadmap

**Name:** the project is called `l2basic09`. Nothing in any name refers to a specific machine, because it may also run on a CoCo 3.
- Deliverable names follow the same rule: `l2b09c` (compiler), `l2b09run` (runtime/debugger), `farmem`.
- Machine-specific code sits behind conditionals, the way `wildbits` already does.
- **6809 only.** There will be no 6309 version. The existing `H6309` conditionals in the Microware source still build, but new code does not need to support them.
- MMU window sizes come from `DAT.BlSz`, so nothing is hard-coded to one machine. Wildbits and the CoCo 3 both use 8K blocks.
- Wildbits is the first test target, with the CoCo 3 port kept in mind.

## Context
Basic09 today is one Level 1-era process. It holds the line editor, compiler, binder, decompiler, debugger and interpreter, plus all source (stored as I-code) and all runtime data, in a single 64K address space. On Wildbits Level 2, `basic09_wildbits` is about 24K, so it takes 3 of the process's 8 × 8K MMU blocks. That leaves roughly 40K for procedures and data together. RunB (about 12K) is the lean runtime. It has no debugger, and PACK strips symbols out of the modules it runs.

Goal: a Level 2 environment in which:
1. an editor (separate process, maybe a separate project) only edits;
2. a compiler turns the source into I-code modules;
3. a runtime/debugger runs the program, with its own terminal and its own 64K;
4. programs can use memory beyond 64K through the MMU.

**Verdict: this is feasible.** The source is in good shape for it. The canonical Microware modular source (`comand/compil/binder/stmts/exprsn/cnvio.asm`) already assembles with lwasm. It already builds several variants through the conditional flags `INCLUDED=EDITOR|RUNTIM|MATHPAK`, and it already has a `wildbits` flag.

## Key findings from the source (nitros9-languages/basic09/microware)
- **Modules talk through jump tables.** They call each other through `X$xxxx` entry tables (`b09defs`, `linkage`), not direct calls. That makes it realistic to build new variants such as "runtime + debugger, no editor".
- **Command I/O is already separate from program I/O.** The command/debugger paths `BASINP`/`BASOUT` are distinct from the program paths `I.IPTH`/`I.OPTH`. So the debugger can talk on a different terminal from the running program with small changes.
- **The debugger is small and uses a fixed hook.** It is the `DEBUG` routine in `comand.asm` (around line 2490), with the verbs `$ CONT DIR Q LIST PRINT STATE TRON TROFF DEG RAD LET`. The interpreter reaches it at one point, `STMLUP` in `stmts.asm:260`, through `J$DBUG` when the `I.RUNM` debug bit is set. Signals set `G.SIGN` via `INTCPT`.
- **The debugger needs the compiler and decompiler.** `PRINT`/`LET` compile an expression, and `LIST` decompiles. So "runtime + debugger" is really "everything except the interactive line editor/command shell". It is smaller, but not RunB-small.
- **PACK throws away what a debugger needs.** PACK (`DUMP` routine, `comand.asm:1739`) rebinds with `SMASH` cleared, which removes REMs, DIMs and symbol names. A "debug pack" that keeps symbols is a small change.
- **Unpacked procedures are already module-shaped.** Workspace procedures are already laid out like modules (`P.MHDR`, `P.SYMB`, `P.DSCB`, and so on). That makes a disk format for debuggable modules natural.
- **The kernel side is already there.** The Level 2 kernel has `F$AllRAM`, `F$MapBlk`, `F$ClrBlk`, `F$CpyMem`, `F$GPrDsc`, and there are pipes (see the P1 findings for the limits). Wildbits has 8K blocks (`defs/wildbits.d`), and `vt1`–`vt8` give multiple terminals. The `samples/mapblk` sample already maps blocks from Basic09 through the `wild` module.

## Proposed architecture
```
 [Editor process, vtN]      text .b09 source; could be a new full-screen editor
        |  editor forks runtime; anonymous pipes on its stdin/stdout + F$Send for BREAK
        v
 [l2b09c compiler]  text -> I-code -> "debug module" (symbols + line table kept) -> /r0 or file
        v
 [l2b09run runtime/debugger process, own 64K, own vt]  F$Load module, run.
        program I/O -> a /vtN it opens itself;  debugger I/O -> the control pipes
```
- **Hand-off format:** a module file. The Level 2 module directory is system-wide, so `F$Load` gives the runtime the code without a shared-memory trick.
- **Protocol:** plain text lines, easy to test by piping a command file into the runtime (`list cmds ! l2b09run`).
  - Editor to runtime: `LOAD`, `RUN proc args`, `BREAK`, `STEP n`, `CONT`, `TRON/TROFF`, `PRINT expr`, `LET`, `STATE`, `QUIT`.
  - Runtime to editor: `READY`, `STOPPED proc line`, `ERROR code proc line`, `EXITED`.
- **Mapping back to source lines:** Basic09 has no mandatory line numbers, so the compiler must emit an I-code-offset → source-line table in the debug module. This is new, and it is the key enabler for an editor that jumps to the error.
- **Debugger process:** start with it in the same process as the runtime, using the existing hook, with its command paths redirected to a pipe or a second terminal. A truly separate debugger process would only need a thin front-end. Moving the debug engine out of the runtime would need `F$CpyMem` for reads and a stub for writes. That adds a lot of complexity for little gain, so it is deferred.

## Beyond 64K (in order of effort)
1. **The split itself.** Editor and source live in one 64K and runtime plus data in another. That roughly doubles usable space with no language change.
2. **A `farmem` subroutine module**, in the style of `syscall`/`wild`, needing no interpreter change. Calls would look like `RUN farmem("alloc"|"free"|"get"|"put", handle, offset, var)`. It uses `F$AllRAM` and keeps one 8K window mapped with `F$MapBlk`, caching the current block so it avoids a syscall per access. It works with stock RunB immediately. **This is the recommended first step.**
3. **Language-level far arrays** (research phase). For example, `DIM big(50000):REAL` with a FAR storage attribute:
   - the symbol type or descriptor gets a far flag in `compil`/`binder`;
   - the variable-reference path (`X$VREF` in `exprsn.asm`) maps the element's block into a window and returns the window address.
   - Hard parts: elements that straddle a block boundary (align or use 2 windows), and two far operands in one statement (2 windows).
   - This changes I-code, so stock RunB would no longer run these programs.
4. **Code beyond 64K.** External packed procedures are already linked and unlinked on demand. An auto-unlink of cold procedures (an overlay manager) could be added later.

### Transparent memory
- **Swapping from disk vs from memory.** The mechanism is the same: the interpreter finds that code isn't resident and brings it in. From disk, "bringing it in" means a copy that costs milliseconds per sector. With an MMU, it's a remap, with nothing copied. So a RAM-backed version is the same design but far faster, and it needs no swap file.
- **Transparent code banking: a good idea.** Procedures are natural units, I-code is read-only, and the cost only shows up at call and return.
  - How it would work: each procedure's I-code lives in far blocks and is mapped into a code window when it's called. Variables, the stacks and parameters stay in the main 64K.
  - Needs work in: RUN/call/return, the error trap, DATA/RESTORE, and debugger LIST.
  - One limit: a single procedure can't be bigger than the window.
- **Fully transparent data: not a good idea.**
  - Every variable access would pay a check.
  - ADDR/PEEK/POKE and assembly subroutines (syscall, gfx, and so on) all expect 16-bit pointers.
  - Parameters passed by reference would need to carry a "far" flag.
- **Middle ground for data.** Far arrays that the programmer opts into in the declaration, but that are then used with normal syntax.

Pascal's approach is not being copied. OS-9 Pascal swaps P-code from disk, which suits disk-based virtual code but not MMU banking.

## Phases
- **P0 – Project bootstrap (done).**
  - The Microware modular source is in `src/`: the six `.asm` files plus `defs`, `b09defs`, `b09type`, `jmpdefs`, `linkage`, `editor` and `build-modular-basic09.py`.
  - `syscall.asm`/`inkey.asm` are in `modules/`, and the stock samples are in `samples/`.
  - The build takes only the defs directory from `NITROS9DIR`, which defaults to `~/projects/wild/joust/nitros9_complete/nitros9`.
  - `make` builds all five stock variants (6809, 6309, wildbits, and both RunBs). `basic09_wildbits`, `runb_6809` and `basic09_6809` are verified byte-for-byte; the 6309 builds have not been compared yet. `make check` compares `basic09_wildbits` and `runb_6809` against the prebuilt copies in nitros9_complete. `basic09_6809` was checked against a build from that tree.
- **P1 – Prove the pipeline with stock binaries (done).** `make p1test` runs `test/p1` headless under MAME via `tools/emu-wildbits.sh`. All checks pass.
  - What it does: stock basic09, driven by a command file (`load`, `pack*`, `bye`), compiles a three-procedure program into packed modules. RunB runs them (Fibonacci, then an 8K sieve). The same program also runs with its I/O on `/vt2`. basic09 is also driven through an anonymous pipe (`list cmds ! basic09`), including a decompiling `LIST`.
  - Timing (emulated 6.29 MHz, RTC resolution 1 s): compiling and packing about 1 s; the program about 4 s. Host time for a whole boot and test is about 5 s.
  - **Pipes must be in OS9Boot.** Loading `pipeman`/`piper`/`pipe` at runtime fails with `E$NoRAM` (237). The system map has no free 8K DAT slot to map a loaded driver into (IOMan attach / `F$FreeHB`); its free pages sit inside blocks that are already mapped. `tools/bootfile-add.py` inserts modules before `Krn` (the stock pipe modules take the file from 30,464 to 31,232 bytes, of 32,256 allowed; `pipeman_named` would reach 32,000). `bootos9` requires the file to end at `$FE00` with `Krn` at `$EE00`, including the 35 bytes that follow `Krn`.
  - **Named pipes do not work.** `pipeman_named` (Level 2 source) assembles and handles anonymous pipes. But a second process opening an existing named pipe fails with error 190: the `OldPipe` path checks and rewrites IOMan's stack frame (`IOMAGIC`), and NitrOS-9's IOMan does not lay out its stack the way that code assumes. The control channel therefore uses anonymous pipes, with the editor as the runtime's parent (P3).
  - **RunB details.** RunB links its module by name, so a packed file must be `load`ed (or be in the exec dir) first. It also needs a memory size (for example `runb #24k`) when a program has large arrays.
  - **Not yet automated.** An OS-9-side `l2b09make` script was not written, because the OS-9 shell has no parameter substitution. `l2b09c` (P2) replaces it.
- **P2 – Build variants.**
  - Split the `INCLUDED` flags into `EDITOR` (interactive shell + line editor) and a new `DEBUG`/`COMPILER`. The aim is to build `l2b09c` (headless compile + debug-pack) and `l2b09run` (runtime + debugger, no editor).
  - Add debug-pack (skip `SMASH`, keep symbols) plus the line table.
- **P3 – Runtime control channel.** `l2b09run` gets:
  - the debugger's `BASINP`/`BASOUT` on anonymous pipes created by the parent (editor) before `F$Fork`;
  - program paths `I.IPTH`/`I.OPTH` on a `/vtN` the runtime opens itself;
  - the text protocol above;
  - `BREAK` via `F$Send` and the existing `INTCPT`/`G.SIGN`.
- **P4 – `farmem` subroutine module** plus a sample and a benchmark.
- **P5 – Editor integration.** This is either a minimal test client or the real editor, depending on where the editor ends up.
- **P6 – Transparent code banking .**
  - Procedure I-code is kept in `F$AllRAM` blocks and mapped into a code window on RUN; the caller's block is restored on return.
  - Touches: call/return in `stmts.asm`, the error-trap path, `DATA`/`RESTORE`, and debugger `LIST`.
- **P7 – Opt-in far arrays .**
  - Marked in `DIM` and used with normal syntax.
  - The far flag is carried in the symbol type/descriptor (`compil`/`binder`); `X$VREF` in `exprsn.asm` maps the element into a data window.
  - `ADDR` and passing a far array to an assembly subroutine are errors.

## Risks and open questions
- **Stock compatibility.** I-code stays compatible with stock RunB until P6. Far arrays are opt-in.
- **Where the editor lives.** The editor itself (here or a separate project) is undecided. The pipe protocol makes this independent of everything else.
- **Pipes on Wildbits.** Pipes are not in the stock SD boot, so l2basic09 needs a boot file with them (see P1). A CoCo 3 port needs the same check. Named pipes would mean porting `pipeman_named` to NitrOS-9's IOMan.
- **Syscall cost.** `F$MapBlk` costs a syscall per remap, so `farmem` should be measured on hardware or in MAME.

## Verification
- P0: byte-identical rebuilds (`cmp`) against `nitros9_complete/nitros9-languages/basic09/{basic09_wildbits,runb_6809}` (`make check`), plus a `basic09_6809` built from that tree.
- P1+: build a Wildbits disk with the recipe in `nitros9/recipes/wildbits` (or `os9 copy` into an existing image), then run it in MAME (`/usr/games/mame`) or on hardware. Test cases:
  - edit, compile, run in vt2;
  - `BREAK` from the controlling side;
  - the `farmem` sample storing more than 64K and reading it back.
