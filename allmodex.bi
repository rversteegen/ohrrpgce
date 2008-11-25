'Allmodex FreeBasic Library header

#IFNDEF ALLMODEX_BI
#DEFINE ALLMODEX_BI

#include "udts.bi"
#include "compat.bi"

'Library routines
DECLARE SUB setmodex ()
DECLARE SUB restoremode ()
DECLARE FUNCTION allocatepage() as integer
DECLARE SUB freepage (BYVAL page as integer)
DECLARE SUB copypage (BYVAL page1 as integer, BYVAL page2 as integer, BYVAL y as integer = 0, BYVAL top as integer = 0, BYVAL bottom as integer = 199)
DECLARE SUB clearpage (BYVAL page as integer, BYVAL top as integer = 0, BYVAL bottom as integer = 199, BYVAL colour as integer = 0)
DECLARE SUB setvispage (BYVAL page as integer)
DECLARE SUB setpal (pal() as RGBcolor)
DECLARE SUB fadeto (BYVAL red as integer, BYVAL green as integer, BYVAL blue as integer)
DECLARE SUB fadetopal (pal() as RGBcolor)
DECLARE SUB loadtileset (BYREF tileset as Frame ptr, BYVAL page as integer)
DECLARE SUB unloadtileset (BYREF tileset as Frame ptr)
DECLARE SUB setmapdata (array() as integer, pas() as integer, BYVAL t as integer, BYVAL b as integer)
DECLARE SUB setmapblock (BYVAL x as integer, BYVAL y as integer, byval l as integer, BYVAL v as integer)
DECLARE FUNCTION readmapblock (BYVAL x as integer, BYVAL y as integer, byval l as integer) as integer
DECLARE SUB setpassblock (BYVAL x as integer, BYVAL y as integer, BYVAL v as integer)
DECLARE FUNCTION readpassblock (BYVAL x as integer, BYVAL y as integer) as integer
DECLARE SUB drawmap overload (BYVAL x as integer, BYVAL y as integer, BYVAL l as integer, BYVAL t as integer, BYVAL tileset as TilesetData ptr, BYVAL p as integer, byval trans as integer = 0)
DECLARE SUB drawmap (BYVAL x as integer, BYVAL y as integer, BYVAL l as integer, BYVAL t as integer, BYVAL tilesetsprite as Frame ptr, BYVAL p as integer, byval trans as integer = 0)
DECLARE SUB setanim (BYVAL cycle1 as integer, BYVAL cycle2 as integer)
DECLARE SUB setoutside (BYVAL defaulttile as integer)
DECLARE SUB drawsprite (pic() as integer, BYVAL picoff as integer, pal() as integer, BYVAL po as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, BYVAL trans as integer = -1)
DECLARE SUB wardsprite (pic() as integer, BYVAL picoff as integer, pal() as integer, BYVAL po as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, BYVAL trans as integer = -1)
DECLARE SUB getsprite (pic() as integer, BYVAL picoff as integer, BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL page as integer)
DECLARE SUB stosprite (pic() as integer, BYVAL picoff as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer)
DECLARE SUB loadsprite (pic() as integer, BYVAL picoff as integer, BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL page as integer)
DECLARE SUB bigsprite  (pic() as integer, pal() as integer, BYVAL p as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, BYVAL trans as integer = -1)
DECLARE SUB hugesprite (pic() as integer, pal() as integer, BYVAL p as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, BYVAL trans as integer = -1)
DECLARE SUB putpixel (BYVAL x as integer, BYVAL y as integer, BYVAL c as integer, BYVAL p as integer)
DECLARE FUNCTION readpixel (BYVAL x as integer, BYVAL y as integer, BYVAL p as integer) as integer
DECLARE SUB rectangle (BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL c as integer, BYVAL p as integer)
DECLARE SUB fuzzyrect (BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL c as integer, BYVAL p as integer)
DECLARE SUB drawline (BYVAL x1 as integer, BYVAL y1 as integer, BYVAL x2 as integer, BYVAL y2 as integer, BYVAL c as integer, BYVAL p as integer)
DECLARE SUB paintat (BYVAL x as integer, BYVAL y as integer, BYVAL c as integer, BYVAL page as integer, buf() as integer, BYVAL max as integer)
DECLARE SUB storepage (fil as string, BYVAL i as integer, BYVAL p as integer)
DECLARE SUB loadpage (fil as string, BYVAL i as integer, BYVAL p as integer)
DECLARE SUB setwait (BYVAL t as integer, BYVAL flagt as integer = 0)
DECLARE FUNCTION dowait () as integer
DECLARE SUB printstr (s as string, BYVAL x as integer, BYVAL y as integer, BYVAL p as integer)
DECLARE SUB textcolor (BYVAL f as integer, BYVAL b as integer)
DECLARE SUB setfont (f() as integer)
DECLARE SUB setbit (b() as integer, BYVAL w as integer, BYVAL b as integer, BYVAL v as integer)
DECLARE FUNCTION readbit (b() as integer, BYVAL w as integer, BYVAL b as integer) as integer
DECLARE SUB storeset (fil as string, BYVAL i as integer, BYVAL l as integer)
DECLARE SUB loadset (fil as string, BYVAL i as integer, BYVAL l as integer)
DECLARE SUB setpicstuf (buf() as integer, BYVAL b as integer, BYVAL p as integer)
DECLARE FUNCTION loadrecord overload (buf() as integer, fh as integer, recordsize as integer, record as integer = -1) as integer
DECLARE FUNCTION loadrecord overload (buf() as integer, filename as string, recordsize as integer, record as integer = 0) as integer
DECLARE SUB storerecord overload (buf() as integer, fh as integer, recordsize as integer, record as integer = -1)
DECLARE SUB storerecord overload (buf() as integer, filename as string, recordsize as integer, record as integer = 0)
DECLARE SUB fixspriterecord (buf() as integer, w as integer, h as integer)
DECLARE SUB bitmap2page (pal() as RGBcolor, bmp as string, BYVAL p as integer)
DECLARE SUB findfiles overload(fmask as string, BYVAL attrib as integer, outfile as string, buf() as integer)
DECLARE SUB findfiles (fmask as string, BYVAL attrib as integer, outfile as string)
DECLARE SUB lumpfiles (listf as string, lump as string, path as string)
DECLARE SUB unlump(lump as string, ulpath as string)
DECLARE SUB unlumpfile(lump as string, fmask as string, path as string)
DECLARE FUNCTION islumpfile (lump as string, fmask as string) as integer
DECLARE FUNCTION isfile (n as string) as integer
DECLARE FUNCTION isdir (sDir as string) as integer
DECLARE FUNCTION drivelist (d() as string) as integer
DECLARE FUNCTION drivelabel (drive as string) as string
DECLARE FUNCTION isremovable (drive as string) as integer
DECLARE FUNCTION hasmedia (drive as string) as integer
DECLARE SUB setupmusic
DECLARE SUB closemusic ()
DECLARE SUB loadsong (f as string)
DECLARE SUB pausesong ()
DECLARE SUB resumesong ()
DECLARE FUNCTION getfmvol () as integer
DECLARE SUB setfmvol (BYVAL vol as integer)
DECLARE SUB copyfile (s as string, d as string)
DECLARE SUB screenshot (f as string, BYVAL p as integer, maspal() as RGBcolor)
DECLARE SUB sprite_export_bmp8 (f$, fr as Frame Ptr, maspal() as RGBcolor)
DECLARE SUB loadbmp (f as string, BYVAL x as integer, BYVAL y as integer, BYVAL p as integer)
DECLARE SUB bitmap2pal (bmp as string, pal() as RGBcolor)
DECLARE FUNCTION loadbmppal (f as string, pal() as RGBcolor) as integer
DECLARE SUB convertbmppal (f as string, mpal() as RGBcolor, pal() as integer, BYVAL o as integer)
DECLARE FUNCTION nearcolor(pal() as RGBcolor, byval red as ubyte, byval green as ubyte, byval blue as ubyte) as ubyte
DECLARE FUNCTION bmpinfo (f as string, dat() as integer) as integer
DECLARE SUB array2str (arr() as integer, BYVAL o as integer, s as string)
DECLARE SUB str2array (s as string, arr() as integer, BYVAL o as integer)
DECLARE SUB setupstack ()
DECLARE SUB pushw (BYVAL word as integer)
DECLARE FUNCTION popw () as integer
DECLARE SUB pushdw (BYVAL word as integer)
DECLARE FUNCTION popdw () as integer
DECLARE SUB releasestack ()
DECLARE FUNCTION stackpos () as integer
DECLARE FUNCTION readstackdw (BYVAL off as integer) as integer
DECLARE SUB drawbox(BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL c as integer, BYVAL p as integer)
DECLARE FUNCTION isawav(fi as string) as integer
DECLARE FUNCTION fileisreadable(f as string) as integer
DECLARE FUNCTION fileiswriteable(f as string) as integer

