'OHRRPGCE CUSTOM - Mostly drawing-related routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'

#include "config.bi"
#include "udts.bi"
#include "custom_udts.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "customsubs.bi"
#include "cglobals.bi"
#include "const.bi"
#include "custom.bi"
#include "string.bi"

CONST COLORNUM_SHOW_TICKS = 30

'External subs and functions
DECLARE SUB loadpasdefaults (byref defaults as integer vector, tilesetnum as integer)
DECLARE SUB savepasdefaults (byref defaults as integer vector, tilesetnum as integer)
DECLARE FUNCTION importmasterpal (f as string, byval palnum as integer) as integer

'Local SUBs and FUNCTIONS

DECLARE SUB airbrush (spr as Frame ptr, byval x as integer, byval y as integer, byval d as integer, byval m as integer, byval c as integer)

DECLARE FUNCTION pick_image_pixel(image as Frame ptr, pal16 as Palette16 ptr = NULL, byref pickpos as XYPair, zoom as integer = 1, maxx as integer = 9999, maxy as integer = 9999, message as string, helpkey as string) as bool
DECLARE FUNCTION mouseover (byval mousex as integer, byval mousey as integer, byref zox as integer, byref zoy as integer, byref zcsr as integer, area() as MouseArea) as integer

DECLARE FUNCTION importbmp_processbmp(srcbmp as string, pmask() as RGBcolor) as Frame ptr
DECLARE FUNCTION importbmp_import(mxslump as string, imagenum as integer, srcbmp as string, pmask() as RGBcolor) as bool
DECLARE SUB select_disabled_import_colors(pmask() as RGBcolor, image as Frame ptr)

' Tileset editor
DECLARE SUB picktiletoedit (byref tmode as integer, byval tilesetnum as integer, mapfile as string, bgcolor as bgType)
DECLARE SUB editmaptile (ts as TileEditState, mouse as MouseInfo, area() as MouseArea, bgcolor as bgType)
DECLARE SUB tilecut (ts as TileEditState, mouse as MouseInfo)
DECLARE SUB refreshtileedit (state as TileEditState)
DECLARE SUB writeundoblock (state as TileEditState)
DECLARE SUB readundoblock (state as TileEditState)
DECLARE SUB fliptile (ts as TileEditState)
DECLARE SUB scrolltile (ts as TileEditState, byval shiftx as integer, byval shifty as integer)
DECLARE SUB clicktile (ts as TileEditState, byval newkeypress as integer, byref clone as TileCloneBuffer)
DECLARE SUB tilecopy (cutnpaste() as integer, ts as TileEditState)
DECLARE SUB tilepaste (cutnpaste() as integer, ts as TileEditState)
DECLARE SUB tiletranspaste (cutnpaste() as integer, ts as TileEditState)
DECLARE SUB copymapblock (sx as integer, sy as integer, sp as integer, dx as integer, dy as integer, dp as integer)
DECLARE SUB tileedit_set_tool (ts as TileEditState, toolinfo() as ToolInfoType, byval toolnum as integer)

' Tileset animation editor
DECLARE SUB testanimpattern (tastuf() as integer, byref taset as integer)
DECLARE SUB setanimpattern (tastuf() as integer, taset as integer, tilesetnum as integer)
DECLARE SUB setanimpattern_refreshmenu(byval pt as integer, menu() as string, menu2() as string, tastuf() as integer, byval taset as integer, llim() as integer, ulim() as integer)
DECLARE SUB setanimpattern_forcebounds(tastuf() as integer, byval taset as integer, llim() as integer, ulim() as integer)
DECLARE SUB tile_anim_set_range(tastuf() as integer, byval taset as integer, byval tilesetnum as integer)
DECLARE SUB tile_animation(byval tilesetnum as integer)
DECLARE SUB tile_edit_mode_picker(byval tilesetnum as integer, mapfile as string, byref bgcolor as bgType)

' Spriteset browser (TODO: misnamed)
DECLARE SUB spriteedit_load_spriteset(byval setnum as integer, byval top as integer, ss as SpriteSetBrowseState)
DECLARE SUB spriteedit_save_spriteset(byval setnum as integer, byval top as integer, ss as SpriteSetBrowseState)
DECLARE SUB spriteedit_save_all_you_see(byval top as integer, ss as SpriteSetBrowseState)
DECLARE SUB spriteedit_load_all_you_see(byval top as integer, ss as SpriteSetBrowseState, workpal() as integer, poffset() as integer)
DECLARE SUB spriteedit_get_loaded_sprite(ss as SpriteSetBrowseState, placer() as integer, top as integer, setnum as integer, framenum as integer)
DECLARE SUB spriteedit_set_loaded_sprite(ss as SpriteSetBrowseState, placer() as integer, top as integer, setnum as integer, framenum as integer)
DECLARE FUNCTION spriteedit_export_name (ss as SpriteSetBrowseState, state as MenuState) as string
DECLARE SUB spritebrowse_save_callback(spr as Frame ptr, context as any ptr)

' Sprite editor
DECLARE SUB sprite_editor(ss as SpriteEditState, sprite as Frame ptr)
DECLARE SUB init_sprite_zones(area() as MouseArea, ss as SpriteEditState)
DECLARE SUB textcolor_icon(selected as bool, hover as bool)
DECLARE SUB spriteedit_draw_icon(ss as SpriteEditState, icon as string, byval areanum as integer, byval highlight as integer = NO)
DECLARE SUB spriteedit_draw_palette(pal16 as Palette16 ptr, x as integer, y as integer, page as integer)
DECLARE SUB spriteedit_draw_sprite_area(ss as SpriteEditState, sprite as Frame ptr, pal as Palette16 ptr, page as integer)
DECLARE SUB spriteedit_display(ss as SpriteEditState)
DECLARE SUB spriteedit_scroll (ss as SpriteEditState, byval shiftx as integer, byval shifty as integer)
DECLARE SUB spriteedit_clip (ss as SpriteEditState)
DECLARE SUB changepal OVERLOAD (byref palval as integer, byval palchange as integer, workpal() as integer, byval aindex as integer)
DECLARE SUB changepal OVERLOAD (ss as SpriteEditState, palchange as integer)
DECLARE SUB writeundospr (ss as SpriteEditState)
DECLARE SUB readundospr (ss as SpriteEditState)
DECLARE SUB readredospr (ss as SpriteEditState)

' Sprite import/export
DECLARE SUB spriteedit_import16(byref ss as SpriteEditState)
DECLARE SUB spriteedit_export OVERLOAD (default_name as string, placer() as integer, palnum as integer)
DECLARE SUB spriteedit_export OVERLOAD (default_name as string, spr as Frame ptr, pal as Palette16 ptr)

' Locals
DIM SHARED ss_save as SpriteEditStatic

WITH ss_save
 .tool = draw_tool
 .airsize = 5
 .mist = 4
 .palindex = 1
 .hidemouse = NO
END WITH


SUB airbrush (spr as Frame ptr, byval x as integer, byval y as integer, byval d as integer, byval m as integer, byval c as integer)
 'airbrush thanks to Ironhoof (Russel Hamrick)

 'AirBrush this rutine works VERY well parameters as fallows:
 ' AIRBRUSH sprite , x , y , diameter , mist_amount , color
 ' diameter sets the width & hight by square radius
 ' mist_amount sets how many pixels to place i put 100 and it ran fast so
 ' it works EXCELLENTLY with a mouse on the DTE =)

 FOR count as integer = 1 TO randint(m)
  DIM x2 as integer = randint(d)
  DIM y2 as integer = randint(d)
  DIM x3 as integer = x - d / 2
  DIM y3 as integer = y - d / 2
  IF ABS((x3 + x2) - x) ^ 2 + ABS((y3 + y2) - y) ^ 2 <= d ^ 2 / 4 THEN
   putpixel spr, x3 + x2, y3 + y2, c
  END IF
 NEXT
END SUB

' Overload used by spriteset browser
' Does NOT save palette
SUB changepal OVERLOAD (byref palval as integer, byval palchange as integer, workpal() as integer, byval aindex as integer)
 palval = bound(palval + palchange, 0, 32767)
 getpal16 workpal(), aindex, palval
END SUB

' Overload used by sprite editor
' Save current palette and load another one. When palchange=0, just saves current
SUB changepal OVERLOAD (ss as SpriteEditState, palchange as integer)
 palette16_save ss.palette, ss.pal_num
 ss.pal_num = bound(ss.pal_num + palchange, 0, 32767)
 palette16_unload @ss.palette
 ss.palette = palette16_load(ss.pal_num)
END SUB

'Copy a tile from one vpage to another
SUB copymapblock (sx as integer, sy as integer, sp as integer, dx as integer, dy as integer, dp as integer)
 DIM srctile as Frame ptr
 srctile = frame_new_view(vpages(sp), sx, sy, 20, 20)
 frame_draw srctile, NULL, dx, dy, , NO, dp
 frame_unload @srctile
END SUB

'Used inside select_disabled_import_colors
PRIVATE SUB toggle_pmask (pmask() as RGBcolor, master() as RGBcolor, index as integer)
 pmask(index).r xor= master(index).r
 pmask(index).g xor= master(index).g
 pmask(index).b xor= master(index).b
 setpal pmask()
END SUB

SUB importbmp (f as string, cap as string, byref count as integer, sprtype as SpriteType)
 STATIC defaultdir as string  'Import & export
 DIM pmask(255) as RGBcolor
 DIM menu(6) as string
 DIM mstate as MenuState
 mstate.size = 24
 mstate.last = UBOUND(menu)
 DIM menuopts as MenuOptions
 menuopts.edged = YES
 menu(0) = "Return to Main Menu"
 menu(1) = CHR(27) + "Browse 0" + CHR(26)
 menu(2) = "Replace current " + cap
 menu(3) = "Append a new " + cap
 menu(4) = "Disable palette colors for import"
 menu(5) = "Export " + cap + " as BMP"
 menu(6) = "Full screen view"
 DIM srcbmp as string
 DIM pt as integer = 0 'backdrop number

 IF count = 0 THEN count = 1
 loadpalette pmask(), activepalette
 loadmxs game & f, pt, vpages(2)

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scCtrl) > 0 AND keyval(scBackspace) > 1 THEN
   DIM crop_this as integer = count - 1
   cropafter pt, crop_this, 3, game + f, 64000
   count = crop_this + 1
  END IF
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "importbmp"
  usemenu mstate
  IF intgrabber(pt, 0, count - 1) THEN
   menu(1) = CHR(27) + "Browse " & pt & CHR(26)
   loadmxs game + f, pt, vpages(2)
  END IF
  IF enter_space_click(mstate) THEN
   IF mstate.pt = 0 THEN EXIT DO
   IF mstate.pt = 2 THEN
    'Replace current
    srcbmp = browse(3, defaultdir, "*.bmp", "", , "browse_import_" & cap)
    IF srcbmp <> "" THEN
     importbmp_import(game & f, pt, srcbmp, pmask())
    END IF
    loadmxs game + f, pt, vpages(2)
   END IF
   IF mstate.pt = 3 AND count < 32767 THEN
    'Append new
    srcbmp = browse(3, defaultdir, "*.bmp", "", , "browse_import_" & cap)
    IF srcbmp <> "" THEN
     IF importbmp_import(game & f, count, srcbmp, pmask()) THEN
      pt = count
      count = pt + 1
     END IF
    END IF
    menu(1) = CHR(27) + "Browse " & pt & CHR(26)
    loadmxs game + f, pt, vpages(2)
   END IF
   IF mstate.pt = 4 THEN
    select_disabled_import_colors pmask(), vpages(2)
   END IF
   IF mstate.pt = 5 THEN
    DIM outfile as string
    outfile = inputfilename("Name of file to export to?", ".bmp", defaultdir, "input_file_export_screen", trimextension(trimpath(sourcerpg)) & " " & cap & pt)
    IF outfile <> "" THEN frame_export_bmp8 outfile & ".bmp", vpages(2), master()
   END IF
  END IF
  copypage 2, dpage
  IF mstate.pt <> 6 THEN
   standardmenu menu(), mstate, 0, 0, dpage, menuopts
  END IF
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 clearpage 2
 sprite_update_cache sprtype
END SUB

' This is the new browser/editor for backdrops.
' TODO: imported backdrops are not saved.
SUB backdrop_browser ()
 STATIC default as string
 DIM pmask(255) as RGBcolor
 DIM srcbmp as string
 DIM backdrop_id as integer = 0

 DIM bgcolor as bgType = bgChequer
 DIM chequer_scroll as integer

 DIM menu(8) as string

 DIM mstate as MenuState
 mstate.last = UBOUND(menu)
 mstate.need_update = YES
 DIM menuopts as MenuOptions
 menuopts.edged = YES

 DIM backdrops_file as string = workingdir + SLASH "backdrops.rgfx"
 IF NOT isfile(backdrops_file) THEN
  'Gives notification about time taken
  convert_mxs_to_rgfx(game + ".mxs", backdrops_file)
 END IF

 DIM BYREF count as integer = gen(genNumBackdrops)
 IF count = 0 THEN count = 1

 loadpalette pmask(), activepalette

 DIM rgfx_doc as DocPtr = rgfx_open(backdrops_file)
 DIM backdrop as Frame ptr
 frame_assign @backdrop, rgfx_get_frame(rgfx_doc, backdrop_id, 0)

 setkeys
 DO
  setwait 55
  setkeys
  chequer_scroll += 1
  IF keyval(scCtrl) > 0 AND keyval(scBackspace) > 1 THEN
   DIM crop_this as integer = count - 1
   ' FIXME: Not implemented
   count = crop_this + 1
  END IF
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "backdrop_browser"
  usemenu mstate
  IF mstate.pt <> 6 ANDALSO intgrabber(backdrop_id, 0, count - 1) THEN
   ' Change selected backdrop
   frame_assign @backdrop, rgfx_get_frame(rgfx_doc, backdrop_id, 0)
   IF backdrop = NULL THEN debugc errPromptBug, "rgfx failed to load" : EXIT DO
   mstate.need_update = YES
  END IF
  IF enter_space_click(mstate) THEN
   IF mstate.pt = 0 THEN EXIT DO
   IF mstate.pt = 2 THEN
    'Replace current
    srcbmp = browse(2, default, "*.bmp", "", , "browse_import_backdrop")
    IF srcbmp <> "" THEN
     DIM imported as Frame ptr = importbmp_processbmp(srcbmp, pmask())
     IF imported THEN frame_assign @backdrop, imported
     mstate.need_update = YES
    END IF
   END IF
   IF mstate.pt = 3 AND count < 32767 THEN
    'Append new
    srcbmp = browse(2, default, "*.bmp", "", , "browse_import_backdrop")
    IF srcbmp <> "" THEN
     DIM imported as Frame ptr = importbmp_processbmp(srcbmp, pmask())
     IF imported THEN
      frame_assign @backdrop, imported
      backdrop_id = count
      'count = backdrop_id + 1   ' FIXME: Commented because saving unimplemented
      mstate.need_update = YES
     END IF
    END IF
   END IF
   IF mstate.pt = 4 THEN
    select_disabled_import_colors pmask(), backdrop
   END IF
   IF mstate.pt = 5 THEN
    DIM outfile as string
    outfile = inputfilename("Name of file to export to?", ".bmp", "", "input_file_export_screen", _
                            trimextension(trimpath(sourcerpg)) & " backdrop" & backdrop_id)
    IF outfile <> "" THEN frame_export_bmp8 outfile & ".bmp", backdrop, master()
   END IF
  END IF
  IF mstate.pt = 6 THEN mstate.need_update OR= intgrabber(bgcolor, bgFIRST, 255)

  IF mstate.need_update THEN
   mstate.need_update = NO
   menu(0) = "Return to Main Menu"
   menu(1) = CHR(27) + "Backdrop " & backdrop_id & CHR(26)
   menu(2) = "Replace current backdrop"
   menu(3) = "Append a new backdrop"
   menu(4) = "Disable palette colors for import"
   menu(5) = "Export backdrop as BMP"
   menu(6) = "Background: " & bgcolor_caption(bgcolor)
   menu(7) = "Size: " & backdrop->w & " x " & backdrop->h
   menu(8) = "Hide menu"
  END IF

  clearpage vpage
  'Show the size of the backdrop by outlining it
  drawbox pRight + 1, pBottom + 1, backdrop->w + 2, backdrop->h + 2, uilook(uiMenuItem), 1, vpage
  frame_draw_with_background backdrop, , pRight + showLeft, pBottom + showTop, , bgcolor, chequer_scroll, vpages(vpage)
  IF mstate.pt <> 8 THEN
   standardmenu menu(), mstate, 0, 0, vpage, menuopts
  END IF
  setvispage vpage
  dowait
 LOOP
 frame_unload @backdrop
 FreeDocument rgfx_doc
 safekill backdrops_file  ' Not live yet
 'sprite_update_cache sprTypeBackdrop
END SUB

' Display an image and select which colours in a copy
' of the master palette to set to black.
PRIVATE SUB select_disabled_import_colors(pmask() as RGBcolor, image as Frame ptr)
 DIM tog as integer
 DIM prev_menu_selected as bool  ' "Previous Menu" is current selection
 DIM cx as integer
 DIM cy as integer
 DIM mouse as MouseInfo
 DIM image_pos as XYPair

 hidemousecursor

 setpal pmask()
 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
  image_pos = get_resolution() - XY(image->w, image->h)
  mouse = readmouse()
  WITH mouse
   IF .clickstick AND mouseleft THEN
    IF rect_collide_point(str_rect("Previous Menu", 0, 0), .x, .y) THEN
     EXIT DO
    ELSE
     DIM rect as RectType
     rect.wide = 10  '2 pixels wider than real squares, to avoid gaps
     rect.high = 10
     DIM col as integer = -1
     'Click on a palette colour
     FOR xidx as integer = 0 TO 15
      FOR yidx as integer = 0 TO 15
       rect.topleft = XY(xidx * 10, 8 + yidx * 10)
       IF rect_collide_point(rect, .x, .y) THEN col = yidx * 16 + xidx
      NEXT
     NEXT
     'Click on an image pixel (safe if the position is off the edge of the image)
     IF col = -1 THEN col = readpixel(image, .x - image_pos.x, .y - image_pos.y)
     toggle_pmask pmask(), master(), col
    END IF
   END IF
  END WITH

  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "importbmp_disable"
  IF prev_menu_selected THEN
   IF enter_or_space() THEN EXIT DO
   IF keyval(scDown) > 1 THEN
    cy = 0
    prev_menu_selected = NO
   END IF
  ELSE
   IF keyval(scLeft) > 1 THEN cx = large(cx - 1, 0)
   IF keyval(scRight) > 1 THEN cx = small(cx + 1, 15)
   IF keyval(scDown) > 1 THEN cy = small(cy + 1, 15)
   IF keyval(scUp) > 1 THEN cy -= 1
   IF cy < 0 THEN
    cy = 0
    prev_menu_selected = YES
   END IF
   IF enter_or_space() THEN
    toggle_pmask pmask(), master(), cy * 16 + cx
   END IF
  END IF

  clearpage dpage
  frame_draw image, , image_pos.x, image_pos.y, , NO, dpage
  textcolor uilook(uiMenuItem), 0
  IF prev_menu_selected THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr "Previous Menu", 0, 0, dpage
  IF prev_menu_selected = NO THEN rectangle 0 + cx * 10, 8 + cy * 10, 10, 10, uilook(uiSelectedItem + tog), dpage
  FOR i as integer = 0 TO 15
   FOR o as integer = 0 TO 15
    rectangle 1 + o * 10, 9 + i * 10, 8, 8, i * 16 + o, dpage
   NEXT o
  NEXT i
  printstr CHR(2), mouse.x - 2, mouse.y - 2, dpage
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 setpal master()
 defaultmousecursor
END SUB

'Give the user the chance to remap a color to 0.
SUB importbmp_change_background_color(img as Frame ptr)
 DIM pickpos as XYPair
 DIM ret as bool
 DIM message as string = !"Pick the background (transparent) color\nor press ESC to skip remapping"
 ret = pick_image_pixel(img, , pickpos, , , , message, "importbmp_pickbackground")
 IF ret THEN
  DIM bgcol as integer = readpixel(img, pickpos.x, pickpos.y)
  replacecolor img, bgcol, 0
 END IF
END SUB

' Read a BMP file, check the bitdepth and palette and perform any necessary
' remapping, possibly create a new master palette (and change activepalette),
' and return the resulting (unsaved) Frame, or NULL if cancelled.
FUNCTION importbmp_processbmp(srcbmp as string, pmask() as RGBcolor) as Frame ptr
 DIM bmpd as BitmapV3InfoHeader
 DIM menu(2) as string
 DIM paloption as integer
 DIM img as Frame ptr
 DIM temppal(255) as RGBcolor
 DIM palmapping(255) as integer

 bmpinfo(srcbmp, bmpd)
 IF bmpd.biBitCount <= 8 THEN
  paloption = 0  'Perform remapping, otherwise disabling colors won't work
  loadbmppal srcbmp, temppal()
  IF memcmp(@temppal(0), @master(0), 256 * sizeof(RGBcolor)) <> 0 THEN
   'the palette is inequal to the master palette
   clearpage vpage
   menu(0) = "Remap to current Master Palette"
   menu(1) = "Import with new Master Palette"
   menu(2) = "Do not remap colours"
   paloption = multichoice("This BMP's palette is not identical to your master palette", _
                           menu(), , , "importbmp_palette")
   IF paloption = -1 THEN RETURN NULL
   IF paloption = 1 THEN
    importmasterpal srcbmp, gen(genMaxMasterPal) + 1
    activepalette = gen(genMaxMasterPal)
    setpal master()
    LoadUIColors uilook(), boxlook(), activepalette
   END IF
  END IF
  img = frame_import_bmp_raw(srcbmp)
  IF paloption = 0 THEN
   'Put hint values in palmapping(), which will used if an exact match
   FOR idx as integer = 0 TO 255
    palmapping(idx) = idx
   NEXT
   ' Disallow anything other than colour 0 from being mapped to colour 0 to prevent accidental transparency,
   ' and force 0 to be mapped to 0.
   convertbmppal srcbmp, pmask(), palmapping(), 1  'firstindex = 1
   palmapping(0) = 0
   FOR y as integer = 0 TO img->h - 1
    FOR x as integer = 0 TO img->w - 1
     putpixel img, x, y, palmapping(readpixel(img, x, y))
    NEXT
   NEXT
  END IF
 ELSE
  'Since the source image is not paletted, we don't know what the background colour
  'is (if any: not all backdrops and tilesets are transparent). Import it, disallowing anything to
  'be remapped to colour 0 (unfortunately colour 0 is the only pure black in the default palette),
  'then let the user pick.
  img = frame_import_bmp24_or_32(srcbmp, pmask(), 1)
  importbmp_change_background_color img
 END IF
 loadpalette pmask(), activepalette
 RETURN img
