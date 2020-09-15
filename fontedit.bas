'OHRRPGCE - Font editor
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs

#include "config.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "const.bi"
#include "cglobals.bi"
#include "custom.bi"
#include "customsubs.bi"


'Subs and functions only used here
DECLARE SUB font_glyph_editor (fnt() as integer)
DECLARE FUNCTION edit_font_picker_point(byval pixelpos as XYPair) as integer
DECLARE FUNCTION edit_font_draw_point(byval pixelpos as XYPair) as XYPair
DECLARE SUB fontedit_export_font(fnt() as integer)
DECLARE SUB fontedit_import_font(fnt() as integer)



SUB font_test_menu
 DIM menu(...) as string = {"Font 0", "Font 1", "Font 2", "Font 3"}
 DIM st as MenuState
 st.last = UBOUND(menu)
 st.size = 22

 DIM controls as string = "1: import from 'fonttests/testfont/', 2: import from bmp, 3: create edged font, 4: create shadow font"

 DO
  setwait 55
  setkeys
  IF keyval(ccCancel) > 1 THEN EXIT DO
  IF keyval(sc1) > 1 THEN
   DIM fallback as Font ptr = fonts(st.pt)
   IF fallback = 0 THEN fallback = fonts(0)
   DIM newfont as Font ptr = font_loadbmps("fonttests/testfont", fallback)
   font_unload @fonts(st.pt)
   fonts(st.pt) = newfont
  END IF
  IF keyval(sc2) > 1 THEN
   DIM filen as string
   filen = browse(browsePalettedImage, "")
   IF LEN(filen) THEN
    font_unload @fonts(st.pt)
    fonts(st.pt) = font_load_16x16(filen)
   END IF
  END IF
  IF keyval(sc3) > 1 THEN
   DIM choice as integer
   choice = multichoice("Create an edged font from which font?", menu())
   IF choice > -1 THEN
    DIM newfont as Font ptr = font_create_edged(fonts(choice))
    font_unload @fonts(st.pt)
    fonts(st.pt) = newfont
   END IF
  END IF
  IF keyval(sc4) > 1 THEN
   DIM choice as integer
   choice = multichoice("Create a drop-shadow font from which font?", menu())
   IF choice > -1 THEN
    DIM newfont as Font ptr = font_create_shadowed(fonts(choice), 2, 2)
    font_unload @fonts(st.pt)
    fonts(st.pt) = newfont
   END IF
  END IF

  usemenu st

  clearpage vpage, findrgb(80,80,80)
  'edgeboxstyle 10, 10, 300, 185, 0, vpage
  standardmenu menu(), st, 0, 0, vpage
  textcolor uilook(uiText), 0
  wrapprint controls, 0, rBottom + ancBottom, , vpage

  FOR i as integer = 0 TO 15
   DIM row as string
   FOR j as integer = i * 16 TO i * 16 + 15
    row &= CHR(j)
   NEXT
   IF fonts(st.pt) THEN
    printstr row, 145, 0 + i * fonts(st.pt)->line_h, vpage, YES, st.pt
   END IF
  NEXT

  setvispage vpage
  dowait
 LOOP
END SUB

