# Recipes: disk images from the NitrOS-9 main tree

The Wildbits core changed with Longview (rc22 and later): the device pages
moved from `$C0` to `$FC`-`$FF`, and NitrOS-9 was updated to match. The
NitrOS-9 tree at `~/projects/wild/main/nitros9` tracks that work. These
recipes build a basic09-l2 disk image from it **without copying it**.

```sh
make k2main                     # from the top: recipes/wildbits/basic09-l2/l2_basic09-l2k2.dsk
make jr2main                    #               recipes/wildbits/basic09-l2/l2_basic09-l2jr2.dsk
cd recipes/wildbits/basic09-l2 && make PLATFORM=jr2      # the same thing
make k2main NITROS9MAIN=/other/nitros9   # nitros9-languages is taken from beside it
```

The image is the tree's stock Wildbits Level 2 image plus:
- the pipe modules (`pipeman piper pipe`) in OS9Boot;
- `basic09-l2`, `l2b09run`, `farmem`, `syscall` and `inkey` in CMDS, built
  with the main tree's defs into `build/main/`;
- `examples/` in `/dd/L2B09`.

## How it works

`recipes/wildbits/basic09-l2/` has the same depth as a recipe in the tree,
so the tree's relative includes resolve to the forwarding files here:

| File | Forwards to |
|---|---|
| `nitros9.mak` | sets and pins `NITROS9DIR` (default `~/projects/wild/main/nitros9`) and `LANGUAGES` |
| `rules.mak`, `libs.mak` | `$(NITROS9DIR)/recipes/rules.mak`, `libs.mak` |
| `wildbits/wildbits.mak` | `$(NITROS9DIR)/recipes/wildbits/wildbits.mak` |

`wildbits/basic09-l2/makefile` includes the tree's own `l2/makefile`, so the
image follows upstream changes to the stock recipe. `recipe.mak` is read by
`wildbits.mak`'s `-include recipe.mak` hook and holds the additions. A new
recipe for another project is a copy of `wildbits/basic09-l2/` (with these
forwarding files beside it).

Notes:
- `nitros9-languages` (stock `basic09`, `runb`), `nitros9-apps` and
  `nitros9-games` are taken from beside the tree.
- From the top-level Makefile, set `NITROS9MAIN`, not `NITROS9DIR`: the
  top level exports `NITROS9DIR` for the emulator (joust) tree.
- The stock recipe writes the generated fonts and backgrounds into the
  tree's `level1/wildbits/sys/`; that is upstream behaviour.
- The K2 OS9Boot with the pipes is 31,744 bytes; the tree's limit is 32,256.

## Two images until MAME catches up

| | Emulator tests (`make p*test`, `k2img`, `jr2img`) | Hardware with the new core (`k2main`, `jr2main`) |
|---|---|---|
| NitrOS-9 tree | `~/projects/wild/joust/nitros9_complete/nitros9` | `~/projects/wild/main/nitros9` |
| Build output | `build/` | `build/main/`, image in the recipe folder |

basic09-l2 uses only the defs and OS-9 system calls (no hardware
addresses), so the same source builds for both. When the Wildbits MAME in
`~/projects/wild/mame` runs the new core, the tests can move to the main tree.
