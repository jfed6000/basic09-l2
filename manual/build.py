#!/usr/bin/env python3
"""Build a basic09-l2 book as a PDF (manual/README.md).

usage: manual/build.py [--book user] [--out build/manual]

A book is a directory under manual/ (manual/user/ is the User's Manual):
book.txt holds its title lines, and its *.txt files, in name order, the
text.  The markup:

  # <n> <title>          a chapter: a group in the contents and the outline
  ## <n> <title>         a section, on a new page
  ### <title>            a heading inside a section
  > <title>              a callout box; the lines after it that start with
  > <text>               "> " are its text
  | a | b | c            a table; the first row is the header; a row whose
                         cells end in "~" carries on the cell above
  - <text>               a bullet
  ```                    a code block, to the next ```
  @figure <name>         a drawing from figures.py
  @image <file> <mm> [<caption>]   an image (relative to the repository)
  @images <mm> <file> <file> ... [| <caption>]   images side by side
  @pagebreak

Inline: **bold**, *italic*, `code`.  Paragraphs are separated by blank
lines; lines in between are joined.  Section numbers and pages fill the
contents table on a second pass.
"""
import argparse
import datetime
import os
import re
import sys

from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, Flowable, Frame, Image,
                                KeepTogether, NextPageTemplate, PageBreak,
                                PageTemplate, Paragraph, Preformatted, Spacer,
                                Table, TableStyle)

TOP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.join(TOP, 'manual')
sys.path.insert(0, HERE)
import figures  # noqa: E402

# The deck's colours ("Terminal amber"), close to the GPU manual's.
NAVY = HexColor('#13202B')
TEAL = HexColor('#1A6878')
AMBER = HexColor('#F2A33A')
INK = HexColor('#16222D')
SOFT = HexColor('#4A5866')
RULE = HexColor('#D3DCE2')
TINT = HexColor('#EDF2F5')
CODEBG = HexColor('#F3F5F7')
PALE = HexColor('#A9BBC8')

PAGE_W, PAGE_H = A4
MARGIN = 20 * mm
BODY_W = PAGE_W - 2 * MARGIN


def fonts():
    d = os.path.join(HERE, 'fonts')
    for name, f in [('Sans', 'IBMPlexSans-Regular'), ('Sans-It', 'IBMPlexSans-Italic'),
                    ('Sans-Semi', 'IBMPlexSans-SemiBold'), ('Sans-Bold', 'IBMPlexSans-Bold'),
                    ('Mono', 'JetBrainsMono-Regular'), ('Mono-Bold', 'JetBrainsMono-Bold')]:
        pdfmetrics.registerFont(TTFont(name, os.path.join(d, f + '.ttf')))
    pdfmetrics.registerFontFamily('Sans', normal='Sans', bold='Sans-Bold',
                                  italic='Sans-It', boldItalic='Sans-Bold')


def styles():
    s = {}
    s['body'] = ParagraphStyle('body', fontName='Sans', fontSize=9, leading=13.2,
                               textColor=INK, spaceAfter=6, alignment=TA_LEFT)
    s['bullet'] = ParagraphStyle('bullet', parent=s['body'], leftIndent=12,
                                 bulletIndent=2, spaceAfter=3)
    s['label'] = ParagraphStyle('label', fontName='Sans-Bold', fontSize=7.5, leading=10,
                                textColor=TEAL, spaceAfter=2)
    s['title'] = ParagraphStyle('title', fontName='Sans-Bold', fontSize=16, leading=20,
                                textColor=INK, spaceAfter=10)
    s['h3'] = ParagraphStyle('h3', fontName='Sans-Bold', fontSize=10, leading=13,
                             textColor=TEAL, spaceBefore=6, spaceAfter=4)
    s['intro'] = ParagraphStyle('intro', parent=s['body'], fontSize=8, leading=11,
                                textColor=SOFT)
    s['cell'] = ParagraphStyle('cell', fontName='Sans', fontSize=7.8, leading=10.4,
                               textColor=INK)
    s['head'] = ParagraphStyle('head', parent=s['cell'], fontName='Sans-Bold',
                               textColor=white)
    s['ctitle'] = ParagraphStyle('ctitle', fontName='Sans-Bold', fontSize=8.5,
                                 leading=11, textColor=TEAL, spaceAfter=2)
    s['cbody'] = ParagraphStyle('cbody', parent=s['body'], fontSize=8.2, leading=11.6,
                                spaceAfter=3)
    s['code'] = ParagraphStyle('code', fontName='Mono', fontSize=7.6, leading=10.4,
                               textColor=INK)
    s['caption'] = ParagraphStyle('caption', fontName='Sans', fontSize=7, leading=9,
                                  textColor=SOFT, spaceBefore=3, spaceAfter=8)
    return s


