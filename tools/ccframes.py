#!/usr/bin/env python3
"""Check and list l2b09cc's stdout (docs/COMPILER.md): "%PROC <name> <bytes>"
lines, each followed by that many bytes, and "%DONE" lines.  Each procedure
must start with a module header ($87CD) whose size and name match the line.

usage: ccframes.py <stdout file> [-x <dir>]   (-x: write each procedure to <dir>/<name>)
"""
import os
import sys


def frames(data):
    i, out = 0, []
    while i < len(data):
        j = data.index(b'\r', i)
        line = data[i:j].decode('latin1')
        i = j + 1
        if line == '%DONE':
            out.append(('done', None, None))
            continue
        tag, name, size = line.split()
        if tag != '%PROC':
            raise ValueError('unexpected line %r' % line)
        size = int(size)
        body = data[i:i + size]
        if len(body) != size:
            raise ValueError('%s: %d bytes, %d expected' % (name, len(body), size))
        i += size
        out.append(('proc', name, body))
    return out


def check(name, body):
    if body[:2] != b'\x87\xcd':
        return 'no module header'
    if int.from_bytes(body[2:4], 'big') != len(body):
        return 'header size %d' % int.from_bytes(body[2:4], 'big')
    n = int.from_bytes(body[4:6], 'big')
    s = ''
    for c in body[n:n + 32]:
        s += chr(c & 0x7f)
        if c & 0x80:
            break
    if s != name:
        return 'header name %r' % s
    return None


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    fr = frames(open(a[0], 'rb').read())
    bad = 0
    for kind, name, body in fr:
        if kind == 'done':
            print('%DONE')
            continue
        err = check(name, body)
        stat = body[0x17] if len(body) > 0x17 else 0  # P.STAT
        print('%%PROC %-14s %5d bytes%s%s' % (name, len(body), '  errors' if stat & 1 else '',
                                            '  BAD: ' + err if err else ''))
        bad += err is not None
        if '-x' in a:
            d = a[a.index('-x') + 1]
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, name), 'wb').write(body)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
