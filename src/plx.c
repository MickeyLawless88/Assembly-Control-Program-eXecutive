/* ========================================================================
 * plx.c  -  PL/X script interpreter (startup / banner scripting for acpx)
 *
 * PL/X language designed by Mickey W. Lawless.
 * Interpreter written for acpx v1.5.  Portable ANSI C (C89), no stdio
 * tricks: #include "plx.c" from acpx.c and plxcfg.c.  See PLX.TXT.
 * ====================================================================== */
#ifndef PLX_C
#define PLX_C

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#if defined(__unix__) || defined(__APPLE__) || defined(__linux__)
#  include <unistd.h>
#  include <termios.h>
#  define PLX_TERMIOS 1
#endif
#if defined(__TURBOC__) || defined(_MSC_VER) || defined(M_I86) || defined(_WIN32)
#  include <io.h>
#  define PLX_DOSIO 1
#  if defined(_WIN32)
#    include <conio.h>
#    define PX_ISATTY(fd) _isatty(fd)
#    define PX_GETCH()    _getch()
#  elif defined(__TURBOC__)
#    include <conio.h>
#    define PX_ISATTY(fd) isatty(fd)
#    define PX_GETCH()    getch()
#  else
#    define PX_ISATTY(fd) isatty(fd)
#  endif
#endif

#ifndef CLOCKS_PER_SEC
#  ifdef CLK_TCK
#    define CLOCKS_PER_SEC CLK_TCK      /* Turbo C 2.0 / old MSC */
#  else
#    define CLOCKS_PER_SEC 18L
#  endif
#endif

#define PLX_OK     0
#define PLX_HALT   1
#define PLX_JUMP   2
#define PLX_ERR  (-1)

#define PX_MAXTOK   3000
#define PX_MAXSRC   32000
#define PX_MAXVAR   64
#define PX_MAXLAB   64
#define PX_MAXBLK   32
#define PX_STR      96
#define PX_MAXDEPTH 12
#define PX_MAXSTEPS 200000L

enum { PT_EOF, PT_NL, PT_ID, PT_NUM, PT_STR, PT_LAB, PT_OP, PT_DOT };

typedef struct { int t; int line; long n; char *s; } PTOK;
typedef struct { char name[16]; int isint; long n; char s[PX_STR]; } PVAR;
typedef struct { char name[16]; int tok; int hdr; int kind; } PSYM;
typedef struct { int isstr; long n; char s[PX_STR]; } PVAL;

static PTOK *px_t;   static int px_n;
static PVAR  px_v[PX_MAXVAR];  static int px_nv;
static PSYM  px_lab[PX_MAXLAB]; static int px_nlab;
static PSYM  px_blk[PX_MAXBLK]; static int px_nblk;
static char  px_err[160];
static int   px_cur, px_jump, px_depth, px_impl, px_nlskip;
static long  px_steps;
static char *px_cap;  static int px_capn;
static int   plx_banner_ran;

/* block kinds */
#define PK_INLINE 0     /* BANNER: runs where it appears in the script    */
#define PK_VAR    1     /* VAR(name): hoisted, runs before the script      */
#define PK_SUB    2     /* every other block: CALL name / host hook        */

/* ---- tiny helpers ----------------------------------------------------- */
static int px_fail(const char *m, const char *w)
{
    int ln = (px_t && px_cur >= 0 && px_cur < px_n) ? px_t[px_cur].line : 0;
    sprintf(px_err, "PLX ERROR LINE %d: %.60s%s%.60s", ln, m,
            (w && *w) ? " - " : "", w ? w : "");
    return PLX_ERR;
}

static char *px_dup(const char *s, int n)
{
    char *p = (char *)malloc((unsigned)n + 1);
    if (p) { memcpy(p, s, (size_t)n); p[n] = '\0'; }
    return p;
}

static void px_cpy(char *d, const char *s)
{
    size_t n = strlen(s);
    if (n > PX_STR - 1) n = PX_STR - 1;
    memcpy(d, s, n);
    d[n] = '\0';
}

static int px_add(int t, int line, long n, const char *s, int len)
{
    PTOK *k;
    if (px_n >= PX_MAXTOK) return -1;
    k = &px_t[px_n++];
    k->t = t; k->line = line; k->n = n;
    k->s = s ? px_dup(s, len) : NULL;
    return 0;
}

static int px_isop(const PTOK *k, const char *o)  { return k->t == PT_OP  && !strcmp(k->s, o); }
static int px_isdot(const PTOK *k, const char *o) { return k->t == PT_DOT && !strcmp(k->s, o); }
static int px_isid(const PTOK *k, const char *o)  { return k->t == PT_ID  && !strcmp(k->s, o); }

static int px_hex(int c)
{
    return isdigit((unsigned char)c) ? c - '0' : toupper((unsigned char)c) - 'A' + 10;
}

static int px_lexerr(int line, const char *m)
{
    sprintf(px_err, "PLX ERROR LINE %d: %.60s", line, m);
    return PLX_ERR;
}

/* ---- lexer ------------------------------------------------------------ *
 * '&' joins the next line to the current statement (and may sit at the
 * start or end of a line).  Strings take "..." or '...' with \n \r \t \e
 * \a \f \xHH \\ \" \' escapes.  *NAME* is a label when it starts a
 * statement or follows GOTO / PROCEED / RET.  .EQ. .NE. .LT. .GT. .LE.
 * .GE. .AND. .OR. .NOT. are the dotted operators.  Comments: slash-star
 * ... star-slash and // to end of line.                                    */
