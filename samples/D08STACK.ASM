* ======================================================================
* D08STACK.ASM - THE STACK, JSR/RTS, BSR, PSHA/PULA, TSX      (self-checking)
*
* Principle: the 6800 stack grows DOWN, SP points at the next FREE byte.
* JSR pushes the return address (low byte first), PSHA stores at SP then
* decrements. TSX copies SP+1 into X, so after TSX, 0,X is the top byte.
* Run:  python sim6800.py D08STACK.S19        Every line must say OK.
* EXPECT-OK 5
* ======================================================================
*
* ---- hardware + minimal console kernel (MC6850 ACIA) ----
ACIAS   EQU   $8008             ACIA status / control
ACIAD   EQU   $8009             ACIA data
TDRE    EQU   $02
CR      EQU   $0D
LF      EQU   $0A
SPACE   EQU   $20
*
        ORG   $E000
RESET   LDS   #$01FF
        LDAA  #$03              ACIA master reset
        STAA  ACIAS
        LDAA  #$15              /16, 8N1
        STAA  ACIAS
        JMP   MAIN
PUTC    PSHA
PUTC1   LDAA  ACIAS
        ANDA  #TDRE
        BEQ   PUTC1
        PULA
        STAA  ACIAD
        RTS
PRSTR   LDAA  0,X
        BEQ   PRSTR9
        JSR   PUTC
        INX
        BRA   PRSTR
PRSTR9  RTS
PRHEX   PSHA
        LSRA
        LSRA
        LSRA
        LSRA
        BSR   PRNIB
        PULA
        ANDA  #$0F
PRNIB   ADDA  #$90
        DAA
        ADCA  #$40
        DAA
        JMP   PUTC
* RESULT: call right after a compare. Z=1 (equal) prints OK, else FAIL.
RESULT  BNE   RFAIL
        LDX   #OKM
        JSR   PRSTR
        RTS
RFAIL   LDX   #FAILM
        JSR   PRSTR
        RTS
OKM     FCB   "OK",CR,LF,0
FAILM   FCB   "FAIL",CR,LF,0
NULLINT RTI
SP1     EQU   $20               saved stack pointers (zero page)
SP2     EQU   $22
*
MAIN    LDX   #HDR
        JSR   PRSTR
*
* 1. three nested subroutine calls, each adds one
        LDX   #T1
        JSR   PRSTR
        CLRA
        JSR   LEVEL1
        CMPA  #3
        JSR   RESULT
*
* 2. PSHA/PULA is last-in first-out
        LDX   #T2
        JSR   PRSTR
        LDAA  #1
        PSHA
        LDAA  #2
        PSHA
        LDAA  #3
        PSHA
        PULA                    3
        PULB                    2
        ABA                     5
        PULB                    1
        ABA                     6
        CMPA  #6
        JSR   RESULT
*
* 3. each PSHA moves SP down by exactly one byte
        LDX   #T3
        JSR   PRSTR
        TSX
        STX   SP1
        PSHA
        PSHA
        TSX
        STX   SP2
        PULA
        PULA
        LDAA  SP1+1
        SUBA  SP2+1
        CMPA  #2
        JSR   RESULT
*
* 4. peek at the top of the stack: after TSX, 0,X is the last byte pushed
        LDX   #T4
        JSR   PRSTR
        LDAA  #$5A
        PSHA
        TSX
        LDAA  0,X
        PULB
        CMPA  #$5A
        JSR   RESULT
*
* 5. BSR is a short-range JSR (relative, 2 bytes)
        LDX   #T5
        JSR   PRSTR
        CLRA
        BSR   ADD7
        BSR   ADD7
        CMPA  #14
        JSR   RESULT
        WAI
*
LEVEL1  INCA
        JSR   LEVEL2
        RTS
LEVEL2  INCA
        JSR   LEVEL3
        RTS
LEVEL3  INCA
        RTS
ADD7    ADDA  #7
        RTS
*
HDR     FCB   "D08STACK",CR,LF,0
T1      FCB   " NESTED JSR ........ ",0
T2      FCB   " PSHA/PULA LIFO .... ",0
T3      FCB   " SP MOVES BY 1 ..... ",0
T4      FCB   " TSX -> TOP BYTE ... ",0
T5      FCB   " BSR ............... ",0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
