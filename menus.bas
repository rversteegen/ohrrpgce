'OHRRPGCE COMMON - Game/Custom shared menu code
'
'Please read LICENSE.txt for GNU GPL details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#include "config.bi"
#include "udts.bi"
#include "const.bi"
#include "scrconst.bi"
#include "allmodex.bi"
#include "common.bi"
#include "menus.bi"

#IFDEF IS_GAME
 #include "scriptcommands.bi"
#ENDIF

'Local functions
DECLARE SUB LoadMenuItems(menu_set as MenuSet, dat as MenuDef, byval record as integer)
DECLARE SUB LoadMenuItem(byval f as integer, items() as MenuDefItem ptr, byval record as integer)
DECLARE SUB SaveMenuItems(menu_set as MenuSet, dat as MenuDef, byval record as integer)
DECLARE SUB SaveMenuItem(byval f as integer, mi as MenuDefItem, byval record as integer, byval menunum as integer, byval itemnum as integer)

'TypeTables
DEFINE_VECTOR_OF_CLASS(BasicMenuItem, BasicMenuItem)
DEFINE_VECTOR_OF_CLASS(SimpleMenuItem, SimpleMenuItem)
DEFINE_VECTOR_OF_CLASS(MenuDefItem, MenuDefItem)

' If > 0, enable mouse controls of menus even if running a game that has disabled that.
' This can be incremented while we are inside a debug/engine menu (to allow nesting).
DIM force_use_mouse as integer = 0


'==========================================================================================
'                                 Generic MenuState Stuff
'==========================================================================================


'(Re-)initialise menu state, preserving .pt if valid
'.pt is moved to a selectable menu item.
'FIXME: sets state.has_been_drawn = YES although state.rect is wrong
SUB init_menu_state (byref state as MenuState, menu() as SimpleMenuItem, menuopts as MenuOptions = MenuOptions())
 calc_menustate_size state, menuopts, 0, 0  'Position not known, fill with dummy data for now

 WITH state
  .first = 0
  .last = UBOUND(menu)
  IF .size <= 0 THEN .size = 20
  .hover = -1
  .pt = bound(.pt, .first, .last)  '.first <= .last
  IF menu(.pt).unselectable THEN
   .pt = -1  'explicitly -1 when nothing selectable
   FOR i as integer = 0 TO UBOUND(menu)
    IF menu(i).unselectable = NO THEN .pt = i: EXIT FOR
   NEXT
  END IF
  'Menus with unselectable items have lookahead, which these +1,-1
  'attempt to simulate. Not perfect, but prevents some flickering
  '(TODO: modify correct_menu_state and all usemenu overloads to do this too)
  IF .pt <> -1 THEN .top = bound(.top, .pt - .size + 1, .pt - 1)
  .top = bound(.top, 0, large(.last - .size, 0))
 END WITH
END SUB

'(Re-)initialise menu state, preserving .pt if valid
'.pt is moved to a selectable menu item.
'
'menu may in fact be a vector of any type inheriting from BasicMenuItem.
'menu's typetable tells the size in bytes of each menu item
'FIXME: sets state.has_been_drawn = YES although state.rect is wrong
SUB init_menu_state (byref state as MenuState, byval menu as BasicMenuItem vector, menuopts as MenuOptions = MenuOptions())
 calc_menustate_size state, menuopts, 0, 0  'Position not known, fill with dummy data for now

 WITH state
  .first = 0
  .last = v_len(menu) - 1
  IF .size <= 0 THEN .size = 20
  .hover = -1
  .pt = bound(.pt, .first, .last)  '.first <= .last
  IF v_at(menu, .pt)->unselectable THEN
   .pt = -1  'explicitly -1 when nothing selectable
   FOR i as integer = 0 TO v_len(menu) - 1
    IF v_at(menu, i)->unselectable = NO THEN .pt = i: EXIT FOR
   NEXT
  END IF
  'Menus with unselectable items have lookahead, which these +1,-1
  'attempt to simulate. Not perfect, but prevents some flickering
  '(TODO: modify correct_menu_state and all usemenu overloads to do this too)
  IF .pt <> -1 THEN .top = bound(.top, .pt - .size + 1, .pt - 1)
  .top = bound(.top, 0, large(.last - .size, 0))
 END WITH
END SUB

SUB recalc_menu_size (byref state as MenuState)
 'Run this once per frame for a menu that should fill the whole screen vertically
 'Does not work unless .spacing is set correctly (set on call to standardmenu)
 WITH state
  IF .spacing = 0 THEN
   ' This error is currently impossible
   IF .has_been_drawn = YES THEN debugc errBug, "recalc_menu_size: .spacing didn't get set"
   EXIT SUB
  END IF
  DIM ignorepix as integer = .autosize_ignore_pixels + .autosize_ignore_lines * large(.spacing, 10)
  .size = (vpages(dpage)->h - ignorepix) \ .spacing - 1
 END WITH
END SUB

'Simple... and yet, more options than a regular menu item
'Can also insert instead of appending... bad name
SUB append_simplemenu_item (byref menu as SimpleMenuItem vector, caption as string, byval unselectable as bool = NO, byval col as integer = 0, byval dat as integer = 0, byval where as integer = -1)
 IF where = -1 THEN
  v_expand menu, 1
  where = v_len(menu) - 1
 END IF
 WITH menu[where]
  .text = caption
  .col = col
  .bgcol = 0
  .unselectable = unselectable
  .disabled = NO
  .dat = dat
 END WITH
END SUB

FUNCTION find_menu_item_at_point (state as MenuState, x as integer, y as integer) as integer
 'If the on-screen position overlaps a MenuState, return the index of the menu item it is touching.
 'Return a value < state.first if it's not on any menu item.
 WITH state
  IF .has_been_drawn THEN
   DIM mpt as integer = rect_collide_point_vertical_chunk(.rect, XY(x, y), .spacing)
   IF mpt > -1 THEN
    mpt += .top
    ' Need to check against size, as there might be a few pixels inside .rect after
    ' the last visible menu item, where the next item isn't drawn
    IF mpt >= .first ANDALSO mpt <= .last ANDALSO mpt <= .top + .size THEN
     RETURN mpt
    END IF
   END IF
  END IF
  RETURN .first - 1 'Mouse is not over a menu item!
 END WITH
END FUNCTION

' Updates state.hover, and returns YES if the mouse is over the menu.
' (You only need this if not calling usemenu or scrollmenu)
FUNCTION mouse_update_hover (state as MenuState) as bool
 DIM use_mouse as bool = YES
#IFDEF IS_GAME
 use_mouse = get_gen_bool("/mouse/mouse_menus") OR (force_use_mouse > 0)
#ENDIF
 IF use_mouse ANDALSO readmouse.active THEN
  state.hover = find_menu_item_at_point(state, readmouse.x, readmouse.y)
  RETURN state.hover >= state.first
 ELSE
  state.hover = state.first - 1
 END IF
 RETURN NO
END FUNCTION

' Updates state.pt. This should be called only after mouse_update_hover has
' updated state.hover and returned YES, if state.hover is a selectable item.
SUB mouse_update_selection (state as MenuState)
 IF (readmouse.buttons OR readmouse.release) AND (mouseleft OR mouseright) THEN
  state.pt = state.hover
 END IF
END SUB

' This does a subset of what usemenu does, call this after modifying .pt, .last, .first or .size
' if not immediately calling usemenu.
SUB correct_menu_state (state as MenuState)
 WITH state
  .pt = small(large(.pt, .first), .last)  '=last when last<first, ie. menu empty
  ' If the bottom of the menu is above the bottom of the screen, scroll up
  .top = large(small(.top, .last - .size), .first)
  ' Selected item must be visible (unless the menu is empty)
  IF .pt >= .first THEN .top = bound(.top, .pt - .size, .pt)
  mouse_update_hover state
 END WITH
END SUB

' Adjust .top and .pt according to mouse wheel input.
SUB mouse_scroll_menu(byref state as MenuState)
 WITH state
  DIM lasttop as integer = large(.first, .last - .size)
  IF .hover >= .first THEN  'Mouse over the menu
   IF (readmouse().buttons AND mouseRight) = 0 THEN  'While right button down, scroll wheel affects intgrabber
    .top = bound(.top + (4 * readmouse().wheel_delta) \ 120, .first, lasttop)
    ' Make sure .pt is visible
    .pt = bound(.pt, .top, .top + .size)
   END IF
  END IF
 END WITH
END SUB

