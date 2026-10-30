; AST3     ASTEROIDS for the Lear Siegler ADM-31 plugin socket ($E000-$E7FF)
;
; Rewrite of ASTX.  Runs on the stock firmware + the ASTGENII character
; generator ($01-$08 ship facing 0-7, $09/$0A/$0B large/medium/small rock,
; $0C bullet).  Enter from the firmware with ESC '  (JMP $E03C).
;
; Controls     A / D   rotate left / right  (tap = one 45 degree step)
;              W       thrust       S  reverse thrust      SPACE  fire
;              ENTER   start / play again   (Z / X also rotate)
;
; What was wrong with ASTX and what this version does instead
;  * ONE rotation step per game tick while a key was down: 8 facings in
;    half a second.  Now: rotate on the key edge, auto-repeat after 8 ticks
;    and then every 3rd tick (KEYREP).
;  * keys were read one at a time (first key found wins), so thrust+turn+
;    fire together never worked.  Now every game key is scanned each tick
;    into a bit mask (SCANKEYS) and all of them act at once.
;  * thrust was a tiny increment that friction wiped out.  Now: real
;    acceleration, speed limit, ship keeps drifting, S = reverse thrust.
;  * tick rate came from a delay loop that ignored the work done; ASTX ran
;    ~14 Hz.  Now 30 Hz (33,333 cycles at 1 MHz) with the work time
;    included, motion is smooth sub-cell fixed point (1/128 cell per tick
;    velocity unit, 8.8 position).  Rocks and bullets use the same code.
;  * no SEI: the firmware IRQ fired into the game.  Now SEI first.
;  * erase-all / draw-all flicker removed: every object is erased and redrawn
;    in one step.
;
; Memory:  zero page $00-$7F   scalars
;          $0200-$02BF         12 rock slots  (16 bytes each)
;          $02C0-$02FF          4 bullet slots
;          $0300-$030F         ship record
; Record:  0 type (0 free,1 large,2 med,3 small,4 bullet,5 ship)
;          1 row cell 0-22   2 row frac   3 col cell 0-79   4 col frac
;          5 row velocity    6 col velocity (signed, 1/128 cell/tick)
;          7 bullet life     8,9 screen address of the drawn glyph (0=none)
;          10 glyph code
; ============================================================================
HALT    EQU     $7000
PIA1    EQU     $7800
CRTRAM  EQU     $8000

FACE    EQU     $00             ; ship facing 0-7
KEYS    EQU     $01             ; 1 L, 2 R, 4 thrust, 8 reverse, 16 fire, 32 start
CNTL    EQU     $02             ; key repeat counters
CNTR    EQU     $03
CNTF    EQU     $04
STATE   EQU     $05             ; 1 playing, 2 ship dead, 3 game over
SCH     EQU     $06             ; score, BCD, units of 10 points
SCL     EQU     $07
LIVES   EQU     $08
WAVE    EQU     $09             ; BCD
RNG     EQU     $0A
HUDF    EQU     $0B             ; nonzero = redraw the status line
TIMER   EQU     $0C
INV     EQU     $0D             ; invulnerable ticks left
TA      EQU     $0E
TB      EQU     $0F
TC      EQU     $10
TD      EQU     $11
TE      EQU     $12
T16     EQU     $13             ; 2 bytes
SAVX    EQU     $15             ; 2 bytes
DST     EQU     $17             ; 2 bytes
BP      EQU     $19             ; 2 bytes  bullet pointer
RP      EQU     $1B             ; 2 bytes  rock pointer
ADR     EQU     $1D             ; 2 bytes  computed screen address
SEED    EQU     $1F
TS      EQU     $20             ; thrust sign
TF      EQU     $21             ; new-wave rock counter
HIH     EQU     $22             ; high score, BCD
HIL     EQU     $23
TICKDLY EQU     3700

ROCKS   EQU     $0200
BULS    EQU     $02C0
SHIP    EQU     $0300

; ============================================================================
        ORG     $E000
        FCB     $54,$4A                 ; "TJ" plugin signature
KEYENTRY RTS                            ; $E002  firmware key callback: unused

        ORG     $E03C
        JMP     START                   ; ESC ' entry

; ---- data in the gap before the fixed callback stubs ----------------------
        ORG     $E040
DIRTAB  FCB     0,1,1,1,0,$FF,$FF,$FF  ; dx for facing 0-7
        FCB     $FF,$FF,0,1,1,1,0,$FF   ; dy
