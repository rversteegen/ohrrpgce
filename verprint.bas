'OHRRPGCE VERPRINT - Crude version printing utility used by compile.bat
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
DECLARE FUNCTION datetag$ ()
DEFINT A-Z
'$DYNAMIC


OPEN "codename.txt" FOR INPUT AS #1
INPUT #1, codename$
CLOSE #1
codename$ = LEFT$(codename$, 11)

PRINT "Version ID " + datetag$
PRINT "Codename " + codename$

OPEN "cver.txt" FOR OUTPUT AS #1

a$ = "version$ = " + CHR$(34) + "OHRRPGCE Editor: " + codename$ + " v." + datetag$ + CHR$(34)
PRINT #1, a$

CLOSE #1

OPEN "gver.txt" FOR OUTPUT AS #1

a$ = "version$ = " + CHR$(34) + "O.H.R.RPG.C.E version " + datetag$ + CHR$(34)
PRINT #1, a$

CLOSE #1

REM $STATIC
FUNCTION datetag$
 datetag$ = MID$(DATE$, 7, 4) + MID$(DATE$, 1, 2) + MID$(DATE$, 4, 2)
END FUNCTION

