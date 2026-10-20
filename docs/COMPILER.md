# A separate compiler process (design note)

Status (2026-10-20): steps 1 to 4 are built, on `main` (developed on the branch `separate_compiler`, merged 2026-10-20). `l2b09run` has no compiler any more (19,477 bytes, down from 23,945): it forks `l2b09cc` at start-up and LOAD, the arguments of RUN, the debugger's statements and PACK go to it. All tests pass, and a 40K workspace starts (`make p8ctest`). Step 5 (using the room) is next. It refines "A separate compiler" in [ARCHITECTURE.md](ARCHITECTURE.md), "Risks and open questions". The compiler is `l2b09cc`.

## The idea

`l2b09run` forks a compiler process, `l2b09cc`, and drives it through pipes.
- **The compiler** has its own 64K map. It compiles and binds procedures in its own memory, then sends each finished procedure down a pipe: the same bytes that the workspace holds today.
- **The runtime** copies those bytes into its workspace.

compil and binder (5,830 bytes) leave `l2b09run`. That frees about 5.4K, which is enough to put the code in slot 7 and get a 40K workspace, with room left for new language features.

**Sharing the runtime's memory map was considered and rejected.**
- **Same addresses everywhere:** Basic09 keeps absolute pointers in its direct page, including the module addresses `M.COMAND` and the rest. So a compiler that shared the workspace would need the workspace and `l2b09run`'s code at the same addresses in both processes.
- **No way to choose a slot:** `F$MapBlk` always takes the highest free slot. Forcing the layout would need dummy mappings, and moving the child's own stack out of slot 0.
- **A dangerous exit:** a child that exits, or crashes, with the runtime's blocks still mapped can free them.
- **No slot gained:** that compiler needs a slot free in the runtime's map, which is exactly what the overlay already needs.

Sending the result instead needs none of this.

## Why a procedure can be sent as bytes

Checked in the source:
- **Offsets, not addresses:** the procedure header (`b09defs`, `P.*`) holds offsets from the start of the procedure. `P.PGMB`, `P.SYMB`, `P.DSCB`, `P.DATA`, `P.EXEC` and `P.PRCS` are all offsets. `SETGLB` (`stmts.asm:249-262`) adds them to the procedure's address on every call, so a procedure can sit anywhere. That's already how it works when LOAD and KILL move procedures around the workspace.
- **Calls are linked at run time:** a call to another procedure goes through a link slot in the caller's variable storage (`P.PRCS`). `EXEC` clears these slots at each call (`stmts.asm:219-232`). So binding doesn't depend on what else is in the workspace.
- **External modules work the same way:** they are found by name when RUN calls them.
- **What the runtime adds after receiving:** a directory entry for the procedure. With `-b`, it also banks it (`L2BANK`, as LOAD does today).

## Who forks whom, and the pipes

```
 basic09-l2 (editor) ==pipes==> l2b09run ==pipes==> l2b09cc
        (protocol unchanged)      (forks it on the first load)
```

- **The runtime forks the compiler,** not the editor. That keeps the editor/runtime protocol ([PROTOCOL.md](PROTOCOL.md)) as it is: the editor still sends `load <file>` and gets back `%CERR`, `%BERR` and `%READY`. `l2b09ctl` and every test keep working.
- **The compiler is forked once,** on the first `load`, and stays alive. When the runtime exits, the compiler's command pipe ends, and it exits too.
- **One pipe each way.** `F$Fork` passes only paths 0-2, so the compiler gets the command pipe on stdin and the data pipe on stdout.
- **Messages go straight to the editor (changed in step 1).** The compiler's stderr is the runtime's own stderr, which it inherits, so `%CERR`, `%BERR` and listings reach the editor as they do today, and the runtime only reads frames. Nothing interleaves: the runtime waits for `%DONE` before it writes its own `%READY`, and the compiler has written its messages by then.

### The runtime → compiler direction

Plain text lines, like the current protocol:
- `load <file>`: compile every procedure in the file. The compiler opens the file itself, with the same current directory as the runtime; it gets the runtime's `chd` and `chx` before each load.
- `bye`: exit.

### The compiler → runtime direction (stdout)

