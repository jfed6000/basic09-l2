# l2basic09

A Level 2 development environment for Basic09 on NitrOS-9.

Repository: <https://github.com/jfed6000/basic09-l2>

Goals:

- **Split the monolith.** The editor, the compiler and the runtime/debugger become separate processes, each with its own 64K address space. The runtime and debugger run the program in their own terminal.
- **Control from an editor.** An editor drives compile, run and debug over a pipe-based protocol.
- **Use the MMU.** Procedure code is banked in transparently, and large arrays can opt into far memory. Together these let programs use more than 64K.
- **Stay machine-neutral.** Wildbits (F256) is the first test target, and the CoCo 3 stays in mind. Machine-specific code sits behind assembly conditionals.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design and roadmap.

## Layout

| Path       | Contents |
|------------|----------|
| `src/`     | Microware modular Basic09/RunB source (comand, compil, binder, stmts, exprsn, cnvio) and the module build script. See `src/MICROWARE.md`. |
| `modules/` | Basic09 subroutine modules: `farmem` (memory beyond 64K, see [docs/FARMEM.md](docs/FARMEM.md)), `syscall`, `inkey`. |
| `samples/` | Basic09 sample programs. |
| `test/`    | Emulator tests (`run` script, command files, expected output). |
| `os9/`     | OS-9 side tools: `l2b09ctl`, a scripted editor stand-in for the protocol. |
| `tools/`   | `emu-wildbits.sh` (headless MAME runner), `bootfile-add.py` (add drivers to OS9Boot). |
| `docs/`    | Architecture and roadmap, the editor protocol, farmem and far arrays. |
| `build/`   | Build output (not tracked). |

## Building

You need `lwasm` and `python3`, plus a NitrOS-9 source tree for its `defs` directory.

    make                    # stock basic09/runb variants + subroutine modules into build/
    make check              # byte-compare stock builds with the NitrOS-9 tree's prebuilt copies
    make l2b09              # build/l2b09run, the l2basic09 runtime
    make p1test             # P1 pipeline test, headless on Wildbits Jr2 under MAME
    make p2test             # l2b09run test: -t terminal, debugger over stdin/stderr, line numbers
    make p3test             # protocol test: l2b09ctl drives l2b09run over pipes, with signals
    make p4test             # farmem: 256K of far records, stock RunB, leak check, benchmark
    make p6test             # code banking: 48K program in a 24K workspace, debugger, LIST/SAVE
    make p7test             # far arrays: REAL/BYTE/STRING/record arrays past 64K, errors, leaks, benchmark
    make loadtime           # benchmark: compile the 937-line startrek sample
    make main               # new-core disk images: build/main/l2_{wildbits,basic09-l2}{k2,jr2}.dsk
    make NITROS9DIR=/path/to/nitros9 BASEIMG=/path/to/l2_wildbitsjr2.dsk

The NitrOS-9 tree is an export of the nitros9project clones in `~/projects/wild/main` (`MAINDIR`): every `make` copies each clone's committed HEAD into `build/main/src/` when it has changed, and builds there, so the clones are never written to (`recipes/README.md`).

Emulator tests use the Wildbits MAME (`~/projects/wild/mame/mame`, machine `wbjr2`, override with `MAME`) and the stock Level 2 image built in that copy (`build/main/l2_wildbitsjr2.dsk`, override with `BASEIMG`). The image is copied into `build/emu/<test>/` and never modified. Only 6809 builds are targeted; the 6309 variants are stock leftovers.

## l2b09run

    l2b09run [#mem] [-b=<kb>] [-t=<terminal>] [<file> [<procedure>[(<params>)]]]

`l2b09run` is Basic09 without the line editor.
- It loads a source file, runs its first procedure (or the one named), then takes Basic09 commands.
- Commands and the debugger use its standard input and standard error.
- `-t` gives the program its own terminal, for example `-t=/vt2`.
- `-b=<kb>` keeps procedure code in <kb> kilobytes of far memory, mapped in when a procedure runs. Programs bigger than the workspace then load and run unchanged.
- `DIM big(14000):FAR REAL` puts an array's elements outside the 64K; it is used with normal syntax, and freed when its procedure returns. See [docs/FARARRAYS.md](docs/FARARRAYS.md).
- The debugger reports where it stopped as `BREAK: PROCEDURE <name> line <n>`. Line 1 is the line after the `PROCEDURE` header.
- For editors there is a line protocol with `%` event lines (`%READY`, `%DEBUG`, `%ERROR`, `%CERR`, `%BERR`, `%ASK`) and signals for break and abort. See [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Origin

The source was copied from `nitros9-languages/basic09` in the NitrOS-9 tree. It is the original Microware modular source, which reassembles byte-for-byte to the distributed Basic09 and RunB.
