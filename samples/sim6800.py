#!/usr/bin/env python3
"""
sim6800.py - a small Motorola MC6800 simulator with a serial console, for
running the ACPX sample programs.

  python sim6800.py PROG.S19            run interactively on your terminal
  python sim6800.py PROG.S19 -i "text"  run with scripted input (\\r \\n \\xHH ok)
  python sim6800.py PROG.BIN -b E000    load a raw binary at the given address

Hardware model (all sample programs assume exactly this):
  $8008  ACIA status (read) / control (write)   MC6850 style
           bit0 RDRF  receive data ready      bit1 TDRE  transmit empty (always 1)
  $8009  ACIA data   (read = receive, write = transmit)
  RAM $0000-$DFFF, ROM $E000-$FFFF (writes ignored); reset vector at $FFFE.
Console input is delivered one key at a time; ENTER is sent as CR ($0D).
Ctrl-C (interactive) quits.  In scripted mode the run ends when the program
asks for a key and the script is exhausted, when it executes WAI/illegal
opcode, or after --max instructions.
"""
import sys, argparse

ACIAS, ACIAD = 0x8008, 0x8009


class Halt(Exception):
    pass


class NeedInput(Exception):
    pass


class CPU:
    def __init__(self, console_in, console_out):
        self.m = bytearray(65536)
        self.a = self.b = 0
        self.x = self.sp = self.pc = 0
        self.h = self.i = self.n = self.z = self.v = self.c = 0
        self.cin, self.cout = console_in, console_out
        self.steps = 0
        self.polls = 0
        self.rnd = 0

    # ---- memory / console ----
    def rd(self, ad):
        ad &= 0xFFFF
        if ad == ACIAS:
            return (1 if self.cin.ready() else 0) | 2
        if ad == ACIAD:
            return self.cin.get() & 0xFF
        return self.m[ad]

    def wr(self, ad, v):
        ad &= 0xFFFF
        v &= 0xFF
        if ad == ACIAD:
            self.cin.empty = 0 if hasattr(self.cin, 'empty') else 0
            self.cout(v)
        elif ad == ACIAS:
            pass
        elif ad < 0xE000:           # $E000-$FFFF is ROM: writes are ignored
            self.m[ad] = v

    def fetch(self):
        v = self.m[self.pc]
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetch16(self):
        h = self.fetch()
        return (h << 8) | self.fetch()

    def rd16(self, ad):
        return (self.rd(ad) << 8) | self.rd(ad + 1)

    def wr16(self, ad, v):
        self.wr(ad, v >> 8)
        self.wr(ad + 1, v)

    def push(self, v):
        self.wr(self.sp, v)
        self.sp = (self.sp - 1) & 0xFFFF

    def pull(self):
        self.sp = (self.sp + 1) & 0xFFFF
        return self.rd(self.sp)

    # ---- condition codes ----
    def getcc(self):
        return (0xC0 | self.h << 5 | self.i << 4 | self.n << 3 |
                self.z << 2 | self.v << 1 | self.c)

    def setcc(self, v):
        self.h = v >> 5 & 1
        self.i = v >> 4 & 1
        self.n = v >> 3 & 1
        self.z = v >> 2 & 1
        self.v = v >> 1 & 1
        self.c = v & 1

    def nz8(self, r):
        self.n = r >> 7 & 1
        self.z = 1 if (r & 0xFF) == 0 else 0

    def nz16(self, r):
        self.n = r >> 15 & 1
        self.z = 1 if (r & 0xFFFF) == 0 else 0

    # ---- ALU ----
    def add(self, a, b, cin=0):
        r = a + b + cin
        self.h = ((a & 15) + (b & 15) + cin) >> 4 & 1
        self.c = r >> 8 & 1
        self.v = 1 if (~(a ^ b) & (a ^ r) & 0x80) else 0
        r &= 0xFF
        self.nz8(r)
        return r

    def sub(self, a, b, cin=0):
        r = a - b - cin
        self.c = 1 if r < 0 else 0
        self.v = 1 if ((a ^ b) & (a ^ r) & 0x80) else 0
        r &= 0xFF
        self.nz8(r)
        return r

    def logic(self, r):
        r &= 0xFF
        self.nz8(r)
        self.v = 0
        return r

    # read-modify-write unary ops; returns new value
    def unary(self, op, v):
        if op == 0x0:                      # NEG
            r = (-v) & 0xFF
            self.nz8(r); self.v = 1 if v == 0x80 else 0; self.c = 1 if r != 0 else 0
        elif op == 0x3:                    # COM
            r = ~v & 0xFF
            self.nz8(r); self.v = 0; self.c = 1
        elif op == 0x4:                    # LSR
            self.c = v & 1; r = v >> 1
            self.n = 0; self.z = 1 if r == 0 else 0; self.v = self.n ^ self.c
        elif op == 0x6:                    # ROR
            c = self.c; self.c = v & 1; r = (c << 7) | (v >> 1)
            self.nz8(r); self.v = self.n ^ self.c
        elif op == 0x7:                    # ASR
            self.c = v & 1; r = (v & 0x80) | (v >> 1)
            self.nz8(r); self.v = self.n ^ self.c
        elif op == 0x8:                    # ASL
            self.c = v >> 7 & 1; r = (v << 1) & 0xFF
            self.nz8(r); self.v = self.n ^ self.c
        elif op == 0x9:                    # ROL
            c = self.c; self.c = v >> 7 & 1; r = ((v << 1) | c) & 0xFF
            self.nz8(r); self.v = self.n ^ self.c
        elif op == 0xA:                    # DEC
            r = (v - 1) & 0xFF
            self.nz8(r); self.v = 1 if v == 0x80 else 0
        elif op == 0xC:                    # INC
            r = (v + 1) & 0xFF
            self.nz8(r); self.v = 1 if v == 0x7F else 0
        elif op == 0xD:                    # TST
            r = v; self.nz8(r); self.v = 0; self.c = 0
        elif op == 0xF:                    # CLR
            r = 0; self.n = 0; self.z = 1; self.v = 0; self.c = 0
        else:
            raise Halt("illegal opcode")
        return r

    def cond(self, op):
        c, z, n, v = self.c, self.z, self.n, self.v
        t = {0x0: 1, 0x2: not (c or z), 0x3: c or z, 0x4: not c, 0x5: c,
             0x6: not z, 0x7: z, 0x8: not v, 0x9: v, 0xA: not n, 0xB: n,
             0xC: not (n ^ v), 0xD: n ^ v, 0xE: not (z or (n ^ v)),
             0xF: z or (n ^ v)}
        return bool(t[op])

    # ---- one instruction ----
    def step(self):
        self.steps += 1
        op = self.fetch()
        hi, lo = op >> 4, op & 15

        if hi == 0:
            if op == 0x01: pass
            elif op == 0x06: self.setcc(self.a)
            elif op == 0x07: self.a = self.getcc()
            elif op == 0x08: self.x = (self.x + 1) & 0xFFFF; self.z = 1 if self.x == 0 else 0
            elif op == 0x09: self.x = (self.x - 1) & 0xFFFF; self.z = 1 if self.x == 0 else 0
            elif op == 0x0A: self.v = 0
            elif op == 0x0B: self.v = 1
            elif op == 0x0C: self.c = 0
            elif op == 0x0D: self.c = 1
            elif op == 0x0E: self.i = 0
            elif op == 0x0F: self.i = 1
            else: raise Halt("illegal opcode %02X at %04X" % (op, self.pc - 1))
            return
        if hi == 1:
            if op == 0x10: self.a = self.sub(self.a, self.b)
            elif op == 0x11: self.sub(self.a, self.b)
            elif op == 0x16: self.b = self.a; self.nz8(self.b); self.v = 0
            elif op == 0x17: self.a = self.b; self.nz8(self.a); self.v = 0
            elif op == 0x19: self.daa()
            elif op == 0x1B: self.a = self.add(self.a, self.b)
            else: raise Halt("illegal opcode %02X at %04X" % (op, self.pc - 1))
            return
        if hi == 2:                        # branches
            off = self.fetch()
            if off & 0x80: off -= 256
            if op == 0x21: raise Halt("illegal opcode 21")
            if self.cond(lo):
                self.pc = (self.pc + off) & 0xFFFF
            return
        if hi == 3:
            if op == 0x30: self.x = (self.sp + 1) & 0xFFFF
            elif op == 0x31: self.sp = (self.sp + 1) & 0xFFFF
            elif op == 0x32: self.a = self.pull()
            elif op == 0x33: self.b = self.pull()
            elif op == 0x34: self.sp = (self.sp - 1) & 0xFFFF
            elif op == 0x35: self.sp = (self.x - 1) & 0xFFFF
            elif op == 0x36: self.push(self.a)
            elif op == 0x37: self.push(self.b)
            elif op == 0x39:
                h = self.pull(); l = self.pull(); self.pc = (h << 8) | l
            elif op == 0x3B:
                self.setcc(self.pull()); self.b = self.pull(); self.a = self.pull()
                xh = self.pull(); xl = self.pull(); self.x = (xh << 8) | xl
                h = self.pull(); l = self.pull(); self.pc = (h << 8) | l
            elif op == 0x3E: raise Halt("WAI")
            elif op == 0x3F: raise Halt("SWI")
            else: raise Halt("illegal opcode %02X at %04X" % (op, self.pc - 1))
            return
        if hi in (4, 5):                   # accumulator unary
            if lo in (1, 2, 5, 0xB, 0xE):
                raise Halt("illegal opcode %02X at %04X" % (op, self.pc - 1))
            if hi == 4: self.a = self.unary(lo, self.a)
            else: self.b = self.unary(lo, self.b)
            return
        if hi in (6, 7):                   # memory unary
            ea = (self.fetch() + self.x) & 0xFFFF if hi == 6 else self.fetch16()
            if lo == 0xE:                  # JMP
                self.pc = ea; return
            if lo in (1, 2, 5, 0xB):
                raise Halt("illegal opcode %02X at %04X" % (op, self.pc - 2))
            self.wr(ea, self.unary(lo, self.rd(ea)))
            return

        # 8x-Fx: A group (hi 8-B) and B group (hi C-F)
        grp = 0 if hi < 12 else 1
        mode = hi & 3                      # 0 imm, 1 dir, 2 idx, 3 ext
        if op == 0x8D:                     # BSR
            off = self.fetch()
            if off & 0x80: off -= 256
            self.push(self.pc & 0xFF); self.push(self.pc >> 8)
            self.pc = (self.pc + off) & 0xFFFF
            return
        wide = (grp == 0 and lo in (0xC, 0xE, 0xF)) or (grp == 1 and lo in (0xE, 0xF))
        if mode == 0:
            ea = None
            val = self.fetch16() if wide else self.fetch()
        else:
            if mode == 1: ea = self.fetch()
            elif mode == 2: ea = (self.fetch() + self.x) & 0xFFFF
            else: ea = self.fetch16()
            val = None
        if lo == 0xD and grp == 0:         # JSR
            if mode < 2: raise Halt("illegal opcode")
            self.push(self.pc & 0xFF); self.push(self.pc >> 8)
            self.pc = ea
            return
        reg = 'a' if grp == 0 else 'b'
        R = self.a if grp == 0 else self.b
        # stores / 16-bit
        if lo == 7:                        # STA
            if mode == 0: raise Halt("illegal opcode")
            self.wr(ea, R); self.nz8(R); self.v = 0
            return
        if wide:
            if lo == 0xC:                  # CPX
                m = val if mode == 0 else self.rd16(ea)
                r = (self.x - m) & 0xFFFF
                self.n = r >> 15 & 1; self.z = 1 if r == 0 else 0
                self.v = 1 if ((self.x ^ m) & (self.x ^ r) & 0x8000) else 0
                return
            if lo == 0xE and grp == 0:     # LDS
                m = val if mode == 0 else self.rd16(ea)
                self.sp = m; self.nz16(m); self.v = 0; return
            if lo == 0xE and grp == 1:     # LDX
                m = val if mode == 0 else self.rd16(ea)
                self.x = m; self.nz16(m); self.v = 0; return
            if lo == 0xF:                  # STS / STX
                if mode == 0: raise Halt("illegal opcode")
                r = self.sp if grp == 0 else self.x
                self.wr16(ea, r); self.nz16(r); self.v = 0; return
            raise Halt("illegal opcode")
        m = val if mode == 0 else self.rd(ea)
        if lo == 0x0: r = self.sub(R, m)
        elif lo == 0x1: self.sub(R, m); return
        elif lo == 0x2: r = self.sub(R, m, self.c)
        elif lo == 0x4: r = self.logic(R & m)
        elif lo == 0x5: self.logic(R & m); return
        elif lo == 0x6: r = self.logic(m)
        elif lo == 0x8: r = self.logic(R ^ m)
        elif lo == 0x9: r = self.add(R, m, self.c)
        elif lo == 0xA: r = self.logic(R | m)
        elif lo == 0xB: r = self.add(R, m)
        else: raise Halt("illegal opcode %02X at %04X" % (op, self.pc - 1))
        if grp == 0: self.a = r
        else: self.b = r

    def daa(self):
        a = self.a
        lsn = a & 15
        msn = a >> 4
        add = 0
        if self.h or lsn > 9: add |= 0x06
        if self.c or msn > 9 or (msn > 8 and lsn > 9): add |= 0x60
        r = a + add
        if r > 0xFF: self.c = 1
        self.a = r & 0xFF
        self.nz8(self.a)

    def reset(self):
        self.pc = self.rd16(0xFFFE)
        self.sp = 0x01FF
        self.i = 1


