#!/usr/bin/env python3
"""Profile l2b09run in MAME: count every read from its code, by routine.

  b09prof.py lua <counts file>  > <testdir>/lua
      Write a MAME autoboot script for a test directory (tools/emu-wildbits.sh).
      Once l2b09run's module header shows up in the upper slots, a read tap on
      its code counts each byte the CPU reads there; the counts are written to
      <counts file> (on the host) when MAME stops.  Reads are close to time.
  b09prof.py report <counts file> [<n>]
      Rebuild l2b09run into a scratch directory for its listings (the image
      must match build/l2b09run), then print the share of reads per module
      and for the <n> busiest labels (default 25).
  b09prof.py calls <counts file> <label>...
      Reads of each label's first byte: how often its first instruction ran.

Used for the compiler speed-ups (docs/OVERVIEW.html, "Compiler speed-ups").
"""
import bisect
import collections
import os
import re
import subprocess
import sys
import tempfile

TOP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RUN = os.path.join(TOP, 'build', 'l2b09run')
MODS = ['comand', 'compil', 'binder', 'stmts', 'exprsn', 'cnvio']

LUA = '''local hdr = {%(hdr)s}
local sp = manager.machine.devices[":maincpu"].spaces["program"]
local size, tap, counts = %(size)d, nil, {}
local function match(a)
  for i = 1, #hdr do if sp:read_u8(a + i - 1) ~= hdr[i] then return false end end
  return true
end
b09prof_sub = emu.add_machine_frame_notifier(function()
  if tap then return end
  for a = 0x6000, 0xFF00, 0x100 do  -- code is in the upper slots
    if match(a) then
      tap = sp:install_read_tap(a, a + size - 1, "b09prof", function(off, data, mask)
        local k = off - a
        counts[k] = (counts[k] or 0) + 1
        return data
      end)
      print(string.format("b09prof: l2b09run at %%04X", a))
      return
    end
  end
end)
b09prof_stop = emu.add_machine_stop_notifier(function()
  local f = io.open("%(out)s", "w")
  for k, v in pairs(counts) do f:write(k, " ", v, "\\n") end
  f:close()
end)
'''


def labels():
    """(address in l2b09run, module:label) for every code label."""
    nitros9 = os.environ.get('NITROS9DIR', os.path.join(TOP, 'build', 'main', 'src', 'nitros9'))
    tmp = tempfile.mkdtemp(prefix='b09prof')
    out = os.path.join(tmp, 'l2b09run')
    subprocess.run([sys.executable, os.path.join(TOP, 'src', 'build-modular-basic09.py'), 'basic09', out,
                    '-DCOMMUNITY=1', '-DL2B09=1', '-DLevel=2'], check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, env=dict(os.environ, NITROS9DIR=os.path.abspath(nitros9)))
    if open(out, 'rb').read() != open(RUN, 'rb').read():
        sys.exit('the rebuilt l2b09run differs from build/l2b09run: run make first')
    build = os.path.join(tmp, '.modular-build', 'basic09')
    syms, start = [], 0
    for m in MODS:
        size = os.path.getsize(os.path.join(build, m))
        for line in open(os.path.join(build, m + '.list'), errors='replace'):
            mm = re.match(r'^([0-9A-F]{4}) [0-9A-F]*\s*\(\s*([^)]*)\):\d+ (.*)$', line)
            if not mm or mm.group(2).strip().endswith('.d'):
                continue
            src = mm.group(3)
            src = src[8:] if src.startswith(' ' * 8) else src
            if src and not src[0].isspace() and not src.startswith('*'):
                a = int(mm.group(1), 16)
                if a < size:
                    syms.append((start + a, '%s:%s' % (m, src.split()[0])))
        start += size
    return sorted(syms)


def counts(path):
    return {int(k): int(v) for k, v in (l.split() for l in open(path))}


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == 'lua':
        img = open(RUN, 'rb').read()
        print(LUA % {'hdr': ','.join(str(b) for b in img[:8]), 'size': len(img),
                     'out': os.path.abspath(a[1])}, end='')
    elif len(a) in (2, 3) and a[0] == 'report':
        syms, c = labels(), counts(a[1])
        addrs = [s for s, _ in syms]
        by, mods, tot = collections.Counter(), collections.Counter(), sum(c.values())
        for k, v in c.items():
            i = bisect.bisect_right(addrs, k) - 1
            name = syms[i][1] if i >= 0 else '?'
            by[name] += v
            mods[name.split(':')[0]] += v
        print('total reads %d' % tot)
        for m, v in mods.most_common():
            print('  %-8s %5.1f%%' % (m, 100 * v / tot))
        for n, v in by.most_common(int(a[2]) if len(a) > 2 else 25):
            print('%5.1f%%  %s' % (100 * v / tot, n))
    elif len(a) >= 3 and a[0] == 'calls':
        syms, c = labels(), counts(a[1])
        where = {n.split(':', 1)[1]: s for s, n in syms}
        for n in a[2:]:
            print('%-10s %d' % (n, c.get(where[n], 0)) if n in where else '%-10s no such label' % n)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
