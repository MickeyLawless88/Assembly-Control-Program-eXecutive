* ======================================================================
* TICTAC.ASM - TIC-TAC-TOE AGAINST THE MC6800              (acpx 6800 sample)
*
* You are X, the computer is O. Press 1-9 to place a mark (no ENTER needed),
* Q to quit. The computer: 1) wins if it can, 2) blocks your win, 3) takes
* the centre, 4) a corner, 5) a side - and opens at random. Who starts
* alternates between games.
* Shows: tables (win lines, move preference), a cell-address routine, nested
* subroutines, EQU-based zero-page variables and a single-key GETC.
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
BOARD   EQU   USER              9 cells: 0 = empty, 'X' or 'O'
WHO     EQU   USER+9           mark being looked for
NP      EQU   USER+10          how many cells of WHO on a line
NE      EQU   USER+11          how many empty cells on a line
EMP     EQU   USER+12          the empty cell found
LPTR    EQU   USER+13          running pointer into a table (2 bytes)
LCNT    EQU   USER+15          line counter
MOVES   EQU   USER+16          moves made this game
TURN    EQU   USER+17          0 = you, 1 = computer
STARTER EQU   USER+18          who opened this game
XWINS   EQU   USER+19
OWINS   EQU   USER+20
DRAWS   EQU   USER+21
IDX     EQU   USER+22          cell counter for drawing
COLN    EQU   USER+23          column counter for drawing
ROWN    EQU   USER+24          row counter for drawing
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
        CLR   XWINS
        CLR   OWINS
        CLR   DRAWS
        LDAA  #1
        STAA  STARTER           flipped before each game: you open first
        JSR   GETC              the wait seeds the random generator
NEWGAME LDAA  STARTER
        EORA  #1
        STAA  STARTER
        STAA  TURN
        CLR   MOVES
        LDX   #BOARD            clear the board
        LDAB  #9
CLR1    CLR   0,X
        INX
        DECB
        BNE   CLR1
*
PLAY    JSR   SHOW
        TST   TURN
        BNE   COMP
*
HUMAN   LDX   #YMOVE
        JSR   PRSTR
HUM1    JSR   GETC
        CMPA  #'q
        BEQ   GOQUIT
        CMPA  #'Q
        BEQ   GOQUIT
        SUBA  #'1
        BCS   HUM1              below '1'
        CMPA  #8
        BHI   HUM1              above '9'
        TAB
        JSR   CELLX
        LDAA  0,X
        BNE   TAKEN
        LDAA  #'X
        STAA  0,X
        BRA   MOVED
TAKEN   LDX   #TAKENM
        JSR   PRSTR
        BRA   HUMAN
GOQUIT  JMP   QUIT
*
COMP    LDX   #THINK
        JSR   PRSTR
        TST   MOVES
        BNE   COMP1
        LDAB  #9                opening move: any cell at random
        JSR   RANDN
        TAB
        BRA   CPLAY
COMP1   LDAA  #'O               1) can I win?
        STAA  WHO
        JSR   FIND
        BCC   CPLAY
        LDAA  #'X               2) must I block?
        STAA  WHO
        JSR   FIND
        BCC   CPLAY
        LDX   #PREF             3) first free cell in preference order
        STX   LPTR
PK1     LDX   LPTR
        LDAB  0,X
        INX
        STX   LPTR
        JSR   CELLX
        LDAA  0,X
        BNE   PK1
CPLAY   JSR   CELLX
        LDAA  #'O
        STAA  0,X
        LDX   #IPLAY
        JSR   PRSTR
        TBA
        ADDA  #'1
        JSR   PUTC
        JSR   CRLF
*
MOVED   INC   MOVES             did the player who just moved win?
        LDAA  #'X
        TST   TURN
        BEQ   MV1
        LDAA  #'O
MV1     STAA  WHO
        JSR   WINCHK
        BCC   WON
        LDAA  MOVES
        CMPA  #9
        BEQ   DRAWN
        LDAA  TURN
        EORA  #1
        STAA  TURN
        JMP   PLAY
*
WON     JSR   SHOW
        TST   TURN
        BNE   IWIN
        INC   XWINS
        LDX   #YOUWIN
        BRA   ENDMSG
IWIN    INC   OWINS
        LDX   #IWINM
        BRA   ENDMSG
DRAWN   JSR   SHOW
        INC   DRAWS
        LDX   #DRAWM
ENDMSG  JSR   PRSTR
        LDX   #SC1
        JSR   PRSTR
        CLR   NUM
        LDAA  XWINS
        STAA  NUM+1
        JSR   PRDEC
        LDX   #SC2
        JSR   PRSTR
        CLR   NUM
        LDAA  OWINS
        STAA  NUM+1
        JSR   PRDEC
        LDX   #SC3
        JSR   PRSTR
        CLR   NUM
        LDAA  DRAWS
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
* CELLX: B = cell 0..8 -> X = its address. Preserves A and B.
CELLX   LDX   #BOARD
        TSTB
        BEQ   CX9
        PSHB
