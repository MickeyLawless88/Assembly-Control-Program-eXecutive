#!/usr/bin/env python3
"""runtests.py - assemble every sample with acpx and check it.

Usage:  python3 runtests.py [--acpx PATH] [--plx PATH]
Checks, per file, whichever tags the header comments carry:
  * EXPECT addr: bytes   object bytes at addr (from the .S19)
  * EXPECT-S9 addr       S9 start address      EXPECT-BIN base size
  * EXPECT-ERR n TEXT    error message on line n   EXPECT-ERRCOUNT n
  * EXPECT-OK n / EXPECT-OUT text   self-checking demos run in sim6800
Interactive programs get a scripted console session in SESSIONS below.
"""
import os, re, subprocess, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6800 import run_script

HERE = os.path.dirname(os.path.abspath(__file__))
ACPX = os.environ.get('ACPX', os.path.join(HERE, '..', 'demo', 'acpx'))
PLX = os.environ.get('ACPXPLX', os.path.join(HERE, '..', 'demo', 'ACP.PLX'))
for i, a in enumerate(sys.argv):
    if a == '--acpx': ACPX = sys.argv[i + 1]
    if a == '--plx': PLX = sys.argv[i + 1]

SESSIONS = {   # name: (input script, [strings that must appear in output])
 'GUESS':   (' 50\r50\r', ['GUESS', '1 TO 100', 'HIGH']),
 'CALC':    ('12+30\r6*7\rA/2\r7%4\rq\r', ['= 42', '= 21', '= 3']),
 'HEXMON':  ('h\r', ['HEXMON', 'HELP']),
 'TICTAC':  (' 5\r', ['TIC-TAC-TOE']),
 'HANGMAN': (' ', ['HANGMAN']),
}
fails = 0
def report(name, ok, msg=''):
    global fails
    if not ok: fails += 1
    print('%-9s %s %s' % (name, 'PASS' if ok else 'FAIL', msg))

def assemble(name):
    s = '2\n%s.ASM\ny\ny\n0\n5\n' % name
    p = subprocess.run([ACPX, '-c', PLX], input='lsi01\n21121\n' + s,
                       capture_output=True, text=True, cwd=HERE)
    return p.stdout

def s19(name):
    mem, s9 = {}, None
    base = name[:8]
    for l in open(os.path.join(HERE, base + '.S19')):
        l = l.strip()
        if l.startswith('S1'):
            c = int(l[2:4], 16); a = int(l[4:8], 16)
            for i, b in enumerate(bytes.fromhex(l[8:8 + 2 * (c - 3)])): mem[a + i] = b
        elif l.startswith('S9'): s9 = int(l[4:8], 16)
    return mem, s9

for path in sorted(glob.glob(os.path.join(HERE, '[A-Z]*.ASM'))):
    name = os.path.basename(path)[:-4]
    src = open(path).read().splitlines()
    out = assemble(name)
    errs = re.findall(r'\*\*\* ERROR \(LINE (\d+)\): (.*)', out)
    cnt = re.findall(r'^ERROR COUNT = (\d+)', out, re.M)
    total = int(cnt[-1]) if cnt else -1
    probs = []
    want_err = [l for l in src if l.startswith('* EXPECT-ERR ')]
    if want_err:
        for l in want_err:
            if l.startswith('* EXPECT-ERRCOUNT'):
                if total != int(l.split()[2]): probs.append('errcount %d' % total)
                continue
            m = re.match(r'\* EXPECT-ERR (\d+) (.*)', l)
            if (m[1], m[2]) not in errs: probs.append('missing error line %s' % m[1])
    elif total != 0:
        probs.append('%d assembly errors' % total)
    if not want_err and not probs:
        mem, s9 = s19(name)
        for l in src:
            m = re.match(r'\* EXPECT ([0-9A-F]{4}): ([0-9A-F ]+)', l)
            if m:
                b = bytes.fromhex(m[2].replace(' ', '')); a = int(m[1], 16)
                got = bytes(mem.get(a + i, 0xEE) for i in range(len(b)))
                if got != b: probs.append('%04X: %s != %s' % (a, got.hex(' '), b.hex(' ')))
            m = re.match(r'\* EXPECT-S9 ([0-9A-F]{4})', l)
            if m and s9 != int(m[1], 16): probs.append('S9 %s' % s9)
            m = re.match(r'\* EXPECT-BIN ([0-9A-F]{4}) (\d+)', l)
            if m:
                sz = os.path.getsize(os.path.join(HERE, name[:8] + '.BIN'))
                if sz != int(m[2]): probs.append('BIN size %d' % sz)
        ok = [l for l in src if l.startswith('* EXPECT-OK')]
        if ok:
            text, cpu, why = run_script(os.path.join(HERE, name[:8] + '.S19'), '')
            n = int(ok[0].split()[2])
            if text.count('OK') != n or 'FAIL' in text:
                probs.append('run: %d OK expected, got %d' % (n, text.count('OK')))
            for l in src:
                m = re.match(r'\* EXPECT-OUT (.*)', l)
                if m and m[1].strip() not in text: probs.append('output lacks ' + m[1])
        if name in SESSIONS:
            inp, need = SESSIONS[name]
            text, cpu, why = run_script(os.path.join(HERE, name + '.S19'), inp)
            for w in need:
                if w not in text: probs.append('session lacks %r' % w)
    report(name, not probs, '; '.join(probs))
print('\n%s' % ('ALL PASSED' if not fails else '%d FAILED' % fails))
sys.exit(1 if fails else 0)
