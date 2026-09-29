# l2basic09 Architecture and Roadmap

**Name:** the project is called `l2basic09`. Nothing in any name refers to a specific machine, because it may also run on a CoCo 3.
- Deliverable names follow the same rule: `l2b09run` (compiler, runtime and debugger; see P2 for why there is no separate `l2b09c`), `farmem`.
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
- **PACK throws away what a debugger needs.** PACK (`DUMP` routine, `comand.asm:1739`) rebinds with `SMASH` cleared, which removes REMs, DIMs and symbol names. That is why the runtime loads source rather than packed modules (see P2).
- **Unpacked procedures are already module-shaped.** Workspace procedures are already laid out like modules (`P.MHDR`, `P.SYMB`, `P.DSCB`, and so on). That makes a disk format for debuggable modules natural.
- **The kernel side is already there.** The Level 2 kernel has `F$AllRAM`, `F$MapBlk`, `F$ClrBlk`, `F$CpyMem`, `F$GPrDsc`, and there are pipes (see the P1 findings for the limits). Wildbits has 8K blocks (`defs/wildbits.d`), and `vt1`–`vt8` give multiple terminals. The `samples/mapblk` sample already maps blocks from Basic09 through the `wild` module.

## Proposed architecture
```
 [Editor process, vtN]      text .b09 source; could be a new full-screen editor
        |  forks l2b09run -t=/vtM; anonymous pipes on its stdin/stderr; F$Send for BREAK
        |  sends "load <file>" with the changed procedures only
        v
 [l2b09run process, own 64K]  compiles source to I-code (symbols kept), runs, debugs
        program I/O -> /vtM (paths 0,1);  commands/debugger -> the control pipes
```
- **Hand-off format:** source text. The runtime compiles it with the stock compiler, so it keeps full symbols for the debugger. Recompiling is slow (937 lines take about 20 s at 6.29 MHz), so the runtime stays running between runs and the editor re-sends only the procedures it changed; LOAD replaces procedures by name. Packed modules still run in RunB for production use.
- **Protocol:** plain text lines; see [PROTOCOL.md](PROTOCOL.md). The editor sends Basic09 and debugger commands. The runtime answers with free text plus `%` event lines (`%READY`, `%DEBUG`, `%ERROR`, `%CERR`, `%BERR`, `%ASK`). BREAK and ABORT are the signals `S$Intrpt` and `S$Abort`.
- **Mapping back to source lines:** LOAD turns every source line after a `PROCEDURE` header into exactly one I-code line, including blank and comment lines. So "procedure P, line N" is file line (line of `PROCEDURE P`) + N, and no separate line table is needed. `l2b09run` reports `BREAK: PROCEDURE <name> line <n>` (P2). This holds for loaded source only; PACK drops DIM/REM lines.
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
- **P2 – Build variants (done).** `make l2b09` builds `build/l2b09run` (22,385 bytes; stock basic09 is 23,232). `make p2test` passes all 14 checks, and `make check` still shows the stock builds are byte-identical.
  - **One flag, `L2B09`, instead of splitting `INCLUDED`.** The stock module stores the `INCLUDED` value (`fcb INCLUDED`), so redefining `FULL` would change stock bytes. `L2B09` (in `src/b09type`) is undefined for stock builds. When set, it:
    - drops the line editor (`EDIT`/`E` and the editor command table);
    - names the module `l2b09run` and gives it a neutral banner;
    - turns off the CoCo ^N output (`Tandy`);
    - adds the features below.
  - **Everything else stays.** The debugger's PRINT/LET compile and run statements, and LIST decompiles, so the compiler, binder and decompiler are all needed in the runtime. That is also why there is no separate `l2b09c`: it would be the same code. Compiling is done by the running `l2b09run` (`load`, or `pack*` for RunB modules).
  - **Usage:** `l2b09run [#mem] [-t=<terminal>] [<file> [<procedure>[(<params>)]]]`
    - With a file, it loads the file, runs the named procedure (or the first one), then reads commands. Stock basic09 wrongly tried to run a procedure named after the file.
    - With no file, it starts in command mode.
    - `-t=<path>` moves standard input and output (paths 0 and 1) to `<path>`, so the program and anything it `SHELL`s use that terminal. Commands and the debugger keep the original stdin (the new `CMDIN` variable) and stderr (path 2, `CMDOUT`/`BASOUT`). The code is `L2OPTS`/`L2TERM` in `comand.asm`. `RUNCMD`, the "Rewrite?" prompt and `HALT` all respect `CMDIN`.
    - A bad option exits with `E$IllArg` (187).
  - **Line numbers:** the debugger header is `BREAK: PROCEDURE <name> line <n>` (`PAPRLN`/`ACTLIN` in `editor`). `<n>` is the line holding the current statement, so it is right for `\`-joined statements and for errors in called procedures, both of which are tested.
  - **Found, left for P3:** the debugger's `PRINT` output goes to the program terminal, not the command channel, because it runs as a direct statement through `I.OPTH`.
  - **Dropped: debug-pack.** It was meant to keep symbols in a packed module. The runtime compiles source instead, which keeps symbols anyway, and incremental reloads make up for compile time. Revisit only if restart times become a problem.
- **P3 – Runtime control channel (done).** The protocol is specified in [PROTOCOL.md](PROTOCOL.md). `make p3test` passes all 8 checks: `os9/l2b09ctl`, an editor stand-in, forks `l2b09run` with anonymous pipes on its stdin and stderr and drives a whole session. `l2b09run` is 22,677 bytes, and `make check` still shows the stock builds are byte-identical.
  - **Event lines:** `%READY`, `%DEBUG <proc> <line>`, `%ERROR`/`%CERR`/`%BERR <code> <proc> <line>` and `%ASK Rewrite?`. They replace the `B:`/`D:` prompts, which had no newline, and the `Ready` line.
    - Events are written by `L2EVNT`, a new comand entry point `X$L2EV` that the binder and interpreter reach through the jump tables. It builds the line on the stack, because during LOAD the I/O buffer holds the source line.
    - `L2LINE` turns an I-code pointer into a procedure line number. `LSTERR` keeps the last error code printed (`PRTERR`), so LOAD's `%CERR` can report it (`L2INSR`).
  - **Output on the command channel:** the debugger's PRINT/LET output (`DIREXQ` points `I.OPTH` at the command channel while it runs), and compiler error lines (`compil.asm` `PRTLIN`), which used to go to the program's stdout.
  - **BREAK/ABORT** need no new code. `INTCPT` already routes `S$Intrpt` to the debugger and `S$Abort` to HALT. Both were tested by signalling a running loop.
  - **Found:** a second PACK fails with error 51 in stock Basic09 too, because PACK strips the workspace copy. Documented in PROTOCOL.md.
  - **Test harness note:** if an `expect` never matches, `l2b09ctl` blocks until the emulator stops, and the output files are cut off because they were never closed. So a hang shows up as missing or short files.
- **P4 – `farmem` subroutine module (done).** `modules/farmem.asm` is 644 bytes; user documentation is in [FARMEM.md](FARMEM.md). `make p4test` passes all 10 checks.
  - **Interface:** `RUN farmem("alloc"|"put"|"get"|"unmap"|"free", fm, ...)`, with a 4-INTEGER descriptor the program owns. A subroutine module has no data area of its own, so all state lives in the descriptor. Far memory is an array of records, each `SIZE(var)` bytes.
  - **How it works:**
    - `F$AllRAM` provides whole 8K blocks, and `F$DelRAM` returns them.
    - One block at a time is mapped with `F$MapBlk` into a window that stays mapped between calls.
    - A block change costs `F$ClrBlk` + `F$MapBlk`.
    - Records crossing a block boundary are copied in pieces.
  - **Tested:**
    - 800 records of 320 bytes (256K, many straddling blocks) written and read back with no errors;
    - the range error (55) caught with `ON ERROR`;
    - the same program packed and run under **stock RunB**;
    - free memory identical before, after, and at the end (no leaks).
  - **Measured (5,000 calls at 6.29 MHz, one-second timer):** local access under 1 s; `farmem` within one block 2–3 s (about 0.5 ms per call, mostly `RUN` overhead); alternating blocks about 4 s (a remap adds about 0.3–0.4 ms).
  - **Limits:**
    - Blocks from `F$AllRAM` are not owned by the process, so a program that ends without `free` leaks them until reboot.
    - The window needs one free 8K slot in the program's 64K.
    - Both limits are documented in FARMEM.md. P7's far arrays have no `free`: the runtime frees them when the procedure returns.
  - **Harness:** `expect` files can now say `same <fileA> <fileB>` (used for the mfree comparison).
- **P5 – Editor integration (done).** `l2b09ed` (`os9/l2b09ed/`, 6809 assembly) is a Turbo C–style IDE that edits one whole `.b09` file and drives `l2b09run` over the pipe protocol. It is specified in [EDITOR.md](EDITOR.md), which also covers the sub-phases P5.0–P5.5 and the keyboard survey.
  - **P5.0/P5.1 (done):** keys from both Wildbits keyboard drivers are folded into one code set. The paged buffer keeps the text in 2K pages in a swap file with an LRU cache of `-c` pages, so files can be larger than the editor's 64K. There is a plain full-screen view with open, edit and save. `make p5atest` edits a 129 KB file with a 3-page cache and matches a Python model byte for byte. `l2b09ed` is 4,344 bytes.
  - **P5.2a (done):** Turbo layout (menu bar, double-framed edit window, line:column border, hint line), drop-down menus, dialog boxes, help, and the File commands. Frame glyphs are installed with `SS.FntChar` and put back on exit. `make p5btest` covers the File commands through menus and dialogs. `l2b09ed` is 7,436 bytes.
  - **P5.2b (done):** selection (Shift+arrows, ^A; reverse video) and a clipboard kept in its own page chain in the swap file. Deleting a selection and pasting work a page at a time. `make p5ctest` checks the results against `tools/edmodel.py`. `l2b09ed` is 8,642 bytes.
  - **P5.2c (done):** find, find next and replace (Y/N/A/Esc), matching either case unless Match case is on. The search scans page buffers directly. `make p5dtest` checks the results against the model. `l2b09ed` is 9,363 bytes.
  - **P5.2d (done):** undo/redo, 50 records. Each record is a 24-bit range whose text is in the buffer or in a swap-file page chain, and undo and redo move it across. If the pages run out, the history is given up. `make p5etest` checks the results against the model. With this, P5.2 is complete. `l2b09ed` is 10,522 bytes.
  - **P5.3 (done):** Make, Run, the error jump and the user screen. The first Make forks `l2b09run` on pipes and keeps it for the session. A table of the procedures it holds, each with a signature of its text, lets Make send only what changed (one `load` of a temp file) and `kill` what is gone. `%CERR`/`%BERR`/`%ERROR` become messages in a message window, with the text from `/dd/sys/errmsg` and the file line, and the cursor goes to them. Run shows the program's terminal (from `-t`, or a free one from the `/vt` factory) and takes the screen back on `%READY`. Found on the way:
    - SCF sends BREAK to the last process that used the terminal, which can be the editor, so the editor passes BREAK and abort on to `l2b09run` from a signal handler.
    - A signal that interrupts a pipe read ends it with `E$EOF`, the same as the end of the pipe, so the handler sets a flag and the read is tried again.
    - Only the direct page is cleared at start; buffers such as the file and terminal names keep what the last process left there, so they are cleared explicitly.
  - `make p5ftest` checks the whole protocol log of a session, the saved file, the program's output, and BREAK passed on from a signal. `l2b09ed` is 14,086 bytes.
  - **Harness:** a test directory may have a `gen` script whose output is copied into the image unchanged (binary key scripts, generated sources).
  - **P5.4 (done):** the debugger UI. A `%DEBUG` stop (PAUSE, BREAK or a runtime error) no longer quits the debugger. The editor shows the stopped line in reverse video and keeps the program there. F7 steps, ^R continues, ^P resets (`q`), ^E evaluates an expression or sets a variable (`print`, `let`), and ^W adds a watch. The watches are printed again at every stop, in a watch window above the message window. Debug ▸ Until return sends the debugger's `BREAK <procedure>`. Make while stopped asks before it resets the program to load changed procedures. `make p5gtest` checks a whole debugging session's protocol log, the program's output, and the watch window in a screen snapshot. `l2b09ed` is 16,090 bytes. Found and fixed on the way:
    - **Debugger `print`/`let` corrupted `P.STAT` (P7 bug).** `L2BSTM` kept the procedure's status in B across `J$BSTM`, which does not preserve B. Every successful direct statement left junk (`$3F`, `P.BANK` included) in the active procedure's status. The next return into that procedure took it for a banked stub, and `I.APRC` pointed into the code window. It now saves the status on the stack.
    - **Step went past a `RUN` (stock).** `RUNSTM` cleared the step bit before a call and never set it again, so a step on a `RUN` line ran the rest of the program. In `L2B09` builds a step now stops at the callee's first statement, and stepping through its END stops back in the caller.
    - **`BREAK <procedure>` did nothing without TRON (stock).** BREAK marks the caller's saved run mode, but the return restored the run mode only when trace was on. The return now always takes the stop from it. A stop pending at the call itself is not saved there, so `cont` inside a callee runs on after the return.
    - **Dialogs lost the Y/N answer (P5.2a bug).** `dlg_done` overwrote A, so a Y/N question never saw Y, and "Save the changes?" treated N as Y.
    - `l2b09run` is 24,388 bytes.
  - **P5.5 (done):** line breakpoints, run to the cursor and step over, in `l2b09run` and the editor. With this, P5 is complete.
    - **Runtime commands** (PROTOCOL.md): `bp <proc> <line>` and `bc` (clear all) in command mode and the debugger, `over` in the debugger, and `step [<proc>]` in command mode (run, stopped before the first statement).
    - **Breakpoint table:** 16 entries of (procedure pointer, I-Code offset of the line's first statement). `bp` finds the offset by walking the procedure's I-Code lines. A banked procedure is mapped in for that, and the code window gets back what it held, so `bp` works while the program is stopped. `load`, `kill` and `pack` clear the table, because procedures move.
    - **Where it lives:** the direct page had 4 bytes left (`L2NBP`, the breakpoint count, and `L2OVRU` take 3). The table sits above the procedure directory, at `G.DIRA+$100`, and `G.PRCA` starts 64 bytes higher.
    - **The check** is in `STMLUP`: one `tst` per statement while no breakpoint is set. With breakpoints, a hit sets the same pending stop a step does (`I.RUNM` bit 7, `STEPS`=1), and `DEBUG` does the rest. It never fires inside a debugger `print`/`let`.
    - **Step over:** `over` notes the stopped procedure's storage (`L2OVRU`) and steps. `RUNSTM` then clears the pending stop for the callee (the stock behaviour), and sets it again when the call returns to that storage, which also tells recursion apart. Any stop clears `L2OVRU`, so a breakpoint inside the call wins.
    - **Editor:** ^T sets or clears a breakpoint, kept as a tracked position at its line's carriage return. The tracked positions now sit at the top of the direct page, followed by the 8 breakpoints, so the page code's tracking loops move the breakpoints with the text. Before the program runs, continues or steps, the editor sends the breakpoints again if they changed (a rescan for the procedures' lines, `bc`, then `bp` for each). F4 sets a breakpoint for one run; the next sync drops it. F8 sends `over`. F7 and F8 start a program that is not running with `step`. The mark is a 15th font glyph on the left border.
    - **Size:** the first version took `l2b09run` to 24,756 bytes, past 24,576 (three 8K blocks). The code then needed a fourth slot, and `make p7test`'s `#24k -b=64` far-array run failed with 207 (no slot left for the data window). It is back to 24,543 bytes:
      - `bc` only clears all, `bp` does not look for duplicates, and the statement check stops at `G.PRCA` instead of counting;
      - `GETLIN`, `CHKEOL`, `DELLIN`, `NXLNRF` and four strings, used only by the line editor (or by nothing), are left out of `L2B09` builds;
      - the protocol events' decimal routine (`L2EDEC`) now borrows `ItoA`, with the I/O buffer pointed at its line for the call.
    - `make p5htest` checks a session's whole protocol log, the saved file, and the marks in a screen snapshot. `l2b09ed` is 17,064 bytes.
  - **P5.6 (done):** syntax colours and pretty print, in the editor only; `l2b09run` is unchanged. It was built on the branch `p5.6` and merged once the benchmark showed the colours cost +18% in redraw time. Details are in EDITOR.md ("Syntax colours", "Pretty print").
    - **Colours:** per line, while `v_line` draws, with a keyword table generated from the compiler's `KEYTAB`. The terminal's own colours come from `SS.FBRgs`.
    - **Pretty print** uses the runtime's decompiler: `list <proc>` output, cleaned up and put in place of the procedure's lines. `SAVE` could not be used, because it skips the indent (`PRTCTL=$80`). The line count does not change, so the procedure counts as loaded and its breakpoints stay on their lines. Undo records got a `UF.LINK` flag so one ^Z takes the whole edit back.
    - **Found on the way:** `c_redo` looping over a linked group lost the record number in B (`u_ptr` multiplies in D).
    - `make p5itest` checks the colour codes and runs the benchmark, and `make p5jtest` checks pretty print, undo/redo, breakpoints and the reload. `l2b09ed` is 19,430 bytes; it keeps 3 blocks up to 24,576. The direct page has 2 bytes left below the tracked positions.
