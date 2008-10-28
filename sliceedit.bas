'OHRRPGCE CUSTOM - Slice Collection Editor
'(C) Copyright 1997-2008 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Except, this module isn't especially crappy. Yay!
'

#ifdef __FB_LANG__
  #if __FB_LANG__ <> "fb"
'$DYNAMIC
    Option Explicit
  #endif
#endif

#include "allmodex.bi"
#include "common.bi"
#include "slices.bi"
#include "scancodes.bi"
#include "custom_udts.bi"
#include "customsubs.bi"

'==============================================================================

TYPE SliceEditMenuItem
 s AS STRING
 handle AS Slice Ptr
END TYPE

'==============================================================================

CONST slgrPICKTYPE = 1
CONST slgrPICKXY = 2
CONST slgrPICKWH = 3
CONST slgrPICKCOL = 4
CONST slgrUPDATESPRITE = 5

'==============================================================================

'Public functions (will put these in a bi file if there turns out to be more than 1)
DECLARE SUB slice_editor ()

'Functions that might go better in slices.bas ... we shall see
DECLARE FUNCTION SliceTypeName (sl AS Slice Ptr) AS STRING
DECLARE FUNCTION SlicePositionString (sl AS Slice Ptr) AS STRING

'Functions only used locally
DECLARE SUB slice_editor_refresh (BYREF state AS MenuState, menu() AS SliceEditMenuItem, edslice AS Slice Ptr)
DECLARE SUB slice_editor_refresh_append (BYREF index AS INTEGER, menu() AS SliceEditMenuItem, caption AS STRING, sl AS Slice Ptr=0)
DECLARE SUB slice_editor_refresh_recurse (BYREF index AS INTEGER, menu() AS SliceEditMenuItem, BYREF indent AS INTEGER, sl AS Slice Ptr)
DECLARE SUB slice_edit_detail (sl AS Slice Ptr, rootsl AS Slice Ptr)
DECLARE SUB slice_edit_detail_refresh (BYREF state AS MenuState, menu() AS STRING, sl AS Slice Ptr, rules() AS EditRule)
DECLARE SUB slice_edit_detail_keys (BYREF state AS MenuState, sl AS Slice Ptr, rootsl AS Slice Ptr, rules() AS EditRule)
DECLARE SUB slice_editor_xy (BYREF x AS INTEGER, BYREF y AS INTEGER, rootsl AS Slice Ptr)

'Functions that need to be aware of magic numbers for SliceType
DECLARE FUNCTION slice_edit_detail_browse_slicetype(BYREF slice_type AS INTEGER) AS INTEGER
DECLARE FUNCTION slice_type_as_number (slice_type AS SliceTypes) AS INTEGER
DECLARE FUNCTION new_slice_by_number (slice_type_number AS INTEGER) AS Slice Ptr
DECLARE FUNCTION SliceTypeNameByNum (num AS INTEGER) AS STRING

'Slice EditRule convenience functions
DECLARE SUB sliceed_rule(rules() AS EditRule, mode AS EditRuleMode, BYVAL dataptr AS ANY PTR, BYVAL lower AS INTEGER=0, BYVAL upper AS INTEGER=0, BYVAL group AS INTEGER = 0)
DECLARE SUB sliceed_rule_tog(rules() AS EditRule, BYVAL dataptr AS INTEGER PTR, BYVAL group AS INTEGER=0)
DECLARE SUB sliceed_rule_none(rules() AS EditRule, BYVAL group AS INTEGER = 0)

'==============================================================================

