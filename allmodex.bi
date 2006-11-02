'Allmodex FreeBasic Library header

#IFNDEF ALLMODEX_BI
#DEFINE ALLMODEX_BI

#include "compat.bi"

'Library routines
DECLARE SUB setmodex ()
DECLARE SUB restoremode ()
DECLARE SUB copypage (BYVAL page1, BYVAL page2)
DECLARE SUB clearpage (BYVAL page)
DECLARE SUB setvispage (BYVAL page)
DECLARE SUB setpal (pal())
DECLARE SUB fadeto (palbuff(), BYVAL red, BYVAL green, BYVAL blue)
DECLARE SUB fadetopal (pal(), palbuff())
DECLARE SUB setmapdata (array(), pas(), BYVAL t, BYVAL b)
DECLARE SUB setmapblock (BYVAL x, BYVAL y, BYVAL v)
DECLARE FUNCTION readmapblock (BYVAL x, BYVAL y)
DECLARE SUB setpassblock (BYVAL x, BYVAL y, BYVAL v)
DECLARE FUNCTION readpassblock (BYVAL x, BYVAL y)
DECLARE SUB drawmap (BYVAL x, BYVAL y, BYVAL t, BYVAL p)
DECLARE SUB setanim (BYVAL cycle1, BYVAL cycle2)
DECLARE SUB setoutside (BYVAL defaulttile)
DECLARE SUB drawsprite (pic(), BYVAL picoff, pal(), BYVAL po, BYVAL x, BYVAL y, BYVAL page, BYVAL trans = -1)
DECLARE SUB wardsprite (pic(), BYVAL picoff, pal(), BYVAL po, BYVAL x, BYVAL y, BYVAL page, BYVAL trans = -1)
DECLARE SUB getsprite (pic(), BYVAL picoff, BYVAL x, BYVAL y, BYVAL w, BYVAL h, BYVAL page)
DECLARE SUB stosprite (pic(), BYVAL picoff, BYVAL x, BYVAL y, BYVAL page)
DECLARE SUB loadsprite (pic(), BYVAL picoff, BYVAL x, BYVAL y, BYVAL w, BYVAL h, BYVAL page)
DECLARE SUB bigsprite (pic(), pal(), BYVAL p, BYVAL x, BYVAL y, BYVAL page, BYVAL trans = -1)
DECLARE SUB hugesprite (pic(), pal(), BYVAL p, BYVAL x, BYVAL y, BYVAL page, BYVAL trans = -1)
DECLARE FUNCTION keyval (BYVAL a)
DECLARE FUNCTION getkey ()
DECLARE SUB setkeys ()
DECLARE SUB putpixel (BYVAL x, BYVAL y, BYVAL c, BYVAL p)
DECLARE FUNCTION readpixel (BYVAL x, BYVAL y, BYVAL p)
DECLARE SUB rectangle (BYVAL x, BYVAL y, BYVAL w, BYVAL h, BYVAL c, BYVAL p)
DECLARE SUB fuzzyrect (BYVAL x, BYVAL y, BYVAL w, BYVAL h, BYVAL c, BYVAL p)
DECLARE SUB drawline (BYVAL x1, BYVAL y1, BYVAL x2, BYVAL y2, BYVAL c, BYVAL p)
DECLARE SUB paintat (BYVAL x, BYVAL y, BYVAL c, BYVAL page, buf(), BYVAL max)
DECLARE SUB storepage (fil$, BYVAL i, BYVAL p)
DECLARE SUB loadpage (fil$, BYVAL i, BYVAL p)
DECLARE SUB setdiskpages (buf(), BYVAL h, BYVAL l)
DECLARE SUB setwait overload (b(), BYVAL t)
DECLARE SUB setwait overload (BYVAL t)
DECLARE SUB dowait ()
DECLARE SUB printstr (s$, BYVAL x, BYVAL y, BYVAL p)
DECLARE SUB textcolor (BYVAL f, BYVAL b)
DECLARE SUB setfont (f())
DECLARE SUB setbit (b(), BYVAL w, BYVAL b, BYVAL v)
DECLARE FUNCTION readbit (b(), BYVAL w, BYVAL b)
DECLARE SUB storeset (fil$, BYVAL i, BYVAL l)
DECLARE SUB loadset (fil$, BYVAL i, BYVAL l)
DECLARE SUB setpicstuf (buf(), BYVAL b, BYVAL p)
DECLARE SUB loadrecord overload (buf(), fh, recordsize, record = -1)
DECLARE SUB loadrecord overload (buf(), filename$, recordsize, record = 0)
DECLARE SUB storerecord overload (buf(), fh, recordsize, record = -1)
DECLARE SUB storerecord overload (buf(), filename$, recordsize, record = 0)
DECLARE SUB bitmap2page (temp(), bmp$, BYVAL p)
DECLARE SUB findfiles overload(fmask$, BYVAL attrib, outfile$, buf())
DECLARE SUB findfiles (fmask$, BYVAL attrib, outfile$)
DECLARE SUB lumpfiles overload(listf$, lump$, path$, buffer())
DECLARE SUB lumpfiles (listf$, lump$, path$)
DECLARE SUB unlump overload (lump$, ulpath$, buffer())
DECLARE SUB unlump(lump$, ulpath$)
DECLARE SUB unlumpfile overload (lump$, fmask$, path$, buf())
DECLARE SUB unlumpfile(lump$, fmask$, path$)
DECLARE FUNCTION islumpfile (lump$, fmask$)
DECLARE FUNCTION isfile (n$)
DECLARE FUNCTION isdir (sDir$)
DECLARE FUNCTION drivelist (d$())
DECLARE FUNCTION drivelabel$ (drive$)
DECLARE FUNCTION isremovable (drive$)
DECLARE FUNCTION hasmedia (drive$)
DECLARE SUB setupmusic
DECLARE SUB closemusic ()
DECLARE SUB loadsong (f$)
DECLARE SUB stopsong ()
DECLARE SUB resumesong ()
DECLARE SUB fademusic (BYVAL vol)
DECLARE FUNCTION getfmvol ()
DECLARE SUB setfmvol (BYVAL vol)
DECLARE SUB copyfile (s$, d$, buf())
DECLARE SUB screenshot (f$, BYVAL p, maspal(), buf())
DECLARE SUB loadbmp (f$, BYVAL x, BYVAL y, buf(), BYVAL p)
DECLARE SUB getbmppal (f$, mpal(), pal(), BYVAL o)
DECLARE FUNCTION bmpinfo (f$, dat())
DECLARE FUNCTION setmouse (mbuf())
DECLARE SUB readmouse (mbuf())
DECLARE SUB movemouse (BYVAL x, BYVAL y)
DECLARE SUB mouserect (BYVAL xmin, BYVAL xmax, BYVAL ymin, BYVAL ymax)
DECLARE FUNCTION readjoy (joybuf(), BYVAL jnum)
DECLARE SUB array2str (arr(), BYVAL o, s$)
DECLARE SUB str2array (s$, arr(), BYVAL o)
DECLARE SUB setupstack ()
DECLARE SUB pushw (BYVAL word)
DECLARE FUNCTION popw ()
DECLARE SUB pushdw (BYVAL word)
DECLARE FUNCTION popdw ()
DECLARE SUB releasestack ()
DECLARE FUNCTION stackpos ()
DECLARE FUNCTION readstackdw (BYVAL off)
DECLARE SUB drawbox(BYVAL x, BYVAL y, BYVAL w, BYVAL h, BYVAL c, BYVAL p)
DECLARE FUNCTION isawav(fi$)

DECLARE SUB setupsound ()
DECLARE SUB closesound ()
DECLARE SUB playsfx (BYVAL num, BYVAL l)
DECLARE SUB stopsfx (BYVAL num)
DECLARE SUB pausesfx (BYVAL num)
DECLARE SUB freesfx (BYVAL num) ' only used by custom's importing interface
DECLARE FUNCTION sfxisplaying (BYVAL num)
'DECLARE SUB getsfxvol (BYVAL num)
'DECLARE SUB setsfxvol (BYVAL num, BYVAL vol)

'DECLARE FUNCTION getsoundvol ()
'DECLARE SUB setsoundvol (BYVAL vol)

#ENDIF