static int px_lex(const char *p)
{
    int line = 1;
    char tmp[260];

    px_n = 0;
    while (*p) {
        char c = *p;
        if (c == '\r' || c == ' ' || c == '\t') { p++; continue; }
        if (c == '\n') { px_add(PT_NL, line, 0, NULL, 0); line++; p++; continue; }
        if (c == '/' && p[1] == '*') {
            p += 2;
            while (*p && !(p[0] == '*' && p[1] == '/')) { if (*p == '\n') line++; p++; }
            if (*p) p += 2;
            continue;
        }
        if (c == '/' && p[1] == '/') { while (*p && *p != '\n') p++; continue; }
        if (c == '&') {
            const char *q = p + 1;
            while (px_n > 0 && px_t[px_n - 1].t == PT_NL) px_n--;
            while (*q == ' ' || *q == '\t' || *q == '\r') q++;
            if (*q == '\n') { line++; q++; }
            p = q;
            continue;
        }
        if (c == '"' || c == '\'') {
            char d = c; int n = 0;
            p++;
            while (*p && *p != d && *p != '\n' && n < 250) {
                if (*p == '\\' && p[1]) {
                    p++;
                    switch (*p) {
                    case 'n': tmp[n++] = '\n'; break;
                    case 'r': tmp[n++] = '\r'; break;
                    case 't': tmp[n++] = '\t'; break;
                    case 'e': tmp[n++] = 27;   break;
                    case 'a': tmp[n++] = 7;    break;
                    case 'f': tmp[n++] = 12;   break;
                    case 'x': {
                        int v = 0, k = 0;
                        while (k < 2 && isxdigit((unsigned char)p[1])) {
                            p++; v = v * 16 + px_hex(*p); k++;
                        }
                        if (v) tmp[n++] = (char)v;
                        break; }
                    default:  tmp[n++] = *p; break;
                    }
                    p++;
                } else tmp[n++] = *p++;
            }
            if (*p != d) return px_lexerr(line, "UNTERMINATED STRING");
            p++;
            px_add(PT_STR, line, (long)n, tmp, n);
            continue;
        }
        if (isdigit((unsigned char)c)) {
            long v = 0;
            while (isdigit((unsigned char)*p)) { v = v * 10 + (*p - '0'); p++; }
            px_add(PT_NUM, line, v, NULL, 0);
            continue;
        }
        if (c == '$' && isxdigit((unsigned char)p[1])) {
            long v = 0;
            p++;
            while (isxdigit((unsigned char)*p)) { v = v * 16 + px_hex(*p); p++; }
            px_add(PT_NUM, line, v, NULL, 0);
            continue;
        }
        if (isalpha((unsigned char)c) || c == '_') {
            int n = 0;
            while (isalnum((unsigned char)*p) || *p == '_') {
                if (n < 15) tmp[n++] = (char)toupper((unsigned char)*p);
                p++;
            }
            px_add(PT_ID, line, 0, tmp, n);
            continue;
        }
        if (c == '.' && isalpha((unsigned char)p[1])) {
            const char *q = p + 1; int n = 0;
            while (isalpha((unsigned char)*q) && n < 6) tmp[n++] = (char)toupper((unsigned char)*q++);
            tmp[n] = '\0';
            if (*q == '.' && (!strcmp(tmp, "EQ") || !strcmp(tmp, "NE") || !strcmp(tmp, "LT") ||
                              !strcmp(tmp, "GT") || !strcmp(tmp, "LE") || !strcmp(tmp, "GE") ||
                              !strcmp(tmp, "AND") || !strcmp(tmp, "OR") || !strcmp(tmp, "NOT"))) {
                px_add(PT_DOT, line, 0, tmp, n);
                p = q + 1;
                continue;
            }
            return px_lexerr(line, "BAD DOTTED OPERATOR");
        }
        if (c == '*' && (isalpha((unsigned char)p[1]) || p[1] == '_')) {
            const PTOK *pk = px_n ? &px_t[px_n - 1] : NULL;
            int ok = (!pk || pk->t == PT_NL || px_isop(pk, "{") || px_isop(pk, "}") ||
                      px_isid(pk, "RET") || px_isid(pk, "PROCEED") || px_isid(pk, "GOTO"));
            if (ok) {
                const char *q = p + 1; int n = 0;
                while (isalnum((unsigned char)*q) || *q == '_') {
                    if (n < 15) tmp[n++] = (char)toupper((unsigned char)*q);
                    q++;
                }
                if (*q == '*') {
                    px_add(PT_LAB, line, 0, tmp, n);
                    p = q + 1;
                    continue;
                }
            }
        }
        if ((c == '=' && p[1] == '=') || (c == '<' && (p[1] == '>' || p[1] == '=')) ||
            (c == '>' && p[1] == '=') || (c == '!' && p[1] == '=')) {
            px_add(PT_OP, line, 0, p, 2); p += 2; continue;
        }
        if (strchr("[]{}(),:=<>+-*/", c)) { px_add(PT_OP, line, 0, p, 1); p++; continue; }
        sprintf(tmp, "UNEXPECTED CHARACTER '%c'", c);
        return px_lexerr(line, tmp);
    }
    px_add(PT_NL, line, 0, NULL, 0);
    px_add(PT_EOF, line, 0, NULL, 0);
    return PLX_OK;
}

/* ---- label / block tables -------------------------------------------- */
static int px_flab(const char *n)
{
    int i;
    for (i = 0; i < px_nlab; i++) if (!strcmp(px_lab[i].name, n)) return i;
    return -1;
}

static int px_fblk(const char *n)
{
    int i;
    for (i = 0; i < px_nblk; i++) if (!strcmp(px_blk[i].name, n)) return i;
    return -1;
}

