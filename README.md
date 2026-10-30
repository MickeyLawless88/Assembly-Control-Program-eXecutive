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

Version `1.6` is shown in the banner (`V1.6`).

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
(ADM-ACP / ASSEDIT, MOTOROLA 6800 ASM)  V1.6
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
| `END [expr]` | | End of source; any operand is accepted but ignored; the S9 start address is the first `ORG` |

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
| `NAME.S19` | Motorola **S-records**: `S1` data records (up to 16 bytes each), `S9` end record whose start address is the first `ORG` (the `END` operand is ignored) |
| `NAME.BIN` | Raw binary of the assembled range, from the first `ORG` (put the lowest `ORG` first; the window is 32 KB) to the highest address emitted; gaps are zero-filled. The bytes are an exact image, so with `ORG $E000` the file's first byte is the byte for $E000. Optionally padded with `FF` |

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
| `OPERAND NOT FOUND - xxx` | undefined symbol or bad expression |
| `VALUE OUT OF BOUNDS - xxx` | an 8-bit operand larger than 255 (or negative: write `#$FF`, not `#-1`) |
| `ILLEGAL ADDRESSING MODE - xxx` | the instruction has no such mode (for example `STAA #1`, `JMP #5`) |
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
| Object bytes from one source line | 130 |
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
