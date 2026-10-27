#!/bin/sh
# Screenshots of the editor for the video slides, taken in MAME.
#
# usage: tools/shots/shots.sh [<scenario>]   (default: editor)
#
# A scenario is a test directory under tools/shots/ (as for
# tools/emu-wildbits.sh), whose lua script drives the editor and calls
# scr:snapshot("l2b09shot-<name>.png").  MAME writes those to its snapshot
# directory (MAME_SNAPDIR, default ~/.mame/snap); this script moves them to
# build/shots/ and adds a copy scaled 2x with hard pixel edges
# (<name>-2x.png, 1280x960), the size the slides use.
#
# edit: the manual's chapter 2: a selection with the Edit menu open
# (editmenu), Find (find, found), the Options menu (options) and a Make
# with errors (errors).
#
# editor: tools/shots/editor/stars.b09 with the Run menu open (runmenu),
# and the debugger stopped at a breakpoint on its third pass with watches
# on count and s (debug); plain is the editor before the menu opens.
set -e

top=$(cd "$(dirname "$0")/../.." && pwd)
scenario=${1:-editor}
snap=${MAME_SNAPDIR:-$HOME/.mame/snap}
out=$top/build/shots

rm -f "$snap"/l2b09shot-*.png
mkdir -p "$out"
EMU_SECONDS=${EMU_SECONDS:-200} "$top/tools/emu-wildbits.sh" "$top/tools/shots/$scenario" > "$out/emu.out"
set -- "$snap"/l2b09shot-*.png
[ -f "$1" ] || { echo "no screenshots in $snap (see build/emu/$scenario/mame.log)" >&2; exit 1; }
for f; do
    name=$(basename "$f" .png)
    name=${name#l2b09shot-}
    mv "$f" "$out/$name.png"
    python3 -c "
import sys
from PIL import Image
im = Image.open(sys.argv[1])
im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(sys.argv[2])
" "$out/$name.png" "$out/$name-2x.png" || echo "warning: no 2x copy of $name (needs Python's PIL)" >&2
    echo "$out/$name.png"
done
