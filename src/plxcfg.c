/* ========================================================================
 * plxcfg.c  -  PL/X configuration tool, sister program to acpx.
 *
 *   PLXCFG                    interactive menu
 *   PLXCFG NEW   FILE.PLX     wizard: writes a complete login + banner script
 *   PLXCFG CHECK FILE.PLX     syntax / label / block check
 *   PLXCFG RUN   FILE.PLX     run the script exactly as acpx would at startup
 *   PLXCFG CALL  FILE.PLX BLK run one block (MENUHDR, GOODBYE, ...)
 *   PLXCFG LINES FILE.PLX [DIGITS [Z|P]]   editor line-number format
 *
 * PL/X language designed by Mickey W. Lawless.  C89; shares plx.c with acpx.
 *     cc -ansi -pedantic -o plxcfg plxcfg.c        tcc plxcfg.c
 * ====================================================================== */
#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS 1
#endif
#include "plx.c"
#ifdef __TURBOC__
extern unsigned _stklen = 0x4000U;   /* Turbo C: 16K stack for the PL/X interpreter */
#endif

#define ACP_VERSION "1.5"

static int ask(const char *prompt, char *buf, int n, const char *dflt)
{
    int len;
    if (dflt && *dflt) printf("%s [%s]: ", prompt, dflt); else printf("%s: ", prompt);
    fflush(stdout);
    if (!fgets(buf, n, stdin)) return 0;
    len = (int)strlen(buf);
    while (len > 0 && (buf[len - 1] == '\n' || buf[len - 1] == '\r')) buf[--len] = '\0';
    if (!buf[0] && dflt) { strncpy(buf, dflt, (size_t)n - 1); buf[n - 1] = '\0'; }
    return 1;
}

/* ---- editor line-number format (LNWIDTH / LNZERO, read by acpx) --------- */
static void put_linenum(FILE *f, int w, int z)
{
    fprintf(f, "VAR(LINENUM)\n{\n    ASSIGN INT LNWIDTH.EQ.%d\n    ASSIGN INT LNZERO.EQ.%d\n    END(LINENUM)\n}\n", w, z);
}

static void ln_sample(int w, int z)
{
    static const int ex[3] = { 1, 2, 10 };
    char b[24]; int i;
    printf("  EDITOR LINES WILL BE NUMBERED:  ");
    for (i = 0; i < 3; i++) {
        if (z) sprintf(b, "%0*d", w, ex[i]); else sprintf(b, "%*d", w, ex[i]);
        printf("%s%s", b, i < 2 ? "   " : "   ...\n");
    }
}

static void ask_linenum(int *w, int *z)
{
    char b[16];
    printf("\nEditor line-number format  (plain = 1,2,3  padded: 2 digits = 01,02  5 digits = 00001)\n");
    ask("  Digits (1-9)", b, sizeof b, "5");
    *w = atoi(b);
    if (*w < 1 || *w > 9) { printf("  OUT OF RANGE - USING 5\n"); *w = 5; }
    ask("  Zero-pad (Y/N)", b, sizeof b, "N");
    *z = (b[0] == 'y' || b[0] == 'Y');
    ln_sample(*w, *z);
}

static int has_word(const char *line, const char *word)
{
    char up[260]; int i;
    for (i = 0; line[i] && i < 259; i++) up[i] = (char)toupper((unsigned char)line[i]);
    up[i] = '\0';
    return strstr(up, word) != NULL;
}

/* rewrite FILE.PLX: drop any old LNWIDTH/LNZERO/VAR(LINENUM) text, append a
 * fresh VAR(LINENUM) block.  The result is re-loaded; on any error the
 * original file is restored untouched.                                      */
