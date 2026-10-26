#!/usr/bin/env python3
"""Build the basic09-l2 video from a shot list (video/README.md).

usage: video/build.py [--shotlist FILE] [--media DIR] [--out DIR] [--list]

Each shot becomes a segment, 1920x1080 at FPS with 48 kHz stereo AAC, all
encoded the same way so that they join without re-encoding.  Segments are
cached by their line and inputs, so a rebuild redoes only what changed.
The result is <out>/basic09-l2.mp4 (loudness evened out) and
<out>/chapters.txt, the YouTube chapters.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

W, H, FPS = 1920, 1080, 60
BARS = '0x13202B'             # the deck's dark slate, beside a 4:3 picture
SLIDE_TAIL = 0.75             # silence after a slide's narration, seconds
VERSION = '1'                 # bump to rebuild every segment

HERE = os.path.dirname(os.path.abspath(__file__))
TOP = os.path.dirname(HERE)

VENC = ['-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
        '-profile:v', 'high', '-pix_fmt', 'yuv420p',
        '-video_track_timescale', '90000']
AENC = ['-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2']


def die(msg):
    sys.exit('build.py: ' + msg)


def run(cmd):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       text=True)
    if r.returncode:
        sys.stderr.write(r.stderr[-3000:])
        die('failed: ' + ' '.join(cmd[:3]) + ' ...')
    return r.stdout


def probe(path):
    return json.loads(run(['ffprobe', '-v', 'error', '-print_format', 'json',
                           '-show_format', '-show_streams', path]))


def duration(path):
    return float(probe(path)['format']['duration'])


def seconds(s):
    """'83.5', '1:23.5', '0:01:23' or '5s' -> seconds."""
    s = s.rstrip('s')
    t = 0.0
    for part in s.split(':'):
        t = t * 60 + float(part)
    return t


def is_time(s):
    return re.fullmatch(r'[\d:.]+s?', s) is not None


class Shot:
    def __init__(self, lineno, kind, args, opts, chapter):
        self.lineno, self.kind, self.args, self.opts = lineno, kind, args, opts
        self.chapter = chapter       # a chapter title starting here, or None


def parse(path):
    shots, chapter = [], None
    with open(path) as f:
        for n, line in enumerate(f, 1):
            line = line.split('#', 1)[0].strip()
            if not line:
                continue
            word, _, rest = line.partition(' ')
            if word == 'chapter':
                if not rest.strip():
                    die(f'{path}:{n}: chapter needs a title')
                chapter = rest.strip()
                continue
            if word not in ('slide', 'clip'):
                die(f'{path}:{n}: unknown "{word}" (slide, clip or chapter)')
            args, opts = [], {}
            for w in rest.split():
                if '=' in w:
                    k, v = w.split('=', 1)
                    opts[k] = v
                else:
                    args.append(w)
            if not args:
                die(f'{path}:{n}: {word} needs a name')
            shots.append(Shot(n, word, args, opts, chapter))
            chapter = None
    return shots


class Builder:
    def __init__(self, a):
        self.media, self.out = a.media, a.out
        self.slides = os.path.join(self.out, 'slides')
        self.segs = os.path.join(self.out, 'segments')
        os.makedirs(self.slides, exist_ok=True)
        os.makedirs(self.segs, exist_ok=True)
        with open(os.path.join(HERE, 'slides.txt')) as f:
            self.order = [l.split('#', 1)[0].strip() for l in f]
        self.order = [s for s in self.order if s]
        self.pdf = os.path.join(self.media, 'slides.pdf')
        self.pages_done = False

    def mpath(self, name):
        p = os.path.join(self.media, name)
        if not os.path.exists(p):
            die(f'missing {p}')
        return p

    # ---- slides: pages of the deck's PDF export, or placeholders

    def slide_png(self, sid):
        if sid not in self.order:
            die(f'slide "{sid}" is not in video/slides.txt')
        png = os.path.join(self.slides, sid + '.png')
        if os.path.exists(self.pdf):
            self.pages()
        elif not os.path.exists(png):
            self.placeholder(sid, png)
        return png

    def pages(self):
        if self.pages_done:
            return
        self.pages_done = True
        stamp = os.path.join(self.slides, '.pdf-mtime')
        mt = str(os.path.getmtime(self.pdf))
        if os.path.exists(stamp) and open(stamp).read() == mt:
            return
        n = int(re.search(r'Pages:\s+(\d+)', run(['pdfinfo', self.pdf]))[1])
        if n != len(self.order):
            die(f'slides.pdf has {n} pages, video/slides.txt lists '
                f'{len(self.order)} slides')
        tmp = os.path.join(self.slides, 'page')
        run(['pdftoppm', '-png', '-scale-to-x', str(W), '-scale-to-y', str(H),
             self.pdf, tmp])
        width = len(str(n))
        for i, sid in enumerate(self.order, 1):
            src = f'{tmp}-{i:0{width}d}.png'
            os.replace(src, os.path.join(self.slides, sid + '.png'))
        open(stamp, 'w').write(mt)

    def placeholder(self, sid, png):
        from PIL import Image, ImageDraw, ImageFont
        im = Image.new('RGB', (W, H), '#13202B')
        d = ImageDraw.Draw(im)
        font = ImageFont.load_default(size=96)
        small = ImageFont.load_default(size=40)
        d.text((W // 2, H // 2 - 40), sid, fill='#F2A33A', font=font,
               anchor='mm')
        d.text((W // 2, H // 2 + 80), 'placeholder: put the deck\'s PDF '
               'export in video/media/slides.pdf', fill='#A9BBC8', font=small,
               anchor='mm')
        im.save(png)

    # ---- segments

    def key(self, shot, inputs):
        h = hashlib.sha1(VERSION.encode())
        h.update(repr((shot.kind, shot.args, sorted(shot.opts.items()),
                       W, H, FPS, BARS, SLIDE_TAIL)).encode())
        for p in inputs:
            h.update(f'{p}:{os.path.getmtime(p)}:{os.path.getsize(p)}'
                     .encode())
        return h.hexdigest()[:12]

    def segment(self, i, shot):
        if shot.kind == 'slide':
            return self.slide_seg(i, shot)
        return self.clip_seg(i, shot)

    def slide_seg(self, i, shot):
        sid, rest = shot.args[0], shot.args[1:]
        png = self.slide_png(sid)
        secs, audio = None, None
        for w in rest:
            if is_time(w):
                secs = seconds(w)
            else:
                audio = self.mpath(w)
        if secs is None and audio is None:
            die(f'line {shot.lineno}: slide {sid} needs a time or narration')
        dur = secs or 0
        if audio:
            dur = max(dur, duration(audio) + SLIDE_TAIL)
        seg = os.path.join(self.segs, f'{i:03d}-{sid}-'
                           f'{self.key(shot, [png] + ([audio] if audio else []))}.mp4')
        if os.path.exists(seg):
            return seg
        ain = ['-i', audio] if audio else \
            ['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo']
        run(['ffmpeg', '-y', '-v', 'error', '-loop', '1', '-framerate',
             str(FPS), '-i', png] + ain +
            ['-filter_complex',
             f'[0:v]scale={W}:{H},setsar=1,format=yuv420p[v];'
             '[1:a]aresample=48000,aformat=channel_layouts=stereo,apad[a]',
             '-map', '[v]', '-map', '[a]', '-t', f'{dur:.3f}', '-r', str(FPS)]
            + VENC + AENC + [seg + '.tmp.mp4'])
        os.replace(seg + '.tmp.mp4', seg)
        return seg

    def clip_seg(self, i, shot):
        name = shot.args[0]
        src = self.mpath(name)
        start = seconds(shot.args[1]) if len(shot.args) > 1 and shot.args[1] != '-' else 0.0
        end = seconds(shot.args[2]) if len(shot.args) > 2 and shot.args[2] != '-' else None
        info = probe(src)
        v = next((s for s in info['streams'] if s['codec_type'] == 'video'), None)
        if v is None:
            die(f'{src}: no video')
        has_audio = any(s['codec_type'] == 'audio' for s in info['streams'])
        total = float(info['format']['duration'])
        dur = (end if end is not None else total) - start
        if dur <= 0:
            die(f'line {shot.lineno}: {name}: nothing between {start} and {end}')

        audio = shot.opts.get('audio', 'keep')
        inputs = [src]
        if audio not in ('keep', 'mute'):
            audio = self.mpath(audio)
            inputs.append(audio)

        w, h = int(v['width']), int(v['height'])
        vf = []
        if 'crop' in shot.opts:                    # crop=W:H:X:Y
            vf.append('crop=' + shot.opts['crop'])
            w, h = (int(x) for x in shot.opts['crop'].split(':')[:2])
        f = min(W / w, H / h)
        if shot.opts.get('scale') == 'int' and f >= 1:
            f = int(f)
        sw, sh = round(w * f / 2) * 2, round(h * f / 2) * 2
        # hard pixel edges when blowing up a low-resolution screen
        flags = 'neighbor' if f >= 1.5 else 'lanczos'
        vf += [f'scale={sw}:{sh}:flags={flags}',
               f'pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color={BARS}',
               'setsar=1', f'fps={FPS}', 'format=yuv420p']

        seg = os.path.join(self.segs, f'{i:03d}-{os.path.splitext(os.path.basename(name))[0]}-'
                           f'{self.key(shot, inputs)}.mp4')
        if os.path.exists(seg):
            return seg
        cmd = ['ffmpeg', '-y', '-v', 'error', '-ss', f'{start:.3f}',
               '-t', f'{dur:.3f}', '-i', src]
        if audio == 'keep' and has_audio:
            achain = '[0:a]'
        elif audio in ('keep', 'mute'):
            cmd += ['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo']
            achain = '[1:a]'
        else:
            cmd += ['-i', audio]
            achain = '[1:a]'
        cmd += ['-filter_complex',
                f'[0:v]{",".join(vf)}[v];'
                f'{achain}aresample=48000,aformat=channel_layouts=stereo,'
                f'apad,atrim=0:{dur:.3f}[a]',
                '-map', '[v]', '-map', '[a]', '-t', f'{dur:.3f}'] + \
            VENC + AENC + [seg + '.tmp.mp4']
        run(cmd)
        os.replace(seg + '.tmp.mp4', seg)
        return seg

    # ---- the whole video

    def build(self, shots):
        segs, chapters, t = [], [], 0.0
        for i, shot in enumerate(shots, 1):
            seg = self.segment(i, shot)
            d = duration(seg)
            if shot.chapter:
                chapters.append((t, shot.chapter))
            print(f'{fmt(t):>8}  {d:6.1f}s  {shot.kind} {" ".join(shot.args)}')
            segs.append(seg)
            t += d
        lst = os.path.join(self.out, 'concat.txt')
        with open(lst, 'w') as f:
            for s in segs:
                f.write(f"file '{s}'\n")
        joined = os.path.join(self.out, 'joined.mp4')
        run(['ffmpeg', '-y', '-v', 'error', '-f', 'concat', '-safe', '0',
             '-i', lst, '-c', 'copy', joined])
        final = os.path.join(self.out, 'basic09-l2.mp4')
        run(['ffmpeg', '-y', '-v', 'error', '-i', joined, '-c:v', 'copy',
             '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11'] + AENC +
            ['-movflags', '+faststart', final])
        with open(os.path.join(self.out, 'chapters.txt'), 'w') as f:
            for ct, title in chapters:
                f.write(f'{fmt(ct)} {title}\n')
        print(f'{fmt(t):>8}  total')
        print(final)
        print(os.path.join(self.out, 'chapters.txt'))
        check_chapters(chapters, t)


def fmt(t):
    t = int(t)
    return f'{t // 3600}:{t % 3600 // 60:02d}:{t % 60:02d}' if t >= 3600 \
        else f'{t // 60}:{t % 60:02d}'


def check_chapters(chapters, total):
    """YouTube: the first at 0:00, at least three, each at least 10 s."""
    if not chapters:
        return
    if chapters[0][0] > 0:
        print('note: YouTube needs the first chapter at 0:00')
    if len(chapters) < 3:
        print('note: YouTube needs at least three chapters')
    ends = [c[0] for c in chapters[1:]] + [total]
    for (start, title), end in zip(chapters, ends):
        if end - start < 10:
            print(f'note: chapter "{title}" is under 10 s; YouTube ignores '
                  'chapters then')


def main():
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--shotlist', default=os.path.join(HERE, 'shotlist.txt'))
    p.add_argument('--media', default=os.path.join(HERE, 'media'))
    p.add_argument('--out', default=os.path.join(TOP, 'build', 'video'))
    p.add_argument('--list', action='store_true',
                   help='only check the shot list and print it')
    a = p.parse_args()
    shots = parse(a.shotlist)
    if a.list:
        for s in shots:
            if s.chapter:
                print(f'== {s.chapter}')
            print(f'   {s.kind} {" ".join(s.args)} '
                  + ' '.join(f'{k}={v}' for k, v in s.opts.items()))
        return
    Builder(a).build(shots)


if __name__ == '__main__':
    main()