- **P6 – Transparent code banking (done).** `l2b09run -b=<kb>` keeps loaded procedures in far memory and maps each one in when it runs. Programs are unchanged. `make p6test` passes all 13 checks, including a program with about 48K of compiled code: it fails with "memory full" (32) in a 24K workspace without `-b`, and loads and runs with `-b=128` (1,355 lines in about 11 s, 22,232 bytes still free). `l2b09run` is 23,182 bytes.
  - **Stubs:** after LOAD binds a procedure (`L2BANK`), its image is copied into a far store (`F$AllRAM`, filled in order) and the workspace copy shrinks to a stub of about 34 bytes. The stub is the header and name, the `P.BANK` bit in `P.STAT`, then the far block and offset. The directory, name searches, `DIR` and the call-chain pointers (`U.PROC`) all point at stubs.
  - **Resolving:** `L2RSLV` turns a stub into a mapped address by mapping its block into the 8K code window (`L2MAPW`: `F$ClrBlk` + `F$MapBlk`). It runs in exactly two places: `EXECUT` (call) and the return path in `RUNSTM` (`RUNS50`, before `SETGLB`). Errors never unwind across procedure levels, so there is no third path. `I.APRC` always points at mapped code, and `INTERP`/`LIST` put it back to the stub afterwards.
  - **Why the window never moves:** banked code must always appear at the same address, because callers keep pointers into it (`U.ICPT`, `I.DATA`) and bound references are offsets from `I.ICBG`. `F$SetImg` is system-state only, so the window is created at `-b` time as the highest free slot (just under `l2b09run`'s code). Only our own process changes its DAT image, and nothing runs between `F$ClrBlk` and `F$MapBlk`, so the same slot comes back every time. `L2MAPW` still checks the address and fails with 207 instead of running code from the wrong place.
  - **Also handled:**
    - `LIST`/`SAVE` map banked procedures before decompiling.
    - PACK refuses banked procedures, because it rewrites procedures in place; load without `-b` to pack.
    - `bye` (and a program's `BYE`) frees the store (`L2FREE`).
  - **Tested:** parameters, recursion, DATA/READ with GOTO, a runtime error two levels deep (`%ERROR`, debugger PRINT, `STATE` chain), LIST, SAVE, and free memory identical afterwards.
  - **Measured (6,000 calls at 6.29 MHz):**
    - caller and callee in the same far block: no measurable cost (about 1 s, against 2 s unbanked);
    - in different blocks: 7 s, about 0.8 ms extra per call and return (four system calls).
    - Small procedures are packed into blocks in load order, so procedures that call each other a lot should be next to each other in the source.
  - **Limits:**
    - Procedures over 8K stay in the workspace. Since P7, when the code window is in the top slot, the limit is 7,424 bytes (see P7).
    - Far space is never reused: a reloaded procedure takes new space, and when the store is full, new procedures stay in the workspace.
    - `S$Kill` or `CHAIN` leak the store (as with farmem).
    - RENAME of a banked procedure leaves the old name in its far copy, which is what error messages show.
    - `DIR` shows stub sizes.
  - **Possible later steps:** a 16K or two-window scheme to cut cross-block calls; placing procedures together by call graph; reusing far space.
- **P7 – Opt-in far arrays (done).** `DIM big(14000):FAR REAL` keeps the elements in whole 8K blocks outside the 64K, and the array is used with normal syntax. User documentation is in [FARARRAYS.md](FARARRAYS.md). `make p7test` passes all 37 checks. `l2b09run` is 24,382 bytes, and all five stock variants are still byte-identical.
  - **Syntax and I-code.** `FAR` is a new secondary token, `T.FAR`, placed after `T.LBNE`. The three "hole in token defs" adjustments, the decompile table (`DCFAR`), the skip table and the keyword table were extended to match. Statement tokens are unchanged, so stock I-code keeps its numbering.
  - **No new symbol-table bits.** A far array is an ordinary `S.VAR` array whose descriptor holds:
    - total size `$FF`/*blocks*. A near array can never be that big: `DIMMUL` now rejects `$FFxx`.
    - elements per block, after the dimensions.
    - as storage offset, a 6-byte handle allocated with the procedure links (`NEXRUN`). `DONE` relocates it like a link, so `EXECUT` clears it on every call.
    - `P.FAR` in `P.STAT` marks the procedure, and PACK refuses it (RunB has no far arrays).
  - **Access** (`L2FVRF`, reached from `VARREF`):
    - It computes a 24-bit element number from the subscripts, in the same order as `VARREF` (first subscript fastest).
    - An 8-step division gives the block and the index within it; elements never straddle blocks.
    - The block goes into the data window (`L2FMAP`: `F$ClrBlk` + `F$MapBlk`, cached in `DWBLK`).
    - The first access allocates the blocks (`F$AllRAM`) and links the handle into `FARLST`.
  - **Freeing.**
    - `ENDSTM` (the only procedure exit) frees the handles of the returning call: the newest ones, since calls nest.
    - Returning to command level (`COMAN0`), BYE and CHAIN free all of them, so an error you quit from leaks nothing.
  - **The one hard case: pointers held across a remap.** Only an assignment keeps an element address while it evaluates more code: the destination is taken first, then the expression runs.
    - `L2PIN` notes a far destination's block, and `L2UNPN` maps it back (and moves the address, if the window moved) just before `ASGDIS` stores.
    - That covers LET, READ and INPUT.
    - A whole far record as the source (`far := far`, across blocks) is copied to the string stack first.
    - Everything else copies values out at once: numbers to the opstack, strings to the string stack.
    - Passing a far element by reference (`RPARAM`) and `ADDR` fail with error 67.
    - An unsubscripted far array fails with error 65.
  - **Debugger.** `DIREX1` treated any non-zero `P.STAT` after binding a direct statement as a binder error, and cleared it. With `P.FAR` set, the debugger's PRINT silently did nothing, and PACK would have been allowed afterwards. `L2BSTM` now keeps the status and tests only the error bit.
  - **Found: the top slot is not a full 8K** (`defs/wildbits.d`). On Wildbits, `$FD00-$FFFF` is fixed whatever block is mapped in slot 7 (on the CoCo 3, `$FE00-$FFFF`).
    - `F$Link` keeps a module out of slot 7 if the module's last block is used past `$1D00`, so a module over 23,808 bytes loses the top slot.
    - P7 took `l2b09run` past that size (P6 was 23,182 bytes). Its code now sits in slots 4–6, and slot 7 stays free, but only up to `$FCFF`.
    - `F$MapBlk` returns the highest free slot. The first far window there wrote element 1486 into `$FD01` and hung the machine.
    - The fix, `L2GARD` at startup:
      - The code window (`-b`) may use slot 7, but then banks at most `$1D00` bytes per block (`WINLIM`).
      - Otherwise slot 7 is filled with a second mapping of the process's own first data block. `F$Exit` frees only the data slots, so the extra mapping needs no clean-up, even after `S$Kill`.
      - The far data window replaces that guard when it maps a block, and puts it back when it unmaps. Far blocks are packed only up to `L2TOPU` (`$1D00`), so they are safe there.
    - This keeps subroutine modules that map blocks (`farmem`, graphics) out of slot 7.
    - The cost is one address slot compared with P6: under `l2b09run`, `farmem` now needs `#16k` (P4's test was changed from `#24k`).
    - **Parked: the proper fix is in the kernel.** The Wildbits `F$Link` fix only covers linking modules. `F$MapBlk` gets its slot from `F$FreeHB`, which excludes slot 7 only for picothing.
      - Plan: in `fmapblk.asm` (KrnP2), under `IFNE wildbits`, treat slot 7 as occupied during the search.
      - Then remove `L2GARD`, the `L2TOPU` packing of far blocks and `WINLIM`.
      - Waiting for other kernel work to land first.
      - The lost slot remains until `l2b09run` is back under 23,808 bytes.
  - **Also fixed:** end of file on the command input inside the debugger printed `What?` forever, because the stand-in `bye` is not a debugger command. It now quits to command mode, where end of file means BYE. This matters to editors whose pipe closes.
  - **Measured** (10,000 reads, one-second clock): near 3 s; far within one block 3 s; far alternating between two blocks 8 s (two system calls per change).
  - **Limits:**
    - 255 blocks and 32,767 per dimension per array.
    - Elements up to 7,424 bytes.
    - About 9% of each block unused.
    - One far window, so alternating blocks is slow.
    - Far arrays are local to a call. There are no far globals, but a far array can be passed down by value one element at a time.
    - `S$Kill` leaks the blocks, as with farmem.

## Risks and open questions
- **Stock compatibility.** I-code stays compatible with stock RunB until P6. Far arrays are opt-in, and PACK refuses procedures that use them.
- **`l2b09run` size.** Past 23,808 bytes the code cannot use the top slot (P7). It is 24,543 bytes now; shrinking it under the limit would give one address slot back. Past 24,576 bytes it needs a fourth 8K block, and `#24k` with `-b` and far arrays no longer fits (P5.5).
- **Keyboard.** `keydrv_ps2` sends no F3–F12, Tab, Home, End, PgUp, PgDn, Ins or Del (and F7 sends a stray byte), so the editor keeps a Ctrl/Alt equivalent for every F-key. Extending that driver is a separate NitrOS-9 change.
- **Pipes on Wildbits.** Pipes are not in the stock SD boot, so l2basic09 needs a boot file with them (see P1). A CoCo 3 port needs the same check. Named pipes would mean porting `pipeman_named` to NitrOS-9's IOMan.
- **Syscall cost.** `F$MapBlk` costs a syscall per remap, so `farmem` should be measured on hardware or in MAME.

## Verification
- P0: byte-identical rebuilds (`cmp`) against `nitros9_complete/nitros9-languages/basic09/{basic09_wildbits,runb_6809}` (`make check`), plus a `basic09_6809` built from that tree.
- P1+: build a Wildbits disk with the recipe in `nitros9/recipes/wildbits` (or `os9 copy` into an existing image), then run it in MAME (`/usr/games/mame`) or on hardware. Test cases:
  - edit, compile, run in vt2;
  - `BREAK` from the controlling side;
  - the `farmem` sample storing more than 64K and reading it back.