KTAB    FCB     48,1,65,1,50,2,66,2     ; A Z = left   D X = right
        FCB     32,4,49,8,75,16         ; W thrust  S reverse  SPACE fire
        FCB     43,32,79,32,0           ; ENTER (both keys) = start

        ORG     $E07D
PLUGCB2 RTS                             ; stock ROM B calls $E07D

        ORG     $E08A
ESCCB   RTS                             ; stock ROM C calls $E08A

        ORG     $E0CA
PLUGCB3 JMP     PLUGINIT                ; stock ROM B calls $E0CA at boot

; With a plugin present the stock firmware (ROM B $EC13) skips setting up its
; own key/ACIA handler vectors and calls $E0CA instead, expecting the plugin
; to do it.  A bare RTS here leaves the vectors at 0 and the first terminal
; event jumps to $0000 -- the terminal never comes up.  So: install exactly
; the defaults the firmware would have installed itself.
PLUGINIT LDX    #$EEA1
        STX     $67
        LDX     #$ED05
        STX     $69
        LDX     #$ED58
        STX     $6B
        LDX     #$F9F5
        STX     $6D
        LDX     #$FE03
        STX     $6F
        RTS

        ORG     $E0E8

; ============================================================================
; primitives
; ============================================================================
; PUTCH   A at screen address X, X advances.  HALT strobe write.
PUTCH   STAA    HALT
        NOP
        STAA    0,X
        INX
        RTS

; RND     8 bit LFSR, A = new value
RND     LDAA    RNG
        LSRA
        BCC     RND1
        EORA    #$B8
RND1    STAA    RNG
        RTS

; SCALE   A = signed dir (-1,0,1), B = magnitude  ->  A = dir * B
SCALE   TSTA
        BEQ     SCA0
        BPL     SCA1
        NEGB
SCA1    TBA
SCA0    RTS

; NXT16   X = X + 16 (record stride, tables sit inside one page)
;         returns Z set when the low byte wrapped to 0
NXT16   STX     SAVX
        LDAA    SAVX+1
        ADDA    #16
        STAA    SAVX+1
        LDX     SAVX
        TSTA
        RTS

; MOVAX   X -> (cell,frac) pair, B = signed velocity (1/128 cell per tick)
MOVAX   CLRA
        TSTB
        BPL     MA1
        COMA
MA1     ASLB
        ROLA
        ADDB    1,X
        STAB    1,X
        ADCA    0,X
        STAA    0,X
        RTS

; WRAP    A = cell, B = modulus  ->  A wrapped into 0..B-1
WRAP    CBA
        BCS     WR2
        TSTA
        BMI     WR1
        SBA
        RTS
WR1     ABA
WR2     RTS

; GETDIR  facing -> A = dx, B = dy  (-1,0,1)
GETDIR  LDX     #DIRTAB
        STX     T16
        LDAB    FACE
        ADDB    T16+1
        STAB    T16+1
        LDX     T16
        LDAA    0,X
        LDAB    8,X
        RTS

; ============================================================================
; entities
; ============================================================================
; ENTMOVE   X -> record, move by its velocity, wrap.  X preserved.
ENTMOVE LDAB    5,X
        INX
        BSR     MOVAX
        LDAA    0,X
        LDAB    #23
        BSR     WRAP
        STAA    0,X
        INX
        INX
        LDAB    3,X
        BSR     MOVAX
        LDAA    0,X
        LDAB    #80
        BSR     WRAP
        STAA    0,X
        DEX
        DEX
        DEX
        RTS

; ENTDRAW   X -> record.  Erase the old glyph if the cell changed, draw the
;           glyph at the current cell.  X preserved.
ENTDRAW STX     SAVX
        LDAA    1,X
        INCA                            ; screen row = cell row + 1
        TAB
        ASLA
        ASLA
        ABA                             ; A = 5 * row
        CLRB
        ASLA
        ROLB
        ASLA
        ROLB
        ASLA
        ROLB
        ASLA
        ROLB                            ; B:A = 80 * row
        ADDA    3,X
        ADCB    #$80                    ; + CRTRAM + column
        STAA    ADR+1
        STAB    ADR
        CMPB    8,X
        BNE     ED1
        CMPA    9,X
        BEQ     ED2
ED1     LDAA    8,X
        BEQ     ED2
        LDX     8,X
        LDAA    #$20
        JSR     PUTCH
        LDX     SAVX