static int px_match(int i)            /* '}' index matching '{' at i, or -1 */
{
    int d = 0;
    for (; i < px_n; i++) {
        if (px_isop(&px_t[i], "{")) d++;
        else if (px_isop(&px_t[i], "}") && --d == 0) return i;
    }
    return -1;
}

static int px_iskw(const char *s);

static int px_scan(void)
{
    int i, j, d = 0;

    px_nlab = px_nblk = 0;
    for (i = 0; i < px_n; i++) {
        const PTOK *k = &px_t[i], *pk = i ? &px_t[i - 1] : NULL;
        int start = (!pk || pk->t == PT_NL || px_isop(pk, "{") || px_isop(pk, "}"));

        px_cur = i;
        if (px_isop(k, "{")) d++;
        else if (px_isop(k, "}") && --d < 0) return px_fail("UNMATCHED }", "");
        if (!start) continue;
        if (k->t == PT_LAB) {
            if (px_flab(k->s) >= 0) return px_fail("DUPLICATE LABEL", k->s);
            if (px_nlab >= PX_MAXLAB) return px_fail("TOO MANY LABELS", "");
            strcpy(px_lab[px_nlab].name, k->s);
            px_lab[px_nlab].tok = i; px_lab[px_nlab].hdr = i; px_lab[px_nlab].kind = 0;
            px_nlab++;
        } else if (k->t == PT_ID) {
            char name[16]; int kind = PK_INLINE;
            j = i;
            strcpy(name, k->s);
            if (!strcmp(name, "SUB") && px_t[j + 1].t == PT_ID) {
                j++; strcpy(name, px_t[j].s); kind = PK_SUB;
            } else if (!strcmp(name, "VAR") && px_isop(&px_t[j + 1], "(") &&
                       px_t[j + 2].t == PT_ID && px_isop(&px_t[j + 3], ")")) {
                strcpy(name, px_t[j + 2].s); kind = PK_VAR; j += 3;
            }
            j++;
            while (px_t[j].t == PT_NL) j++;
            if (px_isop(&px_t[j], "{") && (kind != PK_INLINE || !px_iskw(name))) {
                if (kind == PK_INLINE && strcmp(name, "BANNER")) kind = PK_SUB;
                if (px_nblk >= PX_MAXBLK) return px_fail("TOO MANY BLOCKS", "");
                if (px_fblk(name) >= 0 && kind != PK_VAR) return px_fail("DUPLICATE BLOCK", name);
                strcpy(px_blk[px_nblk].name, name);
                px_blk[px_nblk].tok = j; px_blk[px_nblk].hdr = i; px_blk[px_nblk].kind = kind;
                px_nblk++;
            }
        }
    }
    px_cur = 0;
    if (d != 0) return px_fail("MISSING }", "");
    return PLX_OK;
}

/* ---- variables --------------------------------------------------------- */
static PVAR *px_find(const char *n)
{
    int i;
    for (i = 0; i < px_nv; i++) if (!strcmp(px_v[i].name, n)) return &px_v[i];
    return NULL;
}

static PVAR *px_new(const char *n)
{
    PVAR *v = px_find(n);
    if (v) return v;
    if (px_nv >= PX_MAXVAR) return NULL;
    v = &px_v[px_nv++];
    memset(v, 0, sizeof *v);
    strncpy(v->name, n, 15);
    return v;
}

void plx_setint(const char *n, long x)
{
    PVAR *v = px_new(n);
    if (v) { v->isint = 1; v->n = x; sprintf(v->s, "%ld", x); }
}

void plx_setstr(const char *n, const char *s)
{
    PVAR *v = px_new(n);
    if (v) { v->isint = 0; px_cpy(v->s, s); v->n = atol(v->s); }
}

long plx_getint(const char *n)
{
    PVAR *v = px_find(n);
    return v ? v->n : 0L;
}

static void px_getv(const PVAR *x, PVAL *v)
{
    if (x->isint) { v->isstr = 0; v->n = x->n; v->s[0] = '\0'; }
    else          { v->isstr = 1; v->n = 0;    px_cpy(v->s, x->s); }
}

static int px_store(const char *name, const PVAL *v, int type)
{
    PVAR *x = px_new(name);
    if (!x) return px_fail("TOO MANY VARIABLES", name);
    if (!type) type = v->isstr ? 'S' : 'I';
    if (type == 'I') {
        x->isint = 1;
        x->n = v->isstr ? atol(v->s) : v->n;
        sprintf(x->s, "%ld", x->n);
    } else {
        x->isint = 0;
        if (v->isstr) px_cpy(x->s, v->s); else sprintf(x->s, "%ld", v->n);
        x->n = atol(x->s);
    }
    return PLX_OK;
}

static void px_vstr(const PVAL *v, char *o)
{
    if (v->isstr) px_cpy(o, v->s); else sprintf(o, "%ld", v->n);
}
static long px_num(const PVAL *v)   { return v->isstr ? atol(v->s) : v->n; }
static int  px_truth(const PVAL *v) { return v->isstr ? v->s[0] != '\0' : v->n != 0; }

static void px_sysvars(void)
{
    static const char *mon[] = { "JAN","FEB","MAR","APR","MAY","JUN",
                                 "JUL","AUG","SEP","OCT","NOV","DEC" };
    time_t t = time(NULL);
    struct tm *lt = localtime(&t);
    char b[32];

    plx_setstr("VERSION", "");
    if (!lt) return;
    plx_setstr("SYSMON", mon[lt->tm_mon % 12]);
    plx_setint("SYSDAY", (long)lt->tm_mday);
    plx_setint("SYSYEAR", (long)lt->tm_year + 1900L);
    sprintf(b, "%02d/%02d/%02d", lt->tm_mon + 1, lt->tm_mday, lt->tm_year % 100);
    plx_setstr("SYSDATE", b);
    sprintf(b, "%02d:%02d:%02d", lt->tm_hour, lt->tm_min, lt->tm_sec);
    plx_setstr("SYSTIME", b);
}

