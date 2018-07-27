'OHRRPGCE COMMON - Game/Custom shared menu code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#ifndef MENUS_BI
#define MENUS_BI

#include "udts.bi"
#include "uiconst.bi"

'' Generic MenuState Stuff
DECLARE SUB init_menu_state OVERLOAD (byref state as MenuState, menu() as SimpleMenuItem, menuopts as MenuOptions = MenuOptions())
DECLARE SUB init_menu_state OVERLOAD (byref state as MenuState, byval menu as BasicMenuItem vector, menuopts as MenuOptions = MenuOptions())
DECLARE SUB init_menu_state OVERLOAD (byref state as MenuState, menu() as string, menuopts as MenuOptions = MenuOptions())
DECLARE SUB append_simplemenu_item (byref menu as SimpleMenuItem vector, caption as string, byval unselectable as bool = NO, byval col as integer = 0, byval dat as integer = 0, byval where as integer = -1)
DECLARE SUB correct_menu_state (state as MenuState)
DECLARE SUB correct_menu_state_top (state as MenuState)
DECLARE FUNCTION usemenu_keypress(deckey as integer = scUp, inckey as integer = scDown) as bool
DECLARE FUNCTION usemenu OVERLOAD (state as MenuState, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
DECLARE FUNCTION usemenu OVERLOAD (byref pt as integer, byref top as integer, byval first as integer, byval last as integer, byval size as integer, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
DECLARE FUNCTION usemenu OVERLOAD (state as MenuState, byval menudata as BasicMenuItem vector, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
DECLARE FUNCTION usemenu OVERLOAD (state as MenuState, menu as MenuDef, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
DECLARE FUNCTION usemenu OVERLOAD (state as MenuState, selectable() as bool, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
DECLARE FUNCTION scrollmenu (state as MenuState, byval deckey as integer = scUp, byval inckey as integer = scDown) as bool
DECLARE SUB standard_to_basic_menu (menu() as string, byref state as MenuState, byref basicmenu as BasicMenuItem vector, byval shaded as bool ptr = NULL)
DECLARE SUB standardmenu OVERLOAD (menu() as string, state as MenuState, x as RelPos, y as RelPos, page as integer, menuopts as MenuOptions = MenuOptions())
DECLARE SUB standardmenu OVERLOAD (menu() as string, state as MenuState, shaded() as bool, x as RelPos, y as RelPos, page as integer, menuopts as MenuOptions = MenuOptions())
DECLARE SUB standardmenu OVERLOAD (byval menu as BasicMenuItem vector, state as MenuState, x as RelPos, y as RelPos, page as integer, menuopts as MenuOptions = MenuOptions())
DECLARE SUB recalc_menu_size (byref state as MenuState)
DECLARE SUB calc_menustate_size (state as MenuState, menuopts as MenuOptions, x as RelPos, y as RelPos, page as integer = -1, menu as BasicMenuItem vector = NULL)
DECLARE FUNCTION menu_item_color(state as MenuState, itemno as integer, disabled as bool = NO, unselectable as bool = NO, c as integer = 0, c_disabled as integer = 0, def_normal as integer = -uiMenuItem-1, def_disabled as integer = -uiDisabledItem-1) as integer


'' Mouse support
DECLARE FUNCTION find_menu_item_at_point (state as MenuState, x as integer, y as integer) as integer
DECLARE FUNCTION mouse_update_hover (state as MenuState) as bool
DECLARE SUB mouse_update_selection (state as MenuState)
DECLARE SUB mouse_scroll_menu(byref state as MenuState)
DECLARE SUB mouse_drag_menu(byref state as MenuState, byval button as MouseButton=mouseRight, byval threshold as integer=10, byval magnify as double=1.0)

'' Selection by typing
DECLARE FUNCTION select_by_typing (selectst as SelectTypeState, byval allow_numbers as bool = YES) as bool
DECLARE SUB select_clear (selectst as SelectTypeState)
DECLARE SUB highlight_menu_typing_selection OVERLOAD (menu() as string, menu_display() as string, selectst as SelectTypeState, state as MenuState)
DECLARE SUB highlight_menu_typing_selection OVERLOAD (byref menu as BasicMenuItem vector, byref menu_display as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState)
DECLARE FUNCTION highlight_menu_typing_selection_string(z as string, selectst as SelectTypeState) as string
DECLARE SUB select_on_word_boundary_excluding OVERLOAD (menu() as string, selectst as SelectTypeState, state as MenuState, excludeword as string)
DECLARE SUB select_on_word_boundary_excluding OVERLOAD (byval menu as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState, excludeword as string)
DECLARE SUB select_on_word_boundary OVERLOAD (menu() as string, selectst as SelectTypeState, state as MenuState)
DECLARE SUB select_on_word_boundary OVERLOAD (byval menu as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState)
DECLARE SUB select_instr(menu() as string, selectst as SelectTypeState, state as MenuState)

'' MenuDef
DECLARE SUB ClearMenuData(dat as MenuDef)
DECLARE SUB InitLikeStandardMenu(menu as MenuDef)
DECLARE SUB DeleteMenuItems(menu as MenuDef)
DECLARE SUB SortMenuItems(menu as MenuDef)
DECLARE FUNCTION getmenuname(byval record as integer) as string
DECLARE SUB init_menu_state OVERLOAD (byref state as MenuState, menu as MenuDef)
DECLARE SUB sort_menu_and_select_selectable_item(menu as MenuDef, state as MenuState)
DECLARE FUNCTION append_menu_item(byref menu as MenuDef, caption as string, byval t as integer=0, byval sub_t as integer=0, byval dataptr as ANY ptr=0) as integer
DECLARE SUB remove_menu_item OVERLOAD (byref menu as MenuDef, byval mi as MenuDefItem ptr)
DECLARE SUB remove_menu_item OVERLOAD (byref menu as MenuDef, byval mislot as integer)
DECLARE SUB swap_menu_items(byref menu1 as MenuDef, byval mislot1 as integer, byref menu2 as MenuDef, byval mislot2 as integer)

'' Saving/Loading/(De)serializing MenuDefs
DECLARE SUB LoadMenuData(menu_set as MenuSet, dat as MenuDef, byval record as integer, byval ignore_items as integer=NO)
DECLARE SUB SaveMenuData(menu_set as MenuSet, dat as MenuDef, byval record as integer)
DECLARE SUB MenuBitsToArray (menu as MenuDef, bits() as integer)
DECLARE SUB MenuBitsFromArray (menu as MenuDef, bits() as integer)
DECLARE SUB MenuItemBitsToArray (mi as MenuDefItem, bits() as integer)
DECLARE SUB MenuItemBitsFromArray (mi as MenuDefItem, bits() as integer)
DECLARE FUNCTION read_menu_int (menu as MenuDef, byval intoffset_plus1 as integer) as integer
DECLARE SUB write_menu_int (menu as MenuDef, byval intoffset_plus1 as integer, byval n as integer)
DECLARE FUNCTION read_menu_item_int (mi as MenuDefItem, byval intoffset as integer) as integer
DECLARE SUB write_menu_item_int (mi as MenuDefItem, byval intoffset as integer, byval n as integer)

'' Drawing MenuDefs
DECLARE SUB draw_menu (menu as MenuDef, state as MenuState, byval page as integer)
DECLARE SUB position_menu_item (menu as MenuDef, cap as string, byval i as integer, byref where as XYPair)
DECLARE SUB position_menu (menu as MenuDef, byval page as integer)
DECLARE FUNCTION anchor_point(byval anchor as AlignType, byval size as integer) as integer
DECLARE FUNCTION count_menu_items (menu as MenuDef) as integer

DECLARE FUNCTION get_menu_item_caption (mi as MenuDefItem, menu as MenuDef) as string
DECLARE FUNCTION get_special_menu_caption(byval subtype as integer) as string
DECLARE FUNCTION get_menu_item_editing_annotation (mi as MenuDefItem) as string
DECLARE FUNCTION menu_item_is_activatable(mi as MenuDefItem) as bool

'' Scrollbars!
DECLARE SUB draw_scrollbar OVERLOAD (state as MenuState, menu as MenuDef, page as integer, align as AlignType = alignRight)
DECLARE SUB draw_scrollbar OVERLOAD (state as MenuState, rect as RectType, boxstyle as integer=0, page as integer, align as AlignType = alignRight)
DECLARE SUB draw_fullscreen_scrollbar(state as MenuState, boxstyle as integer=0, page as integer, align as AlignType = alignRight)


' Some day this may be a universal menu class.
' In the meantime, just use a simple menu() as string, but probably
' should switch to BasicMenuItem at a minimum
TYPE ModularMenu EXTENDS Object
 running as bool         'Whether inside run()
 menu(any) as string
 tooltip as string       'Shown at the bottom of the screen
 title as string         'Shown at the top, like the multichoice() prompt
 state as MenuState
 menuopts as MenuOptions
 floating as bool        'Appears in the center of the screen, like notification, instead of fullscreen
 helpkey as string
 holdscreen as integer   '0 if none

 ' Called to create/update 'menu()' and 'state' if state.need_update is true. Also called once at start.
 ' Should correctly set state.last
 DECLARE VIRTUAL SUB update()

 ' Called each tick. Can either call update() itself or set state.need_update=YES
 ' Return YES to exit the menu
 DECLARE VIRTUAL FUNCTION each_tick() as bool

 ' Called before drawing the menu to draw any extra stuff
 DECLARE VIRTUAL SUB draw_underlays()

 ' Generally you shouldn't need to override this.
 DECLARE VIRTUAL SUB draw()

 DECLARE SUB run()
END TYPE

DECLARE FUNCTION generic_add_new (what as string, maxindex as integer, getname as FUNCTION(idx as integer) as string, helpkey as string = "") as integer


'' Global variables
EXTERN force_use_mouse as integer

#endif
