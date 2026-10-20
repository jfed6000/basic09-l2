# A separate compiler process (design note)

Status (2026-10-20): step 1 is built on the branch `separate_compiler`: `l2b09cc` compiles and sends procedures (`make p8btest`); `l2b09run` does not use it yet. It refines "A separate compiler" in [ARCHITECTURE.md](ARCHITECTURE.md), "Risks and open questions". The compiler is `l2b09cc`.

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
- **`%PROC <name> <bytes>`,** followed by exactly that many raw bytes: one finished procedure, as it is in the compiler's workspace (module header, I-code, symbol and description tables; the error bit set in `P.STAT` if it has errors). Pipes carry raw bytes: the runtime reads the line with `I$ReadLn`, then the body with `I$Read`.
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

## Steps

1. **Build `l2b09cc`** from the same sources. Done 2026-10-20 (above).
2. **Both paths side by side.**
   - `l2b09run` learns `%PROC`, but keeps its own compiler.
   - A test option compiles each loaded procedure both ways and compares the bytes, which must be identical. That proves the compiler process before anything depends on it.
3. **Move `run` arguments and the debugger's snippets** to the compiler (routes 1 and 2), with tests for each. `make p8atest` is the reference: the debugger's PRINT and LET (conversions, arrays, a record field, strings, errors 49 and 71) and `run <proc>(<args>)` (expressions, a long string, too few arguments, and stock Basic09's unchecked argument types, whose bytes must stay the same).
4. **Remove compil and binder from `l2b09run`.**
   - Measure, then re-check the slot-7 placement. Code at or under 23,808 bytes should let `#40k` start.
   - Update PROTOCOL.md (216 for `load`), CLAUDE.md and the tests' `modules` files.
5. **Then use the room,** and the compiler's own 64K: GLOBAL storage, labels, `MODULE.Procedure` syntax, and better error messages (ARCHITECTURE.md lists them).

## Open questions

- **Keep the compiler running?** It could stay alive with a copy of every procedure it compiled, so the debugger doesn't need to send the image, or start fresh each time to save memory.
- **Which helpers to copy:** which comand and cnvio routines the compiler needs (number conversion for constants, name search, the I/O buffer), and whether to copy them or share one source file.
- **Error-line mapping:** whether `%CERR`/`%BERR` line numbers need any change once the compiler reads the file itself. They shouldn't: the same code produces them.
- **The banked-procedure limit:** a banked procedure is limited to 8K. The compiler could check that before sending, instead of the runtime finding out.