class ScriptIn:
    def __init__(self, text):
        self.buf = list(text.encode('latin-1'))
        self.empty = 0              # consecutive empty status polls

    def ready(self):
        if self.buf:
            return True
        self.empty += 1
        if self.empty > 200:        # the program is spinning, waiting for a key
            raise NeedInput()
        return False

    def get(self):
        self.empty = 0
        return self.buf.pop(0)


class TermIn:
    """Raw keyboard input (Unix termios or Windows msvcrt)."""
    def __init__(self):
        self.q = []
        try:
            import msvcrt
            self.ms = msvcrt
            self.old = None
        except ImportError:
            import termios, tty, select
            self.ms = None
            self.fd = sys.stdin.fileno()
            self.old = termios.tcgetattr(self.fd)
            tty.setraw(self.fd)
            self.select = select

    def close(self):
        if self.old is not None:
            import termios
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.old)

    def poll(self):
        if self.q:
            return
        if self.ms:
            if self.ms.kbhit():
                ch = self.ms.getwch()
                self.q.append(ord(ch) & 0xFF)
        else:
            r, _, _ = self.select.select([sys.stdin], [], [], 0)
            if r:
                self.q.append(ord(sys.stdin.read(1)) & 0xFF)

    def ready(self):
        self.poll()
        return bool(self.q)

    def get(self):
        self.poll()
        ch = self.q.pop(0) if self.q else 0
        if ch == 3:
            raise Halt("Ctrl-C")
        return ch


