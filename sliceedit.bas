'OHRRPGCE CUSTOM - Slice Collection Editor
'(C) Copyright 1997-2008 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Except, this module isn't especially crappy. Yay!
'
#include "config.bi"
#include "allmodex.bi"
#include "common.bi"
#include "slices.bi"
#include "loading.bi"

#include "sliceedit.bi"

'==============================================================================

TYPE SliceEditState
 collection_number as integer
 collection_group_number as integer
 collection_file as string
 use_index as integer
 last_non_slice as integer
 saved_pos as XYPair
 saved_size as XYPair
 clipboard as Slice Ptr
 hide_menu as integer
END TYPE

TYPE SliceEditMenuItem
 s as string
 handle as Slice Ptr
END TYPE

'------------------------------------------------------------------------------

ENUM EditRuleMode
  erNone              'Used for labels and links
  erIntgrabber
  erStrgrabber
  erToggle
END ENUM

TYPE EditRule
  dataptr as any ptr  'It scares the heck out of me that I think this is the best solution
  mode as EditRuleMode
  lower as integer
  upper as integer
  group as integer    'Marks this rule as a member of a numbered group, the meaning of which is defined in the implementation
  helpkey as string   'actually appended to "sliceedit_" to get the full helpkey
END TYPE

'==============================================================================

REDIM SHARED editable_slice_types(5) as SliceTypes
editable_slice_types(0) = SlContainer
editable_slice_types(1) = SlRectangle
editable_slice_types(2) = SlSprite
editable_slice_types(3) = SlText
editable_slice_types(4) = SlGrid
editable_slice_types(5) = SlEllipse

'==============================================================================