END FUNCTION

'Import a BMP file as a MXS backdrop/tileset. Returns true if imported, false if cancelled
FUNCTION importbmp_import(mxslump as string, imagenum as integer, srcbmp as string, pmask() as RGBcolor) as bool
 DIM img as Frame ptr = importbmp_processbmp(srcbmp, pmask())
 IF img = NULL THEN RETURN NO
 storemxs mxslump, imagenum, img
 frame_unload @img
 RETURN YES
END FUNCTION

'Draw a Frame (specially a tileset) onto another Frame with the transparent
'colour replaced either with another colour, or with a chequer pattern.
'bgcolor is either between 0 and 255 (a colour), bgChequerScroll (a scrolling chequered
'background), or bgChequer (a non-scrolling chequered background)
'chequer_scroll is a counter variable which the calling function should increment once per tick.
SUB frame_draw_with_background (src as Frame ptr, pal as Palette16 ptr = NULL, x as integer, y as integer, scale as integer = 1, bgcolor as bgType, byref chequer_scroll as integer, dest as Frame ptr)
 draw_background dest, bgcolor, chequer_scroll, x, y, src->w * scale, src->h * scale
 'Draw transparently
 frame_draw src, pal, x, y, scale, YES, dest
END SUB

' Describe a bgType value (usually append to "Background: ")
FUNCTION bgcolor_caption(bgcolor as bgType) as string
 IF bgcolor = bgChequer THEN
  RETURN "chequer"
 ELSEIF bgcolor = bgChequerScroll THEN
  RETURN "scrolling chequer"
 ELSE
  RETURN "color " & bgcolor
 END IF
END FUNCTION

SUB maptile ()
STATIC bgcolor as bgType = 0  'Default to first color in master palette
DIM menu() as string
DIM mapfile as string = game & ".til"
DIM tilesetnum as integer
DIM top as integer = -1
DIM chequer_scroll as integer

DIM state as MenuState
state.top = -1
state.pt = -1
state.first = -1
state.last = gen(genMaxTile)
state.autosize = YES
state.autosize_ignore_pixels = 4
state.need_update = YES

'The tileset editor stores the tileset on page 3 and undo on page 2, so lock them to 320x200
lock_page_size 2, 320, 200
lock_page_size 3, 320, 200

clearpage 3
setkeys
DO
 chequer_scroll += 1
 setwait 55
 setkeys
 IF keyval(scESC) > 1 THEN EXIT DO
 IF keyval(scF1) > 1 THEN show_help "maptile_pickset"
 IF keyval(scCtrl) > 0 AND keyval(scBackspace) > 1 AND state.pt > -1 THEN
  cropafter state.pt, gen(genMaxTile), 3, game + ".til", 64000
  state.last = gen(genMaxTile)
  state.need_update = YES
 END IF
 DIM tempnum as integer = large(state.pt, 0)
 IF intgrabber(tempnum, 0, gen(genMaxTile), , , YES) THEN
  state.pt = tempnum
  state.need_update = YES
 END IF
 IF keyval(scDown) > 1 AND state.pt = gen(genMaxTile) AND gen(genMaxTile) < 32767 THEN
  state.pt += 1
  IF needaddset(state.pt, gen(genMaxTile), "tile set") THEN
   clearpage 3
   storemxs mapfile, state.pt, vpages(3)  'lazy
   state.last = gen(genMaxTile)
   state.need_update = YES
  END IF
 ELSEIF usemenu(state) THEN
  state.need_update = YES
 END IF
 IF enter_space_click(state) AND state.pt = -1 THEN EXIT DO
 IF enter_space_click(state) AND state.pt > -1 THEN
  tilesetnum = state.pt
  tile_edit_mode_picker tilesetnum, mapfile, bgcolor
  state.need_update = YES
 END IF

 IF state.need_update THEN
  state.need_update = NO
  REDIM menu(-1 TO gen(genMaxTile))
  menu(-1) = "Return to Main Menu"
  FOR i as integer = 0 TO gen(genMaxTile)
   menu(i) = "Tile Set " & i
  NEXT
  IF state.pt = -1 THEN clearpage 3 ELSE loadmxs mapfile, state.pt, vpages(3)
 END IF

 clearpage dpage
 frame_draw_with_background vpages(3), , 0, 0, , bgcolor, chequer_scroll, vpages(dpage)
 DIM menuopts as MenuOptions
 menuopts.edged = YES
 standardmenu menu(), state, 10, 4, dpage, menuopts
 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP
clearpage 3
clearpage 2
clearpage 1
clearpage 0
'Robust againts tileset leaks
sprite_update_cache sprTypeTileset

unlock_page_size 2
unlock_page_size 3

END SUB
 
SUB tile_edit_mode_picker(byval tilesetnum as integer, mapfile as string, byref bgcolor as bgType)
 DIM chequer_scroll as integer
 DIM menu(6) as string
 menu(0) = "Draw Tiles"
 menu(1) = "Cut Tiles from Tilesets"
 menu(2) = "Cut Tiles from Backdrops"
 menu(3) = "Set Default Passability"
 menu(4) = "Define Tile Animation"
 menu(6) = "Cancel"

 DIM state as MenuState
 init_menu_state state, menu()
 state.need_update = YES
 
 DIM menuopt as menuOptions
 menuopt.edged = YES
 
 setkeys
 DO
  chequer_scroll += 1
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "maptile_tilemode"
  usemenu state
  IF enter_space_click(state) THEN
   SELECT CASE state.pt
    CASE 0, 1, 2, 3
     picktiletoedit state.pt, tilesetnum, mapfile, bgcolor
    CASE 4
     tile_animation tilesetnum
    CASE 5
     bgcolor = color_browser_256(large(bgcolor, 0))
    CASE 6
     EXIT DO
   END SELECT
  END IF
  IF state.pt = 5 THEN intgrabber(bgcolor, bgFIRST, 255)
  clearpage dpage
  frame_draw_with_background vpages(3), , 0, 0, , bgcolor, chequer_scroll, vpages(dpage)
  menu(5) = "Background: " & bgcolor_caption(bgcolor)
  standardmenu menu(), state, 10, 8, dpage, menuopt
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

END SUB

SUB tile_animation(byval tilesetnum as integer)
 DIM tastuf(40) as integer
 DIM taset as integer = 0
 load_tile_anims tilesetnum, tastuf()

 DIM menu(5) as string 
 menu(0) = "Previous Menu"
 menu(2) = "Set Animation Range"
 menu(3) = "Set Animation Pattern"
 menu(5) = "Test Animations"
 
 DIM state as MenuState
 init_menu_state state, menu()
 state.need_update = YES
 
 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "maptile_tileanim"
  IF usemenu(state) THEN state.need_update = YES
  IF state.pt = 4 THEN
   IF tag_grabber(tastuf(1 + 20 * taset)) THEN state.need_update = YES
  ELSE
   IF intgrabber(taset, 0, 1) THEN state.need_update = YES
  END IF
  IF enter_space_click(state) THEN
   SELECT CASE state.pt
    CASE 0: EXIT DO
    CASE 2: tile_anim_set_range tastuf(), taset, tilesetnum
    CASE 3: setanimpattern tastuf(), taset, tilesetnum
    CASE 5: testanimpattern tastuf(), taset
   END SELECT
  END IF
  IF state.need_update THEN
   menu(1) = CHR(27) & "Animation set " & taset & CHR(26)
   menu(4) = tag_condition_caption(tastuf(1 + 20 * taset), "Disable if Tag", "No tag check")
   state.need_update = YES
  END IF
  clearpage dpage
  standardmenu menu(), state, 0, 0, dpage
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 save_tile_anims tilesetnum, tastuf()
END SUB

SUB tile_anim_set_range(tastuf() as integer, byval taset as integer, byval tilesetnum as integer)
 DIM tog as integer
 DIM mouse as MouseInfo

 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
  IF keyval(scESC) > 1 OR enter_or_space() THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "maptile_setanimrange"
  IF keyval(scUp) > 1 THEN tastuf(0 + 20 * taset) = large(tastuf(0 + 20 * taset) - 16, 0)
  IF keyval(scDown) > 1 THEN tastuf(0 + 20 * taset) = small(tastuf(0 + 20 * taset) + 16, 112)
  IF keyval(scLeft) > 1 THEN tastuf(0 + 20 * taset) = large(tastuf(0 + 20 * taset) - 1, 0)
  IF keyval(scRight) > 1 THEN tastuf(0 + 20 * taset) = small(tastuf(0 + 20 * taset) + 1, 112)
  mouse = readmouse()
  WITH mouse
   IF .clickstick AND mouseleft THEN
    IF rect_collide_point(str_rect("ESC when done", 0, 0), .x, .y) THEN
     EXIT DO
    ELSE
     tastuf(0 + 20 * taset) = small(cint(int(.x / 20) + int(.y / 20) * 16), 112)
    END IF
   END IF
  END WITH
  copypage 3, dpage
  tile_anim_draw_range tastuf(), taset, dpage
  edgeprint "ESC when done", 0, 0, uilook(uiText), dpage
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 save_tile_anims tilesetnum, tastuf()
END SUB

SUB tile_anim_draw_range(tastuf() as integer, byval taset as integer, byval page as integer)
 DIM animpos as XYPair
 animpos.x = 0
 animpos.y = 0
 FOR i as integer = 0 TO 159
  IF i < tastuf(0 + 20 * taset) OR i > tastuf(0 + 20 * taset) + 47 THEN
   fuzzyrect animpos.x * 20, animpos.y * 20, 20, 20, uilook(uiText), page
  END IF
  animpos.x += 1
  IF animpos.x > 15 THEN
   animpos.x = 0
   animpos.y += 1
  END IF
 NEXT i
END SUB

FUNCTION mouseover (byval mousex as integer, byval mousey as integer, byref zox as integer, byref zoy as integer, byref zcsr as integer, area() as MouseArea) as integer
 FOR i as integer = UBOUND(area) TO 0 STEP -1
  IF area(i).w <> 0 AND area(i).h <> 0 THEN
   IF mousex >= area(i).x AND mousex < area(i).x + area(i).w THEN
    IF mousey >= area(i).y AND mousey < area(i).y + area(i).h THEN
     zox = mousex - area(i).x
     zoy = mousey - area(i).y
     zcsr = area(i).hidecursor
     mouseover = i + 1
     EXIT FUNCTION
    END IF 'Y OKAY---
   END IF 'X OKAY---
  END IF 'VALID ZONE---
 NEXT i
END FUNCTION

SUB setanimpattern (tastuf() as integer, taset as integer, tilesetnum as integer)
 DIM menu(10) as string
 DIM menu2(1) as string
 DIM llim(7) as integer
 DIM ulim(7) as integer
 menu(0) = "Previous Menu"
 FOR i as integer = 1 TO 2
  llim(i) = 0
  ulim(i) = 9
 NEXT i
 FOR i as integer = 3 TO 4
  llim(i) = 0
  ulim(i) = 159
 NEXT i
 llim(5) = 0
 ulim(5) = 32767
 llim(6) = -max_tag()
 ulim(6) = max_tag()

 DIM context as integer = 0
 DIM index as integer = 0
 DIM tog as integer

 DIM state as MenuState
 init_menu_state state, menu()
 state.need_update = YES

 DIM state2 as MenuState
 init_menu_state state2, menu2()

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scF1) > 1 THEN show_help "maptile_setanimpattern"
  SELECT CASE context
   CASE 0 '---PICK A STATEMENT---
    IF keyval(scESC) > 1 THEN EXIT DO
    IF usemenu(state) THEN state.need_update = YES
    IF enter_space_click(state) THEN
     IF state.pt = 0 THEN
      EXIT DO
     ELSE
      context = 1
     END IF
    END IF
   CASE 1 '---EDIT THAT STATEMENT---
    IF keyval(scESC) > 1 THEN
     save_tile_anims tilesetnum, tastuf()
     context = 0
    END IF
    usemenu state2
    index = bound(state.pt - 1, 0, 8) + 20 * taset
    IF state2.pt = 0 THEN
     IF intgrabber(tastuf(2 + index), 0, 6) THEN state.need_update = YES
    END IF
    IF state2.pt = 1 THEN
     IF tastuf(2 + index) = 6 THEN
      IF tag_grabber(tastuf(11 + index)) THEN state.need_update = YES
     ELSE
      IF intgrabber(tastuf(11 + index), llim(tastuf(2 + index)), ulim(tastuf(2 + index))) THEN state.need_update = YES
     END IF
    END IF
    IF enter_space_click(state2) THEN context = 0
  END SELECT
  IF state.need_update THEN
   setanimpattern_refreshmenu state.pt, menu(), menu2(), tastuf(), taset, llim(), ulim()
   state.need_update = NO
  END IF
  '--Draw screen
  clearpage dpage
  state.active = (context = 0)
  standardmenu menu(), state, 0, 0, dpage
  IF state.pt > 0 THEN
   state2.active = (context = 1)
   standardmenu menu2(), state2, 0, 100, dpage
  END IF
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 setanimpattern_forcebounds tastuf(), taset, llim(), ulim()
END SUB

SUB setanimpattern_refreshmenu(byval pt as integer, menu() as string, menu2() as string, tastuf() as integer, byval taset as integer, llim() as integer, ulim() as integer)
 DIM animop(7) as string
 animop(0) = "end of animation"
 animop(1) = "up"
 animop(2) = "down"
 animop(3) = "right"
 animop(4) = "left"
 animop(5) = "wait"
 animop(6) = "if tag do rest"
 animop(7) = "unknown command"

 setanimpattern_forcebounds tastuf(), taset, llim(), ulim()
 FOR i as integer = 1 TO 9
  menu(i) = "-"
 NEXT i
 menu(10) = ""
 DIM anim_a as integer
 DIM anim_b as integer
 DIM anim_i as integer
 FOR anim_i = 0 TO 8
  anim_a = bound(tastuf((2 + anim_i) + 20 * taset), 0, 7)
  anim_b = tastuf((11 + anim_i) + 20 * taset)
  menu(anim_i + 1) = animop(anim_a)
  IF anim_a = 0 THEN EXIT FOR
  IF anim_a > 0 AND anim_a < 6 THEN menu(anim_i + 1) = menu(anim_i + 1) & " " & anim_b
  IF anim_a = 6 THEN menu(anim_i + 1) = menu(anim_i + 1) & " (" & load_tag_name(anim_b) & ")"
 NEXT anim_i
 IF anim_i = 8 THEN menu(10) = "end of animation"

 menu2(0) = "Action=" + animop(bound(tastuf(2 + bound(pt - 1, 0, 8) + 20 * taset), 0, 7))
 menu2(1) = "Value="
 DIM ta_temp as integer
 ta_temp = tastuf(11 + bound(pt - 1, 0, 8) + 20 * taset)
 SELECT CASE tastuf(2 + bound(pt - 1, 0, 8) + 20 * taset)
  CASE 1 TO 4
   menu2(1) &= ta_temp & " Tiles"
  CASE 5
   menu2(1) &= ta_temp & " Ticks"
  CASE 6
   menu2(1) &= tag_condition_caption(ta_temp, , "Never")
  CASE ELSE
   menu2(1) &= "N/A"
 END SELECT
END SUB

SUB setanimpattern_forcebounds(tastuf() as integer, byval taset as integer, llim() as integer, ulim() as integer)
 DIM tmp as integer
 FOR i as integer = 0 TO 8
  tmp = bound(i, 0, 8) + 20 * taset
  tastuf(2 + tmp) = bound(tastuf(2 + tmp), 0, 7)
  tastuf(11 + tmp) = bound(tastuf(11 + tmp), llim(tastuf(2 + tmp)), ulim(tastuf(2 + tmp)))
 NEXT i
END SUB

SUB testanimpattern (tastuf() as integer, byref taset as integer)
 DIM sample as TileMap
 DIM tilesetview as TileMap
 DIM tanim_state(1) as TileAnimState
 DIM tileset as Frame ptr = NULL
 DIM tog as integer
 DIM csr as integer
 DIM x as integer
 DIM y as integer

 tileset = mxs_frame_to_tileset(vpages(3))

 cleantilemap tilesetview, 16, 3
 FOR y as integer = 0 TO 2
  FOR x as integer = 0 TO 15
   writeblock tilesetview, x, y, tastuf(20 * taset) + x + y * 16
  NEXT
 NEXT

 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1

  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "maptile_testanimpattern"
  IF keyval(scUp) > 1 THEN csr = loopvar(csr, 0, 47, -16)
  IF keyval(scDown) > 1 THEN csr = loopvar(csr, 0, 47, 16)
  IF keyval(scLeft) > 1 THEN csr = loopvar(csr, 0, 47, -1)
  IF keyval(scRight) > 1 THEN csr = loopvar(csr, 0, 47, 1)

  clearpage dpage
  '--draw available animating tiles--
  drawmap tilesetview, 0, 0, tileset, dpage, , , , 10, 60

  '--draw sample--
  setanim tastuf(0) + tanim_state(0).cycle, tastuf(20) + tanim_state(1).cycle
  cycletile tanim_state(), tastuf()

  cleantilemap sample, 3, 3
  FOR x = 0 TO 2
   FOR y = 0 TO 2
    writeblock sample, x, y, 160 + (taset * 48) + csr
   NEXT
  NEXT
  drawmap sample, -130, 0, tileset, dpage, , , , 100, 60

  '--Draw cursor--
  y = csr \ 16
  x = csr - y * 16
  drawbox 20 * x, 10 + 20 * y, 20, 20, uilook(uiSelectedItem + tog), 1, dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 frame_unload @tileset
 unloadtilemap sample
 unloadtilemap tilesetview
END SUB

SUB picktiletoedit (byref tmode as integer, byval tilesetnum as integer, mapfile as string, bgcolor as bgType)
STATIC cutnpaste(19, 19) as integer
STATIC oldpaste as integer
DIM ts as TileEditState
DIM area(24) as MouseArea
DIM mouse as MouseInfo
ts.tilesetnum = tilesetnum
ts.drawframe = frame_new(20, 20, , YES)
DIM chequer_scroll as integer
DIM tog as integer
ts.gotmouse = havemouse()
hidemousecursor
ts.canpaste = oldpaste
ts.drawcursor = 1
ts.airsize = 5
ts.mist = 4
area(0).x = 80   'Tile at 8x zoom
area(0).y = 0
area(0).w = 160
area(0).h = 160
area(0).hidecursor = YES
area(1).x = 0
area(1).y = 160
area(1).w = 320
area(1).h = 32
'TOOLS (more at 21+)
FOR i as integer = 0 TO 5
 area(2 + i).x = 4 + i * 9
 area(2 + i).y = 32
 area(2 + i).w = 8
 area(2 + i).h = 8
NEXT i
FOR i as integer = 0 TO 3
 area(12 + i).x = 4 + i * 9
 area(12 + i).y = 42
 area(12 + i).w = 8
 area(12 + i).h = 8
NEXT i
'Areas 11 and 12 used only in tile cutter
'LESS AIRBRUSH AREA
area(16).x = 12
area(16).y = 60
area(16).w = 8
area(16).h = 8
area(16).hidecursor = NO
'LESS AIRBRUSH MIST
area(17).x = 12
area(17).y = 76
area(17).w = 8
area(17).h = 8
area(17).hidecursor = NO
'MORE AIRBRUSH AREA
area(18).x = 36
area(18).y = 60
area(18).w = 8
area(18).h = 8
area(18).hidecursor = NO
'MORE AIRBRUSH MIST
area(19).x = 36
area(19).y = 76
area(19).w = 8
area(19).h = 8
area(19).hidecursor = NO
FOR i as integer = 0 TO 1  'mark and clone
 area(21 + i).x = 49 + i * 9
 area(21 + i).y = 42
 area(21 + i).w = 8
 area(21 + i).h = 8
NEXT i
area(23).x = 58  'airbrush
area(23).y = 32
area(23).w = 8
area(23).h = 8
area(24).x = 40  'scroll tool
area(24).y = 42
area(24).w = 8
area(24).h = 8

DIM pastogkey(7) as integer
DIM bitmenu(10) as string
IF tmode = 3 THEN
 pastogkey(0) = scUp
 pastogkey(1) = scRight
 pastogkey(2) = scDown
 pastogkey(3) = scLeft
 pastogkey(4) = scA
 pastogkey(5) = scB
 pastogkey(6) = scH
 pastogkey(7) = scO
 loadpasdefaults ts.defaultwalls, tilesetnum
 bitmenu(0) = "Impassable to the North"
 bitmenu(1) = "Impassable to the East"
 bitmenu(2) = "Impassable to the South"
 bitmenu(3) = "Impassable to the West"
 bitmenu(4) = "A-type vehicle Tile"
 bitmenu(5) = "B-type vehicle Tile"
 bitmenu(6) = "Harm Tile"
 bitmenu(7) = "Overhead Tile (OBSOLETE!)"
END IF    

