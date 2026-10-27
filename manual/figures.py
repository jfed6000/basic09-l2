"""Drawings for the manual (@figure <name> in the text).

Each figure is a function (width, styles, top, *args) that returns a list
of flowables: the drawing and its caption.
"""
import os

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib.colors import HexColor, white
from reportlab.platypus import Paragraph

NAVY = HexColor('#13202B')
TEAL = HexColor('#1A6878')
AMBER = HexColor('#F2A33A')
INK = HexColor('#16222D')
SOFT = HexColor('#4A5866')
TINT = HexColor('#EDF2F5')
PANEL = HexColor('#FBFAF6')
RULE = HexColor('#D3DCE2')


def missing(w, h, name):
    d = Drawing(w, h)
    d.add(Rect(0, 0, w, h, fillColor=TINT, strokeColor=RULE))
    d.add(String(w / 2, h / 2, f'{name}: run make shots', fontName='Sans', fontSize=8,
                 fillColor=SOFT, textAnchor='middle'))
    return d


def caption(text, st):
    return Paragraph(text, st['caption'])


def box(d, x, y, w, h, name, what, tag='own 64K', stroke=INK):
    d.add(Rect(x, y, w, h, rx=4, ry=4, fillColor=PANEL, strokeColor=stroke, strokeWidth=1))
    d.add(String(x + 8, y + h - 15, name, fontName='Mono-Bold', fontSize=9.5, fillColor=INK))
    d.add(String(x + 8, y + h - 28, what, fontName='Sans', fontSize=7.5, fillColor=SOFT))
    if tag:
        tw = len(tag) * 3.9 + 10
        d.add(Rect(x + 8, y + 7, tw, 11, rx=5.5, ry=5.5, fillColor=TEAL, strokeWidth=0))
        d.add(String(x + 13, y + 10, tag, fontName='Sans', fontSize=6.5, fillColor=white))


def arrow(d, x1, y1, x2, y2, both=False, color=TEAL):
    d.add(Line(x1, y1, x2, y2, strokeColor=color, strokeWidth=1.2))

    def head(xa, ya, xb, yb):
        import math
        a = math.atan2(yb - ya, xb - xa)
        p = [(xb, yb)]
        for s in (2.6, -2.6):
            p.append((xb - 6 * math.cos(a + s / 6), yb - 6 * math.sin(a + s / 6)))
        d.add(Polygon([v for q in p for v in q], fillColor=color, strokeWidth=0))
    head(x1, y1, x2, y2)
    if both:
        head(x2, y2, x1, y1)


def label(d, x, y, text, size=6.8, color=SOFT, anchor='middle', font='Sans'):
    d.add(String(x, y, text, fontName=font, fontSize=size, fillColor=color,
                 textAnchor=anchor))


def programs(width, st, top):
    """The programs of basic09-l2, each a process with its own 64K."""
    h = 190
    d = Drawing(width, h)
    bw, bh = 128, 52
    gap = (width - 3 * bw) / 2
    xs = [0, bw + gap, 2 * (bw + gap)]
    y1 = h - bh - 4
    box(d, xs[0], y1, bw, bh, 'basic09-l2', 'The editor', stroke=TEAL)
    box(d, xs[1], y1, bw, bh, 'l2b09run', 'Runtime and debugger')
    box(d, xs[2], y1, bw, bh, 'l2b09cc', 'The compiler')
    for i in (0, 1):
        ya = y1 + bh / 2
        arrow(d, xs[i] + bw + 3, ya, xs[i + 1] - 3, ya, both=True)
        label(d, xs[i] + bw + gap / 2, ya + 5, 'two pipes')
    y2 = 40
    box(d, xs[0], y2, bw, bh, 'l2b09help', 'The help browser')
    box(d, xs[1], y2, bw, bh, 'l2b09ovl', 'PACK, loaded when needed', tag='')
    d.add(Rect(xs[2], y2, bw, bh, rx=4, ry=4, fillColor=NAVY, strokeWidth=0))
    d.add(String(xs[2] + 8, y2 + bh - 15, 'Your program', fontName='Sans-Bold',
                 fontSize=9.5, fillColor=white))
    d.add(String(xs[2] + 8, y2 + bh - 28, 'in its own window (/vt)', fontName='Sans',
                 fontSize=7.5, fillColor=HexColor('#A9BBC8')))
    arrow(d, xs[0] + bw / 2, y1 - 3, xs[0] + bw / 2, y2 + bh + 3)
    label(d, xs[0] + bw / 2 + 6, (y1 + y2 + bh) / 2 - 2, 'F1', anchor='start',
          font='Sans-Bold', color=TEAL)
    arrow(d, xs[1] + bw / 2, y1 - 3, xs[1] + bw / 2, y2 + bh + 3)
    label(d, xs[1] + bw / 2 + 6, (y1 + y2 + bh) / 2 - 2, 'PACK', anchor='start',
          font='Sans-Bold', color=TEAL)
    arrow(d, xs[1] + bw - 10, y1 - 3, xs[2] + 20, y2 + bh + 3)
    label(d, (xs[1] + bw + xs[2]) / 2 + 22, (y1 + y2 + bh) / 2 - 2, 'runs',
          anchor='start', font='Sans-Bold', color=TEAL)
    label(d, 0, 8, 'Each box is a separate OS-9 process or module. The editor starts '
          'l2b09run on the first Make, and l2b09run starts l2b09cc.', anchor='start')
    return [d, caption('Figure 1.2: the programs of basic09-l2.', st)]


