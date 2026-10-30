* ======================================================================
* CALC.ASM - 16-BIT INTEGER CALCULATOR                   (acpx 6800 sample)
*
* Type   12+30   900-1   250*4   1000/7   1000%7   A*2   H   Q
* A means "the previous answer". Unsigned 16-bit arithmetic: overflow and
* divide-by-zero are reported, a negative difference is printed with '-'.
* Shows: multi-byte add/sub with carry, shift-and-add multiply, restoring
* divide, ASL/ROL on memory, operator dispatch, and the decimal I/O kernel.
* ======================================================================
*
* ---- HARDWARE: MC6850 ACIA console (change these 2 lines for your board) ----
ACIAS   EQU   $8008             ACIA status (read) / control (write)
ACIAD   EQU   $8009             ACIA data
RDRF    EQU   $01               status bit: receive data ready
TDRE    EQU   $02               status bit: transmit register empty
*
* ---- ZERO PAGE: EQUs are defined BEFORE use so acpx picks direct addressing
SEED    EQU   $00               16-bit PRNG state (also the key-wait counter)
NUM     EQU   $02               16-bit working number
TMP     EQU   $04               16-bit scratch
LEAD    EQU   $06               leading-zero flag for PRDEC
DIGIT   EQU   $07               one decimal digit
LINLEN  EQU   $08               length of the line in BUF
NDIG    EQU   $09               digits seen by PARSE
USER    EQU   $10               first byte free for the program
BUF     EQU   $0200             line buffer (RAM, extended addressing)
MAXLEN  EQU   12                longest line GETLINE accepts
SPACE   EQU   $20
CR      EQU   $0D
LF      EQU   $0A
BS      EQU   $08
A1      EQU   USER              first operand (2 bytes)
A2      EQU   USER+2           second operand (2 bytes)
RES     EQU   USER+4           result (2 bytes)
REM     EQU   USER+6           remainder (2 bytes)
LAST    EQU   USER+8           previous answer (2 bytes)
OPER    EQU   USER+10          operator character
CNT     EQU   USER+11          loop counter
XCARRY  EQU   USER+12          17th bit of the divide remainder
NEG     EQU   USER+13          1 = print a minus sign
*
        ORG   $E000
*
* ======================== KERNEL (identical in every sample) ================
* PUTC    A = char to send.             preserves A,B,X
* GETC    waits for a key -> A.         no echo; counts polls into SEED
* CRLF    sends CR LF.                  clobbers A
* PRSTR   X -> zero-terminated string.  clobbers A,X
* GETLINE reads+echoes a line into BUF (upper-cased, BS works). B=length
* PARSE   X -> digits : NUM = value, X -> first non-digit, C=1 if bad
* PRDEC   prints NUM as unsigned decimal.  clobbers A,X,TMP
* PRHEX   prints A as two hex digits.      clobbers A
* RAND    A = next pseudo-random byte.      clobbers B
* RANDN   B = n (1..255): A = random 0..n-1.  clobbers B
*
RESET   LDS   #$01FF            stack at top of page 1
        SEI
        LDAA  #$03              ACIA master reset
        STAA  ACIAS
        LDAA  #$15              divide by 16, 8 data bits, no parity, 1 stop
        STAA  ACIAS
        LDAA  #$AC              seed must never be zero
        STAA  SEED
        LDAA  #$E1
        STAA  SEED+1
        JMP   MAIN
*
PUTC    PSHA
PUTC1   LDAA  ACIAS
        ANDA  #TDRE
        BEQ   PUTC1
        PULA
        STAA  ACIAD
        RTS
*
GETC    INC   SEED+1            free-running counter: the wait time
        BNE   GETC2             seeds the random number generator
        INC   SEED
GETC2   LDAA  ACIAS
        ANDA  #RDRF
        BEQ   GETC
        LDAA  ACIAD
        RTS