loadmxs mapfile, tilesetnum, vpages(3)
'pick block to draw/import/default
DIM bnum as integer = 0
setkeys
DO
 setwait 17, 70
 setkeys
 IF ts.gotmouse THEN
  mouse = readmouse
 END IF
 IF keyval(scESC) > 1 THEN EXIT DO
 IF keyval(scF1) > 1 THEN
  IF tmode = 3 THEN
   show_help "default_passability"
  ELSE
   show_help "picktiletoedit"
  END IF
 END IF
 IF ts.gotmouse THEN
  IF mouse.x < 320 AND mouse.y < 200 THEN
   bnum = (mouse.y \ 20) * 16 + mouse.x \ 20
  END IF
 END IF
 IF tmode <> 3 OR keyval(scCtrl) = 0 THEN
  DIM movedcsr as integer = NO
  IF slowkey(scLeft, 100) THEN bnum = (bnum + 159) MOD 160: movedcsr = YES
  IF slowkey(scRight, 100) THEN bnum = (bnum + 1) MOD 160: movedcsr = YES
  IF slowkey(scUp, 100) THEN bnum = (bnum + 144) MOD 160: movedcsr = YES
  IF slowkey(scDown, 100) THEN bnum = (bnum + 16) MOD 160: movedcsr = YES
  IF movedcsr AND ts.gotmouse THEN
   mouse.x = (mouse.x MOD 20) + (bnum MOD 16) * 20
   mouse.y = (mouse.y MOD 20) + (bnum \ 16) * 20
   movemouse mouse.x, mouse.y
  END IF
 END IF
 IF tmode = 3 THEN
  '--pass mode shortcuts
  FOR i as integer = 0 TO 7
   IF keyval(scCtrl) > 0 OR i > 3 THEN
    IF keyval(pastogkey(i)) > 1 THEN
     ts.defaultwalls[bnum] XOR= 1 SHL i
    END IF
   END IF
  NEXT i
 END IF
 IF copy_keychord() THEN tilecopy cutnpaste(), ts
 IF paste_keychord() THEN tilepaste cutnpaste(), ts
 IF (keyval(scCtrl) > 0 AND keyval(scT) > 1) THEN tiletranspaste cutnpaste(), ts
 ts.tilex = bnum AND 15
 ts.tiley = bnum \ 16
 IF enter_or_space() OR mouse.clicks > 0 THEN
  setkeys
  IF tmode = 0 THEN
   editmaptile ts, mouse, area(), bgcolor
  END IF
  IF tmode = 1 THEN
   ts.cuttileset = YES
   ts.cutfrom = small(ts.cutfrom, gen(genMaxTile))
   tilecut ts, mouse
  END IF 
  IF tmode = 2 THEN
   ts.cuttileset = NO
   ts.cutfrom = small(ts.cutfrom, gen(genNumBackdrops) - 1)
   tilecut ts, mouse
  END IF 
  IF tmode = 3 THEN
   DIM buf() as integer
   vector_to_array buf(), ts.defaultwalls
   editbitset buf(), bnum, 7, bitmenu()
   array_to_vector ts.defaultwalls, buf()
  END IF
  IF slave_channel <> NULL_CHANNEL THEN storemxs mapfile, tilesetnum, vpages(3)
 END IF

 clearpage dpage
 frame_draw_with_background vpages(3), , 0, 0, , bgcolor, chequer_scroll, vpages(dpage)
 IF tmode = 1 OR tmode = 2 THEN
  'Show tile number
  edgeprint "Tile to overwrite: " & bnum, 0, IIF(bnum < 112, pBottom, 0), uilook(uiText), dpage
 END IF
 IF tmode = 3 THEN
  FOR o as integer = 0 TO 9
   FOR i as integer = 0 TO 15
    IF (ts.defaultwalls[i + o * 16] AND 1) THEN rectangle i * 20, o * 20, 20, 3, uilook(uiMenuItem + tog), dpage
    IF (ts.defaultwalls[i + o * 16] AND 2) THEN rectangle i * 20 + 17, o * 20, 3, 20, uilook(uiMenuItem + tog), dpage
    IF (ts.defaultwalls[i + o * 16] AND 4) THEN rectangle i * 20, o * 20 + 17, 20, 3, uilook(uiMenuItem + tog), dpage
    IF (ts.defaultwalls[i + o * 16] AND 8) THEN rectangle i * 20, o * 20, 3, 20, uilook(uiMenuItem + tog), dpage
    textcolor uilook(uiSelectedItem + tog), 0
    IF (ts.defaultwalls[i + o * 16] AND 16) THEN printstr "A", i * 20, o * 20, dpage
    IF (ts.defaultwalls[i + o * 16] AND 32) THEN printstr "B", i * 20 + 10, o * 20, dpage
    IF (ts.defaultwalls[i + o * 16] AND 64) THEN printstr "H", i * 20, o * 20 + 10, dpage
    IF (ts.defaultwalls[i + o * 16] AND 128) THEN printstr "O", i * 20 + 10, o * 20 + 10, dpage
   NEXT i
  NEXT o
 END IF
 rectangle ts.tilex * 20 + 7, ts.tiley * 20 + 7, 6, 6, IIF(tog, uilook(uiBackground), uilook(uiText)), dpage
 IF ts.gotmouse THEN
  textcolor uilook(IIF(tog, uiText, uiDescription)), 0
  printstr CHR(2), mouse.x - 2, mouse.y - 2, dpage
 END IF
 SWAP dpage, vpage
 setvispage vpage
 IF dowait THEN
  tog = tog XOR 1
  chequer_scroll += 1
 END IF
LOOP
storemxs mapfile, tilesetnum, vpages(3)
IF tmode = 3 THEN
 savepasdefaults ts.defaultwalls, tilesetnum
END IF
v_free ts.defaultwalls
oldpaste = ts.canpaste
frame_unload @ts.drawframe
defaultmousecursor
END SUB

SUB refreshtileedit (state as TileEditState)
 copymapblock state.tilex * 20, state.tiley * 20, 3, 280, 10 + (state.undo * 21), 2
 frame_draw vpages(3), NULL, -state.tilex * 20, -state.tiley * 20, , NO, state.drawframe  'Blit the tile onto state.drawframe
END SUB

SUB writeundoblock (state as TileEditState)
 state.undo = loopvar(state.undo, 0, 5, 1)
 copymapblock state.tilex * 20, state.tiley * 20, 3, 280, 10 + (state.undo * 21), 2
 textcolor uilook(uiMenuItem), 0
 printstr ">", 270, 16 + (state.undo * 21), 2
 state.allowundo = 1
END SUB

SUB readundoblock (state as TileEditState)
 FOR j as integer = 0 TO 5
  'Blank out the arrow pointing at the current undo step
  rectangle 270, 16 + (j * 21), 8, 8, uilook(uiBackground), 2
 NEXT j
 copymapblock 280, 10 + (state.undo * 21), 2, state.tilex * 20, state.tiley * 20, 3
 textcolor uilook(uiMenuItem), 0
 printstr ">", 270, 16 + (state.undo * 21), 2
 refreshtileedit state
END SUB

SUB editmaptile (ts as TileEditState, mouse as MouseInfo, area() as MouseArea, bgcolor as bgType)
STATIC clone as TileCloneBuffer
DIM spot as XYPair

DIM toolinfo(SPRITEEDITOR_NUM_TOOLS - 1) as ToolInfoType
WITH toolinfo(0)
 .name = "Draw"
 .icon = CHR(3)
 .shortcut = scD
 .cursor = 0
 .areanum = 2
END WITH
WITH toolinfo(1)
 .name = "Box"
 .icon = CHR(4)
 .shortcut = scB
 .cursor = 1
 .areanum = 3
END WITH
WITH toolinfo(2)
 .name = "Line"
 .icon = CHR(5)
 .shortcut = scL
 .cursor = 2
 .areanum = 4
END WITH
WITH toolinfo(3)
 .name = "Fill"
 .icon = "F"
 .shortcut = scF
 .cursor = 3
 .areanum = 5
END WITH
WITH toolinfo(4)
 .name = "Oval"
 .icon = "O"
 .shortcut = scO
 .cursor = 2
 .areanum = 7
END WITH
WITH toolinfo(5)
 .name = "Air"
 .icon = "A"
 .shortcut = scA
 .cursor = 3
 .areanum = 23
END WITH
WITH toolinfo(6)
 .name = "Mark"
 .icon = "M"
 .shortcut = scM
 .cursor = 3
 .areanum = 21
END WITH
WITH toolinfo(7)
 .name = "Clone"
 .icon = "C"
 .shortcut = scC
 .cursor = 3
 .areanum = 22
END WITH
WITH toolinfo(8)
 .name = "Replace"
 .icon = "R"
 .shortcut = scR
 .cursor = 3
 .areanum = 6
END WITH
WITH toolinfo(9)
 .name = "Scroll"
 .icon = "S"
 .shortcut = scS
 .cursor = 2
 .areanum = 24
END WITH

DIM overlay as Frame ptr
overlay = frame_new(20, 20, , YES)
DIM overlaypal as Palette16 ptr
overlaypal = palette16_new()

DIM chequer_scroll as integer = 0
DIM tog as integer = 0
DIM tick as integer = 0
ts.lastcpos = TYPE(ts.x, ts.y)
ts.justpainted = 0
ts.didscroll = NO
ts.undo = 0
ts.allowundo = 0
ts.delay = 10
DIM zox as integer = ts.x * 8 + 4
DIM zoy as integer = ts.y * 8 + 4
DIM zcsr as integer
DIM overlay_use_palette as integer
DIM fgcol as integer
DIM bgcol as integer
mouse.x = area(0).x + zox
mouse.y = area(0).y + zoy
movemouse mouse.x, mouse.y
clearpage 2
'--Undo boxes
FOR i as integer = 0 TO 5
 edgebox 279, 9 + (i * 21), 22, 22, uilook(uiBackground), uilook(uiMenuItem), 2
NEXT i
refreshtileedit ts
textcolor uilook(uiMenuItem), 0
printstr ">", 270, 16 + (ts.undo * 21), 2
'--Draw master palette
FOR j as integer = 0 TO 7
 FOR i as integer = 0 TO 15
  rectangle i * 10, j * 4 + 160, 10, 4, j * 16 + i, 2
  rectangle i * 10 + 160, j * 4 + 160, 10, 4, j * 16 + i + 128, 2
 NEXT i
NEXT j
'--frame around the drawing area
rectangle 79, 0, 162, 160, uilook(uiText), 2
'---EDIT BLOCK---
setkeys
DO
 setwait 17, 110
 setkeys
 IF ts.gotmouse THEN
  mouse = readmouse
  zcsr = 0
  ts.zone = mouseover(mouse.x, mouse.y, zox, zoy, zcsr, area())
 END IF

 ts.delay = large(ts.delay - 1, 0)
 ts.justpainted = large(ts.justpainted - 1, 0)
 IF keyval(scEsc) > 1 THEN
  IF ts.hold = YES THEN
   ts.hold = NO
  ELSE
   EXIT DO
  END IF
 END IF
 IF keyval(scF1) > 1 THEN show_help "editmaptile"
 IF keyval(scAlt) = 0 THEN
  DIM fixmouse as integer = NO
  IF ts.tool <> scroll_tool THEN
   IF slowkey(scLeft, 100) THEN ts.x = large(ts.x - 1, 0): fixmouse = YES
   IF slowkey(scRight, 100) THEN ts.x = small(ts.x + 1, 19): fixmouse = YES
   IF slowkey(scUp, 100) THEN ts.y = large(ts.y - 1, 0): fixmouse = YES
   IF slowkey(scDown, 100) THEN ts.y = small(ts.y + 1, 19): fixmouse = YES
  ELSE
   DIM scrolloff as XYPair
   IF slowkey(scLeft, 100) THEN scrolloff.x = -1
   IF slowkey(scRight, 100) THEN scrolloff.x = 1
   IF slowkey(scUp, 100) THEN scrolloff.y = -1
   IF slowkey(scDown, 100) THEN scrolloff.y = 1
   scrolltile ts, scrolloff.x, scrolloff.y
   IF scrolloff.x OR scrolloff.y THEN fixmouse = YES
   ts.x = (ts.x + scrolloff.x + 20) MOD 20
   ts.y = (ts.y + scrolloff.y + 20) MOD 20
  END IF
  IF fixmouse AND ts.zone = 1 THEN
   zox = ts.x * 8 + 4
   zoy = ts.y * 8 + 4
   mouse.x = area(0).x + zox
   mouse.y = area(0).y + zoy
   movemouse mouse.x, mouse.y
  END IF
 END IF 
 IF keyval(scCtrl) > 0 AND keyval(scS) > 1 THEN
  storemxs game + ".til", ts.tilesetnum, vpages(3)
 END IF
 '---KEYBOARD SHORTCUTS FOR TOOLS------------
 IF keyval(scCtrl) = 0 THEN
  FOR i as integer = 0 TO UBOUND(toolinfo)
   IF keyval(toolinfo(i).shortcut) > 1 THEN
    tileedit_set_tool ts, toolinfo(), i
   END IF
  NEXT i
 END IF
 '----------
 IF keyval(scComma) > 1 OR (keyval(scAlt) > 0 AND keyval(scLeft) > 1) THEN
  ts.curcolor = (ts.curcolor + 255) MOD 256
  IF ts.curcolor MOD 16 = 15 THEN ts.curcolor = (ts.curcolor + 144) MOD 256
 END IF
 IF keyval(scPeriod) > 1 OR (keyval(scAlt) > 0 AND keyval(scRight) > 1) THEN
  ts.curcolor += 1
  IF ts.curcolor MOD 16 = 0 THEN ts.curcolor = (ts.curcolor + 112) MOD 256
 END IF
 IF keyval(scAlt) > 0 AND keyval(scUp) > 1 THEN ts.curcolor = (ts.curcolor + 240) MOD 256
 IF keyval(scAlt) > 0 AND keyval(scDown) > 1 THEN ts.curcolor = (ts.curcolor + 16) MOD 256
 IF keyval(scTilde) > 1 THEN ts.hidemouse = ts.hidemouse XOR YES
 IF keyval(scCtrl) > 0 AND keyval(scZ) > 1 AND ts.allowundo THEN
  ts.undo = loopvar(ts.undo, 0, 5, -1)
  readundoblock ts
  ts.didscroll = NO  'save a new undo block upon scrolling
 END IF
 IF keyval(scSpace) > 0 THEN clicktile ts, keyval(scSpace) AND 4, clone
 IF keyval(scEnter) > 1 ORELSE keyval(scG) > 1 THEN ts.curcolor = readpixel(ts.tilex * 20 + ts.x, ts.tiley * 20 + ts.y, 3)
 SELECT CASE ts.zone
 CASE 1
  'Drawing area
  ts.x = zox \ 8
  ts.y = zoy \ 8
  IF ts.tool = clone_tool THEN
   ' For clone brush tool, enter/right-click moves the handle point
   IF ts.readjust THEN
    IF keyval(scEnter) = 0 AND mouse.buttons = 0 THEN ' click or key release
     ts.readjust = NO
     clone.offset.x += (ts.x - ts.adjustpos.x)
     clone.offset.y += (ts.y - ts.adjustpos.y)
     ts.adjustpos.x = 0
     ts.adjustpos.y = 0
    END IF
   ELSE
    IF (keyval(scEnter) AND 5) ORELSE (mouse.buttons AND mouseRight) THEN
     ts.readjust = YES
     ts.adjustpos.x = ts.x
     ts.adjustpos.y = ts.y
    END IF
   END IF
  ELSEIF ts.tool = scroll_tool THEN
   'Handle scrolling by dragging the mouse
   'Did this drag start inside the sprite box? If not, ignore
   IF mouse.dragging ANDALSO mouseover(mouse.clickstart.x, mouse.clickstart.y, 0, 0, 0, area()) = 1 THEN
    scrolltile ts, ts.x - ts.lastcpos.x, ts.y - ts.lastcpos.y
   END IF
  ELSE
   'for all other tools, pick a color
   IF mouse.buttons AND mouseRight THEN
    ts.curcolor = readpixel(ts.tilex * 20 + ts.x, ts.tiley * 20 + ts.y, 3)
   END IF
  END IF
  IF mouse.buttons AND mouseLeft THEN clicktile ts, (mouse.clicks AND mouseLeft), clone
 CASE 2
  'Colour selector
  IF mouse.clicks AND mouseLeft THEN
   ts.curcolor = ((zoy \ 4) * 16) + ((zox MOD 160) \ 10) + (zox \ 160) * 128
  END IF
 CASE 13 TO 16
  IF mouse.clicks AND mouseLeft THEN fliptile ts
 END SELECT
 FOR i as integer = 0 TO UBOUND(toolinfo)
  IF toolinfo(i).areanum = ts.zone - 1 THEN
   IF mouse.clicks AND mouseLeft THEN
    tileedit_set_tool ts, toolinfo(), i
   END IF
  END IF
 NEXT i
 '--mouse over undo
 IF mouse.x >= 280 AND mouse.x < 300 THEN
  FOR i as integer = 0 TO 5
   IF mouse.y >= (10 + (i * 21)) AND mouse.y < (30 + (i * 21)) THEN
    IF (mouse.clicks AND mouseLeft) ANDALSO ts.allowundo THEN
     ts.undo = i
     readundoblock ts
    END IF
   END IF
  NEXT i
 END IF
 IF ts.tool = airbrush_tool THEN '--adjust airbrush
  IF mouse.buttons AND mouseLeft THEN
   IF ts.zone = 17 THEN ts.airsize = large(ts.airsize - tick, 1)
   IF ts.zone = 19 THEN ts.airsize = small(ts.airsize + tick, 30)
   IF ts.zone = 18 THEN ts.mist = large(ts.mist - tick, 1)
   IF ts.zone = 20 THEN ts.mist = small(ts.mist + tick, 99)
  END IF
  IF keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1 THEN
   IF keyval(scCtrl) > 0 THEN
    ts.mist = large(ts.mist - 1, 1)
   ELSE
    ts.airsize = large(ts.airsize - 1, 1)
   END IF
  END IF
  IF keyval(scPlus) > 1 OR keyval(scNumpadPlus) > 1 THEN
   IF keyval(scCtrl) > 0 THEN
    ts.mist = small(ts.mist + 1, 99)
   ELSE
    ts.airsize = small(ts.airsize + 1, 80)
   END IF
  END IF
 END IF
 IF keyval(scBackspace) > 1 OR keyval(scLeftBracket) > 1 OR keyval(scRightBracket) > 1 THEN fliptile ts
 DIM cy as integer = (ts.curcolor \ 16) MOD 8
 DIM cx as integer = (ts.curcolor AND 15) + (ts.curcolor \ 128) * 16
 ts.lastcpos = XY(ts.x, ts.y)

 '--Draw screen (Some of the editor is predrawn to page 2)
 clearpage dpage
 copypage 2, dpage
 frame_draw_with_background ts.drawframe, NULL, 80, 0, 8, bgcolor, chequer_scroll, vpages(dpage)  'Draw the tile, at 8x zoom with background
 frame_clear overlay
 overlay_use_palette = YES  'OK, this is a bit of a hack
 overlaypal->col(1) = ts.curcolor

 rectangle cx * 10 + 4, cy * 4 + 162, 3, 1, IIF(tog, uilook(uiBackground), uilook(uiText)), dpage  'Selected colour marker
 'rectangle 60 + ts.x * 10, ts.y * 8, 10, 8, readpixel(ts.tilex * 20 + ts.x, ts.tiley * 20 + ts.y, 3), dpage  '??? Looks redundant
 'rectangle ts.x * 10 + 64, ts.y * 8 + 3, 3, 2, IIF(tog, uilook(uiBackground), uilook(uiText)), dpage  'Selecter pixel marker
 rectangle ts.x * 8 + 83, ts.y * 8 + 3, 3, 2, IIF(tog, uilook(uiBackground), uilook(uiText)), dpage  'Selected pixel marker
 IF ts.tool = airbrush_tool THEN
  IF tog THEN
   ellipse overlay, ts.x, ts.y, ts.airsize / 2 - 0.5, 1
   'paintat overlay, ts.x, ts.y, 1
  END IF
 END IF
 IF ts.tool = clone_tool AND tog = 0 THEN
  IF clone.exists = YES THEN
   overlay_use_palette = NO  'Don't use the palette, so colour 0 is drawn transparently
   FOR i as integer = 0 TO clone.size.y - 1
    FOR j as integer = 0 TO clone.size.x - 1
     spot.x = ts.x - clone.offset.x + j
     spot.y = ts.y - clone.offset.y + i
     IF ts.readjust = YES THEN
      spot.x -= (ts.x - ts.adjustpos.x)
      spot.y -= (ts.y - ts.adjustpos.y)
     END IF
     putpixel overlay, spot.x, spot.y, clone.buf(j, i)
    NEXT j
   NEXT i
  END IF
 END IF
 IF ts.hold = YES THEN
  DIM select_rect as RectType
  corners_to_rect_inclusive Type(ts.x, ts.y), ts.holdpos, select_rect
  SELECT CASE ts.tool
   CASE box_tool
    rectangle overlay, select_rect.x, select_rect.y, select_rect.wide, select_rect.high, 1
   CASE line_tool
    drawline overlay, ts.x, ts.y, ts.holdpos.x, ts.holdpos.y, 1
   CASE oval_tool
    ts.radius = SQR((ts.holdpos.x - ts.x)^2 + (ts.holdpos.y - ts.y)^2)
    IF ts.zone = 1 THEN
     'Use mouse pointer instead of draw cursor for finer grain control of radius
     ts.radius = SQR( (ts.holdpos.x - (mouse.x - area(0).x - 4) / 8)^2 + (ts.holdpos.y - (mouse.y - area(0).y - 4) / 8)^2 )
    END IF
    ellipse overlay, ts.holdpos.x, ts.holdpos.y, ts.radius, 1
   CASE mark_tool
    IF tog = 0 THEN drawbox overlay, select_rect.x, select_rect.y, select_rect.wide, select_rect.high, 15, 1
    overlaypal->col(15) = randint(10)
  END SELECT
 END IF
 frame_draw overlay, iif(overlay_use_palette, overlaypal, NULL), 80, 0, 8, YES, dpage  'Draw tool overlay, at 8x zoom

 textcolor uilook(uiText), uilook(uiHighlight)
 printstr toolinfo(ts.tool).name, 8, 8, dpage
 printstr "Tool", 8, 16, dpage
 printstr "Undo", 274, 1, dpage
 FOR i as integer = 0 TO UBOUND(toolinfo)
  fgcol = uilook(uiMenuItem)
  bgcol = uilook(uiDisabledItem)
  IF ts.tool = i THEN fgcol = uilook(uiText): bgcol = uilook(uiMenuItem)
  IF ts.zone - 1 = toolinfo(i).areanum THEN bgcol = uilook(uiSelectedDisabled)
  textcolor fgcol, bgcol
  printstr toolinfo(i).icon, area(toolinfo(i).areanum).x, area(toolinfo(i).areanum).y, dpage
 NEXT i
 FOR i as integer = 0 TO 3
  textcolor uilook(uiMenuItem), uilook(uiDisabledItem): IF ts.zone = 13 + i THEN textcolor uilook(uiText), uilook(uiSelectedDisabled)
  printstr CHR(7 + i), 4 + i * 9, 42, dpage
 NEXT i
 IF ts.tool = airbrush_tool THEN
  textcolor uilook(uiMenuItem), 0
  printstr "SIZE", 12, 52, dpage
  printstr STR(ts.airsize), 20, 60, dpage
  printstr "MIST", 12, 68, dpage
  printstr STR(ts.mist), 20, 76, dpage
  textcolor uilook(uiMenuItem), uilook(uiDisabledItem): IF ts.zone = 17 THEN textcolor uilook(uiText), uilook(uiSelectedDisabled)
  printstr CHR(27), 12, 60, dpage
  textcolor uilook(uiMenuItem), uilook(uiDisabledItem): IF ts.zone = 18 THEN textcolor uilook(uiText), uilook(uiSelectedDisabled)
  printstr CHR(27), 12, 76, dpage
  textcolor uilook(uiMenuItem), uilook(uiDisabledItem): IF ts.zone = 19 THEN textcolor uilook(uiText), uilook(uiSelectedDisabled)
  printstr CHR(26), 36, 60, dpage
  textcolor uilook(uiMenuItem), uilook(uiDisabledItem): IF ts.zone = 20 THEN textcolor uilook(uiText), uilook(uiSelectedDisabled)
  printstr CHR(26), 36, 76, dpage
 END IF
 IF ts.gotmouse THEN
  DIM c as integer = zcsr
  IF c = -1 THEN
   c = ts.drawcursor
   IF ts.hidemouse THEN c = -2
  END IF
  textcolor uilook(IIF(tog, uiText, uiDescription)), 0
  printstr CHR(2 + c), mouse.x - 2, mouse.y - 2, dpage
 END IF
 SWAP dpage, vpage
 setvispage vpage
 tick = 0
 IF dowait THEN
  tick = 1
  tog = tog XOR 1
  chequer_scroll += 1
 END IF