def screen(width, st, top, shot='build/shots/plain.png'):
    """The editor's screen, with its parts named."""
    path = os.path.join(top, shot)
    iw = width * 0.64
    ih = iw * 0.75
    d = Drawing(width, ih + 6)
    oy = 3
    rows = 30
    rh = ih / rows
    if os.path.isfile(path):
        from reportlab.graphics.shapes import Image as GImage
        d.add(GImage(0, oy, iw, ih, path))
    else:
        d.add(Rect(0, oy, iw, ih, fillColor=TINT, strokeColor=RULE))
        label(d, iw / 2, oy + ih / 2, f'{shot}: run make shots', size=8)
    d.add(Rect(0, oy, iw, ih, fillColor=None, strokeColor=INK, strokeWidth=0.6))
    lx = iw + 14

    def row_y(r):            # the middle of text row r (0 at the top)
        return oy + ih - (r + 0.5) * rh

    parts = [(0, iw * 0.5, 'Menu bar', 'Alt+letter, or click'),
             (1, iw * 0.55, 'Title', 'the file name'),
             (9, iw * 0.45, 'Text window', 'one whole .b09 file'),
             (5, iw - 2, 'Scroll bar', 'click or drag'),
             (28, iw * 0.07, 'Frame', 'line:column; * when changed'),
             (29, iw * 0.3, 'Hint line', 'keys, or a message')]
    ys = [row_y(0) + 2, row_y(1) - 14, row_y(9) - 8, row_y(15) - 10, row_y(26), row_y(29) - 6]
    for (r, x, name, what), ty in zip(parts, ys):
        y = row_y(r) if r != 5 else row_y(12)
        d.add(Line(x, y, lx - 3, ty + 3, strokeColor=AMBER, strokeWidth=0.9))
        d.add(Rect(x - 1.6, y - 1.6, 3.2, 3.2, fillColor=AMBER, strokeWidth=0))
        label(d, lx, ty + 1, name, size=8, color=INK, anchor='start', font='Sans-Bold')
        label(d, lx, ty - 8.5, what, size=7, anchor='start')
    return [d, caption('Figure 1.5: the editor with a program loaded (80×30 screen).', st)]


def make(width, st, top):
    """What one Make does: a sequence diagram of the three programs."""
    steps = [  # (from, to, text); from == to is a step inside one program
        (0, 0, 'writes the changed procedures to basic09-l2.tmp'),
        (0, 1, 'load basic09-l2.tmp'),
        (1, 2, 'load basic09-l2.tmp'),
        (2, 2, 'reads the file; compiles and binds each procedure'),
        (2, 1, 'the compiled procedures'),
        (2, 0, 'errors, as %CERR and %BERR lines'),
        (1, 0, '%READY'),
        (0, 0, 'messages; the cursor to the first error'),
    ]
    rowh = 21
    head = 34
    h = head + rowh * len(steps) + 12
    d = Drawing(width, h)
    xs = [width * 0.14, width * 0.5, width * 0.86]
    names = [('basic09-l2', 'the editor'), ('l2b09run', 'runtime'), ('l2b09cc', 'compiler')]
    bw = 100
    for x, (n, what) in zip(xs, names):
        d.add(Rect(x - bw / 2, h - 30, bw, 28, rx=4, ry=4, fillColor=PANEL,
                   strokeColor=TEAL if n == 'basic09-l2' else INK, strokeWidth=1))
        label(d, x, h - 15, n, size=8.5, color=INK, font='Mono-Bold')
        label(d, x, h - 25, what, size=6.5)
        d.add(Line(x, h - 31, x, 6, strokeColor=RULE, strokeWidth=1.2,
                   strokeDashArray=[3, 2]))
    for i, (a, b, text) in enumerate(steps):
        y = h - head - rowh * i - 12
        num = String(0, y - 1, str(i + 1), fontName='Sans-Bold', fontSize=7,
                     fillColor=AMBER)
        d.add(num)
        if a == b:
            d.add(Rect(xs[a] - 3, y - 4, 6, 12, fillColor=TEAL, strokeWidth=0))
            anchor = 'start' if a < 2 else 'end'
            tx = xs[a] + 8 if a < 2 else xs[a] - 8
            label(d, tx, y - 1, text, size=7, color=INK, anchor=anchor)
        else:
            arrow(d, xs[a], y + 2, xs[b] + (6 if b < a else -6), y + 2)
            label(d, (xs[a] + xs[b]) / 2, y + 6, text, size=7, color=INK,
                  font='Mono' if text.startswith(('load', '%')) else 'Sans')
    return [d, caption('Figure 3.1: one Make. With no errors, step 6 sends nothing, '
                       'and the hint line says how many procedures were loaded.', st)]