/* ---- expressions -------------------------------------------------------
 * .OR. < .AND. < .NOT. < comparison < + - < * /
 * '+' and '.AND.' CONCATENATE when either side is a string, otherwise
 * they add / logically AND.  Comparisons: == <> != < > <= >= = and
 * .EQ. .NE. .LT. .GT. .LE. .GE.  (strings compare as text)                 */
static int px_or(int *pc, PVAL *v);

static void px_cat(PVAL *v, const PVAL *w)
{
    char a[PX_STR], b[PX_STR];
    size_t la, lb;
    px_vstr(v, a); px_vstr(w, b);
    la = strlen(a); lb = strlen(b);
    if (lb > PX_STR - 1 - la) lb = PX_STR - 1 - la;
    memcpy(a + la, b, lb); a[la + lb] = '\0';
    px_cpy(v->s, a);
    v->isstr = 1; v->n = 0;
}

static int px_prim(int *pc, PVAL *v)
{
    PTOK *k = &px_t[*pc];
    int r;
    px_cur = *pc;
    if (k->t == PT_NUM) { v->isstr = 0; v->n = k->n; v->s[0] = '\0'; (*pc)++; return PLX_OK; }
    if (k->t == PT_STR) { v->isstr = 1; v->n = 0; px_cpy(v->s, k->s); (*pc)++; return PLX_OK; }
    if (k->t == PT_ID) {
        PVAR *x = px_find(k->s);
        if (!x) return px_fail("UNDEFINED VARIABLE", k->s);
        px_getv(x, v);
        (*pc)++;
        return PLX_OK;
    }
    if (px_isop(k, "(")) {
        (*pc)++;
        r = px_or(pc, v); if (r) return r;
        if (!px_isop(&px_t[*pc], ")")) return px_fail("MISSING )", "");
        (*pc)++;
        return PLX_OK;
    }
    if (px_isop(k, "-")) {
        (*pc)++;
        r = px_prim(pc, v); if (r) return r;
        v->n = -px_num(v); v->isstr = 0;
        return PLX_OK;
    }
    return px_fail("EXPRESSION EXPECTED", k->s ? k->s : "");
}

static int px_mul(int *pc, PVAL *v)
{
    PVAL w; int r;
    r = px_prim(pc, v); if (r) return r;
    while (px_isop(&px_t[*pc], "*") || px_isop(&px_t[*pc], "/")) {
        char o = px_t[*pc].s[0];
        (*pc)++;
        r = px_prim(pc, &w); if (r) return r;
        if (o == '*') v->n = px_num(v) * px_num(&w);
        else {
            long d = px_num(&w);
            if (!d) return px_fail("DIVIDE BY ZERO", "");
            v->n = px_num(v) / d;
        }
        v->isstr = 0;
    }
    return PLX_OK;
}

static int px_sum(int *pc, PVAL *v)
{
    PVAL w; int r;
    r = px_mul(pc, v); if (r) return r;
    while (px_isop(&px_t[*pc], "+") || px_isop(&px_t[*pc], "-")) {
        char o = px_t[*pc].s[0];
        (*pc)++;
        r = px_mul(pc, &w); if (r) return r;
        if (o == '+') {
            if (v->isstr || w.isstr) px_cat(v, &w); else v->n += w.n;
        } else { v->n = px_num(v) - px_num(&w); v->isstr = 0; }
    }
    return PLX_OK;
}

static int px_cmp(int *pc, PVAL *v)
{
    PVAL w; int r, op = 0, c;
    PTOK *k;
    r = px_sum(pc, v); if (r) return r;
    k = &px_t[*pc];
    if (k->t == PT_OP) {
        if (!strcmp(k->s, "==") || !strcmp(k->s, "=")) op = 1;
        else if (!strcmp(k->s, "<>") || !strcmp(k->s, "!=")) op = 2;
        else if (!strcmp(k->s, "<"))  op = 3;
        else if (!strcmp(k->s, ">"))  op = 4;
        else if (!strcmp(k->s, "<=")) op = 5;
        else if (!strcmp(k->s, ">=")) op = 6;
    } else if (k->t == PT_DOT) {
        if (!strcmp(k->s, "EQ")) op = 1; else if (!strcmp(k->s, "NE")) op = 2;
        else if (!strcmp(k->s, "LT")) op = 3; else if (!strcmp(k->s, "GT")) op = 4;
        else if (!strcmp(k->s, "LE")) op = 5; else if (!strcmp(k->s, "GE")) op = 6;
    }
    if (!op) return PLX_OK;
    (*pc)++;
    r = px_sum(pc, &w); if (r) return r;
    if (!v->isstr && !w.isstr) c = (v->n < w.n) ? -1 : (v->n > w.n);
    else { char a[PX_STR], b[PX_STR]; px_vstr(v, a); px_vstr(&w, b); c = strcmp(a, b); }
    v->isstr = 0;
    v->n = (op == 1) ? (c == 0) : (op == 2) ? (c != 0) : (op == 3) ? (c < 0) :
           (op == 4) ? (c > 0) : (op == 5) ? (c <= 0) : (c >= 0);
    return PLX_OK;
}

static int px_not(int *pc, PVAL *v)
{
    int r;
    if (px_isdot(&px_t[*pc], "NOT")) {
        (*pc)++;
        r = px_not(pc, v); if (r) return r;
        v->n = !px_truth(v); v->isstr = 0;
        return PLX_OK;
    }
    return px_cmp(pc, v);
}

