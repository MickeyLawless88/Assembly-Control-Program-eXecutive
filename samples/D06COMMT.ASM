* ======================================================================
* D06COMMT.ASM - THE WAYS TO WRITE A COMMENT
*
*  1. '*' or ';' in COLUMN 1 makes the whole line a comment.
*  2. After a normal instruction, anything following the operand (after a
*     blank) is ignored - ';' is optional there.
*  3. After an INHERENT instruction (NOP, RTS, INCA ...) everything is ignored.
*  4. On FCB/DB/FDB/DW/FCC lines the comment MUST begin with ';' because the
*     whole rest of the line is data. Quoted text may contain ';' safely.
*  5. A label alone on a line may not have a comment after it.
*
* EXPECT 0600: 01 86 01 01 02 41 20 42 3B 7E 39
* ======================================================================
; this semicolon comment is in column 1
        ORG   $0600
        NOP                     no ';' needed after an inherent op
        LDAA  #1                text after the operand is a comment
        FCB   1,2               ; data lines need the semicolon
        FCC   "A B"             ; spaces inside the string are data
        FCB   ";"               ; a ';' inside quotes is data (3B)
        FCB   $7E,$39           ; plain bytes
        END
