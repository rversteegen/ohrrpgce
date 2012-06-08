'Allmodex FreeBasic Library header

#IFNDEF ALLMODEX_BI
#DEFINE ALLMODEX_BI

#include "udts.bi"
#include "config.bi"
#IFNDEF BITMAP
 'windows.bi may have been included
 #include "bitmap.bi"
#ENDIF
#include "file.bi"   'FB header
#include "lumpfile.bi"


'Library routines
DECLARE SUB modex_init ()
DECLARE SUB setmodex ()
DECLARE SUB modex_quit ()
DECLARE SUB restoremode ()
DECLARE SUB mersenne_twister (byval seed as double)
DECLARE SUB seedcrappyrand()
DECLARE FUNCTION crappyrand(byval limit as integer) as integer
DECLARE SUB setwindowtitle (title as string)
DECLARE FUNCTION allocatepage(byval w as integer = 320, byval h as integer = 200) as integer
DECLARE FUNCTION duplicatepage (byval page as integer) as integer
DECLARE SUB freepage (byval page as integer)
DECLARE FUNCTION registerpage (byval spr as Frame ptr) as integer
DECLARE SUB copypage (byval page1 as integer, byval page2 as integer)
DECLARE SUB clearpage (byval page as integer, byval colour as integer = -1)
DECLARE FUNCTION updatepagesize (byval page as integer) as integer
DECLARE SUB unlockresolution (byval min_w as integer = -1, byval min_h as integer = -1)
DECLARE SUB setresolution (byval w as integer, byval h as integer)
DECLARE SUB resetresolution ()
DECLARE SUB setvispage (byval page as integer)
DECLARE SUB setpal (pal() as RGBcolor)
DECLARE SUB fadeto (byval red as integer, byval green as integer, byval blue as integer)
DECLARE SUB fadetopal (pal() as RGBcolor)

DECLARE FUNCTION frame_to_tileset(byval spr as frame ptr) as frame ptr
DECLARE FUNCTION tileset_load(byval num as integer) as Frame ptr

DECLARE FUNCTION readblock (map as TileMap, byval x as integer, byval y as integer) as integer
DECLARE SUB writeblock (map as TileMap, byval x as integer, byval y as integer, byval v as integer)

DECLARE SUB drawmap OVERLOAD (tmap as TileMap, byval x as integer, byval y as integer, byval tileset as TilesetData ptr, byval p as integer, byval trans as integer = 0, byval overheadmode as integer = 0, byval pmapptr as TileMap ptr = NULL, byval ystart as integer = 0, byval yheight as integer = -1)
DECLARE SUB drawmap OVERLOAD (tmap as TileMap, byval x as integer, byval y as integer, byval tilesetsprite as Frame ptr, byval p as integer, byval trans as integer = 0, byval overheadmode as integer = 0, byval pmapptr as TileMap ptr = NULL, byval ystart as integer = 0, byval yheight as integer = -1, byval largetileset as integer = NO)
DECLARE SUB drawmap OVERLOAD (tmap as TileMap, byval x as integer, byval y as integer, byval tilesetsprite as Frame ptr, byval dest as Frame ptr, byval trans as integer = 0, byval overheadmode as integer = 0, byval pmapptr as TileMap ptr = NULL, byval largetileset as integer = NO)

DECLARE SUB setanim (byval cycle1 as integer, byval cycle2 as integer)
DECLARE SUB setoutside (byval defaulttile as integer)

'--box drawing
DECLARE SUB drawbox OVERLOAD (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval col as integer, byval thick as integer = 1, byval p as integer)
DECLARE SUB drawbox OVERLOAD (byval dest as Frame ptr, byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval col as integer, byval thick as integer = 1)
DECLARE SUB rectangle OVERLOAD (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval c as integer, byval p as integer)
DECLARE SUB rectangle OVERLOAD (byval fr as Frame Ptr, byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval c as integer)
DECLARE SUB fuzzyrect OVERLOAD (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval c as integer, byval p as integer, byval fuzzfactor as integer = 50)
DECLARE SUB fuzzyrect OVERLOAD (byval fr as Frame Ptr, byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval c as integer, byval fuzzfactor as integer = 50)

