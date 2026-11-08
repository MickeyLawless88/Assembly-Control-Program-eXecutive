# ACPX 6800 sample programs

Five interactive programs and a set of small demonstrations that show what
ACPX accepts and expects. Everything assembles with **0 errors** (except
`D12ERRS`, which fails on purpose) and is checked by `runtests.py`.

## Quick start

    gcc -o ../acpx ../src/acpx.c
    python3 runtests.py --acpx ../acpx --plx ../ACP.PLX    # assemble everything and check it
    python3 sim6800.py GUESS.S19     # play a program (type in the terminal; Ctrl-] quits)
    python3 sim6800.py D08STACK.S19 -i ""   # run a self-checking demo, scripted input

To assemble by hand: start ACPX, choose **2**, give the file name (for example
`GUESS.ASM`), answer `Y` to listing/object questions, `0` for no padding.
The outputs are `GUESS.LST`, `GUESS.S19`, `GUESS.BIN`.

## The test machine

| Item | Value |
|---|---|
| CPU | MC6800 |
| Console | MC6850 ACIA: status `$8008` (bit 0 RDRF, bit 1 TDRE), data `$8009` |
| RAM | `$0000-$DFFF`, zero page for variables, `BUF` at `$0200`, stack top `$01FF` |
| ROM | `$E000-$FFFF`, code at `ORG $E000`, reset vector at `$FFFE` |

On real hardware change only the two `ACIAS`/`ACIAD` equates at the top of each file.
Each sample carries its own copy of the small console kernel (PUTC, GETC, GETLINE,
PRSTR, PRDEC, PRHEX, RAND ...) because ACPX has no `INCLUDE`.

## Interactive programs

| File | What it is | Shows |
|---|---|---|
| `GUESS.ASM` | number guessing game, 7 tries | line input, decimal parsing, 16-bit compare, PRNG seeded by keypress timing |
| `CALC.ASM` | 16-bit calculator `N+N N-N N*N N/N N%N` | shift/add multiply, restoring divide, decimal output, JMP trampolines |
| `HEXMON.ASM` | memory monitor: dump, examine, fill, go | hex parsing/printing, indexed addressing, `JSR 0,X` |
| `TICTAC.ASM` | tic-tac-toe against the computer | tables, board in RAM, simple search |
| `HANGMAN.ASM` | word game | string tables, pointer tables, RAND |

## Demonstrations

| File | Principle |
|---|---|
| `D01MODES` | the six addressing modes and their encodings |
| `D02EXPR` | expressions: `$hex %bin 'c decimal NAME *`, `+`/`-` only, left to right, 16-bit |
| `D03DATA` | FCB, FDB, FCC, RMB, escapes |
| `D04BRNCH` | branch encodings, the -128..+127 limit, long-branch trampoline |
| `D05LABEL` | labels: column 1, colon, case, 15 characters, label-only lines |
| `D06COMMT` | comments: `*`, `;`, trailing text, `;` on data lines |
| `D07ORG` | ORG, gaps, first ORG = S9 start and BIN base |
| `D08STACK` | stack, JSR/RTS/BSR, PSHA/PULA, TSX (self-checking) |
| `D09ARITH` | 8/16-bit arithmetic, multiply, BCD with DAA (self-checking) |
| `D10TABLE` | byte, pointer and jump tables (self-checking) |
| `D11FLAGS` | condition codes; CPX leaves carry alone (self-checking) |
| `D12ERRS` | every error message ACPX can print (fails on purpose) |
| `D13ROM` | a full 2K ROM `$F800-$FFFF` with vectors |
| `D14DIRCT` | automatic direct (zero-page) vs extended addressing |
| `D15LIMIT` | long data lines and other limits |

Machine-checkable lines in the file headers: `EXPECT addr: bytes`, `EXPECT-S9`,
`EXPECT-BIN base size`, `EXPECT-ERR line text`, `EXPECT-OK n`, `EXPECT-OUT text`.

## Disciplines ACPX expects

1. **Labels in column 1, instructions indented.** A mnemonic in column 1 is a label.
2. **Labels are at most 15 characters** and global (no duplicates). A label-only line takes nothing after it.
3. **File names are 8.3**; output files are named from the first 8 characters.
4. **Define zero-page names with EQU before use** to get 2-byte direct addressing.
5. **Expressions are `+`/`-` only**, no parentheses, no high/low operators; use data tables or `FDB`.
6. **No operand spaces:** write `#$20`, not `#' '`.
7. **8-bit immediates are 0-255:** `#$FF`, never `#-1`.
8. **Branches reach -128..+127**; use `JMP` trampolines beyond that.
9. **On FCB/FDB/FCC lines the rest of the line is data**: begin comments with `;`.
10. **`END` operand is ignored**; the entry is the first `ORG`, so put the lowest ORG first.
11. 6800 facts: `CPX` leaves carry alone (use BEQ/BNE), no `ABX`, `TSX` gives SP+1, `JSR n,X` jumps to X+n.
