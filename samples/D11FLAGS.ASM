* ======================================================================
* D11FLAGS.ASM - CONDITION CODES AND WHICH BRANCH TO USE       (self-checking)
*
* Principle: after a compare, unsigned and signed numbers need different
* branches.   unsigned: BHI BLS BCC BCS      signed: BGT BLE BGE BLT
* The 16-bit CPX sets N,Z,V but NOT carry on the 6800 - so after CPX test
* with BEQ/BNE (or the signed branches), never BCS/BCC.  INX/DEX change only
* Z.  LDAA/STAA leave carry alone.
* EXPECT-OK 6
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
*
MAIN    LDX   #HDR
        JSR   PRSTR
*
* 1. A=$80 vs $7F as UNSIGNED: 128 > 127, so BHI is taken
        LDX   #T1
        JSR   PRSTR
        LDAA  #$80
        CMPA  #$7F
        BHI   Y1
        LDAA  #1                not taken -> A=1 (fail)
        BRA   C1
Y1      LDAA  #0
C1      TSTA
        JSR   RESULT
*
* 2. the same compare as SIGNED: -128 < 127, so BGT is NOT taken
        LDX   #T2
        JSR   PRSTR
        LDAA  #$80
        CMPA  #$7F
        BGT   N2
        LDAA  #0                not taken -> pass
        BRA   C2
N2      LDAA  #1
C2      TSTA
        JSR   RESULT
*
* 3. A=$7F vs $80: unsigned 127 < 128 -> BCS taken (carry = borrow)
        LDX   #T3
        JSR   PRSTR
        LDAA  #$7F
        CMPA  #$80
        BCS   Y3
        LDAA  #1
        BRA   C3
Y3      LDAA  #0
C3      TSTA
        JSR   RESULT
*
* 4. CPX does not touch carry: CLC, then CPX #1 with X=0 (0 < 1)
*    a "borrow" would set carry; on the 6800 it stays clear.
        LDX   #T4
        JSR   PRSTR
        LDX   #0
        CLC
        CPX   #1
        BCS   F4                carry set would mean this sim is wrong
        LDAA  #0
        BRA   C4
F4      LDAA  #1
C4      TSTA
        JSR   RESULT
*
* 5. INX / DEX leave carry alone (only Z changes)
        LDX   #T5
        JSR   PRSTR
        LDX   #$00FF
        SEC
        INX
        INX
        DEX
        BCC   F5                carry must still be 1
        LDAA  #0
        BRA   C5
F5      LDAA  #1
C5      TSTA
        JSR   RESULT
*
* 6. LDAA/STAA leave carry alone, so a multi-byte SUB can load between halves
        LDX   #T6
        JSR   PRSTR
        LDAA  #$00
        SUBA  #$01              borrow -> carry set
        LDAA  #$00              loads do not change carry
        STAA  $20
        LDAA  #$00
        SBCA  #$00              0 - 0 - borrow = $FF
        CMPA  #$FF
        JSR   RESULT
        WAI
*
HDR     FCB   "D11FLAGS",CR,LF,0
T1      FCB   " UNSIGNED BHI ...... ",0
T2      FCB   " SIGNED BGT ........ ",0
T3      FCB   " UNSIGNED BCS ...... ",0
T4      FCB   " CPX LEAVES CARRY .. ",0
T5      FCB   " INX/DEX KEEP CARRY  ",0
T6      FCB   " LDAA/STAA KEEP C .. ",0
*
* ---- interrupt / reset vectors (the last 8 bytes of the 64K map) ----
        ORG   $FFF8
        FDB   NULLINT      ; IRQ
        FDB   NULLINT      ; SWI
        FDB   NULLINT      ; NMI
        FDB   RESET        ; RESET
        END
