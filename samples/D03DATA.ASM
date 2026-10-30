* ======================================================================
* D03DATA.ASM - DATA DIRECTIVES:  FCB/DB  FDB/DW  FCC  RMB  EQU
*
*   FCB list   bytes; items may be numbers, expressions or "strings"
*   DB         same as FCB             FDB list  16-bit words, HIGH byte first
*   DW         same as FDB             FCC /text/  characters, any delimiter
*   RMB n      reserve n bytes (no object code; the address just advances)
*
* On FCB/DB/FDB/DW/FCC lines the whole rest of the line is data, so a
* comment MUST start with ';'.  Inside "..." the escapes \n \r \t \\ \" \'
* are understood.  A line may hold up to about 127 characters of data.
*
* EXPECT 0300: 01 02 03 41 42 43 0D 12 34 03 00 03 09 48 45 4C 4C 4F 41 20 42
* EXPECT 0319: 99 41 0A 09 42 5C 22
* ======================================================================
        ORG   $0300
B1      FCB   1,2,3             ; plain bytes                   0300
B2      DB    $41,"BC",$0D      ; numbers and a string mixed    0303
W1      FDB   $1234,B1          ; words: $1234 and address B1   0307
W2      DW    W1+2              ; a word holding W1+2 = $0309   030B
TXT     FCC   "HELLO"           ; FCC: no terminator added      030D
SP3     FCC   /A B/             ; any delimiter, spaces ok      0312
BUF     RMB   4                 ; 4 reserved bytes: 0315-0318   0315
NEXT    FCB   $99               ; address continues at 0319
ESC     FCB   "A\n\tB\\\""      ; A LF TAB B backslash quote
        END
