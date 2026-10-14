"""A model of basic09-l2's editing commands, for generating test expectations.

The model works on a plain string with '\\r' line ends and a cursor index.
Each command mirrors the editor's rules (docs/EDITOR.md).  A Session runs
commands on the model and collects the matching key script, so a test's
key script and its expected file come from one list of operations.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from keys import compile_keys  # noqa: E402

CR = '\r'


def isword(ch):
    return ch.isalnum() or ch == '_'


class Model:
    def __init__(self, text):
        self.t = text
        self.c = 0
        self.want = 0
        self.sel = None        # anchor index while a selection is active
        self.clip = None       # clipboard text (None = never copied)
        self.indent = True
        self.fcase = False     # searches match case
        self.fstr = ''
        self.rstr = ''
        self.recs = []         # undo records: [off, len, deletion, out, text]
        self.ucur = 0          # records applied

    # ---- undo records (same grouping rules as undo.asm)
    NUNDO = 50

    def _last(self):
        if self.recs and self.ucur == len(self.recs):
            return self.recs[-1]
        return None

    def _new(self, rec):
        del self.recs[self.ucur:]
        if len(self.recs) == self.NUNDO:
            self.recs.pop(0)
        self.recs.append(rec)
        self.ucur = len(self.recs)

    def _rec_ins1(self, off):
        r = self._last()
        if r and not r[2] and not r[3] and r[0] + r[1] == off:
            r[1] += 1
        else:
            self._new([off, 1, False, False, ''])

    def _rec_del1(self, off, ch):
        r = self._last()
        if r and r[2] and r[3]:
            if r[0] == off:
                r[1] += 1
                r[4] += ch
                return
            if r[0] == off + 1:
                r[0] = off
                r[1] += 1
                r[4] = ch + r[4]
                return
        self._new([off, 1, True, True, ch])

    def _toggle(self, r):
        self.sel = None
        off, n = r[0], r[1]
        if not r[3]:
            r[4] = self.t[off:off + n]
            self.t = self.t[:off] + self.t[off + n:]
            self.c = off
            r[3] = True
        else:
            self.t = self.t[:off] + r[4] + self.t[off:]
            self.c = off + len(r[4])
            r[4] = ''
            r[3] = False

    def undo(self):
        if self.ucur:
            self.ucur -= 1
            self._toggle(self.recs[self.ucur])

    def redo(self):
        if self.ucur < len(self.recs):
            self._toggle(self.recs[self.ucur])
            self.ucur += 1

    # ---- helpers
    def bol(self, i=None):
        i = self.c if i is None else i
        return self.t.rfind(CR, 0, i) + 1

    def eol(self, i=None):
        i = self.c if i is None else i
        j = self.t.find(CR, i)
        return len(self.t) if j < 0 else j

    def col(self):
        return self.c - self.bol()

    def tocol(self, start, col):
        return min(start + col, self.eol(start))

    def _cut(self, a, b):
        """Delete a..b as one record (a selection)."""
        if b > a:
            self._new([a, b - a, True, True, self.t[a:b]])
        self.t = self.t[:a] + self.t[b:]

    def _del1(self, i):
        """Delete one character (Backspace, Delete, ^D)."""
        self._rec_del1(i, self.t[i])
        self.t = self.t[:i] + self.t[i + 1:]

    def seldel(self):
        """Delete the selection; True if there was one."""
        if self.sel is None:
            return False
        a, b = sorted((self.sel, self.c))
        self._cut(a, b)
        self.c = a
        self.sel = None
        return True

    def _ins(self, s):
        """Insert typed text, a character at a time."""
        for ch in s:
            self._rec_ins1(self.c)
            self.t = self.t[:self.c] + ch + self.t[self.c:]
            self.c += 1

    def _insblock(self, s):
        """Insert a block (paste) as one record."""
        if s:
            self._new([self.c, len(s), False, False, ''])
        self.t = self.t[:self.c] + s + self.t[self.c:]
        self.c += len(s)

    # ---- moves (return True when they keep the wanted column)
    def right(self):
        self.c = min(self.c + 1, len(self.t))

    def left(self):
        self.c = max(self.c - 1, 0)

    def up(self):
        b = self.bol()
        if b > 0:
            self.c = self.tocol(self.bol(b - 1), self.want)
        return True

    def down(self):
        e = self.eol()
        if e < len(self.t):
            self.c = self.tocol(e + 1, self.want)
        return True

    def home(self):
        self.c = self.bol()

    def end(self):
        self.c = self.eol()

    def top(self):
        self.c = 0

    def bottom(self):
        self.c = len(self.t)

    def wright(self):
        while self.c < len(self.t) and isword(self.t[self.c]):
            self.c += 1
        while self.c < len(self.t) and not isword(self.t[self.c]):
            self.c += 1

    def wleft(self):
        while self.c > 0 and not isword(self.t[self.c - 1]):
            self.c -= 1
        while self.c > 0 and isword(self.t[self.c - 1]):
            self.c -= 1

    def goto(self, n):
        line = min(max(n - 1, 0), self.t.count(CR))
        i = 0
        for _ in range(line):
            i = self.t.index(CR, i) + 1
        self.c = i

    # ---- edits
    def type(self, s):
        self.seldel()
        self._ins(s)

    def enter(self):
        self.seldel()
        b = self.bol()
        n = 0
        while self.indent and b + n < self.c and self.t[b + n] == ' ':
            n += 1
        self._ins(CR + ' ' * n)

    def bs(self):
        if self.seldel():
            return
        if self.c > 0:
            self.c -= 1
            self._del1(self.c)

    def delete(self):
        if self.seldel():
            return
        if self.c < len(self.t):
            self._del1(self.c)

    def delln(self):
        self.c = self.bol()
        while self.c < len(self.t):
            ch = self.t[self.c]
            self._del1(self.c)
            if ch == CR:
                break

    def copy(self):
        if self.sel is not None:
            a, b = sorted((self.sel, self.c))
            self.clip = self.t[a:b]

    def cut(self):
        if self.sel is not None:
            self.copy()
            self.seldel()

    def paste(self):
        if self.clip is not None:
            self.seldel()
            self._insblock(self.clip)

    def selall(self):
        self.sel = 0
        self.c = len(self.t)

    def find(self):
        """Find fstr from the cursor on; the match becomes the selection."""
        if not self.fstr:
            return False
        t, p = (self.t, self.fstr) if self.fcase else (self.t.upper(), self.fstr.upper())
        k = t.find(p, self.c)
        if k < 0:
            return False
        self.sel = k
        self.c = k + len(p)
        return True

    def findprev(self):
        """Find fstr before the cursor, or before the selection's start."""
        if not self.fstr:
            return False
        t, p = (self.t, self.fstr) if self.fcase else (self.t.upper(), self.fstr.upper())
        lim = self.c if self.sel is None else min(self.sel, self.c)
        k = t.rfind(p, 0, lim + len(p) - 1)
        if k < 0:
            return False
        self.sel = k
        self.c = k + len(p)
        return True

    def replace(self, answers):
        """Replace fstr with rstr from the cursor on; answers are 'y', 'n',
        'a' (all) or 'esc' for each match asked about."""
        answers = iter(answers)
        every = False
        while self.find():
            if not every:
                a = next(answers)
                if a == 'esc':
                    break
                if a == 'n':
                    continue
                if a == 'a':
                    every = True
            self.seldel()
            self._ins(self.rstr)


