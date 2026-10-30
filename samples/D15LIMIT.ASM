* ======================================================================
* D15LIMIT.ASM - LONG DATA LINES AND OTHER LIMITS
*
*  - One source line holds at most 127 characters.
*  - One FCB/FDB/FCC line may produce up to 130 object bytes (acpx 1.6; older
*    versions silently cut the data at 64 bytes and left zero bytes in the
*    image - keep lines below 64 bytes if you must use an old build).
*  - A file holds at most 3000 lines, 2000 symbols.
*  - Labels: 15 significant characters.   File names: 8.3, upper case.
*
* EXPECT 0F3C: 30 31 32 33 34 35 36 37 38 39 AA
* ======================================================================
        ORG   $0F00
L70     FCB   "0123456789","0123456789","0123456789","0123456789","0123456789","0123456789","0123456789"
AFTER   FCB   $AA               ; 70 bytes later: $0F46
        END