'Top-level menu
SUB font_editor ()
 DIM fnt() as integer
 load_font fnt()

 DIM fonttype as fontTypeEnum = get_font_type(fnt())

 DIM menu(6) as string
 DIM selectable(6) as bool
 flusharray selectable(), , YES

 'This state is used for the menu, not the charpicker
 DIM state as MenuState
 WITH state
  .pt = 0
  .top = 0
  .last = UBOUND(menu)
  .size = 22
 END WITH

 menu(0) = "Previous Menu"
 menu(1) = "Edit Font..."
 menu(2) = "Import Font..."
 menu(3) = "Export Font..."
 selectable(4) = NO
 menu(5) = ""  'Set below
 selectable(6) = NO

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scF1) > 1 THEN show_help "fontedit"

  IF keyval(ccCancel) > 1 THEN EXIT DO
  usemenu state, selectable()
  IF enter_space_click(state) THEN
   IF state.pt = 0 THEN EXIT DO
   IF state.pt = 1 THEN
    font_glyph_editor fnt()
    readmouse.clearclick(mouseLeft)
   END IF
   IF state.pt = 2 THEN
    fontedit_import_font fnt()
    fonttype = get_font_type(fnt())
    state.pt = 1
    font_glyph_editor fnt()
   END IF
   IF state.pt = 3 THEN fontedit_export_font fnt()
  END IF
  IF state.pt = 5 THEN
   IF intgrabber(fonttype, ftypeASCII, ftypeLatin1) THEN
    set_font_type fnt(), fonttype
    save_font fnt()
   END IF
  END IF

  '--Draw screen
  clearpage dpage

  menu(5) = "Font type: "
  IF fonttype = ftypeASCII THEN
   menu(5) &= "ASCII"
   menu(6) = " (Characters 127-255 are icons)"
  ELSEIF fonttype = ftypeLatin1 THEN
   menu(5) &= "Latin1"
   menu(6) = " (Characters 127-160 are icons)"
  END IF

  standardmenu menu(), state, 0, 0, dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

END SUB