*
CRLF    LDAA  #CR
        JSR   PUTC
        LDAA  #LF
        JSR   PUTC
        RTS
*
PRSTR   LDAA  0,X
        BEQ   PRSTR9
        JSR   PUTC
        INX
        BRA   PRSTR
PRSTR9  RTS
*
GETLINE LDX   #BUF
        CLRB
GL1     JSR   GETC
        CMPA  #CR
        BEQ   GL9
        CMPA  #BS
        BEQ   GLBS
        CMPA  #$7F
        BEQ   GLBS
        CMPA  #SPACE
        BCS   GL1               ignore other control keys
        CMPA  #'a
        BCS   GL2
        CMPA  #'z
        BHI   GL2
        SUBA  #$20              force upper case
GL2     CMPB  #MAXLEN
        BCC   GL1               line full
        JSR   PUTC
        STAA  0,X
        INX
        INCB
        BRA   GL1
GLBS    TSTB
        BEQ   GL1
        DEX
        DECB
        LDAA  #BS
        JSR   PUTC
        LDAA  #SPACE
        JSR   PUTC
        LDAA  #BS
        JSR   PUTC
        BRA   GL1
GL9     CLR   0,X
        STAB  LINLEN
        JSR   CRLF
        RTS
*
PARSE   CLR   NUM
        CLR   NUM+1
        CLR   NDIG
PA1     LDAA  0,X
        SUBA  #'0
        BCS   PA9
        CMPA  #9
        BHI   PA9
        STAA  DIGIT
        JSR   MUL10
        BCS   PABAD
        LDAA  NUM+1
        ADDA  DIGIT
        STAA  NUM+1
        LDAA  NUM
        ADCA  #0
        STAA  NUM
        BCS   PABAD
        INC   NDIG
        INX
        BRA   PA1
PA9     TST   NDIG
        BEQ   PABAD
        CLC
        RTS
PABAD   SEC
        RTS
*
MUL10   LDAA  NUM               NUM = NUM * 10, C=1 on overflow
        LDAB  NUM+1
        ASLB
        ROLA
        BCS   M10BAD
        STAA  TMP
        STAB  TMP+1             TMP = NUM*2
        ASLB
        ROLA
        BCS   M10BAD
        ASLB
        ROLA
        BCS   M10BAD            A:B = NUM*8
        ADDB  TMP+1
        ADCA  TMP
        BCS   M10BAD
        STAA  NUM
        STAB  NUM+1
        CLC
        RTS
M10BAD  SEC
        RTS
*
PRDEC   LDX   #PWRS
        CLR   LEAD
PRD1    CLR   DIGIT
PRD2    LDAA  NUM+1             TMP = NUM - 0,X (16 bit)
        SUBA  1,X
        STAA  TMP+1
        LDAA  NUM
        SBCA  0,X
        STAA  TMP
        BCS   PRD3              went negative: digit finished
        STAA  NUM
        LDAA  TMP+1
        STAA  NUM+1
        INC   DIGIT
        BRA   PRD2
PRD3    LDAA  DIGIT
        BNE   PRD4
        TST   LEAD
        BNE   PRD4
        CPX   #PWRS+8
        BNE   PRD5              suppress leading zeros (never the last digit)
PRD4    ADDA  #'0
        JSR   PUTC
        LDAA  #1
        STAA  LEAD
PRD5    INX
        INX
        CPX   #PWRS+10
        BNE   PRD1
        RTS
PWRS    FDB   10000,1000,100,10,1
*
PRHEX   PSHA
        LSRA
        LSRA
        LSRA
        LSRA
        BSR   PRNIB
        PULA
        ANDA  #$0F
PRNIB   ADDA  #$90              the classic 6800 nibble-to-ASCII trick:
        DAA                     ADD $90, DAA, ADC $40, DAA
        ADCA  #$40
        DAA
        JMP   PUTC