SUB slice_editor ()

 DIM edslice AS Slice Ptr
 edslice = NewSlice
 WITH *edslice
  .Attach = slScreen
  .SliceType = slRoot
 END WITH
 NewSlice(edslice)

 DIM menu(0) AS SliceEditMenuItem
 DIM plainmenu(0) AS STRING 'FIXME: This is a hack because I didn't want to re-implement standardmenu right now

 DIM state AS MenuState
 WITH state
  .size = 20
  .need_update = YES
 END WITH

 DIM slice_type_num AS INTEGER = 0
 DIM shift AS INTEGER

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO

  IF state.need_update THEN
   slice_editor_refresh(state, menu(), edslice)
   REDIM plainmenu(state.last) AS STRING
   FOR i AS INTEGER = 0 TO UBOUND(plainmenu)
    plainmenu(i) = menu(i).s
   NEXT i
   state.need_update = NO
  END IF

  shift = (keyval(scLeftShift) > 0 OR keyval(scRightShift) > 0)
  IF enter_or_space() THEN
   IF state.pt = 0 THEN
    EXIT DO
   ELSE
    slice_edit_detail menu(state.pt).handle, edslice
    state.need_update = YES
   END IF 
  END IF
  IF state.pt > 0 THEN
   IF keyval(scPlus) > 1 OR keyval(scNumpadPlus) THEN
    IF slice_edit_detail_browse_slicetype(slice_type_num) THEN
     InsertSiblingSlice menu(state.pt).handle, new_slice_by_number(slice_type_num)
     state.need_update = YES
    END IF
   END IF
   IF shift THEN
    IF keyval(scUp) > 1 AND state.pt > 1 THEN
     SwapSiblingSlices menu(state.pt).handle, menu(state.pt - 1).handle
     state.need_update = YES
    END IF
    IF keyval(scDown) > 1 AND state.pt < state.last THEN
     SwapSiblingSlices menu(state.pt).handle, menu(state.pt + 1).handle
     state.need_update = YES
    END IF
   END IF
  END IF
  usemenu state

  DrawSlice edslice, dpage
  standardmenu plainmenu(), state, 0, 0, dpage, YES
  edgeprint "+ to add a slice. SHIFT+arrows to sort", 0, 190, uilook(uiText), dpage

  SWAP vpage, dpage
  setvispage vpage
  clearpage dpage
  dowait
 LOOP

END SUB

SUB slice_edit_detail (sl AS Slice Ptr, rootsl AS Slice Ptr)

 DIM menu(0) AS STRING
 DIM rules(0) AS EditRule

 DIM state AS MenuState
 WITH state
  .size = 22
  .need_update = YES
 END WITH

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO

  IF state.need_update THEN
   slice_edit_detail_refresh state, menu(), sl, rules()
  END IF

  usemenu state
  IF state.pt = 0 AND enter_or_space() THEN EXIT DO
  slice_edit_detail_keys state, sl, rootsl, rules()
  
  DrawSlice rootsl, dpage
  standardmenu menu(), state, 0, 0, dpage, YES

  SWAP vpage, dpage
  setvispage vpage
  clearpage dpage
  dowait
 LOOP
END SUB

SUB slice_edit_detail_keys (BYREF state AS MenuState, sl AS Slice Ptr, rootsl AS Slice Ptr, rules() AS EditRule)
 DIM rule AS EditRule = rules(state.pt)
 SELECT CASE rule.mode
  CASE erIntgrabber
   DIM n AS INTEGER PTR = rule.dataptr
   IF intgrabber(*n, rule.lower, rule.upper) THEN
    state.need_update = YES
   END IF
  CASE erToggle
   DIM n AS INTEGER PTR = rule.dataptr
   IF intgrabber(*n, -1, 0) THEN
    state.need_update = YES
   END IF
   IF enter_or_space() THEN *n = NOT *n : state.need_update = YES
 END SELECT
 SELECT CASE rule.group
  CASE slgrPICKTYPE:
   DIM slice_type AS INTEGER = slice_type_as_number(sl->SliceType)
   IF intgrabber(slice_type, 0, 5) THEN
    state.need_update = YES
   END IF
   IF enter_or_space() THEN
    IF slice_edit_detail_browse_slicetype(slice_type) THEN
     state.need_update = YES
    END IF
   END IF
   IF state.need_update THEN
    ReplaceSlice sl, new_slice_by_number(slice_type)
   END IF
  CASE slgrPICKXY:
   IF enter_or_space() THEN
    slice_editor_xy sl->X, sl->Y, rootsl
    state.need_update = YES
   END IF
  CASE slgrPICKWH:
   IF enter_or_space() THEN
    slice_editor_xy sl->Width, sl->Height, rootsl
    state.need_update = YES
   END IF
  CASE slgrPICKCOL:
   IF enter_or_space() THEN
    DIM n AS INTEGER PTR = rule.dataptr
    *n = color_browser_256(*n)
    state.need_update = YES
   END IF
  CASE slgrUPDATESPRITE
   IF state.need_update THEN
    DIM dat AS SpriteSliceData Ptr
    dat = sl->SliceData
    dat->loaded = NO
    dat->record = small(dat->record, gen(sprite_sizes(dat->spritetype).genmax))
    dat->frame = small(dat->frame, sprite_sizes(dat->spritetype).frames - 1)
   END IF
 END SELECT
