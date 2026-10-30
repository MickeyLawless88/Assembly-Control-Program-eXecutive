* ======================================================================
* D13ROM.ASM - A COMPLETE 2K ROM IMAGE:  $F800-$FFFF
*
* The 6800 fetches its reset address from $FFFE/$FFFF, so a ROM that ends at
* the top of memory carries the vectors in its last 8 bytes:
*      $FFF8 IRQ   $FFFA SWI   $FFFC NMI   $FFFE RESET
* ORG $F800 first means NAME.BIN is exactly 2048 bytes, ready for a 2716.
* Use the "PAD BINARY TO SIZE" question when the code ends short of the top
* and you want the file filled with $FF to a full ROM size instead.
*
* EXPECT F800: 8E 01 FF 0E 20 FE
* EXPECT FFF8: F8 06 F8 06 F8 06 F8 00
* EXPECT-S9 F800
* EXPECT-BIN F800 2048
* ======================================================================
STACK   EQU   $01FF
        ORG   $F800
RESET   LDS   #STACK            ; 8E 01 FF
        CLI                     ; 0E  enable interrupts
HERE    BRA   HERE              ; 20 FE  idle loop
IRQ     RTI
        ORG   $FFF8
        FDB   IRQ,IRQ,IRQ,RESET ; IRQ, SWI, NMI share the handler
        END
