# ACPX

**An ADM-2 MICOS-style development system for the Motorola 6800: menu shell, line editor and two-pass assembler in portable C89, with a scriptable login and banner.**

*Written by Mickey W. Lawless.*

```
+--------------------------------------------------------------------------+
|                     ###    ####  ####       #                            |
|                    #   #  #      #   #     #    #   #                    |
|                    #####  #      ####     #      # #                     |
|                    #   #  #      #       #       # #                     |
|                    #   #   ####  #      #       #   #                    |
|                        ASSEMBLY  CONTROL  PROGRAM                        |
|           MICOS-STYLE DEVELOPMENT SYSTEM FOR THE MOTOROLA 6800           |
+--------------------------------------------------------------------------+
```

ACPX recreates the programming environment described in Section 5 of the
Lear Siegler ADM-2 microprogramming manual: a three-part system made of

| Part | Role |
|---|---|
| **ACP** | Assembly Control Program, the top-level menu shell |
| **ASSEDIT** | the line-numbered source file editor |
| **ASM** | the two-pass assembler, producing a listing, S-records and a binary image |

The ADM-2's own microcode instruction set has been replaced by standard
**Motorola 6800** assembly language. The shell, the editor, the dialogue wording,
the two-pass workflow, the listing layout, the label list, the cross-reference
and the error messages follow the original; only the target CPU differs.

The startup sequence (login, banner, menu header, sign-off, even the editor's
line-number format) is written in **PL/X**, a small scripting language
designed for this program. You can leave it alone, edit the supplied scripts,
or write your own. See [PLX.md](PLX.md).

---

## Contents