static int px_and(int *pc, PVAL *v)
{
    PVAL w; int r;
    r = px_not(pc, v); if (r) return r;
    while (px_isdot(&px_t[*pc], "AND")) {
        (*pc)++;
        r = px_not(pc, &w); if (r) return r;
        if (v->isstr || w.isstr) px_cat(v, &w);
        else v->n = (v->n && w.n);
    }
    return PLX_OK;
}

static int px_or(int *pc, PVAL *v)
{
    PVAL w; int r;
    r = px_and(pc, v); if (r) return r;
    while (px_isdot(&px_t[*pc], "OR")) {
        (*pc)++;
        r = px_and(pc, &w); if (r) return r;
        v->n = (px_truth(v) || px_truth(&w)); v->isstr = 0;
    }
    return PLX_OK;
}

/* ---- terminal I/O ------------------------------------------------------ */
static int px_tty(void)
{
#ifdef PLX_TERMIOS
    return isatty(0);
#elif defined(PLX_DOSIO)
    return PX_ISATTY(0);
#else
    return 1;
#endif
}

static void px_put(const char *s)
{
    if (px_nlskip && *s) { px_nlskip = 0; if (*s == '\n') s++; }
    fputs(s, stdout);
    if (px_cap) {
        int n = (int)strlen(s);
        if (px_capn + n < PX_STR - 1) { strcpy(px_cap + px_capn, s); px_capn += n; }
    }
}

static char *px_gets(char *b, int n, int hide)
{
    char *r;
#ifdef PLX_TERMIOS
    struct termios o, t;
    int tty = hide && isatty(0);
    if (tty) { tcgetattr(0, &o); t = o; t.c_lflag &= ~(tcflag_t)ECHO; tcsetattr(0, TCSANOW, &t); }
    r = fgets(b, n, stdin);
    if (tty) tcsetattr(0, TCSANOW, &o);
#else
#ifdef PX_GETCH
    if (hide && PX_ISATTY(0)) {         /* console: read keys without echo */
        int i = 0, c;
        for (;;) {
            c = PX_GETCH();
            if (c == 3 || c == 26) return NULL;         /* Ctrl-C / Ctrl-Z */
            if (c == '\r' || c == '\n') break;
            if (c == 0) { getch(); continue; }          /* extended key */
            if (c == '\b') { if (i > 0) i--; continue; }
            if (i < n - 3) b[i++] = (char)c;
        }
        b[i++] = '\n'; b[i] = '\0';
        return b;
    }
#endif
    r = fgets(b, n, stdin);
    (void)hide;
#endif
    return r;
}

/* format letters: A (text, upcased on input)  S (text as typed)  I (integer)
 * Z (zero-padded integer)  H (hidden input, echoes X per character).
 * "5A1" = 5 x A1 = A5.  Width 0 (bare "A"/"S") = whatever the value needs. */
static int px_fmt(int *pc, int *type, int *w)
{
    long rep = 1; PTOK *k = &px_t[*pc]; int width = 0;
    if (k->t == PT_NUM) { rep = k->n; (*pc)++; k = &px_t[*pc]; }
    if (k->t != PT_ID || !strchr("ASIZH", k->s[0])) return px_fail("BAD FORMAT", k->s ? k->s : "");
    *type = k->s[0];
    if (isdigit((unsigned char)k->s[1])) width = atoi(k->s + 1);
    else if (k->s[1]) return px_fail("BAD FORMAT", k->s);
    if (!width && rep == 1 && !k->s[1]) *w = 0; else *w = (width ? width : 1) * (int)rep;
    if (*w > PX_STR - 1) *w = PX_STR - 1;
    (*pc)++;
    return PLX_OK;
}

static void px_putf(const PVAL *v, int type, int w)
{
    char b[PX_STR + 16], o[PX_STR];
    px_vstr(v, o);
    if (type == 'I')      sprintf(b, "%*ld", w, px_num(v));
    else if (type == 'Z') sprintf(b, "%0*ld", w, px_num(v));
    else if (w > 0)       sprintf(b, "%-*.*s", w, w, o);
    else                  strcpy(b, o);
    px_put(b);
}

static int px_input(const char *name, int type, int w)
{
    char b[256]; PVAL v; int n;
    px_nlskip = 0;
    fflush(stdout);
    if (!px_gets(b, (int)sizeof b, type == 'H')) return PLX_HALT;
    n = (int)strlen(b);
    while (n > 0 && (b[n - 1] == '\n' || b[n - 1] == '\r')) b[--n] = '\0';
    if (w <= 0 || w > PX_STR - 1) w = PX_STR - 1;
    if (n > w) { b[w] = '\0'; n = w; }
    if (type == 'I' || type == 'Z') { v.isstr = 0; v.n = atol(b); v.s[0] = '\0'; }
    else {
        if (type != 'S') { int i; for (i = 0; i < n; i++) b[i] = (char)toupper((unsigned char)b[i]); }
        v.isstr = 1; v.n = 0; px_cpy(v.s, b);
    }
    if (type == 'H') { int i; for (i = 0; i < n; i++) px_put("X"); }
    else px_nlskip = px_tty();
    return px_store(name, &v, (type == 'I' || type == 'Z') ? 'I' : 'S');
}

static int px_iskw(const char *s)
{
    static const char *kw[] = { "IF","THEN","ELSE","ASSIGN","INT","STR","STRING","CALL","GOTO",
                                "PROCEED","RET","HALT","EXIT","DELAY","BEEP","PAUSE","END",
                                "SUB","VAR",0 };
    int i;
    for (i = 0; kw[i]; i++) if (!strcmp(kw[i], s)) return 1;
    return 0;
}

