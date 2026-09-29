#!/usr/bin/env python3
"""Compile an l2b09ed key script into the raw bytes the editor reads.

A key script is a sequence of tokens (whitespace separated, '#' starts a
comment):

    "text"        type the characters (\\" and \\\\ escape)
    up down left right              arrows
    pgup pgdn wleft wright          Ctrl+arrows
    top bottom                      Ctrl+Shift+Up/Down
    sup sdown sleft sright          Shift+arrows
    swleft swright                  Ctrl+Shift+Left/Right
    home bs del esc enter tab
    f1 ... f8
    ^a ... ^z     Ctrl+letter
    alt-a ...     Alt+letter
    name*N        repeat a key N times

When the editor's key input is not a terminal it cannot ask for the key
sense bits (SS.KySns), so keys that need them are sent as
$FF <kysns> <char>.

usage: keys.py <script> <out.bin>   (or import compile_keys)
"""
import re
import sys

SHF, CTRL, ALT, UP, DOWN, LEFT, RIGHT = 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40


def pfx(sns, ch):
    return bytes([0xFF, sns, ch])


NAMED = {
    'up': pfx(UP, 0x0C), 'down': pfx(DOWN, 0x0A),
    'left': pfx(LEFT, 0x08), 'right': pfx(RIGHT, 0x09),
    'pgup': pfx(UP | CTRL, 0x0C), 'pgdn': pfx(DOWN | CTRL, 0x0A),
    'wleft': pfx(LEFT | CTRL, 0x08), 'wright': pfx(RIGHT | CTRL, 0x09),
    'sup': pfx(UP | SHF, 0x0C), 'sdown': pfx(DOWN | SHF, 0x0A),
    'sleft': pfx(LEFT | SHF, 0x08), 'sright': pfx(RIGHT | SHF, 0x09),
    'top': pfx(UP | CTRL | SHF, 0x0C), 'bottom': pfx(DOWN | CTRL | SHF, 0x0A),
    'swleft': pfx(LEFT | CTRL | SHF, 0x08), 'swright': pfx(RIGHT | CTRL | SHF, 0x09),
    'home': b'\x01', 'bs': b'\x08', 'del': pfx(SHF, 0x18), 'esc': b'\x05',
    'enter': b'\x0d', 'tab': b'\x09',
}
for n in range(1, 9):
    NAMED['f%d' % n] = bytes([0xA0 + n])

TOKEN = re.compile(r'"((?:[^"\\]|\\.)*)"(?:\*(\d+))?|(\S+)')


def key(name):
    name = name.lower()
    if name in NAMED:
        return NAMED[name]
    if len(name) == 2 and name[0] == '^' and name[1].isalpha():
        return pfx(CTRL, ord(name[1]) - 0x60)
    if name.startswith('alt-') and len(name) == 5 and name[4].isalpha():
        return pfx(ALT, ord(name[4]))
    raise ValueError('unknown key: ' + name)


def compile_keys(text):
    out = bytearray()
    for line in text.splitlines():
        for m in TOKEN.finditer(line):
            if m.group(1) is not None:
                s = re.sub(r'\\(.)', r'\1', m.group(1)).encode('ascii')
                out += s * int(m.group(2) or 1)
            else:
                tok = m.group(3)
                if tok.startswith('#'):
                    break
                n = 1
                if '*' in tok:
                    tok, cnt = tok.split('*')
                    n = int(cnt)
                out += key(tok) * n
    return bytes(out)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[1]) as f:
        data = compile_keys(f.read())
    with open(sys.argv[2], 'wb') as f:
        f.write(data)