'NOTE: clipping values are global.
DECLARE SUB setclip OVERLOAD (byval l as integer = 0, byval t as integer = 0, byval r as integer = 999999, byval b as integer = 999999, byval fr as Frame ptr = 0)
DECLARE SUB setclip (byval l as integer = 0, byval t as integer = 0, byval r as integer = 999999, byval b as integer = 999999, byval page as integer)
DECLARE SUB shrinkclip(byval l as integer = 0, byval t as integer = 0, byval r as integer = 999999, byval b as integer = 999999, byval fr as Frame ptr)
DECLARE SUB saveclip(byref buf as ClipState)
DECLARE SUB loadclip(byref buf as ClipState)
DECLARE SUB drawspritex (pic() as integer, byval picoff as integer, pal() as integer, byval po as integer, byval x as integer, byval y as integer, byval page as integer, byval scale as integer=1, byval trans as integer = -1)
DECLARE SUB drawsprite (pic() as integer, byval picoff as integer, pal() as integer, byval po as integer, byval x as integer, byval y as integer, byval page as integer, byval trans as integer = -1)
DECLARE SUB wardsprite (pic() as integer, byval picoff as integer, pal() as integer, byval po as integer, byval x as integer, byval y as integer, byval page as integer, byval trans as integer = -1)
DECLARE SUB getsprite (pic() as integer, byval picoff as integer, byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval page as integer)
DECLARE SUB stosprite (pic() as integer, byval picoff as integer, byval x as integer, byval y as integer, byval page as integer)
DECLARE SUB loadsprite (pic() as integer, byval picoff as integer, byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval page as integer)
DECLARE SUB bigsprite  (pic() as integer, pal() as integer, byval p as integer, byval x as integer, byval y as integer, byval page as integer, byval trans as integer = -1)
DECLARE SUB hugesprite (pic() as integer, pal() as integer, byval p as integer, byval x as integer, byval y as integer, byval page as integer, byval trans as integer = -1)
DECLARE SUB putpixel OVERLOAD (byval spr as Frame ptr, byval x as integer, byval y as integer, byval c as integer)
DECLARE SUB putpixel OVERLOAD (byval x as integer, byval y as integer, byval c as integer, byval p as integer)
DECLARE FUNCTION readpixel OVERLOAD (byval spr as Frame ptr, byval x as integer, byval y as integer) as integer
DECLARE FUNCTION readpixel OVERLOAD (byval x as integer, byval y as integer, byval p as integer) as integer
DECLARE SUB drawline OVERLOAD (byval dest as Frame ptr, byval x1 as integer, byval y1 as integer, byval x2 as integer, byval y2 as integer, byval c as integer)
DECLARE SUB drawline OVERLOAD (byval x1 as integer, byval y1 as integer, byval x2 as integer, byval y2 as integer, byval c as integer, byval p as integer)
DECLARE SUB paintat (byval dest as Frame ptr, byval x as integer, byval y as integer, byval c as integer)
DECLARE SUB ellipse (byval fr as Frame ptr, byval x as double, byval y as double, byval radius as double, byval c as integer, byval fillcol as integer = -1, byval semiminor as double = 0.0, byval angle as double = 0.0)
DECLARE SUB replacecolor (byval fr as Frame ptr, byval c_old as integer, byval c_new as integer, byval x as integer = -1, byval y as integer = -1, byval w as integer = -1, byval h as integer = -1)

DECLARE SUB storemxs (fil as string, byval record as integer, byval fr as Frame ptr)
DECLARE FUNCTION loadmxs (fil as string, byval record as integer, byval dest as Frame ptr = 0) as Frame ptr

DECLARE SUB setwait (byval t as integer, byval flagt as integer = 0)
DECLARE FUNCTION dowait () as integer
DECLARE SUB enable_speed_control(byval setting as integer=YES)
DECLARE FUNCTION get_tickcount() as integer

DECLARE FUNCTION parse_tag(z as string, byval offset as integer, byval action as string ptr, byval arg as integer ptr) as integer

TYPE PrintStrStatePtr as PrintStrState Ptr

