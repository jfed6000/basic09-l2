# GLOBAL variables: design note

Status: **proposed, not built** (2026-10-24). Planned for after the first release. This note turns the sketch in `docs/OVERVIEW.html` ("How a GLOBAL would fit") into a design. The places marked **Decide** are the user's choices.

## What it is for

Basic09 has no global variables. Today a program shares data through a context record: `TYPE ctx=...` (shared with `DEFTYPE`/`USE` since 2026-10-15), `DIM g:ctx` in `main` and `PARAM g:ctx` in every procedure, passed down on every `RUN`. `GLOBAL` lets each procedure name the shared variables itself:

```
PROCEDURE main
GLOBAL count:INTEGER
GLOBAL board(8,8):BYTE
count=0
RUN move
PRINT count

PROCEDURE move
GLOBAL count:INTEGER
count=count+1
```

Two procedures that declare a `GLOBAL` with the same name share its storage for the whole run.

## Scope of the first version

- **In:** process-wide globals, for one run. Simple variables, arrays and records of every type, declared in each procedure that uses them. They work in `l2b09run` (the editor, command level) and in `runb-l2`.
- **Out, later:** `FAR GLOBAL` arrays (see "Later"); named blocks (`GLOBAL settings` … plus `USE settings`); sharing between processes. Sharing between processes stays with the `global` subroutine module over named data modules (PPM 842), which works with stock Basic09 too and is a separate feature.
- **Never:** stock RunB. Modules that use GLOBAL need `runb-l2`. Stock RunB would treat a global as a local variable and give wrong results without an error. This is the same known issue as far arrays in PACK output, accepted on 2026-10-24.

## How it fits the machine

Every part has a model in the source already.

### The declaration (compiler, `l2b09cc`)

- **Keyword:** add `GLOBAL` to `KEYTAB` (then `tools/kwsort.py` and `tools/mkkw.py`). It compiles to Microware's reserved statement token `T.GLOB` (token 0, `src/b09defs`). The stock compiler can never produce that token, because `GLOBAL` is not in its keyword table, so no old I-code holds it.
- **Syntax:** like `PARAM`, `name[(dims)][:type], ...`, including `STRING[n]` and record types.
- **Symbol kind:** definition value 6 (`$C0`, `S.GLOB`), which is unused: `S.UNDF` to `S.PROC` are 0 to 5 (`b09defs`, "Symbol Table Definition Values"). Stock I-code never has it.
- **Binder:** `PGLOBL` in `binder.asm` (a string expression, shared with `PCHD`) becomes a declaration, as `PPARAM`/`PDIM` are, with `lda #S.GLOB`. Each global gets a **4-byte packet in the link area**, an address and a size, laid out the way a parameter's packet is. The link area is the end of the procedure's storage (from `P.PRCS`), where `RUN` targets and far-array handles already go; `EXECUT` clears it on every call (`EXEC40`). The `DONE` loop moves its offset as it moves theirs (`DONE25`, `L2FDON`). Arrays and records keep their description entries as for `PARAM`.
- **Decompiler (LIST):** prints `GLOBAL`, as it does `PARAM`.
- **Room:** `l2b09cc` is 23,202 bytes, 606 below the slot-7 limit (23,808). The keyword, the parser and binder entries and the decompiler case must fit in that, or `l2b09cc` loses slot 7 (still under 24,576, so it would work with a smaller workspace cap). This is the main constraint, so measure first.

### The access (runtime, `exprsn.asm`)

A global is reached exactly like a parameter, one pointer away through its packet (`VARR11` for arrays, `VARR15` for simple variables and records). In `VARR02`, `DEFNAS` is 0 for a parameter. A global takes the parameter path, with two differences:

1. **No `I.PRLM` check.** A parameter packet past `I.PRLM` was not passed (error 56). A global's packet is in the link area, not among the passed packets, so that check is skipped.
2. **Bound on first use.** The packet starts at 0, because `EXECUT` clears the link area on each call. If the address is 0, the runtime binds the global (below) and stores the address and size in the packet. Later uses in the same call go straight through, the way `RUNSTM` keeps a found procedure in its slot.

