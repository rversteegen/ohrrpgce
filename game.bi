'OHRRPGCE - game.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from game.bas

#IFNDEF GAME_BI
#DEFINE GAME_BI

declare function bound_item(itemid as integer, cmd as string) as integer
declare function bound_hero_party(who as integer, cmd as string, minimum as integer=0) as integer
declare function bound_menuslot(menuslot as integer, cmd as string) as integer
declare function bound_menuslot_and_mislot(menuslot as integer, mislot as integer, cmd as string) as integer
declare function bound_plotstr(n as integer, cmd as string) as integer
declare function bound_formation(form as integer, cmd as string) as integer
declare function bound_formation_slot(form as integer, slot as integer, cmd as string) as integer
declare sub loadmap_gmap(mapnum)
declare sub loadmap_npcl(mapnum)
declare sub loadmap_npcd(mapnum)
declare sub loadmap_tilemap(mapnum)
declare sub loadmap_passmap(mapnum)
declare sub loadmaplumps (mapnum, loadmask)
declare sub menusound(byval s as integer)
declare sub dotimer(byval l as integer)
declare function dotimerbattle() as integer
declare function dotimermenu() as integer
declare sub dotimerafterbattle()
declare function count_sav(filename as string) as integer
declare function add_menu (record as integer, allow_duplicate as integer=no) as integer
declare sub remove_menu (slot as integer)
declare sub bring_menu_forward (slot as integer)
declare function menus_allow_gameplay () as integer
declare function menus_allow_player () as integer
declare sub player_menu_keys (byref menu_text_box as integer, stat(), catx(), caty(), tilesets() as tilesetdata ptr)
declare sub check_menu_tags ()
declare function game_usemenu (state as menustate) as integer
declare function find_menu_id (id as integer) as integer
declare function find_menu_handle (handle) as integer
declare function find_menu_item_handle_in_menuslot (handle as integer, menuslot as integer) as integer
declare function find_menu_item_handle (handle as integer, byref found_in_menuslot) as integer
declare function assign_menu_item_handle (byref mi as menudefitem) as integer
declare function assign_menu_handles (byref menu as menudef) as integer
declare function menu_item_handle_by_slot(menuslot as integer, mislot as integer, visible_only as integer=yes) as integer
declare function find_menu_item_slot_by_string(menuslot as integer, s as string, mislot as integer=0, visible_only as integer=yes) as integer
declare function allowed_to_open_main_menu () as integer
declare function random_formation (byval set as integer) as integer
declare sub init_default_text_colors()

#ENDIF