DECLARE SUB text_layout_dimensions (byval retsize as StringSize ptr, z as string, byval endchar as integer = 999999, byval maxlines as integer = 999999, byval wide as integer = 999999, byval fontnum as integer, byval withtags as integer = YES, byval withnewlines as integer = YES)
DECLARE SUB printstr OVERLOAD (byval dest as Frame ptr, s as string, byval x as integer, byval y as integer, byval wide as integer = 999999, byval fontnum as integer, byval withtags as integer = YES, byval withnewlines as integer = YES)
DECLARE SUB printstr OVERLOAD (s as string, byval x as integer, byval y as integer, byval p as integer, byval withtags as integer = NO)
DECLARE SUB edgeprint (s as string, byval x as integer, byval y as integer, byval c as integer, byval p as integer, byval withtags as integer = NO)
DECLARE SUB textcolor (byval fg as integer, byval bg as integer)

DECLARE FUNCTION textwidth (z as string, byval fontnum as integer = 0, byval withtags as integer = YES, byval withnewlines as integer = YES) as integer

DECLARE SUB find_point_in_text (byval retsize as StringCharPos ptr, byval seekx as integer, byval seeky as integer, z as string, byval wide as integer = 999999, byval xpos as integer, byval ypos as integer, byval fontnum as integer, byval withtags as integer = YES, byval withnewlines as integer = YES)

DECLARE SUB setfont (f() as integer)
DECLARE SUB font_create_edged (byval font as Font ptr, byval basefont as Font ptr)
DECLARE SUB font_create_shadowed (byval font as Font ptr, byval basefont as Font ptr, byval xdrop as integer = 1, byval ydrop as integer = 1)
DECLARE SUB font_loadbmps (byval font as Font ptr, directory as string, byval fallback as Font ptr = null)
DECLARE SUB font_loadbmp_16x16 (byval font as Font ptr, filename as string)

DECLARE SUB storeset (fil as string, byval i as integer, byval l as integer)
DECLARE SUB loadset (fil as string, byval i as integer, byval l as integer)
DECLARE SUB setpicstuf (buf() as integer, byval b as integer, byval p as integer)

DECLARE SUB setupmusic
DECLARE SUB closemusic ()
DECLARE SUB loadsong (f as string)
DECLARE SUB pausesong ()
DECLARE SUB resumesong ()
DECLARE FUNCTION get_music_volume () as single
DECLARE SUB set_music_volume (byval vol as single)

DECLARE SUB screenshot (f as string)
DECLARE SUB bmp_screenshot(f as string)
DECLARE SUB frame_export_bmp4 (f as string, byval fr as Frame Ptr, maspal() as RGBcolor, byval pal as Palette16 ptr)
DECLARE SUB frame_export_bmp8 (f as string, byval fr as Frame Ptr, maspal() as RGBcolor)
DECLARE FUNCTION frame_import_bmp24(bmp as string, pal() as RGBcolor) as Frame ptr
DECLARE FUNCTION frame_import_bmp_raw(bmp as string) as Frame ptr
DECLARE SUB bitmap2pal (bmp as string, pal() as RGBcolor)
DECLARE FUNCTION loadbmppal (f as string, pal() as RGBcolor) as integer
DECLARE SUB convertbmppal (f as string, mpal() as RGBcolor, pal() as integer, byval o as integer)
DECLARE FUNCTION nearcolor(pal() as RGBcolor, byval red as ubyte, byval green as ubyte, byval blue as ubyte) as ubyte
DECLARE FUNCTION bmpinfo (f as string, byref dat as BitmapInfoHeader) as integer

DECLARE FUNCTION isawav(fi as string) as integer

DECLARE FUNCTION keyval (byval a as integer, byval repeat_wait as integer = 0, byval repeat_rate as integer = 0) as integer
DECLARE FUNCTION getinputtext () as string
DECLARE FUNCTION anykeypressed (byval checkjoystick as integer = YES) as integer
DECLARE FUNCTION waitforanykey () as integer
DECLARE SUB setkeyrepeat (byval repeat_wait as integer = 500, byval repeat_rate as integer = 55)
DECLARE SUB setkeys (byval enable_inputtext as integer = NO)
DECLARE SUB clearkey (byval k as integer)
DECLARE SUB setquitflag ()
#DEFINE slowkey(key, ms) (keyval((key), (ms), (ms)) > 1)

DECLARE SUB start_recording_input (filename as string)
DECLARE SUB stop_recording_input ()
DECLARE SUB start_replaying_input (filename as string)
DECLARE SUB stop_replaying_input (msg as string="")