END SUB

SUB slice_editor_xy (BYREF x AS INTEGER, BYREF y AS INTEGER, rootsl AS Slice Ptr)
 DIM shift AS INTEGER = 0
 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF enter_or_space() THEN EXIT DO
  shift = (keyval(scLeftShift) > 0 OR keyval(scRightShift) > 0)
  IF keyval(scUp)    > 0 THEN y -= 1 + 9 * ABS(shift)
  IF keyval(scRight) > 0 THEN x += 1 + 9 * ABS(shift)
  IF keyval(scDown)  > 0 THEN y += 1 + 9 * ABS(shift)
  IF keyval(scLeft)  > 0 THEN x -= 1 + 9 * ABS(shift)
  DrawSlice rootsl, dpage
  edgeprint "Arrow keys to edit, SHIFT for speed", 0, 190, uilook(uiText), dpage
  SWAP vpage, dpage
  setvispage vpage
  clearpage dpage
  dowait
 LOOP
END SUB

SUB sliceed_rule(rules() AS EditRule, mode AS EditRuleMode, BYVAL dataptr AS ANY PTR, BYVAL lower AS INTEGER=0, BYVAL upper AS INTEGER=0, BYVAL group AS INTEGER = 0)
 DIM index AS INTEGER = UBOUND(rules) + 1
 REDIM PRESERVE rules(index) AS EditRule
 WITH rules(index)
  .dataptr = dataptr
  .mode = mode
  .lower = lower
  .upper = upper
  .group = group
 END WITH 
END SUB

SUB sliceed_rule_none(rules() AS EditRule, BYVAL group AS INTEGER = 0)
 sliceed_rule rules(), erNone, 0, 0, 0, group
END SUB

SUB sliceed_rule_tog(rules() AS EditRule, BYVAL dataptr AS INTEGER PTR, BYVAL group AS INTEGER=0)
 sliceed_rule rules(), erToggle, dataptr, -1, 0, group
END SUB

