; LINECFG          ADM-31 plugin ROM ($E000-$E7FF), 129867 firmware family
;
; "ADMENU" -- lettered direct-command line configuration menu, per
; Mickey's own sketch. Each letter performs its action immediately
; (sends the real ESC sequence, or updates internal state) and
; redraws, rather than staging changes behind a separate confirm step.
;
; What's real vs. stubbed, honestly:
;   A/B (conversation/block), C/D (half/full duplex), J (personality
;   prefix) -- confirmed: sent as real ESC sequences through stock
;   firmware's own processor via the traced zero-page vector ($67).
;   E/F/G (parity/data bits/stop bits) -- confirmed mechanism, but NOT
;   independent: the MC6850 ACIA at $7A00 packs all three into one
;   3-bit word-select field with exactly 8 valid combinations (no
;   "7 data bits, no parity" exists on this chip). E/F/G each step
;   through that same shared set; changing one can visibly change the
;   other two on screen, because on the real hardware it does.
;   H (baud rate) -- NOT implemented. Tracing the ACIA init sequence
;   just now showed the counter-divide bits (the ones that actually
;   select baud) are hardcoded by stock firmware, not switch- or
;   software-selected at all -- baud is very likely set by an external
;   clock source this ROM has no path to control. Menu entry present,
;   marked "N/A" rather than faked.
;   I (local echo) -- stub. Likely a stock-firmware RAM flag, but its
;   location hasn't been traced.
;   K (execute polling/opt ROM) -- stub. Would need tracing how the
;   terminal's own polling-mode entry sequence works to replicate it.
;   L (show settings) -- shows this ROM's own tracked state, not a
;   live readback of stock firmware's internal state (untraced).
;   M (reset to defaults) -- resets tracked state and resends the
;   default ESC sequences.
;   Q added (not in the original sketch): quit without applying
;   anything further, straight back to normal terminal operation.
;
; =============================================================================
; HARDWARE I/O
; =============================================================================
HALT            EQU     $7000
PIA1            EQU     $7800
PIA1B           EQU     $7802
ACIA            EQU     $7A00
CRTRAM          EQU     $8000
SCRW            EQU     80
SCRH            EQU     24
CRTEND          EQU     $8780           ; CRTRAM + SCRW*SCRH -- pre-computed,
; NOT left as an expression (this
; assembler does not apply operator
; precedence to "CRTRAM+SCRW*SCRH",
; confirmed by simulation)
ESCVEC          EQU     $67             ; zero-page vector to stock firmware's
; real ESC/char processor, set up by
; ROM B's own boot init -- confirmed
; by direct trace, not assumed

; =============================================================================
; ZERO PAGE -- menu state
; =============================================================================
CONVMODEV       EQU     $0121           ; 0=conversation, 1=block
DUPLEXV         EQU     $0122           ; 0=full, 1=half
WORDSELV        EQU     $0123           ; 0-7, MC6850 word-select index
; (shared by parity/data/stop)
PERSV           EQU     $0124           ; 0-9 personality digit
ECHOV           EQU     $0125           ; 0/1, local echo on/off
BAUDV           EQU     $012A           ; 0-2, ACIA counter-divide index
; (/1,/16,/64) -- honest divide-ratio labels, not fabricated baud
; numbers; real baud needs an external clock frequency not traced
GAMEINIT        EQU     $0126
DONEFLAG        EQU     $0127
FLASHMSG        EQU     $0128           ; 2 bytes -- pointer to a brief
; status string shown after the
; last action, or 0 for none

TMPA            EQU     $0130
TMPB            EQU     $0131
TMPX            EQU     $0132
ADRPTR          EQU     $0134
ROWARG          EQU     $0136
COLARG          EQU     $0137
STRPTR          EQU     $0138

; =============================================================================
; ADM-31 PLUGIN ROM HEADER
; =============================================================================
        ORG     $E000
        FCB     $54,$4A                 ; "TJ" plugin signature
KEYENTRY
        LDAB    GAMEINIT
        CMPB    #$A5
        BNE     KE_SKIP
        LDAB    DONEFLAG
        BNE     KE_SKIP
        PSHA
        JSR     KEYDISP
        PULA
