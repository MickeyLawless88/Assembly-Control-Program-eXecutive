* ======================================================================
* D04BRNCH.ASM - BRANCHES ARE RELATIVE:  -128 ... +127 BYTES
*
* Every branch assembles to  opcode, offset  where
*       offset = target - (address of the branch + 2)
* The offset must fit a signed byte or acpx reports BRANCH OUT OF RANGE.
* For a longer jump branch over a JMP (a "trampoline"), see the end.
*
*   BRA 20  BHI 22  BLS 23  BCC 24  BCS 25  BNE 26  BEQ 27  BVC 28
*   BVS 29  BPL 2A  BMI 2B  BGE 2C  BLT 2D  BGT 2E  BLE 2F  BSR 8D
*
* EXPECT 0400: 20 00 22 00 23 00 24 00 25 00 26 00 27 00 28 00
* EXPECT 0410: 29 00 2A 00 2B 00 2C 00 2D 00 2E 00 2F 00
* EXPECT 041E: 20 FE 20 FC 8D 00 20 7F 20 80
* EXPECT 042C: 26 03 7E 04 00 39
* ======================================================================
        ORG   $0400
        BRA   *+2               ; offset 0 = the next instruction
        BHI   *+2
        BLS   *+2
        BCC   *+2
        BCS   *+2
        BNE   *+2
        BEQ   *+2
        BVC   *+2
        BVS   *+2
        BPL   *+2
        BMI   *+2
        BGE   *+2
        BLT   *+2
        BGT   *+2
        BLE   *+2
        BRA   *                 ; branch to itself (offset FE = -2)
        BRA   *-2              ; backwards: 2 bytes before this one (FC)
        BSR   *+2               ; branch to subroutine, same encoding
        BRA   *+129             ; the longest forward branch  (+127 = 7F)
        BRA   *-126             ; the longest backward branch (-128 = 80)
        FCB   $FF,$FF,$FF,$FF   ; padding
*
* "long branch" idiom: invert the condition and hop over a JMP
        BNE   SKIP              ; condition false -> skip the JMP  26 03
        JMP   FAR               ; ...condition true: JMP reaches anywhere
SKIP    RTS
FAR     EQU   $0400
        END