def inline(t):
    t = t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    t = re.sub(r'`([^`]+)`', r'<font name="Mono" color="#1A6878">\1</font>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'(?<![\w*])\*([^*]+)\*(?![\w*])', r'<i>\1</i>', t)
    # Plex Sans has no ▸ (menu paths: Run ▸ Run to cursor)
    t = t.replace('\u25b8', '<font name="Mono">\u25b8</font>')
    return t


class Anchor(Flowable):
    """A section's start: records its page, a link target and an outline entry."""

    def __init__(self, book, key, num, title, level):
        super().__init__()
        self.book, self.key, self.num, self.title, self.level = book, key, num, title, level
        self.width = self.height = 0

    def draw(self):
        c = self.canv
        self.book.pages[self.key] = c.getPageNumber()
        c.bookmarkPage(self.key)
        text = f'{self.num}  {self.title}' if self.num else self.title
        c.addOutlineEntry(text, self.key, level=self.level, closed=self.level == 0)


class Callout(Flowable):
    """A tinted box with a teal rule on the left, as in the GPU manual."""

    def __init__(self, title, paras, st):
        super().__init__()
        self.items = []
        if title:
            self.items.append(Paragraph(inline(title), st['ctitle']))
        self.items += [Paragraph(inline(p), st['cbody']) for p in paras]

    def wrap(self, aw, ah):
        self.w = aw
        self.sizes = [f.wrap(aw - 22, ah) for f in self.items]
        self.h = sum(h for _, h in self.sizes) + 3 * (len(self.items) - 1) + 16
        return aw, self.h

    def draw(self):
        c = self.canv
        c.setFillColor(TINT)
        c.rect(0, 0, self.w, self.h, stroke=0, fill=1)
        c.setFillColor(TEAL)
        c.rect(0, 0, 2.4, self.h, stroke=0, fill=1)
        y = self.h - 8
        for f, (_, h) in zip(self.items, self.sizes):
            y -= h
            f.drawOn(c, 14, y)
            y -= 3


class CodeBlock(Flowable):
    def __init__(self, text, st):
        super().__init__()
        self.pre = Preformatted(text, st['code'])

    def wrap(self, aw, ah):
        self.w = aw
        _, h = self.pre.wrap(aw - 20, ah)
        self.h = h + 12
        return aw, self.h

    def draw(self):
        c = self.canv
        c.setFillColor(CODEBG)
        c.rect(0, 0, self.w, self.h, stroke=0, fill=1)
        self.pre.drawOn(c, 10, 6)


def table(rows, st, widths=None):
    ncol = max(len(r) for r in rows)
    rows = [r + [''] * (ncol - len(r)) for r in rows]
    data = [[Paragraph(inline(c), st['head']) for c in rows[0]]]
    data += [[Paragraph(inline(c), st['cell']) for c in r] for r in rows[1:]]
    if widths is None:
        # Width by the longest text in each column, within limits.
        lens = [max(len(r[i]) for r in rows) for i in range(ncol)]
        lens = [min(max(n, 8), 70) for n in lens]
        widths = [BODY_W * n / sum(lens) for n in lens]
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 6), ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 4.5), ('BOTTOMPADDING', (0, 0), (-1, -1), 4.5),
        ('LINEBELOW', (0, 1), (-1, -1), 0.5, RULE),
    ]))
    return t