KE_SKIP RTS

        ORG     $E03C
        JMP     RESET

; =============================================================================
SCRNOUT
        STAA    HALT
        NOP
        STAA    0,X
        RTS

        ORG     $E07D
PLUGCB2 RTS
        ORG     $E08A
ESCCB   RTS
        ORG     $E0CA
PLUGCB3 RTS

; =============================================================================
; ESCSEND -- send one character through stock firmware's real ESC/char
; processor via the confirmed zero-page vector. Character in A.
; =============================================================================
ESCSEND
        LDX     ESCVEC
        JSR     0,X
        RTS

; =============================================================================
; PRTSTR -- print a null-terminated string at X to (ROWARG, COLARG).
; =============================================================================
PRTSTR
        STX     STRPTR
PS_LOOP LDX     STRPTR
        LDAA    0,X
        BEQ     PS_DONE
        INX
        STX     STRPTR
        PSHA
        JSR     CALCADR
        PULA
        JSR     SCRNOUT
        INC     COLARG
        BRA     PS_LOOP
PS_DONE RTS

; RBORDER -- write a closing "|" at the fixed right-edge column (51),
; matching the top/bottom border width. Cheaper in bytes than padding
; every menu-item string out to that width with trailing spaces.
RBORDER
        LDAA    #51
        STAA    COLARG
        JSR     CALCADR
        LDAA    #$7C
        JSR     SCRNOUT
        RTS

; SETCURSOR -- position the real hardware cursor at (ROWARG, COLARG).
; Confirmed, not assumed: traced two live writes in stock ROM C where
; $7F0C is set to 79 (last column, 80-wide screen) and $7F0D is set to
; 23 (last row, 24-row screen) as part of end-of-line/end-of-screen
; wrap logic -- $7F0C=column, $7F0D=row, raw 0-indexed, same convention
; as this ROM's own COLARG/ROWARG. Without this, the real blinking
; cursor sits wherever stock firmware last left it (home position)
; the whole time this menu is up, unrelated to anything on screen.
SETCURSOR
        LDAA    COLARG
        STAA    $7F0C
        LDAA    ROWARG
        STAA    $7F0D
        RTS

; =============================================================================
; CALCADR -- (ROWARG, COLARG) -> CRTRAM address in X.
; =============================================================================
CALCADR
        CLR     ADRPTR
        LDAA    ROWARG
        STAA    ADRPTR+1
        ASL     ADRPTR+1
        ROL     ADRPTR
        ASL     ADRPTR+1
        ROL     ADRPTR
        ASL     ADRPTR+1
        ROL     ADRPTR
        ASL     ADRPTR+1
        ROL     ADRPTR
        LDAA    ADRPTR
        LDAB    ADRPTR+1
        PSHA
        PSHB
        ASL     ADRPTR+1
        ROL     ADRPTR
        ASL     ADRPTR+1
        ROL     ADRPTR
        PULB
        ADDB    ADRPTR+1
        STAB    ADRPTR+1
        PULA
        ADCA    ADRPTR
        STAA    ADRPTR
        LDAA    COLARG
        ADDA    ADRPTR+1
        STAA    ADRPTR+1
        LDAA    ADRPTR
        ADCA    #0
        STAA    ADRPTR
        LDAA    ADRPTR
        ADDA    #$80
        STAA    ADRPTR
        LDX     ADRPTR
        RTS

; =============================================================================
CLRSCRN
        CLR     ROWARG
        CLR     COLARG
        LDX     #CRTRAM
CS_LOOP LDAA    #$20
        JSR     SCRNOUT
        INX
        CPX     #CRTEND
        BNE     CS_LOOP
        RTS

