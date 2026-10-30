* ======================================================================
* D07ORG.ASM - ORG, GAPS, THE ENTRY ADDRESS AND THE OUTPUT FILES
*
*  - ORG sets the address of what follows; it may be used many times.
*  - The FIRST ORG (or the first instruction when there is no ORG) is the
*    program's origin. It becomes
*        the S9 start address in NAME.S19  (END's operand is NOT used), and
*        the base of NAME.BIN: the file starts at the lowest address that
*        holds code and ends at the highest, gaps between are zero bytes.
*  - The binary window is 32 KB above the first ORG, so put the LOWEST
*    ORG first. (RAM equates with EQU, not with ORG + RMB at $0000.)
*
* EXPECT E000: 01 39
* EXPECT E010: 01 02 03
* EXPECT FFFE: E0 00
* EXPECT-S9 E000
* EXPECT-BIN E000 8192
* ======================================================================
        ORG   $E000
RESET   NOP
        RTS
        ORG   $E010
TAB     FCB   1,2,3
        ORG   $FFFE
        FDB   RESET             ; the 6800 reset vector
        END   TAB               ; the operand is accepted but ignored
