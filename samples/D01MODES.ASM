* ======================================================================
* D01MODES.ASM - THE FIVE 6800 ADDRESSING MODES AND HOW ACPX PICKS ONE
*
* Source layout rule: a LABEL starts in column 1; the MNEMONIC must be
* indented (at least one blank); the OPERAND follows after blanks.
*
*   inherent   INCA            no operand
*   immediate  LDAA #$41       '#' = the value itself
*   direct     LDAA $20        address $00-$FF (2 bytes: faster, shorter)
*   extended   LDAA $1234      any 16-bit address (3 bytes)
*   indexed    LDAA 5,X        offset (0-255) + index register X
*
* acpx chooses DIRECT whenever the operand is already known in pass 1 and
* is <= $FF; otherwise EXTENDED. A forward reference is therefore always
* extended (see D14DIRECT).  JMP/JSR have no direct form: always extended.
*
* EXPECT 0100: 4C 86 41 96 20 B6 12 34 A6 05 A6 00 A6 00 B6 01 11 39
* ======================================================================
        ORG   $0100
        INCA                    inherent            4C
        LDAA  #$41              immediate           86 41
        LDAA  $20               direct              96 20
        LDAA  $1234             extended            B6 12 34
        LDAA  5,X               indexed             A6 05
        LDAA  0,X               indexed, offset 0   A6 00
        LDAA  ,X                same, offset omitted  A6 00
        LDAA  FWD               forward reference   B6 01 11
FWD     RTS                     (FWD = $0111)       39
        END
