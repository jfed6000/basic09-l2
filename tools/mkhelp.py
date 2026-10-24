#!/usr/bin/env python3
"""Compile the help pages (help/*.txt) into basic09-l2.hlp for l2b09help.

The source format and the compiled layout are in docs/HELP.md.  Checks:
unique names, every link has a target, lines fit, every KEYTAB word
(and the editor's DEFUSE and USE) is a name, every error in errmsg has
a page "Error <n>"; no page is over HPMAX and the name table not over NTMAX
(the viewer's buffers, os9/l2b09help).

usage: mkhelp.py [-o <out>] [--errmsg <file>] [--keytab <comand.asm>]
                 [--nocheck] [--nolinks] [<help dir or files>...]
"""
import argparse
import glob
import os
import re
import sys

TOP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
WIDTH = 76          # body line width
HPMAX = 12 * 1024   # largest page the viewer holds
NTMAX = 6 * 1024    # largest name table it holds
LINK, LEND = 0x01, 0x02
CR = 0x0D


def keytab_words(path):
    lines = open(path, encoding='latin1').read().splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith('KEYTAB'))
    words, kind = [], None
    for l in lines[start + 1:]:
        if re.match(r'^\s+fdb\s+0\b', l):
            break
        m = re.match(r'^\s+fcb\s+T\.\w+,(\w+)', l)
        if m:
            kind = m.group(1)
            continue
        m = re.match(r'^\S*\s+fcs\s+"([^"]+)"', l)
        if m and kind:
            words.append(m.group(1).upper())
            kind = None
    return words + ['DEFUSE', 'USE']


def errmsg_numbers(path):
    nums = []
    for l in open(path, encoding='latin1'):
        m = re.match(r'\s*(\d+)\s*-', l)
        if m:
            nums.append(int(m.group(1)))
    return nums


class Topic:
    def __init__(self, name, title, cat, where):
        self.name, self.title, self.cat, self.where = name, title, cat, where
        self.also, self.body = [], []


def key(name):
    return name.upper()


def parse(files):
    topics, cur, cat = [], None, ''
    for f in files:
        for n, line in enumerate(open(f, encoding='utf-8'), 1):
            line = line.rstrip('\n').rstrip()
            where = '%s:%d' % (os.path.basename(f), n)
            if line.startswith('#'):
                continue
            if line.startswith('@category '):
                cat = line[10:].strip()
                cur = None
                continue
            if line.startswith('== '):
                name, _, title = line[3:].partition('|')
                cur = Topic(name.strip(), title.strip() or name.strip(), cat, where)
                topics.append(cur)
                continue
            if cur is None:
                if line:
                    sys.exit('%s: text outside a topic' % where)
                continue
            if line.startswith('@also '):
                cur.also += [a.replace('_', ' ') for a in line[6:].split()]
                continue
            cur.body.append((line, where))
    for t in topics:
        while t.body and not t.body[0][0]:
            t.body.pop(0)
        while t.body and not t.body[-1][0]:
            t.body.pop()
    return topics


LINKRE = re.compile(r'\{\{|\{([^{}|]+)(?:\|([^{}]+))?\}')


def visible(text):
    return LINKRE.sub(lambda m: '{' if m.group(0) == '{{' else m.group(1), text)


CATORDER = ['Help', 'Statements', 'Functions', 'Editor', 'Errors']


def natural(name):
    # Error 2 before Error 10
    return [int(p) if p.isdigit() else p.upper() for p in re.split(r'(\d+)', name)]