ED2     LDAA    ADR
        STAA    8,X
        LDAA    ADR+1
        STAA    9,X
        LDAA    10,X
        LDX     ADR
        JSR     PUTCH
        LDX     SAVX
        RTS

; ENTKILL   X -> record: erase its glyph, mark free.  X preserved.
ENTKILL STX     SAVX
        LDAA    8,X
        BEQ     EK1
        LDX     8,X
        LDAA    #$20
        JSR     PUTCH
EK1     LDX     SAVX
        CLR     0,X
        CLR     8,X
        RTS

; UPDENT    move + redraw every rock and bullet; bullets age out
UPDENT  LDX     #ROCKS
UE1     LDAA    0,X
        BEQ     UE3
        CMPA    #4
        BNE     UE2
        LDAA    7,X
        DECA
        STAA    7,X
        BNE     UE2
        BSR     ENTKILL
        BRA     UE3
UE2     JSR     ENTMOVE
        BSR     ENTDRAW
UE3     JSR     NXT16
        BNE     UE1
        RTS

; RNDVEL    X -> record: random velocity, speed grows with rock type
RNDVEL  JSR     RND
        STAA    TD
        ANDA    #$0F
        ADDA    #14
        LDAB    0,X
        ASLB
        STAB    TE
        ASLB
        ADDB    TE
        ABA                             ; 14 + (0..15) + 6 * type
        LDAB    WAVE
        ANDB    #7
        ABA                             ; faster every wave
        LDAB    TD
        BITB    #$10
        BEQ     RV1
        NEGA
RV1     STAA    6,X
        JSR     RND
        STAA    TD
        ANDA    #$07
        ADDA    #8
        LDAB    TD
        BITB    #$10
        BEQ     RV2
        NEGA
RV2     STAA    5,X
        RTS

; ============================================================================
; keyboard
; ============================================================================
; SCANKEYS   KEYS = bit mask of the game keys currently down
SCANKEYS CLR    KEYS
        LDX     #KTAB
SK1     LDAA    0,X
        BEQ     SK3
        STAA    PIA1
        LDAB    PIA1
        BPL     SK2
        LDAA    1,X
        ORAA    KEYS
        STAA    KEYS
SK2     INX
        INX
        BRA     SK1
SK3     RTS

; KEYREP   A = key down flag, X -> repeat counter, B = repeat interval.
;          returns A <> 0 when the action fires: on the press, then after
;          the interval + 5 ticks, then every interval ticks.
KEYREP  TSTA
        BEQ     KR4
        LDAA    0,X
        BEQ     KR2
        DECA
        BNE     KR3
        STAB    0,X
        LDAA    #1
        RTS
KR2     ADDB    #5
        STAB    0,X
        LDAA    #1
        RTS
KR3     STAA    0,X
        CLRA
        RTS
KR4     CLR     0,X
        RTS

; ============================================================================
; ship
; ============================================================================
; ACCEL   A = accel (signed), X -> velocity byte, TB = limit
ACCEL   ADDA    0,X
        CMPA    TB
        BLE     AC1
        LDAA    TB
        BRA     AC3
AC1     LDAB    TB
        NEGB
        CBA
        BGE     AC3
        TBA
AC3     STAA    0,X
        RTS

; THR     TS = +1 thrust / $FF reverse
THR     JSR     GETDIR
        PSHB
        LDAB    #4
        JSR     SCALE
        TST     TS
        BPL     TH1
        NEGA
TH1     LDX     #SHIP+6
        LDAB    #56
        STAB    TB
        BSR     ACCEL
        PULA
        LDAB    #2
        JSR     SCALE
        TST     TS
        BPL     TH2
        NEGA
TH2     LDX     #SHIP+5
        LDAB    #28
        STAB    TB
        BSR     ACCEL
        RTS

; FIRE    spawn a bullet from the ship in the facing direction
FIRE    LDX     #BULS
FI1     LDAA    0,X
        BEQ     FI2
        JSR     NXT16
        BNE     FI1
        RTS
FI2     STX     BP
        LDAA    #4
        STAA    0,X
        LDAA    SHIP+1
        STAA    1,X
        LDAA    SHIP+3
        STAA    3,X
        LDAA    #$80
        STAA    2,X
        STAA    4,X
        LDAA    #28
        STAA    7,X
        LDAA    #$0C
        STAA    10,X
        CLR     8,X
        JSR     GETDIR
        PSHB
        LDAB    #110
        JSR     SCALE
        LDX     BP
        STAA    6,X
        PULA
        LDAB    #55
        JSR     SCALE
        LDX     BP
        STAA    5,X
        RTS