SUB slice_edit_detail_refresh (BYREF state AS MenuState, menu() AS STRING, sl AS Slice Ptr, rules() AS EditRule)
 REDIM menu(6)
 REDIM rules(0)
 menu(0) = "Previous Menu"
 WITH *sl
  menu(1) = "Slice type: " & SliceTypeName(sl)
  sliceed_rule_none rules(), slgrPICKTYPE
  menu(2) = "X: " & .X
  sliceed_rule rules(), erIntgrabber, @.X, -9999, 9999, slgrPICKXY
  menu(3) = "Y: " & .Y
  sliceed_rule rules(), erIntgrabber, @.Y, -9999, 9999, slgrPICKXY
  menu(4) = "Width: " & .Width
  sliceed_rule rules(), erIntgrabber, @.Width, 0, 9999, slgrPICKWH
  menu(5) = "Height: " & .Height
  sliceed_rule rules(), erIntgrabber, @.Height, 0, 9999, slgrPICKWH
  menu(6) = "Visible: " & yesorno(.Visible)
  sliceed_rule_tog rules(), @.Visible
  SELECT CASE .SliceType
   CASE slRectangle
    DIM dat AS RectangleSliceData Ptr
    dat = .SliceData
    string_array_grow_append menu(), "Background color: " & defaultint(dat->bgcol)
    sliceed_rule rules(), erIntgrabber, @(dat->bgcol), 0, 255, slgrPICKCOL
    string_array_grow_append menu(), "Foreground color: " & defaultint(dat->fgcol)
    sliceed_rule rules(), erIntgrabber, @(dat->fgcol), 0, 255, slgrPICKCOL
    string_array_grow_append menu(), "Transparent: " & yesorno(dat->transparent)
    sliceed_rule_tog rules(), @(dat->transparent)
    string_array_grow_append menu(), "Border: " & yesorno(dat->border)
    sliceed_rule_tog rules(), @(dat->border)
   CASE slStyleRectangle
    DIM dat AS StyleRectangleSliceData Ptr
    dat = .SliceData
    string_array_grow_append menu(), "Style: " & dat->style
    sliceed_rule rules(), erIntgrabber, @(dat->style), 0, 14
    string_array_grow_append menu(), "Transparent: " & yesorno(dat->transparent)
    sliceed_rule_tog rules(), @(dat->transparent)
    string_array_grow_append menu(), "Hide Border: " & yesorno(dat->hideborder)
    sliceed_rule_tog rules(), @(dat->hideborder)
   CASE slSprite
    DIM dat AS SpriteSliceData Ptr
    dat = .SliceData
    string_array_grow_append menu(), "Sprite Type: " & sprite_sizes(dat->spritetype).name
    sliceed_rule rules(), erIntgrabber, @(dat->spritetype), 0, 8, slgrUPDATESPRITE
    string_array_grow_append menu(), "Sprite Number: " & dat->record
    sliceed_rule rules(), erIntgrabber, @(dat->record), 0, gen(sprite_sizes(dat->spritetype).genmax), slgrUPDATESPRITE
    string_array_grow_append menu(), "Sprite Palette: " & defaultint(dat->pal)
    sliceed_rule rules(), erIntgrabber, @(dat->pal), -1, gen(genMaxPal), slgrUPDATESPRITE
    string_array_grow_append menu(), "Sprite Frame: " & dat->frame
    sliceed_rule rules(), erIntgrabber, @(dat->frame), 0, sprite_sizes(dat->spritetype).frames - 1
  END SELECT
 END WITH
 state.last = UBOUND(menu)
 state.pt = small(state.pt, state.last)
 state.top = small(state.top, state.pt)
END SUB

FUNCTION SliceTypeName (sl AS Slice Ptr) AS STRING
 SELECT CASE sl->SliceType
  CASE slRoot:           RETURN "Root"
  CASE slSpecial:        RETURN "Special"
  CASE slRectangle:      RETURN "Rectangle"
  CASE slStyleRectangle: RETURN "Styled Rect"
  CASE slSprite:         RETURN "Sprite"
  CASE slText:           RETURN "Text"
  CASE slMenu:           RETURN "Menu"
  CASE slMenuItem:       RETURN "MenuItem"
 END SELECT
 RETURN "Unknown"
END FUNCTION

'----------------------------------------------------------------------
' The following four functions need to be aware of magical numbers

FUNCTION SliceTypeNameByNum (num AS INTEGER) AS STRING
 'These are arbitrary numbers that only have meaning in this editor
 SELECT CASE num
  CASE 0: RETURN "Generic"
  CASE 1: RETURN "Rectangle"
  CASE 2: RETURN "Styled Rect"
  CASE 3: RETURN "Sprite"
  CASE 4: RETURN "Text"
  CASE 5: RETURN "Menu"
 END SELECT
 RETURN "Unknown"
END FUNCTION

FUNCTION slice_type_as_number (slice_type AS SliceTypes) AS INTEGER
 'These are arbitrary numbers that only have meaning in this editor
 SELECT CASE slice_type
  CASE slRoot:           RETURN 0
  CASE slSpecial:        RETURN 0
  CASE slRectangle:      RETURN 1
  CASE slStyleRectangle: RETURN 2
  CASE slSprite:         RETURN 3
  CASE slText:           RETURN 4
  CASE slMenu:           RETURN 5
  CASE slMenuItem:       RETURN 0
 END SELECT