; =============================================================================
; KEYDISP -- direct lettered commands, each acting immediately.
; =============================================================================
KEYDISP
        CMPA    #$61                    ; 'a' -> conversation mode
        BNE     KD_B
        LDAA    #0
        STAA    CONVMODEV
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$43
        JSR     ESCSEND
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        JMP     KD_RDRAW
KD_B    CMPA    #$62                    ; 'b' -> block mode
        BNE     KD_C
        LDAA    #1
        STAA    CONVMODEV
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$42
        JSR     ESCSEND
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        JMP     KD_RDRAW
KD_C    CMPA    #$63                    ; 'c' -> half duplex
        BNE     KD_D
        LDAA    #1
        STAA    DUPLEXV
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$44
        JSR     ESCSEND
        LDAA    #$48
        JSR     ESCSEND
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        JMP     KD_RDRAW
KD_D    CMPA    #$64                    ; 'd' -> full duplex
        BNE     KD_E
        LDAA    #0
        STAA    DUPLEXV
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$44
        JSR     ESCSEND
        LDAA    #$46
        JSR     ESCSEND
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        JMP     KD_RDRAW
KD_E    CMPA    #$65                    ; 'e'/'f'/'g' -> step word-select
        BEQ     KD_WSEL
        CMPA    #$66
        BEQ     KD_WSEL
        CMPA    #$67
        BNE     KD_H
KD_WSEL LDAA    WORDSELV
        INCA
        ANDA    #7
        STAA    WORDSELV
        JSR     APPLYACIA
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        JMP     KD_RDRAW

; APPLYACIA -- compute and write the real ACIA control byte from
; WORDSELV and BAUDV. Verified against stock firmware's own computed
; value ($C0 | switch-word-select | fixed-divide) -- $C0 covers the two
; fixed bits (RXIE=1, transmit-control=10) that stock firmware also
; holds constant; only word-select and counter-divide vary here.
APPLYACIA
        LDAA    WORDSELV
        ASLA
        ASLA
        ORAA    #$C0
        ORAA    BAUDV
        STAA    ACIA
        RTS
KD_H    CMPA    #$68                    ; 'h' -> step clock divide
        BNE     KD_I
        LDAA    BAUDV
        INCA
        CMPA    #3
        BLT     KD_HST
        CLRA
KD_HST  STAA    BAUDV
        JSR     APPLYACIA
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        JMP     KD_RDRAW
KD_I    CMPA    #$69                    ; 'i' -> local echo on/off
        BNE     KD_J
        LDAA    ECHOV
        EORA    #1
        STAA    ECHOV
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        JMP     KD_RDRAW
KD_J    CMPA    #$6A                    ; 'j' -> step personality
        BNE     KD_K
        LDAA    PERSV
        INCA
        CMPA    #10
        BLT     KD_JST
        CLRA
KD_JST  STAA    PERSV
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$4F
        JSR     ESCSEND
        LDAA    PERSV
        ADDA    #$30
        JSR     ESCSEND
        LDX     #MSGPERS
        JSR     SETFLASH
        JMP     KD_RDRAW
KD_K    CMPA    #$6B                    ; 'k' -> execute polling (stub)
        BNE     KD_L
        LDX     #MSGNOPOLL
        JSR     SETFLASH
        JMP     KD_RDRAW
KD_L    CMPA    #$6C                    ; 'l' -> show settings (redraw
        BNE     KD_M                    ; already shows tracked state)
        LDX     #MSGSHOWN
        JSR     SETFLASH
        JMP     KD_RDRAW
KD_M    CMPA    #$6D                    ; 'm' -> reset to defaults
        BNE     KD_Q
        JSR     SETDEFLT
        LDX     #MSGRESET
        JSR     SETFLASH
        JMP     KD_RDRAW
KD_Q    CMPA    #$71                    ; 'q' -> quit without applying
        BNE     KD_T
        JSR     CLRSCRN
        LDAA    #11
        STAA    ROWARG
        LDAA    #28
        STAA    COLARG
        LDX     #EXITMSG
        JSR     PRTSTR
        LDAA    #1
        STAA    DONEFLAG
        BRA     KD_DONE
KD_T    CMPA    #$74                    ; 't' -> enter terminal mode:
        BNE     KD_DONE                ; jump to stock firmware's own
