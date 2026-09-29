# l2basic09

A Level 2 development environment for Basic09 on NitrOS-9.

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
| `modules/` | Basic09 subroutine modules (`syscall`, `inkey`). |
| `samples/` | Basic09 sample programs. |
| `test/`    | Emulator tests (`run` script, command files, expected output). |
| `tools/`   | `emu-wildbits.sh` (headless MAME runner), `bootfile-add.py` (add drivers to OS9Boot). |
| `docs/`    | Architecture and roadmap. |
| `build/`   | Build output (not tracked). |

## Building

You need `lwasm` and `python3`, plus a NitrOS-9 source tree for its `defs` directory.

    make                    # stock basic09/runb variants + subroutine modules into build/
    make check              # byte-compare stock builds with the NitrOS-9 tree's prebuilt copies
    make p1test             # P1 pipeline test, headless on Wildbits Jr2 under MAME
    make NITROS9DIR=/path/to/nitros9

`NITROS9DIR` defaults to `~/projects/wild/joust/nitros9_complete/nitros9`.

Emulator tests use that tree's MAME build (`mame/mame`, machine `wbjr2`) and its Level 2 image (`recipes/wildbits/l2/l2_wildbitsjr2.dsk`). The image is copied into `build/emu/<test>/` and never modified. Only 6809 builds are targeted; the 6309 variants are stock leftovers.

## Origin

The source was copied from `nitros9-languages/basic09` in the NitrOS-9 tree. It is the original Microware modular source, which reassembles byte-for-byte to the distributed Basic09 and RunB.