def fararray(width, st, top):
    """The program's 64K in 8K slots, and a FAR array's blocks mapped into the window."""
    h = 240
    d = Drawing(width, h)
    sw, sh = 130, 23
    x0, y0 = 40, 24
    slots = ['code and workspace'] * 7 + ['data window']
    labels = ['$0000', '$2000', '$4000', '$6000', '$8000', '$A000', '$C000', '$E000']
    for i in range(8):
        y = y0 + i * sh
        top_slot = i == 7
        d.add(Rect(x0, y, sw, sh, fillColor=AMBER if top_slot else PANEL,
                   strokeColor=INK, strokeWidth=0.8))
        label(d, x0 - 6, y + sh / 2 - 2.5, labels[i], size=6.5, anchor='end', font='Mono')
        if top_slot:
            label(d, x0 + sw / 2, y + sh / 2 - 3, 'data window', size=7.5, color=INK,
                  font='Sans-Bold')
    d.add(Rect(x0, y0, sw, sh * 7, fillColor=None, strokeColor=INK, strokeWidth=0.8))
    label(d, x0 + sw / 2, y0 + sh * 3.5 + 4, "the program's 64K:", size=7.5, color=INK,
          font='Sans-Bold')
    label(d, x0 + sw / 2, y0 + sh * 3.5 - 7, 'code, workspace, variables', size=7)
    label(d, x0 + sw / 2, h - 12, 'l2b09run: 64K, eight 8K slots', size=7.5, color=INK,
          font='Sans-Bold')
    # The machine's RAM: a grid of 8K blocks, three of them the array's.
    bs, gap, cols, rows = 16, 4, 8, 8
    gx = width - cols * (bs + gap)
    gy = y0
    label(d, gx + (cols * (bs + gap)) / 2, h - 12, 'the 2 MB of RAM, in 8K blocks',
          size=7.5, color=INK, font='Sans-Bold')
    far = [(2, 5), (3, 5), (4, 5)]
    for r in range(rows):
        for c in range(cols):
            x = gx + c * (bs + gap)
            y = gy + r * (bs + gap)
            isfar = (c, r) in far
            d.add(Rect(x, y, bs, bs, rx=2, ry=2, fillColor=TEAL if isfar else TINT,
                       strokeColor=TEAL if isfar else RULE, strokeWidth=0.6))
    for n, (c, r) in enumerate(far):
        label(d, gx + c * (bs + gap) + bs / 2, gy + r * (bs + gap) + 5, str(n), size=7,
              color=white, font='Sans-Bold')
    d.add(Rect(gx, gy - 14, 8, 8, rx=2, ry=2, fillColor=TEAL, strokeWidth=0))
    label(d, gx + 12, gy - 13, "big()'s blocks 0, 1 and 2; the rest are other "
          "programs' or free", size=6.8, anchor='start')
    # Block 1 mapped into the window.
    bx = gx + far[1][0] * (bs + gap) + bs / 2
    by = gy + far[1][1] * (bs + gap) + bs + 1
    wx, wy = x0 + sw + 3, y0 + 7 * sh + sh / 2
    arrow(d, bx, by, wx, wy, color=AMBER)
    mx = (wx + gx) / 2 - 6
    label(d, mx, wy + 20, 'big(2000) is in block 1:', size=7, color=INK, font='Sans-Bold')
    label(d, mx, wy + 10, 'mapped into the window', size=7)
    label(d, mx, wy + 1, 'on access', size=7)
    return [d, caption('Figure 6.2: a FAR array of 4,000 REALs (1,484 to a block) in three '
                       'blocks. Reading big(2000) maps block 1 into the data window.', st)]
