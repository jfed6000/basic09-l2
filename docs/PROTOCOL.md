# l2b09run command-channel protocol

This document is for the editor author. It defines how an editor drives `l2b09run`: loading source, running it, debugging it, and getting error locations back. `os9/l2b09ctl.asm` is a small working client, and `test/p3/script.ctl` shows a full session. The editor, `l2b09ed` (`os9/l2b09ed/rt.asm`, EDITOR.md "Make and Run"), is the full one.

## Connecting

The editor forks `l2b09run` with two anonymous pipes. Named pipes do not work on NitrOS-9 (see ARCHITECTURE.md, P1).

| Runtime path | Connected to | Direction |
|---|---|---|
| 0 (stdin) | pipe A | editor writes commands |
| 2 (stderr) | pipe B | editor reads output and events |
| 1 (stdout) | anything (it is moved by `-t`) | |

Recipe (from `l2b09ctl`):
1. Set aside your own paths 0 and 2 with `I$Dup`.
2. Close 0, open `/pipe` (it becomes 0), and `I$Dup` it; the copy is your write end.
3. Do the same for path 2; the copy is your read end.
4. `F$Fork l2b09run` with parameters `-t=/vtN`.
5. Put your own paths 0 and 2 back.

With `-t=<terminal>`, the program's standard input and output (paths 0 and 1) move to that terminal, and so does anything the program `SHELL`s. The command channel keeps the original stdin and stderr.

Pipes must be in the boot file (OS9Boot); see ARCHITECTURE.md, P1.

Full usage: `l2b09run [#mem] [-b=<kb>] [-t=<terminal>] [<file> [<procedure>[(<params>)]]]`. An editor normally passes no file, then sends `load` commands.

- **`#mem` first.** Put the shell's `#mem` straight after the command name; Shell+ rejects it in front of an argument.
- **`-b=<kb>`** banks procedure code into <kb> kilobytes of far memory (ARCHITECTURE.md, P6), so programs larger than the workspace can be loaded, run and debugged. Line numbers, LIST, SAVE and the debugger work the same with banking. PACK does not.
- **Far arrays** (`DIM x(n):FAR type`, [FARARRAYS.md](FARARRAYS.md)) need nothing from the editor. The debugger's `print` and `let` work on their elements. PACK refuses procedures that use them (error 51).

## Runtime to editor

Output is plain text lines. Lines starting with `%` are events; everything else is human-readable output: LIST, DIR, `ERROR #nnn`, the offending source line with a `^` under the error, debugger PRINT output, and so on.

| Event | Meaning |
|---|---|
| `%READY` | Command mode; waiting for a command. |
| `%DEBUG <proc> <line>` | Debugger; stopped before the statement on `<line>` of `<proc>`, waiting for a debugger command. |
| `%ERROR <code> <proc> <line>` | Runtime error. It is followed by `%DEBUG`. |
| `%CERR <code> <proc> <line>` | Compile error while loading. The line is kept as an error line, and loading continues. |
| `%BERR <code> <proc> <line>` | Bind error when a procedure finishes loading, for example an undefined line number or unmatched control structure. |
| `%ASK Rewrite?` | SAVE/PACK target exists. Answer `y` or `n`. |

- **Codes** are Basic09 error numbers (see the Basic09 manual or the `errmsg` file).
- **Line numbers** are counted within the procedure: line 1 is the line after `PROCEDURE <proc>`. Every source line becomes exactly one I-code line, including blank and comment lines. So:

      file line = (file line of "PROCEDURE <proc>") + <line>

  This holds for source loaded with `load`. It does not hold for packed modules, or for source whose Basic09 line numbers are out of order (the loader moves such lines).
- **End of session:** when `l2b09run` exits (`bye`, or a program's `BYE`), pipe B reaches end of file (`E$EOF`). `F$Wait` returns its exit status.
- **Signals and pipe reads:** a signal that arrives while the editor waits in a pipe read ends the read with `E$EOF` and 0 bytes, just like the end of the pipe (pipeman). An editor with a signal handler must tell the two apart, for example with a flag set by the handler, and read again.
- **Editor gone:** if pipe A reaches end of file, `l2b09run` quits the debugger (as `q`) if it is in it, then exits as for `bye`, freeing its far memory.

## Editor to runtime

Send one command per line, ending with CR.

- **After `%READY`:** Basic09 commands such as `load <file>`, `run [<proc>[(<params>)]]`, `list [<proc>]`, `kill <proc>`, `save* <file>`, `pack* <file>`, `dir`, `mem [<n>]`, `chd`, `chx`, `$<shell command>` and `bye`. The line editor (`edit`/`e`) is not in `l2b09run`.
- **After `%DEBUG`:** debugger commands such as `cont`, `step [n]`, `list`, `print <expr>`, `let <var>:=<expr>`, `state`, `tron`, `troff`, `break <proc>`, `q` (quit to command mode) and `$<shell command>`. `print` output comes back on the channel, before the next `%DEBUG`.

**Incremental reload.** Compiling is slow: 937 lines take about 20 s at 6.29 MHz. So keep one `l2b09run` running and `load` a file holding only the procedures that changed; a loaded procedure replaces the one with the same name. Send `kill <proc>` for a procedure deleted in the editor.

**PACK modifies the workspace.** PACK strips the loaded procedures (REM, DIM, names), so a second `pack*` fails with error 51. That is stock Basic09 behaviour. Reload the source before packing again.

## Signals

Send these with `F$Send` to the runtime's process id (from `F$Fork`).

| Signal | Effect |
|---|---|
| `S$Intrpt` (3) | Break: the running program stops at the next statement, followed by `%DEBUG`. |

A BREAK typed on the program's terminal goes to the last process that used that terminal. That is not always `l2b09run`: an editor that writes to the terminal (for example to select the window) can get it, and should then pass it on with `F$Send`.
| `S$Abort` (2) | Abort: the program stops, followed by `%READY`. |

## Example (from test/p3)

    > start -t=/dd/l2b09/term.out
    < %READY
    > send load p3prog.b09
    < p3main
    < %READY
    > send run p3main
    > signal 3
    < BREAK: PROCEDURE p3main line 5
    < %DEBUG p3main 5
    > send print n
    < 5198
    < %DEBUG p3main 5
    > send cont
    > signal 2
    < %READY
    > send load p3bad.b09
    < p3calc
    < x:=2+
    <      ^
    < ERROR #012
    < %CERR 12 p3calc 2
    < 0010 ERROR #074
    < %BERR 74 p3calc 3
    < %READY

## Not yet covered

- **BREAK during INPUT.** Behaviour while the program is blocked in `INPUT` on its terminal is untested. The stock INPUT code treats a keyboard interrupt as an error exit.
- **Output on path 2.** Output the program writes to path 2 (`PRINT #2`) arrives on the command channel as free text.
- **No read timeout.** Pipes cannot be polled on NitrOS-9 (`pipeman` has no `SS.Ready`), so an editor that must not block needs its own design (for example, a reader process).