DECLARE FUNCTION havemouse () as integer
DECLARE SUB hidemousecursor ()
DECLARE SUB unhidemousecursor ()
DECLARE FUNCTION readmouse () as MouseInfo
DECLARE SUB movemouse (byval x as integer, byval y as integer)
DECLARE SUB mouserect (byval xmin as integer, byval xmax as integer, byval ymin as integer, byval ymax as integer)

DECLARE FUNCTION readjoy OVERLOAD (joybuf() as integer, byval jnum as integer) as integer
DECLARE FUNCTION readjoy (byval joynum as integer, byref buttons as integer, byref x as integer, byref y as integer) as integer

DECLARE SUB resetsfx ()
DECLARE SUB playsfx (byval num as integer, byval l as integer=0) 'l is loop count. -1 for infinite loop
DECLARE SUB stopsfx (byval num as integer)
DECLARE SUB pausesfx (byval num as integer)
DECLARE SUB freesfx (byval num as integer) ' only used by custom's importing interface
DECLARE FUNCTION sfxisplaying (byval num as integer) as integer
DECLARE FUNCTION getmusictype (file as string) as integer
'DECLARE SUB getsfxvol (byval num as integer)
'DECLARE SUB setsfxvol (byval num as integer, byval vol as integer)

'DECLARE FUNCTION getsoundvol () as integer
'DECLARE SUB setsoundvol (byval vol)

'new sprite functions
declare function frame_new(byval w as integer, byval h as integer, byval frames as integer = 1, byval clr as integer = NO, byval wantmask as integer = NO) as Frame ptr
declare function frame_new_view(byval spr as Frame ptr, byval x as integer, byval y as integer, byval w as integer, byval h as integer) as Frame ptr
declare function frame_new_from_buffer(pic() as integer, byval picoff as integer) as Frame ptr
declare function frame_load overload (byval ptno as integer, byval rec as integer) as frame ptr
declare function frame_load(as string, byval as integer, byval as integer , byval as integer, byval as integer) as frame ptr
declare function frame_reference(byval p as frame ptr) as frame ptr
declare sub frame_unload(byval p as frame ptr ptr)
declare sub frame_draw overload (byval src as frame ptr, Byval pal as Palette16 ptr = NULL, Byval x as integer, Byval y as integer, Byval scale as integer = 1, Byval trans as integer = -1, byval page as integer)
declare sub frame_draw(byval src as Frame ptr, Byval pal as Palette16 ptr = NULL, Byval x as integer, Byval y as integer, Byval scale as integer = 1, Byval trans as integer = YES, byval dest as Frame ptr)
declare function frame_dissolved(byval spr as frame ptr, byval tlength as integer, byval t as integer, byval style as integer) as frame ptr
declare function default_dissolve_time(byval style as integer, byval w as integer, byval h as integer) as integer
declare sub frame_flip_horiz(byval spr as frame ptr)
declare sub frame_flip_vert(byval spr as frame ptr)
declare function frame_rotated_90(byval spr as Frame ptr) as Frame ptr
declare function frame_rotated_270(byval spr as Frame ptr) as Frame ptr
declare function frame_duplicate(byval p as frame ptr, byval clr as integer = 0, byval addmask as integer = 0) as frame ptr
declare sub frame_clear(byval spr as frame ptr, byval colour as integer = 0)
declare sub sprite_empty_cache()
declare sub sprite_update_cache_pt(byval ptno as integer)
declare sub sprite_update_cache_tilesets()
declare sub tileset_empty_cache()
declare function frame_is_valid(byval p as frame ptr) as integer
declare sub sprite_debug_cache()
declare function frame_describe(byval p as frame ptr) as string

declare function palette16_new() as palette16 ptr
declare function palette16_new_from_buffer(pal() as integer, byval po as integer) as Palette16 ptr
declare function palette16_load overload (byval num as integer, byval autotype as integer = 0, byval spr as integer = 0) as palette16 ptr
declare function palette16_load(fil as string, byval num as integer, byval autotype as integer = 0, byval spr as integer = 0) as palette16 ptr
declare sub palette16_unload(byval p as palette16 ptr ptr)
declare sub palette16_empty_cache()
declare sub palette16_update_cache(fil as string, byval num as integer)


'globals
extern vpages() as Frame ptr
extern vpagesp as Frame ptr ptr
extern key2text(3,53) as string*1
extern disable_native_text_input as integer
extern fonts() as Font

#ENDIF
