#!/bin/sh
# Export basic09-l2 into a nitros9-languages tree as wildbits/basic09-l2
# (docs/ARCHITECTURE.md, "Upstreaming to NitrOS-9").  The languages copy
# is never edited by hand: it is this export of the files that ship, plus
# upstream/languages/ (the makefiles and README written for that tree).
#
# usage: tools/export-lang.sh <nitros9-languages tree>
#
# wildbits/basic09-l2 is replaced as a whole; the top-level Makefile gets
# "wildbits" in its dirs.  It exports the working tree and warns if a file
# it exports is new or changed and not committed (the README names the
# commit).
set -e

[ $# -eq 1 ] || { echo "usage: $0 <nitros9-languages tree>" >&2; exit 2; }
top=$(cd "$(dirname "$0")/.." && pwd)
lang=$1
[ -f "$lang/Makefile" ] && [ -d "$lang/basic09" ] ||
    { echo "$lang: not a nitros9-languages tree" >&2; exit 1; }
dest=$lang/wildbits/basic09-l2

SRC="b09defs b09type binder.asm build-modular-basic09.py cnvio.asm comand.asm
     compil.asm defs editor exprsn.asm jmpdefs linkage mem MICROWARE.md
     overlay.asm pack stmts.asm"
EXAMPLES="demo.b09 fardemo.b09"

cd "$top"
paths="upstream/languages $(for f in $SRC; do echo src/$f; done) os9/basic09-l2
       os9/l2b09help help tools/mkhelp.py modules/farmem.asm
       $(for f in $EXAMPLES; do echo examples/$f; done)"
changed=$(git status --porcelain -- $paths)
if [ -n "$changed" ]; then
    echo "warning: exported files are not all committed:" >&2
    echo "$changed" >&2
fi

rm -rf "$dest"
mkdir -p "$dest/src" "$dest/editor" "$dest/help" "$dest/modules" "$dest/examples"
cp upstream/languages/wildbits/Makefile "$lang/wildbits/Makefile"
cp upstream/languages/wildbits/basic09-l2/Makefile \
   upstream/languages/wildbits/basic09-l2/defsfile "$dest/"
commit=$(git rev-parse --short HEAD)
sed "s/@COMMIT@/$commit/" upstream/languages/wildbits/basic09-l2/README.md > "$dest/README.md"
for f in $SRC; do cp "src/$f" "$dest/src/"; done
cp os9/basic09-l2/*.asm "$dest/editor/"
cp os9/l2b09help/l2b09help.asm help/*.txt tools/mkhelp.py "$dest/help/"
cp modules/farmem.asm "$dest/modules/"
for f in $EXAMPLES; do cp "examples/$f" "$dest/examples/"; done

# the top-level Makefile builds wildbits with the other directories
if ! grep -q '^dirs = .*\bwildbits\b' "$lang/Makefile"; then
    sed -i 's/^\(dirs = .*\)$/\1 wildbits/' "$lang/Makefile"
fi
grep -q '^dirs = .*\bwildbits\b' "$lang/Makefile" ||
    { echo "$lang/Makefile: could not add wildbits to dirs" >&2; exit 1; }

echo "exported basic09-l2 $commit to $dest"
