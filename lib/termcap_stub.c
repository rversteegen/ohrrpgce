// Minimal stub for the termcap API (part of curses), which can be linked to
// remove a dependency on libncurses/libtinfo by FB programs.
// This does just enough to make hInit() in libfb succeed so INKEY works.
//
// Placed in the public domain.

#include <stdio.h>
#include <string.h>
#define NCURSES_STATIC  // Building or linking to a static library (needed on Windows only)
#include <termcap.h>

char PC;
char * UP;
char * BC;
NCURSES_OSPEED ospeed;

#define BUFSZ 10
char buf[BUFSZ];

NCURSES_EXPORT(char *) tgetstr (const char *id, char **area) {
    if (strcmp(id, "ce") == 0)  // SEQ_CLEOL - clear until end of line
        return "\e[K";
    if (strcmp(id, "cm") == 0)  // SEQ_LOCATE - move cursor
        return "cm";
    if (strcmp(id, "ve") == 0)  // SEQ_SHOW_CURSOR - make cursor visible
        return "\e[?25h";
    if (strcmp(id, "vi") == 0)  // SEQ_HIDE_CURSOR - make cursor invisible
        return "\e[?25l";

    return 0;
}
NCURSES_EXPORT(char *) tgoto (const char *cap, int col, int row) {
    if (strcmp(cap, "cm") == 0) {
//        snprintf(buf, BUFSZ, "\e[%d;%df", row, col);
        snprintf(buf, BUFSZ, "\e[%d;%dH", row, col);
        return buf;
    }
    return (char *)cap;
}
NCURSES_EXPORT(int) tgetent (char *bp, const char *name) {
    return 1;
}
NCURSES_EXPORT(int) tgetflag (const char *id) {
    if (strcmp(id, "am") == 0)
        return 1;
    return 0;
}
NCURSES_EXPORT(int) tgetnum (const char *id) {
    return 0;
}
NCURSES_EXPORT(int) tputs (const char *str, int affcnt, int (*putc)(int)) {
    puts(str);
    return 0;
}