CX1     INX
        DECB
        BNE   CX1
        PULB
CX9     RTS
*
* TCELL: look at cell B for the mark WHO: NP counts WHO, NE counts empties
* (EMP remembers the last empty cell).
TCELL   JSR   CELLX
        LDAA  0,X
        BEQ   TC1
        CMPA  WHO
        BNE   TC9
        INC   NP
        RTS
TC1     INC   NE
        STAB  EMP
TC9     RTS
*
* LINEPEEK: score the line LPTR points to (3 cell numbers) -> NP, NE, EMP
LINEPEEK CLR  NP
        CLR   NE
        LDX   LPTR
        LDAB  0,X
        JSR   TCELL
        LDX   LPTR
        LDAB  1,X
        JSR   TCELL
        LDX   LPTR
        LDAB  2,X
        JMP   TCELL             tail call
*
* NEXTLINE: advance LPTR one line; Z=1 when all 8 lines are done.
NEXTLINE LDX  LPTR
        INX
        INX
        INX
        STX   LPTR
        DEC   LCNT
        RTS
*
* FIND: a line with two WHO and one empty cell -> C=0, B = the empty cell.
FIND    LDX   #LINES
        STX   LPTR
        LDAA  #8
        STAA  LCNT
FD1     JSR   LINEPEEK
        LDAA  NP
        CMPA  #2
        BNE   FD2
        LDAA  NE
        CMPA  #1
        BNE   FD2
        LDAB  EMP
        CLC
        RTS
FD2     JSR   NEXTLINE
        BNE   FD1
        SEC
        RTS
*
* WINCHK: three WHO in a line -> C=0.
WINCHK  LDX   #LINES
        STX   LPTR
        LDAA  #8
        STAA  LCNT
WC1     JSR   LINEPEEK
        LDAA  NP
        CMPA  #3
        BEQ   WC9
        JSR   NEXTLINE
        BNE   WC1
        SEC
        RTS
WC9     CLC
        RTS
*
* SHOW: draw the board. Empty cells show their number.
SHOW    JSR   CRLF
        CLR   IDX
        CLR   COLN
        CLR   ROWN
SH1     LDAA  #SPACE
        JSR   PUTC
        LDAB  IDX
        JSR   CELLX
        LDAA  0,X
        BNE   SH2
        LDAA  IDX
        ADDA  #'1
SH2     JSR   PUTC
        INC   IDX
        INC   COLN
        LDAA  COLN
        CMPA  #3
        BEQ   SH3
        LDAA  #SPACE
        JSR   PUTC
        LDAA  #'|
        JSR   PUTC
        BRA   SH1
SH3     CLR   COLN
        JSR   CRLF
        INC   ROWN
        LDAA  ROWN
        CMPA  #3
        BEQ   SH9
        LDX   #DIVIDER
        JSR   PRSTR
        BRA   SH1
SH9     RTS
*
* ---- tables ----
* The 8 winning lines as cell numbers 0..8 (3 bytes each).
LINES   FCB   0,1,2,3,4,5,6,7,8
        FCB   0,3,6,1,4,7,2,5,8
        FCB   0,4,8,2,4,6
* Computer's preference order: centre, corners, sides.
PREF    FCB   4,0,2,6,8,1,3,5,7
*
BANNER  FCB   CR,LF,"*** TIC-TAC-TOE ON THE MC6800 ***",CR,LF
        FCB   "YOU ARE X, I AM O.  PRESS A KEY TO START... ",0
YMOVE   FCB   "YOUR MOVE (1-9, Q=QUIT)? ",0
TAKENM  FCB   CR,LF,"THAT SQUARE IS TAKEN.",CR,LF,0
THINK   FCB   "I AM THINKING...",CR,LF,0
IPLAY   FCB   "I PLAY ",0
YOUWIN  FCB   CR,LF,"*** YOU WIN! ***",CR,LF,0
IWINM   FCB   CR,LF,"*** I WIN! ***",CR,LF,0
DRAWM   FCB   CR,LF,"*** A DRAW. ***",CR,LF,0
DIVIDER FCB   "---+---+---",CR,LF,0
SC1     FCB   "YOU ",0
SC2     FCB   "  ME ",0
SC3     FCB   "  DRAWS ",0
AGAIN   FCB   CR,LF,"PLAY AGAIN (Y/N)? ",0
BYE     FCB   "GOODBYE. (MACHINE HALTED)",CR,LF,0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