static int px_barefmt(const char *s)
{
    if (!s[0] || !strchr("ASIZH", s[0]) || !s[1]) return 0;
    for (s++; *s; s++) if (!isdigit((unsigned char)*s)) return 0;
    return 1;
}

/* bare I4 / A10 items print USRNO, PORTNO (in that order) per block run */
static int px_implicit(PVAL *v)
{
    static const char *nm[] = { "USRNO", "PORTNO" };
    PVAR *x = (px_impl < 2) ? px_find(nm[px_impl]) : NULL;
    px_impl++;
    if (!x) return 0;
    px_getv(x, v);
    return 1;
}

/* Item list.  mode 0: statement level; 1: inside [..] prompt (NAME:fmt reads
 * input); 2: inside NAME=[..] (output only, text is also stored in NAME).   */
static int px_items(int *pc, int mode)
{
    int r, type = 0, w = 0;
    for (;;) {
        PTOK *k = &px_t[*pc], *n1 = &px_t[*pc + 1];
        PVAL v;
        px_cur = *pc;
        if (px_isop(k, ",")) { (*pc)++; continue; }
        if (mode && px_isop(k, "]")) { (*pc)++; return PLX_OK; }
        if (mode && k->t == PT_NL) { (*pc)++; continue; }
        if (k->t == PT_EOF) return mode ? px_fail("MISSING ]", "") : PLX_OK;
        if (px_isop(k, "[")) {
            (*pc)++;
            r = px_items(pc, mode == 2 ? 2 : 1); if (r) return r;
            continue;
        }
        if (k->t == PT_STR) { px_put(k->s); (*pc)++; continue; }
        if (k->t == PT_NUM) { char b[24]; sprintf(b, "%ld", k->n); px_put(b); (*pc)++; continue; }
        if (k->t == PT_ID) {
            PVAR *x;
            if (!mode && px_iskw(k->s)) return PLX_OK;
            if (!mode && (px_isop(n1, "=") || px_isdot(n1, "EQ")) && !px_isop(&px_t[*pc + 2], "["))
                return PLX_OK;              /* next statement is an assignment */
            if ((px_isop(n1, "=") || px_isdot(n1, "EQ")) && px_isop(&px_t[*pc + 2], "[")) {
                char sv[PX_STR]; char *oc = px_cap; int on = px_capn;
                *pc += 3;
                sv[0] = '\0'; px_cap = sv; px_capn = 0;
                r = px_items(pc, 2);
                px_cap = oc; px_capn = on;
                if (r) return r;
                v.isstr = 1; v.n = 0; px_cpy(v.s, sv);
                r = px_store(k->s, &v, 'S'); if (r) return r;
                continue;
            }
            if (px_isop(n1, ":")) {
                *pc += 2;
                r = px_fmt(pc, &type, &w); if (r) return r;
                if (mode == 1) { r = px_input(k->s, type, w); if (r) return r; }
                else {
                    x = px_find(k->s);
                    if (!x) return px_fail("UNDEFINED VARIABLE", k->s);
                    px_getv(x, &v); px_putf(&v, type, w);
                }
                continue;
            }
            x = px_find(k->s);
            if (x) {
                char b[PX_STR];
                px_getv(x, &v); px_vstr(&v, b); px_put(b);
                (*pc)++;
                continue;
            }
            if (px_barefmt(k->s)) {
                type = k->s[0]; w = atoi(k->s + 1);
                if (px_implicit(&v)) px_putf(&v, type, w);
                else { char b[PX_STR]; sprintf(b, "%*s", w, ""); px_put(b); }
                (*pc)++;
                continue;
            }
            return px_fail("UNDEFINED VARIABLE", k->s);
        }
        if (mode) return px_fail("UNEXPECTED TOKEN IN LIST", k->s ? k->s : "");
        return PLX_OK;
    }
}

/* ---- statements -------------------------------------------------------- */
static int px_range(int pc, int end);
static int px_exec(int *pc);

static int px_body(int open)            /* run the body of the block at '{' */
{
    int close = px_match(open), r, svi = px_impl;
    if (close < 0) return px_fail("MISSING }", "");
    if (px_depth >= PX_MAXDEPTH) return px_fail("BLOCK NESTING TOO DEEP", "");
    px_depth++; px_impl = 0;
    r = px_range(open + 1, close);
    px_depth--; px_impl = svi;
    return r;
}

/* skip one statement; a '{..}' block counts as one; stop_else halts at ELSE */
static void px_skip(int *pc, int stop_else)
{
    int d = 0;
    for (;;) {
        PTOK *k = &px_t[*pc];
        if (k->t == PT_EOF) return;
        if (stop_else && d == 0 && px_isid(k, "ELSE")) return;
        if (k->t == PT_OP) {
            char c = k->s[0];
            if (c == '{' || c == '[' || c == '(') d++;
            else if (c == '}' || c == ']' || c == ')') {
                if (d == 0) return;
                d--;
                if (d == 0 && c == '}') { (*pc)++; return; }
            }
        }
        if (k->t == PT_NL && d == 0) { (*pc)++; return; }
        (*pc)++;
    }
}

