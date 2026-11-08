* ======================================================================
* HANGMAN.ASM - GUESS THE WORD, ONE LETTER AT A TIME      (acpx 6800 sample)
*
* The computer picks one of 16 words about the 6800. Press a letter (no
* ENTER needed); six wrong guesses lose the game. Shows: a table of string
* pointers (FDB of labels), indexed lookups through X, a 26-byte "letters
* used" array, conditional drawing, and a random pick via RANDN.
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
WORDP   EQU   USER              pointer to the chosen word (2 bytes)
WPTR    EQU   USER+2           running pointer (2 bytes)
WRONG   EQU   USER+4           wrong guesses so far
UNREV   EQU   USER+5           letters still hidden
IDX     EQU   USER+6           loop index
WINS    EQU   USER+7
LOSSES  EQU   USER+8
USED    EQU   USER+10          26 flags: letter already guessed
NWORDS  EQU   16
MAXWRONG EQU  6
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
        CLR   WINS
        CLR   LOSSES
NEWGAME CLR   WRONG
        LDX   #USED             clear the 26 "used" flags
        LDAB  #26
NG1     CLR   0,X
        INX
        DECB
        BNE   NG1
        LDX   #PRESS
        JSR   PRSTR
        JSR   GETC              the wait seeds the random generator
        JSR   CRLF
        LDAB  #NWORDS
        JSR   RANDN             A = 0..15
        LDX   #WTAB
        TSTA
        BEQ   NG3
NG2     INX                     X = WTAB + 2*A
        INX
        DECA
        BNE   NG2
NG3     LDX   0,X               X = pointer to the word
        STX   WORDP
*
TURN    JSR   DRAWMAN
        LDAA  UNREV
        BEQ   WON
        LDAA  WRONG
        CMPA  #MAXWRONG
        BEQ   LOST
        LDX   #ASK
        JSR   PRSTR
GETLTR  JSR   GETC
        CMPA  #'a
        BCS   LT1
        CMPA  #'z
        BHI   LT1
        SUBA  #$20
LT1     CMPA  #'A
        BCS   GETLTR
        CMPA  #'Z
        BHI   GETLTR
        JSR   PUTC              echo the letter
        PSHA
        SUBA  #'A
        TAB
        JSR   GADDR
        PULA
        TST   0,X
        BNE   DUP
        INC   0,X               mark it used
        JSR   INWORD
        BCC   HIT
        INC   WRONG
        LDX   #NOPE
        BRA   REPLY
HIT     LDX   #YEP
REPLY   JSR   PRSTR
        BRA   TURN
DUP     LDX   #DUPM
        JSR   PRSTR
        BRA   GETLTR
*
WON     INC   WINS
        LDX   #WONM
        BRA   DONE
LOST    INC   LOSSES
        LDX   #LOSTM
        JSR   PRSTR
        LDX   WORDP
DONE    JSR   PRSTR
        LDX   #SCORE
        JSR   PRSTR
        CLR   NUM
        LDAA  WINS
        STAA  NUM+1
        JSR   PRDEC
        LDX   #SCORE2
        JSR   PRSTR
        CLR   NUM
        LDAA  LOSSES
        STAA  NUM+1
        JSR   PRDEC
        LDX   #AGAIN
        JSR   PRSTR
        JSR   GETC
        ANDA  #$DF
        CMPA  #'Y
        BNE   QUIT
        JSR   CRLF
        JMP   NEWGAME
QUIT    JSR   CRLF
        LDX   #BYE
        JSR   PRSTR
        WAI
*
* GADDR: B = 0..25 -> X = address of USED[B].  Preserves A and B.
GADDR   LDX   #USED
        TSTB
        BEQ   GA9
        PSHB
GA1     INX
        DECB
        BNE   GA1
        PULB
GA9     RTS
*
* INWORD: is letter A in the word?  C=0 yes, C=1 no.  Preserves A.
INWORD  LDX   WORDP
IW1     TST   0,X
        BEQ   IWNO
        CMPA  0,X
        BEQ   IWYES
        INX
        BRA   IW1
IWYES   CLC
        RTS
IWNO    SEC
        RTS
*
* PCOND: print A if WRONG >= B, else a space.
PCOND   CMPB  WRONG
        BLS   PC1               B <= WRONG: show the part
        LDAA  #SPACE