# key -> (model method, keeps the selection, extends it)
PLAIN_MOVES = {'right': 'right', 'left': 'left', 'up': 'up', 'down': 'down',
               'wright': 'wright', 'wleft': 'wleft', '^j': 'home', '^k': 'end',
               'top': 'top', 'bottom': 'bottom'}
SHIFT_MOVES = {'sright': 'right', 'sleft': 'left', 'sup': 'up', 'sdown': 'down',
               'swright': 'wright', 'swleft': 'wleft'}
EDITS = {'enter': 'enter', 'bs': 'bs', 'del': 'delete', '^d': 'delln',
         '^c': 'copy', '^x': 'cut', '^v': 'paste', '^a': 'selall',
         '^z': 'undo', '^y': 'redo'}


def q(s):
    """s as a quoted key-script string."""
    return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')


class Session:
    """Runs keys on a Model and records the key script."""

    def __init__(self, text):
        self.m = Model(text)
        self.keys = []

    def _after(self, vertical):
        if not vertical:
            self.m.want = self.m.col()

    def key(self, name, n=1):
        """A named key (see keys.py), n times."""
        m = self.m
        for _ in range(n):
            if name in PLAIN_MOVES:
                m.sel = None
                self._after(getattr(m, PLAIN_MOVES[name])())
            elif name in SHIFT_MOVES:
                if m.sel is None:
                    m.sel = m.c
                self._after(getattr(m, SHIFT_MOVES[name])())
            elif name in EDITS:
                if name == '^d':
                    m.sel = None
                getattr(m, EDITS[name])()
                self._after(False)
            elif name == 'esc':
                m.sel = None
                self._after(False)
            else:
                raise ValueError('model has no key ' + name)
        self.keys.append(name if n == 1 else '%s*%d' % (name, n))

    def type(self, s):
        self.m.type(s)
        self._after(False)
        self.keys.append(q(s))

    def goto(self, n):
        self.m.sel = None
        self.m.goto(n)
        self._after(False)
        self.keys.append('^g "%d" enter' % n)

    def find(self, text):
        """^F with new text (typing replaces the remembered text)."""
        self.m.fstr = text
        self.m.find()
        self._after(False)
        self.keys.append('^f %s enter' % q(text))

    def fnext(self):
        self.m.find()
        self._after(False)
        self.keys.append('^l')

    def fprev(self):
        self.m.findprev()
        self._after(False)
        self.keys.append('s^l')

    def replace(self, find, repl, answers):
        """Search > Replace; repl must not be empty (an empty answer
        keeps the remembered text)."""
        self.m.fstr, self.m.rstr = find, repl
        self.m.replace(answers)
        self._after(False)
        self.keys.append('alt-s "r" %s enter %s enter' % (q(find), q(repl)))
        self.keys.append(' '.join('esc' if a == 'esc' else '"%s"' % a for a in answers))

    def matchcase(self):
        """Options > Match case (toggles)."""
        self.m.fcase = not self.m.fcase
        self.keys.append('alt-o "m"')

    def raw(self, keys):
        """Keys the model does not need to follow (save, quit, menus)."""
        self.keys.append(keys)

    def keybytes(self):
        return compile_keys('\n'.join(self.keys))


def source(nlines):
    """A Basic09-like test file: some lines indented, varying lengths."""
    out = []
    for i in range(1, nlines + 1):
        indent = '  ' * (i % 4 == 0)
        pad = 'x' * (i * 7 % 29)
        out.append('%s%05d PRINT "line %d"; REM %s' % (indent, i, i, pad))
    return CR.join(out) + CR


def write(outdir, name, data):
    mode = 'wb' if isinstance(data, bytes) else 'w'
    kw = {} if isinstance(data, bytes) else {'newline': ''}
    with open(os.path.join(outdir, name), mode, **kw) as f:
        f.write(data)
