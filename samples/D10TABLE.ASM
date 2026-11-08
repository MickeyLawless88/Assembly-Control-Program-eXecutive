* ======================================================================
* D10TABLE.ASM - LOOKUP TABLES, POINTER TABLES, JUMP TABLES   (self-checking)
*
* Principle: the 6800 has no "table[i]" instruction and no ABX. To index a
* table you add the index to X yourself (INX in a loop, or 16-bit add in
* memory). A table of ADDRESSES (FDB label,label,...) gives you string tables
* and jump tables: "LDX 0,X" loads the address, "JSR 0,X" calls it.
* EXPECT-OK 2
* EXPECT-OUT ABC
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
IDX     EQU   $20
*
MAIN    LDX   #HDR
        JSR   PRSTR
*
* 1. byte table: squares[7] = 49 = $31
        LDX   #T1
        JSR   PRSTR
        LDAB  #7
        LDX   #SQUARES
        BSR   ADDX              X = X + B
        LDAA  0,X
        CMPA  #49
        JSR   RESULT
*
* 2. pointer table: print three strings picked by index 0,1,2
        LDX   #T2
        JSR   PRSTR
        CLR   IDX
S1      LDX   #STRTAB
        LDAB  IDX
        ASLB                    each pointer is 2 bytes
        BSR   ADDX
        LDX   0,X               X = the pointer stored in the table
        JSR   PRSTR
        LDAA  #SPACE
        JSR   PUTC
        INC   IDX
        LDAA  IDX
        CMPA  #3
        BNE   S1
        LDX   #CRLFS
        JSR   PRSTR
*
* 3. jump table: call routine number 0,1,2 -> prints A, B, C
        LDX   #T3
        JSR   PRSTR
        CLR   IDX
J1      LDX   #JTAB
        LDAB  IDX
        ASLB
        BSR   ADDX
        LDX   0,X               X = routine address
        JSR   0,X               call it
        INC   IDX
        LDAA  IDX
        CMPA  #3
        BNE   J1
        LDX   #CRLFS
        JSR   PRSTR
        LDX   #T4
        JSR   PRSTR
        LDAA  #1                (the three OK lines above are 1, 2, 3 -
        CMPA  #1                 this last line only proves we got here)
        JSR   RESULT
        WAI
*
* ADDX: X = X + B  (unsigned 8-bit index). Clobbers nothing else.
ADDX    TSTB
        BEQ   ADDX9
ADDX1   INX
        DECB
        BNE   ADDX1
ADDX9   RTS
*
ROUTA   LDAA  #'A
        JMP   PUTC
ROUTB   LDAA  #'B
        JMP   PUTC
ROUTC   LDAA  #'C
        JMP   PUTC
*
SQUARES FCB   0,1,4,9,16,25,36,49,64,81
STRTAB  FDB   S0,S1T,S2
JTAB    FDB   ROUTA,ROUTB,ROUTC
S0      FCB   "ZERO",0
S1T     FCB   "ONE",0
S2      FCB   "TWO",0
CRLFS   FCB   CR,LF,0
HDR     FCB   "D10TABLE",CR,LF,0
T1      FCB   " BYTE TABLE ........ ",0
T2      FCB   " POINTER TABLE ..... ",0
T3      FCB   " JUMP TABLE ........ ",0
T4      FCB   " ALL DONE .......... ",0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
