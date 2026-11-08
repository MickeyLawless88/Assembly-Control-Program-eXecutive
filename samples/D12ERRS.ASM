* ======================================================================
* D12ERRS.ASM - EVERY ERROR ACPX CAN REPORT  (this file fails on purpose)
*
* Each line below triggers exactly one message. Assemble it and compare with
* the EXPECT-ERR lines. Errors are listed as
*      *** ERROR (LINE n): MESSAGE - detail
* and the line is skipped (no code), so the following addresses shift.
*
* EXPECT-ERR 22 LABEL ALREADY EXISTS - DUP
* EXPECT-ERR 23 INSTRUCTION NOT FOUND - FOO
* EXPECT-ERR 24 OPERAND MISSING IN SOURCE STATEMENT - LDAA
* EXPECT-ERR 25 OPERAND NOT FOUND - NOSUCH
* EXPECT-ERR 26 VALUE OUT OF BOUNDS - 256
* EXPECT-ERR 27 VALUE OUT OF BOUNDS - -1
* EXPECT-ERR 28 ILLEGAL ADDRESSING MODE - STAA
* EXPECT-ERR 29 ILLEGAL ADDRESSING MODE - JMP
* EXPECT-ERR 30 BRANCH OUT OF RANGE - FAR
* EXPECT-ERRCOUNT 9
* ======================================================================
        ORG   $0800
DUP     NOP
DUP     NOP
        FOO
        LDAA
        LDAA  NOSUCH
        LDAA  #256
        LDAA  #-1
        STAA  #1
        JMP   #5
        BRA   FAR
        RMB   200
FAR     NOP
        END
