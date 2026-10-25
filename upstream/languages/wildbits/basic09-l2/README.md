# basic09-l2

A Basic09 development environment for NitrOS-9 Level 2 on the Wildbits
computers (K2 and Jr2, Longview core rc22 or later): a full-screen editor
with menus, a debugger, and a runtime whose programs can use memory beyond
64K.

## A fork, not a change to Basic09

basic09-l2 is a separate product. Its Basic09 source in `src/` was forked
from `../../basic09/microware` on 2026-10-20 and has been changed since
then. It does **not** change the original Basic09 or RunB in any way:
`basic09/microware` remains the authoritative source of those, and the
stock `basic09` and `runb` modules are built from it as before.

The rule basic09-l2 keeps is compatibility: Basic09 source files load,
compile and run unchanged, and packed I-code modules made by stock Basic09
run under basic09-l2's runtime and under `runb-l2`.

It is for the Wildbits only. Its development repository, with the tests
(run under MAME), the design notes and the history, is
https://github.com/jfed6000/basic09-l2; this directory is exported from it
(see "Version" below).

## Modules

| Module | What it is |
|---|---|
| `basic09-l2` | The editor: menus, find and replace, undo, mouse, syntax colours, pretty print. It runs `l2b09run` as a separate process and talks to it over pipes. |
| `l2b09run` | The runtime: Basic09's interpreter, commands and debugger, without the compiler. |
| `l2b09cc` | The compiler, started by `l2b09run` as a separate process. |
| `l2b09ovl` | Commands `l2b09run` loads only when used (PACK). |
| `runb-l2` | RunB built from this source (module name `RunB`). It runs stock packed programs and also programs with FAR arrays. |
| `l2b09help` | The help browser (F1 in the editor). |
| `basic09-l2.hlp` | The help pages, built from `help/*.txt`. |
| `farmem` | A subroutine module for memory beyond 64K (`RUN farmem(...)`). |

The editor and `l2b09run` need the pipe modules (`pipeman`, `piper`,
`pipe`) in the boot file; loading them at run time does not work.

## Layout

- `src/`: the forked Basic09 source and `build-modular-basic09.py`
  (`src/MICROWARE.md` describes the fork).
- `editor/`: the editor. `kwtab.asm` is generated from the keyword table
  in `src/comand.asm` by a tool in the development repository, and
  committed here.
- `help/`: the help browser, the help pages and `mkhelp.py`, which builds
  the help file and checks that every Basic09 keyword and error has a page.
- `modules/`: `farmem`.
- `examples/`: `demo.b09` and `fardemo.b09` (FAR arrays).

## Building

From the top of nitros9-languages, `make` builds this directory with the
others. Here, on its own:

```sh
make NITROS9DIR=/path/to/nitros9
make l2b09run          # one module
make clean
```

It needs `lwasm` and Python 3, as `basic09/microware` does. No module may
pass 24,576 bytes (three 8K blocks); the build warns if one does.

## Version

Exported from jfed6000/basic09-l2 commit @COMMIT@.