static void cfg_lines(const char *path, const char *wa, const char *za)
{
    FILE *f; char *buf, *out; long n, o = 0; int w, z, skip = 0, crlf; char *p, *e;
    const char *eol;

    f = fopen(path, "rb");
    if (!f) { printf("CANNOT OPEN %s\n", path); return; }
    buf = (char *)malloc(PX_MAXSRC + 1);
    out = (char *)malloc(PX_MAXSRC + 400);
    if (!buf || !out) { fclose(f); printf("OUT OF MEMORY\n"); free(buf); free(out); return; }
    n = (long)fread(buf, 1, PX_MAXSRC, f);
    buf[n] = '\0';
    fclose(f);

    if (wa) {
        w = atoi(wa);
        if (w < 1 || w > 9) { printf("DIGITS MUST BE 1-9\n"); free(buf); free(out); return; }
        z = (za && (za[0] == 'z' || za[0] == 'Z' || za[0] == '0'));
        ln_sample(w, z);
    } else ask_linenum(&w, &z);

    crlf = (strchr(buf, '\r') != NULL);
    eol = crlf ? "\r\n" : "\n";
    for (p = buf; *p; p = e) {
        char ln[260]; int len, k;
        e = strchr(p, '\n');
        len = e ? (int)(e - p) : (int)strlen(p);
        e = e ? e + 1 : p + len;
        for (k = 0; k < len && k < 255; k++) ln[k] = p[k];
        ln[k] = '\0';
        while (k > 0 && (ln[k - 1] == '\r' || ln[k - 1] == ' ' || ln[k - 1] == '\t')) ln[--k] = '\0';
        if (skip) {
            if (strchr(ln, '}')) skip = 0;
            continue;
        }
        if (has_word(ln, "VAR(LINENUM)")) { if (!strchr(ln, '}')) skip = 1; continue; }
        if (has_word(ln, "LNWIDTH") || has_word(ln, "LNZERO")) continue;
        memcpy(out + o, p, (size_t)(e - p)); o += (long)(e - p);
    }
    if (o > 0 && out[o - 1] != '\n') { strcpy(out + o, eol); o += (long)strlen(eol); }
    o += sprintf(out + o, "%s", eol);
    o += sprintf(out + o, "VAR(LINENUM)%s{%s    ASSIGN INT LNWIDTH.EQ.%d%s    ASSIGN INT LNZERO.EQ.%d%s    END(LINENUM)%s}%s",
                 eol, eol, w, eol, z, eol, eol, eol);

    f = fopen(path, "wb");
    if (!f) { printf("CANNOT WRITE %s\n", path); free(buf); free(out); return; }
    fwrite(out, 1, (size_t)o, f);
    fclose(f);
    if (plx_load(path) != PLX_OK) {
        printf("%s\nRESULT DID NOT LOAD - RESTORING %s\n", plx_error(), path);
        f = fopen(path, "wb");
        if (f) { fwrite(buf, 1, (size_t)n, f); fclose(f); }
    } else {
        printf("%s: EDITOR LINE NUMBERS = %d DIGIT%s, %s\n", path, w, w == 1 ? "" : "S",
               z ? "ZERO-PADDED" : "PLAIN");
    }
    free(buf); free(out);
}

/* write text as a PL/X string item; %V -> VERSION, %D -> SYSDATE, %U -> user no */
static void put_item(FILE *f, const char *t)
{
    int open = 0, first = 1;
    for (; *t; t++) {
        if (t[0] == '%' && (t[1] == 'V' || t[1] == 'D' || t[1] == 'U')) {
            if (open) { fputc('"', f); open = 0; }
            if (!first) fputc(',', f);
            fputs(t[1] == 'V' ? "VERSION" : t[1] == 'D' ? "SYSDATE" : "USRNO:I4", f);
            first = 0; t++;
            continue;
        }
        if (!open) { if (!first) fputc(',', f); fputc('"', f); open = 1; first = 0; }
        if (*t == '"' || *t == '\\') { fputc('\\', f); fputc(*t, f); }
        else if (*t == 27) fputs("\\e", f);
        else fputc(*t, f);
    }
    if (open) fputc('"', f);
    if (first) fputs("\"\"", f);
}

static void read_block(const char *title, char lines[][100], int *n, int max)
{
    char b[100];
    *n = 0;
    printf("%s  (type // alone to finish; %%V=version %%D=date %%U=user no.)\n", title);
    while (*n < max && ask("  ", b, sizeof b, NULL)) {
        if (!strcmp(b, "//")) break;
        strcpy(lines[(*n)++], b);
    }
}

