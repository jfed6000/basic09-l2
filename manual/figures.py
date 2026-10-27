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