DECLARE FUNCTION keyval (BYVAL a as integer, BYVAL rwait as integer = 0, BYVAL rrate as integer = 0) as integer
DECLARE FUNCTION getkey () as integer
DECLARE FUNCTION waitforanykey (modkeys as integer = -1) as integer
DECLARE SUB setkeyrepeat (rwait as integer = 8, rrate as integer = 1)
DECLARE SUB setkeys ()
DECLARE SUB clearkey (byval k as integer)
DECLARE FUNCTION setmouse (mbuf() as integer) as integer
DECLARE SUB readmouse (mbuf() as integer)
DECLARE SUB movemouse (BYVAL x as integer, BYVAL y as integer)
DECLARE SUB mouserect (BYVAL xmin as integer, BYVAL xmax as integer, BYVAL ymin as integer, BYVAL ymax as integer)
DECLARE FUNCTION readjoy (joybuf() as integer, BYVAL jnum as integer) as integer
#DEFINE slowkey(key, fraction) (keyval((key), (fraction), (fraction)) > 1)

DECLARE SUB resetsfx ()
DECLARE SUB playsfx (BYVAL num as integer, BYVAL l as integer=0) 'l is loop count. -1 for infinite loop
DECLARE SUB stopsfx (BYVAL num as integer)
DECLARE SUB pausesfx (BYVAL num as integer)
DECLARE SUB freesfx (BYVAL num as integer) ' only used by custom's importing interface
DECLARE FUNCTION sfxisplaying (BYVAL num as integer) as integer
DECLARE FUNCTION getmusictype (file as string) as integer
'DECLARE SUB getsfxvol (BYVAL num as integer)
'DECLARE SUB setsfxvol (BYVAL num as integer, BYVAL vol as integer)