static void cfg_new(const char *path)
{
    static char ban[24][100], men[8][100];
    char act[40], pw[40], usr[16], port[16], tries[16], b[100], yn[8];
    int nb, nm, i, login, lw, lz;
    FILE *f;

    printf("\nPLXCFG - NEW ACP.PLX WIZARD  (writing %s)\n\n", path);
    ask("Require login (Y/N)", yn, sizeof yn, "Y");
    login = (yn[0] != 'n' && yn[0] != 'N');
    strcpy(act, "LSI01"); strcpy(pw, "21121"); strcpy(tries, "3");
    if (login) {
        ask("Account-ID", act, sizeof act, "LSI01");
        ask("Password", pw, sizeof pw, "21121");
        ask("Attempts before disconnect", tries, sizeof tries, "3");
    }
    ask("User number", usr, sizeof usr, "4100");
    ask("Port number", port, sizeof port, "7");
    ask_linenum(&lw, &lz);
    read_block("Banner text, shown after login", ban, &nb, 24);
    if (nb == 0) {
        strcpy(ban[nb++], "       GOOD DAY USER %U");
        strcpy(ban[nb++], "(ADM-ACP / ASSEDIT, MOTOROLA 6800 ASM)  V%V");
        strcpy(b, "");
    }
    read_block("Menu header, shown above every ACP menu (blank = built-in)", men, &nm, 8);

    for (i = 0; act[i]; i++) act[i] = (char)toupper((unsigned char)act[i]);
    for (i = 0; pw[i];  i++) pw[i]  = (char)toupper((unsigned char)pw[i]);
    f = fopen(path, "w");
    if (!f) { printf("CANNOT WRITE %s\n", path); return; }
    fprintf(f, "/* %s - generated by PLXCFG.  PL/X by Mickey W. Lawless. */\n\n", path);
    fprintf(f, "VAR(DECLARATION)\n{\n    ASSIGN ACT.EQ.'%s'\n    ASSIGN ACTPW.EQ.'%s'\n", act, pw);
    fprintf(f, "    ASSIGN MON.EQ.SYSMON\n    ASSIGN INT DAY.EQ.SYSDAY\n    ASSIGN INT YEAR.EQ.SYSYEAR\n");
    fprintf(f, "    ASSIGN INT USRNO.EQ.%ld\n    ASSIGN INT PORTNO.EQ.%ld\n", atol(usr), atol(port));
    fprintf(f, "    ASSIGN INT TRIES.EQ.0\n    ASSIGN INT MAXTRY.EQ.%ld\n    END(DECLARATION)\n}\n\n", atol(tries));
    put_linenum(f, lw, lz);
    fputc('\n', f);
    if (login) {
        fprintf(f, "*PROMPT1*[\"ACCOUNT-ID: \",AID:%dA1],'\\n'\n", (int)strlen(act) + 1);
        fprintf(f, " IF(AID == ACT) THEN PROCEED *PROMPT2*\n TRIES = TRIES + 1\n");
        fprintf(f, " IF(TRIES >= MAXTRY) HALT \"TOO MANY ATTEMPTS - DISCONNECTED\",'\\n'\n");
        fprintf(f, " \"INVALID ACCOUNT-ID\",'\\n'\n RET *PROMPT1*\n\n");
        fprintf(f, "*PROMPT2*[\"PASSWORD: \",PAS:%dH1],\"  \",DATE=[MON,\"/\",DAY,\"/\",YEAR],'\\n'\n", (int)strlen(pw) + 1);
        fprintf(f, " IF(PAS == ACTPW) THEN PROCEED *WELCOME*\n TRIES = TRIES + 1\n");
        fprintf(f, " IF(TRIES >= MAXTRY) HALT \"TOO MANY ATTEMPTS - DISCONNECTED\",'\\n'\n");
        fprintf(f, " \"INVALID PASSWORD\",'\\n'\n RET *PROMPT1*\n\n*WELCOME*\n");
    }
    fprintf(f, "BANNER\n{\n");
    for (i = 0; i < nb; i++) { fputs("    ", f); put_item(f, ban[i]); fputs(",'\\n'\n", f); }
    fprintf(f, "    BANNER<END>\n}\n");
    if (nm > 0) {
        fprintf(f, "\nMENUHDR\n{\n");
        for (i = 0; i < nm; i++) { fputs("    ", f); put_item(f, men[i]); fputs(",'\\n'\n", f); }
        fprintf(f, "}\n");
    }
    fclose(f);
    printf("\nWROTE %s - try:  PLXCFG CHECK %s   then   ACPX -c %s\n", path, path, path);
}

