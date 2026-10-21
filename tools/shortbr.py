#!/usr/bin/env python3
"""Find long branches in an lwasm listing whose target is in short range.

  shortbr.py <listing> [--apply <srcdir>]

Lists each lbra/lbsr/lbcc... whose short form (2 bytes) would reach its
target, from the bytes in the listing.  Removing bytes between a branch
and its target only brings them closer, so all of them can be shortened
at once.  --apply rewrites the source lines (the file is the one named in
the listing, found in <srcdir>), keeping the column layout.  Lines with
"(long)" in their comment are left alone.  Saves 1 byte per lbra/lbsr and
2 per long conditional.
"""
import os
import re
import sys

LINE = re.compile(r'^([0-9A-F]{4}) ([0-9A-F]+)\s+\(\s*([^)]*)\):(\d+) (.*)$')
OPS = {'lbra': 'bra', 'lbsr': 'bsr'}
CONDS = ('brn bhi bls bcc bhs bcs blo bne beq bvc bvs bpl bmi bge blt bgt ble').split()


def main():
    a = sys.argv[1:]
    hits, saved = [], 0
    for l in open(a[0], errors='replace'):
        m = LINE.match(l.rstrip('\n'))
        if not m:
            continue
        addr, code, fname, ln, src = int(m.group(1), 16), bytes.fromhex(m.group(2)), m.group(3).strip(), int(m.group(4)), m.group(5)
        f = src.split()
        ops = [w.lower() for w in f[:2]]
        op = ops[0] if ops and ops[0] in OPS or (ops and ops[0][1:] in CONDS and ops[0][0] == 'l') else (ops[1] if len(ops) > 1 and (ops[1] in OPS or (ops[1][0] == 'l' and ops[1][1:] in CONDS)) else None)
        if not op or '(long)' in src:
            continue
        if op in ('lbra', 'lbsr') and len(code) == 3:
            off, n = int.from_bytes(code[1:3], 'big', signed=True), 3
        elif len(code) == 4 and code[0] == 0x10:
            off, n = int.from_bytes(code[2:4], 'big', signed=True), 4
        else:
            continue
        tgt = addr + n + off
        d = tgt - (addr + 2)
        if -128 <= d <= 127:
            hits.append((fname, ln, op))
            saved += n - 2
    print('%d branches, %d bytes' % (len(hits), saved))
    if len(a) == 3 and a[1] == '--apply':
        byfile = {}
        for fname, ln, op in hits:
            byfile.setdefault(os.path.basename(fname), []).append((ln, op))
        for base, lst in byfile.items():
            p = os.path.join(a[2], base)
            lines = open(p).read().split('\n')
            for ln, op in lst:
                s = lines[ln - 1]
                new = OPS.get(op, op[1:])
                s2 = re.sub(r'(?<![\w])' + op + r'(\s+)', lambda mm: new + ' ' + mm.group(1), s, count=1, flags=re.I)
                assert s2 != s, (p, ln, s)
                lines[ln - 1] = s2
            open(p, 'w').write('\n'.join(lines))
    else:
        for h in hits:
            print('%s:%d %s' % h)


if __name__ == '__main__':
    main()