*
RAND    LDAA  SEED              16-bit Galois LFSR, taps $B400
        ORAA  SEED+1
        BNE   RAND1
        LDAA  #$AC              recover from an all-zero state
        STAA  SEED
        LDAA  #$E1
        STAA  SEED+1
RAND1   LDAA  SEED
        LDAB  SEED+1
        LSRA
        RORB
        BCC   RAND2
        EORA  #$B4
RAND2   STAA  SEED
        STAB  SEED+1
        TBA
        RTS
*
RANDN   STAB  TMP               n
        JSR   RAND
        LDAB  TMP
RN1     CBA
        BCS   RN2               A < n : done
        SBA
        BRA   RN1
RN2     RTS
*
NULLINT RTI
*
MAIN    LDX   #BANNER
        JSR   PRSTR
        CLR   LAST
        CLR   LAST+1
NEXT    LDX   #PROMPT
        JSR   PRSTR
        JSR   GETLINE
        LDAA  LINLEN
        BEQ   NEXT              empty line: ask again
        LDAA  BUF
        CMPA  #'Q
        BEQ   GOQUIT
        CMPA  #'H
        BEQ   GOHELP
        LDX   #BUF
        JSR   ARG               first operand
        BCS   SYNTAX
        LDAA  NUM
        STAA  A1
        LDAA  NUM+1
        STAA  A1+1
        LDAA  0,X               the operator
        STAA  OPER
        BEQ   SYNTAX            nothing after the number
        INX
        JSR   ARG               second operand
        BCS   SYNTAX
        LDAA  0,X
        BNE   SYNTAX            junk at the end
        LDAA  NUM
        STAA  A2
        LDAA  NUM+1
        STAA  A2+1
        CLR   NEG
*
        LDAA  OPER              ---- dispatch on the operator
        CMPA  #'+
        BEQ   DOADD
        CMPA  #'-
        BEQ   DOSUB
        CMPA  #'*
        BEQ   DOMUL
        CMPA  #'/
        BEQ   DODIV
        CMPA  #'%
        BEQ   GOMOD
SYNTAX  LDX   #SYNMSG
        JSR   PRSTR
        BRA   NEXT
* Relative branches reach only -128..+127 bytes. A target that is too far
* away needs a "trampoline": branch to a nearby JMP, which can go anywhere.
GOQUIT  JMP   QUIT
GOHELP  JMP   HELP
GOOVF   JMP   OVFLOW
GODZ    JMP   DIVZERO
GOMOD   JMP   DOMOD
*
DOADD   LDAA  A1+1
        ADDA  A2+1
        STAA  RES+1
        LDAA  A1
        ADCA  A2
        STAA  RES
        BCS   GOOVF
        BRA   SHOW
*
DOSUB   LDAA  A1+1              A1 - A2, 16 bits
        SUBA  A2+1
        STAA  RES+1
        LDAA  A1
        SBCA  A2
        STAA  RES
        BCC   SHOW              no borrow: result is positive
        INC   NEG               borrow: print "-" and negate (0 - RES)
        CLRA
        SUBA  RES+1
        STAA  RES+1
        CLRA
        SBCA  RES
        STAA  RES
        BRA   SHOW
*
DOMUL   CLR   RES               shift-and-add; A1 = multiplicand, A2 = multiplier
        CLR   RES+1
MUL1    LDAA  A2
        ORAA  A2+1
        BEQ   SHOW              multiplier exhausted
        LSR   A2                A2 >>= 1, bit 0 -> carry
        ROR   A2+1
        BCC   MUL2
        LDAA  RES+1             RES += A1
        ADDA  A1+1
        STAA  RES+1
        LDAA  RES
        ADCA  A1
        STAA  RES
        BCS   GOOVF
MUL2    LDAA  A2
        ORAA  A2+1
        BEQ   SHOW              done: skip the final (needless) shift
        ASL   A1+1              A1 <<= 1
        ROL   A1
        BCS   GOOVF
        BRA   MUL1