'Editor for drawing a font
LOCAL SUB font_glyph_editor (fnt() as integer)
 DIM menu(0) as string
 menu(0) = "Previous Menu"  'Only one textual menu item
 DIM tog as integer

 DIM f(255) as integer  'Contains the character indices which should be shown (always 32-255)
 DIM copybuf(4) as integer

 DIM i as integer

 DIM last as integer = -1
 FOR i = 32 TO 255
  last += 1
  f(last) = i
 NEXT i

 'Whether we're editing a character. If NO, selecting a character to edit
 DIM editing_char as bool = NO

 DIM linesize as integer = 14
 DIM pt as integer = -1 * linesize

 DIM x as integer
 DIM y as integer
 
 DIM xoff as integer
 DIM yoff as integer
 
 DIM c as integer
 DIM hover_char as integer
 DIM hover_draw as XYPair
 DIM drawcol as integer   'The "color" (0 or 1) of the current stroke

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scF1) > 1 THEN show_help "fontedit_draw"
  hover_char = edit_font_picker_point(readmouse.pos)
  hover_draw = edit_font_draw_point(readmouse.pos)
  IF editing_char = NO THEN 'Picking a character to edit
   IF keyval(ccCancel) > 1 THEN EXIT DO 'mode = -1
   IF keyval(ccUp) > 1 THEN pt = large(pt - linesize, -1 * linesize)
   IF keyval(ccDown) > 1 THEN pt = small(pt + linesize, last)
   IF keyval(ccLeft) > 1 THEN pt = large(pt - 1, 0)
   IF keyval(ccRight) > 1 THEN pt = small(pt + 1, last)
   IF enter_or_space() THEN
    IF pt < 0 THEN
     EXIT DO
    ELSE
     editing_char = YES
     x = 0
     y = 0
    END IF
   END IF
  ELSE ' Editing a character
   IF keyval(ccCancel) > 1 OR keyval(scAnyEnter) > 1 THEN
    editing_char = NO
    save_font fnt()
   END IF
   IF keyval(ccUp) > 1 THEN loopvar y, 0, 7, -1
   IF keyval(ccDown) > 1 THEN loopvar y, 0, 7, 1
   IF keyval(ccLeft) > 1 THEN loopvar x, 0, 7, -1
   IF keyval(ccRight) > 1 THEN loopvar x, 0, 7, 1
   IF keyval(scSpace) > 0 THEN  'Only Space, Enter leaves edit mode
    'On a new keypress, determine whether to add or subtract pixels
    IF keyval(scSpace) AND 4 THEN drawcol = (readbit(fnt(), 0, (f(pt) * 8 + x) * 8 + y) XOR 1)
    setbit fnt(), 0, (f(pt) * 8 + x) * 8 + y, drawcol
    setfont fnt()
   END IF
  END IF

  IF keyval(scCtrl) > 0 ANDALSO keyval(scS) > 1 THEN
   save_font fnt()
   show_overlay_message "Saved.", 0.5
  END IF

  '--copy and paste support
  IF copy_keychord() THEN
   FOR i = 0 TO 63
    setbit copybuf(), 0, i, readbit(fnt(), 0, f(pt) * 64 + i)
   NEXT i
  END IF
  IF paste_keychord() THEN
   FOR i = 0 TO 63
    setbit fnt(), 0, f(pt) * 64 + i, readbit(copybuf(), 0, i)
   NEXT i
   setfont fnt()
   save_font fnt()
  END IF
  '--clicking on the "Previous menu" label
  IF readmouse.release AND mouseLeft THEN
   IF rect_collide_point(str_rect(menu(0), 0, 0), readmouse.pos) THEN
    EXIT DO
   END IF
  END IF
  '--Clicking on a character to edit
  IF readmouse.release AND (mouseLeft OR mouseRight) THEN
   IF hover_char >= 0 THEN
    pt = hover_char
    editing_char = NO
   END IF
  END IF
  '--Clicking on a pixel to draw
  IF readmouse.buttons AND (mouseLeft OR mouseRight) THEN
   IF pt >= 0 ANDALSO hover_draw.x >= 0 ANDALSO hover_draw.y >= 0 THEN
    editing_char = YES
    x = hover_draw.x
    y = hover_draw.y
    DIM setpix as integer = 0
    IF readmouse.buttons AND mouseLeft THEN setpix = 1
    setbit fnt(), 0, (f(pt) * 8 + x) * 8 + y, setpix
    setfont fnt()
   END IF
  END IF

  '--Draw screen
  clearpage dpage

  tog XOR= 1
  xoff = 8
  yoff = 8
  FOR i = 0 TO last
   textcolor uilook(uiMenuItem), uilook(uiDisabledItem)
   DIM cpos as XYPair = XY(xoff + (i MOD linesize) * 9, yoff + (i \ linesize) * 9)
   IF pt >= 0 THEN
    IF editing_char = NO THEN
     IF (i MOD linesize) = (pt MOD linesize) OR (i \ linesize) = (pt \ linesize) THEN textcolor uilook(uiMenuItem), uilook(uiHighlight)
    END IF
   END IF
   IF hover_char = i THEN textcolor uilook(uiMouseHoverItem), uilook(uiSelectedDisabled)
   IF pt = i THEN textcolor uilook(uiSelectedItem + tog), 0
   printstr CHR(f(i)), cpos.x, cpos.y, dpage
  NEXT i
  textcolor uilook(uiMenuItem), 0
  IF rect_collide_point(str_rect(menu(0), 0, 0), readmouse.pos) THEN
   textcolor uilook(uiMouseHoverItem), 0
  END IF
  IF pt < 0 THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr menu(0), 8, 0, dpage

  IF pt >= 0 THEN
   xoff = 150
   yoff = 4
   rectangle xoff, yoff, 160, 160, uilook(uiDisabledItem), dpage
   FOR i = 0 TO 7
    FOR j as integer = 0 TO 7
     IF readbit(fnt(), 0, (f(pt) * 8 + i) * 8 + j) THEN
      c = uilook(uiMenuItem)
      rectangle xoff + i * 20, yoff + j * 20, 20, 20, c, dpage
     END IF
    NEXT j
   NEXT i
   IF editing_char THEN
    IF readbit(fnt(), 0, (f(pt) * 8 + x) * 8 + y) THEN
     c = uilook(uiSelectedItem2)
    ELSE
     c = uilook(uiSelectedDisabled)
    END IF
    rectangle xoff + x * 20, yoff + y * 20, 20, 20, c, dpage
   END IF
   IF hover_draw.x >= 0 ANDALSO hover_draw.y >= 0 THEN
    edgebox xoff + hover_draw.x * 20, yoff + hover_draw.y * 20, 20, 20, uilook(uiMouseHoverItem), uilook(uiSelectedItem) + tog, dpage, transHollow
   END IF
   textcolor uilook(uiText), 0
   DIM tmp as string = "CHAR " & f(pt)
   IF f(pt) >= &hA1 THEN tmp &= "/U+00" & HEX(f(pt))
   printstr tmp, 12, 190, dpage
   IF f(pt) < 32 THEN
    printstr "RESERVED", 160, 190, dpage
   ELSE
    FOR i = 2 TO 53
     IF f(pt) = ASC(key2text(2, i)) THEN printstr "ALT+" + UCASE(key2text(0, i)), 160, 190, dpage
     IF f(pt) = ASC(key2text(3, i)) THEN printstr "ALT+SHIFT+" + UCASE(key2text(0, i)), 160, 190, dpage
    NEXT i
    IF f(pt) = 32 THEN printstr "SPACE", 160, 190, dpage
   END IF
  END IF

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 'If you click on Previous Menu you can get here without having saved yet
 save_font fnt()
