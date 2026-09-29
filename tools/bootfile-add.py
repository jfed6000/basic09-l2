#!/usr/bin/env python3
"""Insert OS-9 modules into a Level 2 bootfile, just before the kernel (Krn).

usage: bootfile-add.py <in-bootfile> <out-bootfile> <module file>...

Modules loaded at runtime cannot be used as system-state drivers when the
system map has no free 8K DAT slot (true on Wildbits L2), so file managers,
drivers and descriptors such as the pipe modules have to be in the bootfile.
The bootfile carries $FF padding at the front (os9 padrom) so that Krn ends
the file; the result is re-padded the same way to a 256-byte multiple.
"""

import sys

MAX_L2_BOOTFILE = 32256  # $7E00: $8000-$FDFF window, see recipes/wildbits/wildbits.mak


def modules(image):
    """Yield (offset, size, name) for each module in a merged module image."""
    off = 0
    while off + 9 <= len(image) and image[off] == 0x87 and image[off + 1] == 0xCD:
        size = (image[off + 2] << 8) | image[off + 3]
        noff = (image[off + 4] << 8) | image[off + 5]
        name = bytearray()
        i = off + noff
        while True:
            c = image[i]
            name.append(c & 0x7F)
            i += 1
            if c & 0x80:
                break
        yield off, size, name.decode()
        off += size


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    src, dst, *extra = sys.argv[1:]
    image = open(src, 'rb').read()
    image = image[len(image) - len(image.lstrip(b'\xff')):]  # drop front padding
    mods = list(modules(image))
    krn = [m for m in mods if m[2] == 'Krn']
    if not krn:
        sys.exit(f"{src}: no Krn module found")
    koff = krn[0][0]

    added = b''.join(open(f, 'rb').read() for f in extra)
    for _, _, name in modules(added):
        if any(m[2] == name for m in mods):
            sys.exit(f"{src}: already contains {name}")

    # keep everything from Krn to the end: bootos9 expects Krn at $EE00 with
    # the file ending at $FE00, and the stock file has trailing bytes after Krn
    out = image[:koff] + added + image[koff:]
    out = b'\xff' * (-len(out) % 256) + out
    if len(out) > MAX_L2_BOOTFILE:
        sys.exit(f"bootfile would be {len(out)} bytes, over the {MAX_L2_BOOTFILE} byte L2 limit")
    open(dst, 'wb').write(out)
    print(f"{dst}: {len(out)} bytes, added {', '.join(n for _, _, n in modules(added))}")


if __name__ == '__main__':
    main()
