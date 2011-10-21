'OHRRPGCE COMMON - Game/Custom shared menu code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#ifndef MENUS_BI
#define MENUS_BI

'*** Requires construction (with ClearMenuData or LoadMenuData) + destruction (with DeleteMenuItems) ***

'' Generic MenuState Stuff
DECLARE SUB init_menu_state OVERLOAD (byref state as MenuState, menu() as SimpleMenuItem)
DECLARE SUB init_menu_state OVERLOAD (byref state as MenuState, byval menu as BasicMenuItem vector)
DECLARE SUB clamp_menu_state (byref state as MenuState)
DECLARE SUB append_simplemenu_item (byref menu as SimpleMenuItem vector, caption as string, byval unselectable as integer = NO, byval col as integer = 0, byval dat as integer = 0, byval where as integer = -1)
DECLARE FUNCTION usemenu OVERLOAD (state as MenuState, byval deckey as integer = scUp, byval inckey as integer = scDown) as integer
DECLARE FUNCTION usemenu OVERLOAD (byref pt as integer, byref top as integer, byval first as integer, byval last as integer, byval size as integer, byval deckey as integer = scUp, byval inckey as integer = scDown) as integer
DECLARE FUNCTION usemenu OVERLOAD (state as MenuState, byval menudata as BasicMenuItem vector, byval deckey as integer = scUp, byval inckey as integer = scDown) as integer
DECLARE FUNCTION usemenu OVERLOAD (state as MenuState, selectable() as integer, byval deckey as integer = scUp, byval inckey as integer = scDown) as integer
DECLARE FUNCTION scrollmenu (state as MenuState, byval deckey as integer = scUp, byval inckey as integer = scDown) as integer
DECLARE SUB standard_to_basic_menu (menu() as string, byval last as integer, byref basicmenu as BasicMenuItem vector, byval shaded as integer PTR=NULL)
DECLARE SUB standardmenu OVERLOAD (menu() as STRING, state as MenuState, byval x as integer, byval y as integer, byval page as integer, byval edge as integer=NO, byval hidecursor as integer=NO, byval wide as integer=9999, byval highlight as integer=NO, byval toggle as integer=YES)
DECLARE SUB standardmenu OVERLOAD (menu() as STRING, state as MenuState, shaded() as integer, byval x as integer, byval y as integer, byval page as integer, byval edge as integer=NO, byval hidecursor as integer=NO, byval wide as integer=9999, byval highlight as integer=NO, byval toggle as integer=YES)
DECLARE SUB standardmenu OVERLOAD (menu() as STRING, byval size as integer, byval vis as integer, byval pt as integer, byval top as integer, byval x as integer, byval y as integer, byval page as integer, byval edge as integer=NO, byval wide as integer=9999, byval highlight as integer=NO, byval toggle as integer=YES)
DECLARE SUB standardmenu OVERLOAD (byval menu as BasicMenuItem vector, state as MenuState, byval x as integer, byval y as integer, byval page as integer, byval edge as integer=NO, byval hidecursor as integer=NO, byval wide as integer=9999, byval highlight as integer=NO, byval toggle as integer=YES)

'' MenuDef
DECLARE SUB ClearMenuData(dat as MenuDef)
DECLARE SUB DeleteMenuItems(menu as MenuDef)
DECLARE SUB ClearMenuItem(mi as MenuDefItem)
DECLARE SUB SortMenuItems(menu as MenuDef)
DECLARE FUNCTION getmenuname(byval record as integer) as STRING
DECLARE SUB init_menu_state OVERLOAD (byref state as MenuState, menu as MenuDef)
DECLARE FUNCTION append_menu_item(byref menu as MenuDef, caption as STRING, byval t as integer=0, byval sub_t as integer=0) as integer
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
DECLARE FUNCTION read_menu_int (menu as MenuDef, byval intoffset as integer) as integer
DECLARE SUB write_menu_int (menu as MenuDef, byval intoffset as integer, byval n as integer)
DECLARE FUNCTION read_menu_item_int (mi as MenuDefItem, byval intoffset as integer) as integer
DECLARE SUB write_menu_item_int (mi as MenuDefItem, byval intoffset as integer, byval n as integer)

'' Drawing MenuDefs
DECLARE SUB draw_menu (menu as MenuDef, state as MenuState, byval page as integer)
DECLARE SUB position_menu_item (menu as MenuDef, cap as STRING, byval i as integer, byref where as XYPair)
DECLARE SUB position_menu (menu as MenuDef, byval page as integer)
DECLARE FUNCTION anchor_point(byval anchor as integer, byval size as integer) as integer
DECLARE FUNCTION count_menu_items (menu as MenuDef) as integer
DECLARE FUNCTION get_menu_item_caption (mi as MenuDefItem, menu as MenuDef) as STRING
DECLARE FUNCTION get_special_menu_caption(byval subtype as integer, byval edit_mode as integer= NO) as STRING

'' Scrollbars!
DECLARE SUB draw_scrollbar OVERLOAD (state as MenuState, menu as MenuDef, byval page as integer)
DECLARE SUB draw_scrollbar OVERLOAD (state as MenuState, rect as RectType, byval boxstyle as integer=0, byval page as integer)
DECLARE SUB draw_scrollbar OVERLOAD (state as MenuState, rect as RectType, byval count as integer, byval boxstyle as integer=0, byval page as integer)
DECLARE SUB draw_fullscreen_scrollbar(state as MenuState, byval boxstyle as integer=0, byval page as integer)


#endif