*
DODIV   JSR   DIV16
        BCS   GODZ
        LDAA  A1                quotient was built in A1
        STAA  RES
        LDAA  A1+1
        STAA  RES+1
        BRA   SHOW
DOMOD   JSR   DIV16
        BCS   GODZ
        LDAA  REM
        STAA  RES
        LDAA  REM+1
        STAA  RES+1
        BRA   SHOW
*
SHOW    LDX   #EQUALS
        JSR   PRSTR
        TST   NEG
        BEQ   SHOW2
        LDAA  #'-
        JSR   PUTC
SHOW2   LDAA  RES
        STAA  NUM
        LDAA  RES+1
        STAA  NUM+1
        STAA  LAST+1            remember the answer for "A"
        LDAA  RES
        STAA  LAST
        JSR   PRDEC
        JSR   CRLF
        JMP   NEXT
OVFLOW  LDX   #OVFMSG
        JSR   PRSTR
        JMP   NEXT
DIVZERO LDX   #DZMSG
        JSR   PRSTR
        JMP   NEXT
HELP    LDX   #HELPMSG
        JSR   PRSTR
        JMP   NEXT
QUIT    LDX   #BYEMSG
        JSR   PRSTR
        WAI
*
* ARG: X -> operand. 'A' = previous answer, else a decimal number.
ARG     LDAA  0,X
        CMPA  #'A
        BNE   ARG1
        LDAA  LAST
        STAA  NUM
        LDAA  LAST+1
        STAA  NUM+1
        INX
        CLC
        RTS
ARG1    JMP   PARSE             tail call: PARSE returns straight to our caller
*
* DIV16: A1 / A2 -> quotient in A1, remainder in REM.  C=1 if A2 = 0.
DIV16   LDAA  A2
        ORAA  A2+1
        BNE   DV0
        SEC
        RTS
DV0     CLR   REM
        CLR   REM+1
        LDAA  #16
        STAA  CNT
DV1     ASL   A1+1              shift the dividend left into the remainder
        ROL   A1
        ROL   REM+1
        ROL   REM
        LDAA  #0
        ROLA                    A = the bit that fell off the remainder
        STAA  XCARRY
        LDAA  REM+1             TMP = REM - A2
        SUBA  A2+1
        STAA  TMP+1
        LDAA  REM
        SBCA  A2
        STAA  TMP
        BCC   DV2               no borrow: remainder >= divisor
        TST   XCARRY
        BEQ   DV3               borrow and no 17th bit: remainder < divisor
DV2     LDAA  TMP               commit the subtraction
        STAA  REM
        LDAA  TMP+1
        STAA  REM+1
        INC   A1+1              quotient bit (bit 0 is free after the shift)
DV3     DEC   CNT
        BNE   DV1
        CLC
        RTS
*
BANNER  FCB   CR,LF,"*** CALC - 16-BIT CALCULATOR FOR THE MC6800 ***",CR,LF
        FCB   "ENTER  N+N  N-N  N*N  N/N  N%N   (A = last answer, H = help, Q = quit)",CR,LF,0
PROMPT  FCB   "> ",0
EQUALS  FCB   "= ",0
SYNMSG  FCB   "? SYNTAX ERROR - TYPE H FOR HELP",CR,LF,0
OVFMSG  FCB   "? OVERFLOW (RESULT EXCEEDS 65535)",CR,LF,0
DZMSG   FCB   "? DIVISION BY ZERO",CR,LF,0
HELPMSG FCB   "  12+30    ADD            900-1000  SUBTRACT (NEGATIVE ALLOWED)",CR,LF
        FCB   "  250*4    MULTIPLY       1000/7    QUOTIENT",CR,LF
        FCB   "  1000%7   REMAINDER      A*2       USE THE LAST ANSWER",CR,LF,0
BYEMSG  FCB   "BYE. (MACHINE HALTED)",CR,LF,0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
