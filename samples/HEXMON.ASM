* ======================================================================
* HEXMON.ASM - A TINY MEMORY MONITOR                     (acpx 6800 sample)
*
*   D [addr [len]]       dump memory (hex + ASCII), CR repeats from where it ended
*   E addr               examine / deposit: type a hex byte, CR = skip, . = stop
*   F addr len byte      fill
*   M src dst len        move (overlap-safe)
*   G addr               call a routine (JSR) - it should end with RTS
*   H  help     Q  quit
* All numbers are hexadecimal. Try:  D E000   E 300   G 300
* Shows: command table + "LDX 1,X / JSR 0,X" dispatch, 16-bit pointers kept in
* the zero page, hex parsing/printing, overlap-safe block move.
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
MAXLEN  EQU   24                longest line GETLINE accepts
SPACE   EQU   $20
CR      EQU   $0D
LF      EQU   $0A
BS      EQU   $08
DADDR   EQU   USER              next dump address
REMN    EQU   USER+2           bytes left in this dump
LN      EQU   USER+4           bytes on the current dump line
COL     EQU   USER+5           column counter
PTR2    EQU   USER+6           running pointer
ARG1    EQU   USER+8           first argument
ARG2    EQU   USER+10          second argument
ARG3    EQU   USER+12          third argument
NARG    EQU   USER+14          how many arguments GETARGS found
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
        LDX   #$0300
        STX   DADDR
LOOP    LDX   #PROMPT
        JSR   PRSTR
        JSR   GETLINE
        LDAA  LINLEN
        BEQ   LOOP
        LDAA  BUF
        LDX   #CMDTAB
FIND    CMPA  0,X
        BEQ   FOUND
        INX                     each entry is 3 bytes: letter, handler hi, lo
        INX
        INX
        TST   0,X
        BNE   FIND
        LDX   #HUH
        JSR   PRSTR
        BRA   LOOP
FOUND   LDX   1,X               X = address of the handler
        JSR   0,X               call it (JSR n,X jumps to X+n)
        BRA   LOOP
*
CMDTAB  FCB   'D
        FDB   DODUMP
        FCB   'E
        FDB   DOEXAM
        FCB   'F
        FDB   DOFILL
        FCB   'M
        FDB   DOMOVE
        FCB   'G
        FDB   DOGO
        FCB   'H
        FDB   DOHELP
        FCB   'Q
        FDB   DOQUIT
        FCB   0
*
* ---------------- hex helpers ----------------
SKIPSP  LDAA  0,X
        CMPA  #SPACE
        BNE   SKIP9
        INX
        BRA   SKIPSP
SKIP9   RTS
*
HEXVAL  SUBA  #'0               A = char -> 0..15, or $FF if not a hex digit
        BCS   HVBAD
        CMPA  #9
        BLS   HVOK
        SUBA  #7
        CMPA  #10
        BCS   HVBAD
        CMPA  #15
        BHI   HVBAD
HVOK    RTS
HVBAD   LDAA  #$FF
        RTS
*
HEXNUM  JSR   SKIPSP            X -> text. NUM = value, C=1 if no digits
        CLR   NUM
        CLR   NUM+1
        CLR   NDIG
HN1     LDAA  0,X
        JSR   HEXVAL
        CMPA  #$FF
        BEQ   HN9
        LDAB  #4
HN2     ASL   NUM+1             NUM = NUM * 16
        ROL   NUM
        DECB
        BNE   HN2
        ORAA  NUM+1
        STAA  NUM+1
        INC   NDIG
        INX
        BRA   HN1
HN9     TST   NDIG
        BEQ   HNBAD
        CLC
        RTS
HNBAD   SEC
        RTS
*
PRADDR  LDAA  NUM               print NUM as 4 hex digits
        JSR   PRHEX
        LDAA  NUM+1
        JSR   PRHEX
        RTS
