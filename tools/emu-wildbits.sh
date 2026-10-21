#!/usr/bin/env bash
# Run a test directory on NitrOS-9 Level 2 for Wildbits Jr2 under MAME, headless.
#
# usage: tools/emu-wildbits.sh <testdir>
#
# The test directory holds:
#   run      OS-9 shell script, executed at boot from /dd/l2b09
#   modules  optional "<build file> <name>" lines; copied from build/ with exec attrs
#            to /dd/L2B09/<name>, or to /dd/<path> for a name /<path> (e.g. /CMDS/x)
#   bootmods optional list of build/ modules to add to OS9Boot (drivers, managers)
#   fetch    optional list of files to copy back from /dd/l2b09 after the run
#            (as text, CR to LF; "raw:<file>" copies it unchanged)
#   expect   optional "<file> <text>" lines; each text must appear in that file,
#            or "same <fileA> <fileB>": the two fetched files must be identical
#   gen      optional executable, run as "gen <dir>"; every file it writes to
#            <dir> is copied into /dd/l2b09 as it is (binary)
#   lua      optional MAME autoboot script (keyboard and mouse input)
#   *        every other file is copied into /dd/l2b09 as text (LF -> CR)
#
# The base image is copied, never modified. Results land in build/emu/<test>/:
# run.out/run.err (stdout/stderr of the script), fetched files, and mame.log
# (which ends with the emulator's text-screen snapshot).
#
# Environment overrides: MAME, BASEIMG, EMU_SECONDS (emulated seconds).
# The defaults are the Wildbits MAME and the stock Jr2 image that
# "make jr2main" builds from the NitrOS-9 main repos (recipes/README.md).

set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
MAME=${MAME:-$HOME/projects/wild/mame/mame}
BASEIMG=${BASEIMG:-$top/build/main/l2_wildbitsjr2.dsk}
EMU_SECONDS=${EMU_SECONDS:-60}

[ $# -eq 1 ] || { echo "usage: $0 <testdir>" >&2; exit 2; }
tdir=$(cd "$1" && pwd)
name=$(basename "$tdir")
out=$top/build/emu/$name
img=$out/$name.dsk

rm -rf "$out"
mkdir -p "$out"
cp "$BASEIMG" "$img"
# The emulated SD card only accepts sizes it can express in its CSD:
# pad to a power of two, at least 8 MiB (the disk's own size is unchanged).
size=$(stat -c %s "$img")
card=$((8 * 1024 * 1024))
while [ "$card" -lt "$size" ]; do card=$((card * 2)); done
truncate -s "$card" "$img"

os9 makdir "$img,L2B09"
for f in "$tdir"/*; do
    case $(basename "$f") in
        modules|fetch|bootmods|expect|gen|lua) ;;
        *) os9 copy -l -r "$f" "$img,L2B09/$(basename "$f")" ;;
    esac
done
if [ -x "$tdir/gen" ]; then
    mkdir -p "$out/gen"
    "$tdir/gen" "$out/gen"
    for f in "$out/gen"/*; do
        os9 copy -r "$f" "$img,L2B09/$(basename "$f")"
    done
fi
if [ -f "$tdir/modules" ]; then
    grep -v '^#' "$tdir/modules" | while read -r src dst; do
        [ -n "$src" ] || continue
        case "$dst" in /*) dst=${dst#/} ;; *) dst=L2B09/$dst ;; esac
        os9 copy -r "$top/build/$src" "$img,$dst"
        os9 attr -q -e -pe -r -pr "$img,$dst"
    done
fi

if [ -f "$tdir/bootmods" ]; then
    os9 copy -r "$img,OS9Boot" "$out/OS9Boot.orig"
    "$top/tools/bootfile-add.py" "$out/OS9Boot.orig" "$out/OS9Boot" \
        $(grep -v '^#' "$tdir/bootmods" | sed "s|^|$top/build/|")
    os9 copy -r "$out/OS9Boot" "$img,OS9Boot"
fi

printf 'shell /dd/l2b09/run >/dd/l2b09/run.out >>/dd/l2b09/run.err\n' > "$out/startup"
os9 copy -l -r "$out/startup" "$img,startup"

lua=()
[ -f "$tdir/lua" ] && lua=(-autoboot_script "$tdir/lua")
start=$(date +%s.%N)
# no host input: keys typed or mouse moves on this computer while a test
# runs would reach the emulated machine (a lua script drives its own ports);
# SDL's dummy drivers keep MAME off the desktop, so it takes no focus
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$MAME" wbjr2 -video none -sound none -nothrottle -skip_gameinfo \
    -keyboardprovider none -mouseprovider none -joystickprovider none -lightgunprovider none \
    -seconds_to_run "$EMU_SECONDS" -hard "$img" "${lua[@]}" > "$out/mame.log" 2>&1 || true
end=$(date +%s.%N)

for f in run.out run.err $( [ -f "$tdir/fetch" ] && cat "$tdir/fetch" ); do
    l=-l
    case $f in raw:*) f=${f#raw:}; l= ;; esac
    os9 copy $l -r "$img,L2B09/$f" "$out/$f" 2>/dev/null || true
    [ -f "$out/$f" ] || echo "(missing: $f)" > "$out/$f"
done

for f in run.out run.err $( [ -f "$tdir/fetch" ] && cat "$tdir/fetch" ); do
    case $f in
    raw:*) echo "---------------- ${f#raw:} ($(stat -c %s "$out/${f#raw:}") bytes, binary)" ;;
    *) echo "---------------- $f"; cat "$out/$f" ;;
    esac
done
echo "---------------- screen"
sed -n '/=== VRAM TEXT MATRIX SNAPSHOT ===/,/^=====/p' "$out/mame.log"
printf 'host time: %.1fs for %s emulated seconds\n' "$(echo "$end - $start" | bc)" "$EMU_SECONDS"

if [ -f "$tdir/expect" ]; then
    fail=0
    while read -r file text; do
        case $file in ''|'#'*) continue ;; esac
        if [ "$file" = same ]; then
            # "same <fileA> <fileB>": the two fetched files must be identical
            set -- $text
            if cmp -s "$out/$1" "$out/$2"; then
                echo "PASS  $1 same as $2"
            else
                echo "FAIL  $1 differs from $2"
                fail=1
            fi
            continue
        fi
        if grep -qF -- "$text" "$out/$file"; then
            echo "PASS  $file: $text"
        else
            echo "FAIL  $file: $text"
            fail=1
        fi
    done < "$tdir/expect"
    [ $fail -eq 0 ] && echo "$name: all checks passed" || { echo "$name: FAILED"; exit 1; }
fi