; real post-self-test hand-off
; ($E9D5: prints "Test Complete",
; does its own PIA1B/SW_BNK1
; setup, falls into the real
; vector-table init at $EC00 --
; confirmed by direct trace, the
; same code path a real boot
; takes, not a guessed re-entry)
        JSR     CLRSCRN
        LDAA    #1
        STAA    DONEFLAG
        JMP     $E9D5
KD_RDRAW
        JSR     DRAWMENU
KD_DONE RTS

; SETFLASH -- X = pointer to a status string, remembered for the next
; DRAWMENU to show at the bottom of the screen.
SETFLASH
        STX     FLASHMSG
        RTS

; SETDEFLT -- reset tracked state to defaults (full duplex, conversation
; mode, 8N1, personality 0) and resend the corresponding ESC sequences.
SETDEFLT
        CLR     CONVMODEV
        CLR     DUPLEXV
        LDAA    #5                      ; index 101 = 8N1
        STAA    WORDSELV
        LDAA    #1
        STAA    BAUDV
        CLR     PERSV
        CLR     ECHOV
        JSR     APPLYACIA
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$43
        JSR     ESCSEND
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$44
        JSR     ESCSEND
        LDAA    #$46
        JSR     ESCSEND
        LDAA    #$1B
        JSR     ESCSEND
        LDAA    #$4F
        JSR     ESCSEND
        LDAA    #$30
        JSR     ESCSEND
        RTS

; =============================================================================
; DRAWMENU -- the bordered ADMenu screen.
; =============================================================================
DRAWMENU
        JSR     CLRSCRN

        LDAA    #1
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #BORDERT
        JSR     PRTSTR

        LDAA    #2
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #TITLE1
        JSR     PRTSTR
        LDAA    #3
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #TITLE2
        JSR     PRTSTR
        LDAA    #4
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #BORDERM
        JSR     PRTSTR

        LDAA    #5
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_A
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #6
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_B
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #7
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_C
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #8
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_D
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #9
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_E
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #10
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_F
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #11
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_G
        JSR     PRTSTR
        LDAA    WORDSELV
        ASLA
        ASLA                            ; A = WORDSELV*4 (each FMTTBL
; entry is exactly 4 bytes: 3
; chars + null)
        LDX     #FMTTBL
        STX     ADRPTR
        ADDA    ADRPTR+1
        STAA    ADRPTR+1
        LDAA    ADRPTR
        ADCA    #0
        STAA    ADRPTR
        LDX     ADRPTR
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #12
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_H
        JSR     PRTSTR
        LDAA    BAUDV
        ASLA
        ASLA                            ; A = BAUDV*4 (each BAUDTBL
; entry is 4 bytes: 3 chars +
; null, same layout as FMTTBL)
        LDX     #BAUDTBL
        STX     ADRPTR
        ADDA    ADRPTR+1
        STAA    ADRPTR+1
        LDAA    ADRPTR
        ADCA    #0
        STAA    ADRPTR
        LDX     ADRPTR
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #13
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_I
        JSR     PRTSTR
        LDX     #OFFSTR
        LDAA    ECHOV
        BEQ     DM_ECHO
        LDX     #ONSTR
DM_ECHO JSR     PRTSTR
        JSR     RBORDER
        LDAA    #14
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_J
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #15
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_K
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #16
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_L
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #17
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_M
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #18
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_Q
        JSR     PRTSTR
        JSR     RBORDER
        LDAA    #19
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #LN_T
        JSR     PRTSTR
        JSR     RBORDER

        LDAA    #20
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #BORDERM
        JSR     PRTSTR

        LDX     FLASHMSG
        BEQ     DM_STAT
        LDAA    #21
        STAA    ROWARG
        LDAA    #11
        STAA    COLARG
        LDX     FLASHMSG
        JSR     PRTSTR
        BRA     DM_NOFL
DM_STAT LDAA    #21
        STAA    ROWARG
        LDAA    #11
        STAA    COLARG
        LDX     #STAT1
        JSR     PRTSTR
        LDX     #STATCV
        LDAA    CONVMODEV
        BEQ     DM_SC
        LDX     #STATBK
DM_SC   JSR     PRTSTR
        LDX     #STAT2
        JSR     PRTSTR
        LDX     #STATFL
        LDAA    DUPLEXV
        BEQ     DM_SD
        LDX     #STATHF
