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