SHIPINIT LDX    #SHIP
        LDAA    #5
        STAA    0,X
        LDAA    #11
        STAA    1,X
        LDAA    #40
        STAA    3,X
        LDAA    #1
        STAA    10,X
        CLRA
        STAA    FACE
        STAA    2,X
        STAA    4,X
        STAA    5,X
        STAA    6,X
        STAA    8,X
        STAA    9,X
        RTS

SHIPTICK LDAA   INV
        BEQ     ST0
        DECA
        STAA    INV
ST0     LDX     #CNTL
        LDAA    KEYS
        ANDA    #1
        LDAB    #3
        JSR     KEYREP
        TSTA
        BEQ     ST1
        LDAA    FACE
        DECA
        ANDA    #7
        STAA    FACE
        INCA
        STAA    SHIP+10
ST1     LDX     #CNTR
        LDAA    KEYS
        ANDA    #2
        LDAB    #3
        JSR     KEYREP
        TSTA
        BEQ     ST2
        LDAA    FACE
        INCA
        ANDA    #7
        STAA    FACE
        INCA
        STAA    SHIP+10
ST2     LDAA    KEYS
        ANDA    #4
        BEQ     ST3
        LDAA    #1
        STAA    TS
        JSR     THR
ST3     LDAA    KEYS
        ANDA    #8
        BEQ     ST4
        LDAA    #$FF
        STAA    TS
        JSR     THR
ST4     LDX     #CNTF
        LDAA    KEYS
        ANDA    #16
        LDAB    #6
        JSR     KEYREP
        TSTA
        BEQ     ST5
        JSR     FIRE
ST5     LDX     #SHIP
        JSR     ENTMOVE
        JSR     ENTDRAW
        LDAA    INV
        ANDA    #2
        BEQ     ST6
        LDX     SHIP+8
        LDAA    #$20
        JSR     PUTCH
ST6     RTS

; ============================================================================
; collisions
; ============================================================================
; ROCKHIT   RP -> rock that was hit: score, split into two smaller rocks
ROCKHIT LDX     RP
        LDAA    0,X
        STAA    TC
        LDAB    #2
        CMPA    #1
        BEQ     RH1
        LDAB    #5
        CMPA    #2
        BEQ     RH1
        LDAB    #$10
RH1     LDAA    SCH
        STAA    TD
        LDAA    SCL
        ABA
        DAA
        STAA    SCL
        LDAA    SCH
        ADCA    #0
        DAA
        STAA    SCH
        EORA    TD
        ANDA    #$F0                    ; every 10,000 points: extra ship
        BEQ     RH5
        LDAA    LIVES
        CMPA    #9
        BCC     RH5
        INCA
        STAA    LIVES
RH5     LDAA    #1
        STAA    HUDF
        LDAA    1,X
        STAA    TA
        LDAA    3,X
        STAA    TB
        JSR     ENTKILL
        LDAA    TC
        CMPA    #3
        BEQ     RH9                     ; small rock: gone
        INCA
        STAA    TC                      ; child type
        BSR     RH2                     ; child 1 reuses the slot
        LDX     #ROCKS
RH3     LDAA    0,X
        BEQ     RH4
        JSR     NXT16
        CPX     #BULS
        BNE     RH3
RH9     RTS
; child 2 goes into a free slot (RH4 falls into RH2)
RH4
RH2     LDAA    TC
        STAA    0,X
        ADDA    #8
        STAA    10,X
        LDAA    TA
        STAA    1,X
        LDAA    TB
        STAA    3,X
        LDAA    #$80
        STAA    2,X
        STAA    4,X
        CLR     8,X
        JSR     RNDVEL
        JSR     ENTDRAW
        RTS

; COLLIDE   bullets against rocks
COLLIDE LDX     #BULS
CB1     LDAA    0,X
        BEQ     CB9
        STX     BP
        LDAA    1,X
        STAA    TA
        LDAA    3,X
        STAA    TB
        LDX     #ROCKS
CB2     LDAA    0,X
        BEQ     CB4
        LDAA    1,X
        CMPA    TA
        BNE     CB4
        LDAA    3,X
        SUBA    TB
        INCA
        CMPA    #2
        BHI     CB4
        STX     RP
        JSR     ROCKHIT
        LDX     BP
        JSR     ENTKILL
        BRA     CB9