class Book:
    def __init__(self, bookdir):
        self.dir = bookdir
        self.meta = {}
        for line in open(os.path.join(bookdir, 'book.txt')):
            if ':' in line and not line.startswith('#'):
                k, v = line.split(':', 1)
                self.meta[k.strip()] = v.strip()
        self.pages = {}
        self.entries = []      # (key, num, title, is_chapter)
        self.st = styles()

    # -- the text --------------------------------------------------------

    def parse(self):
        files = sorted(f for f in os.listdir(self.dir)
                       if f.endswith('.txt') and f != 'book.txt')
        lines = []
        for f in files:
            lines += open(os.path.join(self.dir, f)).read().split('\n') + ['']
        out, para, i = [], [], 0
        st = self.st

        def flush():
            if para:
                out.append(Paragraph(inline(' '.join(para)), st['body']))
                para.clear()

        nsec = 0
        in_chapter = False
        while i < len(lines):
            ln = lines[i]
            s = ln.strip()
            if s.startswith('%'):                 # a comment
                i += 1
                continue
            if not s:
                flush()
            elif s.startswith('### '):
                flush()
                out.append(Paragraph(inline(s[4:]), st['h3']))
            elif s.startswith('## '):
                flush()
                num, title = s[3:].split(' ', 1)
                key = f's{nsec}'
                nsec += 1
                self.entries.append((key, num, title, False))
                if nsec > 1:
                    out.append(PageBreak())
                out.append(Anchor(self, key, num if num != '-' else '', title,
                                  1 if in_chapter else 0))
                out.append(Paragraph(num if num != '-' else title.upper(), st['label']))
                out.append(Paragraph(inline(title), st['title']))
            elif s.startswith('# '):
                flush()
                num, title = s[2:].split(' ', 1)
                key = f'c{num}'
                self.entries.append((key, num, title, True))
                in_chapter = True
                out.append(Anchor(self, key, num, title, 0))
            elif s.startswith('>'):
                flush()
                title = s[1:].strip()
                body, cur = [], []
                i += 1
                while i < len(lines) and lines[i].startswith('>'):
                    t = lines[i][1:].strip()
                    if t:
                        cur.append(t)
                    elif cur:
                        body.append(' '.join(cur))
                        cur = []
                    i += 1
                if cur:
                    body.append(' '.join(cur))
                out.append(Spacer(1, 4))
                out.append(Callout(title, body, st))
                out.append(Spacer(1, 8))
                continue
            elif s.startswith('|'):
                flush()
                rows = []
                widths = None
                while i < len(lines) and lines[i].strip().startswith('|'):
                    cells = [c.strip() for c in lines[i].strip().strip('|').split('|')]
                    if cells and cells[0].startswith('@widths'):
                        widths = [float(w) * mm for w in cells[0].split()[1:]]
                    elif rows and cells[0] == '~':
                        rows[-1] = [a + (' ' + b if b else '') for a, b in
                                    zip(rows[-1], cells[1:] + [''] * len(rows[-1]))]
                    else:
                        rows.append(cells)
                    i += 1
                out.append(Spacer(1, 2))
                out.append(table(rows, st, widths))
                out.append(Spacer(1, 8))
                continue
            elif s.startswith('- '):
                flush()
                item = [s[2:]]
                i += 1
                while i < len(lines) and lines[i].startswith('  ') and lines[i].strip():
                    item.append(lines[i].strip())
                    i += 1
                out.append(Paragraph(inline(' '.join(item)), st['bullet'],
                                     bulletText='•'))
                continue
            elif s.startswith('```'):
                flush()
                code = []
                i += 1
                while i < len(lines) and not lines[i].strip().startswith('```'):
                    code.append(lines[i])
                    i += 1
                out.append(Spacer(1, 2))
                out.append(CodeBlock('\n'.join(code), st))
                out.append(Spacer(1, 8))
            elif s.startswith('@figure '):
                flush()
                args = s.split()[1:]
                out.append(KeepTogether(getattr(figures, args[0].replace('-', '_'))(
                    BODY_W, st, TOP, *args[1:])))
            elif s.startswith('@image '):
                flush()
                parts = s.split(None, 3)
                out += image(os.path.join(TOP, parts[1]), float(parts[2]) * mm,
                             parts[3] if len(parts) > 3 else '', st)
            elif s.startswith('@images '):
                flush()
                head, _, cap = s.partition('|')
                parts = head.split()
                out += images([os.path.join(TOP, f) for f in parts[2:]],
                              float(parts[1]) * mm, cap.strip(), st)
            elif s == '@pagebreak':
                flush()
                out.append(PageBreak())
            elif s == '@intro':
                pass
            else:
                para.append(s)
            i += 1
        flush()
        return out

    # -- contents --------------------------------------------------------

    def contents(self):
        st = self.st
        out = [Anchor(self, 'contents', '', 'Contents', 0),
               Paragraph('CONTENTS', st['label']),
               Paragraph('Contents', st['title']),
               Paragraph('Each entry gives its section number and page. The PDF outline '
                         'and the entries are also clickable.', st['intro']),
               Spacer(1, 6)]
        rows = [[Paragraph('Section', st['head']), Paragraph('Subject', st['head']),
                 Paragraph('Page', st['head'])]]
        chapters = []
        for key, num, title, chap in self.entries:
            page = str(self.pages.get(key, ''))
            link = f'<a href="#{key}" color="#16222D">{inline(title)}</a>'
            if chap:
                chapters.append(len(rows))
                rows.append([Paragraph(f'<b>{num}</b>', st['cell']),
                             Paragraph(f'<b>{link}</b>', st['cell']), ''])
            else:
                rows.append([Paragraph(num if num != '-' else '', st['cell']),
                             Paragraph(link, st['cell']), Paragraph(page, st['cell'])])
        t = Table(rows, colWidths=[22 * mm, BODY_W - 40 * mm, 18 * mm], repeatRows=1)
        style = [('BACKGROUND', (0, 0), (-1, 0), NAVY),
                 ('LINEBELOW', (0, 1), (-1, -1), 0.5, RULE),
                 ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                 ('LEFTPADDING', (0, 0), (-1, -1), 6)]
        for r in chapters:
            style.append(('BACKGROUND', (0, r), (-1, r), TINT))
        t.setStyle(TableStyle(style))
        out.append(t)
        out.append(PageBreak())
        return out

    # -- pages -----------------------------------------------------------

    def cover(self, c, doc):
        m = self.meta
        c.saveState()
        c.setFillColor(NAVY)
        c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
        x = 24 * mm
        y = PAGE_H - 34 * mm
        c.setFillColor(TEAL)
        c.rect(x, y + 10 * mm, 14 * mm, 1.6, stroke=0, fill=1)
        c.setFont('Sans-Bold', 9)
        c.setFillColor(HexColor('#5FB4C4'))
        c.drawString(x, y, m['kicker'])
        c.setFillColor(white)
        c.setFont('Sans-Bold', 30)
        yy = y - 18 * mm
        for line in m['title'].split(' / '):
            c.drawString(x, yy, line)
            yy -= 12 * mm
        c.setFont('Sans', 11)
        c.setFillColor(PALE)
        yy -= 1 * mm
        for line in m['subtitle'].split(' / '):
            c.drawString(x, yy, line)
            yy -= 6 * mm
        shot = os.path.join(TOP, m.get('cover-image', ''))
        iw = PAGE_W - 2 * x
        ih = iw * 3 / 4
        iy = 66 * mm
        if os.path.isfile(shot):
            c.drawImage(shot, x, iy, iw, ih)
        else:
            c.setFillColor(HexColor('#1E3140'))
            c.rect(x, iy, iw, ih, stroke=0, fill=1)
        c.setStrokeColor(TEAL)
        c.setLineWidth(1)
        c.rect(x, iy, iw, ih, stroke=1, fill=0)
        c.setFont('Sans', 6.5)
        c.setFillColor(PALE)
        c.drawString(x, iy - 6 * mm, m.get('cover-caption', '').upper())
        c.setStrokeColor(HexColor('#2A3D4D'))
        c.line(x, 46 * mm, PAGE_W - x, 46 * mm)
        c.setFillColor(white)
        c.setFont('Sans-Bold', 12)
        c.drawString(x, 37 * mm, f"Revision {m['revision']}")
        c.setFont('Sans', 9)
        c.drawString(x, 31 * mm, self.date)
        c.setFont('Sans', 7)
        c.setFillColor(PALE)
        yy = 20 * mm
        for line in m.get('cover-notes', '').split(' / '):
            c.drawString(x, yy, line)
            yy -= 4.5 * mm
        c.restoreState()

    def body(self, c, doc):
        m = self.meta
        c.saveState()
        top = PAGE_H - 12 * mm
        c.setFillColor(TEAL)
        c.rect(MARGIN, top + 1, 9 * mm, 1.4, stroke=0, fill=1)
        c.setFont('Sans-Bold', 6.5)
        c.setFillColor(INK)
        c.drawString(MARGIN + 12 * mm, top, m['header'])
        c.setFont('Sans', 6.5)
        c.setFillColor(SOFT)
        c.drawRightString(PAGE_W - MARGIN, top, f"REV {m['revision']}")
        c.setStrokeColor(RULE)
        c.setLineWidth(0.5)
        c.line(MARGIN, 15 * mm, PAGE_W - MARGIN, 15 * mm)
        c.setFont('Sans', 6.5)
        c.drawString(MARGIN, 11 * mm, f"{self.date}  |  Revision {m['revision']}")
        c.drawCentredString(PAGE_W / 2, 11 * mm, m['footer'])
        c.setFont('Sans-Bold', 7)
        c.setFillColor(INK)
        c.drawRightString(PAGE_W - MARGIN, 11 * mm, str(c.getPageNumber()))
        c.restoreState()

    def build(self, out):
        d = self.meta.get('date')
        day = datetime.date.fromisoformat(d) if d else datetime.date.today()
        self.date = f'{day:%B} {day.day}, {day.year}'
        for _ in range(2):          # the second pass has the page numbers
            self.entries = []       # flowables cannot be built twice: parse again
            text = self.parse()
            doc = BaseDocTemplate(out, pagesize=A4, title=self.meta['pdf-title'],
                                  author=self.meta.get('author', ''),
                                  subject=self.meta.get('subject', ''))
            frame = Frame(MARGIN, 20 * mm, BODY_W, PAGE_H - 46 * mm, id='f',
                          leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
            doc.addPageTemplates([
                PageTemplate('cover', [Frame(0, 0, PAGE_W, PAGE_H)], onPage=self.cover),
                PageTemplate('body', [frame], onPage=self.body)])
            story = [NextPageTemplate('body'), Spacer(1, 1), PageBreak()] + self.contents() + text
            doc.build(story)
        return out


def picture(path, width):
    if os.path.isfile(path):
        from PIL import Image as PI
        w, h = PI.open(path).size
        return Image(path, width, width * h / w)
    return figures.missing(width, width * 3 / 4, os.path.relpath(path, TOP))


def image(path, width, caption, st):
    out = [picture(path, width)]
    if caption:
        out.append(Paragraph(inline(caption), st['caption']))
    return [KeepTogether(out)]


def images(paths, width, caption, st):
    """Images side by side, each width wide, with one caption."""
    cells = [picture(p, width) for p in paths]
    t = Table([cells], colWidths=[BODY_W / len(paths)] * len(paths))
    t.setStyle(TableStyle([('LEFTPADDING', (0, 0), (-1, -1), 0),
                           ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                           ('ALIGN', (0, 0), (-1, -1), 'LEFT')]))
    out = [t]
    if caption:
        out.append(Paragraph(inline(caption), st['caption']))
    return [KeepTogether(out)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--book', default='user')
    ap.add_argument('--out', default=os.path.join(TOP, 'build', 'manual'))
    a = ap.parse_args()
    fonts()
    book = Book(os.path.join(HERE, a.book))
    os.makedirs(a.out, exist_ok=True)
    out = os.path.join(a.out, book.meta['file'])
    book.build(out)
    print(out)


if __name__ == '__main__':
    main()