That is "resolve early, pay once" (OVERVIEW, "Design rules"): one lookup per global per call, then the speed of a parameter. Code stays reentrant: the packets are in the process's storage, never in the module.

### The global table (runtime)

- **What it holds:** one entry per global: the name, the kind byte (type and shape), the size, and the storage that follows.
- **Binding:** look the name up. If it is found, check it: a different type, shape or size is an error (**Decide:** a new error number, or an existing one such as 56 "parameter error" or 76). If it is not found, add it with its storage cleared to zero. Locals are not cleared; globals are cleared because the table is new for each run.
- **Where it lives (Decide; recommended first):**
  1. **Sized at the start of the run.** Before the first procedure starts, the runtime walks the procedures in the workspace (for `runb-l2`, the modules of the loaded file), adds up their globals, and takes that much from the bottom of the free space (`G.VARS`), under the first procedure's storage. Binding then only looks names up. A procedure loaded during the run (`RUN` of a name found on disk) can add a global only if room was set aside; otherwise it is an error. Recommended: one pass, nothing moves, and it matches "resolve early".
  2. **Grown as globals appear,** from the top of the free space downwards, against the string stack. More general, but the free space shrinks during the run, and it needs a test against the stacks.
- **Lifetime:** the whole run. Under `l2b09run`, a `RUN` from command level (each Run from the editor) starts with an empty table. Under `runb-l2` that is the whole process. While the debugger has the program stopped, the globals are intact, so watches and PRINT see them. The debugger compiles against the paused procedure, so a global can be watched where it is declared.

### PACK (`l2b09ovl`, `src/pack`)

PACK drops the symbol names but keeps them for `S.PROC` entries, so that `RUN` can find its target by name (`DUMP9`: `cmpa #S.PROC`). Globals are bound by name too, so that test becomes `S.PROC` or `S.GLOB`. Nothing else in PACK changes.

### The editor

There is nothing to do for the first version: the editor sends source text and `l2b09cc` compiles it. Optional: syntax colour for `GLOBAL` (from `mkkw.py`), a help page (`help/`; `mkhelp.py` requires one for every keyword anyway), and `GLOBAL` lines in a `DEFTYPE` block, so that a block can declare shared variables as well as types (**Decide**).

## Compatibility

- **Old programs:** unaffected. Old source has no `GLOBAL` keyword. A program that uses `global` as a variable name stops compiling, as any new keyword does (**Decide** whether that is acceptable; `GLOBAL` is a reserved word in Microware's own token list).
- **Old PACKed modules:** never hold `T.GLOB` or `S.GLOB`, so they run as before.
- **New modules under stock RunB:** wrong results, no error. This is a known issue, as for far arrays. Marking L2-only modules is still parked (PPM 206).

## Tests

A new emulator test, in the style of p8a:

- Two procedures share a simple global, an array and a record; `main` prints the values after `RUN`.
- A recursive procedure sees the same global at every depth.
- A type mismatch between two declarations gives the chosen error, and the debugger stops at it.
- The table is cleared between two Runs.
- A watch on a global while stopped.
- PACK, then the module run under `runb-l2`, gives the same output.
- p8c and p8d still pass, so procedures without GLOBAL are byte-identical.

## Later

- **FAR GLOBAL arrays:** the table entry holds a far array's 6-byte handle instead of the data, and the element access goes through `L2FVRF` with that handle. The blocks are freed at the end of the run, not at the procedure's `END`. This gives large shared arrays (PPM 840).
- **Named blocks:** `GLOBAL settings` … `END GLOBAL`, with `USE settings` in a procedure, bound once per block. Each variable is then an offset in the block, as a field is in a record. That means one lookup per block instead of one per name.

## Steps

1. Measure: a stub of the keyword plus the binder entry in `l2b09cc`, to see what room it costs.
2. The compiler, decompiler and binder; check LOAD/LIST round trips.
3. Runtime: the access path in `exprsn`, binding, and the table (option 1).
4. PACK and `runb-l2`.
5. Tests and docs: this note becomes the reference, and the help page is added.