def make_index(topics):
    cats = [c for c in CATORDER if any(t.cat == c for t in topics)]
    for t in topics:
        if t.cat not in cats:
            cats.append(t.cat)
    t = Topic('Index', 'Index', '', 'mkhelp')
    for c in cats:
        names = sorted((x.name for x in topics if x.cat == c), key=natural)
        if not names:
            continue
        t.body.append((c or 'Other', 'mkhelp'))
        w = max(len(n) for n in names) + 2
        per = max(1, WIDTH // w)
        for i in range(0, len(names), per):
            row = names[i:i + per]
            t.body.append((''.join('{%s}%s' % (n, ' ' * (w - len(n))) for n in row).rstrip(), 'mkhelp'))
        t.body.append(('', 'mkhelp'))
    if t.body and not t.body[-1][0]:
        t.body.pop()
    return t


def build(topics, nolinks=False):
    names = {}
    for t in topics:
        for n in [t.name] + t.also:
            if key(n) in names:
                sys.exit('%s: name %r already used at %s' % (t.where, n, names[key(n)].where))
            names[key(n)] = t
    # pages: first pass for sizes (links need the target offsets)
    errs = []

    def encode(t, offs):
        out = bytearray(t.title.encode('latin1') + b'\r')
        for line, where in t.body:
            if len(visible(line)) > WIDTH:
                errs.append('%s: line longer than %d' % (where, WIDTH))
            pos = 0
            for m in LINKRE.finditer(line):
                out += line[pos:m.start()].encode('latin1')
                pos = m.end()
                if m.group(0) == '{{':
                    out += b'{'
                    continue
                text, target = m.group(1), (m.group(2) or m.group(1))
                tt = names.get(key(target))
                if tt is None:
                    if not nolinks:
                        errs.append('%s: no topic %r' % (where, target))
                    off, ln = 0, 0
                else:
                    off, ln = offs.get(id(tt), (0, 0))
                out += bytes([LINK]) + off.to_bytes(3, 'big') + ln.to_bytes(2, 'big')
                out += text.encode('latin1') + bytes([LEND])
            out += line[pos:].encode('latin1') + b'\r'
        return bytes(out)

    table = bytearray()
    for n in sorted(names):
        enc = n.encode('latin1')
        table += enc[:-1] + bytes([enc[-1] | 0x80]) + bytes(5)
    head = 9 + len(table)
    offs, pages, pos = {}, [], head
    for t in topics:
        p = encode(t, {})
        offs[id(t)] = (pos, len(p))
        pos += len(p)
    errs.clear()
    for t in topics:
        p = encode(t, offs)
        assert len(p) == offs[id(t)][1]
        if len(p) > HPMAX:
            errs.append('%s: page %s is %d bytes, more than %d' % (t.where, t.name, len(p), HPMAX))
        pages.append(p)
    if errs:
        sys.exit('\n'.join(errs))
    table = bytearray()
    for n in sorted(names):
        enc = n.encode('latin1')
        off, ln = offs[id(names[n])]
        table += enc[:-1] + bytes([enc[-1] | 0x80]) + off.to_bytes(3, 'big') + ln.to_bytes(2, 'big')
    if len(table) > NTMAX:
        sys.exit('the name table is %d bytes, more than %d' % (len(table), NTMAX))
    out = b'B9HL' + bytes([1]) + len(names).to_bytes(2, 'big') + len(table).to_bytes(2, 'big') + table
    return out + b''.join(pages), names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-o', default=os.path.join(TOP, 'build', 'basic09-l2.hlp'))
    ap.add_argument('--keytab', default=os.path.join(TOP, 'src', 'comand.asm'))
    ap.add_argument('--errmsg')
    ap.add_argument('--nocheck', action='store_true', help='skip the coverage checks')
    ap.add_argument('--nolinks', action='store_true', help='allow links to topics not given')
    ap.add_argument('src', nargs='*')
    a = ap.parse_args()
    src = a.src or [os.path.join(TOP, 'help')]
    files = []
    for s in src:
        files += sorted(glob.glob(os.path.join(s, '*.txt'))) if os.path.isdir(s) else [s]
    topics = parse(files)
    topics.append(make_index(topics))
    data, names = build(topics, a.nolinks)
    if not a.nocheck:
        missing = [w for w in keytab_words(a.keytab) if w not in names]
        if a.errmsg:
            missing += ['Error %d' % n for n in errmsg_numbers(a.errmsg) if 'ERROR %d' % n not in names]
        if 'HELP' not in names:
            missing.append('Help')
        if missing:
            sys.exit('no page for: ' + ', '.join(missing))
    open(a.o, 'wb').write(data)
    print('%s: %d topics, %d names, %d bytes' % (a.o, len(topics), len(names), len(data)))


if __name__ == '__main__':
    main()
