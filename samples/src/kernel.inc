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