FUNCTION usemenu (byref state as MenuState, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
 WITH state
  IF .autosize THEN
   recalc_menu_size state
  END IF

  DIM oldptr as integer = .pt
  DIM oldtop as integer = .top

  IF .first < .last THEN
   IF keyval(deckey) > 1 THEN loopvar .pt, .first, .last, -1
   IF keyval(inckey) > 1 THEN loopvar .pt, .first, .last, 1
   IF keyval(scPageup) > 1 THEN .pt -= .size
   IF keyval(scPagedown) > 1 THEN .pt += .size
   IF keyval(scHome) > 1 THEN .pt = .first
   IF keyval(scEnd) > 1 THEN .pt = .last
  END IF
  correct_menu_state state  'Update .top and .pt

  IF mouse_update_hover(state) THEN mouse_update_selection(state)
  mouse_scroll_menu state

  IF oldptr = .pt AND oldtop = .top THEN
   RETURN NO
  ELSE
   negative_zero = NO 'Reset for intgrabber
   RETURN YES
  END IF

 END WITH
END FUNCTION

FUNCTION usemenu (byref pt as integer, byref top as integer, byval first as integer, byval last as integer, byval size as integer, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
 'FIXME: eventually phase this out by making sure that all callers to usemenu have their own MenuState
 DIM state as MenuState
 WITH state
  .pt = pt
  .top = top
  .first = first
  .last = last
  .size = size
 END WITH
 DIM result as bool = usemenu(state, deckey, inckey)
 WITH state
  pt = .pt
  top = .top
  first = .first
  last = .last
  size = .size
 END WITH
 RETURN result
END FUNCTION

'a version for menus with unselectable items, skip items for which menudata[i].unselectable = YES
'menu may in fact be a vector of any type inheriting from BasicMenuItem.
'menu's typetable tells the size in bytes of each menu item
FUNCTION usemenu (state as MenuState, byval menudata as BasicMenuItem vector, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
 WITH state
  IF .autosize THEN
   recalc_menu_size state
  END IF
  '.pt = -1 when the menu has no selectable items
  IF .pt = -1 THEN RETURN NO

  DIM as integer oldptr, oldtop, d, moved_d
  oldptr = .pt
  oldtop = .top
  d = 0
  moved_d = 0

  IF keyval(deckey) > 1 THEN d = -1
  IF keyval(inckey) > 1 THEN d = 1
  IF keyval(scPageup) > 1 THEN
   .pt = large(.pt - .size, .first)
   WHILE v_at(menudata, .pt)->unselectable AND .pt > .first : loopvar(.pt, .first, .last, -1) : WEND
   IF v_at(menudata, .pt)->unselectable THEN d = 1
   moved_d = -1
  END IF
  IF keyval(scPagedown) > 1 THEN
   .pt = small(.pt + .size, .last)
   WHILE v_at(menudata, .pt)->unselectable AND .pt < .last : loopvar(.pt, .first, .last, 1) : WEND
   IF v_at(menudata, .pt)->unselectable THEN d = -1
   moved_d = 1
  END IF
  IF keyval(scHome) > 1 THEN .pt = .last : d = 1
  IF keyval(scEnd) > 1 THEN .pt = .first : d = -1

  IF d THEN 
   moved_d = d
   DO
    .top = bound(.top, .pt - .size, .pt)
    loopvar .pt, .first, .last, d
   LOOP WHILE v_at(menudata, .pt)->unselectable
  END IF

  IF moved_d THEN
   'we look ahead of the actual cursor, to bring unselectable items at the ends of the menu into view
   DIM lookahead as integer = .pt
   DO
    lookahead += moved_d
   LOOP WHILE bound(lookahead, .first, .last) = lookahead ANDALSO v_at(menudata, lookahead)->unselectable
   lookahead = bound(lookahead, .first, .last)
   .top = bound(.top, lookahead - .size, lookahead)
  END IF
  correct_menu_state state  'Update .top

  IF mouse_update_hover(state) ANDALSO NOT v_at(menudata, .hover)->unselectable THEN
   mouse_update_selection(state)
  END IF
  mouse_scroll_menu state

  IF oldptr = .pt AND oldtop = .top THEN
   RETURN NO
  ELSE
   negative_zero = NO 'Reset for intgrabber
   RETURN YES
  END IF
 END WITH
END FUNCTION

'a version for menus with unselectable items, skip items for which selectable(i) = 0
FUNCTION usemenu (state as MenuState, selectable() as bool, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
 WITH state
  IF .autosize THEN
   recalc_menu_size state
  END IF
  '.pt = -1 when the menu has no selectable items
  IF .pt = -1 THEN RETURN NO

  DIM as integer oldptr, oldtop, d, moved_d
  oldptr = .pt
  oldtop = .top
  d = 0
  moved_d = 0

  IF keyval(deckey) > 1 THEN d = -1
  IF keyval(inckey) > 1 THEN d = 1
  IF keyval(scPageup) > 1 THEN
   .pt = large(.pt - .size, .first)
   WHILE selectable(.pt) = 0 AND .pt > .first : loopvar(.pt, .first, .last, -1) : WEND
   IF selectable(.pt) = 0 THEN d = 1
   moved_d = -1
  END IF
  IF keyval(scPagedown) > 1 THEN
   .pt = small(.pt + .size, .last)
   WHILE selectable(.pt) = 0 AND .pt < .last : loopvar(.pt, .first, .last, 1) : WEND
   IF selectable(.pt) = 0 THEN d = -1
   moved_d = 1
  END IF
  IF keyval(scHome) > 1 THEN .pt = .last : d = 1
  IF keyval(scEnd) > 1 THEN .pt = .first : d = -1

  IF d THEN
   moved_d = d
   DO
    .top = bound(.top, .pt - .size, .pt)
    loopvar .pt, .first, .last, d
   LOOP WHILE selectable(.pt) = 0
  END IF

  IF moved_d THEN
   'we look ahead of the actual cursor, to bring unselectable items at the ends of the menu into view
   DIM lookahead as integer = .pt
   DO
    lookahead += moved_d
   LOOP WHILE bound(lookahead, .first, .last) = lookahead ANDALSO selectable(lookahead) = 0
   lookahead = bound(lookahead, .first, .last)
   .top = bound(.top, lookahead - .size, lookahead)
  END IF
  correct_menu_state state  'Update .top

  IF mouse_update_hover(state) ANDALSO selectable(.hover) THEN
   mouse_update_selection(state)
  END IF
  mouse_scroll_menu state

  IF oldptr = .pt AND oldtop = .top THEN
   RETURN NO
  ELSE
   negative_zero = NO 'Reset for intgrabber
   RETURN YES
  END IF
 END WITH
END FUNCTION

'scrollmenu is like usemenu for menus where no menu item is selected:
'you just want to scroll a menu up and down (modifies .top; .pt is ignored).
'Returns true when view changed.
FUNCTION scrollmenu (state as MenuState, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
 WITH state
  IF .autosize THEN
   recalc_menu_size state
  END IF
  DIM oldtop as integer = .top
  DIM lasttop as integer = large(.first, .last - .size)
  IF keyval(deckey) > 1 THEN loopvar .top, .first, lasttop, -1
  IF keyval(inckey) > 1 THEN loopvar .top, .first, lasttop, 1
  IF keyval(scPageup) > 1 THEN .top = large(.first, .top - .size)
  IF keyval(scPagedown) > 1 THEN .top = small(lasttop, .top + .size)
  IF keyval(scHome) > 1 THEN .top = .first
  IF keyval(scEnd) > 1 THEN .top = lasttop
  mouse_update_hover(state)
  mouse_scroll_menu(state)
  RETURN (.top <> oldtop)
 END WITH
END FUNCTION

SUB standard_to_basic_menu (menu() as string, byref state as MenuState, byref basicmenu as BasicMenuItem vector, byval shaded as bool ptr = NULL)
 v_new basicmenu, state.last - state.first + 1
 FOR i as integer = 0 TO state.last - state.first
  WITH basicmenu[i]
   .text = menu(state.first + i)
   .col = 0  'Default, usually uilook(uiMenuItem)
   IF shaded THEN
    .disabled = shaded[state.first + i]
   END IF
  END WITH
 NEXT
END SUB

' For standardmenu only. Not to be confused with recalc_menu_size, which only sets MenuState.size.
' Initialises/updates size and position data in MenuState, including .rect, and .size
' if .autosize is true.
' Used if you want to calculate the size of the menu before the first call to standardmenu,
' but unless you're using menuopts.calc_size, calling init_menu_state is sufficient.
' (Note: 'menu' is optional, needed only to calculate width.)
' Sets .has_been_drawn=YES to indicate that these members have been initialised,
' even if not called from standardmenu.
SUB calc_menustate_size(state as MenuState, menuopts as MenuOptions, x as RelPos, y as RelPos, page as integer = -1, menu as BasicMenuItem vector = NULL)
 IF page = -1 THEN page = vpage
 WITH state
  .has_been_drawn = YES
  IF menuopts.edged THEN .spacing = 9 ELSE .spacing = 8
  .spacing += menuopts.itemspacing

  ' TODO: calc_menustate_size used to call recalc_menu_size unconditionally. So still
  ' need to call it if .size is 0. But would be cleaner to just default .autosize to YES
  IF .autosize OR (.size = 0) THEN
   ' Calculate .size.
   ' usemenu also calls recalc_menu_size, but usemenu might not be called if the
   ' menu is inactive (more than one on-screen), and on the first tick with
   ' .autosize=YES before .spacing is set the correct .size won't be known either.
   ' (In that case, you should call init_menu_state, passing menuopts if used.)
   recalc_menu_size state
  END IF

  ' Width
  DIM wide as integer = menuopts.wide
  IF menuopts.calc_size ANDALSO menu THEN
   ' Widen the menu according to widest menu item
   FOR i as integer = 0 TO small(v_len(menu) - 1, .last)
    wide = large(wide, textwidth(v_at(menu, i)->text))
   NEXT
   IF menuopts.scrollbar THEN wide += 6
  END IF
  .rect.wide = small(vpages(page)->w, wide)

  ' Height
  DIM num_menu_items as integer
  IF menuopts.calc_size THEN
   num_menu_items = .last - .first + 1
  ELSE
   num_menu_items = .size + 1
  END IF
  .rect.high = small(vpages(page)->h, num_menu_items * .spacing)

  ' Now position the menu, and clamp to screen size
  .rect.x = relative_pos(x, vpages(page)->w, .rect.wide)
  .rect.y = relative_pos(y, vpages(page)->h, .rect.high)
  .rect.wide = small(.rect.wide, vpages(page)->w - .rect.x)
  .rect.high = small(.rect.high, vpages(page)->h - .rect.y)
 END WITH
END SUB

SUB standardmenu (menu() as string, byref state as MenuState, x as RelPos, y as RelPos, page as integer, menuopts as MenuOptions)
 DIM basicmenu as BasicMenuItem vector
 standard_to_basic_menu menu(), state, basicmenu
 'Shift menu items so that state.first = 0
 DIM first as integer = state.first
 state.top -= first
 state.pt -= first
 state.hover -= first
 state.last -= first
 state.first = 0
 standardmenu basicmenu, state, x, y, page, menuopts
 state.top += first
 state.pt += first
 state.hover += first
 state.last += first
 state.first = first
 v_free basicmenu
END SUB

'Version which allows items to be greyed out/disabled/shaded
SUB standardmenu (menu() as string, byref state as MenuState, shaded() as bool, x as RelPos, y as RelPos, page as integer, menuopts as MenuOptions)
 IF LBOUND(shaded) > LBOUND(menu) OR UBOUND(shaded) < UBOUND(menu) THEN fatalerror "standardmenu: shaded() too small"
 DIM basicmenu as BasicMenuItem vector
 standard_to_basic_menu menu(), state, basicmenu, @shaded(0)
 'Shift menu items so that state.first = 0
 DIM first as integer = state.first
 state.top -= first
 state.pt -= first
 state.hover -= first
 state.last -= first
 state.first = 0
 standardmenu basicmenu, state, x, y, page, menuopts
 state.top += first
 state.pt += first
 state.hover += first
 state.last += first
 state.first = first
 v_free basicmenu
END SUB

'Draws an undecorated menu (just lines of coloured text, and optionally a scrollbar), as used throughout Custom.
'(The in-game user-customisable menus are drawn with draw_menu.)
'menu may in fact be a vector of any type inheriting from BasicMenuItem:
' standardmenu cast(BasicMenuItem vector, menu), ...
'The vector's internal typetable tells the size in bytes of each menu item
SUB standardmenu (byval menu as BasicMenuItem vector, state as MenuState, x as RelPos, y as RelPos, page as integer, menuopts as MenuOptions)

 IF state.first <> 0 THEN
  'The following doesn't affect simple string array menus which are converted to BasicMenuItem menus
  showerror "Programmer error: standardmenu: state.first <> 0 not supported for BasicMenuItem menus!"
  EXIT SUB
 END IF

 calc_menustate_size state, menuopts, x, y, page, menu
 DIM wide as integer = state.rect.wide
 'calc_menustate_size solved from RelPos to screen positions
 x = state.rect.x
 y = state.rect.y

 IF state.active THEN
  state.tog XOR= 1
 END IF

 IF menuopts.scrollbar THEN
  draw_scrollbar state, state.rect, 0, page
 ELSEIF menuopts.fullscreen_scrollbar THEN
  draw_fullscreen_scrollbar state, 0, page
 END IF

 DIM rememclip as ClipState = cliprect
 shrinkclip x, , x + wide - 1, , vpages(page)

 FOR i as integer = state.top TO state.top + state.size
  IF i < v_len(menu) THEN
   WITH *v_at(menu, i)

    DIM linewidth as integer = textwidth(.text)
    IF .bgcol THEN
     rectangle x + 0, y, wide, 8, .bgcol, page
    END IF
    IF state.pt = i AND state.active AND menuopts.highlight <> NO THEN
     rectangle x + 0, y, IIF(linewidth, linewidth, 9999), 8, uilook(uiHighlight), page
    END IF
    DIM col as integer = .col
    IF .disabled THEN
     IF .col = 0 THEN col = uilook(uiDisabledItem)
     IF state.pt = i AND state.active THEN
      col = uilook(uiSelectedDisabled + state.tog)
     'A menu item with the .disabled colour may or may not be selectable, so not clear what to do
     ' ELSEIF state.hover = i AND state.active THEN
     '  col = uilook(uiMouseHoverItem)
     END IF
    ELSE
     IF .col = 0 THEN col = uilook(uiMenuItem)
     IF state.pt = i AND state.active THEN
      col = uilook(uiSelectedItem + state.tog)
     ELSEIF state.hover = i AND state.active THEN
      col = uilook(uiMouseHoverItem)
     END IF
    END IF
    DIM drawx as integer = x
    IF linewidth > wide AND state.active THEN
     IF state.pt = i OR menuopts.showright THEN
      drawx = x + wide - linewidth
     END IF
    END IF
    IF menuopts.edged THEN
     edgeprint .text, drawx, y, col, page, YES
    ELSE
     textcolor col, 0
     printstr .text, drawx, y, page, YES
    END IF
    y += state.spacing
   END WITH
  END IF
 NEXT i

 cliprect = rememclip
END SUB


'==========================================================================================
'                                   Selection by typing
'==========================================================================================


CONST SELECT_TYPE_TIMEOUT as double = 0.7

'If the user typed something, returns YES and set select_query to a search string, to be used
'with e.g. INSTR or find_on_word_boundary_excluding, or select_on_word_boundary[_excluding]
'which handles all the details.
'Special care required on menus using strgrabber, or even intgrabber.
'Generally you should pass accept_numbers=NO on menus using intgrabber.
'Example usage:
'  setkeys YES
'
'  IF select_by_typing(selectst) THEN
'   select_on_word_boundary menu(), selectst, state
'  END IF
'
'  highlight_menu_typing_selection menu(), menu_display(), selectst, state
'  standardmenu menu_display(), state, 0, 0, dpage 
'
FUNCTION select_by_typing(selectst as SelectTypeState, byval allow_numbers as bool = YES) as bool
 WITH selectst
  IF TIMER - .last_input_time > SELECT_TYPE_TIMEOUT THEN
   select_clear selectst
  END IF
  DIM intext as string = getinputtext
  IF LEN(intext) = 0 THEN RETURN NO
  'Only test first character for simplicity
  IF allow_numbers = NO ANDALSO (isdigit(intext[0]) ORELSE intext[0] = ASC("-")) THEN RETURN NO
  .last_input_time = TIMER

  .buffer += LCASE(intext)
  'If user has just typed the same character repeatedly, only search by that, otherwise by whole input
  '...unless the user is entering a number
  IF isdigit(.buffer[0]) THEN
   .query = .buffer
  ELSE
   .query = LEFT(.buffer, 1)
   FOR i as integer = 0 TO LEN(.buffer) - 1
    IF .buffer[i] <> .query[0] THEN
     .query = .buffer
     EXIT FOR
    END IF
   NEXT
  END IF
  RETURN YES
 END WITH
END FUNCTION

'Manually set select_by_typing state to inactive
SUB select_clear(selectst as SelectTypeState)
 selectst.buffer = ""
 selectst.query = ""
 selectst.highlight_at = 1
END SUB

'Copies contents of menu() to menu_display(), with text markup added to highlight
'text matching selectst.query.
'The calling menu should set selectst.query_at to the offset in menu(state.pt) which matches
'the query, or 0 if no match, after doing text matching after calling select_by_typing.
'Can also set query_at to -1 for an invisible match (no highlighting)
'(The select_on_word_boundary SUB handles this.)
'
'Idea: could highlight all matches rather than just one on the current line
SUB highlight_menu_typing_selection(menu() as string, menu_display() as string, selectst as SelectTypeState, state as MenuState)
 'If the user moves the cursor normally, reset
 '(Yes, this is a rather regretable function in which to put this)
 IF selectst.remember_pt <> state.pt THEN select_clear selectst
 selectst.remember_pt = state.pt

 FOR i as integer = LBOUND(menu) TO UBOUND(menu)
  menu_display(i) = menu(i)
 NEXT

 menu_display(state.pt) = highlight_menu_typing_selection_string(menu(state.pt), selectst)
END SUB

SUB highlight_menu_typing_selection(byref menu as BasicMenuItem vector, byref menu_display as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState)
 'Works with any type derived from BasicMenuItem.
 'If the user moves the cursor normally, reset
 '(Yes, this is a rather regretable function in which to put this)
 IF selectst.remember_pt <> state.pt THEN select_clear selectst
 selectst.remember_pt = state.pt

 IF state.first <> 0 OR v_len(menu) - 1 <> state.last THEN debugc errPromptBug, "highlight_menu_typing_selection: bad MenuState"
 v_copy menu_display, menu

 v_at(menu_display, state.pt)->text = highlight_menu_typing_selection_string(v_at(menu, state.pt)->text, selectst)
END SUB

'Internal function sometimes useful if a menu doesn't use a string array to store menu items
FUNCTION highlight_menu_typing_selection_string(z as string, selectst as SelectTypeState) as string
 WITH selectst
  'Initialisation
  IF .highlight_at = 0 THEN .highlight_at = 1

  IF .query_at THEN
   .highlight_at = .query_at
  END IF

  IF .highlight_at > 0 AND LEN(.query) > 0 THEN
   'Length of .query that matches the text
   DIM match_len as integer
   FOR i as integer = .highlight_at TO LEN(z)
    IF tolower(z[i - 1]) <> .query[i - .highlight_at] THEN EXIT FOR
    match_len += 1
   NEXT
   'In order to have something visible, highlight first character
   'on a failed match... unless it's part of a markup tag
   IF match_len = 0 ANDALSO LEFT(z, 2) <> "${" THEN match_len = 1

   'FIXME: should add a set of Custom-only UI colours instead of using these
   DIM col as integer
   IF .query_at THEN
    col = uilook(uiHighlight2)
   ELSE
    col = uilook(uiSelectedDisabled)
   END IF

   RETURN MID(z, 1, .highlight_at - 1) _
          & bgcol_text(MID(z, .highlight_at, match_len), col) _
          & MID(z, .highlight_at + match_len)
  END IF
  RETURN z
 END WITH
END FUNCTION


'==========================================================================================
'                               MenuSearch function family
'==========================================================================================


FUNCTION MenuSearcher.text(byval index as integer) as string
 IF this.menu_array THEN
  RETURN this.menu_array[index]
 ELSE
  RETURN v_at(this.menu_vector, index)->text
 END IF
END FUNCTION

FUNCTION MenuSearcher.selectable(byval index as integer) as bool
 IF this.menu_array THEN
  RETURN YES
 ELSE
  RETURN NOT v_at(this.menu_vector, index)->unselectable
 END IF
END FUNCTION

'Possibilities for MenuSearcher.findfunc

FUNCTION MenuSearcher_find_word_boundary(this as MenuSearcher, itemtext as string, query as string) as integer
 RETURN find_on_word_boundary_excluding(LCASE(itemtext), query, this.excludeword)
END FUNCTION

FUNCTION MenuSearcher_find_instr(this as MenuSearcher, itemtext as string, query as string) as integer
 RETURN INSTR(LCASE(itemtext), query)
END FUNCTION

'End possibilities

CONSTRUCTOR MenuSearcher(menu() as string)
 this.menu_array = @menu(0)
END CONSTRUCTOR

CONSTRUCTOR MenuSearcher(byval menu_vector as BasicMenuItem vector)
 this.menu_vector = menu_vector
END CONSTRUCTOR

'Internal generic implementation for select_* functions
SUB select_menuitem(searcher as MenuSearcher, selectst as SelectTypeState, state as MenuState)
 DIM index as integer = state.pt
 IF LEN(selectst.query) = 1 THEN loopvar index, state.first, state.last
 FOR ctr as integer = state.first TO state.last
  selectst.query_at = searcher.findfunc(searcher, searcher.text(index), selectst.query)
  IF selectst.query_at THEN
   'index may be an unselectable menu item. However moving the cursor to a selectable item
   'doesn't act nicely. Ideal solution would be to add and use selectst.highlight_pt, but
   'that's too much work to bother, so just allow selecting unselectable items for now.
   'WHILE NOT searcher.selectable(index)
   ' loopvar index, state.first, state.last
   'WEND
   state.pt = index
   selectst.remember_pt = state.pt
   EXIT FOR
  END IF
  loopvar index, state.first, state.last
 NEXT
END SUB

'Search menu() for a match to the typed query string using find_on_word_boundary_excluding.
'Use in combination with select_by_typing and optionally highlight_menu_typing_selection
SUB select_on_word_boundary_excluding(menu() as string, selectst as SelectTypeState, state as MenuState, excludeword as string)
 DIM searcher as MenuSearcher = MenuSearcher(menu())
 searcher.findfunc = @MenuSearcher_find_word_boundary
 searcher.excludeword = excludeword
 select_menuitem searcher, selectst, state
END SUB

SUB select_on_word_boundary(menu() as string, selectst as SelectTypeState, state as MenuState)
 select_on_word_boundary_excluding menu(), selectst, state, ""
END SUB

'Works with any type derived from BasicMenuItem.
SUB select_on_word_boundary_excluding(byval menu as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState, excludeword as string)
 DIM searcher as MenuSearcher = MenuSearcher(menu)
 searcher.findfunc = @MenuSearcher_find_word_boundary
 searcher.excludeword = excludeword
 select_menuitem searcher, selectst, state
END SUB

SUB select_on_word_boundary(byval menu as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState)
 select_on_word_boundary_excluding menu, selectst, state, ""
END SUB

'Search menu() for a match to the typed query string using INSTR.
'Use in combination with select_by_typing and optionally highlight_menu_typing_selection
SUB select_instr(menu() as string, selectst as SelectTypeState, state as MenuState)
 DIM searcher as MenuSearcher = MenuSearcher(menu())
 searcher.findfunc = @MenuSearcher_find_instr
 select_menuitem searcher, selectst, state
END SUB


'==========================================================================================
'                                         MenuDef
'==========================================================================================


'This initialises a menu if it has not been already
SUB ClearMenuData(dat as MenuDef)
 DIM bits(0) as integer
 WITH dat
  .record = -1
  .handle = 0
  .name = ""
  .boxstyle = 0
  .textcolor = 0
  .maxrows = 0
  .offset.x = 0
  .offset.y = 0
  .anchorhoriz = alignCenter
  .anchorvert = alignCenter
  .alignhoriz = alignCenter
  .alignvert = alignCenter
  .textalign = alignCenter
  .min_chars = 0
  .max_chars = 0
  .bordersize = 0
  .itemspacing = 0
  IF .items THEN
   DeleteMenuItems dat
  END IF
 END WITH
 bits(0) = 0
 MenuBitsFromArray dat, bits()
END SUB

'Initialise a MenuDef so that it looks like a plain menu, as drawn by standardmenu
SUB InitLikeStandardMenu(menu as MenuDef)
 ClearMenuData menu
 WITH menu
  .no_box = YES
  .textalign = alignLeft
  .alignhoriz = alignLeft
  .alignvert = alignTop
  .anchorhoriz = alignLeft
  .anchorvert = alignTop
  .min_chars = 9999  'Fill screen
  'border should be -8 to be like standardmenu, but drawing the menu at 4,4 looks better
  .bordersize = -4
  .itemspacing = -1
  .withtags = YES
 END WITH
END SUB

SUB DeleteMenuItems(menu as MenuDef)
 DIM i as integer
 WITH menu
  FOR i = 0 TO .numitems - 1
   menu.remove(.items[i]
   DELETE .items[i]
  NEXT i
  DEALLOCATE(.items)
  .items = NULL
 END WITH
END SUB

'recreate a menu's items[] array, which sorts visible items to the top
SUB SortMenuItems(menu as MenuDef)
 DIM as integer i, j, lowest, found
 DIM mi as MenuDefItem ptr
 IF menu.numitems = 0 THEN
  DEALLOCATE(menu.items)
  menu.items = NULL
  EXIT SUB
 END IF
 menu.items = REALLOCATE(menu.items, SIZEOF(any ptr) * menu.numitems)
 'stick all visible items in .items[]
 i = 0
 mi = menu.first
 WHILE mi
  IF (mi->disabled AND mi->hide_if_disabled) = 0 THEN
   menu.items[i] = mi
   i += 1
  END IF
  mi = mi->trueorder.next
 WEND
 'append all invisible items
 mi = menu.first
 WHILE mi
  IF mi->disabled AND mi->hide_if_disabled THEN
   menu.items[i] = mi
   i += 1
  END IF
  mi = mi->trueorder.next
 WEND
END SUB

FUNCTION getmenuname(byval record as integer) as string
 DIM as string ret
#IFDEF IS_GAME
 STATIC cache(32) as IntStrPair
 ret = search_string_cache(cache(), record, game_unique_id)
 IF ret <> "" THEN RETURN ret
#ENDIF

 DIM menu_set as MenuSet
 menu_set.menufile = workingdir + SLASH + "menus.bin"
 menu_set.itemfile = workingdir + SLASH + "menuitem.bin"
 DIM menu as MenuDef
 LoadMenuData menu_set, menu, record, YES
 ret = menu.name
 ClearMenuData menu

#IFDEF IS_GAME
 add_string_cache cache(), record, ret
#ENDIF
 RETURN ret
END FUNCTION

'(Re-)initialise menu state, preserving .pt if valid
'FIXME: sets state.has_been_drawn = YES although state.rect is wrong
SUB init_menu_state (byref state as MenuState, menu() as string, menuopts as MenuOptions)
 calc_menustate_size state, menuopts, 0, 0  'Position not known, fill with dummy data for now

 WITH state
  .first = LBOUND(menu)
  .last = UBOUND(menu)
  'FIXME: what is this doing here? It doesn't match what calc_menustate_size does
  .size = small(.last - .first, cint(int(get_resolution().h / 8)))
 END WITH
 ' Fix .pt and update .top
 correct_menu_state state
END SUB

'(Re-)initialise menu state, preserving .pt if valid or otherwise picking a new one.
'Also sorts the menu.
SUB init_menu_state (byref state as MenuState, menu as MenuDef)
 WITH state
  .first = 0
  .last = count_menu_items(menu) - 1
  .size = menu.maxrows - 1
  IF .size = -1 THEN .size = 17
 END WITH
 ' Pick a suitable .pt
 sort_menu_and_select_visible_item menu, state
 ' Update .top
 correct_menu_state state
END SUB

' Make sure .pt is valid, move it to the next visible menu item if the current one is hidden.
' This only works correctly if you haven't already called SortMenuItems!
' Does no update .top (not a substitute for correct_menu_state).
' Note that this is a substitue for what usemenu does, but is specific to MenuDef's
' troublesome shuffling of hidden of menu items to the end.
SUB sort_menu_and_select_visible_item(menu as MenuDef, state as MenuState)
 WITH menu
  DIM selecteditem as MenuDefItem ptr
  IF state.pt >= 0 AND state.pt < .numitems THEN
   selecteditem = .items[state.pt]
  ELSE
   selecteditem = NULL
  END IF
  SortMenuItems menu
  ' First forwards look for the next visible item
  WHILE selecteditem ANDALSO (selecteditem->disabled AND selecteditem->hide_if_disabled)
   selecteditem = cvar(selecteditem, selecteditem->next)
  WEND
  IF selecteditem THEN
   FOR i as integer = 0 TO .numitems - 1
    IF .items[i] = selecteditem THEN
     state.pt = i
     EXIT SUB
    END IF
   NEXT i
  END IF
  ' otherwise pick the last visible one
  FOR i as integer = .numitems - 1 TO 0 STEP -1
   IF (.items[i]->disabled AND .items[i]->hide_if_disabled) = NO THEN
    state.pt = i
    EXIT SUB
   END IF
  NEXT
  ' The menu is empty
  state.pt = -1
 END WITH
END SUB

' Returns index in menu.items[]
FUNCTION append_menu_item(byref menu as MenuDef, caption as string, byval t as integer=0, byval sub_t as integer=0, byval dataptr as ANY ptr=0) as integer
 DIM i as integer
 DIM item as MenuDefItem ptr
 item = NEW MenuDefItem
 WITH *item
  .caption = caption
  .t = t
  .sub_t = sub_t
  .dataptr = dataptr
 END WITH

 menu.append(item) 'updates .numitems

 'rather than call SortMenuItems, shuffle hidden items down a slot and insert new item
 menu.items = REALLOCATE(menu.items, menu.numitems * SIZEOF(any ptr))
 FOR i = menu.numitems - 2 TO 0 STEP -1  'last item in array is garbage
  IF menu.items[i]->disabled AND menu.items[i]->hide_if_disabled THEN
   SWAP menu.items[i], menu.items[i + 1]
  ELSE
   EXIT FOR
  END IF
 NEXT
 menu.items[i + 1] = item

 RETURN menu.numitems - 1
END FUNCTION

SUB remove_menu_item(byref menu as MenuDef, byval mi as MenuDefItem ptr)
 menu.remove(mi)
 DELETE mi
 'rebuild menu.items[]
 SortMenuItems menu
END SUB

SUB remove_menu_item(byref menu as MenuDef, byval mislot as integer)
 remove_menu_item menu, menu.items[mislot]
END SUB

SUB swap_menu_items(byref menu1 as MenuDef, byval mislot1 as integer, byref menu2 as MenuDef, byval mislot2 as integer)
 dlist_swap(menu1, menu1.items[mislot1], menu2, menu2.items[mislot2])
 SortMenuItems menu1
 SortMenuItems menu2
END SUB


'==========================================================================================
'                        Saving/Loading/(De)serializing MenuDefs
'==========================================================================================

Destructor MenuDef ()
 DeleteMenuItems this
End Destructor

FUNCTION MenuDef.last() as MenuDefItem ptr
 RETURN cast(MenuDefItem ptr, base.last)
END FUNCTION

SUB LoadMenuData(menu_set as MenuSet, dat as MenuDef, byval record as integer, byval ignore_items as integer=NO)
 DIM f as integer
 DIM bits(0) as integer
 IF record > gen(genMaxMenu) OR record < 0 THEN
  ClearMenuData dat
  EXIT SUB
 END IF
 OPENFILE(menu_set.menufile, FOR_BINARY, f)
 SEEK #f, record * getbinsize(binMENUS) + 1
 WITH dat
  .record = record
  .name = ReadByteStr(f, 20)
  .boxstyle = ReadShort(f)
  .textcolor = ReadShort(f)
  .maxrows = ReadShort(f)
  bits(0) = ReadShort(f)
  MenuBitsFromArray dat, bits()
  .offset.x = ReadShort(f)
  .offset.y = ReadShort(f)
  .alignhoriz = alignCenter       ' Not saved
  .alignvert = alignCenter        ' ditto
  .anchorhoriz = ReadShort(f) + 1 ' On-disk enum is -1,0,1
  .anchorvert = ReadShort(f) + 1  ' ditto
  .textalign = ReadShort(f) + 1   ' ditto
  .min_chars = ReadShort(f)
  .max_chars = ReadShort(f)
  .bordersize = ReadShort(f)
  .on_close = ReadShort(f)
  .esc_menu = ReadShort(f)
  ReadShort(f)  'garbage INT
  .itemspacing = ReadShort(f)
  IF .items THEN
   DeleteMenuItems dat
  END IF
 END WITH
 CLOSE #f
 IF ignore_items = NO THEN 'This is disableable for performance when all you care about loading is the menu's name
  LoadMenuItems menu_set, dat, record
 END IF
END SUB

SUB LoadMenuItems(menu_set as MenuSet, menu as MenuDef, byval record as integer)
 DIM i as integer
 DIM f as integer
 DIM member as integer
 DIM actual_record_count as integer = 0
 'The items may appear out-of-order in menuitem.bin, so rather than just append them as
 'we find the, first we store them in this temp array:
 REDIM itemarray(0) as MenuDefItem ptr

 OPENFILE(menu_set.itemfile, FOR_BINARY, f)
 'FIXME: this shouldn't be here, it's covered in upgrade() (but commented out currently)
 actual_record_count = LOF(f) / getbinsize(binMENUITEM)
 IF actual_record_count <> gen(genMaxMenuItem) + 1 THEN
  debug "menuitem.bin record count sanity check failed " & gen(genMaxMenuItem) & "->" & actual_record_count - 1
  gen(genMaxMenuItem) = actual_record_count - 1
 END IF
 FOR i = 0 TO gen(genMaxMenuItem)
  SEEK #f, i * getbinsize(binMENUITEM) + 1
  member = ReadShort(f)
  IF member = record + 1 THEN
   LoadMenuItem f, itemarray(), i
  END IF
 NEXT i
 CLOSE #f

 'build the item list
 FOR i = 0 TO UBOUND(itemarray)
  IF itemarray(i) <> NULL THEN
   menu.append(itemarray(i))
  ELSE
   'can't create a zero length FB array
   IF UBOUND(itemarray) <> 0 THEN
    debug "menu " & record & " item " & i & " could not be found in " & menu_set.itemfile
   END IF
  END IF
 NEXT
 'build the items[] array
 SortMenuItems menu
END SUB

SUB LoadMenuItem(byval f as integer, items() as MenuDefItem ptr, byval record as integer)
 DIM i as integer
 DIM bits(0) as integer
 DIM mi as MenuDefItem ptr
 DIM itemnum as integer
 mi = NEW MenuDefItem
 SEEK #f, record * getbinsize(binMENUITEM) + 1
 WITH *mi
  ReadShort(f) 'throw away member
  .caption = ReadByteStr(f, 38)
  itemnum = ReadShort(f)
  .t = ReadShort(f)
  .sub_t = ReadShort(f)
  .tag1 = ReadShort(f)
  .tag2 = ReadShort(f)
  .settag = ReadShort(f)
  .togtag = ReadShort(f)
  bits(0) = ReadShort(f)
  FOR i = 0 TO 2
   .extra(i) = ReadShort(f)
  NEXT i
 END WITH
 IF itemnum > UBOUND(items) THEN REDIM PRESERVE items(itemnum)
 items(itemnum) = mi
 MenuItemBitsFromArray *mi, bits()
END SUB

SUB SaveMenuData(menu_set as MenuSet, dat as MenuDef, byval record as integer)
 DIM f as integer
 DIM bits(0) as integer
 OPENFILE(menu_set.menufile, FOR_BINARY, f)
 SEEK #f, record * getbinsize(binMENUS) + 1
 WITH dat
  WriteByteStr(f, 20, .name)
  WriteShort(f, -1, .boxstyle)
  WriteShort(f, -1, .textcolor)
  WriteShort(f, -1, .maxrows)
  MenuBitsToArray dat, bits()
  WriteShort(f, -1, bits(0))
  WriteShort(f, -1, .offset.x)
  WriteShort(f, -1, .offset.y)
  WriteShort(f, -1, .anchorhoriz - 1) ' On-disk enum is -1,0,1
  WriteShort(f, -1, .anchorvert - 1)  ' ditto  
  WriteShort(f, -1, .textalign - 1)   ' ditto
  WriteShort(f, -1, .min_chars)
  WriteShort(f, -1, .max_chars)
  WriteShort(f, -1, .bordersize)
  WriteShort(f, -1, .on_close)
  WriteShort(f, -1, .esc_menu)
  WriteShort(f, -1, 0)  'wasted garbage INT
  WriteShort(f, -1, .itemspacing)
 END WITH
 CLOSE #f
 SaveMenuItems menu_set, dat, record
END SUB

SUB SaveMenuItems(menu_set as MenuSet, menu as MenuDef, byval record as integer)
 DIM i as integer
 DIM f as integer
 DIM member as integer
 DIM elem as integer = 0
 DIM mi as MenuDefItem ptr
 DIM blankmi as MenuDefItem
 
 OPENFILE(menu_set.itemfile, FOR_BINARY, f)
 'Loop through each record and orphan all old entries for this menu
 FOR i = 0 TO gen(genMaxMenuItem)
  SEEK #f, i * getbinsize(binMENUITEM) + 1
  member = ReadShort(f)
  IF member = record + 1 THEN
   SaveMenuItem f, blankmi, i, -1, 0
  END IF
 NEXT i
 'Loop through each record, writing new values into orphan slots
 mi = menu.first
 FOR i = 0 TO gen(genMaxMenuItem)
  SEEK #f, i * getbinsize(binMENUITEM) + 1
  member = ReadShort(f)
  IF member = 0 THEN
   IF mi = NULL THEN EXIT FOR
   SaveMenuItem f, *mi, i, record, elem
   elem = elem + 1
   mi = mi->trueorder.next
  END IF
 NEXT i
 DO WHILE mi
  'More items need to be written, append them
  gen(genMaxMenuItem) += 1
  SaveMenuItem f, *mi, gen(genMaxMenuItem), record, elem
  elem += 1
  mi = mi->trueorder.next
 LOOP
 CLOSE #f
END SUB

SUB SaveMenuItem(byval f as integer, mi as MenuDefItem, byval record as integer, byval menunum as integer, byval itemnum as integer)
 DIM i as integer
 DIM bits(0) as integer
 SEEK #f, record * getbinsize(binMENUITEM) + 1
 WITH mi
  WriteShort(f, -1, menunum + 1)
  WriteByteStr(f, 38, .caption)
  WriteShort(f, -1, itemnum)
  WriteShort(f, -1, .t)
  WriteShort(f, -1, .sub_t)
  WriteShort(f, -1, .tag1)
  WriteShort(f, -1, .tag2)
  WriteShort(f, -1, .settag)
  WriteShort(f, -1, .togtag)
  MenuItemBitsToArray mi, bits()
  WriteShort(f, -1, bits(0))
  FOR i = 0 TO 2
   WriteShort(f, -1, .extra(i))
  NEXT i
 END WITH
END SUB

SUB MenuBitsToArray (menu as MenuDef, bits() as integer)
 bits(0) = 0
 WITH menu
  setbit bits(), 0, 0, .translucent
  setbit bits(), 0, 1, .no_scrollbar
  setbit bits(), 0, 2, .allow_gameplay
  setbit bits(), 0, 3, .suspend_player
  setbit bits(), 0, 4, .no_box
  setbit bits(), 0, 5, .no_close
  setbit bits(), 0, 6, .no_controls
  setbit bits(), 0, 7, .prevent_main_menu
  setbit bits(), 0, 8, .advance_textbox
  setbit bits(), 0, 9, .highlight_selection
  setbit bits(), 0, 10, .remember_selection
 END WITH
END SUB

SUB MenuBitsFromArray (menu as MenuDef, bits() as integer)
 WITH menu
  .translucent    = xreadbit(bits(), 0)
  .no_scrollbar   = xreadbit(bits(), 1)
  .allow_gameplay = xreadbit(bits(), 2)
  .suspend_player = xreadbit(bits(), 3)
  .no_box         = xreadbit(bits(), 4)
  .no_close       = xreadbit(bits(), 5)
  .no_controls    = xreadbit(bits(), 6)
  .prevent_main_menu = xreadbit(bits(), 7)
  .advance_textbox   = xreadbit(bits(), 8)
  .highlight_selection = xreadbit(bits(), 9)
  .remember_selection = xreadbit(bits(), 10)
 END WITH
END SUB

SUB MenuItemBitsToArray (mi as MenuDefItem, bits() as integer)
 bits(0) = 0
 WITH mi
  setbit bits(), 0, 0, .hide_if_disabled
  setbit bits(), 0, 1, .close_if_selected
  setbit bits(), 0, 2, .skip_close_script
 END WITH
END SUB

SUB MenuItemBitsFromArray (mi as MenuDefItem, bits() as integer)
 WITH mi
  .hide_if_disabled  = xreadbit(bits(), 0)
  .close_if_selected = xreadbit(bits(), 1)
  .skip_close_script = xreadbit(bits(), 2)
 END WITH
END SUB

FUNCTION read_menu_int (menu as MenuDef, byval intoffset as integer) as integer
 '--This function allows read access to integers in a menu for the plotscripting interface
 '--intoffset is the integer offset, same as appears in the MENUS.BIN lump documentation
 DIM bits(0) as integer
 WITH menu
  SELECT CASE intoffset
   CASE 12: RETURN .boxstyle
   CASE 13: RETURN .textcolor
   CASE 14: RETURN .maxrows
   CASE 15:
    MenuBitsToArray menu, bits()
    RETURN bits(0)
   CASE 16: RETURN .offset.x
   CASE 17: RETURN .offset.y
   CASE 18: RETURN .anchorhoriz - 1 ' Translate to align: constants
   CASE 19: RETURN .anchorvert - 1  ' ditto
   CASE 20: RETURN .textalign - 1   ' ditto
   CASE 21: RETURN .min_chars
   CASE 22: RETURN .max_chars
   CASE 23: RETURN .bordersize
   CASE 24: RETURN .on_close
   CASE 25: RETURN .esc_menu
   CASE ELSE
    debug "read_menu_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
 RETURN 0
END FUNCTION

SUB write_menu_int (menu as MenuDef, byval intoffset as integer, byval n as integer)
 '--This sub allows write access to integers in a menu for the plotscripting interface
 '--FIXME: there's no error checking, not even in the wrapper scripts in plotscr.hsd!
 '--intoffset is the integer offset, same as appears in the MENUS.BIN lump documentation
 DIM bits(0) as integer
 WITH menu
  SELECT CASE intoffset
   CASE 12: .boxstyle = n
   CASE 13: .textcolor = n
   CASE 14: .maxrows = n
   CASE 15:
    bits(0) = n
    MenuBitsFromArray menu, bits()
   CASE 16: .offset.x = n
   CASE 17: .offset.y = n
   CASE 18: .anchorhoriz = n + 1 ' Translate from align: constants
   CASE 19: .anchorvert = n + 1  ' ditto
   CASE 20: .textalign = n + 1   ' ditto
   CASE 21: .min_chars = n
   CASE 22: .max_chars = n
   CASE 23: .bordersize = n
   CASE 24: .on_close = n
   CASE 25: .esc_menu = n
   CASE ELSE
    debug "write_menu_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
END SUB

FUNCTION read_menu_item_int (mi as MenuDefItem, byval intoffset as integer) as integer
 '--This function allows read access to integers in a menu item for the plotscripting interface
 '--intoffset is the integer offset, same as appears in the MENUITEM.BIN lump documentation
 DIM bits(0) as integer
 WITH mi
  SELECT CASE intoffset
   CASE 22: RETURN .t
   CASE 23: RETURN .sub_t
   CASE 24: RETURN .tag1
   CASE 25: RETURN .tag2
   CASE 26: RETURN .settag
   CASE 27: RETURN .togtag
   CASE 28:
    MenuItemBitsToArray mi, bits()
    RETURN bits(0)
   CASE 29 TO 31: RETURN .extra(intoffset - 29)
   CASE ELSE
    debug "read_menu_item_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
 RETURN 0
END FUNCTION

SUB write_menu_item_int (mi as MenuDefItem, byval intoffset as integer, byval n as integer)
 '--This sub allows write access to integers in a menu item for the plotscripting interface
 '--intoffset is the integer offset, same as appears in the MENUITEM.BIN lump documentation
 DIM bits(0) as integer
 WITH mi
  SELECT CASE intoffset
   CASE 22: .t = n
   CASE 23: .sub_t = n
   CASE 24: .tag1 = n
   CASE 25: .tag2 = n
   CASE 26: .settag = n
   CASE 27: .togtag = n
   CASE 28:
    bits(0) = n
    MenuItemBitsFromArray mi, bits()
   CASE 29 TO 31: .extra(intoffset - 29) = n
   CASE ELSE
    debug "write_menu_item_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
END SUB


'==========================================================================================
'                                    Drawing MenuDefs
'==========================================================================================


SUB draw_menu (menu as MenuDef, state as MenuState, byval page as integer)
 DIM i as integer
 DIM elem as integer
 DIM col as integer
 DIM where as XYPair
 DIM metermax as integer

 'Update the caption of each menu item
 FOR i = 0 TO menu.numitems - 1
  menu.items[i]->text = get_menu_item_caption(*menu.items[i], menu)
 NEXT

 position_menu menu, page

 DIM bord as integer = 8 + menu.bordersize
 WITH state
  .has_been_drawn = YES
  .rect.x = menu.rect.x + bord
  .rect.y = menu.rect.y + bord
  .rect.wide = menu.rect.wide - bord * 2
  .rect.high = menu.rect.high - bord * 2
  .spacing = 10 + menu.itemspacing
 END WITH

 IF menu.no_box = NO THEN
  WITH menu.rect
   edgeboxstyle .x, .y, .wide, .high, menu.boxstyle, page, menu.translucent
  END WITH
 END IF

 state.tog = state.tog XOR 1
 DIM selected as integer

 'First draw the highlight rectangle, if any, behind the items
 IF menu.highlight_selection THEN
  i = state.pt - state.top
  IF i >= 0 AND i <= state.size THEN
   where = menu.rect.topleft + XY(4, bord + i * (10 + menu.itemspacing))
   rectangle where.x, where.y, menu.rect.wide - 8, 10, uiLook(uiHighlight), page
  END IF
 END IF

 IF menu.no_scrollbar = NO THEN
  draw_scrollbar state, menu, page
 END IF

 'Draw the items
 FOR i = 0 TO state.size
  selected = NO
  elem = state.top + i
  IF elem >= 0 AND elem < menu.numitems THEN
   col = menu.textcolor
   IF col = 0 THEN col = uilook(uiMenuItem)
   IF state.pt = elem AND state.active THEN col = uilook(uiSelectedItem + state.tog)
   WITH *menu.items[elem]
    selected = (state.pt = elem ANDALSO state.active)
    IF .disabled THEN
     col = uilook(uiDisabledItem)
     IF selected THEN col = uilook(uiSelectedDisabled + state.tog)
    ELSEIF state.hover = elem AND state.active AND NOT selected THEN
     col = uilook(uiMouseHoverItem)
    END IF
    IF .col > 0 ANDALSO NOT selected THEN
     IF .disabled = NO OR .disabled_overrides_color = NO THEN col = .col
    END IF
    IF NOT (.disabled ANDALSO .hide_if_disabled) THEN
     position_menu_item menu, .text, i, where
     IF .t = mtypeSpecial THEN
      ' Check for menu items with bars behind
      DIM bar_width as integer = 0
      metermax = small(state.rect.wide, 80)  'large(48, textwidth(.text))
      IF .sub_t = spMusicVolume OR .sub_t = spVolumeMenu THEN
       bar_width = get_music_volume() * metermax
      ELSEIF .sub_t = spSoundVolume THEN
       bar_width = get_global_sfx_volume() * metermax
      ELSEIF .sub_t = spMargins THEN ' TV Safe Margin meter
       bar_width = get_safe_zone_margin() * metermax \ 10
      END IF
      edgeboxstyle menu.rect.x + (menu.rect.wide - metermax) \ 2, where.y, bar_width, 10, menu.boxstyle, page, NO, YES
     END IF
     edgeprint .text, where.x, where.y, col, page, menu.withtags
    END IF
   END WITH
  END IF
 NEXT i
 
END SUB

' Calculate top-left corner of the text, placed in 'where'
SUB position_menu_item (menu as MenuDef, cap as string, byval i as integer, byref where as XYPair)
 DIM bord as integer
 bord = 8 + menu.bordersize
 WITH menu.rect
  SELECT CASE menu.textalign
   CASE alignLeft
    where.x = .x + bord
   CASE alignCenter
    where.x = .x + (.wide - textwidth(cap)) / 2
   CASE alignRight
    where.x = .x + .wide - bord - textwidth(cap)
  END SELECT
  where.y = .y + bord + (i * (10 + menu.itemspacing))
 END WITH
END SUB

' Calculate menu.rect (not to be confused with menustate.rect, which includes the border padding)
SUB position_menu (menu as MenuDef, byval page as integer)
 DIM i as integer
 DIM bord as integer
 bord = 8 + menu.bordersize

 menu.rect.wide = bord * 2
 menu.rect.high = bord * 2

 FOR i = 0 TO menu.numitems - 1
  WITH *menu.items[i]
   'hidden items used to matter for auto-width but not auto-height; now they don't for either
   IF .disabled AND .hide_if_disabled THEN CONTINUE FOR
   menu.rect.wide = large(menu.rect.wide, textwidth(.text) + bord * 2)
   menu.rect.high += 10
   IF i <> 0 THEN menu.rect.high += menu.itemspacing
  END WITH
 NEXT i
 '--enforce min width
 menu.rect.wide = large(menu.rect.wide, menu.min_chars * 8 + bord * 2)
 '--enforce screen boundaries
 menu.rect.wide = small(menu.rect.wide, vpages(page)->w)
 menu.rect.high = small(menu.rect.high, vpages(page)->h)
 IF menu.maxrows > 0 THEN
  menu.rect.high = small(menu.rect.high, menu.maxrows * (10 + menu.itemspacing) - menu.itemspacing + bord * 2)
 END IF

 WITH menu
  .rect.x = anchor_point(.alignhoriz, vpages(page)->w) - anchor_point(.anchorhoriz, .rect.wide) + menu.offset.x
  .rect.y = anchor_point(.alignvert, vpages(page)->h) - anchor_point(.anchorvert, .rect.high) + menu.offset.y
 END WITH
END SUB

FUNCTION anchor_point(byval anchor as AlignType, byval size as integer) as integer
 SELECT CASE anchor
  CASE alignLeft
   RETURN 0
  CASE alignMiddle
   RETURN size \ 2
  CASE alignRight
   RETURN size
 END SELECT
END FUNCTION

FUNCTION count_menu_items (menu as MenuDef) as integer
 DIM i as integer
 DIM count as integer = 0
 FOR i = 0 TO menu.numitems - 1
  WITH *menu.items[i]
   IF .disabled AND .hide_if_disabled THEN CONTINUE FOR
   count += 1
  END WITH
 NEXT i
 RETURN count
END FUNCTION

FUNCTION get_menu_item_caption (mi as MenuDefItem, menu as MenuDef) as string
 DIM cap as string
 cap = mi.caption
 IF LEN(cap) = 0 THEN
  'No caption, use the default
  SELECT CASE mi.t
   CASE mtypeSpecial
    cap = get_special_menu_caption(mi.sub_t)
   CASE mtypeMenu
    cap = getmenuname(mi.sub_t)
    IF cap = "" THEN cap = "Menu " & mi.sub_t
   CASE mtypeTextBox
    cap = "Text Box " & mi.sub_t
   CASE mtypeScript
    cap = scriptname(mi.sub_t)
  END SELECT
 END IF
 IF menu.edit_mode = YES THEN
  IF LEN(TRIM(cap)) = 0 THEN cap = "[BLANK]"
  cap &= get_menu_item_editing_annotation(mi)
 END IF
 #IFDEF IS_GAME
  embedtext cap
 #ENDIF
 IF menu.max_chars > 0 THEN ' Crop overlength
  IF menu.textalign = alignRight THEN
   cap = RIGHT(cap, menu.max_chars)
  ELSE ' left and center align
   cap = LEFT(cap, menu.max_chars)
  END IF
 END IF
 RETURN cap
END FUNCTION

FUNCTION get_special_menu_caption(byval subtype as integer) as string
 DIM cap as string
 SELECT CASE subtype
  CASE spItems           : cap = readglobalstring(60, "Items", 10)
  CASE spSpells          : cap = readglobalstring(61, "Spells", 10)
  CASE spStatus          : cap = readglobalstring(62, "Status", 10)
  CASE spEquip           : cap = readglobalstring(63, "Equip", 10)
  CASE spOrder           : cap = readglobalstring(64, "Order", 10)
  CASE spTeam            : cap = readglobalstring(65, "Team", 10)
  CASE spTeamOrOrder
   IF readbit(gen(), genBits, 5) THEN
    cap = readglobalstring(65, "Team", 10)
   ELSE
    cap = readglobalstring(64, "Order", 10)
   END IF
  CASE spMap,spMapMaybe  : cap = readglobalstring(68, "Map", 10)
  CASE spSave,spSaveMaybe: cap = readglobalstring(66, "Save", 10)
  CASE spLoad            : cap = readglobalstring(322, "Load", 20)
  CASE spQuit            : cap = readglobalstring(67, "Quit", 10)
  CASE spVolumeMenu      : cap = readglobalstring(69, "Volume", 10)
  CASE spMusicVolume     : cap = readglobalstring(318, "Music", 20)
  CASE spSoundVolume     : cap = readglobalstring(320, "Sound", 20)
  CASE spMargins         : cap = readglobalstring(308, "Margins", 10)
  CASE spPurchases       : cap = readglobalstring(313, "Purchases", 10)
  CASE spWindowed        : cap = readglobalstring(314, "Windowed", 20)
  CASE spFullscreen      : cap = readglobalstring(316, "Fullscreen", 20)
 END SELECT
 RETURN cap
END FUNCTION

' Return the suffix that is appended to a menu item while in edit mode
FUNCTION get_menu_item_editing_annotation (mi as MenuDefItem) as string
 SELECT CASE mi.t
  CASE 1 ' special screen
   SELECT CASE mi.sub_t
    CASE spTeamOrOrder
     RETURN " [general bitset]"
    CASE spMapMaybe
     RETURN " [if allowed by map]"
    CASE spSaveMaybe
     RETURN " [if allowed by map]"
    CASE spMargins
     RETURN " [if available]"
    CASE spPurchases
     RETURN " [if available]"
    CASE spWindowed
     RETURN " [if fullscreen]"
    CASE spFullscreen
     RETURN " [if windowed]"
    CASE spVolumeMenu
     RETURN " [menu]"
   END SELECT
 END SELECT
 RETURN ""
END FUNCTION


'==========================================================================================
'                                       Scrollbars!
'==========================================================================================


SUB draw_scrollbar(state as MenuState, menu as MenuDef, page as integer, align as AlignType = alignRight)
 draw_scrollbar state, menu.rect, menu.boxstyle, page, align
END SUB

'Hint: usually you would pass state.rect as rect
'count being the number of (visible) menu items
'align is which side to put the slider on
SUB draw_scrollbar(state as MenuState, rect as RectType, boxstyle as integer=0, page as integer, align as AlignType = alignRight)
 DIM count as integer = state.last - state.first + 1
 'recall state.size is off-by-1
 IF state.top > state.first OR count > (state.size + 1) THEN
  IF count > 0 THEN
   DIM sbar as RectType
   DIM slider as RectType
   ' 2px padding on each side, 4px wide slider
   DIM pad as integer = 2
   sbar.wide = 4
   sbar.high = rect.high - pad * 2
   sbar.x = rect.x + pad + anchor_point(align, rect.wide - pad * 2 - sbar.wide)
   sbar.y = rect.y + pad
   WITH sbar
    slider.y = .high / count * (state.top - state.first)
    slider.high = .high / count * (state.size + 1)
    rectangle .x, .y, .wide, .high, uilook(uiBackground), page
    rectangle .x, .y + slider.y, .wide, slider.high, boxlook(boxstyle).edgecol, page
   END WITH
  END IF
 END IF
END SUB

SUB draw_fullscreen_scrollbar(state as MenuState, boxstyle as integer=0, page as integer, align as AlignType = alignRight)
 DIM rect as RectType
 rect.wide = vpages(page)->w
 rect.high = vpages(page)->h
 draw_scrollbar state, rect, boxstyle, page, align
END SUB


'==========================================================================================
'                                   Generic menu system
'==========================================================================================


' The boilerplate for displaying a MenuDef menu, if nothing else has to be drawn to the screen.
SUB run_MenuDef(menu as MenuDef, each_tick as FnMenuLogic, dataptr as any ptr = NULL)
 DIM holdscreen as integer = allocatepage
 copypage vpage, holdscreen
 DIM state as MenuState
 init_menu_state state, menu
 DO
  setwait 55
  setkeys YES
  usemenu state
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF each_tick(menu, state, dataptr) THEN EXIT DO
  copypage holdscreen, vpage
  draw_menu menu, state, vpage
  setvispage vpage
  dowait
 LOOP
 setkeys
 freepage holdscreen
END SUB

SUB ModularMenu.update()
END SUB

FUNCTION ModularMenu.each_tick() as bool
 RETURN NO
END FUNCTION

SUB ModularMenu.draw_underlays()
END SUB

SUB ModularMenu.draw()
 IF floating THEN
  copypage holdscreen, vpage
 ELSE
  clearpage vpage
 END IF
 draw_underlays()

 DIM where as XYPair = (4, 4)
 IF floating THEN
  'FIXME: state.rect isn't calculated until standardmenu is called
  'TODO: In fact, this is a pretty ugly way to draw a floating menu. And state.rect
  'takes a tick to update.
  'So this should probably be replaced with MenuDef draw_menu
  edgeboxstyle pCentered, pCentered, state.rect.wide + 10, state.rect.high + 10, 1, vpage
  where = XY(pCentered, pCentered)
 END IF
 standardmenu menu(), state, where.x, where.y, vpage, menuopts
 IF LEN(tooltip) THEN
  edgeprint tooltip, 0, pBottom, uilook(uiText), vpage
 END IF
END SUB

SUB ModularMenu.run()
 IF floating THEN
  holdscreen = allocatepage
  copypage vpage, holdscreen

  menuopts.wide = 80
  menuopts.calc_size = YES
 END IF
 state.autosize_ignore_lines = 1  'For the tooltip
 menuopts.scrollbar = YES

 update()
 init_menu_state state, menu()
 IF floating THEN draw()   'To calculate state.rect

 DO
  setwait 55
  setkeys YES
  usemenu state
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF LEN(helpkey) AND keyval(scF1) > 1 THEN show_help helpkey
  IF each_tick() THEN EXIT DO
  IF state.need_update THEN
   state.need_update = NO
   update()
  END IF

  draw()
  setvispage vpage
  dowait
 LOOP
 setkeys
 IF holdscreen THEN freepage holdscreen
END SUB


'==========================================================================================

'Ask how to add a new record to an editor.
'what:     Type of a record, like "map"
'maxindex: Max valid ID of an existing record
'getname:  Returns the name or description of a record
'Return value:
' -2  =Cancel
' -1  =New blank
' >=0 =Copy existing
'TODO: this is duplicated in a number of places. Search for 'generic_add_new'
FUNCTION generic_add_new (what as string, maxindex as integer, getname as FUNCTION(idx as integer) as string, helpkey as string = "") as integer
 DIM menu(2) as string
 DIM whichtocopy as integer = 0
 DIM state as MenuState
 state.last = UBOUND(menu)
 state.size = 24

 state.need_update = YES
 setkeys YES
 DO
  setwait 55
  setkeys YES
  IF keyval(scESC) > 1 THEN
   '--return cancel
   RETURN -2
  END IF
  IF keyval(scF1) > 1 THEN show_help helpkey
  usemenu state
  IF state.pt = 2 THEN
   IF intgrabber(whichtocopy, 0, maxindex) THEN state.need_update = YES
  END IF
  IF enter_space_click(state) THEN
   SELECT CASE state.pt
   CASE 0 ' cancel
    RETURN -2
   CASE 1 ' blank
    RETURN -1
   CASE 2 ' copy
    RETURN whichtocopy
   END SELECT
  END IF
  IF state.need_update THEN
   state.need_update = NO
   menu(0) = "Cancel"
   menu(1) = "New blank " & what
   menu(2) = "Copy of " & what & " " & whichtocopy & " " & getname(whichtocopy)
  END IF
  clearpage vpage
  standardmenu menu(), state, 0, 0, vpage

  setvispage vpage
  dowait
 LOOP
END FUNCTION