static int cfg_load(const char *path)
{
    if (plx_load(path) != PLX_OK) { printf("%s\n", plx_error()); return 0; }
    plx_setstr("VERSION", ACP_VERSION);
    return 1;
}

static void cfg_check(const char *path)
{
    int bad;
    if (!cfg_load(path)) return;
    bad = plx_check(stdout);
    printf("%s: %s\n", path, bad ? "PROBLEMS FOUND" : "SYNTAX OK");
}

static void cfg_run(const char *path, const char *block)
{
    int r;
    if (!cfg_load(path)) return;
    r = block ? plx_call(block) : plx_run();
    if (r == PLX_ERR) printf("\n%s\n", plx_error());
    else if (r == PLX_HALT) printf("[SCRIPT HALTED]\n");
}

static void usage(void)
{
    printf("PLXCFG - PL/X CONFIGURATION TOOL FOR ACPX\n");
    printf("  PLXCFG                     INTERACTIVE MENU\n");
    printf("  PLXCFG NEW   FILE.PLX      BANNER / LOGIN WIZARD\n");
    printf("  PLXCFG CHECK FILE.PLX      SYNTAX, LABEL AND BLOCK CHECK\n");
    printf("  PLXCFG RUN   FILE.PLX      RUN SCRIPT AS ACPX WOULD AT STARTUP\n");
    printf("  PLXCFG CALL  FILE.PLX BLK  RUN ONE BLOCK (MENUHDR, GOODBYE...)\n");
    printf("  PLXCFG LINES FILE.PLX [DIGITS [Z|P]]   EDITOR LINE NUMBERS: 1 / 01 / 00001\n");
}

int main(int argc, char **argv)
{
    char cmd[40], file[100], blk[40];

    plx_console_init();

    if (argc >= 3) {
        strncpy(cmd, argv[1], sizeof cmd - 1); cmd[sizeof cmd - 1] = '\0';
        { int i; for (i = 0; cmd[i]; i++) cmd[i] = (char)toupper((unsigned char)cmd[i]); }
        if (!strcmp(cmd, "NEW"))        cfg_new(argv[2]);
        else if (!strcmp(cmd, "CHECK")) cfg_check(argv[2]);
        else if (!strcmp(cmd, "RUN"))   cfg_run(argv[2], NULL);
        else if (!strcmp(cmd, "LINES")) cfg_lines(argv[2], argc > 3 ? argv[3] : NULL, argc > 4 ? argv[4] : NULL);
        else if (!strcmp(cmd, "CALL") && argc >= 4) {
            strncpy(blk, argv[3], sizeof blk - 1); blk[sizeof blk - 1] = '\0';
            { int i; for (i = 0; blk[i]; i++) blk[i] = (char)toupper((unsigned char)blk[i]); }
            cfg_run(argv[2], blk);
        } else { usage(); return 1; }
        return 0;
    }
    if (argc != 1) { usage(); return 1; }

    for (;;) {
        printf("\nPLXCFG  (PL/X CONFIGURATION FOR ACPX V%s)\n", ACP_VERSION);
        printf("1  NEW CONFIG WIZARD\n2  CHECK A SCRIPT\n3  RUN A SCRIPT (PREVIEW)\n");
        printf("4  RUN ONE BLOCK\n5  EDITOR LINE-NUMBER FORMAT\n6  QUIT\n");
        if (!ask("...? ", cmd, sizeof cmd, NULL)) break;
        switch (cmd[0]) {
        case '1': ask("FILE", file, sizeof file, "ACP.PLX"); cfg_new(file); break;
        case '2': ask("FILE", file, sizeof file, "ACP.PLX"); cfg_check(file); break;
        case '3': ask("FILE", file, sizeof file, "ACP.PLX"); cfg_run(file, NULL); break;
        case '4': ask("FILE", file, sizeof file, "ACP.PLX"); ask("BLOCK", blk, sizeof blk, "MENUHDR");
                  { int i; for (i = 0; blk[i]; i++) blk[i] = (char)toupper((unsigned char)blk[i]); }
                  cfg_run(file, blk); break;
        case '5': ask("FILE", file, sizeof file, "ACP.PLX"); cfg_lines(file, NULL, NULL); break;
        case '6': return 0;
        default:  printf("ENTER 1-6\n"); break;
        }
    }
    return 0;
}