DM_SD   JSR     PRTSTR
DM_NOFL LDAA    #22
        STAA    ROWARG
        LDAA    #11
        STAA    COLARG
        LDX     #PROMPT
        JSR     PRTSTR
        JSR     SETCURSOR
        LDAA    #23
        STAA    ROWARG
        LDAA    #9
        STAA    COLARG
        LDX     #BORDERT
        JSR     PRTSTR
        RTS

; =============================================================================
; RESET
; =============================================================================
RESET
        CLR     DONEFLAG
        CLR     CONVMODEV
        CLR     DUPLEXV
        LDAA    #5
        STAA    WORDSELV
        LDAA    #1
        STAA    BAUDV                   ; default /16, matches stock
; firmware's own fixed value
        CLR     PERSV
        CLR     ECHOV
        CLR     FLASHMSG
        CLR     FLASHMSG+1
        LDAA    #$A5
        STAA    GAMEINIT
        JSR     APPLYACIA
        JSR     DRAWMENU

MAINLP  LDAB    DONEFLAG
        BNE     MAINLP
        JSR     POLLKEY
        BRA     MAINLP

; =============================================================================
KBDTAB  EQU     $EA1A

POLLKEY
        CLRB
PK_SCAN STAB    PIA1
        LDAA    PIA1
        BMI     PK_HIT
        INCB
        CMPB    #$58
        BNE     PK_SCAN
        RTS
PK_HIT  STAB    TMPB
        ASLB
        LDAA    PIA1B
        BPL     PK_NS
        INCB
PK_NS   LDX     #KBDTAB
        STX     ADRPTR
        ADDB    ADRPTR+1
        STAB    ADRPTR+1
        LDAA    ADRPTR
        ADCA    #0
        STAA    ADRPTR
        LDX     ADRPTR
        LDAA    0,X
        JSR     KEYDISP
        RTS

; =============================================================================
; DATA
; =============================================================================
BORDERT FCB     "+----------------------------------------+",0
BORDERM FCB     "+----------------------------------------+",0
TITLE1  FCB     "|              ADMENU  V1.0               |",0
TITLE2  FCB     "|          SYSTEM CONFIGURATION           |",0

LN_A    FCB     "| A) Conversation",0
LN_B    FCB     "| B) Block Mode",0
LN_C    FCB     "| C) Half Dplx",0
LN_D    FCB     "| D) Full Dplx",0
LN_E    FCB     "| E) Parity",0
LN_F    FCB     "| F) Data Bits",0
LN_G    FCB     "| G) Stop Bits   FMT: ",0
LN_H    FCB     "| H) Baud Rate   RATE: ",0
LN_I    FCB     "| I) Local Echo  ECHO: ",0
LN_J    FCB     "| J) Persnlty",0
LN_K    FCB     "| K) Polling (stub)",0
LN_L    FCB     "| L) ShowCfg",0
LN_M    FCB     "| M) Reset Defaults",0
LN_Q    FCB     "| Q)Quit",0
LN_T    FCB     "| T)Terminal",0
FMTTBL  FCB     "7E2",0,"7O2",0,"7E1",0,"7O1",0
        FCB     "8N2",0,"8N1",0,"8E1",0,"8O1",0
BAUDTBL FCB     "/1 ",0,"/16",0,"/64",0
ONSTR   FCB     "ON ",0
OFFSTR  FCB     "OFF",0
PROMPT  FCB     "> ",0
STAT1   FCB     "Mode: ",0
STATCV  FCB     "CONV",0
STATBK  FCB     "BLOCK",0
STAT2   FCB     "  Duplex: ",0
STATFL  FCB     "FULL",0
STATHF  FCB     "HALF",0

MSGPERS FCB     "advanced",0
MSGNOPOLL FCB   "not impl.",0
MSGSHOWN FCB    "shown above",0
MSGRESET FCB    "reset",0
EXITMSG FCB     "RETURNING TO NORMAL OPERATION",0

        ORG     $E7FE
        FCB     $FF,$FF