LOOP
IF ts.gotmouse THEN
 movemouse ts.tilex * 20 + 10, ts.tiley * 20 + 10
END IF
frame_unload @overlay
palette16_unload @overlaypal
END SUB

SUB tileedit_set_tool (ts as TileEditState, toolinfo() as ToolInfoType, byval toolnum as integer)
 IF ts.tool <> toolnum AND toolnum = scroll_tool THEN ts.didscroll = NO
 ts.tool = toolnum
 ts.hold = NO
 ts.drawcursor = toolinfo(ts.tool).cursor + 1
END SUB

SUB clicktile (ts as TileEditState, byval newkeypress as integer, byref clone as TileCloneBuffer)
DIM spot as XYPair

IF ts.delay > 0 THEN EXIT SUB
SELECT CASE ts.tool
 CASE draw_tool
  IF ts.justpainted = 0 THEN writeundoblock ts
  ts.justpainted = 3
  putpixel 280 + ts.x, 10 + (ts.undo * 21) + ts.y, ts.curcolor, 2
  rectangle ts.tilex * 20 + ts.x, ts.tiley * 20 + ts.y, 1, 1, ts.curcolor, 3
  refreshtileedit ts
 CASE box_tool
  IF newkeypress THEN
   IF ts.hold = YES THEN
    writeundoblock ts
    DIM select_rect as RectType
    corners_to_rect_inclusive Type(ts.x, ts.y), ts.holdpos, select_rect
    rectangle ts.tilex * 20 + select_rect.x, ts.tiley * 20 + select_rect.y, select_rect.wide, select_rect.high, ts.curcolor, 3
    refreshtileedit ts
    ts.hold = NO
   ELSE
    ts.hold = YES
    ts.holdpos.x = ts.x
    ts.holdpos.y = ts.y
   END IF
  END IF
 CASE line_tool
  IF newkeypress THEN
   IF ts.hold = YES THEN
    writeundoblock ts
    drawline ts.tilex * 20 + ts.x, ts.tiley * 20 + ts.y, ts.tilex * 20 + ts.holdpos.x, ts.tiley * 20 + ts.holdpos.y, ts.curcolor, 3
    refreshtileedit ts
    ts.hold = NO
   ELSE
    ts.hold = YES
    ts.holdpos.x = ts.x
    ts.holdpos.y = ts.y
   END IF
  END IF
 CASE fill_tool
  IF newkeypress THEN
   writeundoblock ts
   rectangle 0, 0, 22, 22, ts.curcolor, dpage
   FOR i as integer = 0 TO 19
    FOR j as integer = 0 TO 19
     putpixel 1 + i, 1 + j, readpixel(ts.tilex * 20 + i, ts.tiley * 20 + j, 3), dpage
    NEXT j
   NEXT i
   paintat vpages(dpage), 1 + ts.x, 1 + ts.y, ts.curcolor
   FOR i as integer = 0 TO 19
    FOR j as integer = 0 TO 19
     putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, readpixel(1 + i, 1 + j, dpage), 3
    NEXT j
   NEXT i
   refreshtileedit ts
   rectangle 0, 0, 22, 22, uilook(uiBackground), dpage
  END IF
 CASE replace_tool
  IF newkeypress THEN
   writeundoblock ts
   replacecolor vpages(3), readpixel(ts.tilex * 20 + ts.x, ts.tiley * 20 + ts.y, 3), ts.curcolor, ts.tilex * 20, ts.tiley * 20, 20, 20
   refreshtileedit ts
  END IF
 CASE oval_tool
  IF newkeypress THEN
   IF ts.hold = YES THEN
    writeundoblock ts
    rectangle 0, 0, 22, 22, uilook(uiText), dpage
    FOR i as integer = 0 TO 19
     FOR j as integer = 0 TO 19
      putpixel 1 + i, 1 + j, readpixel(ts.tilex * 20 + i, ts.tiley * 20 + j, 3), dpage
     NEXT j
    NEXT i
    ellipse vpages(dpage), 1 + ts.holdpos.x, 1 + ts.holdpos.y, ts.radius, ts.curcolor
    FOR i as integer = 0 TO 19
     FOR j as integer = 0 TO 19
      putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, readpixel(1 + i, 1 + j, dpage), 3
     NEXT j
    NEXT i
    refreshtileedit ts
    rectangle 0, 0, 22, 22, uilook(uiBackground), dpage
    ts.hold = NO
   ELSE
    ts.hold = YES
    ts.holdpos.x = ts.x
    ts.holdpos.y = ts.y
   END IF
  END IF
 CASE airbrush_tool
  IF ts.justpainted = 0 THEN writeundoblock ts
  ts.justpainted = 3
  rectangle 19, 119, 22, 22, uilook(uiText), dpage
  FOR i as integer = 0 TO 19
   FOR j as integer = 0 TO 19
    putpixel 20 + i, 120 + j, readpixel(ts.tilex * 20 + i, ts.tiley * 20 + j, 3), dpage
   NEXT j
  NEXT i
  airbrush vpages(dpage), 20 + ts.x, 120 + ts.y, ts.airsize, ts.mist, ts.curcolor
  FOR i as integer = 0 TO 19
   FOR j as integer = 0 TO 19
    putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, readpixel(20 + i, 120 + j, dpage), 3
   NEXT j
  NEXT i
  refreshtileedit ts
 CASE mark_tool
  IF newkeypress THEN
   IF ts.hold = YES THEN
    DIM select_rect as RectType
    corners_to_rect_inclusive Type(ts.x, ts.y), ts.holdpos, select_rect
    clone.size.x = select_rect.wide
    clone.size.y = select_rect.high
    FOR i as integer = 0 TO clone.size.y - 1
     FOR j as integer = 0 TO clone.size.x - 1
      clone.buf(j, i) = readpixel(ts.tilex * 20 + select_rect.x + j, ts.tiley * 20 + select_rect.y + i, 3)
     NEXT j
    NEXT i
    clone.offset.x = clone.size.x \ 2
    clone.offset.y = clone.size.y \ 2
    ts.readjust = NO
    ts.adjustpos.x = 0
    ts.adjustpos.y = 0
    clone.exists = YES
    refreshtileedit ts
    ts.hold = NO
    ts.tool = clone_tool ' auto-select the clone tool after marking
   ELSE
    ts.hold = YES
    ts.holdpos.x = ts.x
    ts.holdpos.y = ts.y
   END IF
  END IF
 CASE clone_tool
  IF newkeypress THEN
   IF ts.justpainted = 0 THEN writeundoblock ts
   ts.justpainted = 3
   IF clone.exists = YES THEN
    FOR i as integer = 0 TO clone.size.y - 1
     FOR j as integer = 0 TO clone.size.x - 1
      spot.x = ts.x - clone.offset.x + j + ts.adjustpos.x
      spot.y = ts.y - clone.offset.y + i + ts.adjustpos.y
      IF spot.x >= 0 AND spot.x <= 19 AND spot.y >= 0 AND spot.y <= 19 AND clone.buf(j, i) > 0 THEN
       putpixel ts.tilex * 20 + spot.x, ts.tiley * 20 + spot.y, clone.buf(j, i), 3
      END IF
     NEXT j
    NEXT i
    refreshtileedit ts
   ELSE
    'if no clone buffer, switch to mark tool
    ts.tool = mark_tool
    ts.hold = YES
    ts.holdpos.x = ts.x
    ts.holdpos.y = ts.y
   END IF
  END IF
END SELECT
END SUB

SUB scrolltile (ts as TileEditState, byval shiftx as integer, byval shifty as integer)
 'Save an undo before the first of a consecutive scrolls
 IF shiftx = 0 AND shifty = 0 THEN EXIT SUB
 IF ts.didscroll = NO THEN writeundoblock ts
 ts.didscroll = YES

 rectangle 0, 0, 20, 20, uilook(uiBackground), dpage
 DIM tempx as integer
 DIM tempy as integer
 FOR i as integer = 0 TO 19
  FOR j as integer = 0 TO 19
   tempx = (i + shiftx + 20) MOD 20
   tempy = (j + shifty + 20) MOD 20
   putpixel tempx, tempy, readpixel(ts.tilex * 20 + i, ts.tiley * 20 + j, 3), dpage
  NEXT j
 NEXT i
 FOR i as integer = 0 TO 19
  FOR j as integer = 0 TO 19
   putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, readpixel(i, j, dpage), 3
  NEXT j
 NEXT i
 refreshtileedit ts
 rectangle 0, 0, 20, 20, uilook(uiBackground), dpage
END SUB

SUB fliptile (ts as TileEditState)
 writeundoblock ts
 rectangle 0, 0, 20, 20, uilook(uiBackground), dpage
 DIM flipx as integer = 0
 DIM flipy as integer = 0
 DIM tempx as integer
 DIM tempy as integer
 IF (ts.zone = 13 OR ts.zone = 16) OR keyval(scLeftBracket) > 1 OR (keyval(scBackspace) > 1 AND keyval(scCtrl) = 0) THEN flipx = 19
 IF ts.zone = 14 OR ts.zone = 15 OR keyval(scRightBracket) > 1 OR (keyval(scBackspace) > 1 AND keyval(scCtrl) > 0) THEN flipy = 19
 FOR i as integer = 0 TO 19
  FOR j as integer = 0 TO 19
   tempx = ABS(i - flipx)
   tempy = ABS(j - flipy)
   IF (ts.zone = 15 OR ts.zone = 16) OR (keyval(scLeftBrace) > 1 OR keyval(scRightBrace) > 1) THEN SWAP tempx, tempy
   putpixel tempx, tempy, readpixel(ts.tilex * 20 + i, ts.tiley * 20 + j, 3), dpage
  NEXT j
 NEXT i
 FOR i as integer = 0 TO 19
  FOR j as integer = 0 TO 19
   putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, readpixel(i, j, dpage), 3
  NEXT j
 NEXT i
 refreshtileedit ts
 rectangle 0, 0, 20, 20, uilook(uiBackground), dpage
END SUB

SUB tilecut (ts as TileEditState, mouse as MouseInfo)
DIM area(24) as MouseArea
'"Prev" button
area(10).x = 8
area(10).y = 200 - 10
area(10).w = 8 * 6
area(10).h = 10
'"Next" button
area(11).x = 320 - 10 - 8 * 6
area(11).y = 200 - 10
area(11).w = 8 * 6
area(11).h = 10

STATIC snap_to_grid as bool = NO

IF ts.gotmouse THEN
 movemouse ts.x, ts.y
END IF
ts.delay = 3
DIM previewticks as integer = 0
IF ts.cuttileset THEN
 loadmxs game + ".til", ts.cutfrom, vpages(2)
ELSE
 loadmxs game + ".mxs", ts.cutfrom, vpages(2)
END IF
DIM tog as integer
DIM zcsr as integer
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 'Alt as alias for people who remember the old interface
 IF keyval(scAlt) > 1 OR keyval(scG) > 1 THEN snap_to_grid XOR= YES
 ts.delay = large(ts.delay - 1, 0)
 IF ts.gotmouse THEN
  mouse = readmouse
  zcsr = 0
  ts.zone = mouseover(mouse.x, mouse.y, 0, 0, zcsr, area())
  IF mouse.moved THEN
   ts.x = small(mouse.x, 320 - 20)
   ts.y = small(mouse.y, 200 - 20)
  END IF
 END IF
 IF keyval(scESC) > 1 THEN
  EXIT DO
 END IF
 IF keyval(scF1) > 1 THEN show_help "tilecut"

 '' Move cursor by keyboard
 DIM inc as integer
 IF keyval(scLeftShift) OR keyval(scRightShift) OR snap_to_grid THEN inc = 20 ELSE inc = 1
 DIM as integer movex = 0, movey = 0
 IF keyval(scUp) AND 5 THEN movey = -inc
 IF keyval(scDown) AND 5 THEN movey = inc
 IF keyval(scLeft) AND 5 THEN movex = -inc
 IF keyval(scRight) AND 5 THEN movex = inc
 ts.x = bound(ts.x + movex, 0, 320 - 20)
 ts.y = bound(ts.y + movey, 0, 200 - 20)
 IF (movex <> 0 OR movey <> 0) AND ts.gotmouse THEN movemouse ts.x, ts.y

 IF snap_to_grid THEN
  ts.x -= ts.x MOD 20
  ts.y -= ts.y MOD 20
 END IF

 '' Cut tile
 IF enter_or_space() OR (mouse.clicks > 0 AND ts.zone = 0) THEN
  IF ts.delay = 0 THEN
   FOR i as integer = 0 TO 19
    FOR j as integer = 0 TO 19
     putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, readpixel(ts.x + i, ts.y + j, 2), 3
    NEXT j
   NEXT i
   IF keyval(scEnter) > 1 OR (mouse.clicks AND (mouseRight OR mouseMiddle)) THEN
    ts.tiley = (ts.tiley + (ts.tilex + 1) \ 16) MOD 10
    ts.tilex = (ts.tilex + 1) AND 15
    ts.x += 20
    IF ts.x > 300 THEN
     ts.x = 0
     ts.y += 20
     IF ts.y > 180 THEN ts.y = 0
    END IF
    IF ts.gotmouse THEN movemouse ts.x, ts.y
    previewticks = 12
   ELSE
    EXIT DO
   END IF
  END IF
 END IF

 '' Changing source tileset/backdrop
 DIM oldcut as integer = ts.cutfrom
 DIM maxset as integer
 IF ts.cuttileset THEN
  maxset = gen(genMaxTile)
 ELSE
  maxset = gen(genNumBackdrops) - 1
 END IF
 intgrabber ts.cutfrom, 0, maxset, scLeftCaret, scRightCaret
 IF ts.zone = 11 AND mouse.clicks > 0 THEN ts.cutfrom = loopvar(ts.cutfrom, 0, maxset, -1)
 IF ts.zone = 12 AND mouse.clicks > 0 THEN ts.cutfrom = loopvar(ts.cutfrom, 0, maxset, 1)
 IF oldcut <> ts.cutfrom THEN
  IF ts.cuttileset THEN
   loadmxs game + ".til", ts.cutfrom, vpages(2)
  ELSE
   loadmxs game + ".mxs", ts.cutfrom, vpages(2)
  END IF
 END IF

 '' Draw screen
 IF previewticks THEN
  'Show preview of destination tileset at top or bottom of screen
  DIM preview as Frame ptr
  DIM previewy as integer = bound(ts.tiley * 20 - 20, 0, 140)
  preview = frame_new_view(vpages(3), 0, previewy, vpages(3)->w, 59)

  clearpage dpage  'The tileset (page 2) may be smaller
  copypage 2, dpage
  IF ts.y < 100 THEN
   'preview 59 pixels of tileset at bottom of screen
   frame_draw preview, , 0, 141, , NO, dpage
   rectangle 0, 139, 320, 2, uilook(uiSelectedItem + tog), dpage
   drawbox ts.tilex * 20, 141 + ts.tiley * 20 - previewy, 20, 20, uilook(uiSelectedItem + tog), 1, dpage
  ELSE
   'tileset preview at top of screen
   frame_draw preview, , 0, 0, , NO, dpage
   rectangle 0, 59, 320, 2, uilook(uiSelectedItem + tog), dpage
   drawbox ts.tilex * 20, ts.tiley * 20 - previewy, 20, 20, uilook(uiSelectedItem + tog), 1, dpage
  END IF
  frame_unload @preview
  previewticks -= 1
 ELSE
  clearpage dpage  'The tileset (page 2) may be smaller
  copypage 2, dpage
 END IF

 drawbox ts.x, ts.y, 20, 20, iif(tog, uilook(uiText), uilook(uiDescription)), 1, dpage

 textcolor uilook(uiMenuItem + tog), 1
 IF ts.zone = 11 THEN textcolor uilook(uiSelectedItem + tog), uilook(uiHighlight)
 printstr "< Prev", area(10).x, area(10).y, dpage
 textcolor uilook(uiMenuItem + tog), 1
 IF ts.zone = 12 THEN textcolor uilook(uiSelectedItem + tog), uilook(uiHighlight)
 printstr "Next >", area(11).x, area(11).y, dpage

 DIM ypos as integer
 IF ts.y < 100 THEN ypos = 200 - 20 ELSE ypos = 0
 textcolor uilook(uiText), uilook(uiHighlight)
 DIM temp as string
 IF ts.cuttileset THEN
  temp = "Tileset " & ts.cutfrom
 ELSE
  temp = "Backdop " & ts.cutfrom
 END IF
 printstr temp, 320\2 - LEN(temp) * 4, ypos, dpage
 temp = "X=" & ts.x & " Y=" & ts.y
 printstr temp, 320\2 - LEN(temp) * 4, ypos + 10, dpage

 temp = hilite("G") & "ridsnap:" & yesorno(snap_to_grid, "On", "Off")
 printstr temp, 4, ypos, dpage, YES

 IF ts.gotmouse THEN
  textcolor uilook(IIF(tog, uiText, uiDescription)), 0
  printstr CHR(2), mouse.x - 2, mouse.y - 2, dpage
 END IF
 SWAP dpage, vpage
 setvispage vpage
 dowait
LOOP
IF ts.gotmouse THEN
 movemouse ts.tilex * 20 + 10, ts.tiley * 20 + 10
END IF
END SUB

SUB tilecopy (cutnpaste() as integer, ts as TileEditState)
 FOR i as integer = 0 TO 19
  FOR j as integer = 0 TO 19
   cutnpaste(i, j) = readpixel(ts.tilex * 20 + i, ts.tiley * 20 + j, 3)
  NEXT j
 NEXT i
 ts.canpaste = 1
END SUB

SUB tilepaste (cutnpaste() as integer, ts as TileEditState)
 IF ts.canpaste THEN
  FOR i as integer = 0 TO 19
   FOR j as integer = 0 TO 19
    putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, cutnpaste(i, j), 3
   NEXT j
  NEXT i
  IF slave_channel <> NULL_CHANNEL THEN storemxs game + ".til", ts.tilesetnum, vpages(3)
 END IF 
END SUB

SUB tiletranspaste (cutnpaste() as integer, ts as TileEditState)
 IF ts.canpaste THEN
  FOR i as integer = 0 TO 19
   FOR j as integer = 0 TO 19
    IF cutnpaste(i, j) THEN putpixel ts.tilex * 20 + i, ts.tiley * 20 + j, cutnpaste(i, j), 3
   NEXT j
  NEXT i
  IF slave_channel <> NULL_CHANNEL THEN storemxs game + ".til", ts.tilesetnum, vpages(3)
 END IF
END SUB

'xw, yw is the size of a single frame.
'sets is the global holding maximum spriteset index, e.g. gen(genMaxNPCPic)
'perset is frames per spriteset.
'info() is an array of names for each frame
'fileset is the .PT# number.
SUB spriteset_editor (byval xw as integer, byval yw as integer, byref sets as integer, byval perset as integer, info() as string, fileset as SpriteType, fullset as bool=NO, byval cursor_start as integer=0, byval cursor_top as integer=0)

DIM ss as SpriteSetBrowseState
WITH ss
 .fileset = fileset
 .spritefile = game & ".pt" & .fileset
 .max_spriteset = @sets
 .framenum = 0
 .wide = xw
 .high = yw
 .perset = perset
 .size = (.wide * .high + 1) \ 2
 .setsize = .size * .perset
 .at_a_time = 200 \ (.high + 5) - 1
 .fullset = fullset
 .visible_sprites = allocate((.at_a_time + 1) * (.setsize \ 2) * sizeof(short))
END WITH

'--Editor state
DIM edstate as SpriteEditState
WITH edstate
 .wide = xw
 .high = yw
 .fileset = fileset
 .fullset = fullset
 .save_callback = @spritebrowse_save_callback
 .save_callback_context = @ss
END WITH

DIM placer(2 + ss.setsize \ 2) as integer
DIM workpal(8 * (ss.at_a_time + 1)) as integer
REDIM poffset(large(sets, ss.at_a_time)) as integer
DIM as integer do_paste = 0
DIM as integer paste_transparent = 0
DIM as integer debug_palettes = 0
DIM caption as string
'FOR Loop counters
DIM as integer i, j, o

