#!/usr/bin/env python3
"""Sort Basic09's keyword table (KEYTAB in src/comand.asm) by name and
give l2b09cc a first-letter index to it (docs/OVERVIEW.html, "Compiler
speed-ups").

The compiler looks up every name in the source in KEYTAB before the
procedure's own names, one entry after another.  Each entry carries its
token, and the decompiler finds entries by token, so their order does not
matter; sorted, each letter's keywords are together, and KWIDX (assembled
in l2b09cc only, just in front of the table's header, where compil finds
it from KEYWORDS) gives each letter's first entry and count.

comand is always assembled with MATHPAK on (only compil, binder and
exprsn get another INCLUDED), so the MATHPAK conditionals in the table
are resolved here.  Run it again after adding a keyword.

usage: kwsort.py [src/comand.asm]
"""
import re
import sys

p = sys.argv[1] if len(sys.argv) > 1 else 'src/comand.asm'
lines = open(p, encoding='latin1').read().split('\n')
start = next(i for i, l in enumerate(lines) if l.strip() == '* Keyword Table')
kt = next(i for i, l in enumerate(lines) if l.startswith('KEYTAB'))
end = next(i for i in range(kt, len(lines)) if lines[i].startswith(' ttl DECOMPILE'))

entries, i = [], kt + 1
while i < end:
    l = lines[i]
    s = l.strip()
    if not s or re.match(r'(ifne|ifeq)\s+INCLUDED&MATHPAK|else$|endc$', s) or s.startswith('*') \
            or re.match(r'KW\.[A-Z]\s+equ', s):
        i += 1
        continue
    m = re.match(r'^\s+fcb\s+T\.\w+,\w+', l)
    if not m:
        if s.startswith('pag') or s.startswith('ttl'):
            i += 1
            continue
        break
    fcs = lines[i + 1]
    n = re.match(r'^(\S*)\s+fcs\s+"([^"]+)"', fcs)
    if not n:
        sys.exit('%s:%d: expected a fcs line after %r' % (p, i + 2, l))
    entries.append((n.group(2).upper(), l, fcs))
    i += 2
rest = i
# the header: the count of the full table
hdr = [l for l in lines[start:kt] if re.match(r'^\s+fdb\s+\d+', l)]
count = len(entries)
if count != 115:
    sys.exit('%d entries, expected 115 (update this script for a new keyword)' % count)
entries.sort(key=lambda e: e[0])
out = ['* Keyword Table',
       '*   Sorted by name (tools/kwsort.py): every name in the source is',
       '*   looked up here first.  l2b09cc has KWIDX, a first-letter index:',
       '*   each letter\'s first entry (from KEYTAB) and how many there are.',
       '',
       ' ifne L2B09CC',
       'KWIDX equ *']
for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
    n = sum(1 for e in entries if e[0][0] == c)
    out.append(' fdb %s' % ('KW.%s-KEYTAB' % c if n else '0'))
    out.append(' fcb %d %s' % (n, c))
out += ['KWISZ equ *-KWIDX', ' ifne KWISZ-26*3', " error KWIDX must be 26*3 bytes (compil's KWSRCH)", ' endc', ' endc',
        ' fdb %d Number of entries in keytab' % count,
        ' fcb 2 number of skip bytes per entry', '', 'KEYTAB equ *']
last = ''
for name, f, s in entries:
    if name[0] != last and name[0].isalpha():
        out.append('KW.%s equ *' % name[0])
        last = name[0]
    out += [f, s]
out.append('')
lines = lines[:start] + out + lines[rest:]
open(p, 'w', encoding='latin1').write('\n'.join(lines))
print('%s: %d keywords sorted, index for %d letters' %
      (p, count, len({e[0][0] for e in entries if e[0][0].isalpha()})))