*
* GETARGS: parse up to 3 hex arguments from BUF+1 into ARG1..ARG3.
* Returns B = how many were found (kept in NARG: HEXNUM uses B as a counter).
GETARGS LDX   #BUF+1
        CLR   NARG
        JSR   HEXNUM
        BCS   GA9
        LDAA  NUM
        STAA  ARG1
        LDAA  NUM+1
        STAA  ARG1+1
        INC   NARG
        JSR   HEXNUM
        BCS   GA9
        LDAA  NUM
        STAA  ARG2
        LDAA  NUM+1
        STAA  ARG2+1
        INC   NARG
        JSR   HEXNUM
        BCS   GA9
        LDAA  NUM
        STAA  ARG3
        LDAA  NUM+1
        STAA  ARG3+1
        INC   NARG
GA9     LDAB  NARG
        RTS
*
NEEDARG LDX   #ARGMSG
        JSR   PRSTR
        RTS
*
* ---------------- D : dump ----------------
DODUMP  JSR   GETARGS
        TSTB
        BEQ   DD1               no address: continue where we left off
        LDX   ARG1
        STX   DADDR
DD1     LDX   #$0040            default length
        CMPB  #2
        BCS   DD2
        LDX   ARG2
DD2     STX   REMN
DDLINE  LDAA  REMN
        ORAA  REMN+1
        BNE   DDGO
        RTS
DDGO    LDAA  DADDR
        JSR   PRHEX
        LDAA  DADDR+1
        JSR   PRHEX
        LDAA  #':
        JSR   PUTC
        LDAB  #16               LN = min(16, REMN)
        LDAA  REMN
        BNE   DDL1
        LDAA  REMN+1
        CMPA  #16
        BCC   DDL1
        TAB
DDL1    STAB  LN
        LDX   DADDR
        STX   PTR2
        CLR   COL
DDHEX   LDAA  #SPACE
        JSR   PUTC
        LDAA  COL
        CMPA  LN
        BCC   DDPAD
        LDX   PTR2
        LDAA  0,X
        INX
        STX   PTR2
        JSR   PRHEX
        BRA   DDNXT
DDPAD   LDAA  #SPACE
        JSR   PUTC
        JSR   PUTC
DDNXT   INC   COL
        LDAA  COL
        CMPA  #16
        BNE   DDHEX
        LDAA  #SPACE
        JSR   PUTC
        LDAA  #'|
        JSR   PUTC
        LDX   DADDR
        STX   PTR2
        CLR   COL
DDASC   LDAA  COL
        CMPA  LN
        BCC   DDEOL
        LDX   PTR2
        LDAA  0,X
        INX
        STX   PTR2
        CMPA  #SPACE
        BCS   DDDOT             control char
        CMPA  #$7F
        BCS   DDPUT             printable
DDDOT   LDAA  #'.
DDPUT   JSR   PUTC
        INC   COL
        BRA   DDASC
DDEOL   LDAA  #'|
        JSR   PUTC
        JSR   CRLF
        LDX   PTR2              advance the address by LN
        STX   DADDR
        LDAA  REMN+1            REMN = REMN - LN
        SUBA  LN
        STAA  REMN+1
        LDAA  REMN
        SBCA  #0
        STAA  REMN
        JMP   DDLINE
*
* ---------------- E : examine / deposit ----------------
DOEXAM  JSR   GETARGS
        TSTB
        BNE   EX1
        BRA   EXNEED
EX1     LDX   ARG1
        LDAA  ARG1
        STAA  NUM
        LDAA  ARG1+1
        STAA  NUM+1
        JSR   PRADDR
        LDAA  #':
        JSR   PUTC
        LDAA  #SPACE
        JSR   PUTC
        LDX   ARG1
        LDAA  0,X
        JSR   PRHEX
        LDAA  #SPACE
        JSR   PUTC
        LDAA  #'?
        JSR   PUTC
        LDAA  #SPACE
        JSR   PUTC
        JSR   GETLINE
        LDAA  LINLEN
        BEQ   EXNEXT            CR alone: leave the byte, go to the next
        LDAA  BUF
        CMPA  #'.
        BEQ   EXDONE
        LDX   #BUF
        JSR   HEXNUM
        BCS   EXBAD
        LDX   ARG1
        LDAA  NUM+1
        STAA  0,X
        CMPA  0,X               read it back: ROM or no RAM here?
        BEQ   EXNEXT
        LDX   #ROMMSG
        JSR   PRSTR
EXNEXT  LDX   ARG1
        INX
        STX   ARG1
        BRA   EX1
EXBAD   LDX   #HUH
        JSR   PRSTR
        BRA   EX1