CB4     JSR     NXT16
        CPX     #BULS
        BNE     CB2
        LDX     BP
CB9     JSR     NXT16
        BNE     CB1
        RTS

; SHIPCOL   rock on the ship's cell kills the ship (not while invulnerable)
SHIPCOL LDAA    INV
        BNE     SC9
        LDX     #ROCKS
SC1     LDAA    0,X
        BEQ     SC2
        LDAA    1,X
        CMPA    SHIP+1
        BNE     SC2
        LDAA    3,X
        CMPA    SHIP+3
        BEQ     SHIPDIE
SC2     JSR     NXT16
        CPX     #BULS
        BNE     SC1
SC9     RTS

SHIPDIE LDX     SHIP+8
        LDAA    #$2A                    ; '*' explosion marker
        JSR     PUTCH
        CLR     SHIP
        LDAA    #2
        STAA    STATE
        LDAA    #50
        STAA    TIMER
        LDAA    LIVES
        DECA
        STAA    LIVES
        LDAA    #1
        STAA    HUDF
        RTS

HICHK   LDAA    SCH
        CMPA    HIH
        BHI     HI1
        BNE     HI9
        LDAA    SCL
        CMPA    HIL
        BLS     HI9
HI1     LDAA    SCH
        STAA    HIH
        LDAA    SCL
        STAA    HIL
HI9     RTS

DEADTICK LDAA   TIMER
        DECA
        STAA    TIMER
        BNE     DT9
        LDX     SHIP+8
        LDAA    #$20
        JSR     PUTCH
        LDAA    LIVES
        BNE     DT1
        LDAA    #3
        STAA    STATE
        JSR     HICHK
        LDAA    #1
        STAA    HUDF
        LDX     #STRGO
        JMP     PRSTR
DT1     JSR     SHIPINIT
        LDAA    #1
        STAA    STATE
        LDAA    #60
        STAA    INV
DT9     RTS

; ============================================================================
; waves
; ============================================================================
CNTROCK LDX     #ROCKS
CR1     LDAA    0,X
        BNE     CR9
        JSR     NXT16
        CPX     #BULS
        BNE     CR1
        CLRA
CR9     RTS

NEWWAVE LDAA    WAVE
        ADDA    #1
        DAA
        STAA    WAVE
        LDAB    #4
        CMPA    #4
        BHI     NW0
        TAB
NW0     ADDB    #2
        STAB    TF
        LDAA    #1
        STAA    HUDF
NW1     LDX     #ROCKS
NW2     LDAA    0,X
        BEQ     NW3
        JSR     NXT16
        CPX     #BULS
        BNE     NW2
        RTS
NW3     LDAA    #1
        STAA    0,X
        LDAA    #$09
        STAA    10,X
        JSR     RND
        ANDA    #$1F
        CMPA    #23
        BCS     NW4
        SUBA    #9
NW4     STAA    1,X
        JSR     RND
        LDAB    RNG
        ANDB    #$10
        ASLB
        ASLB
        ANDA    #$0F
        ABA
        STAA    3,X
        LDAA    #$80
        STAA    2,X
        STAA    4,X
        CLR     8,X
        JSR     RNDVEL
        JSR     ENTDRAW
        LDAA    TF
        DECA
        STAA    TF
        BNE     NW1
        RTS

; ============================================================================
; screen text
; ============================================================================
CLS     LDX     #CRTRAM
        LDAA    #$20
CL1     STAA    HALT
        NOP
        STAA    0,X
        INX
        CPX     #CRTRAM+1920
        BNE     CL1
        RTS

; PRSTR   X -> blocks of  FDB address, text, 0 ;  ends with a 0 byte
PRSTR   LDAA    0,X
        BEQ     PS9
        STAA    DST
        LDAA    1,X
        STAA    DST+1
        INX
        INX
PS1     LDAA    0,X
        INX
        TSTA
        BEQ     PRSTR
        STX     SAVX
        LDX     DST
        JSR     PUTCH
        STX     DST
        LDX     SAVX
        BRA     PS1
PS9     RTS

; PRBCD   A = two BCD digits -> screen at X
PRBCD   PSHA
        LSRA
        LSRA
        LSRA
        LSRA
        ADDA    #'0
        JSR     PUTCH
        PULA
        ANDA    #$0F
        ADDA    #'0
        JMP     PUTCH

