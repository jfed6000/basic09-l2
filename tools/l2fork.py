#!/usr/bin/env python3
"""Fork Microware's Basic09 source into basic09-l2's own (2026-10-20).

Resolves every "ifne L2B09" (kept) and "ifeq L2B09" (dropped) block in
the assembly files given, as if L2B09 were always on, and leaves all
other conditionals (INCLUDED&EDITOR, H6309, wildbits, L2B09RT, L2B09CC,
Level ...) as they are.  The stock-only code goes; the l2basic09 builds
must come out byte-identical, which is the check that it was right.

Directives are only recognised on indented lines (column 1 is a label:
the source has labels named IF and ELSE).

usage: l2fork.py <file>...   (rewrites them in place)
"""
import re
import sys

COND = re.compile(r'^\s+(if\w*)\b\s*(\S*)', re.I)
ELSE = re.compile(r'^\s+else\b', re.I)
ENDC = re.compile(r'^\s+(endc|endif)\b', re.I)


def resolve(lines, where):
    out, stack = [], []   # frames: [resolved?, keep this branch?]

    def visible():
        return all(keep for res, keep in stack if res)

    for n, line in enumerate(lines, 1):
        m = COND.match(line)
        if m and m.group(1).lower() != 'if':
            d, arg = m.group(1).lower(), m.group(2)
            if arg == 'L2B09' and d in ('ifne', 'ifeq'):
                stack.append([True, d == 'ifne'])
                continue
            if arg.upper() == 'L2B09':
                sys.exit('%s:%d: %s L2B09 is not handled' % (where, n, d))
            if visible():
                out.append(line)
            stack.append([False, True])
            continue
        if ELSE.match(line):
            if not stack:
                sys.exit('%s:%d: else without if' % (where, n))
            if stack[-1][0]:
                stack[-1][1] = not stack[-1][1]
                continue
            if visible():
                out.append(line)
            continue
        if ENDC.match(line):
            if not stack:
                sys.exit('%s:%d: endc without if' % (where, n))
            res, _ = stack.pop()
            if not res and visible():
                out.append(line)
            continue
        if visible():
            out.append(line)
    if stack:
        sys.exit('%s: %d conditionals not closed' % (where, len(stack)))
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for p in sys.argv[1:]:
        text = open(p, encoding='latin1').read()
        lines = text.split('\n')
        out = resolve(lines, p)
        if out != lines:
            open(p, 'w', encoding='latin1').write('\n'.join(out))
            print('%s: %d lines -> %d' % (p, len(lines), len(out)))


if __name__ == '__main__':
    main()