EXDONE  RTS
EXNEED  JMP   NEEDARG
*
* ---------------- F : fill ----------------
DOFILL  JSR   GETARGS
        CMPB  #3
        BCC   FL0
        JMP   NEEDARG
FL0     LDX   ARG1
FL1     LDAA  ARG2
        ORAA  ARG2+1
        BEQ   FLEND
        LDAA  ARG3+1
        STAA  0,X
        INX
        LDAA  ARG2+1            ARG2 = ARG2 - 1
        SUBA  #1
        STAA  ARG2+1
        LDAA  ARG2
        SBCA  #0
        STAA  ARG2
        BRA   FL1
FLEND   RTS
*
* ---------------- M : move (overlap-safe) ----------------
* ARG1 = source, ARG2 = destination, ARG3 = length
DOMOVE  JSR   GETARGS
        CMPB  #3
        BCC   MV0
        JMP   NEEDARG
MV0     LDAA  ARG2              if dst > src copy backwards
        CMPA  ARG1
        BHI   MVBACK
        BCS   MVFWD
        LDAA  ARG2+1
        CMPA  ARG1+1
        BHI   MVBACK
MVFWD   LDAA  ARG3
        ORAA  ARG3+1
        BEQ   MVEND
        LDX   ARG1
        LDAA  0,X
        INX
        STX   ARG1
        LDX   ARG2
        STAA  0,X
        INX
        STX   ARG2
        JSR   DEC3
        BRA   MVFWD
MVBACK  LDX   ARG3              point both at one past the end
        STX   PTR2              (PTR2 = length)
        LDAA  ARG1+1
        ADDA  ARG3+1
        STAA  ARG1+1
        LDAA  ARG1
        ADCA  ARG3
        STAA  ARG1
        LDAA  ARG2+1
        ADDA  ARG3+1
        STAA  ARG2+1
        LDAA  ARG2
        ADCA  ARG3
        STAA  ARG2
MVB1    LDAA  ARG3
        ORAA  ARG3+1
        BEQ   MVEND
        LDX   ARG1
        DEX
        STX   ARG1
        LDAA  0,X
        LDX   ARG2
        DEX
        STX   ARG2
        STAA  0,X
        JSR   DEC3
        BRA   MVB1
MVEND   RTS
DEC3    LDAA  ARG3+1            ARG3 = ARG3 - 1
        SUBA  #1
        STAA  ARG3+1
        LDAA  ARG3
        SBCA  #0
        STAA  ARG3
        RTS
*
* ---------------- G : go ----------------
DOGO    JSR   GETARGS
        TSTB
        BNE   GO1
        JMP   NEEDARG
GO1     LDX   ARG1
        JSR   0,X               run the user's routine
        LDX   #RETMSG
        JSR   PRSTR
        RTS
*
DOHELP  LDX   #HELPMSG
        JSR   PRSTR
        LDX   #PUTC             show where the console routine lives
        STX   NUM               (a label's high/low bytes come via a 16-bit store)
        JSR   PRADDR
        JSR   CRLF
        RTS
DOQUIT  LDX   #BYEMSG
        JSR   PRSTR
        WAI
*
BANNER  FCB   CR,LF,"*** HEXMON - MEMORY MONITOR FOR THE MC6800 ***",CR,LF
        FCB   "ALL NUMBERS ARE HEX.  H = HELP.",CR,LF,0
PROMPT  FCB   "* ",0
HUH     FCB   "? WHAT?",CR,LF,0
ARGMSG  FCB   "? ARGUMENT(S) MISSING",CR,LF,0
ROMMSG  FCB   "  (NOT WRITABLE)",CR,LF,0
RETMSG  FCB   "[RETURNED]",CR,LF,0
HELPMSG FCB   "D [ADDR [LEN]]  DUMP     E ADDR  EXAMINE/DEPOSIT (. ENDS)",CR,LF
        FCB   "F ADDR LEN BYTE  FILL     M SRC DST LEN  MOVE",CR,LF
        FCB   "G ADDR  CALL (RTS RETURNS)     Q  QUIT.  CONSOLE PUTC IS AT ",0
BYEMSG  FCB   "BYE. (MACHINE HALTED)",CR,LF,0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
