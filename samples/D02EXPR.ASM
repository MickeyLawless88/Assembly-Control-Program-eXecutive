* ======================================================================
* D02EXPR.ASM - OPERAND EXPRESSIONS
*
* NOTE: inside FCB/DB a quote starts a STRING, so write FCB "A" (or $41),
* not FCB 'A.  The 'A form works in instructions:  LDAA #'A.
*
* A term is one of:   1234 decimal   $FF00 hex   %1010 binary   'A character
*                     NAME (label or EQU)   * (current address)
* Terms are joined with + and - and evaluated strictly LEFT TO RIGHT.
* There are NO parentheses, NO precedence, NO * / & | operators, and no
* high/low-byte operators: to get the high byte of an address use a data
* word (FDB) or LDX #label / STX.  Results are 16 bits: -1 is $FFFF.
*
* EXPECT 0200: CE 10 00 CE 10 0E 86 41 86 0F 86 0F 86 F0 86 FF 86 61
* EXPECT 0212: CE 02 12 CE 02 1B 20 FE 20 00 CE FF FF FF 01 41 61
* ======================================================================
BASE    EQU   $1000
SIZE    EQU   16
TOP     EQU   BASE+SIZE         EQU may use expressions: $1010
        ORG   $0200
        LDX   #BASE             16-bit immediate        CE 10 00
        LDX   #TOP-2            symbol arithmetic       CE 10 0E
        LDAA  #'A               character constant      86 41
        LDAA  #%00001111        binary                  86 0F
        LDAA  #10+5             decimal sum             86 0F
        LDAA  #$FF-$0F          hex difference          86 F0
        LDAA  #$ff              hex digits any case     86 FF
        LDAA  #'a               lower case char = $61   86 61
        LDX   #*                '*' = this instruction  CE 02 12
        LDX   #*+6              "here + 6"              CE 02 1B
        BRA   *                 branch to itself        20 FE
        BRA   *+2               to the next instruction 20 00
        LDX   #-1               wraps to 16 bits        CE FF FF
        FCB   -1,255+2,"Aa"     ; expressions and a string       FF 01 41 61
        END