Lines, plus one binary frame:
- **`%PROC <bytes> <name>`** (name last, so LOAD's own code can kill by it), followed by exactly that many raw bytes: one finished procedure, as it is in the compiler's workspace (module header, I-code, symbol and description tables; the error bit set in `P.STAT` if it has errors). Pipes carry raw bytes: the runtime reads the line with `I$ReadLn`, then the body with `I$Read`.
- **`%DONE`:** the compiler is ready for a command: once at start-up, and after each command (so after a load has sent all its procedures).

### How the runtime handles a received procedure

- **An existing procedure of the same name** is killed first, as LOAD does now.
- **No room in the workspace:** the runtime reports ERROR #032 as today, so the editor's Make still grows the workspace and retries.
- **A procedure with errors:** the compiler sends it too, with the error bit set in `P.STAT`, as stock Basic09 keeps it, so RUN refuses it with "procedure errors". The `LIST12` path that rebinds a procedure to show its errors (`comand.asm:1955`) is not needed: the compiler already sent the errors.

## What stays in `l2b09run`

- **The interpreter:** stmts, exprsn and cnvio.
- **The commands it still runs itself:** LIST, SAVE (the decompiler), RUN, KILL, MEM and PACK in the overlay, with `UNBIND`, which PACK uses.
- **The routines that run while a program runs:** `MOVDWN` (record assignment, `stmts.asm:1016`), plus `NAMSYM` and `SEARC0` for command lines. About 190 bytes; the survey of 2026-10-15 lists them.
- **The receiver:** the fork, `%PROC` reading, and forwarding. About 150 bytes, estimated.

## The compile-time work that happens while running

These call the compiler today. Each one needs a route:

1. **`run <proc>(<args>)`** compiles and binds the argument list each time (`CPRM`/`BPRM`, `comand.asm:2075-2087`).
   - **Route:** send the argument text to the compiler and get back a bound parameter block, framed like `%PROC`.
   - The editor's Run sends no arguments, but tests and `l2b09ctl` do.
2. **The debugger:** PRINT, LET, Evaluate and watches compile a statement against the paused procedure's symbols, then the runtime executes it (`X$ISTM`).
   - **Route:** the runtime sends the paused procedure's image (from the workspace or the far store) and the text. The compiler returns the bound snippet.
   - **Watches** are re-evaluated at every stop, so the runtime keeps each watch's compiled snippet and asks again only when the procedure changes.
   - **Open:** what a snippet may change. For example, an unknown name today can add to the symbol table.
3. **Breakpoints** (`bp`) take line numbers and need no compiler.

Until 1 and 2 are moved, compil and binder can't leave the runtime. That shapes the order of the steps below.

## What it costs

- **A process:** its code is about 8-10K by estimate (compil, binder, LOAD's line reader, and the conversion and search helpers it calls). Its data is enough for the largest procedure plus the compiler's tables. It never takes a slot in the runtime's map.
- **Time:**
  - a fork on the first load;
  - per procedure, one pipe copy, about the size of the procedure;
  - per debugger PRINT, one pipe round trip, a few milliseconds by estimate.
- **Pipes:** two more. The pipe modules are already in OS9Boot for the editor.
- **When the compiler is missing:** `load` fails with 216, as PACK does without the overlay.

## How `l2b09cc` is built (step 1)

`l2b09cc` is `l2b09run`'s own source built with `-DL2B09CC=1` (`make` builds it). So it compiles exactly as `l2b09run` does, and `l2b09run` stays byte-identical. The differences, all under `ifne L2B09CC` in `comand.asm`:
- the module name;
- `L2BANK`, which runs after LOAD binds each procedure, first calls `L2SEND`, which writes the `%PROC` frame to stdout;
- the command loop (`COMAN0`) writes `%DONE` to stdout before each command.

It keeps every procedure it compiled in its own workspace, as LOAD does, so a later step can compile debugger statements against them. It is 24,035 bytes today, with the interpreter still in; trimming it is for later, since it has its own 64K.

`make p8btest` loads startrek and a file with a compile error into `l2b09cc`, then checks the frames with `tools/ccframes.py`: each must start with a module header whose size and name match its `%PROC` line (`-x <dir>` writes the procedures out). The emulator harness fetches binary results unchanged with `raw:<file>` in a test's `fetch` file.

## How `l2b09run` takes procedures in (step 2)

Two commands, for now beside LOAD (`comand.asm`, after the protocol code):
- **`ccload <file>`** starts `l2b09cc` the first time (`L2CCST`), sends it `load <file>`, and puts each procedure it sends in the workspace, as LOAD would: an old one of the same name is killed first, and with `-b` it goes to the far store (`L2BANK`). With no room (the procedure plus 256 bytes), the rest of that frame is read away and ERROR #032 is reported once the compiler sends `%DONE`, so the pipe never gets out of step.
- **`cccmp <file>`** does the same, but compares each procedure with the one of that name that LOAD put here, and prints `%SAME <bytes> <name>` or `%DIFF <bytes> <name>`.

Details:
- **Starting the compiler:** our paths 0 and 1 are set aside, two pipes are opened as paths 0 and 1, `l2b09cc` is forked with 32K (it inherits them, and our stderr), and our paths are put back. A copy of each pipe stays open; both path numbers fit in the last free direct-page byte (`L2CCP`). The compiler's first `%DONE` is read into free space, because the command line is still in the I/O buffer.
- **When `l2b09run` exits,** the compiler's command pipe ends and it exits too (`procs` shows no `l2b09cc` afterwards).
- **The name in a `%PROC` line** goes through `J$NAME`, which marks its last character as directory names are; `DIRSCH` compares that bit too.

**Result:** every procedure tried is byte-identical in both processes (`make p8ctest`: a 200-line numbered procedure with conversions, one with a compile error, and a two-procedure program with a call, DATA and arrays). So a bound procedure holds no addresses that depend on where it sits, which is what the design rests on. CCLOADed procedures run, list, and replace older ones.

**Open items found in step 2:**
- **The compiler's copies fill its workspace.** It keeps every procedure it compiled, but nothing tells it when the runtime kills one, and its 32K is fixed. Loading startrek after other files failed in the compiler with 32 and then bind errors. Step 3 should pass `kill` on and grow the compiler's memory (or start from the runtime's size).
- **The current directories** are the runtime's at the moment of the first fork; a later `chd` or `chx` in the runtime does not reach the compiler yet.
- **Size:** the receiver costs about 500 bytes, so `l2b09run` is 24,480 bytes, 96 below the limit. Step 3 needs room before it can add the run-argument and debugger routes: CCCMP can go once LOAD itself uses the compiler, and compil and binder are the big win (step 4).

## How it works now (steps 3 and 4)

**`l2b09run` is built with `-DL2B09RT=1`.** The build script then assembles compil and binder in their RunB form (`-DINCLUDED=6` for those two only): compil keeps `NAMSYM`, `SEARC0`, `MOVDWN` and the literal-only `CMPRAM` (635 bytes), binder keeps an empty `PRPRAM` (19). `l2b09run` went from 23,945 to 19,477 bytes, so its code can use slot 7: `#40k` starts and runs (`make p8ctest`). Stock builds are unchanged (`make check`).

**At start-up** `L2CCST` forks `l2b09cc` with our workspace size and our `-b`, with pipe A as its stdin and pipe B as its stdout; its stderr is ours. Both pipe paths are kept in `L2CCP`. Without `l2b09cc`, LOAD gives ERROR #216.

**What goes to the compiler** (`L2FWD` sends a line, `L2CCLP` reads its answers until `%DONE`):
- **LOAD** sends `load <file>`; `%PROC` frames go into the workspace as in step 2 (an old procedure of the same name is killed through `KILL0`, by directory entry), with `-b` banking.
- **PACK** is done there entirely (it has the same procedures). If it asks to rewrite a file, it writes `%ASK` on stdout as well, and `l2b09run` passes it one line of its own input.
- **RUN's arguments:** with none, `l2b09run` writes the I-Code `T.EOL` itself. Otherwise it sends `ccprm <procedure> <arguments>`; the compiler compiles and binds them as INTERP did (`CMPRAM`, `PRPRAM`) and answers `%ICODE`, 2 bytes of length, and the bound I-Code (length 0: errors, shown by the compiler).
- **The debugger's statements** (PRINT, LET, the editor's Evaluate and watches): `ccstm <procedure> <statement>`; the compiler sets up its copy of the procedure as `SETGLB` would (mapping it in first if it is banked), compiles and binds the statement in debugger mode as DIREXQ did, and answers `%ICODE`. `l2b09run` runs it with `X$ISTM` as before.
- **KILL, MEM, CHD and CHX** are done here, then passed on, so that the compiler's copies and settings stay as ours. MEM passes on `mem <the size now>`, because its own output overwrites the command line. Lines are passed on with bit 7 cleared, because `J$NAME` marks the last character of a name in place.

**In `l2b09cc` (`-DL2B09CC=1`)** there is no prompt, banner, name line or MEM size line (its stderr is the editor's), and it has the two commands `ccprm` and `ccstm`.

**Found on the way:**
- `HALT` (Q, and an abort) closes every path from 3 up except the command paths; it now skips the two pipes (`L2CCPA`), or the compiler saw the end of its input and exited.
- `CMPRAM` used to clear the `DEBUGGER` flag on every RUN; after Q in the debugger the next RUN relied on it, so `L2PRM` clears it too.
- `DIRSCH` destroys B, so the compiler keeps `J$NAME`'s name length across it.
- LIST no longer rebinds a procedure with errors to show them again (the compiler showed them when it loaded it).

**Speed:** loading startrek (`make loadtime`) takes about 4 s against 3 s with the built-in compiler: the fork of `l2b09cc` and the pipe copy. Programs run as fast as before.

**Still open:**
- **`l2b09cc` was 24,425 bytes, too big for slot 7** (fixed 2026-10-20): its workspace was capped at 32K. Its exprsn is now assembled without the trig package (`-DINCLUDED=3` for that module only; the compiler evaluates nothing, and cnvio's number conversion needs only the real arithmetic), 5,592 → 4,009 bytes, so `l2b09cc` is 22,842 bytes (22,970 with the keyword index, 23,138 with the name index), its code can use slot 7, and it gets the runtime's workspace, 40K included (`make p8ctest` loads startrek at `#40k`).
- **RUN of an external (packed) module with arguments** (fixed 2026-10-20): the compiler did not know the module and refused the arguments (error 51). `CCPRM` now uses a stand-in header holding the name, since the binder only marks errors in it; `make p8dtest` runs a PACKed module with constants and expressions.
- **Room:** `l2b09run` has 4,331 bytes left below 23,808 (5,099 below 24,576), for step 5.

## Steps

1. **Build `l2b09cc`** from the same sources. Done 2026-10-20 (above).
2. **Both paths side by side** (done 2026-10-20, above).
   - `l2b09run` learns `%PROC`, but keeps its own compiler.
   - A test option compiles each loaded procedure both ways and compares the bytes, which must be identical. That proves the compiler process before anything depends on it.
3. **Move `run` arguments and the debugger's snippets** (done 2026-10-20, with step 4, above) to the compiler (routes 1 and 2), with tests for each. `make p8atest` is the reference: the debugger's PRINT and LET (conversions, arrays, a record field, strings, errors 49 and 71) and `run <proc>(<args>)` (expressions, a long string, too few arguments, and stock Basic09's unchecked argument types, whose bytes must stay the same).
4. **Remove compil and binder from `l2b09run`** (done 2026-10-20).
   - Measure, then re-check the slot-7 placement. Code at or under 23,808 bytes should let `#40k` start.
   - Update PROTOCOL.md (216 for `load`), CLAUDE.md and the tests' `modules` files.
5. **Then use the room,** and the compiler's own 64K: GLOBAL storage, labels, `MODULE.Procedure` syntax, and better error messages (ARCHITECTURE.md lists them).

## Open questions

- **Keep the compiler running?** It could stay alive with a copy of every procedure it compiled, so the debugger doesn't need to send the image, or start fresh each time to save memory.
- **Which helpers to copy:** which comand and cnvio routines the compiler needs (number conversion for constants, name search, the I/O buffer), and whether to copy them or share one source file.
- **Error-line mapping:** whether `%CERR`/`%BERR` line numbers need any change once the compiler reads the file itself. They shouldn't: the same code produces them.
- **The banked-procedure limit:** a banked procedure is limited to 8K. The compiler could check that before sending, instead of the runtime finding out.