CONST slgrPICKTYPE = 1
CONST slgrPICKXY = 2
CONST slgrPICKWH = 4
CONST slgrPICKCOL = 8
CONST slgrUPDATESPRITE = 16
CONST slgrUPDATERECTCOL = 32
CONST slgrUPDATERECTSTYLE = 64
CONST slgrPICKLOOKUP = 128
'--This system won't be able to expand forever ... :(

CONST slLOWCOLORCODE = -18

'==============================================================================

'This overload of slice_editor is only allowed locally.
'The other public overloads are in sliceedit.bi
DECLARE SUB slice_editor OVERLOAD (byref ses as SliceEditState, byref edslice as Slice Ptr, byval use_index as integer=0)

'Functions that might go better in slices.bas ... we shall see
DECLARE SUB DrawSliceAnts (byval sl as Slice Ptr, byval dpage as integer)

'Functions that use awkward adoption metaphors
DECLARE SUB SliceAdoptSister (byval sl as Slice Ptr)
DECLARE SUB AdjustSlicePosToNewParent (byval sl as Slice Ptr, byval newparent as Slice Ptr)
DECLARE SUB SliceAdoptNiece (byval sl as Slice Ptr)

'Functions only used locally
DECLARE SUB slice_editor_refresh (byref ses as SliceEditState, byref state as MenuState, menu() as SliceEditMenuItem, edslice as Slice Ptr, byref cursor_seek as Slice Ptr, slicelookup() as string)
DECLARE SUB slice_editor_refresh_delete (byref index as integer, menu() as SliceEditMenuItem)
DECLARE SUB slice_editor_refresh_append (byref index as integer, menu() as SliceEditMenuItem, caption as string, sl as Slice Ptr=0)
DECLARE SUB slice_editor_refresh_recurse (byref index as integer, menu() as SliceEditMenuItem, byref indent as integer, sl as Slice Ptr, rootslice as Slice Ptr, slicelookup() as string)
DECLARE SUB slice_edit_detail (sl as Slice Ptr, byref ses as SliceEditState, rootsl as Slice Ptr, slicelookup() as string)
DECLARE SUB slice_edit_detail_refresh (byref state as MenuState, menu() as string, sl as Slice Ptr, rules() as EditRule, slicelookup() as string)
DECLARE SUB slice_edit_detail_keys (byref state as MenuState, sl as Slice Ptr, rootsl as Slice Ptr, rules() as EditRule, slicelookup() as string)
DECLARE SUB slice_editor_xy (byref x as integer, byref y as integer, byval focussl as Slice Ptr, byval rootsl as Slice Ptr)
DECLARE FUNCTION slice_editor_filename(byref ses as SliceEditState) as string
DECLARE SUB slice_editor_load(byref edslice as Slice Ptr, filename as string)
DECLARE SUB slice_editor_save(byval edslice as Slice Ptr, filename as string)
DECLARE FUNCTION slice_lookup_code_caption(byval code as integer, slicelookup() as string) as string
DECLARE FUNCTION edit_slice_lookup_codes(slicelookup() as string, byval start_at_code as integer) as integer
DECLARE FUNCTION slice_caption (sl as Slice Ptr, slicelookup() as string) as string
DECLARE SUB slice_editor_copy(byref ses as SliceEditState, byval slice as Slice Ptr, byval edslice as Slice Ptr)
DECLARE SUB slice_editor_paste(byref ses as SliceEditState, byval slice as Slice Ptr, byval edslice as Slice Ptr)
DECLARE FUNCTION slice_color_caption(byval n as integer, ifzero as string="0") as string

'Functions that need to be aware of magic numbers for SliceType
DECLARE FUNCTION slice_edit_detail_browse_slicetype(byref slice_type as SliceTypes) as SliceTypes

'Slice EditRule convenience functions
DECLARE SUB sliceed_rule(rules() as EditRule, helpkey as String, mode as EditRuleMode, byval dataptr as any ptr, byval lower as integer=0, byval upper as integer=0, byval group as integer = 0)
DECLARE SUB sliceed_rule_tog(rules() as EditRule, helpkey as String, byval dataptr as integer ptr, byval group as integer=0)
DECLARE SUB sliceed_rule_none(rules() as EditRule, helpkey as String, byval group as integer = 0)

'==============================================================================

REDIM SHARED HorizCaptions(2) as string
HorizCaptions(0) = "Left"
HorizCaptions(1) = "Center"
HorizCaptions(2) = "Right"
REDIM SHARED VertCaptions(2) as string
VertCaptions(0) = "Top"
VertCaptions(1) = "Center"
VertCaptions(2) = "Bottom"
REDIM SHARED BorderCaptions(-2 TO -1) as string
BorderCaptions(-2) = "None"
BorderCaptions(-1) = "Line"
REDIM SHARED TransCaptions(0 TO 2) as string
TransCaptions(0) = "Solid"
TransCaptions(1) = "Fuzzy"
TransCaptions(2) = "Hollow"
REDIM SHARED AutoSortCaptions(0 TO 5) as string
AutoSortCaptions(0) = "None"
AutoSortCaptions(1) = "Custom"
AutoSortCaptions(2) = "by Y"
AutoSortCaptions(3) = "by top edge"
AutoSortCaptions(4) = "by center Y"
AutoSortCaptions(5) = "by bottom edge"

'==============================================================================

SUB slice_editor ()

 DIM ses as SliceEditState

 DIM edslice as Slice Ptr
 edslice = NewSlice
 WITH *edslice
  .Attach = slScreen
  .SliceType = slContainer
  .Fill = YES
 END WITH

 IF isfile(slice_editor_filename(ses)) THEN
  SliceLoadFromFile edslice, slice_editor_filename(ses)
 ELSEIF isfile(workingdir & SLASH & "slicetree_0.reld") THEN
  '--FIXME: this backcompat is of very low importance (probably only matters to James)
  '--and can be removed completely before Zenzizenzic
  SliceLoadFromFile edslice, workingdir & SLASH & "slicetree_0.reld"
  safekill workingdir & SLASH & "slicetree_0.reld"
 END IF

 slice_editor ses, edslice, YES

 slice_editor_save edslice, slice_editor_filename(ses)
 
 DeleteSlice @edslice

END SUB

SUB slice_editor (byref edslice as Slice Ptr)
 DIM ses as SliceEditState
 slice_editor ses, edslice, NO
END SUB

SUB slice_editor (byref ses as SliceEditState, byref edslice as Slice Ptr, byval use_index as integer=0)
 '--use_index controls the display of the collection number index

 '--use_index controls whether or not this is the indexed collection editor
 '--or the non-indexed single-collection editor
 ses.use_index = use_index
 
 '--save the dimensions of the outer container to restore them later
 ses.saved_pos.x = edslice->X
 ses.saved_pos.y = edslice->Y
 ses.saved_size.x = edslice->Width
 ses.saved_size.y = edslice->Height
 
 '--zero the position, in case we are editing an existing slice in full-screen
 edslice->X = 0
 edslice->Y = 0

 '--user-defined slice lookup codes
 REDIM slicelookup(10) as string
 load_string_list slicelookup(), workingdir & SLASH & "slicelookup.txt"

 REDIM menu(0) as SliceEditMenuItem
 REDIM plainmenu(0) as string 'FIXME: This is a hack because I didn't want to re-implement standardmenu right now

 DIM state as MenuState
 WITH state
  .spacing = 8
  .need_update = YES
 END WITH
 DIM menuopts as MenuOptions
 WITH menuopts
  .edged = YES
  .highlight = YES
 END WITH

 DIM cursor_seek as Slice Ptr = 0

 DIM slice_type as SliceTypes

 DIM filename as string
 
 DIM jump_to_collection as integer

 '--this early draw ensures that all the slices are updated before the loop starts
 DrawSlice edslice, dpage

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN
   IF ses.hide_menu THEN
    ses.hide_menu = NO
   ELSE
    EXIT DO
   END IF
  END IF
  #IFDEF IS_CUSTOM
   IF keyval(scF1) > 1 THEN show_help "sliceedit"
  #ELSE
   IF keyval(scF1) > 1 THEN show_help "sliceedit_game"
  #ENDIF
  IF keyval(scF4) > 1 THEN ses.hide_menu = NOT ses.hide_menu

  IF state.need_update = NO AND enter_space_click(state) THEN
   IF state.pt = 0 THEN
    EXIT DO
   ELSE
    cursor_seek = menu(state.pt).handle
    slice_edit_detail menu(state.pt).handle, ses, edslice, slicelookup()
    state.need_update = YES
   END IF 
  END IF
  IF ses.use_index THEN
   IF state.pt = 1 THEN
    '--Browse collections
    jump_to_collection = ses.collection_number
    IF intgrabber(jump_to_collection, 0, 32767, , , , NO) THEN  'Disable copy/pasting
     slice_editor_save edslice, slice_editor_filename(ses)
     ses.collection_number = jump_to_collection
     slice_editor_load edslice, slice_editor_filename(ses)
     state.need_update = YES
    END IF
   END IF
  END IF
  IF keyval(scF2) > 1 THEN
   filename = inputfilename("Export slice collection", ".slice", "", "input_filename_export_slices")
   IF filename <> "" THEN
    SliceSaveToFile edslice, filename & ".slice"
   END IF
  END IF
#IFDEF IS_CUSTOM
  IF ses.use_index THEN
   '--import is only allowed when regular index editing mode is enabled, and not in Game...
   IF keyval(scF3) > 1 THEN
    filename = browse(0, "", "*.slice", "",, "browse_import_slices")
    IF filename <> "" THEN
     slice_editor_load edslice, filename
     cursor_seek = NULL
     state.need_update = YES
    END IF
   END IF
  END IF
#ENDIF
  IF state.need_update = NO AND (keyval(scPlus) > 1 OR keyval(scNumpadPlus)) THEN
   IF slice_edit_detail_browse_slicetype(slice_type) THEN
    IF state.pt > ses.last_non_slice THEN
     InsertSliceBefore menu(state.pt).handle, NewSliceOfType(slice_type)
    ELSE
     cursor_seek = NewSliceOfType(slice_type, edslice)
    END IF
    state.need_update = YES
   END IF
  END IF

  IF state.need_update = NO THEN
   IF copy_keychord() THEN
    #IFDEF IS_GAME
     IF menu(state.pt).handle ANDALSO menu(state.pt).handle->Lookup < 0 THEN
      notification "Can't copy special slices!"
      CONTINUE DO
     END IF
    #ENDIF
    slice_editor_copy ses, menu(state.pt).handle, edslice
   ELSEIF paste_keychord() THEN
    slice_editor_paste ses, menu(state.pt).handle, edslice
    state.need_update = YES
   END IF
  END IF

  IF state.need_update = NO AND menu(state.pt).handle <> NULL THEN

   IF keyval(scDelete) > 1 THEN
    #IFDEF IS_GAME
     IF menu(state.pt).handle->Lookup < 0 THEN
      notification "Can't delete special slices!"
      CONTINUE DO
     END IF
    #ENDIF
    IF yesno("Delete this " & SliceTypeName(menu(state.pt).handle) & " slice?", NO) THEN
     slice_editor_refresh_delete state.pt, menu()
     state.need_update = YES
    END IF
   ELSEIF keyval(scF) > 1 THEN
    slice_editor menu(state.pt).handle

   ELSEIF keyval(scShift) > 0 THEN

    IF keyval(scUp) > 1 THEN
     SwapSiblingSlices menu(state.pt).handle, menu(state.pt).handle->PrevSibling
     cursor_seek = menu(state.pt).handle
     state.need_update = YES
    ELSEIF keyval(scDown) > 1 AND state.pt < state.last THEN
     SwapSiblingSlices menu(state.pt).handle, menu(state.pt).handle->NextSibling
     cursor_seek = menu(state.pt).handle
     state.need_update = YES
    ELSEIF keyval(scRight) > 1 THEN
     SliceAdoptSister menu(state.pt).handle
     cursor_seek = menu(state.pt).handle
     state.need_update = YES
    ELSEIF keyval(scLeft) > 1 THEN
     IF (menu(state.pt).handle)->parent <> edslice THEN
      SliceAdoptNiece menu(state.pt).handle
      cursor_seek = menu(state.pt).handle
      state.need_update = YES
     END IF
    END IF

   ELSEIF keyval(scCtrl) > 0 THEN '--ctrl, not shift

    IF keyval(scUp) > 1 THEN
     cursor_seek = menu(state.pt).handle->prevSibling
     state.need_update = YES
    ELSEIF keyval(scDown) > 1 THEN
     cursor_seek = menu(state.pt).handle->nextSibling
     state.need_update = YES
    ELSEIF keyval(scLeft) > 1 THEN
     cursor_seek = menu(state.pt).handle->parent
     state.need_update = YES
    ELSEIF keyval(scRight) > 1 THEN
     cursor_seek = menu(state.pt).handle->firstChild
     state.need_update = YES
    END IF

   ELSE '--neither shift nor ctrl

    IF keyval(scLeft) > 1 THEN
     cursor_seek = (menu(state.pt).handle)->parent
     state.need_update = YES
    END IF

   END IF

  END IF '--end IF state.need_update = NO AND menu(state.pt).handle

  ' Window size change
  IF UpdateScreenSlice() THEN state.need_update = YES

  IF state.need_update THEN
   state.size = vpages(dpage)->h / state.spacing - 4
   slice_editor_refresh(ses, state, menu(), edslice, cursor_seek, slicelookup())
   REDIM plainmenu(state.last) as string
   FOR i as integer = 0 TO UBOUND(plainmenu)
    plainmenu(i) = menu(i).s
   NEXT i
   state.need_update = NO
  ELSE
   usemenu state
  END IF

  clearpage dpage
  DrawSlice edslice, dpage
  IF state.pt > 0 THEN
   DrawSliceAnts menu(state.pt).handle, dpage
  END IF
  IF ses.hide_menu = NO THEN
   IF state.last > state.size THEN
    draw_fullscreen_scrollbar state, , dpage
   END IF
   standardmenu plainmenu(), state, 0, 0, dpage, menuopts
   edgeprint "+ to add a slice. SHIFT+arrows to sort", 0, vpages(dpage)->h - 10, uilook(uiText), dpage
  END IF

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 edslice->X = ses.saved_pos.x
 edslice->Y = ses.saved_pos.y
 edslice->Width = ses.saved_size.x
 edslice->Height = ses.saved_size.y

 '--free the clipboard if there is something in it
 IF ses.clipboard THEN DeleteSlice @ses.clipboard

END SUB

'--Returns whether one of the descendents is forbidden
FUNCTION slice_editor_forbidden_search(byval sl as Slice Ptr) as integer
 IF sl = 0 THEN RETURN NO
 IF sl->Lookup < 0 THEN RETURN YES
 IF int_array_find(editable_slice_types(), sl->SliceType) < 0 THEN RETURN YES
 IF slice_editor_forbidden_search(sl->FirstChild) THEN RETURN YES
 RETURN slice_editor_forbidden_search(sl->NextSibling)
END FUNCTION

SUB slice_editor_load(byref edslice as Slice Ptr, filename as string)
 DIM newcollection as Slice Ptr
 newcollection = NewSlice
 WITH *newcollection
  .Attach = slScreen
  .SliceType = slContainer
  .Fill = YES
 END WITH
 IF isfile(filename) THEN
  SliceLoadFromFile newcollection, filename
 END IF
 '--You can export slice collections from the in-game slice debugger. These
 '--collections are full of forbidden slices, so we must detect these and
 '--prevent importing. Attempting to do so instead will open a new editor.
 IF slice_editor_forbidden_search(newcollection) THEN
  notification "The slice collection you are trying to load includes special " _
               "slices (either due to their type or lookup code), probably " _
               "because it has been exported from a game. You aren't allowed " _
               "to import this collection, but it will be now be opened in " _
               "the slice collection editor so that you may view, edit, and reexport " _
               "it. Exit that editor to go back to your previous slice collection. " _
               "Try removing the special slices and exporting the collection; " _
               "you'll then be able to import normally."
  slice_editor newcollection
 ELSE
  DeleteSlice @edslice
  edslice = newcollection
 END IF
END SUB

SUB slice_editor_save(byval edslice as Slice Ptr, filename as string)
 IF edslice->NumChildren > 0 THEN
  '--save non-empty slice collections
  SliceSaveToFile edslice, filename
 ELSE
  '--erase empty slice collections
  safekill filename
 END IF
END SUB

SUB slice_editor_copy(byref ses as SliceEditState, byval slice as Slice Ptr, byval edslice as Slice Ptr)
 IF ses.clipboard THEN DeleteSlice @ses.clipboard
 DIM sl as Slice Ptr
 IF slice THEN
  ses.clipboard = NewSliceOfType(slContainer)
  sl = CloneSliceTree(slice)
  SetSliceParent sl, ses.clipboard
 ELSE
  ses.clipboard = CloneSliceTree(edslice)
 END IF
END SUB

'Insert pasted slices before 'slice'
SUB slice_editor_paste(byref ses as SliceEditState, byval slice as Slice Ptr, byval edslice as Slice Ptr)
 IF ses.clipboard THEN
  DIM child as Slice Ptr
  child = LastChild(ses.clipboard)
  WHILE child
   DIM copied as Slice Ptr = CloneSliceTree(child)
   IF slice THEN
    InsertSliceBefore slice, copied
   ELSE
    SetSliceParent copied, edslice
   END IF
   slice = copied
   child = child->PrevSibling
  WEND
 END IF
END SUB

SUB slice_edit_detail (sl as Slice Ptr, byref ses as SliceEditState, rootsl as Slice Ptr, slicelookup() as string)

 STATIC remember_pt as integer

 IF sl = 0 THEN EXIT SUB

 REDIM menu(0) as string
 REDIM rules(0) as EditRule

 DIM state as MenuState
 WITH state
  .pt = remember_pt
  .spacing = 8
  .size = 22
  .need_update = YES
 END WITH
 DIM menuopts as MenuOptions
 WITH menuopts
  .edged = YES
  .highlight = YES
 END WITH

 setkeys YES
 DO
  setwait 55
  setkeys YES
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "sliceedit_" & rules(state.pt).helpkey
  IF keyval(scF4) > 1 THEN ses.hide_menu = NOT ses.hide_menu

  IF UpdateScreenSlice() THEN state.need_update = YES

  IF state.need_update THEN
   slice_edit_detail_refresh state, menu(), sl, rules(), slicelookup()
   state.need_update = NO
   state.size = vpages(dpage)->h \ state.spacing - 1
  END IF

  usemenu state
  IF state.pt = 0 AND enter_space_click(state) THEN EXIT DO
  slice_edit_detail_keys state, sl, rootsl, rules(), slicelookup()
  
  clearpage dpage
  DrawSlice rootsl, dpage
  DrawSliceAnts sl, dpage
  IF ses.hide_menu = NO THEN
   standardmenu menu(), state, 0, 0, dpage, menuopts
  END IF

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 
 remember_pt = state.pt
 
END SUB

SUB slice_edit_detail_keys (byref state as MenuState, sl as Slice Ptr, rootsl as Slice Ptr, rules() as EditRule, slicelookup() as string)
 DIM rule as EditRule = rules(state.pt)
 SELECT CASE rule.mode
  CASE erIntgrabber
   DIM n as integer ptr = rule.dataptr
   IF intgrabber(*n, rule.lower, rule.upper, , , , , NO) THEN  'Don't autoclamp
    state.need_update = YES
   END IF
  CASE erToggle
   DIM n as integer ptr = rule.dataptr
   IF intgrabber(*n, -1, 0) THEN
    state.need_update = YES
   END IF
   IF enter_space_click(state) THEN *n = NOT *n : state.need_update = YES
  CASE erStrgrabber
   DIM s as string ptr = rule.dataptr
   IF keyval(scENTER) > 1 THEN
    *s = multiline_string_editor(*s, "sliceedit_text_multiline", NO)
    state.need_update = YES
   ELSE
    IF strgrabber(*s, 32767) THEN 'FIXME: this limit is totally arbitrary.
     state.need_update = YES
    END IF
   END IF
 END SELECT
 IF rule.group AND slgrPICKTYPE THEN
  DIM switchtype as integer = NO
  DIM slice_type as SliceTypes = sl->SliceType
  DIM slice_type_num as integer = -1
  FOR i as integer = 0 TO UBOUND(editable_slice_types)
   IF slice_type = editable_slice_types(i) THEN slice_type_num = i
  NEXT i
  '--Don't autoclamp, because slice_type_num may be -1
  IF intgrabber(slice_type_num, 0, UBOUND(editable_slice_types), , , , , NO) THEN
   slice_type = editable_slice_types(slice_type_num)
   state.need_update = YES
   switchtype = YES
  END IF
  IF enter_space_click(state) THEN
   IF slice_edit_detail_browse_slicetype(slice_type) THEN
    state.need_update = YES
    switchtype = YES
   END IF
  END IF
  IF switchtype THEN
   ReplaceSliceType sl, NewSliceOfType(slice_type)
   switchtype = NO
  END IF
 END IF
 IF rule.group AND slgrPICKXY THEN
  IF enter_space_click(state) THEN
   slice_editor_xy sl->X, sl->Y, sl, rootsl
   state.need_update = YES
  END IF
 END IF
 IF rule.group AND slgrPICKWH THEN
  IF enter_space_click(state) THEN
   slice_editor_xy sl->Width, sl->Height, sl, rootsl
   state.need_update = YES
  END IF
 END IF
 IF rule.group AND slgrPICKCOL THEN
  IF enter_space_click(state) THEN
   DIM n as integer ptr = rule.dataptr
   *n = color_browser_256(*n)
   state.need_update = YES
  END IF
 END IF
 IF rule.group AND slgrPICKLOOKUP THEN
  IF enter_space_click(state) THEN
   DIM n as integer ptr = rule.dataptr
   *n = edit_slice_lookup_codes(slicelookup(), *n)
   state.need_update = YES
  END IF
 END IF
 IF rule.group AND slgrUPDATESPRITE THEN
  IF state.need_update THEN
   'state.need_update is cleared at the top of the loop
   DIM dat as SpriteSliceData Ptr
   dat = sl->SliceData
   dat->loaded = NO
   dat->paletted = (dat->spritetype <> sprTypeMXS)
   WITH sprite_sizes(dat->spritetype)
    dat->record = small(dat->record, gen(.genmax) + .genmax_offset)
    dat->frame = small(dat->frame, .frames - 1)
   END WITH
  END IF
 END IF
 IF rule.group AND slgrUPDATERECTCOL THEN
  IF state.need_update THEN
   DIM dat as RectangleSliceData Ptr
   dat = sl->SliceData
   dat->style = -1
   dat->style_loaded = NO
  END IF
 END IF
 IF rule.group AND slgrUPDATERECTSTYLE THEN
  IF state.need_update THEN
   DIM dat as RectangleSliceData Ptr
   dat = sl->SliceData
   dat->style_loaded = NO
  END IF
 END IF
 IF state.need_update AND sl->SliceType = slText THEN
  UpdateTextSlice sl
 END IF
END SUB

FUNCTION slice_editor_filename(byref ses as SliceEditState) as string
 RETURN workingdir & SLASH & "slicetree_" & ses.collection_group_number & "_" & ses.collection_number & ".reld"
END FUNCTION

SUB slice_editor_xy (byref x as integer, byref y as integer, byval focussl as Slice Ptr, byval rootsl as Slice Ptr)
 DIM shift as integer = 0
 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF enter_or_space() THEN EXIT DO
  shift = ABS(keyval(scShift) > 0)
  IF keyval(scUp)    > 0 THEN y -= 1 + 9 * shift
  IF keyval(scRight) > 0 THEN x += 1 + 9 * shift
  IF keyval(scDown)  > 0 THEN y += 1 + 9 * shift
  IF keyval(scLeft)  > 0 THEN x -= 1 + 9 * shift
  clearpage dpage
  DrawSlice rootsl, dpage
  DrawSliceAnts focussl, dpage
  edgeprint "Arrow keys to edit, SHIFT for speed", 0, 190, uilook(uiText), dpage
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END SUB

SUB sliceed_rule(rules() as EditRule, helpkey as String, mode as EditRuleMode, byval dataptr as any ptr, byval lower as integer=0, byval upper as integer=0, byval group as integer = 0)
 DIM index as integer = UBOUND(rules) + 1
 REDIM PRESERVE rules(index) as EditRule
 WITH rules(index)
  .dataptr = dataptr
  .mode = mode
  .lower = lower
  .upper = upper
  .group = group
  .helpkey = helpkey
 END WITH 
END SUB

SUB sliceed_rule_none(rules() as EditRule, helpkey as String, byval group as integer = 0)
 sliceed_rule rules(), helpkey, erNone, 0, 0, 0, group
END SUB

SUB sliceed_rule_tog(rules() as EditRule, helpkey as String, byval dataptr as integer ptr, byval group as integer=0)
 sliceed_rule rules(), helpkey, erToggle, dataptr, -1, 0, group
END SUB

SUB slice_edit_detail_refresh (byref state as MenuState, menu() as string, sl as Slice Ptr, rules() as EditRule, slicelookup() as string)
 REDIM menu(6) as string
 REDIM rules(0) as EditRule
 rules(0).helpkey = "detail"
 menu(0) = "Previous Menu"
 WITH *sl
  menu(1) = "Slice type: " & SliceTypeName(sl)
  #IFDEF IS_CUSTOM
   sliceed_rule_none rules(), "slicetype", slgrPICKTYPE
  #ELSE
   '--If this is a special slice, then you're not allowed to change the type.
   IF .Lookup >= 0 THEN
    sliceed_rule_none rules(), "slicetype", slgrPICKTYPE
   ELSE
    sliceed_rule_none rules(), "slicetype"
   END IF
  #ENDIF
  menu(2) = "X: " & .X
  sliceed_rule rules(), "pos", erIntgrabber, @.X, -9999, 9999, slgrPICKXY
  menu(3) = "Y: " & .Y
  sliceed_rule rules(), "pos", erIntgrabber, @.Y, -9999, 9999, slgrPICKXY
  menu(4) = "Width: " & .Width
  sliceed_rule rules(), "size", erIntgrabber, @.Width, 0, 9999, slgrPICKWH
  menu(5) = "Height: " & .Height
  sliceed_rule rules(), "size", erIntgrabber, @.Height, 0, 9999, slgrPICKWH
  menu(6) = "Lookup code: " & slice_lookup_code_caption(.Lookup, slicelookup())
  #IFDEF IS_CUSTOM
   sliceed_rule rules(), "lookup", erIntgrabber, @.Lookup, 0, UBOUND(slicelookup), slgrPICKLOOKUP
  #ELSE
   IF .Lookup >= 0 THEN
    sliceed_rule rules(), "lookup", erIntgrabber, @.Lookup, 0, UBOUND(slicelookup), slgrPICKLOOKUP
   ELSE
    '--Not allow to change lookup code at all
    sliceed_rule_none rules(), "lookup"
   END IF
   str_array_append menu(), "Script handle: " & defaultint(.TableSlot, "None", 0)
   sliceed_rule_none rules(), "scripthandle"
  #ENDIF 
  SELECT CASE .SliceType
   CASE slRectangle
    DIM dat as RectangleSliceData Ptr
    dat = .SliceData
    str_array_append menu(), "Style: " & defaultint(dat->style, "None")
    sliceed_rule rules(), "rect_style", erIntgrabber, @(dat->style), -1, 14, slgrUPDATERECTSTYLE
    str_array_append menu(), "Background color: " & slice_color_caption(dat->bgcol)
    sliceed_rule rules(), "rect_bg", erIntgrabber, @(dat->bgcol), slLOWCOLORCODE, 255, (slgrUPDATERECTCOL OR slgrPICKCOL)
    str_array_append menu(), "Foreground color: " & slice_color_caption(dat->fgcol)
    sliceed_rule rules(), "rect_fg", erIntgrabber, @(dat->fgcol), slLOWCOLORCODE, 255, (slgrUPDATERECTCOL OR slgrPICKCOL)
    str_array_append menu(), "Border: " & caption_or_int(dat->border, BorderCaptions())
    sliceed_rule rules(), "rect_border", erIntgrabber, @(dat->border), -2, 14, slgrUPDATERECTCOL 
    str_array_append menu(), "Translucency: " & TransCaptions(dat->translucent)
    sliceed_rule rules(), "rect_trans", erIntgrabber, @(dat->translucent), 0, 2
    IF dat->translucent = 1 THEN
     str_array_append menu(), "Fuzziness: " & dat->fuzzfactor & "%"
     sliceed_rule rules(), "rect_fuzzfact", erIntgrabber, @(dat->fuzzfactor), 0, 99
    END IF
   CASE slText
    DIM dat as TextSliceData Ptr
    dat = .SliceData
    str_array_append menu(), "Text: " & dat->s
    sliceed_rule rules(), "text_text", erStrgrabber, @(dat->s), 0, 0
    str_array_append menu(), "Color: " & slice_color_caption(dat->col, "Default")
    sliceed_rule rules(), "text_color", erIntgrabber, @(dat->col), slLOWCOLORCODE, 255, slgrPICKCOL
    str_array_append menu(), "Outline: " & yesorno(dat->outline)
    sliceed_rule_tog rules(), "text_outline", @(dat->outline)
    str_array_append menu(), "Wrap: " & yesorno(dat->wrap)
    sliceed_rule_tog rules(), "text_wrap", @(dat->wrap)
    str_array_append menu(), "Background Color: " & slice_color_caption(dat->bgcol, "Default")
    sliceed_rule rules(), "text_bg", erIntgrabber, @(dat->bgcol), slLOWCOLORCODE, 255, slgrPICKCOL
   CASE slSprite
    DIM dat as SpriteSliceData Ptr
    dat = .SliceData
    DIM size as SpriteSize Ptr
    size = @sprite_sizes(dat->spritetype)
    str_array_append menu(), "Sprite Type: " & size->name
    sliceed_rule rules(), "sprite_type", erIntgrabber, @(dat->spritetype), 0, sprTypeLast, slgrUPDATESPRITE
    str_array_append menu(), "Sprite Number: " & dat->record
    sliceed_rule rules(), "sprite_rec", erIntgrabber, @(dat->record), 0, gen(size->genmax) + size->genmax_offset, slgrUPDATESPRITE
    IF dat->paletted THEN
     str_array_append menu(), "Sprite Palette: " & defaultint(dat->pal)
     sliceed_rule rules(), "sprite_pal", erIntgrabber, @(dat->pal), -1, gen(genMaxPal), slgrUPDATESPRITE
    END IF
    str_array_append menu(), "Sprite Frame: " & dat->frame
    sliceed_rule rules(), "sprite_frame", erIntgrabber, @(dat->frame), 0, size->frames - 1
    str_array_append menu(), "Flip horiz.: " & yesorno(dat->flipHoriz)
    sliceed_rule_tog rules(), "sprite_flip", @(dat->flipHoriz), slgrUPDATESPRITE
    str_array_append menu(), "Flip vert.: " & yesorno(dat->flipVert)
    sliceed_rule_tog rules(), "sprite_flip", @(dat->flipVert), slgrUPDATESPRITE
    str_array_append menu(), "Transparent: " & yesorno(dat->trans)
    sliceed_rule_tog rules(), "sprite_trans", @(dat->trans)
   CASE slGrid
    DIM dat as GridSliceData Ptr
    dat = .SliceData
    str_array_append menu(), "Rows: " & dat->rows
    sliceed_rule rules(), "grid_rows", erIntgrabber, @(dat->rows), 0, 99 'FIXME: upper limit of 99 is totally arbitrary
    str_array_append menu(), "Columns: " & dat->cols
    sliceed_rule rules(), "grid_cols", erIntgrabber, @(dat->cols), 0, 99 'FIXME: upper limit of 99 is totally arbitrary
    str_array_append menu(), "Show Grid: " & yesorno(dat->show)
    sliceed_rule_tog rules(), "grid_show", @(dat->show)
   CASE slEllipse
    DIM dat as EllipseSliceData Ptr
    dat = .SliceData
    str_array_append menu(), "Border Color: " & slice_color_caption(dat->bordercol, "transparent")
    sliceed_rule rules(), "bordercol", erIntgrabber, @(dat->bordercol), slLOWCOLORCODE, 255, slgrPICKCOL
    str_array_append menu(), "Fill Color: " & slice_color_caption(dat->fillcol, "transparent")
    sliceed_rule rules(), "fillcol", erIntgrabber, @(dat->fillcol), slLOWCOLORCODE, 255, slgrPICKCOL
  END SELECT
  str_array_append menu(), "Visible: " & yesorno(.Visible)
  sliceed_rule_tog rules(), "vis", @.Visible
  str_array_append menu(), "Fill Parent: " & yesorno(.Fill)
  sliceed_rule_tog rules(), "fill", @.Fill
  str_array_append menu(), "Clip Children: " & yesorno(.Clip)
  sliceed_rule_tog rules(), "clip", @.Clip
  IF .Fill = NO THEN
   str_array_append menu(), "Align horiz. with: " & HorizCaptions(.AlignHoriz)
   sliceed_rule rules(), "align", erIntgrabber, @.AlignHoriz, 0, 2
   str_array_append menu(), "Align vert. with: " & VertCaptions(.AlignVert)
   sliceed_rule rules(), "align", erIntgrabber, @.AlignVert, 0, 2
   str_array_append menu(), "Anchor horiz. on: " & HorizCaptions(.AnchorHoriz)
   sliceed_rule rules(), "anchor", erIntgrabber, @.AnchorHoriz, 0, 2
   str_array_append menu(), "Anchor vert. on: " & VertCaptions(.AnchorVert)
   sliceed_rule rules(), "anchor", erIntgrabber, @.AnchorVert, 0, 2
  END IF
  str_array_append menu(), "Padding Top: " & .PaddingTop
  sliceed_rule rules(), "padding", erIntgrabber, @.PaddingTop, -9999, 9999
  str_array_append menu(), "Padding Right: " & .PaddingRight
  sliceed_rule rules(), "padding", erIntgrabber, @.PaddingRight, -9999, 9999
  str_array_append menu(), "Padding Bottom: " & .PaddingBottom
  sliceed_rule rules(), "padding", erIntgrabber, @.PaddingBottom, -9999, 9999
  str_array_append menu(), "Padding Left: " & .PaddingLeft
  sliceed_rule rules(), "padding", erIntgrabber, @.PaddingLeft, -9999, 9999
  FOR i as integer = 0 TO 2
   str_array_append menu(), "Extra Data " & i & ": " & .Extra(i)
   sliceed_rule rules(), "extra", erIntgrabber, @.Extra(i), -2147483648, 2147483647
  NEXT
  sliceed_rule rules(), "autosort", erIntgrabber, @.AutoSort, 0, 5
  str_array_append menu(), "Auto-sort children: " & AutoSortCaptions(.AutoSort)
 END WITH
  
 state.last = UBOUND(menu)
 state.pt = small(state.pt, state.last)
 state.top = small(state.top, state.pt)
END SUB

FUNCTION slice_edit_detail_browse_slicetype(byref slice_type as SliceTypes) as SliceTypes

 DIM state as MenuState
 WITH state
  .last = UBOUND(editable_slice_types)
  .size = 22
 END WITH

 DIM menu(UBOUND(editable_slice_types)) as string
 FOR i as integer = 0 TO UBOUND(menu)
  menu(i) = SliceTypeName(editable_slice_types(i))
  IF editable_slice_types(i) = slice_type THEN state.pt = i
 NEXT i

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN RETURN NO
  IF keyval(scF1) > 1 THEN show_help "slicedit_browse_slicetype"

  usemenu state
  
  IF enter_space_click(state) THEN
   slice_type = editable_slice_types(state.pt)
   RETURN YES
  END IF
  
  clearpage dpage
  standardmenu menu(), state, 0, 0, dpage
 
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 RETURN NO 
END FUNCTION

FUNCTION slice_caption (sl as Slice Ptr, slicelookup() as string) as string
 'This shows the absolute screen position of a slice.
 DIM s as string
 WITH *sl
  s = .ScreenX & "," & .ScreenY & "(" & .Width & "x" & .Height & ")"
  s &= "${K" & uilook(uiText) & "} "
  IF .Lookup > 0 AND .Lookup <= UBOUND(slicelookup) THEN
   s &= slicelookup(.Lookup)
  ELSE
   s &= SliceLookupCodeName(.Lookup)
  END IF
 END WITH
 RETURN s
END FUNCTION

SUB slice_editor_refresh (byref ses as SliceEditState, byref state as MenuState, menu() as SliceEditMenuItem, edslice as Slice Ptr, byref cursor_seek as Slice Ptr, slicelookup() as string)
 FOR i as integer = 0 TO UBOUND(menu)
  menu(i).s = ""
 NEXT i
 DIM index as integer = 0

 'Refresh positions of all slices
 DrawSlice edslice, dpage

 DIM indent as integer = 0
 slice_editor_refresh_append index, menu(), "Previous Menu"
 ses.last_non_slice = 0
 IF ses.use_index THEN
  slice_editor_refresh_append index, menu(), CHR(27) & " Slice Collection " & ses.collection_number & " " & CHR(26)
  ses.last_non_slice += 1
 END IF
 slice_editor_refresh_recurse index, menu(), indent, edslice, edslice, slicelookup()

 IF cursor_seek <> 0 THEN
  FOR i as integer = 0 TO index - 1
   IF menu(i).handle = cursor_seek THEN
    state.pt = i
    cursor_seek = 0
    EXIT FOR
   END IF
  NEXT i
 END IF
 
 WITH state
  .last = index - 1
  .pt = small(.pt, .last)
  .top = bound(.top, .pt - .size, .pt)
 END WITH
END SUB

SUB slice_editor_refresh_delete (byref index as integer, menu() as SliceEditMenuItem)
 DeleteSlice @(menu(index).handle)
 FOR i as integer = index + 1 TO UBOUND(menu)
  SWAP menu(i), menu(i - 1)
 NEXT i
END SUB

SUB slice_editor_refresh_append (byref index as integer, menu() as SliceEditMenuItem, caption as string, sl as Slice Ptr=0)
 IF index > UBOUND(menu) THEN
  REDIM PRESERVE menu(index + 10) as SliceEditMenuItem
 END IF
 menu(index).s = caption
 menu(index).handle = sl
 index += 1
END SUB

SUB slice_editor_refresh_recurse (byref index as integer, menu() as SliceEditMenuItem, byref indent as integer, sl as Slice Ptr, rootslice as Slice Ptr, slicelookup() as string)
 WITH *sl
  DIM caption as string
  caption = STRING(indent, " ")
  caption = caption & SliceTypeName(sl)
  caption = caption & " " & slice_caption(sl, slicelookup())
  IF sl <> rootslice THEN
   slice_editor_refresh_append index, menu(), caption, sl
   indent += 1
  END IF
  'Now append the children
  DIM ch as slice ptr = .FirstChild
  DO WHILE ch <> 0
   slice_editor_refresh_recurse index, menu(), indent, ch, rootslice, slicelookup()
   ch = ch->NextSibling
  LOOP
  IF sl <> rootslice THEN
   indent -= 1
  END IF
 END WITH
END SUB

SUB SliceAdoptSister (byval sl as Slice Ptr)
 DIM newparent as Slice Ptr = sl->PrevSibling
 IF newparent = 0 THEN EXIT SUB ' Eldest sibling can't be adopted
 '--Adopt self to elder sister's family
 SetSliceParent sl, newparent
 AdjustSlicePosToNewParent sl, newparent
END SUB

SUB SliceAdoptNiece (byval sl as Slice Ptr)
 DIM oldparent as Slice Ptr = sl->Parent
 IF oldparent = 0 THEN EXIT SUB ' No parent
 DIM newparent as Slice Ptr = sl->Parent->Parent
 IF newparent = 0 THEN EXIT SUB ' No grandparent
 'Adopt self to parent's family
 SetSliceParent sl, newparent
 'Make sure that the slice is the first sibling after its old parent
 SwapSiblingSlices sl, oldparent->NextSibling
 AdjustSlicePosToNewParent sl, newparent
END SUB

SUB AdjustSlicePosToNewParent (byval sl as Slice Ptr, byval newparent as Slice Ptr)
 '--Re-adjust ScreenX/ScreenY position for new parent
 IF newparent->SliceType = slGrid THEN
  '--except if the new parent is a grid. Then it would be silly to preserve Screen pos.
  sl->X = 0
  sl->Y = 0
  EXIT SUB
 END IF
 DIM oldpos as XYPair
 oldpos.x = sl->ScreenX
 oldpos.y = sl->ScreenY
 RefreshSliceScreenPos sl
 DIM newpos as XYPair
 newpos.x = sl->ScreenX
 newpos.y = sl->ScreenY
 sl->X += oldpos.x - newpos.x
 sl->Y += oldpos.y - newpos.y
END SUB

SUB DrawSliceAnts (byval sl as Slice Ptr, byval dpage as integer)
 STATIC ant as integer = 0
 IF sl = 0 THEN EXIT SUB
 DIM col as integer
 '--Draw verticals
 FOR i as integer = small(0, sl->Height + 1) TO large(sl->Height - 1, 0)
  SELECT CASE (i + ant) MOD 3
   CASE 0: CONTINUE FOR
   CASE 1: col = uiLook(uiText)
   CASE 2: col = uiLook(uiBackground)
  END SELECT
  putpixel sl->ScreenX, sl->ScreenY + i, col, dpage
  putpixel sl->ScreenX + sl->Width + iif(sl->Width > 0, -1, 1), sl->ScreenY + i, col, dpage
 NEXT i
 '--Draw horizontals
 FOR i as integer = small(0, sl->Width + 1) TO large(sl->Width - 1, 0)
  SELECT CASE (i + ant) MOD 3
   CASE 0: CONTINUE FOR
   CASE 1: col = uiLook(uiText)
   CASE 2: col = uiLook(uiBackground)
  END SELECT
  putpixel sl->ScreenX + i, sl->ScreenY, col, dpage
  putpixel sl->ScreenX + i, sl->ScreenY + sl->Height + iif(sl->Height > 0, -1, 1), col, dpage
 NEXT i
 '--Draw gridlines if this is a grid
 IF sl->SliceType = slGrid THEN
  DIM dat as GridSliceData Ptr = sl->SliceData
  IF dat THEN
   DIM w as integer = sl->Width \ large(1, dat->cols)
   DIM h as integer = sl->Height \ large(1, dat->rows)
   '--draw verticals
   FOR i as integer = 1 TO dat->cols - 1
    FOR y as integer = 0 TO large(ABS(sl->Height) - 1, 2)
     SELECT CASE (y + ant) MOD 3
      CASE 0: CONTINUE FOR
      CASE 1: col = uiLook(uiText)
      CASE 2: col = uiLook(uiBackground)
     END SELECT
     putpixel sl->ScreenX + i * w, sl->ScreenY + y, col, dpage
    NEXT y
   NEXT i
   '--draw horizontals
   FOR i as integer = 1 TO dat->rows - 1
    FOR x as integer = 0 TO large(ABS(sl->Width) - 1, 2)
     SELECT CASE (x + ant) MOD 3
      CASE 0: CONTINUE FOR
      CASE 1: col = uiLook(uiText)
      CASE 2: col = uiLook(uiBackground)
     END SELECT
     putpixel sl->ScreenX + x, sl->ScreenY + i * h, col, dpage
    NEXT x
   NEXT i
  END IF
 END IF
 ant = loopvar(ant, 0, 2, 1)
END SUB

FUNCTION slice_lookup_code_caption(byval code as integer, slicelookup() as string) as string
 DIM s as string
 IF code = 0 THEN RETURN "None"
 IF code < 0 THEN
  '--negative codes are hard-coded slice code
  s = SliceLookupCodeName(code)
 ELSE
  s = STR(code)
  IF code <= UBOUND(slicelookup) THEN
   s = s & " " & slicelookup(code)
  END IF
 END IF
 RETURN s
END FUNCTION

FUNCTION edit_slice_lookup_codes(slicelookup() as string, byval start_at_code as integer) as integer

 DIM result as integer
 result = start_at_code
 
 '--temporarily put a menu label in string 0
 slicelookup(0) = "Previous Menu..."

 '--make the list longer so there will be at least one blank space at the end
 REDIM PRESERVE slicelookup(UBOUND(slicelookup) + 1) as string

 DIM state as MenuState
 WITH state
  .size = 24
  .last = UBOUND(slicelookup)
  IF start_at_code > 0 THEN
   '--start at the specified starting point
   .pt = start_at_code
  ELSE
   '--but if start_at_code is zero, then look for the first blank line
   FOR i as integer = 1 TO UBOUND(slicelookup)
    IF TRIM(slicelookup(i)) = "" THEN
     .pt = i
     EXIT FOR
    END IF
   NEXT i
  END IF
 END WITH
 DIM menuopts as MenuOptions
 menuopts.highlight = YES

 setkeys YES
 DO
  setwait 55
  setkeys YES
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "slice_lookup_codes"
  IF keyval(scEnter) > 1 THEN
   result = state.pt
   EXIT DO
  END IF

  usemenu state
  IF state.pt > 0 THEN
   IF strgrabber(slicelookup(state.pt), 40) THEN
    slicelookup(state.pt) = sanitize_script_identifier(slicelookup(state.pt))
   END IF
  END IF
  
  '--make the list longer if we have selected the last item in the list and it is not blank
  IF state.pt = UBOUND(slicelookup) ANDALSO TRIM(slicelookup(state.pt)) <> "" THEN
   REDIM PRESERVE slicelookup(UBOUND(slicelookup) + 1) as string
   state.last = UBOUND(slicelookup)
  END IF

  clearpage dpage
  draw_fullscreen_scrollbar state, , dpage
  standardmenu slicelookup(), state, 0, 0, dpage, menuopts

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 
 '--shrink the end of the list to exclude blank ones.
 DIM last as integer = UBOUND(slicelookup)
 FOR i as integer = UBOUND(slicelookup) TO 0 STEP -1
  IF TRIM(slicelookup(i)) <> "" THEN
   last = i
   EXIT FOR
  END IF
 NEXT i
 IF UBOUND(slicelookup) <> last THEN
  REDIM PRESERVE slicelookup(last) as string 
 END IF

 '--re-blank the 0 string
 slicelookup(0) = ""
 
 save_string_list slicelookup(), workingdir & SLASH & "slicelookup.txt"

 RETURN result
END FUNCTION

FUNCTION slice_color_caption(byval n as integer, ifzero as string="0") as string
 IF n = 0 THEN RETURN ifzero
 'Normal colors
 IF n > 0 ANDALSO n <= 255 THEN RETURN STR(n)
 'uilook colors
 IF n <= -1 ANDALSO n >= slLOWCOLORCODE THEN
  SELECT CASE (n * -1) - 1
   CASE uiBackground: RETURN "Background"
   CASE uiMenuItem: RETURN "Menu item"
   CASE uiDisabledItem: RETURN "Disabled menu item"
   CASE uiSelectedItem: RETURN "Selected item A"
   CASE uiSelectedItem2: RETURN "Selected item B"
   CASE uiSelectedDisabled: RETURN "Selected disabled A"
   CASE uiSelectedDisabled+1: RETURN "Selected disabled B"
   CASE uiHighlight: RETURN "Highlight A"
   CASE uiHighlight2: RETURN "Highlight B"
   CASE uiTimeBar: RETURN "Time bar"
   CASE uiTimeBarFull: RETURN "Time bar full"
   CASE uiHealthBar: RETURN "Health bar"
   CASE uiHealthBarFlash: RETURN "Health bar full"
   CASE uiText: RETURN "Text"
   CASE uiOutline: RETURN "Text outline"
   CASE uiDescription: RETURN "Spell description"
   CASE uiGold: RETURN "Money"
   CASE uiShadow: RETURN "Vehicle shadow"
  END SELECT
 END IF
 'Invalid values still print, but !?
 RETURN n & "(!?)"
END FUNCTION