1. [Features](#1-features)
2. [Installing and building](#2-installing-and-building)
3. [Running ACPX](#3-running-acpx)
4. [A first session](#4-a-first-session)
5. [The ACP menu](#5-the-acp-menu)
6. [ASSEDIT, the source editor](#6-assedit-the-source-editor)
7. [The assembler](#7-the-assembler)
8. [Output files](#8-output-files)
9. [Error messages](#9-error-messages)
10. [Startup scripting with PL/X](#10-startup-scripting-with-plx)
11. [Limits](#11-limits)
12. [Platform notes](#12-platform-notes)
13. [Repository layout](#13-repository-layout)

---

## 1. Features

* Complete **MC6800** instruction set
  (`ABA` ... `WAI`, with `LSL`/`LSLA`/`LSLB` as synonyms of `ASL`), the five
  addressing modes (inherent, immediate, direct, indexed, extended) and relative branches.
* Directives `ORG` `EQU` `FCB`/`DB` `FDB`/`DW` `FCC` `RMB` `END`.
* Expressions with `$hex`, `%binary`, `'c` character and decimal terms, symbols,
  `*` (the location counter) and `+` / `-`.
* **Two-pass** assembly with forward references; automatic direct/extended
  selection.
* Formatted **listing** (address, object code, line number, source), **symbol table**
  and a sorted **cross-reference**, with an adjustable page width.
* **S-record** (S1/S9) and raw **binary** output, with optional padding to ROM
  size (`FF` fill).
* Line-oriented **editor**: create, append, edit (change, insert, delete,
  list, search), duplicate, shrink, merge.
* **PL/X scripting** of login, banner, menu header, sign-off and line-number
  format, with a companion configuration tool, `PLXCFG`.
* **One portable source:** strict ANSI C89, tested with GCC, Turbo C++ 1.00 (DOS),
  and MinGW-w64 (Windows 32/64-bit). No dependencies beyond the C library.

---

## 2. Installing and building

The program is two source files that go together: `acpx.c`, which includes
`plx.c`, and the configuration tool `plxcfg.c`, which also includes `plx.c`.
Keep `acpx.c`, `plx.c` and `plxcfg.c` in one directory.

| Platform | Commands |
|---|---|
| Linux / macOS | `cc -ansi -pedantic -O2 -o acpx acpx.c`<br>`cc -ansi -pedantic -O2 -o plxcfg plxcfg.c` |
| Windows (MinGW-w64) | `gcc -O2 -o acpx.exe acpx.c`<br>`gcc -O2 -o plxcfg.exe plxcfg.c` |
| Windows (MSVC) | `cl /nologo /O2 acpx.c`<br>`cl /nologo /O2 plxcfg.c` |
| DOS (Turbo C / C++) | `tcc -ml acpx.c`<br>`tcc -ml plxcfg.c` |

Under Turbo C use the **large** (`-ml`) or **compact** (`-mc`) model. The small and
medium models compile but do not run correctly.

Prebuilt binaries for DOS, 32-bit Windows and 64-bit Windows are in the release
package (`dos\`, `win32\`, `win64\`).

---

## 3. Running ACPX

```
acpx                 run, loading ACP.PLX from the current directory if present
acpx -c FILE.PLX     run with the startup script FILE.PLX
acpx FILE.PLX        same
acpx -n              ignore scripts; use the built-in banner
```

Source files, listings and object files are read and written in the **current
directory**, so start ACPX in the directory where your programs live.

With no script (or `-n`) ACPX prints the original hard-wired session banner.
If a script fails to load or run, the error is printed and ACPX falls back to the
same built-in banner, so a damaged script can never lock you out.

Version `1.5` is shown in the banner (`V1.5`).

---

## 4. A first session

The sample script `ACP.PLX` logs in as account `LSI01`, password `21121`. (Edit the
`VAR(DECLARATION)` block in the script to change them.)

```
ACCOUNT-ID: LSI01
PASSWORD: XXXXX  10/30/26
       GOOD DAY USER 4100  PORT 7
           WELCOME TO THE WONDERFUL WORLD OF 'MICOS'
*************************************************************
BELIEVE NOTHING YOU HEAR, AND ONLY ONE HALF THAT YOU SEE
*************************************************************
##
RUN'ACP'
(ADM-ACP / ASSEDIT, MOTOROLA 6800 ASM)  V1.5
=============================================================
ENTER "BYE" AT THE ACP PROMPT TO DISCONNECT.

'ACP' AT YOUR SERVICE - CHOOSE YOUR OPTION.
=============================================================
1    SOURCE FILE EDITOR.
2    ASSEMBLE PROGRAM.
3    SHOW THE ASSEMBLER OUTPUT FILE ON THE TERMINAL
4    SET LISTING WIDTH   (NOW 79)
5    END
...? 1
```

Create a source file:

```
'ASSEDIT' HERE -- WHAT DO YOU WANT TO DO?
C    CREATE A NEW SOURCE FILE.
A    APPEND TO AN EXISTING SOURCE FILE.
E    EDIT AN EXISTING SOURCE FILE.
D    DUPLICATE A SOURCE FILE.
S    SHRINK/EXPAND A SOURCE FILE
M    MERGE TWO FILES
(CR) EXIT FROM EDITOR.
? C
NAME THE NEW ADM SOURCE FILE
HELLO.ASM

HELLO.ASM READY FOR INPUT

00001   * HELLO - FIRST PROGRAM
00002           ORG   $E000
00003   START   LDAA  #1
00004           STAA  $0010
00005   LOOP    BRA   LOOP
00006           END   START
00007   //
HELLO.ASM SAVED
```

Type `//` on a line by itself to finish entering text. Press RETURN at the
`ASSEDIT` prompt to leave the editor, then choose option 2 to assemble:

```
...? 2
SOURCE FILE NAME ? HELLO.ASM

ASSEMBLY PASS 1
PASS 1 COMPLETE
LAST ADDRESS USED IS E006
ERROR COUNT = 0
PRINT LABEL LIST (Y) ? Y

CONTINUE WITH ASSEMBLY (Y) ? Y
```

and ACPX writes `HELLO.LST`, `HELLO.S19` and `HELLO.BIN` (section 8).
Enter `BYE` at the menu, or option 5, to sign off.

---

## 5. The ACP menu

| Option | Action |
|---|---|
| `1` | **Source file editor** (ASSEDIT, section 6) |
| `2` | **Assemble a program** (section 7) |
| `3` | **Show** the last assembler output (the `.LST` listing) on the terminal; asks for a file name if nothing has been assembled yet |
| `4` | **Set listing width**: `72` (teletype), `80` (CRT), `132` (printer) or `0` for unlimited; RETURN keeps the current value. The minimum accepted is a few dozen columns (the program says what), and the default is 79 |
| `5` | **End** the session (runs the `GOODBYE` hook of the script) |
| `BYE` | Same as 5, typed at the `...?` prompt (case-insensitive) |

Anything else prints `INVALID OPTION - ENTER 1, 2, 3, 4 OR 5`.

---

## 6. ASSEDIT, the source editor

Source files are plain text, one statement per line, saved with an ordinary
newline. The editor addresses lines by number, starting at **1**. Line
numbers are shown, not stored in the file.

**File names** are upper-cased and follow the 8.3 rule: 1 to 8 alphanumeric
characters starting with a letter, optionally followed by `.` and a 1 to 3 character
extension (`HELLO.ASM`, `SINE`, `C:\SRC\PONG.ASM`).

### 6.1 ASSEDIT commands

| Command | Meaning |
|---|---|
| `C` | **Create** a new source file and enter lines from 1 |
| `A` | **Append** to an existing file: new lines go after the last one |
| `E` | **Edit** an existing file (section 6.2) |
| `D` | **Duplicate** a file under a new name (asks `NEW FILE NAME` then `OLD FILE NAME`) |
| `S` | **Shrink/expand**: rewrite the file compactly and report its record count |
| `M` | **Merge**: copy lines `L1,L2` of one file into another after line `L` |
| RETURN | Exit the editor, back to the ACP menu |

### 6.2 Edit mode

`E` asks for a file, reports `n RECORDS ON FILE NAME`, and shows the edit menu:

```
           READY FOR EDITING
A    APPEND TO FILE
C    CHANGE LINE
D    DELETE LINE
I    INSERT LINE BEFORE
L    DISPLAY LINE(S)
S    SEARCH FOR STRING BETWEEN LINES
T    DISPLAY FILE
X    EXIT FROM EDITOR
```

| Command | Dialogue |
|---|---|
| `A` | Append lines after the last line (end with `//`) |
| `C` | `# LINE-NO.` (or type `C #12`): shows the line, then prompts with its number; type the replacement, or `//` to keep it |
| `D` | `FROM LINE, TO LINE` (`5` or `5,8`); lists the lines, asks `ARE THESE THE CORRECT LINE(S) (Y/N)?`, then deletes |
| `I` | `# OF LINES TO INSERT BEFORE LINE # n,line` (e.g. `3,10` inserts 3 lines before line 10); end early with `//` |
| `L` | `FROM LINE, TO LINE`: lists the lines (`5` or `5,12`) |
| `S` | `STR`: lists every line containing the text (exact, case-sensitive substring) |
| `T` | Lists the whole file |
| `X` | Saves the file and leaves edit mode (`NAME SAVED`) |
| `?` | Re-displays the menu |

Any other letter prints `CMD ERR -- TYPE ? FOR LIST`.

### 6.3 Line-number format

Line numbers print five wide by default (`    1`). You can change the
format in the startup script, or with `plxcfg lines`:

| Setting | Appearance |
|---|---|
| `plxcfg lines ACP.PLX 1` | `1` `2` `3` ... |
| `plxcfg lines ACP.PLX 2 Z` | `01` `02` `03` ... |
| `plxcfg lines ACP.PLX 5 Z` | `00001` `00002` ... |

---

## 7. The assembler

### 7.1 Source format

```
label   MNEMONIC   operand   comment
```

* A **label** starts in column 1 (a trailing `:` is allowed and removed). Labels
  are upper-cased and the first **15 characters** are significant. They may contain
  letters, digits, `_` and `.`.
* A line whose first character is `*` or `;` is a **comment** line.
* The **mnemonic** and the **operand** are separated by blanks. The operand is
  one blank-free token, and anything after it is treated as a comment (for the
  data directives, which may contain blanks inside quotes, use `;` to start a
  comment).
* Mnemonics and directives are case-insensitive.

### 7.2 Addressing modes

| Syntax | Mode | Example |
|---|---|---|
| (none) | Inherent / accumulator | `INCA`  `RTS`  `NOP` |
| `#expr` | Immediate (16-bit for `LDS` `LDX` `CPX`) | `LDAA #$41`   `LDX #TABLE` |
| `expr` ≤ $FF | **Direct**, chosen automatically | `STAA $10` |
| `expr` > $FF or not yet defined | **Extended** | `JSR PUTCH`  `LDAA $E000` |
| `expr,X` | Indexed | `LDAA 4,X`  `JMP 0,X` |
| `expr` | Relative (branches) | `BNE LOOP` |

The direct/extended choice is made in pass 1, so a forward reference is always
assembled as extended (3 bytes). A relative branch whose target is more than
127 bytes away reports `BRANCH OUT OF RANGE`.

### 7.3 Expressions

An expression is a chain of terms joined by `+` and `-`, evaluated left to
right (no precedence, no parentheses). A leading sign is allowed.

| Term | Meaning |
|---|---|
| `1234` | decimal |
| `$FF00` | hexadecimal |
| `%10110` | binary |
| `'A` | character code (`'` then one character) |
| `NAME` | a label or `EQU` value |
| `*` | current location counter |

Values are 16-bit (taken modulo 65536). Examples: `TABLE+2`, `END-START`, `*+4`, `$E000+$40`.

### 7.4 Directives

| Directive | Alias | Function |
|---|---|---|
| `ORG expr` | | Set the location counter (and the load address of the output) |
| `label EQU expr` | | Define a constant (needs a label and an operand) |
| `FCB list` | `DB` | Define bytes. Comma-separated items: values or `"quoted strings"` (one byte per character; backslash escapes allowed) |
| `FDB list` | `DW` | Define 16-bit words (high byte first, as on the 6800) |
| `FCC "text"` | | Define a character string; the first character is the delimiter (`FCC /HELLO/`, `FCC "HELLO"`) |
| `RMB expr` | | Reserve `expr` bytes of storage (not written to the output) |
| `END [expr]` | | End of source; the optional operand is the program entry address, written to the S9 record |

```
        ORG   $E000
MSG     FCC   "HELLO, WORLD"
        FCB   $0D,$0A,0
TABLE   FDB   START,LOOP
BUF     RMB   16
START   LDX   #MSG          ; print the message
```

### 7.5 What the assembler asks

Option 2 runs these steps:

1. `SOURCE FILE NAME ?`. The output names are derived from it: drive, directory and
   extension are dropped and the base is cut to 8 characters (`SINE.ASM` gives
   `SINE.LST`, `SINE.S19`, `SINE.BIN`).
2. **Pass 1** builds the symbol table. It reports `LAST ADDRESS USED` and
   `ERROR COUNT`.
3. `PRINT LABEL LIST (Y) ?` (the original wording)
4. `CONTINUE WITH ASSEMBLY (Y) ?`. Answer `N` to abort without writing anything.
5. **Pass 2** generates code, printing each line to the terminal and the listing,
   then the symbol table and the cross-reference table.
6. The listing, S-record and binary files are written, and the directory they
   went to is shown.
7. `PAD BINARY TO SIZE (0=none, 2048=2K ROM, other):`. A larger size pads the `.BIN`
   with `FF` bytes to exactly that length (for burning a ROM).

### 7.6 The listing

```
ADDR  CODE          LINE  SOURCE STATEMENT
----  ------------  ----  ----------------
E000  86 01            3  START   LDAA  #1
E002  97 10            4          STAA  $0010
E004  A6 04            5          LDAA  4,X
E006  B6 E0 0B         6          LDAA  FWD
E009  20 FE            7  LOOP    BRA   LOOP
E00B  48 49            8  FWD     FCC   "HI"

SYMBOL TABLE
  START    E000  LOOP     E009  FWD      E00B

CROSS-REFERENCE TABLE
SYMBOL          TYP  VAL   DEF     CNT  REFERENCES
--------------  ---  ----  -----  ----  ------------------------------------
FWD             LAB  E00B  L8        1  L6
LOOP            LAB  E009  L7        1  L7
START           LAB  E000  L3        0
```

(Note the forward reference to `FWD` assembled as a 3-byte extended
instruction, `B6 E0 0B`, while the already-known `$0010` became a 2-byte direct
one.) After the code come the **symbol table** (every label with its value) and
the **cross-reference**, a sorted table of each symbol with its type (`LAB`
address, `EQU` constant, or storage reserved by `RMB`), value, defining line and
the lines that use it. The listing ends with an `ASSEMBLY SUMMARY` and either
`STATUS: ASSEMBLY SUCCESSFUL - NO ERRORS` or the error count.

Option 4 changes the width used for the source column and the wrapping of the
cross-reference lists.

---

## 8. Output files

| File | Contents |
|---|---|
| `NAME.LST` | The full listing, symbol table, cross-reference and summary (text) |
| `NAME.S19` | Motorola **S-records**: `S1` data records (up to 16 bytes each), `S9` end record carrying the `END` entry address |
| `NAME.BIN` | Raw binary of the assembled range, from the lowest to the highest address emitted. The bytes are an exact image, so with `ORG $E000` the file's first byte is the byte for $E000. Optionally padded with `FF` |

The binary image window is 32 KB. `RMB` areas and gaps are not written
to the S-records.

These are the formats expected by 6800 emulators, EPROM programmers and ROM
tools: load the `.S19` into an emulator, or burn the padded `.BIN` (for example
`PAD ... 2048` for a 2 KB 2716 ROM image at `$E000`).

---

## 9. Error messages

Assembly errors print as `*** ERROR (LINE n): MESSAGE - detail` and are repeated
in the listing with the offending source line.

| Message | Cause |
|---|---|
| `INSTRUCTION NOT FOUND - xxx` | unknown mnemonic or directive |
| `LABEL ALREADY EXISTS - xxx` | a label defined twice |
| `OPERAND MISSING IN SOURCE STATEMENT` | an instruction or `EQU` that needs an operand has none |
| `OPERAND NOT FOUND - xxx` | undefined symbol, bad expression, or an addressing mode the instruction does not have (for example `STAA #1`) |
| `VALUE OUT OF BOUNDS - xxx` | an 8-bit operand larger than 255 |
| `BRANCH OUT OF RANGE - xxx` | relative branch beyond -128 / +127 |

Editor and shell messages keep the original wording: `FILE NOT FOUND`,
`NAME MUST BE 1-8 ALPHANUMERIC, BEGIN WITH A LETTER`, `CMD ERR -- TYPE ? FOR LIST`,
`NO SUCH LINE`, `STRING NOT FOUND`, `DELETE IGNORED`.

---

## 10. Startup scripting with PL/X

At start ACPX runs a **PL/X** script that can

* ask for an account id and password (hidden input, attempt counting),
* print any banner, in any layout, with colours or ADM-31 escape codes,
* supply the text above each ACP menu and the sign-off message,
* set the editor's line-number format.

A minimal script:

```
BANNER
{
    "WELCOME TO ACPX V", VERSION, '\n'
}

GOODBYE
{
    "SIGNED OFF.", '\n'
}
```

Use the configuration tool to create and test scripts without writing any code:

```
plxcfg                       interactive menu
plxcfg new   MY.PLX          wizard: login and banner
plxcfg check MY.PLX          check syntax, labels and blocks
plxcfg run   MY.PLX          preview the script
plxcfg lines MY.PLX 5 Z      editor line numbers 00001, 00002, ...
acpx -c MY.PLX               use it
```

The full language reference (types, expressions, formats, blocks, host hooks and
error messages) is in **[PLX.md](PLX.md)**. Ready-made scripts:

| Script | Description |
|---|---|
| `ACP.PLX` | The default: the classic LSI01 login and welcome text |
| `MICOS.PLX` | A boxed, verbose banner with the ACP/x logo |

---

## 11. Limits

| Item | Limit |
|---|---|
| Lines per source file | 3000 |
| Source line length | 127 characters |
| Symbols | 2000 |
| Cross-reference entries | 12 000 |
| Object bytes from one source line | 64 |
| Binary image window | 32 KB |
| Label length | 15 significant characters |

---

## 12. Platform notes

* **Linux / macOS / Unix:** works on a terminal or over a serial line (plain stdio, no
  curses); hidden password entry uses termios.
* **Windows:** a console program (32- and 64-bit builds). ANSI escape codes are
  switched on automatically on Windows 10 and later, so coloured banners work in
  Command Prompt and PowerShell.
* **DOS:** build with Turbo C large model; password entry uses direct keyboard
  reads. For ANSI escapes in banners under plain DOS, load `ANSI.SYS`.
* Input can be **redirected**: `acpx < session.txt` runs a scripted session
  (prompts run together in the output because no keystrokes are echoed).
* On an ADM-31 or any other serial terminal, `\e` escape sequences in a PL/X banner can
  position the cursor, clear the screen, or select highlighting.

---

## 13. Repository layout

```
acpx/
  README.md        this file
  PLX.md           PL/X language reference
  PLX.TXT          one-page PL/X summary
  ACP.PLX          default startup script
  MICOS.PLX        verbose boxed banner
  src/
    acpx.c         ACP shell, ASSEDIT editor, 6800 assembler
    plx.c          PL/X interpreter (included by both programs)
    plxcfg.c       PLXCFG configuration tool
  dos/             ACPX.EXE, PLXCFG.EXE   (Turbo C++ 1.00, large model)
  win32/           ACPX.EXE, PLXCFG.EXE   (MinGW-w64, 32-bit)
  win64/           ACPX.EXE, PLXCFG.EXE   (MinGW-w64, 64-bit)
```

---

*ACPX and PL/X by Mickey W. Lawless. Based on the environment described in the
Lear Siegler ADM-2 microprogramming manual.*
# PL/X

**The ACPX scripting language — language reference, host interface and tool guide**

*Language designed by Mickey W. Lawless.*
*Reference interpreter: `plx.c` (strict ANSI C89), shipped with ACPX 1.5.*

---

## Table of contents

1. [What PL/X is](#1-what-plx-is)
2. [Quick start](#2-quick-start)
3. [Files and tools](#3-files-and-tools)
4. [Running scripts](#4-running-scripts)
5. [Program structure and execution model](#5-program-structure-and-execution-model)
6. [Lexical structure](#6-lexical-structure)
7. [Data types and variables](#7-data-types-and-variables)
8. [Expressions](#8-expressions)
9. [Statements](#9-statements)
10. [Blocks](#10-blocks)
11. [Labels and control flow](#11-labels-and-control-flow)
12. [Input and output](#12-input-and-output)
13. [Predefined and host variables](#13-predefined-and-host-variables)
14. [The ACPX host interface](#14-the-acpx-host-interface)
15. [PLXCFG, the configuration tool](#15-plxcfg-the-configuration-tool)
16. [Limits](#16-limits)
17. [Error messages](#17-error-messages)
18. [Pitfalls and rules of thumb](#18-pitfalls-and-rules-of-thumb)
19. [Formal grammar](#19-formal-grammar)
20. [Complete examples](#20-complete-examples)
21. [Building the interpreter and tools](#21-building-the-interpreter-and-tools)
22. [Portability notes](#22-portability-notes)
23. [Revision history](#23-revision-history)

---

## 1. What PL/X is

PL/X is a small, line-oriented scripting language with the flavour of 1970s
timesharing systems (MICOS, ADM-ACP, PL/I-style dotted operators, `*LABELS*`,
`RET`/`PROCEED`). It exists to make the **startup sequence of ACPX** fully
programmable:

* the **login dialogue** (account id, password, attempt counting),
* the **welcome banner** (any text, any layout, ANSI/ADM-31 escape codes),
* the **ACP menu header** printed above every menu,
* the **sign-off message**,
* and the **editor's line-number format** (`1`, `01`, `00001`, ...).

A PL/X program is a plain text file, conventionally named `*.PLX`. ACPX loads
it at startup (default `ACP.PLX`), runs it, and then continues with the normal
ACP menu. Nothing in a script is mandatory: an empty script is legal and
simply leaves ACPX with its built-in banner.

Design goals of the language:

| Goal | How |
|---|---|
| Readable by someone who used 1970s terminals | Keywords such as `ASSIGN`, `PROCEED`, `RET`, dotted operators `.EQ.` `.AND.` |
| Output-first | A line that is just a list of strings and variables *prints* them |
| Safe | No file or system access, bounded step count, bounded memory |
| Small | One C file, no dependencies, runs on DOS (Turbo C), Windows and Unix |

PL/X is **case-insensitive** (names, keywords and format letters), except for
the contents of strings and the comparison of string values.

---

## 2. Quick start

Save as `HELLO.PLX`:

```
/* HELLO.PLX - smallest useful PL/X program */
BANNER
{
    "HELLO FROM PL/X, VERSION ", VERSION, '\n'
}
```

Check it and run it:

```
plxcfg check HELLO.PLX
plxcfg run   HELLO.PLX
acpx -c HELLO.PLX
```

A line that is only an item list prints the items. A `BANNER` block runs where
it appears. `VERSION` is supplied by the host. `'\n'` is a one-character string
holding a newline.

A login screen with a password:

```
VAR(DECLARATION)
{
    ASSIGN ACT.EQ.'LSI01'
    ASSIGN ACTPW.EQ.'21121'
    ASSIGN INT TRIES.EQ.0
    ASSIGN INT MAXTRY.EQ.3
}

*PROMPT1*["ACCOUNT-ID: ",AID:5A1],'\n'
 IF (AID == ACT) THEN PROCEED *PROMPT2*
 TRIES = TRIES + 1
 IF (TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
 "INVALID ACCOUNT-ID",'\n'
 RET *PROMPT1*

*PROMPT2*["PASSWORD: ",PAS:5H1],'\n'
 IF (PAS == ACTPW) THEN PROCEED *WELCOME*
 TRIES = TRIES + 1
 IF (TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
 "INVALID PASSWORD",'\n'
 RET *PROMPT1*

*WELCOME*
BANNER
{
    "WELCOME, ", AID, '\n'
}
```

---

## 3. Files and tools

| File | Purpose |
|---|---|
| `ACPX.EXE` / `acpx` | The assembler/editor. Loads and runs a PL/X script at startup. |
| `PLXCFG.EXE` / `plxcfg` | Configuration tool: wizard, syntax checker, preview runner, line-number setter. |
| `ACP.PLX` | The default startup script (loaded automatically from the current directory). |
| `MICOS.PLX` | A verbose, boxed example banner generated with the PLXCFG wizard. |
| `PLX.TXT` | One-page quick reference (plain text). |
| `README.md` | This document. |
| `src/plx.c` | The PL/X interpreter. `#include`d by both `acpx.c` and `plxcfg.c`. |
| `src/acpx.c`, `src/plxcfg.c` | The host programs. Keep all three together when compiling. |

---

## 4. Running scripts

### 4.1 ACPX command line

```
acpx                    load ACP.PLX from the current directory if it exists
acpx -c FILE.PLX        load FILE.PLX
acpx FILE.PLX           same as -c FILE.PLX (any argument not starting with '-')
acpx -n                 ignore all scripts and use the built-in banner
```

Any other option prints the usage text and exits with status 1.

If the script cannot be opened, has a syntax error, or fails at run time,
ACPX prints the `PLX ERROR ...` message and **falls back to the built-in
banner and menu header**, so a broken script never locks you out.

### 4.2 PLXCFG command line

```
plxcfg                               interactive menu
plxcfg new   FILE.PLX                banner / login wizard
plxcfg check FILE.PLX                syntax, label and block check
plxcfg run   FILE.PLX                run the script as ACPX would at startup
plxcfg call  FILE.PLX BLOCK          run one named block (MENUHDR, GOODBYE, ...)
plxcfg lines FILE.PLX [DIGITS [Z|P]] set the editor line-number format
```

See [section 15](#15-plxcfg-the-configuration-tool).

---

## 5. Program structure and execution model

A PL/X program is a flat sequence of **statements** and **blocks**. There is
no `main`, no `end of program` marker, and no declaration section required.

### 5.1 Load phase

1. The file is read (at most 32 000 bytes), converted to **tokens** (at most
   3 000) and the system variables (`SYSDATE`, ...) are initialised.
2. A **scan** records every `*LABEL*` and every named `{ ... }` block, and
   checks that braces balance.
3. Any lexical or scan error aborts the load with a `PLX ERROR LINE n: ...`
   message. Nothing has been executed yet.

### 5.2 Run phase

1. The host sets its own variables (ACPX sets `VERSION`).
2. All `VAR(name) { ... }` blocks are run **in file order**. This is the
   "declaration section": it may sit anywhere in the file.
3. The main flow starts at the top of the file and runs statement by statement:
   * ordinary statements execute;
   * the `BANNER` block executes in place;
   * every other block (`VAR(...)`, `SUB`, `MENUHDR`, `GOODBYE`, ...) is
     **skipped** — it only runs when called (`CALL`) or when the host calls it;
   * `*LABEL*` lines are markers and do nothing by themselves.
4. The run ends when the end of the file is reached (normal), when `HALT` or
   `EXIT` executes (the host then exits), or when an error occurs.
5. Afterwards the host may call hook blocks (`MENUHDR` before each menu,
   `GOODBYE` on sign-off) and read host variables (`LNWIDTH`, `LNZERO`,
   `SKIPHDR`).

### 5.3 Statements and lines

PL/X is **line oriented**: a statement ends at the end of the line. Two
statements may share a line only where the grammar makes the boundary
unambiguous, typically an `IF` whose body is a `{ block }` followed by `ELSE`.
To continue a statement on the next line, use `&` ([section 6.6](#66-line-continuation)).

Indentation and blank lines are free.

---

## 6. Lexical structure

### 6.1 Character set

Source is read as text (CR, LF and CRLF line endings are all accepted).
Outside strings and comments only these characters are meaningful:

```
letters  digits  _  $  .  *  &  "  '  [ ] { } ( ) , : = < > ! + - /  space  tab
```

Any other character produces `UNEXPECTED CHARACTER 'c'`.

### 6.2 Comments

```
/* block comment, may span lines */
// line comment to end of line
```

Comments are removed during lexing. They do not nest.

### 6.3 Identifiers

An identifier starts with a letter or `_` and continues with letters, digits
and `_`. Identifiers are **case-insensitive** and only the first **15
characters** are significant (extra characters are ignored: `A_VERY_LONG_NAME_XYZ`
and `A_VERY_LONG_NAM` are the same name).

Identifiers name variables, blocks, keywords and format specifiers.

### 6.4 Numbers

| Form | Example | Value |
|---|---|---|
| Decimal | `4100` | 4100 |
| Hexadecimal, `$` prefix | `$1F`, `$e000` | 31, 57344 |

Numbers are signed `long` (at least 32 bit). There is no negative literal;
write `-5` as unary minus applied to `5` (legal inside expressions, see 8.4).
There are no floating-point numbers.

### 6.5 Strings

Strings are delimited by `"..."` or `'...'`; both are identical. A string
**cannot span lines** (an unterminated string is `UNTERMINATED STRING`). The
other quote character needs no escaping inside a string: `"IT'S"`, `'say "hi"'`.

Escape sequences:

| Escape | Character |
|---|---|
| `\n` | newline |
| `\r` | carriage return |
| `\t` | tab |
| `\e` | ESC (27) — for ANSI / ADM-31 escape sequences |
| `\a` | bell (7) |
| `\f` | form feed (12) |
| `\xHH` | the byte with hex value `HH` (one or two hex digits; `\x00` is ignored) |
| `\\` | backslash |
| `\"` `\'` | the quote character |
| `\` + any other char | that character |

`'\n'` is therefore an ordinary one-character string and is the usual way to
end a printed line.

A string literal may be up to 250 characters. When a string is *stored in a
variable* or produced by an expression it is limited to **95 characters**
(longer values are silently truncated).

### 6.6 Line continuation

The `&` character joins lines. It may stand at the **start** of the next line
(the traditional style) or at the **end** of the current line:

```
"       GOOD DAY USER ",I4,"  PORT ",I1,'\n'
&   "           WELCOME TO THE WONDERFUL WORLD OF 'MICOS'",'\n'
&   "*************************************************************",'\n'
```

This prints three lines with one statement. Blank lines between the pieces are
also absorbed.

### 6.7 Labels

`*NAME*` is a **label** — but only when it appears at the start of a statement
(first token of a line, or directly after `{` or `}`) or directly after
`GOTO`, `PROCEED` or `RET`. Anywhere else `*` is the multiplication operator.

### 6.8 Dotted operators

`.EQ.` `.NE.` `.LT.` `.GT.` `.LE.` `.GE.` `.AND.` `.OR.` `.NOT.`

Case-insensitive. A dot followed by a letter that does not form one of these
operators is `BAD DOTTED OPERATOR`.

### 6.9 Operators and punctuation

```
[ ]  { }  ( )  ,  :  =  ==  <>  !=  <  >  <=  >=  +  -  *  /
```

### 6.10 Reserved words

These cannot be used as variable names:

```
IF THEN ELSE ASSIGN INT STR STRING CALL GOTO PROCEED RET HALT EXIT
DELAY BEEP PAUSE END SUB VAR
```

`BANNER`, `MENUHDR`, `GOODBYE` and the host variables (`LNWIDTH`, ...) are
*conventional* names, not reserved words. Format-looking names (`A`, `S`, `I`,
`Z`, `H` followed by digits, such as `I4`, `A10`) are special in output lists
(section 12.6); avoid them as variable names.

---

## 7. Data types and variables

PL/X has two types:

| Type | Holds | Created by |
|---|---|---|
| **INT** | a signed `long` | `ASSIGN INT X.EQ.5`, or any assignment of a numeric value |
| **STR** | text up to 95 characters | `ASSIGN STR X.EQ.5`, or any assignment of a string value |

Variables are **global** and created by assignment. There is no separate
declaration, no scoping, and no arrays. At most **64** variables exist
(including the system ones).

### 7.1 Typing rules

* An assignment without a type keyword takes the type of the value assigned:
  `X = 5` makes an INT, `X = "5"` makes a STR. (Re-assigning changes the type.)
* `ASSIGN INT X.EQ.expr` forces INT: a string value is converted with the C
  `atol` rule (leading digits; no digits means 0).
* `ASSIGN STR X.EQ.expr` forces STR: a number is converted to its decimal text.
* Reading an **undefined** variable is an error (`UNDEFINED VARIABLE name`).
  Always assign before use. The `VAR(...)` block exists for exactly that.

### 7.2 Truth

A value is **true** if it is a non-zero number or a non-empty string.
Comparisons and logical operators yield `1` (true) or `0` (false), always INT.

---

## 8. Expressions

### 8.1 Precedence

From lowest to highest binding:

| Level | Operators | Notes |
|---|---|---|
| 1 | `.OR.` | logical OR, result 0/1 |
| 2 | `.AND.` | logical AND for numbers; **concatenation** if either side is a string |
| 3 | `.NOT.` | prefix, logical negation |
| 4 | `==` `=` `.EQ.`  `<>` `!=` `.NE.`  `<` `.LT.`  `>` `.GT.`  `<=` `.LE.`  `>=` `.GE.` | one comparison per level (not chained) |
| 5 | `+` `-` | `+` **concatenates** if either side is a string |
| 6 | `*` `/` | integer arithmetic; `/` truncates; division by zero is an error |
| 7 | unary `-`, `( )`, literals, variables | |

All binary operators are left-associative.

### 8.2 Comparison

* Both operands numbers: numeric comparison.
* Otherwise both are converted to text and compared with the C `strcmp`
  ordering — **case-sensitive**. A number compared with a string uses the
  decimal text of the number.

Note that `ASSIGN INT TRIES.EQ.0` then `IF (TRIES >= MAXTRY)` is numeric, but
`IF (AID == ACT)` with two strings is textual. Console input in format `A` is
upper-cased on entry, so compare it with upper-case literals.

### 8.3 String building

```
S = "AB" + "CD" + 7          /* "ABCD7"  - + concatenates when a side is a string */
D = MON .AND. "/" .AND. DAY  /* "OCT/30" - .AND. also concatenates strings        */
V = "5" + 1                  /* "51"     - NOT 6: one side is a string            */
V = "5" - 1                  /* 4        - '-' always converts to numbers         */
```

Concatenated results are cut at 95 characters. For formatted text see the
capture-print form in section 12.5.

### 8.4 Arithmetic

* `+` `-` `*` `/` on INTs behave as C `long` (truncating division).
* Unary minus applies to a primary: `-X`, `-(A+B)`, `-5`.
* `$FF + 1` is `256`.
* Strings used with `-` `*` `/` are converted to numbers (`atol`).

### 8.5 Where expressions are allowed

Expressions are allowed on the right of an assignment, inside `IF ( ... )`, and
as the operand of `DELAY`. **Output lists are not expressions:** an output item
is a literal, a variable or a format (section 12); to print a computed value,
assign it to a variable first.

```
X = 7 / 2
"HALF IS ", X, '\n'        /* correct */
"HALF IS ", 7 / 2, '\n'    /* NOT valid: '/' is not allowed in an output list */
```

---

## 9. Statements

### 9.1 Summary

| Statement | Purpose |
|---|---|
| `items` | Print an output list (section 12) |
| `[ items ]` | Prompt list: print text and **read** input into variables |
| `NAME = [ items ]` | Print the items **and** store the text in `NAME` |
| `ASSIGN [INT\|STR] NAME.EQ.expr` | Assign |
| `[INT\|STR] NAME = expr`, `NAME.EQ.expr` | Assign (short forms) |
| `IF (expr) [THEN] stmt [ELSE stmt]` | Conditional |
| `GOTO *L*` `PROCEED *L*` `RET *L*` | Jump to a label |
| `CALL NAME` | Run a named block, then continue after the CALL |
| `HALT [items]` / `EXIT` | Print optional items, then end the program |
| `DELAY expr` | Wait `expr` milliseconds |
| `BEEP` | Ring the terminal bell (`\a`) |
| `PAUSE [items]` | Print optional items, wait for RETURN |
| `{ ... }` | Plain statement group |
| `END(NAME)`, `NAME<END>` | Closing markers, ignored |
| `NAME { ... }`, `SUB NAME { ... }`, `VAR(NAME) { ... }` | Block definitions (section 10) |

### 9.2 Assignment

```
ASSIGN ACT.EQ.'LSI01'            /* classic form                          */
ASSIGN INT DAY.EQ.SYSDAY         /* typed                                  */
ASSIGN STR CODE.EQ.1234          /* STR "1234"                             */
TRIES = TRIES + 1                /* short form, type comes from the value  */
INT N = "42"                     /* typed short form: N = 42               */
DATE = [MON,"/",DAY,"/",YEAR]    /* capture-print form (see 12.5)          */
```

The `.EQ.` of `ASSIGN X.EQ.value` is the assignment symbol here, not a
comparison. Inside `IF ( ... )` and other expressions `=` and `.EQ.` are
comparisons.

### 9.3 IF / THEN / ELSE

```
IF (expr) statement
IF (expr) THEN statement
IF (expr) statement ELSE statement
IF (expr) { ... } ELSE { ... }
IF (expr) { ... }
ELSE { ... }                      /* ELSE may start the next line */
```

* `THEN` is optional.
* The body is **one statement**: a single line (an output list, an assignment,
  a jump, `HALT`, ...) or a `{ ... }` group.
* A single-line body ends at the end of the line; `ELSE` may follow on the
  same line or at the start of the next line.
* `IF` statements can nest (the body can itself be an `IF`).

```
IF (N > 2) { "BIG",'\n' } ELSE { "SMALL",'\n' }
IF (AID == ACT) THEN PROCEED *PROMPT2*
IF (TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
```

A single-line body that is an output list ends at the first item that cannot
continue the list (a keyword, or a name followed by `=`), or at the end of the
line.

### 9.4 HALT / EXIT

`HALT items` prints the items (if any) and ends the whole program. For ACPX this
means **ACPX exits immediately** — the standard way to refuse a login. `EXIT` is
the same without output (items are accepted too). Input reaching end-of-file
during a prompt also halts the script.

### 9.5 PAUSE, DELAY, BEEP

```
PAUSE "PRESS RETURN TO CONTINUE"     /* prints text, waits for a line of input */
DELAY 1500                           /* busy-waits about 1.5 s                  */
BEEP                                 /* prints the bell character               */
```

`DELAY` uses the CPU clock and spins; keep delays short. `PAUSE` hitting
end-of-file halts the script.

### 9.6 CALL

`CALL NAME` runs the body of block `NAME` (any block kind) and returns to the
statement after the `CALL`. Blocks can call other blocks up to a nesting depth
of 12. Blocks do not take arguments; they share the global variables.

```
SUB RULE
{
    "-----------------------------------------------",'\n'
}
CALL RULE
"  HELLO",'\n'
CALL RULE
```

(Defining the block after the call is fine: blocks are known after the load
phase.)

### 9.7 Closing markers

For readability in the classic style, a block may end with `END(NAME)` or
`NAME<END>` as its last line. Both forms are accepted anywhere and have no
effect.

---

## 10. Blocks

A **block** is a name followed by a brace group. The name may be on the line
above the `{`.

```
NAME
{
    statements
}
```

### 10.1 Block kinds

| Form | Kind | When it runs |
|---|---|---|
| `BANNER { ... }` | inline | in place, when the main flow reaches it |
| `VAR(NAME) { ... }` | hoisted | automatically, **before** the main flow, in file order |
| `SUB NAME { ... }` | callable | only by `CALL NAME` |
| `NAME { ... }` (any other name) | callable | only by `CALL NAME` or the host |

Block names are case-insensitive and unique (except that several `VAR(...)`
blocks may share a name). Reserved words cannot be block names. At most 32
blocks per script.

### 10.2 Host hooks

The ACPX host looks for these callable blocks by name:

| Block | Called by ACPX |
|---|---|
| `MENUHDR` | before every ACP menu; replaces the built-in "'ACP' AT YOUR SERVICE" header |
| `GOODBYE` | on `BYE` and on menu option 5; replaces the built-in "SIGNED OFF." |

If a hook block does not exist the built-in text is used. See section 14.

### 10.3 `VAR` blocks

A `VAR` block is the place for declarations and settings. Because VAR blocks
run first wherever they stand, the traditional layout puts them at the top, but
they may equally sit at the end of the file (PLXCFG appends its
`VAR(LINENUM)` block at the end).

```
VAR(DECLARATION)
{
    ASSIGN ACT.EQ.'LSI01'
    ASSIGN INT USRNO.EQ.4100
    END(DECLARATION)
}
```

### 10.4 Bare groups

A `{ ... }` that is not preceded by a name (or by `IF` / `ELSE`) is simply a
statement group and runs in place.

---

## 11. Labels and control flow

### 11.1 Defining and using labels

```
*RETRY*
...
GOTO *RETRY*
```

Labels live in one global namespace (max 64, duplicates are
`DUPLICATE LABEL`). A label is a marker on its own line (a statement may follow
on the same line).

### 11.2 The three jump verbs

`GOTO`, `PROCEED` and `RET` all jump to a label and are **equivalent**. Three
spellings exist because the original language used them idiomatically:

| Verb | Idiom |
|---|---|
| `GOTO *L*` | unconditional jump |
| `PROCEED *L*` | "carry on at L" — typically in the success branch of an `IF` |
| `RET *L*` | "return to L" — typically to repeat a prompt |

`PROCEED` or `RET` with **no label** after them is a no-op. `GOTO` without a
label is `LABEL EXPECTED AFTER GOTO`.

```
*PROMPT1*["ACCOUNT-ID: ",AID:5A1],'\n'
 IF (AID == ACT) THEN PROCEED *PROMPT2*      /* good: move on        */
 TRIES = TRIES + 1
 IF (TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
 "INVALID ACCOUNT-ID",'\n'
 RET *PROMPT1*                               /* bad: ask again       */
```

### 11.3 Loops

There is no loop keyword; build loops with a label and a conditional jump:

```
ASSIGN INT N.EQ.5
*AGAIN*
"COUNTDOWN ",N,'\n'
N = N - 1
IF (N > 0) GOTO *AGAIN*
"LIFTOFF",'\n'
```

A run is limited to **200 000 statements**; exceeding that stops the script
with `LOOP LIMIT EXCEEDED` (protects against infinite loops).

### 11.4 Jumping out of blocks

A jump may leave a block (even a `CALL`ed one) to a label in an enclosing
region. Do **not** jump *into* a block from outside it.

---

## 12. Input and output

### 12.1 Output lists

Any line that does not start with a keyword or an assignment is an **output
list**: items separated by commas (commas are optional between items, but use
them).

| Item | Prints |
|---|---|
| `"text"` / `'text'` | the string |
| `123`, `$1F` | the number in decimal |
| `NAME` | the variable's value |
| `NAME:fmt` | the variable formatted (12.4) |
| `I4`, `A10`, ... (bare format) | USRNO / PORTNO (12.6) |
| `[ ... ]` | a nested prompt list (12.2) |
| `NAME=[ ... ]` | capture-print (12.5) |

The list ends at the end of the line. A trailing comma does **not** continue
the list; use `&`. Output is not buffered across lines: each item is written
straight to standard output.

```
"GOOD DAY, USER ", USRNO:I4, "   ", SYSDATE, '\n'
```

### 12.2 Prompt lists — reading input

A bracketed list `[ ... ]` is a **prompt list**. Strings and variables inside
print as usual, and an item of the form `NAME:fmt` **reads a line of input** into
`NAME`:

```
["ACCOUNT-ID: ", AID:5A1]       /* prints the prompt, reads up to 5 characters into AID */
["AMOUNT: ", AMT:I6]            /* reads an integer                                      */
```

Inside the brackets newlines are ignored, so a prompt list can be spread over
several lines. One input is read per `NAME:fmt` item, each consuming a whole
line from standard input (the user presses RETURN).

If input reaches end-of-file the script halts (for ACPX: the program exits).

### 12.3 Input conversion

For an input item with format letter:

| Letter | Stored as | Conversion |
|---|---|---|
| `A` | STR | input is converted to **upper case** |
| `S` | STR | input stored exactly as typed |
| `H` | STR | hidden input (12.7); also upper-cased |
| `I` | INT | `atol` of the text (garbage becomes 0) |
| `Z` | INT | same as `I` (the `Z` matters only when printing) |

Input longer than the field width is cut to the width. A width of 0 (bare `A`,
`S`) means "up to 95 characters".

### 12.4 Format specifiers

A format is written after a colon: `NAME:fmt`. Its syntax is

```
fmt  ::=  [ count ] LETTER [ width ]          LETTER = A | S | I | Z | H
```

The field width in characters is `width × count` (each missing part counts as 1):

| Spelling | Meaning | Field width |
|---|---|---|
| `A` / `S` | text, any length | unlimited (up to 95) |
| `A5` | text | 5 |
| `5A1` | five times `A1` | 5 |
| `5A` | five times `A` | 5 |
| `I4` | integer | 4 |
| `Z5` | integer, zero-padded | 5 |
| `H1`, `5H1` | hidden text | 1, 5 |

Both `5A1` and `A5` are width 5; `5A1` is the original "five one-character
fields" style.

When **printing** `NAME:fmt`:

| Letter | Output |
|---|---|
| `A` `S` `H` | text, left-justified, padded or **truncated** to the width |
| `I` | number, right-justified in the width (blank padded) |
| `Z` | number, zero-padded to the width (`00042`) |

```
N = 42
S = "AB"
N:I5, '|', N:Z5, '|', S:A5, '|'     /* prints    42|00042|AB   |  */
```

Formats apply to **variables**, not literals. A format with no letter
(`S:6`) is `BAD FORMAT`.

### 12.5 Capture-print: `NAME=[ ... ]`

Prints the bracketed items **and** stores what was printed in the variable
`NAME` (as a STR, at most 95 characters). It is the PL/X way to format text:

```
DATE=[MON,"/",DAY,"/",YEAR]      /* prints OCT/30/2026 and stores it in DATE */
```

It can be used as a stand-alone statement, inside a prompt list or as the right
side of an assignment (`TXT = [ "A", N ]`). Nested `[ ]` in a capture are also
output only (no input).

### 12.6 Bare formats: `I4`, `A10`, ...

A name that looks like a format but is **not** a defined variable (letter
`A S I Z H` followed only by digits) prints one of two implicit values:

* the first bare format in a block run prints `USRNO`,
* the second prints `PORTNO`,
* any further ones print blanks of that width.

```
"       GOOD DAY USER ",I4,"  PORT ",I1,'\n'      /* GOOD DAY USER 4100  PORT 7 */
```

The count restarts every time a block starts running (and is restored after a
`CALL`). If `USRNO` / `PORTNO` are not defined, blanks are printed.
New scripts should prefer the explicit `USRNO:I4`, which does the same and is
self-documenting.

### 12.7 Hidden input (`H`)

```
["PASSWORD: ", PAS:5H1]
```

The typed characters are **not echoed**:

* on Unix the terminal's echo is turned off during the read,
* in a Windows or DOS console the keys are read directly (`_getch` / `getch`),
* when standard input is a file or pipe nothing special happens.

After RETURN, one `X` is printed per character typed, so the screen shows
`PASSWORD: XXXXX`. Backspace works on the console. Ctrl-C / Ctrl-Z abort the read
(the script halts).

### 12.8 Newline handling on a terminal

On an interactive terminal the RETURN you type is already echoed by the
terminal, so a `'\n'` printed right after visible input would produce a blank
line. PL/X therefore **drops a leading newline** at the first output after a
visible keyboard input (and after `PAUSE`). With piped input there is no echo,
so the newline is kept — scripts behave identically either way: write
`..., AID:5A1], '\n'` and you get exactly one line break.

### 12.9 Escape sequences and terminals

Because `\e` produces ESC, scripts can drive any terminal:

```
"\e[2J\e[H"                      /* ANSI: clear screen, home           */
"\e[1m BOLD \e[0m"               /* ANSI bold                          */
```

On Windows 10+ the console is switched to VT processing at startup so ANSI
sequences work. ADM-31 sequences (`\e=`, `\e*`, ...) work on a real ADM-31 or an
emulator.

---

## 13. Predefined and host variables

### 13.1 Provided to scripts

| Name | Type | Value |
|---|---|---|
| `VERSION` | STR | ACPX version, e.g. `1.5` (set by the host before the run) |
| `SYSMON` | STR | three-letter upper-case month: `JAN` ... `DEC` |
| `SYSDAY` | INT | day of month, 1–31 |
| `SYSYEAR` | INT | four-digit year |
| `SYSDATE` | STR | `MM/DD/YY`, e.g. `10/30/26` |
| `SYSTIME` | STR | `HH:MM:SS` (24 hour) |

The `SYS*` values are captured **once, when the script is loaded**; they do not
tick during a run.

### 13.2 Read by the host after the script runs

| Name | Meaning |
|---|---|
| `LNWIDTH` | editor line-number width, 1–9 (anything else is ignored; default 5) |
| `LNZERO` | non-zero: zero-pad line numbers (`LNWIDTH 5` → `00001`); zero: blank-pad (`    1`) |
| `SKIPHDR` | non-zero and no `MENUHDR` block: skip the built-in menu header once |

### 13.3 Conventions

`USRNO` and `PORTNO` are used by bare formats (12.6). Everything else
(`ACT`, `ACTPW`, `TRIES`, `MAXTRY`, `AID`, `PAS`, `MON`, `DAY`, `YEAR`, `DATE`) is
just the naming used by the stock `ACP.PLX`.

---

## 14. The ACPX host interface

### 14.1 Startup sequence

1. Parse the command line (section 4.1); without `-n` and without a file,
   use `ACP.PLX` if present in the current directory.
2. `plx_load`: on failure print the `PLX ERROR` text and continue with the
   built-in banner.
3. Set `VERSION`, then `plx_run` (VAR blocks, then the main flow).
4. * Error → print `PLX ERROR LINE n: ...`, discard the script, use built-in
     banner and menu header.
   * `HALT` / `EXIT` → ACPX exits with status 0 (this is how a failed login ends).
   * Otherwise the script is *active*: `LNWIDTH`, `LNZERO` and `SKIPHDR` are read.
5. If no script is active, **or the script never ran a `BANNER` block**, the
   built-in banner is printed.
6. The ACP menu loop starts.

### 14.2 During the session

* Before each menu: if `MENUHDR` exists it runs; else, if `SKIPHDR` was set it is
  skipped once; else the built-in header is printed. A run-time error inside
  `MENUHDR` prints the message and deactivates the script (built-in header from
  then on).
* On `BYE` or option 5: if `GOODBYE` exists it runs, otherwise the built-in text.
* The editor formats line numbers according to `LNWIDTH` / `LNZERO`.

### 14.3 The banner is yours

When a script supplies `BANNER`, **nothing else** is printed by ACPX at startup
— blank lines, login lines and credits are the script's responsibility. The
built-in banner (used when there is no script) reproduces the original
`ACCOUNT-ID` / `PASSWORD` / `GOOD DAY USER 4100 PORT 7` session text.

If your `BANNER` already prints the "'ACP' AT YOUR SERVICE" header, either set
`ASSIGN INT SKIPHDR.EQ.1` or move those lines into a `MENUHDR` block; otherwise
the header appears twice at the first menu.

---

## 15. PLXCFG, the configuration tool

### 15.1 Interactive menu

```
PLXCFG  (PL/X CONFIGURATION FOR ACPX V1.5)
1  NEW CONFIG WIZARD
2  CHECK A SCRIPT
3  RUN A SCRIPT (PREVIEW)
4  RUN ONE BLOCK
5  EDITOR LINE-NUMBER FORMAT
6  QUIT
```

### 15.2 `plxcfg new FILE.PLX` — the wizard

Asks for account id, password, user and port numbers, the number of attempts,
whether to include the login dialogue, and then the banner and menu-header text
line by line (end each with a line holding only `//`). In the text you may use
`%V` (version), `%D` (date) and `%U` (user number); the wizard turns them into
`VERSION`, `SYSDATE` and `USRNO:I4` items. It writes a complete script and
suggests `plxcfg check` and `acpx -c FILE.PLX`. It also asks for the editor
line-number format.

### 15.3 `plxcfg check FILE.PLX`

Loads the script (lexical and structural checks) and prints:

```
LABELS: *PROMPT1* *PROMPT2* *WELCOME*
BLOCKS: DECLARATION(HOISTED) BANNER(RUNS INLINE) MENUHDR(CALLABLE) GOODBYE(CALLABLE)
ACP.PLX: SYNTAX OK
```

and reports `LINE n: UNDEFINED LABEL *X*` for any jump to a missing label and
`UNDEFINED BLOCK X` for any `CALL` of a missing block. It does **not** execute
the script, so run-time errors (undefined variables, bad formats) show up only
with `run`.

### 15.4 `plxcfg run FILE.PLX` and `plxcfg call FILE.PLX BLOCK`

`run` executes the script exactly like ACPX at startup (including prompts), then
prints `[SCRIPT HALTED]` if it ended with `HALT`. `call` runs one named block
only: use it to preview `MENUHDR` or `GOODBYE`.

### 15.5 `plxcfg lines FILE.PLX [DIGITS [Z|P]]`

Sets the editor line-number format in the script (menu 5 does the same
interactively). `DIGITS` is 1–9; `Z` zero-pads, `P` (plain) blank-pads:

| Command | Editor shows |
|---|---|
| `plxcfg lines ACP.PLX 1` | `1`, `2`, `3`, ... |
| `plxcfg lines ACP.PLX 2 Z` | `01`, `02`, `03`, ... |
| `plxcfg lines ACP.PLX 5 Z` | `00001`, `00002`, ... |
| `plxcfg lines ACP.PLX 5 P` | `    1`, `    2`, ... |

The tool rewrites the `VAR(LINENUM)` block in place (adding it if absent),
reloads the result to verify it, and restores the original file if the new one
fails to load.

```
VAR(LINENUM)
{
    ASSIGN INT LNWIDTH.EQ.5
    ASSIGN INT LNZERO.EQ.1
    END(LINENUM)
}
```

You can of course also edit these two numbers by hand.

---

## 16. Limits

| Item | Limit | On overflow |
|---|---|---|
| Source file size | 32 000 bytes | the rest is silently ignored |
| Tokens | 3 000 | excess tokens are silently dropped |
| Variables | 64 (includes `VERSION` and the `SYS*` set) | `TOO MANY VARIABLES` |
| Labels | 64 | `TOO MANY LABELS` |
| Blocks | 32 | `TOO MANY BLOCKS` |
| Block/CALL nesting depth | 12 | `BLOCK NESTING TOO DEEP` |
| String literal length | 250 | longer literals are cut |
| String value (variable, expression, capture) | 95 characters | silently cut |
| Identifier significance | 15 characters | extra characters ignored |
| Statements per run | 200 000 | `LOOP LIMIT EXCEEDED` |
| Input line | 255 characters, further limited by the format width | cut |

The two **silent** limits (source size, token count) are the usual reason that a
big script "stops working at the end"; run `plxcfg check` after adding material.
Every string, comma, bracket and name is one token, so a banner line such as
`"text",'\n'` costs 3 tokens; roughly 900 banner lines fit in 3 000 tokens.

---

## 17. Error messages

Every error has the form `PLX ERROR LINE n: MESSAGE - detail`, where `n` is the
source line (0 if unknown).

### Load-time

| Message | Cause |
|---|---|
| `CANNOT OPEN file` | file missing or unreadable |
| `OUT OF MEMORY` | allocation failure |
| `UNTERMINATED STRING` | closing quote missing before end of line |
| `BAD DOTTED OPERATOR` | `.XYZ.` that is not one of the nine operators |
| `UNEXPECTED CHARACTER 'c'` | character outside the language |
| `UNMATCHED }` / `MISSING }` | unbalanced braces |
| `DUPLICATE LABEL` / `TOO MANY LABELS` | label problems |
| `DUPLICATE BLOCK` / `TOO MANY BLOCKS` | block problems |

### Run-time

| Message | Cause |
|---|---|
| `UNDEFINED VARIABLE name` | variable read before it was assigned |
| `TOO MANY VARIABLES` | 64-variable limit |
| `EXPRESSION EXPECTED` | missing operand, e.g. `X = ` or `IF ( )` |
| `MISSING )` / `( EXPECTED AFTER IF` / `) EXPECTED` | parenthesis problems |
| `DIVIDE BY ZERO` | `/` by zero |
| `BAD FORMAT x` | unknown format letter or a malformed format |
| `MISSING ]` / `UNEXPECTED TOKEN IN LIST` | prompt or capture list problem |
| `VARIABLE NAME EXPECTED` / `= OR .EQ. EXPECTED AFTER x` | malformed assignment |
| `UNDEFINED LABEL x` / `LABEL EXPECTED AFTER GOTO` | jump problems |
| `BLOCK NAME EXPECTED AFTER CALL` / `UNDEFINED BLOCK x` | CALL problems |
| `BLOCK NESTING TOO DEEP` | CALL recursion deeper than 12 |
| `SYNTAX ERROR AT x` | statement not recognised |
| `LOOP LIMIT EXCEEDED` | more than 200 000 statements in one run |

---

## 18. Pitfalls and rules of thumb

1. **Output items are not expressions.** `"X=",X+1` is an error; assign
   `Y = X + 1` and print `Y`.
2. **`+` concatenates when either side is text.** `"5"+1` is `"51"`. Use
   `ASSIGN INT` or `-` to force numbers.
3. **`ASSIGN X.EQ.5`** assigns; **`IF (X .EQ. 5)`** compares. Context decides.
4. **Strings compare case-sensitively;** `A`-format input is already upper case.
5. **A label is only a label at the start of a statement.** `A*B*C` is arithmetic.
6. **Always assign before use.** Put declarations in a `VAR(...)` block.
7. **`HALT` ends ACPX.** Use it for failed logins only; to leave a block use a
   label jump.
8. **Don't name variables like formats** (`I4`, `A10`, `S2`); they would be read
   as bare formats if not defined and are confusing even when defined.
9. **A trailing comma does not continue a line;** use `&`.
10. **Keep `BANNER` self-contained.** When you provide one, ACPX prints no other
    startup text.
11. **Test with `plxcfg check` then `plxcfg run`** before pointing ACPX at a new
    script; ACPX itself falls back to the built-in banner on any error, which
    can hide a typo if you don't read the first line of output.
12. **Hidden input prints one `X` per typed character** after RETURN; the typed
    characters themselves never appear. Use `H` for passwords, not `A` or `S`.

---

## 19. Formal grammar

Informal EBNF. Keywords and identifiers are case-insensitive; `NL` is end of
line (after `&` joining); `[ x ]` optional, `{ x }` repetition, `|` choice.

```
program      ::= { NL | statement | block }

block        ::= blockhead NL* "{" { statement | NL } "}"
blockhead    ::= "VAR" "(" ident ")"
               | "SUB" ident
               | ident                          (* BANNER runs inline, others are callable *)

statement    ::= label
               | "{" { statement | NL } "}"
               | assignment
               | if
               | jump
               | "CALL" ident
               | ("HALT" | "EXIT") [ itemlist ]
               | "PAUSE" [ itemlist ]
               | "DELAY" expr
               | "BEEP"
               | "END" "(" ident ")"
               | ident "<" "END" ">"
               | itemlist

label        ::= "*" ident "*"
jump         ::= ("GOTO" | "PROCEED" | "RET") [ label ]

assignment   ::= [ "ASSIGN" ] [ "INT" | "STR" | "STRING" ] ident ( "=" | ".EQ." )
                 ( expr | "[" itemlist "]" )

if           ::= "IF" "(" expr ")" [ "THEN" ] statement
                 [ NL* "ELSE" statement ]

itemlist     ::= item { [ "," ] item }
item         ::= string | number | ident
               | ident ":" format
               | ident "=" "[" itemlist "]"
               | "[" itemlist "]"
               | bareformat
format       ::= [ number ] letter [ digits ]   (* letter: A S I Z H, written as one word with the digits *)

expr         ::= and { ".OR." and }
and          ::= not { ".AND." not }
not          ::= ".NOT." not | cmp
cmp          ::= sum [ relop sum ]
relop        ::= "==" | "=" | "<>" | "!=" | "<" | ">" | "<=" | ">="
               | ".EQ." | ".NE." | ".LT." | ".GT." | ".LE." | ".GE."
sum          ::= term { ("+" | "-") term }
term         ::= primary { ("*" | "/") primary }
primary      ::= number | string | ident | "(" expr ")" | "-" primary

number       ::= digits | "$" hexdigits
string       ::= '"' chars '"' | "'" chars "'"
ident        ::= (letter | "_") { letter | digit | "_" }
comment      ::= "/*" ... "*/" | "//" ... NL
```

---

## 20. Complete examples

### 20.1 The stock `ACP.PLX`

```
VAR(DECLARATION)
{
    ASSIGN ACT.EQ.'LSI01'
    ASSIGN ACTPW.EQ.'21121'
    ASSIGN MON.EQ.SYSMON
    ASSIGN INT DAY.EQ.SYSDAY
    ASSIGN INT YEAR.EQ.SYSYEAR
    ASSIGN INT USRNO.EQ.4100
    ASSIGN INT PORTNO.EQ.7
    ASSIGN INT TRIES.EQ.0
    ASSIGN INT MAXTRY.EQ.3
    ASSIGN INT SKIPHDR.EQ.0
    END(DECLARATION)
}

'\n'
*PROMPT1*["ACCOUNT-ID: ",AID:5A1],'\n'
 IF(AID == ACT) THEN PROCEED *PROMPT2*
 TRIES = TRIES + 1
 IF(TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
 "INVALID ACCOUNT-ID",'\n'
 RET *PROMPT1*

*PROMPT2*["PASSWORD: ",PAS:5H1],"  ",DATE=[MON,"/",DAY,"/",YEAR],'\n'
 IF(PAS == ACTPW) THEN PROCEED *WELCOME*
 TRIES = TRIES + 1
 IF(TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
 "INVALID PASSWORD",'\n'
 RET *PROMPT1*

*WELCOME*
BANNER
{
    "       GOOD DAY USER ",I4,"  PORT ",I1,'\n'
&   "           WELCOME TO THE WONDERFUL WORLD OF 'MICOS'",'\n'
&   "*************************************************************",'\n'
&   "BELIEVE NOTHING YOU HEAR, AND ONLY ONE HALF THAT YOU SEE",'\n'
&   "*************************************************************",'\n'
&   "##",'\n'
&   "RUN'ACP'",'\n'
&   "(ADM-ACP / ASSEDIT, MOTOROLA 6800 ASM)  V",VERSION,'\n'
&   "=============================================================",'\n'
&   'ENTER "BYE" AT THE ACP PROMPT TO DISCONNECT.','\n'
    BANNER<END>
}

MENUHDR
{
    '\n',"'ACP' AT YOUR SERVICE - CHOOSE YOUR OPTION.",'\n'
&   "=============================================================",'\n'
}

GOODBYE
{
    "##",'\n',"SIGNED OFF.",'\n'
}
```

Walk-through: `VAR(DECLARATION)` runs first and defines the account data. The
main flow prints a blank line, then enters `*PROMPT1*`, which reads up to five
characters into `AID` (upper-cased) and jumps on if they match. `PROMPT2` reads
the password hidden, prints `XXXXX`, the date (captured into `DATE`) and
a newline. `BANNER` then prints the welcome text. `MENUHDR` and `GOODBYE` are
skipped in the main flow and used later by ACPX.

### 20.2 Boxed banner with expanded fields

```
BANNER
{
    "+----------------------------------------+",'\n'
    "|  GOOD DAY, USER ",USRNO:I4,"  ",SYSDATE,"  |",'\n'
    "+----------------------------------------+",'\n'
}
```

### 20.3 Subroutines, a counter and a menu choice

```
VAR(INIT)
{
    ASSIGN INT N.EQ.3
}

SUB RULE
{
    "--------------------",'\n'
}

BANNER
{
    CALL RULE
    "  COUNTING DOWN",'\n'
    CALL RULE
    *AGAIN*
    "  ",N:Z2,'\n'
    N = N - 1
    IF (N > 0) GOTO *AGAIN*
    ["CONTINUE? (Y/N) ",ANS:A1]
    IF (ANS == "N") THEN HALT "BYE",'\n'
}
```

### 20.4 ANSI colour and screen control

```
BANNER
{
    "\e[2J\e[H"
    "\e[1;32m*** ACP ONLINE ***\e[0m",'\n'
}
```

### 20.5 Computing text with `+` and `.AND.`

```
VAR(D)
{
    ASSIGN INT V.EQ.15
    ASSIGN LBL.EQ."VALUE "
}
BANNER
{
    T = LBL + V + " UNITS"       /* "VALUE 15 UNITS" */
    T,'\n'
    IF (V > 10 .AND. V < 20) "IN RANGE",'\n'
}
```

---

## 21. Building the interpreter and tools

The project is **strict ANSI C89**, one translation unit per program
(`acpx.c` and `plxcfg.c` both `#include "plx.c"`), so keep the three sources in
one directory.

| Platform | Command |
|---|---|
| Linux / macOS | `cc -ansi -pedantic -O2 -o acpx acpx.c`  and  `cc -ansi -pedantic -O2 -o plxcfg plxcfg.c` |
| Windows, MinGW-w64 | `gcc -O2 -o acpx.exe acpx.c`  and  `gcc -O2 -o plxcfg.exe plxcfg.c` |
| Windows, MSVC | `cl /nologo /O2 acpx.c`  and  `cl /nologo /O2 plxcfg.c` |
| DOS, Turbo C / C++ | `tcc -ml acpx.c`  and  `tcc -ml plxcfg.c` |

Turbo C notes: use the **large** (`-ml`) or **compact** (`-mc`) memory model;
the small and medium models build but produce no output at run time because
the interpreter's token and string tables need far data. ACPX sets its stack
size (`_stklen`) itself.

Embedding: the public C API of `plx.c` is

```c
int          plx_load(const char *path);     /* PLX_OK or PLX_ERR              */
int          plx_run(void);                  /* PLX_OK, PLX_HALT or PLX_ERR    */
int          plx_call(const char *block);    /* run one named block            */
int          plx_has(const char *block);     /* does the block exist?          */
int          plx_check(FILE *out);           /* static report, returns #problems */
void         plx_setint(const char *name, long value);
void         plx_setstr(const char *name, const char *value);
long         plx_getint(const char *name);
const char  *plx_error(void);                /* last error text                */
void         plx_free(void);
void         plx_console_init(void);         /* Windows: enable ANSI escapes   */
extern int   plx_banner_ran;                 /* did a BANNER block execute?    */
```

Set host variables with `plx_setint` / `plx_setstr` *after* `plx_load` and
*before* `plx_run`.

---

## 22. Portability notes

* **Line endings:** CRLF, LF and CR-LF mixtures are accepted in scripts.
* **Hidden input:** Unix uses termios, Windows uses `_getch`, Turbo C uses
  `getch`. When input is redirected the password is read like any other line.
* **ANSI escapes:** enabled automatically on Windows 10+ consoles. Under plain
  DOS use ANSI.SYS, or avoid `\e` in the script.
* **`DELAY`:** based on `clock()`; resolution is the C library's (18 ticks/s on
  Turbo C).
* **Dates:** from the local clock at load time.
* **Character set:** bytes are passed through unchanged, so code-page or box
  drawing characters can be included with `\xHH` escapes (for example
  `"\xC9\xCD\xBB"` for a DOS box corner set).

---

## 23. Revision history

| Version | Notes |
|---|---|
| PL/X draft 1 | The original sketch: `ASSIGN .EQ.`, `[ ]` prompt lists, `*LABEL*`, `PROCEED`, `RET`, `BANNER`, `&` continuation, `END(NAME)` / `NAME<END>`. All draft 1 scripts run unchanged. |
| PL/X draft 2 (ACPX 1.5) | Added `NAME = expr`, `IF` / `ELSE`, `CALL`, `SUB`, `VAR(...)` blocks, `MENUHDR` / `GOODBYE` hooks, hidden input (`H`), `NAME:fmt` output, `HALT` / `EXIT` / `DELAY` / `BEEP` / `PAUSE`, hexadecimal numbers, string escapes (`\e` for ADM-31 sequences), comments, system date/time/version variables, password checking with attempt counting, editor line-number settings (`LNWIDTH`, `LNZERO`), the `PLXCFG` tool and a Windows / DOS / Unix portable interpreter. |

---

*PL/X language © Mickey W. Lawless. Documentation covers ACPX 1.5.*