PC1     JMP   PUTC
*
DRAWMAN JSR   CRLF
        LDX   #GAL1
        JSR   PRSTR
        LDAA  #'O               head
        LDAB  #1
        JSR   PCOND
        LDX   #GAL2
        JSR   PRSTR
        LDAA  #'/               left arm
        LDAB  #3
        JSR   PCOND
        LDAA  #'|               body
        LDAB  #2
        JSR   PCOND
        LDAA  #$5C              right arm (backslash)
        LDAB  #4
        JSR   PCOND
        LDX   #GAL3
        JSR   PRSTR
        LDAA  #'/               left leg
        LDAB  #5
        JSR   PCOND
        LDAA  #SPACE
        JSR   PUTC
        LDAA  #$5C              right leg
        LDAB  #6
        JSR   PCOND
        LDX   #GAL4
        JSR   PRSTR
*       the word with unguessed letters hidden
        LDX   WORDP
        STX   WPTR
        CLR   UNREV
DW1     LDX   WPTR
        LDAA  0,X
        BEQ   DW9
        INX
        STX   WPTR
        PSHA
        SUBA  #'A
        TAB
        JSR   GADDR
        PULA
        TST   0,X
        BNE   DW2
        INC   UNREV
        LDAA  #'_
DW2     JSR   PUTC
        LDAA  #SPACE
        JSR   PUTC
        BRA   DW1
DW9     JSR   CRLF
*       letters tried that are not in the word
        LDX   #MISSED
        JSR   PRSTR
        CLR   IDX
DM1     LDAB  IDX
        JSR   GADDR
        TST   0,X
        BEQ   DM2
        LDAA  IDX
        ADDA  #'A
        JSR   INWORD
        BCC   DM2               in the word: not a miss
        JSR   PUTC
        LDAA  #SPACE
        JSR   PUTC
DM2     INC   IDX
        LDAA  IDX
        CMPA  #26
        BNE   DM1
        JSR   CRLF
        RTS
*
BANNER  FCB   CR,LF,"*** HANGMAN ON THE MC6800 ***",CR,LF
        FCB   "THE WORDS ARE ALL ABOUT THE 6800 AND ITS TOOLS.",CR,LF,0
PRESS   FCB   CR,LF,"PRESS A KEY TO PICK A WORD... ",0
GAL1    FCB   "  +---+",CR,LF,"  |   |",CR,LF,"  ",0
GAL2    FCB   "   |",CR,LF," ",0
GAL3    FCB   "  |",CR,LF," ",0
GAL4    FCB   "  |",CR,LF,"      |",CR,LF,"=========",CR,LF,0
MISSED  FCB   "MISSED: ",0
ASK     FCB   "GUESS A LETTER? ",0
YEP     FCB   "  - YES!",CR,LF,0
NOPE    FCB   "  - NO.",CR,LF,0
DUPM    FCB   CR,LF,"YOU TRIED THAT ONE ALREADY. ",0
WONM    FCB   CR,LF,"*** YOU GOT IT! ***",CR,LF,0
LOSTM   FCB   CR,LF,"*** HANGED! THE WORD WAS ",0
SCORE   FCB   CR,LF,"WON ",0
SCORE2  FCB   "  LOST ",0
AGAIN   FCB   CR,LF,"ANOTHER WORD (Y/N)? ",0
BYE     FCB   "GOODBYE. (MACHINE HALTED)",CR,LF,0
*
* table of pointers to the words
WTAB    FDB   W0,W1,W2,W3,W4,W5,W6,W7
        FDB   W8,W9,W10,W11,W12,W13,W14,W15
W0      FCB   "MOTOROLA",0
W1      FCB   "ASSEMBLER",0
W2      FCB   "ACCUMULATOR",0
W3      FCB   "REGISTER",0
W4      FCB   "INTERRUPT",0
W5      FCB   "EXTENDED",0
W6      FCB   "INDEXED",0
W7      FCB   "MNEMONIC",0
W8      FCB   "DIRECTIVE",0
W9      FCB   "SUBROUTINE",0
W10     FCB   "PROGRAM",0
W11     FCB   "PROCESSOR",0
W12     FCB   "TERMINAL",0
W13     FCB   "BRANCH",0
W14     FCB   "OVERFLOW",0
W15     FCB   "CARRY",0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