END SUB

FUNCTION edit_font_draw_point(byval pixelpos as XYPair) as XYPair
 'Return the font drawing x,y pos that the pixelpos (mouse cursor) is over
 DIM offset as XYPair = XY(150, 4)
 DIM rows as integer = 8
 DIM cols as integer = 8
 DIM tilesize as integer = 20
 DIM areasize as RectType
 corners_to_rect offset, offset + XY(cols, rows) * tilesize, areasize
 IF NOT rect_collide_point(areasize, pixelpos) THEN RETURN XY(-1, -1)
 DIM drawpos as XYPair
 drawpos = pixelpos - offset
 drawpos = drawpos \ tilesize
 RETURN drawpos
END FUNCTION

FUNCTION edit_font_picker_point(byval pixelpos as XYPair) as integer
 'Return the character id that the pixelpos (mouse cursor) collides with or -1 if none
 DIM offset as XYPair = XY(8,8)
 DIM rows as integer = 16
 DIM cols as integer = 14
 DIM tilesize as integer = 9
 DIM areasize as RectType
 corners_to_rect offset, offset + XY(cols, rows) * tilesize, areasize
 IF NOT rect_collide_point(areasize, pixelpos) THEN RETURN -1
 DIM charpos as XYPair
 charpos = pixelpos - offset
 charpos = charpos \ tilesize
 RETURN charpos.y * cols + charpos.x
END FUNCTION

SUB fontedit_export_font(fnt() as integer)

 DIM newfont as string = "newfont"
 newfont = inputfilename("Input a filename to save to", ".ohf", "", "input_file_export_font") 

 IF newfont <> "" THEN
  save_font fnt()
  copyfile game & ".fnt", newfont & ".ohf"
 END IF

END SUB

SUB fontedit_import_font(fnt() as integer)

 STATIC default as string
 DIM newfont as string
 newfont = browse(browseAny, default, "*.ohf", "browse_font")
 
 IF newfont <> "" THEN
  writeablecopyfile newfont, game & ".fnt"

  DIM i as integer
  DIM font_tmp(1023) as integer

  '--character 0 (actually fnt(0)) contains metadata (marks as ASCII or Latin-1)
  '--character 1 to 31 are internal icons and should never be overwritten
  FOR i = 1 * 4 TO 32 * 4 - 1
   font_tmp(i) = fnt(i)
  NEXT i

  '--Reload the font
  load_font fnt()
  setfont fnt()

  '--write back the old 1-31 characters
  FOR i = 1 * 4 TO 32 * 4 - 1
   fnt(i) = font_tmp(i)
  NEXT i

 END IF
END SUB