END FUNCTION

FUNCTION new_slice_by_number (slice_type_number AS INTEGER) AS Slice Ptr
 'These are arbitrary numbers that only have meaning in this editor
 SELECT CASE slice_type_number
  CASE 1: DIM dat AS RectangleSliceData
          RETURN NewRectangleSlice(0, dat)
  CASE 2: DIM dat AS StyleRectangleSliceData
          RETURN NewStyleRectangleSlice(0, dat)
  CASE 3: DIM dat AS SpriteSliceData
          dat.pal = -1 'FIXME: This is because we can't use constructors yet
          RETURN NewSpriteSlice(0, dat)
  CASE 4: DIM dat AS TextSliceData
          RETURN NewTextSlice(0, dat)
  CASE 5: DIM dat AS MenuSliceData
          RETURN NewMenuSlice(0, dat)
  CASE ELSE: RETURN NewSlice()
 END SELECT
END FUNCTION

FUNCTION slice_edit_detail_browse_slicetype(BYREF slice_type AS INTEGER) AS INTEGER

 DIM menu(5) AS STRING
 FOR i AS INTEGER = 0 TO UBOUND(menu)
  menu(i) = SliceTypeNameByNum(i)
 NEXT i

 DIM state AS MenuState
 WITH state
  .pt = slice_type
  .last = UBOUND(menu)
  .size = 22
 END WITH

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN RETURN NO

  usemenu state
  
  IF enter_or_space() THEN
   slice_type = state.pt
   RETURN YES
  END IF
  
  standardmenu menu(), state, 0, 0, dpage
 
  SWAP vpage, dpage
  setvispage vpage
  clearpage dpage
  dowait
 LOOP
 RETURN NO 
END FUNCTION

' The preceding four functions need to be aware of magical numbers
'----------------------------------------------------------------------

FUNCTION SlicePositionString (sl AS Slice Ptr) AS STRING
 'This shows the absolute screen position of a slice.
 WITH *sl
  RETURN .ScreenX & "," & .ScreenY & "(" & .Width & "x" & .Height & ")"
 END WITH
END FUNCTION

SUB slice_editor_refresh (BYREF state AS MenuState, menu() AS SliceEditMenuItem, edslice AS Slice Ptr)
 FOR i AS INTEGER = 0 TO UBOUND(menu)
  menu(i).s = ""
 NEXT i
 DIM index AS INTEGER = 0

 DIM indent AS INTEGER = 0
 slice_editor_refresh_append index, menu(), "Previous Menu"
 slice_editor_refresh_recurse index, menu(), indent, edslice
 WITH state
  .last = index - 1
  .pt = small(.pt, .last)
  .top = small(.top, .pt)
 END WITH
END SUB

SUB slice_editor_refresh_append (BYREF index AS INTEGER, menu() AS SliceEditMenuItem, caption AS STRING, sl AS Slice Ptr=0)
 IF index > UBOUND(menu) THEN
  REDIM PRESERVE menu(index + 10) AS SliceEditMenuItem
 END IF
 menu(index).s = caption
 menu(index).handle = sl
 index += 1
END SUB

SUB slice_editor_refresh_recurse (BYREF index AS INTEGER, menu() AS SliceEditMenuItem, BYREF indent AS INTEGER, sl AS Slice Ptr)
 WITH *sl
  DIM caption AS STRING
  caption = STRING(indent, " ")
  caption = caption & SliceTypeName(sl)
  caption = caption & " " & SlicePositionString(sl)
  IF .SliceType <> slRoot THEN
   slice_editor_refresh_append index, menu(), caption, sl
   indent += 1
  END IF
  'Now append the children
  DIM ch AS slice ptr = .FirstChild
  DO WHILE ch <> 0
   slice_editor_refresh_recurse index, menu(), indent, ch
   ch = ch->NextSibling
  LOOP
  IF .SliceType <> slRoot THEN
   indent -= 1
  END IF
 END WITH
END SUB