DIM state as MenuState
WITH state
 .pt = cursor_start
 .top = cursor_top
 .size = ss.at_a_time
END WITH

FOR i = 0 TO 15
 'nulpal is used for getsprite and can go away once we convert to use Frame
 poke8bit ss.nulpal(), i, i
NEXT i
loaddefaultpals ss.fileset, poffset(), sets
spriteedit_load_all_you_see state.top, ss, workpal(), poffset()

setkeys
DO
 setwait 55
 setkeys
 state.tog = state.tog XOR 1
 IF keyval(scESC) > 1 THEN EXIT DO
 IF keyval(scF1) > 1 THEN
  IF ss.fullset THEN
   show_help "sprite_pickset_fullset"
  ELSE
   show_help "sprite_pickset"
  END IF
 END IF
 IF keyval(scCtrl) > 0 AND keyval(scBackspace) > 1 THEN
  spriteedit_save_all_you_see state.top, ss
  cropafter state.pt, sets, 0, ss.spritefile, ss.setsize
  clearpage 3
  spriteedit_load_all_you_see state.top, ss, workpal(), poffset()
 END IF
 IF enter_or_space() THEN
  spriteedit_get_loaded_sprite ss, placer(), state.top, state.pt, ss.framenum
  ' sprite_editor uses the callback to save the edited sprite.
  ' It also saves changes to palettes, but not the default palette selection (ss.pal_num)
  edstate.pal_num = poffset(state.pt)
  edstate.spriteset_num = state.pt
  edstate.framename = info(ss.framenum)
  edstate.default_export_filename = spriteedit_export_name(ss, state)
  ss.state_pt = state.pt  'These are needed by the callback
  ss.state_top = state.top
  DIM sprite as Frame ptr
  sprite = frame_new_from_buffer(placer())
  sprite_editor edstate, sprite
  frame_unload @sprite
  poffset(state.pt) = edstate.pal_num
  savedefaultpals ss.fileset, poffset(), sets  'Save default palettes immediately, only needed for live previewing
  ' Reload the palettes
  spriteedit_load_all_you_see state.top, ss, workpal(), poffset()
 END IF
 IF keyval(scCtrl) > 0 AND keyval(scF) > 1 THEN
  IF ss.fullset = NO AND ss.perset > 1 THEN
   spriteedit_save_all_you_see state.top, ss
   savedefaultpals ss.fileset, poffset(), sets
   spriteset_editor ss.wide * ss.perset, ss.high, sets, 1, info(), ss.fileset, YES, state.pt, state.top
   REDIM PRESERVE poffset(large(sets, ss.at_a_time))
   loaddefaultpals ss.fileset, poffset(), sets
   spriteedit_load_all_you_see state.top, ss, workpal(), poffset()
  END IF
 END IF
 DIM oldtop as integer = state.top
 IF intgrabber_with_addset(state.pt, 0, sets, 32767, "graphics", scUp, scDown) THEN
  IF state.pt > sets THEN
   sets = state.pt
   state.last = state.pt
   '--Add a new blank sprite set
   DIM zerobuf(ss.setsize \ 2 - 1) as integer
   storerecord zerobuf(), ss.spritefile, ss.setsize \ 2, state.pt
   '-- re-size the array that stores the default palette offset
   REDIM PRESERVE poffset(large(sets, ss.at_a_time))
   '--add a new blank default palette
   poffset(state.pt) = 0
   spriteedit_load_all_you_see state.top, ss, workpal(), poffset()
  END IF
  correct_menu_state state
 ELSE
  state.last = sets
  usemenu state
 END IF
 IF oldtop <> state.top THEN
  spriteedit_save_all_you_see oldtop, ss
  spriteedit_load_all_you_see state.top, ss, workpal(), poffset()
 END IF
 IF keyval(scLeft) > 1 THEN ss.framenum = large(ss.framenum - 1, 0)
 IF keyval(scRight) > 1 THEN ss.framenum = small(ss.framenum + 1, ss.perset - 1)
 IF keyval(scLeftBrace) > 1 THEN
  ' Previous palette
  changepal poffset(state.pt), -1, workpal(), state.pt - state.top
 END IF
 IF keyval(scRightBrace) > 1 THEN
  ' Next palette
  changepal poffset(state.pt), 1, workpal(), state.pt - state.top
 END IF
 '--copying
 IF copy_keychord() THEN
  spriteedit_get_loaded_sprite ss, placer(), state.top, state.pt, ss.framenum
  frame_assign @ss_save.spriteclip, frame_new_from_buffer(placer())
 END IF
 '--pasting
 do_paste = 0
 IF paste_keychord() AND ss_save.spriteclip <> NULL THEN
  do_paste = -1
  paste_transparent = 0
 END IF
 IF (keyval(scCtrl) > 0 AND keyval(scT) > 1) AND ss_save.spriteclip <> NULL THEN
  do_paste = -1
  paste_transparent = -1
 END IF
 IF do_paste THEN
  do_paste = 0
  spriteedit_get_loaded_sprite ss, placer(), state.top, state.pt, ss.framenum
  rectangle 0, 0, ss.wide, ss.high, 0, dpage
  drawsprite placer(), 0, ss.nulpal(), 0, 0, 0, dpage
  frame_draw ss_save.spriteclip, NULL, 0, 0, , paste_transparent, dpage
  getsprite placer(), 0, 0, 0, ss.wide, ss.high, dpage
  spriteedit_set_loaded_sprite ss, placer(), state.top, state.pt, ss.framenum
  spriteedit_save_spriteset state.pt, state.top, ss
 END IF
 IF keyval(scF2) > 1 THEN
  debug_palettes = debug_palettes XOR 1
 END IF
 IF keyval(scE) > 1 THEN
  spriteedit_get_loaded_sprite ss, placer(), state.top, state.pt, ss.framenum
  spriteedit_export spriteedit_export_name(ss, state), placer(), poffset(state.pt)
 END IF
 'draw sprite sets
 rectangle 0, 0, 320, 200, uilook(uiDisabledItem), dpage
 rectangle 4 + (ss.framenum * (ss.wide + 1)), (state.pt - state.top) * (ss.high + 5), ss.wide + 2, ss.high + 2, uilook(uiText), dpage
 FOR setnum as integer = state.top TO small(state.top + ss.at_a_time, sets)
  FOR framenum as integer = 0 TO ss.perset - 1
   rectangle 5 + framenum * (ss.wide + 1), 1 + (setnum - state.top) * (ss.high + 5), ss.wide, ss.high, 0, dpage
   spriteedit_get_loaded_sprite ss, placer(), state.top, setnum, framenum
   drawsprite placer(), 0, workpal(), (setnum - state.top) * 16, 5 + framenum * (ss.wide + 1), 1 + (setnum - state.top) * (ss.high + 5), dpage
  NEXT
 NEXT
 textcolor uilook(uiMenuItem), 0
 printstr "Palette " & poffset(state.pt), 320 - (LEN("Palette " & poffset(state.pt)) * 8), 0, dpage
 FOR i = 0 TO 15
  rectangle 271 + i * 3, 8, 3, 8, peek8bit(workpal(), (state.pt - state.top) * 16 + i), dpage
 NEXT i
 IF debug_palettes THEN
   FOR j = 0 TO ss.at_a_time
     FOR i = 0 TO 15
      rectangle 271 + i * 3, 40 + j * 5, 3, 4, peek8bit(workpal(), j * 16 + i), dpage
     NEXT i
   NEXT j
 END IF
 '--text captions
 caption = "Set " & state.pt
 printstr caption, 320 - (LEN(caption) * 8), 16, dpage
 caption = info(ss.framenum)
 printstr caption, 320 - (LEN(caption) * 8), 24, dpage
 caption = ""
 IF ss.fullset = NO AND ss.perset > 1 THEN
  caption = "CTRL+F Full-Set Mode, "
 ELSEIF ss.fullset = YES THEN
  caption = "ESC back to Single-Frame Mode, "
 END IF
 caption = caption & "F1 Help"
 printstr caption, 320 - (LEN(caption) * 8), 192, dpage
 '--screen update
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
spriteedit_save_all_you_see state.top, ss
deallocate ss.visible_sprites
savedefaultpals ss.fileset, poffset(), sets
'sprite_empty_cache ss.fileset
'Robust against sprite leaks
IF ss.fileset > -1 THEN sprite_update_cache ss.fileset

END SUB '----END of spriteset_editor()

' The sprite buffer remains in a rotated state after a rotation operation,
' call this to clip it to the correct size.
SUB spriteedit_clip (ss as SpriteEditState)
 IF ss.sprite->w <> ss.wide OR ss.sprite->h <> ss.high THEN
  frame_assign @ss.sprite, frame_resized(ss.sprite, ss.wide, ss.high)
 END IF
END SUB

' Save the current edit state as an undo step
SUB writeundospr (ss as SpriteEditState)
 ' Delete any redo steps. If ss.undodepth points before the end
 ' of history then we just undid a change before the current edit,
 ' and the current state is probably equal to .undo_history[.undodepth],
 ' so we could skip saving, but to be on the safe side save overwrite
 ' the current step.
 v_delete_slice ss.undo_history, ss.undodepth, v_len(ss.undo_history)
 ' Trim history if too long
 IF ss.undodepth >= ss.undomax THEN
  v_delete_slice ss.undo_history, 0, 1
  ss.undodepth -= 1
 END IF
 ' Append
 DIM spr as Frame ptr = frame_duplicate(ss.sprite)  'refcount == 1
 v_append ss.undo_history, spr  'Increments refcount
 ss.undodepth = v_len(ss.undo_history)
 frame_unload @spr
END SUB

' Change the current state of the sprite editor sprite to a new
' Frame, saving an undo step.
SUB spriteedit_edit(ss as SpriteEditState, new_sprite as Frame ptr)
 writeundospr ss
 frame_assign @ss.sprite, new_sprite
END SUB

' Perform undo
SUB readundospr (ss as SpriteEditState)
 IF ss.undodepth > 0 THEN
  ' If there are no existing redo steps, then save current state for redo
  IF ss.undodepth = v_len(ss.undo_history) THEN
   DIM spr as Frame ptr = frame_duplicate(ss.sprite)  'refcount == 1
   v_append ss.undo_history, spr  'Increments refcount
   frame_unload @spr
  END IF
  ss.undodepth -= 1
  frame_unload @ss.sprite
  ss.sprite = frame_duplicate(ss.undo_history[ss.undodepth])
  ss.didscroll = NO  'save a new undo block upon scrolling
 END IF
END SUB

' Perform redo
SUB readredospr (ss as SpriteEditState)
 IF ss.undodepth < v_len(ss.undo_history) - 1 THEN
  ss.undodepth += 1
  frame_unload @ss.sprite
  ss.sprite = frame_duplicate(ss.undo_history[ss.undodepth])
  ss.didscroll = NO  'save a new undo block upon scrolling
 END IF
END SUB

' Draw a 16-colour palette onscreen, with surrounding box
SUB spriteedit_draw_palette(pal16 as Palette16 ptr, x as integer, y as integer, page as integer)
 drawbox x, y, 67, 8, uilook(uiText), 1, page
 FOR i as integer = 0 TO 15
  rectangle x + 2 + (i * 4), y + 2, 3, 5, pal16->col(i), page
 NEXT
END SUB

' Draw the zoomed and unzoomed sprite areas
SUB spriteedit_draw_sprite_area(ss as SpriteEditState, sprite as Frame ptr, pal as Palette16 ptr, page as integer)
 ' Unzoomed preview
 drawbox ss.previewpos.x - 1, ss.previewpos.y - 1, ss.wide + 2, ss.high + 2, uilook(uiText), 1, page
 frame_draw sprite, pal, ss.previewpos.x, ss.previewpos.y, 1, NO, page
 ' Main draw area
 drawbox ss.area(0).x - 1, ss.area(0).y - 1, ss.area(0).w + 2, ss.area(0).h + 2, uilook(uiText), 1, page
 setclip ss.area(0).x, ss.area(0).y, ss.area(0).x + ss.area(0).w - 1, ss.area(0).y + ss.area(0).h - 1
 frame_draw sprite, pal, ss.area(0).x, ss.area(0).y, ss.zoom, NO, page
 setclip
END SUB

' Draw sprite editor
SUB spriteedit_display(ss as SpriteEditState)
 clearpage dpage
 ' Draw the sprite
 spriteedit_draw_sprite_area ss, ss.sprite, ss.palette, dpage

 ' Draw the master palette
 ss.curcolor = ss.palette->col(ss.palindex)   'Is this necessary?
 rectangle 247 + ((ss.curcolor - ((ss.curcolor \ 16) * 16)) * 4), 0 + ((ss.curcolor \ 16) * 6), 5, 7, uilook(uiText), dpage
 DIM as integer i, o
 FOR i = 0 TO 15
  FOR o = 0 TO 15
   rectangle 248 + (i * 4), 1 + (o * 6), 3, 5, o * 16 + i, dpage
  NEXT o
 NEXT i

 ' Draw the <-Pal###-> or <-Col###-> display
 textcolor_icon NO, ss.zonenum = 5
 printstr CHR(27), 243, 100, dpage
 textcolor_icon NO, ss.zonenum = 6
 printstr CHR(26), 307, 100, dpage
 textcolor uilook(uiText), 0
 DIM paldisplay as string
 IF ss.showcolnum > 0 THEN
  paldisplay = " Col" & rlpad(STR(ss.curcolor), " ", 3, 4)
  IF keyval(scAlt) = 0 THEN
   ss.showcolnum -= 1
  END IF
 ELSE
  paldisplay = " Pal" & rlpad(STR(ss.pal_num), " ", 3, 4)
 END IF
 printstr paldisplay, 243, 100, dpage

 rectangle 247 + (ss.palindex * 4), 110, 5, 7, uilook(uiText), dpage
 spriteedit_draw_palette ss.palette, 246, 109, dpage

 DIM select_rect as RectType
 corners_to_rect_inclusive Type(ss.x, ss.y), ss.holdpos, select_rect

 IF ss.hold = YES AND ss.tool = box_tool THEN
  rectangle 4 + select_rect.x * ss.zoom, 1 + select_rect.y * ss.zoom, select_rect.wide * ss.zoom, select_rect.high * ss.zoom, ss.curcolor, dpage
  rectangle 4 + ss.holdpos.x * ss.zoom, 1 + ss.holdpos.y * ss.zoom, ss.zoom, ss.zoom, IIF(ss.tog, uilook(uiBackground), uilook(uiText)), dpage
 END IF

 DIM overlay as Frame ptr
 overlay = frame_new(ss.wide, ss.high, , YES)
 'hack: We don't draw real palette colours to overlay, otherwise we couldn't draw colour 0
 DIM pal16 as Palette16 ptr
 pal16 = palette16_new()
 pal16->col(1) = ss.curcolor

 IF ss.hold = YES AND ss.tool = box_tool THEN
  rectangle ss.previewpos.x + select_rect.x, ss.previewpos.y + select_rect.y, select_rect.wide, select_rect.high, ss.curcolor, dpage
  putpixel ss.previewpos.x + ss.holdpos.x, ss.previewpos.y + ss.holdpos.y, ss.tog * 15, dpage
 END IF
 IF ss.hold = YES AND ss.tool = line_tool THEN
  drawline ss.previewpos.x + ss.x, ss.previewpos.y + ss.y, ss.previewpos.x + ss.holdpos.x, ss.previewpos.y + ss.holdpos.y, ss.curcolor, dpage
  drawline overlay, ss.x, ss.y, ss.holdpos.x, ss.holdpos.y, 1
 END IF
 IF ss.hold = YES AND ss.tool = oval_tool THEN
  ellipse vpages(dpage), ss.previewpos.x + ss.holdpos.x, ss.previewpos.y + ss.holdpos.y, ss.radius, ss.curcolor, , ss.ellip_minoraxis, ss.ellip_angle
  ellipse overlay, ss.holdpos.x, ss.holdpos.y, ss.radius, 1, , ss.ellip_minoraxis, ss.ellip_angle
 END IF
 IF ss.tool = airbrush_tool THEN
  ellipse vpages(dpage), ss.previewpos.x + ss.x, ss.previewpos.y + ss.y, ss.airsize / 2, ss.curcolor
  ellipse vpages(dpage), 5 + (ss.x * ss.zoom), 2 + (ss.y * ss.zoom), (ss.airsize / 2) * ss.zoom, ss.curcolor
 END IF

 frame_draw overlay, pal16, 4, 1, ss.zoom, YES, dpage
 frame_unload @overlay
 palette16_unload @pal16

 IF ss.tool <> clone_tool THEN
  'Pixel at cursor position
  rectangle 4 + (ss.x * ss.zoom), 1 + (ss.y * ss.zoom), ss.zoom, ss.zoom, IIF(ss.tog, uilook(uiBackground), uilook(uiText)), dpage
  putpixel ss.previewpos.x + ss.x, ss.previewpos.y + ss.y, ss.tog * 15, dpage
 END IF
 IF ss.hold = YES AND ss.tool = mark_tool AND ss.tog = 0 THEN
  ss.curcolor = randint(255) ' Random color when marking a clone region
  drawbox 4 + select_rect.x * ss.zoom, 1 + select_rect.y * ss.zoom, select_rect.wide * ss.zoom, select_rect.high * ss.zoom, ss.curcolor, ss.zoom, dpage
  drawbox ss.previewpos.x + select_rect.x, ss.previewpos.y + select_rect.y, select_rect.wide, select_rect.high, ss.curcolor, 1, dpage
 END IF
 DIM temppos as XYPair
 IF ss.tool = clone_tool AND ss_save.clone_brush <> NULL AND ss.tog = 0 THEN
  temppos.x = ss.x - ss_save.clonepos.x
  temppos.y = ss.y - ss_save.clonepos.y
  IF ss.readjust THEN
   temppos.x += (ss.adjustpos.x - ss.x)
   temppos.y += (ss.adjustpos.y - ss.y)
  END IF
  frame_draw ss_save.clone_brush, ss.palette, 4 + temppos.x * ss.zoom, 1 + temppos.y * ss.zoom, ss.zoom, , dpage
  frame_draw ss_save.clone_brush, ss.palette, ss.previewpos.x + temppos.x, ss.previewpos.y + temppos.y, , , dpage
 END IF
 textcolor uilook(uiMenuItem), 0
 printstr "x=" & ss.x & " y=" & ss.y, 0, 190, dpage
 printstr "Tool:" & ss.toolinfo(ss.tool).name, 0, 182, dpage
 printstr ss.framename, 0, 174, dpage
 FOR i = 0 TO UBOUND(ss.toolinfo)
  spriteedit_draw_icon ss, ss.toolinfo(i).icon, ss.toolinfo(i).areanum, (ss.tool = i)
 NEXT i
 spriteedit_draw_icon ss, CHR(7), 3  'horizontal flip
 spriteedit_draw_icon ss, "I", 12
 spriteedit_draw_icon ss, "E", 25

 IF ss.undodepth = 0 THEN
  textcolor uilook(uiBackground), uilook(uiDisabledItem)
 ELSE
  textcolor_icon ss.zonenum = 20, NO
 END IF
 printstr "UNDO", 130, 182, dpage
 ' Both undodepth = len and undodepth = len-1 are valid and indicate
 ' no more redo history (the later means no unsaved changes)
 IF ss.undodepth >= v_len(ss.undo_history) - 1 THEN
  textcolor uilook(uiBackground), uilook(uiDisabledItem)
 ELSE
  textcolor_icon ss.zonenum = 21, NO
 END IF
 printstr "REDO", 170, 182, dpage

 IF ss.tool = airbrush_tool THEN
  textcolor uilook(uiMenuItem), 0
  printstr "SIZE" & ss.airsize, 228, 182, dpage
  printstr "MIST" & ss.mist, 228, 190, dpage
  spriteedit_draw_icon ss, CHR(27), 14
  spriteedit_draw_icon ss, CHR(27), 15
  spriteedit_draw_icon ss, CHR(26), 16
  spriteedit_draw_icon ss, CHR(26), 17
 END IF
 IF ss.tool <> airbrush_tool THEN
  textcolor uilook(uiMenuItem), 0
  printstr "ROTATE", 228, 190, dpage
  spriteedit_draw_icon ss, CHR(27), 15
  spriteedit_draw_icon ss, CHR(26), 17
 END IF
 IF ss.gotmouse THEN
  IF ss.zonecursor = -1 THEN
   IF ss.hidemouse THEN ss.zonecursor = -2 ELSE ss.zonecursor = ss.drawcursor
  END IF
  textcolor uilook(IIF(ss.tog, uiText, uiDescription)), 0
  printstr CHR(2 + ss.zonecursor), ss.mouse.x - 2, ss.mouse.y - 2, dpage
 END IF
END SUB

SUB textcolor_icon(selected as bool, hover as bool)
 DIM as integer fg = uiMenuItem, bg = uiDisabledItem
 IF selected THEN
  fg = uiText
  bg = uiMenuItem
 END IF
 IF hover THEN
  IF selected THEN fg = uiSelectedItem ELSE fg = uiText
  bg = uiSelectedDisabled
 END IF
 textcolor uilook(fg), uilook(bg)
END SUB

'Draw one of the clickable areas (obviously this will all be replaced with slices eventually)
SUB spriteedit_draw_icon(ss as SpriteEditState, icon as string, byval areanum as integer, byval highlight as integer = NO)
 textcolor_icon highlight, (ss.zonenum = areanum + 1)
 printstr icon, ss.area(areanum).x, ss.area(areanum).y, dpage
END SUB

