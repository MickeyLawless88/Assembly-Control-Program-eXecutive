* ======================================================================
* D14DIRCT.ASM - ZERO-PAGE (DIRECT) ADDRESSING IS AUTOMATIC - IF YOU ALLOW IT
*
* acpx assembles a memory operand as DIRECT (2 bytes, faster) when, during
* pass 1, the value is already known and is <= $FF. So:
*   - define zero-page variables with EQU BEFORE the code that uses them;
*   - a name defined AFTER its first use is assembled as EXTENDED (3 bytes);
*   - ASL/ASR/LSR/ROL/ROR/COM/NEG/INC/DEC/TST/CLR have no direct form
*     on the 6800 at all (only indexed and extended), likewise JMP and JSR.
*
* EXPECT 0E00: 97 30 B7 00 31 96 31 78 00 30 7E 00 30 97 30 B6 01 00
* ======================================================================
ZPV     EQU   $30
        ORG   $0E00
        STAA  ZPV               ; known, <= $FF     -> direct    97 30
        STAA  LATE              ; defined below     -> extended  B7 00 31
        LDAA  ZPV+1             ; $31, known        -> direct    96 31
        ASL   ZPV               ; no direct form    -> extended  78 00 30
        JMP   ZPV               ; JMP is never direct            7E 00 30
        STAA  $0030             ; leading zeros do not matter    97 30
        LDAA  $0100             ; > $FF             -> extended  B6 01 00
LATE    EQU   $31
        END
