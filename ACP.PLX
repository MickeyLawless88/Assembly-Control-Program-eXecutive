/* ACP.PLX  -  acpx startup script (PL/X)
 * PL/X language by Mickey W. Lawless.  Run:  acpx            (loads ACP.PLX)
 *                                            acpx -c FILE.PLX
 * Blocks: BANNER runs after login; MENUHDR prints above every ACP menu;
 *         GOODBYE runs on BYE / option 5.  Everything is optional.        */

VAR(DECLARATION)
{
    ASSIGN ACT.EQ.'LSI01'
    ASSIGN ACTPW.EQ.'21121'
    ASSIGN MON.EQ.SYSMON
    ASSIGN INT DAY.EQ.SYSDAY
    ASSIGN INT YEAR.EQ.SYSYEAR
    ASSIGN INT USRNO.EQ.4100
    ASSIGN INT PORTNO.EQ.7
    ASSIGN INT TRIES.EQ.0
    ASSIGN INT MAXTRY.EQ.3
    ASSIGN INT SKIPHDR.EQ.0
    END(DECLARATION)
}

'\n'
*PROMPT1*["ACCOUNT-ID: ",AID:5A1],'\n'
 IF(AID == ACT) THEN PROCEED *PROMPT2*
 TRIES = TRIES + 1
 IF(TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
 "INVALID ACCOUNT-ID",'\n'
 RET *PROMPT1*

*PROMPT2*["PASSWORD: ",PAS:5H1],"  ",DATE=[MON,"/",DAY,"/",YEAR],'\n'
 IF(PAS == ACTPW) THEN PROCEED *WELCOME*
 TRIES = TRIES + 1
 IF(TRIES >= MAXTRY) HALT "TOO MANY ATTEMPTS - DISCONNECTED",'\n'
 "INVALID PASSWORD",'\n'
 RET *PROMPT1*

*WELCOME*
BANNER
{
    "       GOOD DAY USER ",I4,"  PORT ",I1,'\n'
&   "           WELCOME TO THE WONDERFUL WORLD OF 'MICOS'",'\n'
&   "*************************************************************",'\n'
&   "BELIEVE NOTHING YOU HEAR, AND ONLY ONE HALF THAT YOU SEE",'\n'
&   "*************************************************************",'\n'
&   "##",'\n'
&   "RUN'ACP'",'\n'
&   "(ADM-ACP / ASSEDIT, MOTOROLA 6800 ASM)  V",VERSION,'\n'
&   "=============================================================",'\n'
&   'ENTER "BYE" AT THE ACP PROMPT TO DISCONNECT.','\n'
    BANNER<END>
}

MENUHDR
{
    '\n',"'ACP' AT YOUR SERVICE - CHOOSE YOUR OPTION.",'\n'
&   "=============================================================",'\n'
}

GOODBYE
{
    "##",'\n',"SIGNED OFF.",'\n'
}
