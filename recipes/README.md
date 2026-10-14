# Recipes: disk images from the NitrOS-9 main repos

The Wildbits core changed with Longview (rc22 and later): the device pages
moved from `$C0` to `$FC`-`$FF`, and NitrOS-9 was updated to match. The
clones in `~/projects/wild/main` (`nitros9`, `nitros9-languages`,
`nitros9-apps`, `nitros9-games`, from nitros9project) track that work and
are kept **pristine**: nothing here builds in them or writes to them.

```sh
make main                       # all four images below
make k2main                     # build/main/l2_wildbitsk2.dsk, l2_basic09-l2k2.dsk
make jr2main                    # build/main/l2_wildbitsjr2.dsk, l2_basic09-l2jr2.dsk
make main MAINDIR=/other/main   # clones somewhere else
```

| Image | What it is | For |
|---|---|---|
| `l2_wildbits{k2,jr2}.dsk` | The stock Wildbits Level 2 image, from the tree's own `recipes/wildbits/l2` | Emulator tests (the default `BASEIMG`) |
| `l2_basic09-l2{k2,jr2}.dsk` | The stock image plus basic09-l2 (below) | Real hardware |

The basic09-l2 image adds:
- the pipe modules (`pipeman piper pipe`) in OS9Boot;
- `basic09-l2`, `l2b09run` and its overlay `l2b09ovl`, `farmem`, `syscall` and `inkey` in CMDS, built
  with the copy's defs into `build/main/`;
- `examples/` in `/dd/L2B09` (`.b09` files as text, with LF turned into CR; anything else byte for byte).

## How it works

1. `export-main.sh` writes each clone's committed `HEAD` into
   `build/main/src/<repo>` with `git archive`, which only reads the clone.
   A copy is replaced only when that `HEAD` changes (the commit is kept in
   `build/main/src/<repo>.head`), so later builds are incremental. If a
   clone has uncommitted changes, it warns and exports `HEAD` anyway.
2. `wildbits/basic09-l2/` (`makefile` and `recipe.mak`) is copied into the
   copy's `recipes/wildbits/`, beside the stock recipes, so its relative
   includes (`../l2/makefile`, `../wildbits.mak`, `../../rules.mak`) are
   the tree's own.
3. The stock `l2` recipe and `basic09-l2` are built there, with
   `NITROS9DIR`, `LANGUAGES` and `NITROS9_APPS_DIR` pointing at the copy,
   and the images are copied to `build/main/`.

`makefile` includes the stock `l2/makefile`, so the image follows upstream
changes to the stock recipe. `recipe.mak` is read through `wildbits.mak`'s
`-include recipe.mak` hook and holds the additions. A recipe for another
project is a copy of `wildbits/basic09-l2/` plus the top-level Makefile's
`mainsrc` and `%main` rules.

Notes:
- The upstream build writes generated files (fonts, backgrounds, the
  `basic09_wildbits` it builds in `nitros9-languages`); here they all land
  in the copy.
- `make clean` removes `build/`, the copy included; the next `make main`
  exports and builds everything again (about three minutes).
- The top-level Makefile runs `export-main.sh` whenever it is read (except
  for `make clean`), and its default `NITROS9DIR` is the copy, so `defs`,
  the pipe modules and `make check`'s reference builds all come from it.
- The K2 OS9Boot with the pipes is 31,744 bytes; the tree's limit is 32,256.
- The stock images are 262,134 blocks. The emulated SD card accepts only
  sizes it can express, so `tools/emu-wildbits.sh` pads its copy to a power
  of two.

## Emulator

Since 2026-10-12 the Wildbits MAME (`~/projects/wild/mame`) emulates the
Longview core, and since 2026-10-13 the tests run on
`build/main/l2_wildbitsjr2.dsk` (built on demand). The old-core joust tree
still builds with `NITROS9DIR=~/projects/wild/joust/nitros9_complete/nitros9
BASEIMG=<its l2_wildbitsjr2.dsk>`, but MAME no longer shows its screen.