SUB init_sprite_zones(area() as MouseArea, ss as SpriteEditState)
 DIM i as integer
 'DRAWING ZONE
 area(0).w = small(ss.wide * ss.zoom, 240)
 area(0).h = small(ss.high * ss.zoom, 165)
 area(0).x = 4
 area(0).y = 1
 area(0).hidecursor = YES
 'PALETTE ZONE
 area(1).x = 248
 area(1).y = 111
 area(1).w = 64
 area(1).h = 6
 area(1).hidecursor = NO
 'MASTER PAL ZONE
 area(2).x = 248
 area(2).y = 1
 area(2).w = 64
 area(2).h = 96
 area(2).hidecursor = NO
 'FLIP BUTTON
 area(3).x = 184
 area(3).y = 190
 area(3).w = 8
 area(3).h = 10
 area(3).hidecursor = NO
 'PREV PAL BUTTON
 area(4).x = 243
 area(4).y = 100
 area(4).w = 8
 area(4).h = 8
 area(4).hidecursor = NO
 'NEXT PAL BUTTON
 area(5).x = 307
 area(5).y = 100
 area(5).w = 8
 area(5).h = 8
 area(5).hidecursor = NO
 'TOOL BUTTONS (more below at 21-24)
 FOR i = 0 TO 5
  area(6 + i).x = 80 + i * 10
  area(6 + i).y = 190
  area(6 + i).w = 8
  area(6 + i).h = 10
  area(6 + i).hidecursor = NO
 NEXT i
 'IMPORT BUTTON
 area(12).x = 196
 area(12).y = 190
 area(12).w = 8
 area(12).h = 10
 area(12).hidecursor = NO
 'SMALL DRAWING AREA
 area(13).w = ss.wide
 area(13).h = ss.high
 area(13).x = ss.previewpos.x
 area(13).y = ss.previewpos.y
 area(13).hidecursor = YES
 'LESS AIRBRUSH AREA
 area(14).x = 220
 area(14).y = 182
 area(14).w = 8
 area(14).h = 8
 area(14).hidecursor = NO
 'LESS AIRBRUSH MIST
 area(15).x = 220
 area(15).y = 190
 area(15).w = 8
 area(15).h = 8
 area(15).hidecursor = NO
 'MORE AIRBRUSH AREA
 area(16).x = 276
 area(16).y = 182
 area(16).w = 8
 area(16).h = 8
 area(16).hidecursor = NO
 'MORE AIRBRUSH MIST
 area(17).x = 276
 area(17).y = 190
 area(17).w = 8
 area(17).h = 8
 area(17).hidecursor = NO
 'PALETTE NUMBER
 area(18).x = 256
 area(18).y = 100
 area(18).w = 48
 area(18).h = 8
 area(18).hidecursor = NO
 'UNDO BUTTON
 area(19).x = 130
 area(19).y = 182
 area(19).w = 32
 area(19).h = 8
 area(19).hidecursor = NO
 'REDO BUTTON
 area(20).x = 170
 area(20).y = 182
 area(20).w = 32
 area(20).h = 8
 area(20).hidecursor = NO
 'MORE TOOLS
 FOR i = 0 TO 3
  area(21 + i).x = 140 + i * 10
  area(21 + i).y = 190
  area(21 + i).w = 8
  area(21 + i).h = 10
  area(21 + i).hidecursor = NO
 NEXT i
 'EXPORT BUTTON
 area(25).x = 206
 area(25).y = 190
 area(25).w = 8
 area(25).h = 10
 area(25).hidecursor = NO
END SUB

' This is called from the sprite editor and calls into the spriteset browser
' in order to save the current frame to file.
SUB spritebrowse_save_callback(spr as Frame ptr, context as any ptr)
 DIM byref ss as SpriteSetBrowseState = *cast(SpriteSetBrowseState ptr, context)
 DIM placer(2 + ss.setsize \ 2) as integer
 frame_to_buffer spr, placer()
 spriteedit_set_loaded_sprite ss, placer(), ss.state_top, ss.state_pt, ss.framenum
 spriteedit_save_spriteset ss.state_pt, ss.state_top, ss
 IF ss.fileset > -1 THEN sprite_update_cache ss.fileset
END SUB

' Copies one of the frames visible in the spriteset browser into placer()
SUB spriteedit_get_loaded_sprite(ss as SpriteSetBrowseState, placer() as integer, top as integer, setnum as integer, framenum as integer)
 DIM offset as integer = (setnum - top) * (ss.setsize \ 2) + framenum * (ss.size \ 2)
 placer(0) = ss.wide
 placer(1) = ss.high
 FOR idx as integer = 0 TO ss.size \ 2 - 1
  placer(2 + idx) = ss.visible_sprites[offset + idx]
 NEXT
END SUB

' Sets one of the frames visible in the spriteset browser from placer()
SUB spriteedit_set_loaded_sprite(ss as SpriteSetBrowseState, placer() as integer, top as integer, setnum as integer, framenum as integer)
 DIM offset as integer = (setnum - top) * (ss.setsize \ 2) + framenum * (ss.size \ 2)
 FOR idx as integer = 0 TO ss.size \ 2 - 1
  ss.visible_sprites[offset + idx] = placer(2 + idx)
 NEXT
END SUB

' Save .visible_sprites (all spritesets visible in spriteset browser) to disk
SUB spriteedit_save_all_you_see(byval top as integer, ss as SpriteSetBrowseState)
 FOR setnum as integer = top TO top + ss.at_a_time
  spriteedit_save_spriteset(setnum, top, ss)
 NEXT setnum
END SUB

' Load all visible spritesets (.visible_sprites) and their palettes (workpal()) from disk
SUB spriteedit_load_all_you_see(byval top as integer, ss as SpriteSetBrowseState, workpal() as integer, poffset() as integer)
 FOR setnum as integer = top TO top + ss.at_a_time
  ' Load pal
  getpal16 workpal(), setnum - top, poffset(setnum)
  ' Load spriteset
  spriteedit_load_spriteset(setnum, top, ss)
 NEXT
END SUB

' Load a spriteset into ss.visible_sprites
SUB spriteedit_load_spriteset(setnum as integer, top as integer, ss as SpriteSetBrowseState)
 DIM buf(ss.setsize \ 2) as integer
 DIM placer(2 + ss.setsize \ 2) as integer
 DIM offset as integer = 0
 IF setnum <= *ss.max_spriteset THEN
  loadrecord buf(), ss.spritefile, ss.setsize \ 2, setnum
  ' Create a temporary placer() buffer
  FOR framenum as integer = 0 TO (ss.perset - 1)
   placer(0) = ss.wide
   placer(1) = ss.high
   FOR k as integer = 0 to ss.size \ 2 - 1
    placer(2 + k) = buf(offset)
    offset += 1
   NEXT
   spriteedit_set_loaded_sprite ss, placer(), top, setnum, framenum
  NEXT framenum
 END IF
END SUB

' Save one of the spriteset in ss.visible_sprites to disk
SUB spriteedit_save_spriteset(setnum as integer, top as integer, ss as SpriteSetBrowseState)
 DIM buf(ss.setsize \ 2) as integer
 DIM placer(2 + ss.setsize \ 2) as integer
 DIM offset as integer = 0
 IF setnum <= *ss.max_spriteset THEN
  FOR framenum as integer = 0 TO (ss.perset - 1)
   spriteedit_get_loaded_sprite ss, placer(), top, setnum, framenum
   'placer(0),placer(1) are w,h, placer(2 to 2+(w*h+1)\2) are pixels (2 bytes per int)
   FOR k as integer = 0 to ss.size \ 2 - 1
    buf(offset) = placer(2 + k)
    offset += 1
   NEXT
  NEXT framenum
  storerecord buf(), ss.spritefile, ss.setsize \ 2, setnum
 END IF
END SUB

FUNCTION spriteedit_export_name (ss as SpriteSetBrowseState, state as MenuState) as string
 DIM s as string
 s = trimpath(trimextension(sourcerpg)) & " " & exclude(LCASE(sprite_sizes(ss.fileset).name), " ")
 IF ss.fullset THEN
  s &= " set " & state.pt
 ELSE
  s &= " " & state.pt
  IF ss.perset > 1 THEN s &= " frame " & ss.framenum
 END IF
 RETURN s
END FUNCTION

'Wrapper, only for the spriteset browser
SUB spriteedit_export(default_name as string, placer() as integer, palnum as integer)
 'palnum is offset into pal lump of the 16 color palette this sprite should use

 DIM as Frame ptr sprite = frame_new_from_buffer(placer())
 DIM as Palette16 ptr pal = palette16_load(palnum)
 '--hand off the frame and palette to the real export function
 spriteedit_export default_name, sprite, pal
 '--cleanup
 frame_unload @sprite
 palette16_unload @pal
END SUB

SUB spriteedit_export(default_name as string, sprite as Frame ptr, pal as Palette16 ptr)
 STATIC defaultdir as string
 DIM outfile as string
 outfile = inputfilename("Export to bitmap file", ".bmp", defaultdir, "input_file_export_sprite", default_name)
 IF outfile <> "" THEN
  frame_export_bmp4 outfile & ".bmp", sprite, master(), pal
 END IF
END SUB

'Load a BMP of any bitdepth into a Frame which has just 16 colours: those in pal16
SUB spriteedit_import16_loadbmp(byref ss as SpriteEditState, srcbmp as string, byref impsprite as Frame ptr, byref pal16 as Palette16 ptr)
 pal16 = palette16_new()

 DIM bmpd as BitmapV3InfoHeader
 bmpinfo(srcbmp, bmpd)
 'debuginfo "import16_load: bitdepth " & bmpd.biBitCount

 'Map from impsprite colors to master pal indices
 DIM bmppal(255) as integer
 'Put color index hints in bmppal(), which are used if they are an exact match.
 FOR i as integer = 0 TO 15
  bmppal(i) = ss.palette->col(i)
 NEXT

 IF bmpd.biBitCount <= 4 THEN
  'If 4 bit or below, we preserve the colour indices from the BMP

  impsprite = frame_import_bmp_raw(srcbmp)

  convertbmppal(srcbmp, master(), bmppal())
  FOR i as integer = 0 TO 15
   pal16->col(i) = bmppal(i)
  NEXT 

 ELSE
  'For higher bitdepths, try to shift used colour indices into 0-15

  'map from impsprite colors to master pal indices
  DIM bmppal(255) as integer

  IF bmpd.biBitCount > 8 THEN
   'notification srcbmp & " is a " & bmpd.biBitCount & "-bit BMP file. Colors will be mapped to the nearest entry in the master palette." _
   '             " It's recommended that you save your graphics as 4-bit BMPs so that you can control which colours are used."
   impsprite = frame_import_bmp24_or_32(srcbmp, master())
   FOR i as integer = 0 TO 255
    bmppal(i) = i
   NEXT
  ELSE  'biBitCount = 8
   impsprite = frame_import_bmp_raw(srcbmp)
   convertbmppal(srcbmp, master(), bmppal())
  END IF

  IF impsprite <> NULL THEN
   'First special case (intended for 8 bit bmps): don't do any remapping if the indices are already 0-15

   DIM require_remap as bool = NO
   FOR x as integer = 0 TO impsprite->w - 1
    FOR y as integer = 0 TO impsprite->h - 1
     IF readpixel(impsprite, x, y) >= 16 THEN require_remap = YES
    NEXT
   NEXT

   IF require_remap = NO THEN
    FOR i as integer = 0 TO 15
     pal16->col(i) = bmppal(i)
    NEXT i
   ELSE

    'Find the set of colours used in impsprite, and remap impsprite
    'to those colour indices
    DIM vpal16 as integer vector
    v_new vpal16
    'v_append vpal16, 0

    FOR x as integer = 0 TO impsprite->w - 1   'small(impsprite->w, ss.wide) - 1
     FOR y as integer = 0 TO impsprite->h - 1  'small(impsprite->h, ss.high) - 1
      DIM col as integer = bmppal(readpixel(impsprite, x, y))
      DIM at as integer = v_find(vpal16, col)
      IF at = -1 THEN
       v_append vpal16, col
       col = v_len(vpal16) - 1
      ELSE
       col = at
      END IF
      putpixel(impsprite, x, y, col)
     NEXT
    NEXT
    debuginfo srcbmp & " contains " & v_len(vpal16) & " colors"

    IF v_len(vpal16) > 16 THEN
     notification "This image contains " & v_len(vpal16) & " colors (after finding nearest-matches to the master palette). At most 16 are allowed." _
                  " Reduce the number of colors and try importing again."
     palette16_unload @pal16
     frame_unload @impsprite
     v_free vpal16
     EXIT SUB
    ELSE
     FOR i as integer = 0 TO v_len(vpal16) - 1
      pal16->col(i) = vpal16[i]
     NEXT i
    END IF

    v_free vpal16
   END IF
  END IF
 END IF

 IF impsprite = NULL THEN
  notification "Could not load " & srcbmp
  palette16_unload @pal16
  EXIT SUB
 END IF
END SUB

'Returns a new Frame, after deleting the input one. Returns NULL if cancelled
FUNCTION spriteedit_import16_cut_frames(byref ss as SpriteEditState, impsprite as Frame ptr, pal16 as Palette16 ptr, bgcol as integer) as Frame ptr
 DIM image_pos as XYPair = (1, 1)  'Position at which to draw impsprite

 'This staticness is a bit hacky
 STATIC last_fileset as integer = -1
 STATIC frame_size as XYPair
 STATIC first_offset as XYPair     'Position of first frame
 STATIC direction_offset as XYPair 'Offset between direction groups
 STATIC frame_offset as XYPair     'Offset between frames for the same direction

 DIM flattened_set as Frame ptr

 WITH sprite_sizes(ss.fileset)
  DIM frames_per_dir as integer = .frames \ .directions

  IF last_fileset <> ss.fileset THEN
   frame_size = .size
   first_offset = TYPE(0, 0)
   frame_offset = TYPE(.size.w, 0)
   direction_offset = TYPE(.size.w * frames_per_dir, 0)
  END IF
  last_fileset = ss.fileset

  DIM tog as integer
  DIM menu(7) as string
  DIM st as MenuState
  DIM menuopts as MenuOptions
  menuopts.edged = YES
  menuopts.itemspacing = -1
  st.active = YES
  IF .directions > 1 THEN
   st.last = 7
  ELSE
   st.last = 5
  END IF
  st.size = st.last + 1

  setkeys
  DO
   setwait 55
   setkeys
   tog XOR= 1

   'Every frame re-layout the menu
   'The Y position of the text at bottom of the screen
   DIM texty as integer = vpages(dpage)->h - (st.last + 2) * 8 - 4

   DIM zoom as integer
   ' Choose maximum zoom that will fit
   zoom = small(large(1, vpages(dpage)->w \ impsprite->w), large(1, texty \ impsprite->h))

   IF keyval(scESC) > 1 THEN
    frame_unload @impsprite
    RETURN NULL
   END IF
   IF keyval(scF1) > 1 THEN show_help "sprite_import16_cut_frames"
   IF enter_or_space() THEN EXIT DO

   usemenu st
   DIM temp as integer = st.pt
   IF .directions = 1 AND temp >= 2 THEN temp += 2
   SELECT CASE temp
    CASE 0: intgrabber first_offset.x, -impsprite->w, impsprite->w
    CASE 1: intgrabber first_offset.y, -impsprite->h, impsprite->h
    CASE 2: intgrabber direction_offset.x, -impsprite->w, impsprite->w
    CASE 3: intgrabber direction_offset.y, -impsprite->h, impsprite->h
    CASE 4: intgrabber frame_offset.x, -impsprite->w, impsprite->w
    CASE 5: intgrabber frame_offset.y, -impsprite->h, impsprite->h
    CASE 6: intgrabber frame_size.w, 0, .size.w
    CASE 7: intgrabber frame_size.h, 0, .size.h
   END SELECT

   menu(0) = "First frame x: " & first_offset.x
   menu(1) = "First frame y: " & first_offset.y
   temp = 2
   IF .directions > 1 THEN
    menu(2) = "Direction group offset x: " & direction_offset.x
    menu(3) = "Direction group offset y: " & direction_offset.y
    temp = 4
   END IF
   menu(temp) = "Each-frame offset x: " & frame_offset.x
   menu(temp + 1) = "Each-frame offset y: " & frame_offset.y
   menu(temp + 2) = "Frame width: " & frame_size.w
   menu(temp + 3) = "Frame height: " & frame_size.h

   '--Draw screen
   clearpage dpage
   drawbox image_pos.x - 1, image_pos.y - 1, zoom * impsprite->w + 2, zoom * impsprite->h + 2, uilook(uiMenuItem), 1, dpage
   frame_draw impsprite, pal16, image_pos.x, image_pos.y, zoom, NO, dpage

   DIM framenum as integer = 0
   FOR direction as integer = 0 TO .directions - 1
    FOR dirframe as integer = 0 TO frames_per_dir - 1
     DIM as integer x, y  'coords in terms of impsprite pixels
     x = first_offset.x + direction * direction_offset.x + dirframe * frame_offset.x
     y = first_offset.y + direction * direction_offset.y + dirframe * frame_offset.y
     drawbox image_pos.x + zoom * x, image_pos.y + zoom * y, zoom * frame_size.w, zoom * frame_size.h, uilook(uiText), 1, dpage
     framenum += 1
    NEXT
   NEXT

   'edgeprint "Offsets between spriteset frames:", 0, texty, uilook(uiText), dpage, YES, YES
   edgeprint "Define spriteset layout and press ENTER", 0, texty, uilook(uiText), dpage, YES, YES
   standardmenu menu(), st, 0, texty + 10, dpage, menuopts
   
   SWAP vpage, dpage
   setvispage vpage
   dowait
  LOOP

  ' Cut out the frames and place in a new one
  flattened_set = frame_new(ss.wide, ss.high)
  frame_clear flattened_set, bgcol

  DIM framenum as integer = 0
  FOR direction as integer = 0 TO .directions - 1
   FOR dirframe as integer = 0 TO frames_per_dir - 1
    DIM as integer x, y
    x = first_offset.x + direction * direction_offset.x + dirframe * frame_offset.x
    y = first_offset.y + direction * direction_offset.y + dirframe * frame_offset.y
    DIM impview as Frame ptr = frame_new_view(impsprite, x, y, frame_size.w, frame_size.h)
    frame_draw impview, , (.size.w - frame_size.w) \ 2 + framenum * .size.w, .size.h - frame_size.h, , NO, flattened_set
    frame_unload @impview
    framenum += 1
   NEXT
  NEXT

  frame_unload @impsprite
 END WITH

 RETURN flattened_set
END FUNCTION

'Select a single pixel from a Frame, used for selecting the background colour.
'pal16 may be NULL.
'zoom is the zoom to draw at.
'Can restrict the selected pixel to the top left corner of the image by passing maxx, maxy args
'Returns NO if user cancelled, otherwise YES and the pixel coordinate is returned in pickpos
FUNCTION pick_image_pixel(image as Frame ptr, pal16 as Palette16 ptr = NULL, byref pickpos as XYPair, zoom as integer = 1, maxx as integer = 9999, maxy as integer = 9999, message as string, helpkey as string) as bool
 DIM ret as bool = YES
 DIM tog as integer
 DIM picksize as XYPair
 'pickpos will be set to mouse cursor position
 pickpos.x = 0
 pickpos.y = 0
 DIM initialise_pickpos as bool = YES
 DIM imagepos as XYPair
 ' If it's smaller than the screen, offset the image so it's not sitting in the corner
 IF maxx * zoom + 4 < vpages(dpage)->w THEN
  imagepos.x = 4
  imagepos.y = 1
 END IF

 DIM prev_mouse_vis as CursorVisibility = getcursorvisibility()
 hidemousecursor
 DIM mouse as MouseInfo
 setkeys
 DO
  setwait 20
  setkeys
  mouse = readmouse()
  tog XOR= 1
  IF keyval(scESC) > 1 THEN ret = NO : EXIT DO
  IF keyval(scF1) > 1 THEN show_help helpkey

  IF enter_or_space() OR (mouse.clickstick AND mouseleft) THEN
   ret = YES
   EXIT DO
  END IF

  picksize.x = small(vpages(dpage)->w, small(image->w, maxx))
  picksize.y = small(vpages(dpage)->h, small(image->h, maxy))

  '--Moving mouse moves cursor and vice versa
  IF mouse.moved OR initialise_pickpos THEN
   pickpos.x = bound((mouse.x - imagepos.x) \ zoom, 0, picksize.x - 1)
   pickpos.y = bound((mouse.y - imagepos.y) \ zoom, 0, picksize.y - 1)
   initialise_pickpos = NO
  ELSE
   DIM movespeed as integer
   IF keyval(scALT) THEN movespeed = 9 ELSE movespeed = 1
   DIM moved as bool = NO
   IF keyval(scUp) > 0 THEN pickpos.y = large(pickpos.y - movespeed, 0) : moved = YES
   IF keyval(scDown) > 0 THEN pickpos.y = small(pickpos.y + movespeed, picksize.y - 1) : moved = YES
   IF keyval(scleft) > 0 THEN pickpos.x = large(pickpos.x - movespeed, 0) : moved = YES
   IF keyval(scRight) > 0 THEN pickpos.x = small(pickpos.x + movespeed, picksize.x - 1) : moved = YES
   IF moved THEN
    mouse.x = imagepos.x + (pickpos.x + 0.5) * zoom
    mouse.y = imagepos.y + (pickpos.y + 0.5) * zoom
    movemouse mouse.x, mouse.y
   END IF
  END IF

  clearpage dpage
  frame_draw image, pal16, imagepos.x, imagepos.y, zoom, NO, dpage
  'Draw box around the selectable proportion of the image
  drawbox imagepos.x - 1, imagepos.y - 1, picksize.x * zoom + 2, picksize.y * zoom + 2, uilook(uiText), 1, dpage

  '--Draw info box at top right
  DIM current_col as integer = readpixel(image, pickpos.x, pickpos.y)
  DIM master_col as integer  ' Index in master()
  IF pal16 THEN
   master_col = pal16->col(current_col)
  ELSE
   master_col = current_col
  END IF
  rectangle rRight - 50, 0, 50, 40, master_col, dpage
  edgeprint !"Color:\n" & current_col, rRight - 50, 10, uilook(uiMenuItem), dpage, YES, YES

  '--Draw the pixel cursor
  DIM col as integer
  IF tog THEN col = uilook(uiBackground) ELSE col = uilook(uiText)
  IF zoom = 1 THEN
   'A single pixel is too small, so draw the crosshair mouse cursor.
   'A little bit tricky: we only draw the mouse cursor, and not a separate cursor
   textcolor col, 0
   'printstr CHR(5), imagepos.x + pickpos.x - 2, imagepos.y + pickpos.y - 2, dpage
   printstr CHR(5), mouse.x - 2, mouse.y - 2, dpage
  ELSE
   'Draw both pixel cursor and mouse cursor
   rectangle imagepos.x + pickpos.x * zoom, imagepos.y + pickpos.y * zoom, zoom, zoom, col, dpage
   textcolor uilook(uiSelectedItem + tog), 0
   printstr CHR(2), mouse.x - 2, mouse.y - 2, dpage
  END IF

  edgeprint message, 0, 180, uilook(uiMenuItem), dpage, YES, YES
  'edgeprint "ALT: move faster", 320 - 16*8, 190, uilook(uiMenuItem), dpage, YES, YES
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 setcursorvisibility(prev_mouse_vis)
 RETURN ret