static int px_assign(int *pc)
{
    int p = *pc, type = 0, r;
    PVAL v; char name[16];

    if (px_isid(&px_t[p], "ASSIGN")) p++;
    if (px_isid(&px_t[p], "INT")) { type = 'I'; p++; }
    else if (px_isid(&px_t[p], "STR") || px_isid(&px_t[p], "STRING")) { type = 'S'; p++; }
    if (px_t[p].t != PT_ID) return px_fail("VARIABLE NAME EXPECTED", "");
    strcpy(name, px_t[p].s); p++;
    if (!(px_isop(&px_t[p], "=") || px_isdot(&px_t[p], "EQ")))
        return px_fail("= OR .EQ. EXPECTED AFTER", name);
    p++;
    if (px_isop(&px_t[p], "[")) {
        char sv[PX_STR]; char *oc = px_cap; int on = px_capn;
        p++;
        sv[0] = '\0'; px_cap = sv; px_capn = 0;
        r = px_items(&p, 2);
        px_cap = oc; px_capn = on;
        if (r) return r;
        v.isstr = 1; v.n = 0; px_cpy(v.s, sv);
        type = 'S';
    } else {
        r = px_or(&p, &v); if (r) return r;
    }
    *pc = p;
    return px_store(name, &v, type);
}

static int px_exec(int *pc)
{
    PTOK *k = &px_t[*pc];
    int r, i;

    px_cur = *pc;
    if (k->t == PT_NL || k->t == PT_LAB) { (*pc)++; return PLX_OK; }
    if (px_isop(k, "}")) return px_fail("UNMATCHED }", "");
    if (px_isop(k, "{")) {
        r = px_body(*pc); if (r) return r;
        *pc = px_match(*pc) + 1;
        return PLX_OK;
    }
    if (k->t == PT_ID) {
        if (px_isop(&px_t[*pc + 1], "<") && px_isid(&px_t[*pc + 2], "END") &&
            px_isop(&px_t[*pc + 3], ">")) { *pc += 4; return PLX_OK; }
        if (px_isid(k, "END") && px_isop(&px_t[*pc + 1], "(")) {
            while (px_t[*pc].t != PT_EOF && !px_isop(&px_t[*pc], ")")) (*pc)++;
            if (px_t[*pc].t != PT_EOF) (*pc)++;
            return PLX_OK;
        }
        for (i = 0; i < px_nblk; i++) if (px_blk[i].hdr == *pc) {
            int open = px_blk[i].tok;
            if (px_blk[i].kind == PK_INLINE) {
                if (!strcmp(px_blk[i].name, "BANNER")) plx_banner_ran = 1;
                r = px_body(open); if (r) return r;
            }
            *pc = px_match(open) + 1;
            return PLX_OK;
        }
        if (!strcmp(k->s, "IF")) {
            PVAL c; int t, sv, j;
            (*pc)++;
            if (!px_isop(&px_t[*pc], "(")) return px_fail("( EXPECTED AFTER IF", "");
            (*pc)++;
            r = px_or(pc, &c); if (r) return r;
            if (!px_isop(&px_t[*pc], ")")) return px_fail(") EXPECTED", "");
            (*pc)++;
            if (px_isid(&px_t[*pc], "THEN")) (*pc)++;
            t = px_truth(&c);
            if (t) { r = px_exec(pc); if (r) return r; }
            else px_skip(pc, 1);
            sv = j = *pc;
            while (px_t[j].t == PT_NL) j++;
            if (px_isid(&px_t[j], "ELSE")) {
                *pc = j + 1;
                if (t) px_skip(pc, 0);
                else { r = px_exec(pc); if (r) return r; }
            } else *pc = sv;
            return PLX_OK;
        }
        if (!strcmp(k->s, "GOTO") || !strcmp(k->s, "PROCEED") || !strcmp(k->s, "RET")) {
            (*pc)++;
            if (px_t[*pc].t == PT_LAB) {
                i = px_flab(px_t[*pc].s);
                if (i < 0) return px_fail("UNDEFINED LABEL", px_t[*pc].s);
                px_jump = px_lab[i].tok + 1;
                (*pc)++;
                return PLX_JUMP;
            }
            if (k->s[0] == 'G') return px_fail("LABEL EXPECTED AFTER GOTO", "");
            return PLX_OK;
        }
        if (!strcmp(k->s, "CALL")) {
            (*pc)++;
            if (px_t[*pc].t != PT_ID) return px_fail("BLOCK NAME EXPECTED AFTER CALL", "");
            i = px_fblk(px_t[*pc].s);
            if (i < 0) return px_fail("UNDEFINED BLOCK", px_t[*pc].s);
            (*pc)++;
            return px_body(px_blk[i].tok);
        }
        if (!strcmp(k->s, "HALT") || !strcmp(k->s, "EXIT")) {
            (*pc)++;
            r = px_items(pc, 0); if (r) return r;
            return PLX_HALT;
        }
        if (!strcmp(k->s, "BEEP")) { (*pc)++; px_put("\a"); return PLX_OK; }
        if (!strcmp(k->s, "PAUSE")) {
            static char b[256];         /* static: keep DOS stack frames small */
            (*pc)++;
            r = px_items(pc, 0); if (r) return r;
            fflush(stdout); px_nlskip = 0;
            if (!fgets(b, (int)sizeof b, stdin)) return PLX_HALT;
            px_nlskip = px_tty();
            return PLX_OK;
        }
        if (!strcmp(k->s, "DELAY")) {
            PVAL d; clock_t e;
            (*pc)++;
            r = px_or(pc, &d); if (r) return r;
            fflush(stdout);
            e = clock() + (clock_t)(px_num(&d) * (long)CLOCKS_PER_SEC / 1000L);
            while (clock() < e) { }
            return PLX_OK;
        }
        if (!strcmp(k->s, "ASSIGN") || !strcmp(k->s, "INT") || !strcmp(k->s, "STR") ||
            !strcmp(k->s, "STRING") ||
            ((px_isop(&px_t[*pc + 1], "=") || px_isdot(&px_t[*pc + 1], "EQ")) && !px_iskw(k->s)))
            return px_assign(pc);
    }
    {
        int s0 = *pc;
        r = px_items(pc, 0);
        if (r) return r;
        if (*pc == s0) return px_fail("SYNTAX ERROR AT", k->s ? k->s : "");
    }
    return PLX_OK;
}