def load_s19(cpu, path):
    start = None
    for ln in open(path):
        ln = ln.strip()
        if ln.startswith('S1'):
            n = int(ln[2:4], 16)
            ad = int(ln[4:8], 16)
            data = bytes.fromhex(ln[8:8 + (n - 3) * 2])
            cpu.m[ad:ad + len(data)] = data
        elif ln.startswith('S9'):
            start = int(ln[4:8], 16)
    return start


def unescape(s):
    return (s.replace('\\r', '\r').replace('\\n', '\n').replace('\\t', '\t')
             .replace('\\e', '\x1b').replace('\\\\', '\\'))


def run_script(image, text, max_steps=5000000, base=None):
    """Run IMAGE (.S19 or .BIN) with scripted console input TEXT.
    Returns (output_text, cpu, reason).  Used by the test runner."""
    out = []
    cpu = CPU(ScriptIn(text), out.append)
    if image.lower().endswith('.bin'):
        data = open(image, 'rb').read()
        cpu.m[base:base + len(data)] = data
    else:
        load_s19(cpu, image)
    cpu.reset()
    try:
        while cpu.steps < max_steps:
            cpu.step()
        why = 'instruction limit'
    except NeedInput:
        why = 'waiting for input'
    except Halt as e:
        why = str(e)
    text = bytes(out).decode('latin-1').replace('\r\n', '\n').replace('\r', '\n')
    return text, cpu, why


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('image')
    ap.add_argument('-i', '--input', help='scripted console input')
    ap.add_argument('-b', '--base', help='load address (hex) for a raw .BIN')
    ap.add_argument('--max', type=int, default=5000000)
    ap.add_argument('--vector', action='store_true',
                    help='start at reset vector even if S9 present')
    ap.add_argument('--quiet', action='store_true')
    a = ap.parse_args()

    out = []
    scripted = a.input is not None
    if scripted:
        cin = ScriptIn(unescape(a.input))
        def cout(v):
            out.append(v)
    else:
        cin = TermIn()
        def cout(v):
            if v == 0x0A: sys.stdout.write('\n')
            elif v == 0x0D: sys.stdout.write('\r')
            else: sys.stdout.write(chr(v))
            sys.stdout.flush()
    cpu = CPU(cin, cout)
    if a.image.lower().endswith('.bin'):
        base = int(a.base or '0', 16)
        data = open(a.image, 'rb').read()
        cpu.m[base:base + len(data)] = data
    else:
        load_s19(cpu, a.image)
    cpu.reset()
    why = ''
    try:
        while cpu.steps < a.max:
            cpu.step()
        why = 'instruction limit'
    except NeedInput:
        why = 'waiting for input'
    except Halt as e:
        why = str(e)
    except KeyboardInterrupt:
        why = 'interrupted'
    finally:
        if not scripted:
            cin.close()
    if scripted:
        text = bytes(out).decode('latin-1')
        sys.stdout.write(text.replace('\r\n', '\n').replace('\r', '\n'))
        if not a.quiet:
            sys.stdout.write('\n[sim: %s after %d instructions]\n' % (why, cpu.steps))
    else:
        sys.stdout.write('\r\n[sim: %s]\r\n' % why)


if __name__ == '__main__':
    main()
