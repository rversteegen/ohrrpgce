'OHRRPGCE GAME & CUSTOM - Plank-Slice based menus
'(C) Copyright 2014 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability

#include "config.bi"
#include "allmodex.bi"
#include "common.bi" 
#include "loading.bi"
#include "const.bi"
#include "uiconst.bi"
#include "slices.bi"
#include "sliceedit.bi"
#include "plankmenu.bi"

#ifdef IS_GAME
#include "gglobals.bi"
#include "scriptcommands.bi"  'For embed_text_codes
#endif


'Local subs and functions

'-----------------------------------------------------------------------

'A note about planks: A plank should have the lookup code SL_PLANK_HOLDER whatever its type.
'Child slices of types slText, slRectangle or slSelect can have lookup code SL_PLANK_MENU_SELECTABLE
'if their styles should change depending on selection state

'-----------------------------------------------------------------------

FUNCTION load_plank_from_file(filename as string) as Slice Ptr
 IF NOT isfile(filename) THEN visible_debug "load_plank_from_file: unable to open file """ & filename & """": RETURN 0
 DIM col as Slice Ptr
 col = NewSliceOfType(slSpecial)
 SliceLoadFromFile col, filename
 IF col = 0 THEN visible_debug "load_plank_from_file: unable to load slices from """ & filename & """": RETURN 0
 DIM sl as Slice Ptr
 sl = LookupSlice(SL_PLANK_HOLDER, col)
 IF sl = 0 THEN
  visible_debug "load_plank_from_file: could not find plank holder"
  DeleteSlice @(col)
  RETURN 0
 END IF
 DIM plank as Slice Ptr
 plank = CloneSliceTree(sl, YES, YES)
 DeleteSlice @(col)
 RETURN plank
END FUNCTION

'axis:  0 for left/right, 1 for up/down
'd:     1 for right or down, -1 for left or up
FUNCTION plank_menu_move_cursor (byref ps as PlankState, byval axis as integer, byval d as integer, byval start_parent as Slice Ptr=0) as bool

 IF ps.cur = 0 THEN
  'No cursor yet, guess a default one
  ps.cur = top_left_plank(ps)
  RETURN YES
 END IF
 
 DIM old_cur as Slice Ptr = ps.cur

 REDIM planks(any) as Slice Ptr
 IF start_parent = 0 THEN start_parent = ps.m
 find_all_planks ps, start_parent, planks()
 
 DIM old as XYPair
 old = ps.cur->ScreenPos + ps.cur->Size \ 2

 DIM best as ulongint = &HFFFFFFFFFFFFFFFF
 DIM p as XYPair
 DIM dist as ulongint
 
 DIM sl as Slice Ptr
 FOR i as integer = 0 TO UBOUND(planks)
  sl = planks(i)
  p.x = sl->ScreenX + sl->Width \ 2
  p.y = sl->ScreenY + sl->Height \ 2
  IF (d = 1 ANDALSO p.n(axis) > old.n(axis)) ORELSE (d = -1 ANDALSO p.n(axis) < old.n(axis)) THEN
   dist = (old.x - p.x) ^ 2 + (old.y - p.y) ^ 2
   IF dist < best THEN
    best = dist
    ps.cur = sl
   END IF
  END IF
 NEXT i
 
 RETURN ps.cur <> old_cur
END FUNCTION

SUB plank_menu_scroll_page (byref ps as PlankState, byval scrolldir as integer, byval start_parent as Slice Ptr=0)

 IF ps.cur = 0 THEN
  'No cursor yet, guess a default one
  ps.cur = top_left_plank(ps)
  IF ps.cur = 0 THEN debug "plank_menu_scroll_page: No cursor, and can't find one" : EXIT SUB
 END IF

 DIM scroll as Slice ptr = find_plank_scroll(ps.m)

 DIM targpos as XYPair
 targpos = ps.cur->ScreenPos + ps.cur->Size / 2
 IF scroll THEN targpos.y += scroll->Height * scrolldir

 REDIM planks(any) as Slice Ptr
 IF start_parent = 0 THEN start_parent = ps.m
 find_all_planks ps, start_parent, planks()

 IF UBOUND(planks) < 0 THEN EXIT SUB

 DIM best_sl as Slice Ptr = ps.cur
 DIM best as integer = (best_sl->ScreenX + best_sl->Width / 2 - targpos.x) ^ 2 + (best_sl->ScreenY + best_sl->Height / 2 - targpos.y) ^ 2
 DIM dist as integer
 DIM sl as Slice Ptr
 FOR i as integer = 0 TO UBOUND(planks)
  sl = planks(i)
  dist = (sl->ScreenX + sl->Width / 2 - targpos.x) ^ 2 + (sl->ScreenY + sl->Height / 2 - targpos.y) ^ 2
  IF dist < best THEN
   best = dist
   best_sl = sl
  END IF
 NEXT i

 ps.cur = best_sl
END SUB

FUNCTION plank_menu_arrows (byref ps as PlankState, byval start_parent as Slice Ptr=0) as bool
 DIM result as bool = NO
 'IF keyval(scA) > 1 THEN slice_editor m
 IF start_parent = 0 THEN start_parent = ps.m
#IFDEF IS_GAME
 IF carray(ccLeft) > 1  ANDALSO plank_menu_move_cursor(ps, 0, -1, start_parent) THEN result = YES
 IF carray(ccRight) > 1 ANDALSO plank_menu_move_cursor(ps, 0, 1, start_parent)  THEN result = YES
 IF carray(ccUp) > 1    ANDALSO plank_menu_move_cursor(ps, 1, -1, start_parent) THEN result = YES
 IF carray(ccDown) > 1  ANDALSO plank_menu_move_cursor(ps, 1, 1, start_parent)  THEN result = YES
#ELSE
 IF keyval(scLeft) > 1  ANDALSO plank_menu_move_cursor(ps, 0, -1, start_parent) THEN result = YES
 IF keyval(scRight) > 1 ANDALSO plank_menu_move_cursor(ps, 0, 1, start_parent)  THEN result = YES
 IF keyval(scUp) > 1    ANDALSO plank_menu_move_cursor(ps, 1, -1, start_parent) THEN result = YES
 IF keyval(scDown) > 1  ANDALSO plank_menu_move_cursor(ps, 1, 1, start_parent)  THEN result = YES
#ENDIF
 IF keyval(scPageUp) > 1 THEN plank_menu_scroll_page ps, -1, start_parent : result = YES
 IF keyval(scPageDown) > 1 THEN plank_menu_scroll_page ps, 1, start_parent : result = YES
 IF keyval(scHome) > 1 THEN IF plank_menu_home(ps) THEN result = YES
 IF keyval(scEnd) > 1 THEN IF plank_menu_end(ps) THEN result = YES
 RETURN result
END FUNCTION

FUNCTION plank_menu_drag_scroll(byref ps as PlankState, byval which_button as MouseButton=mouseRight, byval min_threshold as integer=10) as bool
 IF (readmouse.dragging AND which_button) THEN
  IF readmouse.drag_dist > min_threshold THEN
   DIM amount as integer = readmouse.pos.y - readmouse.lastpos.y
   RETURN plank_menu_scroll(ps, amount)
  END IF
 END IF

 RETURN NO
END FUNCTION

FUNCTION plank_menu_mouse_wheel(byref ps as PlankState, byval dist as integer=30) as bool
 '30 is a reasonable default number of pixels, I guess?
 DIM scroll_move as integer = dist * -1 * readmouse.wheel_delta / 120
 RETURN plank_menu_scroll(ps, scroll_move)
END FUNCTION

FUNCTION plank_menu_scroll(byref ps as PlankState, byval scroll_move as integer, byval mouse_must_be_in_scroll as bool=YES) as bool
 DIM result as bool = NO
 DIM scroll as Slice Ptr
 scroll = find_plank_scroll(ps.m)
 IF scroll = 0 THEN RETURN NO
 IF mouse_must_be_in_scroll THEN
  IF NOT SliceCollidePoint(scroll, readmouse.pos) THEN RETURN NO
 END IF

 DIM topy as integer = scroll->ScreenY
 DIM boty as integer = scroll->ScreenY + scroll->Height
 DIM as XYPair min, max
 CalcSliceContentsSize scroll, min, max, 0
 DO WHILE min.y + scroll_move > topy : scroll_move -= 1 : LOOP
 DO WHILE max.y + scroll_move < boty : scroll_move += 1 : LOOP
 ScrollAllChildren scroll, 0, scroll_move

 RETURN YES
END FUNCTION

FUNCTION plank_menu_home(byref ps as PlankState) as bool
 DIM old_cur as Slice ptr = ps.cur
 ps.cur = top_left_plank(ps)
 RETURN ps.cur <> old_cur
END FUNCTION

FUNCTION plank_menu_end(byref ps as PlankState) as bool
 DIM old_cur as Slice ptr = ps.cur
 ps.cur = bottom_right_plank(ps)
 RETURN ps.cur <> old_cur
END FUNCTION

FUNCTION plank_menu_update_hover(byref ps as PlankState) as bool
 'Returns YES if the hover has changed
 DIM oldhover as Slice Ptr = ps.hover
 ps.hover = find_plank_at_screen_pos(ps, readmouse.pos)
 RETURN ps.hover <> oldhover
END FUNCTION

FUNCTION find_plank_nearest_screen_pos(byref ps as PlankState, byval targpos as XYPair, byval start_parent as Slice Ptr=0) as Slice Ptr
 'Given a target screen pos, find the closest plank, even if it does not overlap the target pos
 REDIM planks(any) as Slice Ptr
 IF start_parent = 0 THEN start_parent = ps.m
 find_all_planks ps, start_parent, planks()

 DIM best_sl as Slice Ptr = 0
 DIM best as integer = INT_MAX
 DIM p as XYPair
 DIM dist as integer
 
 DIM sl as Slice Ptr
 FOR i as integer = 0 TO UBOUND(planks)
  sl = planks(i)
  p.x = sl->ScreenX + sl->Width / 2
  p.y = sl->ScreenY + sl->Height / 2
  dist = (targpos.x - p.x) ^ 2 + (targpos.y - p.y) ^ 2
  IF dist < best THEN
   best = dist
   best_sl = sl
  END IF
 NEXT i
 
 RETURN best_sl
END FUNCTION

FUNCTION find_plank_at_screen_pos(byref ps as PlankState, byval targpos as XYPair, byval start_parent as Slice Ptr=0) as Slice Ptr
 'Given a target screen pos, find the first colliding plank that is not invisible.
 REDIM planks(any) as Slice Ptr
 IF start_parent = 0 THEN start_parent = ps.m
 find_all_planks ps, start_parent, planks()
 
 DIM sl as Slice Ptr
 FOR i as integer = 0 TO UBOUND(planks)
  sl = planks(i)
  IF SliceIsInvisibleOrClipped(sl) THEN CONTINUE FOR
  IF SliceCollidePoint(sl, targpos) THEN RETURN sl
 NEXT i
 
 RETURN 0
END FUNCTION

FUNCTION top_left_plank(byref ps as PlankState) as Slice Ptr
 REDIM planks(any) as Slice Ptr
 find_all_planks ps, ps.m, planks()

 IF UBOUND(planks) < 0 THEN RETURN 0

 DIM best as Slice Ptr = planks(0)
 DIM sl as Slice Ptr
 FOR i as integer = 0 TO UBOUND(planks)
  sl = planks(i)
  IF sl->ScreenX <= best->ScreenX ANDALSO sl->ScreenY <= best->ScreenY THEN
   best = sl
  END IF
 NEXT i
 
 RETURN best
END FUNCTION

FUNCTION bottom_right_plank(byref ps as PlankState) as Slice Ptr
 REDIM planks(any) as Slice Ptr
 find_all_planks ps, ps.m, planks()

 IF UBOUND(planks) < 0 THEN RETURN 0

 DIM best as Slice Ptr = planks(UBOUND(planks))
 DIM sl as Slice Ptr
 FOR i as integer = UBOUND(planks) to 0 STEP -1
  sl = planks(i)
  IF sl->ScreenX >= best->ScreenX ANDALSO sl->ScreenY >= best->ScreenY THEN
   best = sl
  END IF
 NEXT i
 
 RETURN best
END FUNCTION

FUNCTION default_is_plank(byval sl as Slice Ptr) as bool
 IF sl = 0 THEN debug "default_is_plank: null slice ptr" : RETURN NO
 IF sl->Lookup = SL_PLANK_HOLDER THEN
  IF SliceIsInvisible(sl) THEN RETURN NO
  RETURN YES
 END IF
 RETURN NO
END FUNCTION

' Fill planks() with all descendents of m that are planks (according to the callback)
' By default this excludes invisible planks (also planks with invisible parents)
SUB find_all_planks(byref ps as PlankState, byval m as Slice Ptr, planks() as Slice Ptr)
 IF m = 0 THEN debug "find_all_planks: null m ptr" : EXIT SUB

 DIM plank_checker as FnIsPlank
 plank_checker = ps.is_plank_callback
 IF plank_checker = 0 THEN plank_checker = @default_is_plank

 REDIM planks(-1 TO -1)
 DIM planks_found as integer = 0
 DIM desc as Slice ptr = m->FirstChild
 DO WHILE desc
  IF plank_checker(desc) THEN
   'This is a plank.
   IF planks_found > UBOUND(planks) THEN
    REDIM PRESERVE planks(-1 TO UBOUND(planks) + 10)
   END IF
   planks(planks_found) = desc
   planks_found += 1
  END IF
  desc = NextDescendent(desc, m)
 LOOP
 REDIM PRESERVE planks(-1 TO planks_found - 1)
END SUB

SUB set_plank_state_default_callback (byval sl as Slice Ptr, byval state as PlankItemState)
 SELECT CASE sl->SliceType
  CASE slText:
   SELECT CASE state
    CASE plankNORMAL:          ChangeTextSlice sl, , uiMenuItem * -1 - 1
    CASE plankSEL:             ChangeTextSlice sl, , uiSelectedItem2 * -1 - 1
    CASE plankDISABLE:         ChangeTextSlice sl, , uiDisabledItem * -1 - 1
    CASE plankSELDISABLE:      ChangeTextSlice sl, , uiSelectedDisabled2 * -1 - 1
    CASE plankSPECIAL:         ChangeTextSlice sl, , uiSpecialItem * -1 - 1
    CASE plankSELSPECIAL:      ChangeTextSlice sl, , uiSelectedSpecial2 * -1 - 1
    CASE plankMOUSEHOVER:      ChangeTextSlice sl, , uiMouseHoverItem * -1 -1
   END SELECT
  CASE slRectangle:
   sl->Visible = YES
   'Change the bgcol
   SELECT CASE state
    CASE plankNORMAL:          sl->Visible = NO
    CASE plankSEL:             ChangeRectangleSlice sl, , uiHighlight * -1 - 1
    CASE plankDISABLE:         sl->Visible = NO
    CASE plankSELDISABLE:      ChangeRectangleSlice sl, , uiHighlight * -1 - 1
    CASE plankSPECIAL:         sl->Visible = NO
    CASE plankSELSPECIAL:      ChangeRectangleSlice sl, , uiHighlight * -1 - 1
    CASE plankMOUSEHOVER:      sl->Visible = NO
   END SELECT
 END SELECT
END SUB

' Set the state (using the callback) of each descendent of sl with lookup=SL_PLANK_MENU_SELECTABLE
SUB set_plank_state (byref ps as PlankState, byval sl as Slice Ptr, byval state as PlankItemState = plankNORMAL)
 IF sl = 0 THEN debug "set_plank_state: null slice ptr": EXIT SUB

 DIM desc as Slice ptr = sl
 DO WHILE desc
  IF desc->Lookup = SL_PLANK_MENU_SELECTABLE THEN
   IF ps.state_callback THEN
    ps.state_callback(desc, state)
   ELSE
    set_plank_state_default_callback(desc, state)
   END IF
  END IF
  desc = NextDescendent(desc, sl)
 LOOP
END SUB

FUNCTION plank_menu_append (byval sl as slice ptr, byval lookup as integer, byval collection_kind as integer, byval callback as FnEmbedCode=0, byval arg0 as intptr_t=0, byval arg1 as intptr_t=0, byval arg2 as intptr_t=0) as Slice Ptr
 DIM collection as Slice Ptr = NewSliceOfType(slContainer)
 load_slice_collection collection, collection_kind
 IF collection = 0 THEN debug "plank_menu_append: plank collection not found " & collection_kind : RETURN 0
 DIM result as Slice Ptr
 result = plank_menu_append(sl, lookup, collection, callback, arg0, arg1, arg2)
 DeleteSlice @collection
 RETURN result
END FUNCTION

'Add a new plank child, copied from 'collection' to the 'LookupSlice(lookup, sl)' slice
'Other args: passed to expand_slice_text_insert_codes
FUNCTION plank_menu_append (byval sl as slice ptr, byval lookup as integer, byval collection as Slice Ptr, byval callback as FnEmbedCode=0, byval arg0 as intptr_t=0, byval arg1 as intptr_t=0, byval arg2 as intptr_t=0) as Slice Ptr
 IF sl = 0 THEN debug "plank_menu_append: null slice ptr": RETURN 0
 DIM m as Slice ptr = LookupSlice(lookup, sl)
 IF m = 0 THEN debug "plank_menu_append: menu not found " & lookup : RETURN 0
 IF collection = 0 THEN debug "plank_menu_append: plank collection null ptr" : RETURN 0
 DIM holder as Slice Ptr
 holder = LookupSlice(SL_PLANK_HOLDER, collection)
 DIM cl as Slice Ptr
 IF holder <> 0 THEN
  'Found a holder, use only it
  cl = CloneSliceTree(holder)
  cl->Fill = YES
 ELSE
  'No holder, use the whole collection
  cl = CloneSliceTree(collection)
  cl->Lookup = SL_PLANK_HOLDER
 END IF
 
 SetSliceParent cl, m
 
 expand_slice_text_insert_codes cl, callback, arg0, arg1, arg2
 
 RETURN cl
END FUNCTION

'For use when you're using a template slice instead of a separate slice collection.
'(Template slices aren't implemented yet, but for now just use normal slices as templates.)
FUNCTION plank_menu_clone_template (byval templatesl as Slice ptr) as Slice ptr
 IF templatesl = 0 THEN debug "plank_menu_clone_template: null template" : RETURN 0
 DIM sl as Slice ptr
 sl = CloneSliceTree(templatesl)
 IF sl = 0 THEN debug "plank_menu_clone_template: unclonable" : RETURN 0
 InsertSliceBefore templatesl, sl
 sl->Visible = YES
 sl->Lookup = SL_PLANK_HOLDER
 RETURN sl
END FUNCTION

SUB plank_menu_clear (byval sl as Slice Ptr, byval lookup as integer)
 IF sl = 0 THEN debug "plank_menu_clear: null slice ptr": EXIT SUB
 DIM m as Slice ptr = LookupSlice(lookup, sl)
 IF m = 0 THEN
  debug "plank_menu_clear: menu not found " & lookup
  EXIT SUB
 END IF
 DeleteSliceChildren m
END SUB

SUB expand_slice_text_insert_codes (byval sl as Slice ptr, byval callback as FnEmbedCode=0, byval arg0 as intptr_t=0, byval arg1 as intptr_t=0, byval arg2 as intptr_t=0)
 'Starting with children of the given container slice, iterate through
 ' all children and expand any ${} codes found in any TextSlice
 ' Do not descend into child slices marked with SL_PLANK_HOLDER because planks are responsible for their own text codes
 IF sl = 0 THEN debug "expand_slice_text_insert_codes: null slice ptr": EXIT SUB
 DIM ch as Slice Ptr = sl->FirstChild
 DIM dat as TextSliceData Ptr
 DO WHILE ch <> 0
  IF ch->Lookup <> SL_PLANK_HOLDER THEN
   IF ch->SliceType = slText THEN
    dat = ch->SliceData
    IF dat->s_orig = "" THEN dat->s_orig = dat->s
#IFDEF IS_GAME
    ChangeTextSlice ch, embed_text_codes(dat->s_orig, callback, arg0, arg1, arg2)
#ENDIF
   END IF
   expand_slice_text_insert_codes ch, callback, arg0, arg1, arg2
  END IF
  ch = ch->NextSibling
 LOOP
END SUB

SUB hide_slices_by_lookup_code (byval sl as Slice ptr, byval lookup as integer, byval hide as bool)
 ' Starting with a given container slice, iterate through
 ' all descendents and set the visibility of any slices with a specific lookup code
 ' (Note: the argument is whether to set hidden, opposite of Slice.Visible)
 IF sl = 0 THEN debug "hide_slices_by_lookup_code: null slice ptr": EXIT SUB

 DIM desc as Slice ptr = sl
 DO WHILE desc
  IF desc->Lookup = lookup THEN desc->Visible = NOT hide
  desc = NextDescendent(desc, sl)
 LOOP
END SUB

SUB set_sprites_by_lookup_code (byval sl as Slice ptr, byval lookup as integer, byval sprtype as SpriteType, byval picnum as integer, byval palnum as integer=-1)
 'Starting with children of the given container slice, iterate through
 ' all children and change any sprites matching the lookup code
 IF sl = 0 THEN debug "set_sprites_by_lookup_code: null slice ptr": EXIT SUB

 DIM desc as Slice ptr = sl
 DO WHILE desc
  IF desc->Lookup = lookup AND desc->SliceType = slSprite THEN
   ChangeSpriteSlice desc, sprtype, picnum, palnum
  END IF
  desc = NextDescendent(desc, sl)
 LOOP
END SUB

FUNCTION find_plank_scroll (byval sl as Slice Ptr) as slice ptr
 IF sl = 0 THEN debug "find_plank_scroll: null slice ptr" : RETURN 0

 DIM desc as Slice ptr = sl
 DO WHILE desc
  IF desc->SliceType = slScroll THEN RETURN desc
  desc = NextDescendent(desc, sl)
 LOOP
 RETURN 0
END FUNCTION

SUB update_plank_scrolling (byref ps as PlankState)
 IF ps.m = 0 THEN debug "update_plank_scrolling: null m slice ptr" : EXIT SUB

 DIM scroll as slice ptr = find_plank_scroll(ps.m)
 IF scroll ANDALSO ps.cur ANDALSO IsAncestor(ps.cur, scroll) THEN
  ScrollToChild scroll, ps.cur
 END IF
END SUB

SUB save_plank_selection (byref ps as PlankState)
 'Attempt to save the current selection and scroll position without any slice references
 ps.selection_saved = NO
 IF ps.cur = 0 THEN EXIT SUB
 ps._saved_pos.x = ps.cur->ScreenX + ps.cur->Width / 2
 ps._saved_pos.y = ps.cur->ScreenY + ps.cur->Height / 2
 ps.selection_saved = YES
END SUB

SUB restore_plank_selection (byref ps as PlankState)
 'Attempt to restore selection previously saved by save_plank_selection
 ps.cur = 0
 IF ps.selection_saved = NO THEN EXIT SUB
 ps.cur = find_plank_nearest_screen_pos(ps, ps._saved_pos)
 ps.selection_saved = NO
END SUB

FUNCTION focus_plank_by_extra_id(byref ps as PlankState, byval extra_idx as integer = 0, byval id as integer, byval start_parent as Slice Ptr = 0) as bool
 DIM old_cur as Slice Ptr = ps.cur

 DIM new_cur as Slice Ptr
 new_cur = find_plank_by_extra_id(ps, extra_idx, id, start_parent)
 IF new_cur THEN
  ps.cur = new_cur
  update_plank_scrolling ps
 END IF
 
 RETURN ps.cur <> old_cur
END FUNCTION

FUNCTION find_plank_by_extra_id(byref ps as PlankState, byval extra_idx as integer = 0, byval id as integer, byval start_parent as Slice Ptr = 0) as Slice Ptr
 'If more than one plank has the same Extra(0) id number, just return the first one.

 REDIM planks(any) as Slice Ptr
 IF start_parent = 0 THEN start_parent = ps.m
 find_all_planks ps, start_parent, planks()
 
 DIM sl as Slice Ptr
 FOR i as integer = 0 TO UBOUND(planks)
  sl = planks(i)
  IF sl->Extra(extra_idx) = id THEN RETURN sl
 NEXT i

 RETURN 0
END FUNCTION

Function plank_select_by_string(byref ps as PlankState, query as string) as bool
 IF ps.cur = 0 THEN
  'No cursor yet, guess a default one
  ps.cur = top_left_plank(ps)
 END IF
 
 DIM old_cur as Slice Ptr = ps.cur

 'get a list of all of the planks.
 REDIM planks(any) as Slice Ptr
 find_all_planks ps, ps.m, planks()

 'Find the current plank's index in the list
 DIM start_i as integer = -1
 FOR i as integer = 0 TO UBOUND(planks)
  IF planks(i) = ps.cur THEN start_i = i
 NEXT i
 IF start_i = -1 THEN
  start_i = 0
 END IF
 
 'Loop through the rest of the planks searching for the string in any text child
 DIM found_it as bool = NO
 FOR i as integer = start_i TO UBOUND(planks)
  IF FindTextSliceStringRecursively(planks(i), query) THEN
   ps.cur = planks(i)
   found_it = YES
   EXIT FOR
  END IF
 NEXT i
 IF NOT found_it THEN
  FOR i as integer = 0 TO start_i - 1
   IF FindTextSliceStringRecursively(planks(i), query) THEN
    ps.cur = planks(i)
    found_it = YES
    EXIT FOR
   END IF
  NEXT i
 END IF
 
 RETURN ps.cur <> old_cur
End Function


