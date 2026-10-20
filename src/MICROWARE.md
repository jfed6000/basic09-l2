# Basic09 / RunB — Microware's source, forked for basic09-l2

**Forked 2026-10-20.** Until then this directory was Microware's original source with every l2basic09 change behind `ifne L2B09` / `ifeq L2B09`, so that the stock builds stayed byte-identical to the NitrOS-9 tree's (`make check`). `tools/l2fork.py` then resolved those blocks as if `L2B09` were always on and dropped the stock-only code (the line editor, `src/dir`, `src/rename`); `l2b09run`, `l2b09cc`, `l2b09ovl` and the editor came out byte-identical, which was the check. The pristine source stays in the NitrOS-9 tree (`nitros9-languages/basic09`), and the stock programs are on its disk images. What remains conditional: `L2B09RT` (the runtime, without the compiler), `L2B09CC` (the compiler), `INCLUDED`/`EDITOR` (compil and binder in their RunB form for the runtime), `H6309`, and the machine conditionals. The rule is now compatibility (ARCHITECTURE.md): old programs, source and PACKed, must run on basic09-l2.

The history below describes the source as it came from Microware and NitrOS-9.

# Basic09 / RunB — Microware Original Source

This directory contains the original Microware multi-file source layout for
Basic09 and RunB:

- `comand.asm`
- `compil.asm`
- `binder.asm`
- `stmts.asm`
- `exprsn.asm`
- `cnvio.asm`

Supporting files — `defs`, `b09defs`, `b09type`, `jmpdefs`, `linkage`,
`editor` — replicate the original Microware build environment.

## Reproducing the Tandy binary

Commit `081ec321` is the point at which these sources assemble byte-for-byte
to the original Tandy-distributed Basic09 and RunB binaries.  The historical
build assembled the six source files separately, merged them in the order
listed above, patched the module size and jump table in `comand`, then ran
OS-9 `verify ... u` to update the header parity and module CRC.  The
`build-modular-basic09.py` script in this directory reproduces those steps.

Local compatibility edits for lwasm and the NitrOS-9 tree:

- `defs` includes the repository `os9.d` instead of `/h0/defs/os9defs`.
- `b09type` lets make pass `INCLUDED=RUNTIM+MATHPAK` for RunB builds.
- `cnvio.asm` reserves the final three CRC bytes explicitly.

## Canonical source

This modular layout is the sole source of truth for Basic09 and RunB in this
repository. Both the 6809 and 6309 modules shipped by the package are built
from these files. The older monolithic disassemblies and their extracted
floating-point fragments have been removed.

## 6309 optimizations

Beyond `081ec321`, the sources have been extended with HD6309-specific
optimizations: native multiply and divide (`MULD`/`DIVQ`), block transfer
(`TFM`), immediate bit-manipulation (`OIM`), quad-word load/store
(`LDQ`/`STQ`), and others. These are conditioned on the `H6309` assembly flag
and do not affect the 6809 output.