END FUNCTION

'Lets the use pick one of the colour/pixels in impsprite, returns the colour index
'Returns -1 if cancelled.
FUNCTION spriteedit_import16_pick_bgcol(byref ss as SpriteEditState, impsprite as Frame ptr, pal16 as Palette16 ptr) as integer
 DIM pickpos as XYPair
 DIM ret as bool
 ret = pick_image_pixel(impsprite, pal16, pickpos, ss.zoom, , , "Pick background (transparent) color", "sprite_import16_pickbackground")
 IF ret = NO THEN RETURN -1

 RETURN readpixel(impsprite, pickpos.x, pickpos.y)
END FUNCTION

'Set can_remap to whether a mapping from pal16 to ss.palette exists,
'and if so write it in palmapping().
SUB spriteedit_import16_compare_palettes(byref ss as SpriteEditState, byval new_pal as Palette16 ptr, palmapping() as integer, byref can_remap as bool, byref is_identical as bool)
 can_remap = YES
 is_identical = YES
 FOR i as integer = 1 TO 15
  'IF new_pal->col(i) <> ss.palette->col(i) THEN is_identical = NO
  IF color_distance(master(), new_pal->col(i), ss.palette->col(i)) > 0 THEN is_identical = NO
  DIM found as bool = NO
  FOR j as integer = 1 TO 15
   'IF new_pal->col(i) = ss.palette->col(j) THEN
   IF color_distance(master(), new_pal->col(i), ss.palette->col(j)) = 0 THEN
    palmapping(i) = j
    found = YES
    EXIT FOR
   END IF
  NEXT
  IF found = NO THEN can_remap = NO
 NEXT
END SUB

'Return value: see retval()
'Also returns contents of palmapping()
FUNCTION spriteedit_import16_remap_menu(byref ss as SpriteEditState, byref impsprite as Frame ptr, byref pal16 as Palette16 ptr, palmapping() as integer) as integer
 DIM can_remap as bool
 DIM is_identical as bool
 DIM usepal as Palette16 ptr
 DIM ret as integer

 DIM pmenu(2) as string
 DIM retval(2) as integer
 DIM palstate as MenuState 
 palstate.pt = 0
 palstate.last = 2
 palstate.size = 2
 palstate.need_update = YES
 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN ret = 3 : EXIT DO
  IF keyval(scF1) > 1 THEN show_help "frame_import16"
  IF keyval(scLeft) > 1 OR keyval(scLeftBrace) > 1 THEN
   changepal ss, -1
   palstate.need_update = YES
  END IF
  IF keyval(scRight) > 1 OR keyval(scRightBrace) > 1 THEN
   changepal ss, 1
   palstate.need_update = YES
  END IF
  IF usemenu(palstate) THEN palstate.need_update = YES
  IF enter_space_click(palstate) THEN ret = retval(palstate.pt) : EXIT DO

  IF palstate.need_update THEN
   palstate.need_update = NO
   spriteedit_import16_compare_palettes ss, pal16, palmapping(), can_remap, is_identical

   pmenu(0) = "Overwrite Current Palette"
   retval(0) = 0
   IF can_remap THEN
    pmenu(1) = "Remap into Current Palette"
    retval(1) = 1
   ELSE
    pmenu(1) = "Import Without Palette"
    retval(1) = 2
   END IF 
   pmenu(2) = "Cancel Import"
   retval(2) = 3

   IF palstate.pt = 1 AND can_remap = NO THEN
    'Preview import without palette
    usepal = ss.palette
   ELSE
    usepal = pal16
   END IF
  END IF

  clearpage dpage
  spriteedit_draw_sprite_area ss, impsprite, usepal, dpage

  'Draw palettes
  textcolor uilook(uiText), 0
  printstr bgcol_text(CHR(27), uilook(uiDisabledItem)) _
           & "Pal" & rlpad(STR(ss.pal_num), " ", 3, 4) _
           & bgcol_text(CHR(26), uilook(uiDisabledItem)), 243, 100, dpage, YES
  spriteedit_draw_palette ss.palette, 246, 109, dpage
  printstr "Image Pal", 245, 80, dpage
  spriteedit_draw_palette pal16, 246, 89, dpage

  rectangle 4, 144, 224, 32, uilook(uiDisabledItem), dpage
  standardmenu pmenu(), palstate, 8, 148, dpage
  edgeprint "(Press LEFT or RIGHT to select palette)", 0, 188, uilook(uiMenuItem), dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 RETURN ret
END FUNCTION

'state.pt is the current palette number
SUB spriteedit_import16(byref ss as SpriteEditState)
 DIM srcbmp as string
 STATIC default as string

 'Any BMP, any size
 srcbmp = browse(2, default, "*.bmp", "", , "browse_import_sprite")
 IF srcbmp = "" THEN EXIT SUB

 DIM as Frame ptr impsprite, impsprite2
 DIM pal16 as Palette16 ptr
 spriteedit_import16_loadbmp ss, srcbmp, impsprite, pal16
 IF impsprite = NULL THEN EXIT SUB
 'frame_export_bmp4 "debug0.bmp", impsprite, master(), pal16

 'Pick background color
 DIM bgcol as integer
 bgcol = spriteedit_import16_pick_bgcol(ss, impsprite, pal16)
 IF bgcol = -1 THEN  'cancelled
  frame_unload @impsprite
  palette16_unload @pal16
  EXIT SUB
 END IF

 IF ss.fullset THEN
  impsprite = spriteedit_import16_cut_frames(ss, impsprite, pal16, bgcol)
  IF impsprite = NULL THEN
   palette16_unload @pal16
   EXIT SUB
  END IF
 END IF

 'Swap the transparent pixels to 0
 frame_swap_colors impsprite, 0, bgcol
 SWAP pal16->col(0), pal16->col(bgcol)

 'Trim or expand the image to final dimensions (only for spritedit_import16_remap_menu)
 impsprite2 = frame_new(ss.wide, ss.high, , YES)
 frame_draw impsprite, NULL, 0, 0, , NO, impsprite2
 SWAP impsprite, impsprite2
 frame_unload @impsprite2
 'frame_export_bmp4 "debug1.bmp", impsprite, master(), pal16

 'Check whether pal16 can be mapped directly onto the existing palette
 '(ignoring background colours), and whether it's actually the same
 DIM can_remap as bool
 DIM is_identical as bool
 DIM palmapping(15) as integer
 spriteedit_import16_compare_palettes ss, pal16, palmapping(), can_remap, is_identical

 'Prompt about remapping palette
 DIM remap as integer
 IF is_identical THEN
  remap = 2
  debuginfo "spriteedit_import16: is identical"
 ELSE
  remap = spriteedit_import16_remap_menu(ss, impsprite, pal16, palmapping())
 END IF

 IF remap = 0 THEN
  'Overwrite current palette
  FOR i as integer = 0 TO 15
   ss.palette->col(i) = pal16->col(i)
  NEXT i
  'If the palette has changed, update genMaxPal
  gen(genMaxPal) = large(gen(genMaxPal), ss.pal_num)

 ELSEIF remap = 1 THEN
  'Remap into current palette
  FOR x as integer = 0 TO impsprite->w - 1
   FOR y as integer = 0 TO impsprite->h - 1
    DIM col as integer = palmapping(readpixel(impsprite, x, y))
    putpixel(impsprite, x, y, col)
   NEXT
  NEXT

 ELSEIF remap = 2 THEN
  'Import without palette

 ELSEIF remap = 3 THEN
  'Cancel Import
  frame_unload @impsprite
  palette16_unload @pal16
  EXIT SUB
 END IF

 'Set as sprite
 frame_assign @ss.sprite, frame_resized(impsprite, ss.wide, ss.high)

 frame_unload @impsprite
 palette16_unload @pal16
END SUB

' Part of ss should be filled in with the necessary arguments.
' sprite contains the sprite to be edited, and the result is passed back by calling ss.save_callback()
' before exiting, or whenever want to immediately save.
' Also, this expects the caller to save the default palette (ss.pal_num). However, it saves the palette (ss.palette) itself.
SUB sprite_editor(ss as SpriteEditState, sprite as Frame ptr)

 WITH ss
  .palette = palette16_load(.pal_num)
  .sprite = frame_duplicate(sprite)
  .delay = 10
  .zoom = large(1, small(240 \ ss.wide, 170 \ ss.high))
  .draw_area_offset = XY(0, 0)
  .x = 0
  .y = 0
  .lastpos.x = -1
  .lastpos.y = -1
  .zone.x = 0
  .zone.y = 0
  .hold = NO
  .gotmouse = havemouse()
  .didscroll = NO
  .drawcursor = 1
  .tool = ss_save.tool
  .airsize = ss_save.airsize
  .mist = ss_save.mist
  .palindex = ss_save.palindex
  .hidemouse = ss_save.hidemouse
  .previewpos.x = 319 - .wide
  .previewpos.y = 119

  v_new .undo_history
  .undodepth = 0
  .undomax = maxSpriteHistoryMem \ (sizeof(Frame) + .wide * .high)
 END WITH

 init_sprite_zones ss.area(), ss

 WITH ss.toolinfo(draw_tool)
  .name = "Draw"
  .icon = CHR(3)
  .shortcut = scD
  .cursor = 0
  .areanum = 6
 END WITH
 WITH ss.toolinfo(box_tool)
  .name = "Box"
  .icon = CHR(4)
  .shortcut = scB
  .cursor = 1
  .areanum = 7
 END WITH
 WITH ss.toolinfo(line_tool)
  .name = "Line"
  .icon = CHR(5)
  .shortcut = scL
  .cursor = 2
  .areanum = 8
 END WITH
 WITH ss.toolinfo(fill_tool)
  .name = "Fill"
  .icon = "F"
  .shortcut = scF
  .cursor = 3
  .areanum = 9
 END WITH
 WITH ss.toolinfo(oval_tool)
  .name = "Oval"
  .icon = "O"
  .shortcut = scO
  .cursor = 2
  .areanum = 11
 END WITH
 WITH ss.toolinfo(airbrush_tool)
  .name = "Air"
  .icon = "A"
  .shortcut = scA
  .cursor = 3
  .areanum = 21
 END WITH
 WITH ss.toolinfo(mark_tool)
  .name = "Mark"
  .icon = "M"
  .shortcut = scM
  .cursor = 2
  .areanum = 23
 END WITH
 WITH ss.toolinfo(clone_tool)
  .name = "Clone"
  .icon = "C"
  .shortcut = scC
  .cursor = 3
  .areanum = 24
 END WITH
 WITH ss.toolinfo(replace_tool)
  .name = "Replace"
  .icon = "R"
  .shortcut = scR
  .cursor = 3
  .areanum = 10
 END WITH
 WITH ss.toolinfo(scroll_tool)
  .name = "Scroll"
  .icon = "S"
  .shortcut = scS
  .cursor = 2
  .areanum = 22
 END WITH

 hidemousecursor
 setkeys
 DO
  setwait 17, 70
  setkeys
  IF ss.gotmouse THEN
   ss.mouse = readmouse
   ss.zonecursor = 0
   ss.zonenum = mouseover(ss.mouse.x, ss.mouse.y, ss.zone.x, ss.zone.y, ss.zonecursor, ss.area())
  END IF
  IF keyval(scESC) > 1 THEN
   IF ss.hold = YES THEN
    GOSUB resettool
   ELSE
    spriteedit_clip ss
    GOSUB resettool
    EXIT DO
   END IF
  END IF
  IF keyval(scF1) > 1 THEN show_help "sprite_editor"
  IF ss.delay = 0 THEN
   GOSUB sprctrl
  END IF
  ss.delay = large(ss.delay - 1, 0)
  spriteedit_display ss
  SWAP vpage, dpage
  setvispage vpage
  'blank the sprite area
  rectangle ss.previewpos.x, ss.previewpos.y, ss.wide, ss.high, 0, dpage
  ss.tick = 0
  IF dowait THEN
   ss.tick = 1
   ss.tog = ss.tog XOR 1
  END IF
 LOOP
 defaultmousecursor
 palette16_save ss.palette, ss.pal_num
 palette16_unload @ss.palette
 v_free ss.undo_history

 WITH ss_save
  .tool = ss.tool
  .airsize = ss.airsize
  .mist = ss.mist
  .palindex = ss.palindex
  .hidemouse = ss.hidemouse
 END WITH

 'Save the sprite before leaving
 spriteedit_clip ss
 ss.save_callback(ss.sprite, ss.save_callback_context)
EXIT SUB

sprctrl:
'Debug keys
IF keyval(scCtrl) > 0 AND keyval(sc3) > 1 THEN setvispage 3: waitforanykey
'Normal keys
IF ss.mouse.buttons = 0 AND keyval(scSpace) = 0 THEN
 ss.lastpos.x = -1
 ss.lastpos.y = -1
END IF
IF keyval(scTilde) > 1 THEN ss.hidemouse = ss.hidemouse XOR YES

' Changing the index in the 16 color palette
IF keyval(scComma) > 1 AND ss.palindex > 0 THEN
 ss.palindex -= 1
 ss.showcolnum = COLORNUM_SHOW_TICKS
END IF
IF keyval(scPeriod) > 1 AND ss.palindex < 15 THEN
 ss.palindex += 1
 ss.showcolnum = COLORNUM_SHOW_TICKS
END IF
IF ss.zonenum = 2 THEN
 IF ss.mouse.clicks > 0 THEN
  ss.palindex = small(ss.zone.x \ 4, 15)
  ss.showcolnum = COLORNUM_SHOW_TICKS
 END IF
END IF

' Changing to a different 16 color palette
IF keyval(scLeftBrace) > 1 OR (ss.zonenum = 5 AND ss.mouse.clicks > 0) THEN
 ' Previous palette
 changepal ss, -1
END IF
IF keyval(scRightBrace) > 1 OR (ss.zonenum = 6 AND ss.mouse.clicks > 0) THEN
 ' Next palette
 changepal ss, 1
END IF
IF keyval(scP) > 1 OR (ss.zonenum = 19 AND ss.mouse.clicks > 0) THEN '--call palette browser
 '--write changes so far
 ss.save_callback(ss.sprite, ss.save_callback_context)
 '--save current palette
 palette16_save ss.palette, ss.pal_num
 ss.pal_num = pal16browse(ss.pal_num, ss.fileset, ss.spriteset_num)
 clearkey(scEnter)
 clearkey(scSpace)
 palette16_unload @ss.palette
 ss.palette = palette16_load(ss.pal_num)
END IF
'If the palette has changed, update genMaxPal
gen(genMaxPal) = large(gen(genMaxPal), ss.pal_num)

'--UNDO
IF (keyval(scCtrl) > 0 AND keyval(scZ) > 1) OR (ss.zonenum = 20 AND ss.mouse.clicks > 0) THEN readundospr ss
'--REDO
IF (keyval(scCtrl) > 0 AND keyval(scY) > 1) OR (ss.zonenum = 21 AND ss.mouse.clicks > 0) THEN readredospr ss

'--COPY (CTRL+INS,SHIFT+DEL,CTRL+C)
IF copy_keychord() THEN
 frame_assign @ss_save.spriteclip, frame_duplicate(ss.sprite)
END IF
'--PASTE (SHIFT+INS,CTRL+V)
IF paste_keychord() AND ss_save.spriteclip <> NULL THEN
 writeundospr ss
 spriteedit_clip ss
 frame_draw ss_save.spriteclip, NULL, 0, 0, , NO, ss.sprite
END IF
'--TRANSPARENT PASTE (CTRL+T)
IF (keyval(scCtrl) > 0 AND keyval(scT) > 1) AND ss_save.spriteclip <> NULL THEN
 writeundospr ss
 spriteedit_clip ss
 frame_draw ss_save.spriteclip, NULL, 0, 0, , YES, ss.sprite
END IF

'--COPY PALETTE (ALT+C)
IF keyval(scAlt) > 0 AND keyval(scC) > 1 THEN
 palette16_unload @ss_save.pal_clipboard
 ss_save.pal_clipboard = palette16_duplicate(ss.palette)
END IF
'--PASTE PALETTE (ALT+V)
IF keyval(scAlt) > 0 AND keyval(scV) > 1 THEN
 IF ss_save.pal_clipboard THEN
  palette16_unload @ss.palette
  ss.palette = palette16_duplicate(ss_save.pal_clipboard)
 END IF
END IF

' Change master palette index for the selected palette color
ss.curcolor = ss.palette->col(ss.palindex)
IF keyval(scAlt) > 0 THEN
 IF keyval(scUp) > 1 AND ss.curcolor > 15 THEN ss.curcolor -= 16 : ss.showcolnum = COLORNUM_SHOW_TICKS
 IF keyval(scDown) > 1 AND ss.curcolor < 240 THEN ss.curcolor += 16 : ss.showcolnum = COLORNUM_SHOW_TICKS
 IF keyval(scLeft) > 1 AND ss.curcolor > 0 THEN ss.curcolor -= 1 : ss.showcolnum = COLORNUM_SHOW_TICKS
 IF keyval(scRight) > 1 AND ss.curcolor < 255 THEN ss.curcolor += 1 : ss.showcolnum = COLORNUM_SHOW_TICKS
END IF
IF (ss.mouse.clicks AND mouseLeft) ANDALSO ss.zonenum = 3 THEN
 ss.curcolor = ((ss.zone.y \ 6) * 16) + (ss.zone.x \ 4)
 ss.showcolnum = COLORNUM_SHOW_TICKS
END IF
ss.palette->col(ss.palindex) = ss.curcolor

' Change brush position
IF keyval(scAlt) = 0 THEN
 DIM fixmouse as integer = NO
 WITH ss
  fixmouse = NO
  IF slowkey(scUp, 100) THEN .y = large(0, .y - 1):      fixmouse = YES
  IF slowkey(scDown, 100) THEN .y = small(.high - 1, .y + 1): fixmouse = YES
  IF slowkey(scLeft, 100) THEN .x = large(0, .x - 1):      fixmouse = YES
  IF slowkey(scRight, 100) THEN .x = small(.wide - 1, .x + 1): fixmouse = YES
 END WITH
 IF fixmouse THEN
  IF ss.zonenum = 1 THEN
   ss.zone.x = ss.x * ss.zoom + (ss.zoom \ 2)
   ss.zone.y = ss.y * ss.zoom + (ss.zoom \ 2)
   ss.mouse.x = ss.area(0).x + ss.zone.x 
   ss.mouse.y = ss.area(0).y + ss.zone.y
   movemouse ss.mouse.x, ss.mouse.y
  END IF 
  IF ss.zonenum = 14 THEN
   ss.zone.x = ss.x
   ss.zone.y = ss.y
   ss.mouse.x = ss.area(13).x + ss.zone.x 
   ss.mouse.y = ss.area(13).y + ss.zone.y
   movemouse ss.mouse.x, ss.mouse.y
  END IF
 END IF
END IF
' Mouse over main sprite view
IF ss.zonenum = 1 THEN
 ss.x = ss.zone.x \ ss.zoom
 ss.y = ss.zone.y \ ss.zoom
END IF

IF ss.tool = airbrush_tool THEN '--adjust airbrush
 IF ss.mouse.buttons AND mouseLeft THEN
  IF ss.zonenum = 15 THEN ss.airsize = large(ss.airsize - ss.tick, 1)
  IF ss.zonenum = 17 THEN ss.airsize = small(ss.airsize + ss.tick, 80)
  IF ss.zonenum = 16 THEN ss.mist = large(ss.mist - ss.tick, 1)
  IF ss.zonenum = 18 THEN ss.mist = small(ss.mist + ss.tick, 99)
 END IF
 IF keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1 THEN
  IF keyval(scCtrl) > 0 THEN
   ss.mist = large(ss.mist - 1, 1)
  ELSE
   ss.airsize = large(ss.airsize - 1, 1)
  END IF
 END IF
 IF keyval(scPlus) > 1 OR keyval(scNumpadPlus) > 1 THEN
  IF keyval(scCtrl) > 0 THEN
   ss.mist = small(ss.mist + 1, 99)
  ELSE
   ss.airsize = small(ss.airsize + 1, 80)
  END IF
 END IF
END IF
IF ss.tool = clone_tool THEN
 '--When clone tool is active, rotate the clone buffer
 IF ss.mouse.buttons AND mouseLeft THEN
  IF ss_save.clone_brush THEN
   IF ss.zonenum = 16 THEN
    frame_assign @ss_save.clone_brush, frame_rotated_90(ss_save.clone_brush)  'anticlockwise
    ss.delay = 20
   END IF
   IF ss.zonenum = 18 THEN
    frame_assign @ss_save.clone_brush, frame_rotated_270(ss_save.clone_brush)  'clockwise
    ss.delay = 20
   END IF
  END IF
 END IF
ELSEIF ss.tool <> airbrush_tool THEN
 '--when other tools are active, rotate the whole buffer
 '--except for the airbrush tool because it's buttons collide.
 IF ss.mouse.buttons AND mouseLeft THEN
  IF ss.zonenum = 16 THEN
   spriteedit_edit ss, frame_rotated_90(ss.sprite)  'anticlockwise
   ss.delay = 20
  END IF
  IF ss.zonenum = 18 THEN
   spriteedit_edit ss, frame_rotated_270(ss.sprite)  'clockwise
   ss.delay = 20
  END IF
 END IF
END IF

' Mouse over thumbnail view
IF ss.zonenum = 14 THEN
 ss.x = ss.zone.x
 ss.y = ss.zone.y
END IF

