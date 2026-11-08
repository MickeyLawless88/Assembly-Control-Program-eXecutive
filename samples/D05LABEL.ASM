* ======================================================================
* D05LABEL.ASM - HOW LABELS ARE WRITTEN
*
*  - A label starts in COLUMN 1. Anything that starts in column 1 and is
*    not a '*' or ';' comment is a label - even if it spells a mnemonic!
*  - A trailing ':' is allowed:  START:
*  - Letters, digits, '_' and '.' are allowed (not as the first character).
*  - Case does not matter (everything is upper-cased).
*  - A label is at most 15 characters. Longer names are NOT shortened: the
*    tail is read as the mnemonic (INSTRUCTION NOT FOUND). Keep names <= 15.
*  - A label may stand alone on a line (nothing after it, not even a
*    comment); it then takes the next address.
*  - Labels are global: a name used twice is "LABEL ALREADY EXISTS".
*
* EXPECT 0500: 01 01 01 01 7E 05 00 7E 05 01 7E 05 02 7E 05 03 01 7E 05 10
* EXPECT 0514: 01
* ======================================================================
        ORG   $0500
START:  NOP                     ; colon form                    0500
lower   NOP                     ; lower case = LOWER            0501
My_Lab.1 NOP                    ; underscore and dot            0502
LONGEST_NAME_15 NOP             ; exactly 15 characters         0503
        JMP   START             ; 7E 05 00
        JMP   LOWER             ; case-insensitive
        JMP   my_lab.1
        JMP   LONGEST_NAME_15
ALONE
        NOP                     ; 01 at 0510
        JMP   ALONE             ; 7E 05 10
*
* TRAP: a mnemonic written in column 1 is read as a LABEL, not an
* instruction. The next line emits the only byte; "RTS" below is just a name.
RTS
        NOP                     ; 01 at 0514
        END