static int px_range(int pc, int end)
{
    int start = pc, r;
    while (pc < end && px_t[pc].t != PT_EOF) {
        if (++px_steps > PX_MAXSTEPS) { px_cur = pc; return px_fail("LOOP LIMIT EXCEEDED", ""); }
        r = px_exec(&pc);
        if (r == PLX_JUMP) {
            if (px_jump >= start && px_jump < end) { pc = px_jump; continue; }
            return PLX_JUMP;
        }
        if (r) return r;
    }
    return PLX_OK;
}

/* ---- public API -------------------------------------------------------- */
void plx_free(void)
{
    int i;
    if (px_t) {
        for (i = 0; i < px_n; i++) free(px_t[i].s);
        free(px_t);
        px_t = NULL;
    }
    px_n = px_nv = px_nlab = px_nblk = 0;
}

const char *plx_error(void) { return px_err; }

int plx_load(const char *path)
{
    FILE *f; char *buf; size_t n; int r;

    plx_free();
    px_err[0] = '\0'; px_cur = 0;
    f = fopen(path, "r");
    if (!f) { sprintf(px_err, "PLX ERROR: CANNOT OPEN %.100s", path); return PLX_ERR; }
    buf = (char *)malloc(PX_MAXSRC + 1);
    px_t = (PTOK *)calloc(PX_MAXTOK + 8, sizeof(PTOK));
    if (!buf || !px_t) { fclose(f); free(buf); plx_free(); strcpy(px_err, "PLX ERROR: OUT OF MEMORY"); return PLX_ERR; }
    n = fread(buf, 1, PX_MAXSRC, f);
    buf[n] = '\0';
    fclose(f);
    px_sysvars();
    r = px_lex(buf);
    free(buf);
    if (!r) r = px_scan();
    if (r) { plx_free(); return r; }
    return PLX_OK;
}

int plx_has(const char *name) { return px_t && px_fblk(name) >= 0; }

/* run the script: VAR blocks first, then the main flow */
int plx_run(void)
{
    int i, r;
    px_err[0] = '\0'; px_steps = 0; px_depth = 0; px_impl = 0;
    px_nlskip = 0; px_cap = NULL; plx_banner_ran = 0;
    for (i = 0; i < px_nblk; i++)
        if (px_blk[i].kind == PK_VAR) { r = px_body(px_blk[i].tok); if (r == PLX_ERR) return r; }
    r = px_range(0, px_n);
    fflush(stdout);
    return r;
}

/* run one named block (host hooks: MENUHDR, GOODBYE, or any SUB) */
int plx_call(const char *name)
{
    int i, r;
    i = px_fblk(name);
    if (i < 0) return PLX_OK;
    px_steps = 0; px_depth = 0; px_impl = 0; px_cap = NULL;
    r = px_body(px_blk[i].tok);
    fflush(stdout);
    return r;
}

/* static check: labels/blocks listing + undefined GOTO/CALL targets.
 * returns number of problems found */
int plx_check(FILE *o)
{
    int i, bad = 0;
    fprintf(o, "LABELS:");
    for (i = 0; i < px_nlab; i++) fprintf(o, " *%s*", px_lab[i].name);
    fprintf(o, "\nBLOCKS:");
    for (i = 0; i < px_nblk; i++)
        fprintf(o, " %s(%s)", px_blk[i].name,
                px_blk[i].kind == PK_INLINE ? "RUNS INLINE" : px_blk[i].kind == PK_VAR ? "HOISTED" : "CALLABLE");
    fprintf(o, "\n");
    for (i = 0; i < px_n; i++) {
        PTOK *k = &px_t[i];
        if ((px_isid(k, "GOTO") || px_isid(k, "PROCEED") || px_isid(k, "RET")) &&
            px_t[i + 1].t == PT_LAB && px_flab(px_t[i + 1].s) < 0) {
            fprintf(o, "LINE %d: UNDEFINED LABEL *%s*\n", k->line, px_t[i + 1].s); bad++;
        }
        if (px_isid(k, "CALL") && (px_t[i + 1].t != PT_ID || px_fblk(px_t[i + 1].s) < 0)) {
            fprintf(o, "LINE %d: UNDEFINED BLOCK %s\n", k->line, px_t[i + 1].s ? px_t[i + 1].s : "?"); bad++;
        }
    }
    return bad;
}

/* Windows console: turn on ANSI/VT escape processing so "\e[..." strings work
 * (Windows 10+).  Declared by hand: windows.h clashes with acpx's BYTE/WORD. */
#ifdef _WIN32
__declspec(dllimport) void *__stdcall GetStdHandle(unsigned long);
__declspec(dllimport) int   __stdcall GetConsoleMode(void *, unsigned long *);
__declspec(dllimport) int   __stdcall SetConsoleMode(void *, unsigned long);
#endif

void plx_console_init(void)
{
#ifdef _WIN32
    void *h = GetStdHandle((unsigned long)-11);          /* STD_OUTPUT_HANDLE */
    unsigned long m;
    if (h && h != (void *)-1 && GetConsoleMode(h, &m))
        SetConsoleMode(h, m | 4UL);        /* ENABLE_VIRTUAL_TERMINAL_PROCESSING */
#endif
}

#endif /* PLX_C */
