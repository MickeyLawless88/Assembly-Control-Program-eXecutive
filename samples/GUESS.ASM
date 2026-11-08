* ======================================================================
* GUESS.ASM - NUMBER GUESSING GAME                       (acpx 6800 sample)
*
* The computer picks a secret number 1-100; you get 7 guesses and are told
* HIGH or LOW. Shows: line input + decimal parsing, 16-bit compare, a PRNG
* seeded from the time you take to press a key, and string tables.
* Assemble with ACPX option 2, run with:  python sim6800.py GUESS.S19
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
SECRET  EQU   USER              the number to find
TRIES   EQU   USER+1            guesses used so far
GAMES   EQU   USER+2            games played
WINS    EQU   USER+3            games won
MAXTRY  EQU   7
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
        CLR   GAMES
        CLR   WINS
NEWGAME LDX   #SHUFFLE
        JSR   PRSTR
        JSR   GETC              the wait seeds the random generator
        JSR   CRLF
        LDAB  #100
        JSR   RANDN             A = 0..99
        INCA
        STAA  SECRET            1..100
        CLR   TRIES
        INC   GAMES
ASK     LDX   #PROMPT
        JSR   PRSTR
        JSR   GETLINE
        LDX   #BUF
        JSR   PARSE
        BCS   BAD               no digits / overflow
        LDAA  0,X
        BNE   BAD               junk after the number
        LDAA  NUM
        BNE   BAD               more than 255
        LDAA  NUM+1
        BEQ   BAD               zero
        CMPA  #100
        BHI   BAD
        INC   TRIES
        CMPA  SECRET
        BEQ   WIN
        BCS   LOW               guess < secret (unsigned borrow)
        LDX   #TOOHIGH
        BRA   SHOW
LOW     LDX   #TOOLOW
SHOW    JSR   PRSTR
        LDAA  TRIES
        CMPA  #MAXTRY
        BNE   ASK
        LDX   #LOSE1
        JSR   PRSTR
        CLR   NUM
        LDAA  SECRET
        STAA  NUM+1
        JSR   PRDEC
        LDX   #LOSE2
        JSR   PRSTR
        BRA   AGAIN
BAD     LDX   #BADMSG
        JSR   PRSTR
        BRA   ASK
WIN     INC   WINS
        LDX   #WIN1
        JSR   PRSTR
        CLR   NUM
        LDAA  TRIES
        STAA  NUM+1
        JSR   PRDEC
        LDX   #WIN2
        JSR   PRSTR
AGAIN   LDX   #SCORE1
        JSR   PRSTR
        CLR   NUM
        LDAA  WINS
        STAA  NUM+1
        JSR   PRDEC
        LDX   #SCORE2
        JSR   PRSTR
        CLR   NUM
        LDAA  GAMES
        STAA  NUM+1
        JSR   PRDEC
        LDX   #SCORE3
        JSR   PRSTR
        JSR   GETC
        ANDA  #$DF              fold to upper case
        CMPA  #'Y
        BEQ   ANOTHER
        JSR   CRLF
        LDX   #BYE
        JSR   PRSTR
        WAI
ANOTHER JSR   CRLF
        JMP   NEWGAME
*
BANNER  FCB   CR,LF,"*** GUESS - A NUMBER GAME FOR THE MC6800 ***",CR,LF
        FCB   "I AM THINKING OF A NUMBER FROM 1 TO 100.",CR,LF
        FCB   "YOU HAVE 7 GUESSES.",CR,LF,0
SHUFFLE FCB   CR,LF,"PRESS ANY KEY TO SHUFFLE... ",0
PROMPT  FCB   "YOUR GUESS? ",0
TOOLOW  FCB   "  TOO LOW.",CR,LF,0
TOOHIGH FCB   "  TOO HIGH.",CR,LF,0
BADMSG  FCB   "  PLEASE ENTER A WHOLE NUMBER 1-100.",CR,LF,0
WIN1    FCB   "  *** CORRECT! YOU NEEDED ",0
WIN2    FCB   " GUESS(ES). ***",CR,LF,0
LOSE1   FCB   "  SORRY, OUT OF GUESSES. THE NUMBER WAS ",0
LOSE2   FCB   ".",CR,LF,0
SCORE1  FCB   "SCORE: ",0
SCORE2  FCB   " WON OF ",0
SCORE3  FCB   " PLAYED.  PLAY AGAIN (Y/N)? ",0
BYE     FCB   "THANKS FOR PLAYING. (MACHINE HALTED)",CR,LF,0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