'DECLARE FUNCTION getsoundvol () as integer
'DECLARE SUB setsoundvol (BYVAL vol)

'new sprite functions
declare function sprite_load(byval as string, byval as integer, byval as integer , byval as integer, byval as integer) as frame ptr
declare sub sprite_unload(byval p as frame ptr ptr)
declare sub sprite_draw(byval spr as frame ptr, Byval pal as Palette16 ptr, Byval x as integer, Byval y as integer, Byval scale as integer = 1, Byval trans as integer = -1, byval page as integer)
declare function sprite_dissolve(byval spr as frame ptr, byval tim as integer, byval p as integer, byval style as integer = 0, byval direct as integer = 0) as frame ptr
declare function sprite_flip_horiz(byval spr as frame ptr, byval direct as integer = 0) as frame ptr
declare function sprite_flip_vert(byval spr as frame ptr, byval direct as integer = 0) as frame ptr
declare function sprite_duplicate(byval p as frame ptr, byval clr as integer = 0) as frame ptr
declare sub sprite_clear(byval spr as frame ptr)
declare sub sprite_empty_cache()
declare function sprite_is_valid(byval p as frame ptr) as integer
declare sub sprite_crash_invalid(byval p as frame ptr)

declare function palette16_load(byval fil as string, byval num as integer, byval autotype as integer = 0, byval spr as integer = 0) as palette16 ptr
declare sub palette16_unload(byval p as palette16 ptr ptr)
declare sub palette16_empty_cache()

#ENDIF