STRHUD  FDB     CRTRAM+2
        FCC     "SCORE"
        FCB     0
        FDB     CRTRAM+16
        FCC     "HI"
        FCB     0
        FDB     CRTRAM+30
        FCC     "SHIPS"
        FCB     0
        FDB     CRTRAM+60
        FCC     "WAVE"
        FCB     0
        FCB     0
STRGO   FDB     CRTRAM+915
        FCC     "GAME OVER"
        FCB     0
        FDB     CRTRAM+1074
        FCC     "PRESS ENTER"
        FCB     0
        FCB     0

HUD     LDX     #STRHUD
        BSR     PRSTR
        LDX     #CRTRAM+8
        LDAA    SCH
        BSR     PRBCD
        LDAA    SCL
        BSR     PRBCD
        LDAA    #'0
        JSR     PUTCH
        LDX     #CRTRAM+19
        LDAA    HIH
        JSR     PRBCD
        LDAA    HIL
        JSR     PRBCD
        LDAA    #'0
        JSR     PUTCH
        LDX     #CRTRAM+36
        LDAB    LIVES
        BEQ     HU2
HU1     LDAA    #1
        JSR     PUTCH
        DECB
        BNE     HU1
HU2     LDAA    #$20
        JSR     PUTCH
        JSR     PUTCH
        JSR     PUTCH
        LDX     #CRTRAM+65
        LDAA    WAVE
        JMP     PRBCD

; ---- text: FDB screen-address, text, 0 ... FCB 0 --------------------------
STRTITLE FDB    CRTRAM+351
        FCC     "A S T E R O I D S"
        FCB     0
        FDB     CRTRAM+506
        FCC     "FOR THE LEAR SIEGLER ADM-31"
        FCB     0
        FDB     CRTRAM+827
        FCC     "A / D    ROTATE"
        FCB     0
        FDB     CRTRAM+907
        FCC     "W        THRUST"
        FCB     0
        FDB     CRTRAM+987
        FCC     "S        REVERSE"
        FCB     0
        FDB     CRTRAM+1067
        FCC     "SPACE    FIRE"
        FCB     0
STRPLAY FDB     CRTRAM+1390
        FCC     "PRESS ENTER TO PLAY"
        FCB     0
        FCB     0


; ============================================================================
; main
; ============================================================================
START   SEI
        LDS     #$01FF
        CLR     SEED
        CLR     HIH
        CLR     HIL
        JSR     CLS
        LDX     #STRTITLE
        JSR     PRSTR
        LDX     #STRPLAY
        JSR     PRSTR
TW1     INC     SEED
        JSR     SCANKEYS
        LDAA    KEYS
        ANDA    #32
        BEQ     TW1
        LDAA    SEED
        ORAA    #1
        STAA    RNG

NEWGAME JSR     CLS
        CLRA
        STAA    SCH
        STAA    SCL
        STAA    WAVE
        STAA    CNTL
        STAA    CNTR
        STAA    CNTF
        LDX     #ROCKS
NG1     STAA    0,X
        INX
        CPX     #SHIP+16
        BNE     NG1
        LDAA    #3
        STAA    LIVES
        LDAA    #1
        STAA    STATE
        LDAA    #60
        STAA    INV
        JSR     SHIPINIT
        JSR     NEWWAVE

MAIN    JSR     SCANKEYS
        LDAA    STATE
        CMPA    #1
        BEQ     M1
        CMPA    #2
        BEQ     M2
        LDAA    KEYS
        ANDA    #32
        BNE     NEWGAME_J
        BRA     M4
M1      JSR     SHIPTICK
        BRA     M4
M2      JSR     DEADTICK
M4      JSR     UPDENT
        JSR     COLLIDE
        LDAA    STATE
        CMPA    #1
        BNE     M5X
        JSR     SHIPCOL
        JSR     CNTROCK
        BNE     M5
        JSR     NEWWAVE
        BRA     M5
M5X     CMPA    #2
        BNE     M5
        LDX     SHIP+8
        LDAA    #$2A
        LDAB    TIMER
        BITB    #4
        BEQ     M5Y
        LDAA    #$20
M5Y     JSR     PUTCH
M5      LDAA    HUDF
        BEQ     M6
        CLR     HUDF
        JSR     HUD
M6      LDX     #TICKDLY
M7      DEX
        BNE     M7
        BRA     MAIN

NEWGAME_J JMP   NEWGAME

        ORG     $E7FF
        FCB     $FF
        END