IF ((ss.zonenum = 1 OR ss.zonenum = 14) ANDALSO (ss.mouse.buttons AND mouseLeft)) OR keyval(scSpace) > 0 THEN
 SELECT CASE ss.tool
  CASE draw_tool
   GOSUB putdot
  CASE box_tool
   IF ss.mouse.clicks > 0 OR keyval(scSpace) > 1 THEN
    IF ss.hold THEN
     ss.hold = NO: GOSUB drawsquare
    ELSE
     ss.hold = YES
     ss.holdpos.x = ss.x
     ss.holdpos.y = ss.y
    END IF
   END IF
  CASE line_tool
   IF ss.mouse.clicks > 0 OR keyval(scSpace) > 1 THEN
    IF ss.hold = YES THEN
     ss.hold = NO
     GOSUB straitline
    ELSE
     ss.hold = YES
     ss.holdpos.x = ss.x
     ss.holdpos.y = ss.y
    END IF
   END IF
  CASE fill_tool
   IF ss.mouse.clicks > 0 OR keyval(scSpace) > 1 THEN
    GOSUB floodfill
   END IF
  CASE replace_tool
   IF ss.mouse.clicks > 0 OR keyval(scSpace) > 1 THEN
    GOSUB replacecol
   END IF
  CASE oval_tool
   IF ss.mouse.clicks > 0 OR keyval(scSpace) > 1 THEN
    IF ss.hold = NO THEN
     '--start oval
     ss.holdpos.x = ss.x
     ss.holdpos.y = ss.y
     ss.ellip_angle = 0.0
     ss.ellip_minoraxis = 0.0
     ss.radius = 0.0
     ss.hold = YES
    ELSE
     GOSUB drawoval
     ss.hold = NO
    END IF
   END IF
  CASE airbrush_tool
   GOSUB sprayspot
  CASE mark_tool
   IF ss.mouse.clicks > 0 OR keyval(scSpace) > 1 THEN
    IF ss.hold THEN
     ss.hold = NO
     frame_assign @ss_save.clone_brush, frame_resized(ss.sprite, ABS(ss.x - ss.holdpos.x) + 1, ABS(ss.y - ss.holdpos.y) + 1, -small(ss.x, ss.holdpos.x), -small(ss.y, ss.holdpos.y))
     ss_save.clonepos.x = ss_save.clone_brush->w \ 2
     ss_save.clonepos.y = ss_save.clone_brush->h \ 2
     ss.tool = clone_tool ' auto-select the clone tool after marking
    ELSE
     ss.hold = YES
     ss.holdpos.x = ss.x
     ss.holdpos.y = ss.y
    END IF
   END IF
  CASE clone_tool
   IF ss.mouse.clicks > 0 OR keyval(scSpace) > 1 THEN
    IF ss_save.clone_brush THEN
     IF ss.lastpos.x = -1 AND ss.lastpos.y = -1 THEN
      writeundospr ss
     END IF
     spriteedit_clip ss
     frame_draw ss_save.clone_brush, , ss.x - ss_save.clonepos.x, ss.y - ss_save.clonepos.y, , , ss.sprite
     ss.lastpos.x = ss.x
     ss.lastpos.y = ss.y
    ELSE
     ss.tool = mark_tool ' select selection tool if clone is not available
     ss.hold = YES
     ss.holdpos.x = ss.x
     ss.holdpos.y = ss.y
    END IF
   END IF
 END SELECT
END IF
IF ss.hold = YES AND ss.tool = oval_tool THEN
 ss.radius = SQR((ss.x - ss.holdpos.x)^2 + (ss.y - ss.holdpos.y)^2)
 IF ss.zonenum = 1 THEN
  'Use mouse pointer instead of draw cursor for finer grain control of radius
  ss.radius = SQR( (ss.holdpos.x + 0.5 - ss.zone.x / ss.zoom)^2 + (ss.holdpos.y + 0.5 - ss.zone.y / ss.zoom)^2 )
 END IF
END IF
FOR i as integer = 0 TO UBOUND(ss.toolinfo)
 'Check tool selection
 'Alt is used for alt+c and alt+v
 IF (ss.mouse.clicks > 0 AND ss.zonenum = ss.toolinfo(i).areanum + 1) OR _
    (keyval(scAlt) = 0 AND keyval(scCtrl) = 0 AND keyval(ss.toolinfo(i).shortcut) > 1) THEN
  IF ss.tool <> i THEN ss.didscroll = NO
  ss.tool = i
  GOSUB resettool
  ss.drawcursor = ss.toolinfo(i).cursor + 1
 END IF
NEXT i
IF ss.tool <> airbrush_tool THEN
 ' Change zoom, unless adjusting airbrush size
 IF keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1 THEN spriteedit_increment_zoom ss, -1
 IF keyval(scPlus) > 1 OR keyval(scNumpadPlus) > 1 THEN spriteedit_increment_zoom ss, 1
END IF
IF ss.tool <> clone_tool THEN
 IF keyval(scRightCaret) > 1 AND keyval(scShift) > 0 THEN
  spriteedit_edit ss, frame_rotated_270(ss.sprite)  'clockwise
 END IF
 IF keyval(scLeftCaret) > 1 AND keyval(scShift) > 0 THEN
  spriteedit_edit ss, frame_rotated_90(ss.sprite)  'anticlockwise
 END IF
END IF
IF ss.tool = clone_tool THEN
 ' For clone brush tool, enter/right-click moves the handle point
 IF ss.readjust THEN
  IF keyval(scEnter) = 0 AND ss.mouse.buttons = 0 THEN ' click or key release
   ss.readjust = NO
   ss_save.clonepos.x += (ss.x - ss.adjustpos.x)
   ss_save.clonepos.y += (ss.y - ss.adjustpos.y)
   ss.adjustpos.x = 0
   ss.adjustpos.y = 0
  END IF
 ELSE
  IF (keyval(scEnter) AND 5) OR ss.mouse.buttons = mouseRight THEN
   ss.readjust = YES
   ss.adjustpos.x = ss.x
   ss.adjustpos.y = ss.y
  END IF
 END IF
 ' clone buffer rotation
 IF ss_save.clone_brush THEN
  IF keyval(scPlus) > 1 THEN
   frame_assign @ss_save.clone_brush, frame_rotated_270(ss_save.clone_brush)  'clockwise
  END IF
  IF keyval(scMinus) > 1 THEN
   frame_assign @ss_save.clone_brush, frame_rotated_90(ss_save.clone_brush)  'anticlockwise
  END IF
 END IF
ELSE
 ' For all other tools, pick a color
 IF keyval(scEnter) > 1 ORELSE keyval(scG) > 1 ORELSE (ss.zonenum = 1 AND ss.mouse.buttons = mouseRight) THEN
  ss.palindex = readpixel(ss.sprite, ss.x, ss.y)
  ss.showcolnum = COLORNUM_SHOW_TICKS
 END IF
END IF
IF keyval(scBackspace) > 1 OR (ss.zonenum = 4 AND ss.mouse.clicks > 0) THEN
 writeundospr ss
 frame_flip_horiz ss.sprite
END IF
IF ss.tool = scroll_tool AND (ss.zonenum = 1 OR ss.zonenum = 14) THEN
 'Handle scrolling by dragging the mouse
 'Did this drag start inside the sprite box? If not, ignore
 IF ss.mouse.dragging ANDALSO mouseover(ss.mouse.clickstart.x, ss.mouse.clickstart.y, 0, 0, 0, ss.area()) = ss.zonenum THEN
  spriteedit_scroll ss, ss.x - ss.lastcpos.x, ss.y - ss.lastcpos.y
 END IF
END IF
IF ss.tool = scroll_tool AND keyval(scAlt) = 0 THEN
 DIM scrolloff as XYPair
 IF slowkey(scLeft, 100) THEN scrolloff.x = -1
 IF slowkey(scRight, 100) THEN scrolloff.x = 1
 IF slowkey(scUp, 100) THEN scrolloff.y = -1
 IF slowkey(scDown, 100) THEN scrolloff.y = 1
 spriteedit_scroll ss, scrolloff.x, scrolloff.y
END IF
IF keyval(scI) > 1 OR (ss.zonenum = 13 AND ss.mouse.clicks > 0) THEN
 spriteedit_import16 ss
END IF
IF keyval(scE) > 1 OR (ss.zonenum = 26 AND ss.mouse.clicks > 0) THEN
 palette16_save ss.palette, ss.pal_num  'Save palette in case it has changed
 spriteedit_export ss.default_export_filename, ss.sprite, ss.palette
END IF
ss.lastcpos = TYPE(ss.x, ss.y)
RETRACE

resettool:
ss.hold = NO
ss.readjust = NO
ss.adjustpos.x = 0
ss.adjustpos.y = 0
RETRACE

floodfill:
writeundospr ss
spriteedit_clip ss
paintat ss.sprite, ss.x, ss.y, ss.palindex
RETRACE

replacecol:
writeundospr ss
spriteedit_clip ss
replacecolor ss.sprite, readpixel(ss.sprite, ss.x, ss.y), ss.palindex
RETRACE

sprayspot:
IF ss.lastpos.x = -1 AND ss.lastpos.y = -1 THEN writeundospr ss
spriteedit_clip ss
airbrush ss.sprite, ss.x, ss.y, ss.airsize, ss.mist, ss.palindex
ss.lastpos.x = ss.x
ss.lastpos.y = ss.y
RETRACE

putdot:
IF ss.lastpos.x = -1 AND ss.lastpos.y = -1 THEN
 writeundospr ss
 spriteedit_clip ss
 putpixel ss.sprite, ss.x, ss.y, ss.palindex
ELSE
 drawline ss.sprite, ss.x, ss.y, ss.lastpos.x, ss.lastpos.y, ss.palindex
END IF
ss.lastpos.x = ss.x
ss.lastpos.y = ss.y
RETRACE

drawoval:
writeundospr ss
spriteedit_clip ss
ellipse ss.sprite, ss.holdpos.x, ss.holdpos.y, ss.radius, ss.palindex, , ss.ellip_minoraxis, ss.ellip_angle
RETRACE

drawsquare:
writeundospr ss
spriteedit_clip ss
rectangle ss.sprite, small(ss.x, ss.holdpos.x), small(ss.y, ss.holdpos.y), ABS(ss.x - ss.holdpos.x) + 1, ABS(ss.y - ss.holdpos.y) + 1, ss.palindex
RETRACE

straitline:
writeundospr ss
spriteedit_clip ss
drawline ss.sprite, ss.x, .ss.y, ss.holdpos.x, ss.holdpos.y, ss.palindex
RETRACE
END SUB

SUB spriteedit_increment_zoom (ss as SpriteEditState, amount as integer)
 ss.zoom = bound(ss.zoom + amount, 1, 8)
 init_sprite_zones ss.area(), ss
END SUB

SUB spriteedit_scroll (ss as SpriteEditState, byval shiftx as integer, byval shifty as integer)
 'Save an undo before the first of a consecutive scrolls
 IF shiftx = 0 AND shifty = 0 THEN EXIT SUB
 IF ss.didscroll = NO THEN writeundospr ss
 ss.didscroll = YES

 frame_assign @ss.sprite, frame_resized(ss.sprite, ss.wide, ss.high, shiftx, shifty)
END SUB


'==========================================================================================
'                                   New Spriteset Editor
'==========================================================================================

DECLARE SUB edit_animation(sprset as SpriteSet ptr, anim_name as string, pal as Palette16 ptr)

TYPE SpriteSetEditor
 ss as SpriteSet ptr
 anim_preview as SpriteState ptr
 pal as Palette16 ptr
 tog as integer

 DECLARE SUB display()
 DECLARE SUB run()
 DECLARE SUB export_menu()
 DECLARE SUB export_gif(fname as string, anim as string, transparent as bool = NO)
END TYPE

SUB new_spriteset_editor()
 DIM editor as SpriteSetEditor
 editor.run()
END SUB

SUB SpriteSetEditor.run()
 ss = spriteset_load(sprTypeHero, 1)
 anim_preview = NEW SpriteState(ss)
 pal = palette16_load(-1, sprTypeHero, 1)

 setkeys
 DO
  setwait 55
  setkeys
  tog XOR= 1
  anim_preview->animate()

  IF keyval(scEsc) > 1 THEN EXIT DO

  IF keyval(scI) > 1 THEN anim_preview->start_animation("idle")
  IF keyval(scA) > 1 THEN anim_preview->start_animation("attack")
  IF keyval(scW) > 1 THEN anim_preview->start_animation("walk left")

  IF keyval(scE) > 1 THEN edit_animation(ss, "attack", pal)
  IF keyval(scX) > 1 THEN export_menu()
   
  display()
  dowait
 LOOP
 spriteset_unload @ss
 palette16_unload @pal
 DELETE anim_preview
END SUB

SUB SpriteSetEditor.display()
 clearpage vpage

 DIM caption as string = "(I)dle, (A)ttack, (W)alk  (E)dit, e(X)port"
 printstr caption, pRight, pBottom, vpage

 DIM as integer x, y
 FOR idx as integer = 0 to ss->num_frames - 1
  frame_draw @ss->frames[idx], pal, x, y, , , vpage
  x += ss->frames[idx].w
 NEXT

 frame_draw anim_preview->cur_frame(), pal, 0, 100, , , vpage

 '--screen update
 setvispage vpage
END SUB

' Very unfinished
SUB SpriteSetEditor.export_menu()
 DIM choices(...) as string = { _
  "Current frame", "Spritesheet (unimplemented)", _
  "Animated .gif", "Transparent animated .gif" _
 }
 DIM choice as integer = multichoice("Export what?", choices())
 IF choice = 0 THEN
  frame_export_gif @ss->frames[0], "hero0.gif", master(), pal
 ELSEIF choice = 1 THEN
 ELSEIF choice = 2 THEN
  export_gif "hero.gif", "walk left"
 ELSEIF choice = 3 THEN
  export_gif "herotrans.gif", "walk left", YES
 END IF
END SUB

' Export a certain animation as a looping gif
SUB SpriteSetEditor.export_gif(fname as string, anim_name as string, transparent as bool = NO)
  DIM writer as GifWriter
  DIM gifpal as GifPalette
  GifPalette_from_pal gifpal, master(), pal
  DIM outsize as XYPair = (ss->frames[0].w, ss->frames[0].h)

  IF GifBegin(@writer, fopen(fname, "wb"), outsize.w, outsize.h, 1, transparent, @gifpal) = NO THEN
    debug "GifWriter(" & fname & ") failed"
    safekill fname
  END IF

  CONST frameTime as integer = 5  'In hundreds of a second
  DIM sprst as SpriteState ptr
  sprst = NEW SpriteState(ss)
  sprst->start_animation(anim_name, 1)  'Loop once

  ' FIXME: if animations contain loops other than repeating, this could loop forever
  WHILE sprst->anim
    sprst->animate()
    DIM fr as Frame ptr = sprst->cur_frame()
    DIM waitticks as integer = sprst->skip_wait()
    IF waitticks > 0 THEN
      IF GifWriteFrame8(@writer, fr->image, fr->w, fr->h, waitticks * frameTime, NULL) = NO THEN
        debug "GifWriteFrame8 failed"
        safekill fname
        DELETE sprst
      END IF
    END IF
  WEND

  IF GifEnd(@writer) = NO then
    debug "GifEnd failed"
  END IF
  DELETE sprst
END SUB

'==========================================================================================
'                                     Animation Editor
'==========================================================================================
' Highly unfinished.
' This is separate from the spriteset editor because it's also used by the backdrop editor

TYPE AnimationEditState
  animptr as Animation ptr
  sprset as SpriteSet ptr
  state as MenuState
  anim_name as string
  pal as Palette16 ptr

  DECLARE SUB run()
END TYPE

'SUB additem(byref menu as SimpleMenuItem vector, caption as string)
 'append_simplemenu_item
'END SUB

SUB rebuild_animation_menu(byref menu as SimpleMenuItem vector, anim as Animation)
 v_new menu
 FOR i as integer = 0 TO UBOUND(anim.ops)
  WITH anim.ops(i)
   DIM caption as string
   SELECT CASE .type
    CASE animOpWait
     caption = ms_to_frames(.arg1) & " frame(s) (" & FORMAT(0.001 * .arg1, "0.000") & "sec)"
    CASE animOpWaitMS
     caption = FORMAT(0.001 * .arg1, "0.000") & "sec (" & ms_to_frames(.arg1) & " frame(s))"
    CASE animOpRepeat
     'pass
    CASE ELSE
     caption = STR(.arg1)   '& " " & .arg2
   END SELECT
   append_simplemenu_item menu, anim_op_names(.type) & " " & caption
  END WITH
 NEXT
 append_simplemenu_item menu, "-" + fgcol_text(": Delete step", uilook(uiSelectedDisabled))
 append_simplemenu_item menu, "+" + fgcol_text(": Add step", uilook(uiSelectedDisabled))

 'menu(0) = "Frame 5  wait 1 tick (0.055sec)"
 'menu(1) = "Repeat animation"
END SUB

SUB edit_animation(sprset as SpriteSet ptr, anim_name as string, pal as Palette16 ptr)
 DIM editor as AnimationEditState
 editor.sprset = sprset
 editor.pal = pal
 editor.anim_name = anim_name
 editor.run()
END SUB

SUB AnimationEditState.run()
 set_animation_framerate gen(genMillisecPerFrame)

 DIM BYREF anim as Animation = *sprset->find_animation(anim_name)
 IF @anim = NULL THEN
  visible_debug "Animation Editor: animation " & anim_name & " doesn't exit"
  EXIT SUB
 END IF

 DIM menu as SimpleMenuItem vector
 rebuild_animation_menu menu, anim

 state.last = v_len(menu) - 1
 DIM menuopts as MenuOptions
 menuopts.wide = 80  ' Minimum width
 menuopts.calc_size = YES
 DIM mpos as XYPair = (4,4)

 'Precompute the menu size
 calc_menustate_size state, menuopts, mpos.x, mpos.y, vpage, cast(BasicMenuItem vector, menu)

 DIM sprst as SpriteState ptr
 sprst = NEW SpriteState(sprset)

 DIM animating as bool = NO  'Current mode: whether playing the animation, or editing it
 DIM framenum as integer = 0

 DO
  setwait 55
  setkeys

  DIM curop as AnimationOp ptr = NULL


  IF animating THEN

   sprst->animate()
   framenum = sprst->frame_num
   IF sprst->anim = NULL THEN
    animating = NO
    state.pt = 0
   ELSE
    state.pt = sprst->anim_step
   END IF

   IF keyval(scEsc) > 1 or keyval(scP) > 1 THEN
    animating = NO
   END IF

  ELSE
   IF keyval(scShift) = 0 THEN
    usemenu state, cast(BasicMenuItem ptr, menu)
   END IF
   DIM op_idx as integer = -1
   IF state.pt <= UBOUND(anim.ops) THEN op_idx = state.pt
   IF op_idx > -1 THEN curop = @anim.ops(op_idx)

   IF keyval(scEsc) > 1 THEN EXIT DO

   IF keyval(scPlus) > 1 OR keyval(scNumpadPlus) > 1 THEN
    DIM newtype as AnimOpType
    newtype = multichoice("Which operator?", anim_op_fullnames(), , , "animation_ops")
    IF newtype >= 0 THEN
     DIM newidx as integer = UBOUND(anim.ops) + 1
     REDIM PRESERVE anim.ops(newidx)
     anim.ops(newidx).type = newtype
     curop = NULL
    END IF
   ELSEIF keyval(scDelete) > 1 OR keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1 THEN
    IF curop THEN
     any_array_remove(anim.ops, op_idx)  'macro
    ELSEIF UBOUND(anim.ops) > 0 THEN
     REDIM PRESERVE anim.ops(UBOUND(anim.ops) - 1)
    END IF
    curop = NULL
   ELSEIF keyval(scP) > 1 THEN  'Play
    sprst->start_animation(anim_name)
    animating = YES
   ELSEIF keyval(scShift) > 0 AND op_idx >= 0 THEN
    ' Rearranging items
    IF keyval(scUp) > 1 AND op_idx > 0 THEN
     SWAP anim.ops(op_idx), anim.ops(op_idx - 1)
     state.pt -= 1
    ELSEIF keyval(scDown) > 1 AND op_idx < UBOUND(anim.ops) THEN
     SWAP anim.ops(op_idx), anim.ops(op_idx + 1)
     state.pt += 1
    END IF
    op_idx = state.pt
    curop = @anim.ops(op_idx)
   END IF

   IF curop THEN
    SELECT CASE curop->type
    CASE animOpWait
     ' arg1 is in ms, but change number of frames
     DIM frames as integer = ms_to_frames(curop->arg1)
     IF intgrabber(frames, 0, 9999) THEN
      curop->arg1 = frames_to_ms(frames)
     END IF
     IF keyval(scTab) > 1 THEN curop->type = animOpWaitMS
    CASE animOpWaitMS
     intgrabber curop->arg1, 0, 9999
     IF keyval(scTab) > 1 THEN curop->type = animOpWait
    CASE animOpFrame
     intgrabber curop->arg1, 0, sprset->num_frames - 1
     framenum = curop->arg1  ' Update visual
    CASE ELSE
     intgrabber curop->arg1, -9999, 9999
    END SELECT
   END IF

   rebuild_animation_menu menu, anim
   state.last = v_len(menu) - 1
  END IF

  ' Draw screen
  clearpage vpage
  draw_background vpages(vpage), bgChequer
  frame_draw @sprset->frames[framenum], pal, pCentered, pBottom - 30, , , vpage

  WITH state.rect
   fuzzyrect vpages(vpage), .x, .y, .wide, .high, uilook(uiBackground)
  END WITH
  standardmenu cast(BasicMenuItem vector, menu), state, mpos.x, mpos.y, vpage, menuopts

  DIM message as string = IIF(animating, "P/ESC to Stop", "(P)lay")
  IF curop THEN
   ' IF the op has multiple editable fields
   IF curop->type = animOpWait OR curop->type = animOpWaitMS THEN message += "  TAB to select arg"
  END IF
  edgeprint message, pLeft, pBottom, uilook(uiText), vpage
  setvispage vpage
  dowait
 LOOP
 v_free menu

 set_animation_framerate 55  'Most of Custom runs at this framerate
END SUB