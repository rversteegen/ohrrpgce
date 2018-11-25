'OHRRPGCE - Some Custom common code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#ifndef CUSTOMSUBS_BI
#define CUSTOMSUBS_BI

#include "const.bi"
#include "slices.bi"
#include "custom_udts.bi"
#include "tagedit.bi"   'For tag grabber and caption functions

TYPE FnScriptVisitor as function (byref trig as integer, description as string, caption as string) as bool


DECLARE FUNCTION charpicker() as string


CONST THINGGRABBER_TOOLTIP = "Ctrl-Enter/Click to edit, +/Insert to add new"

DECLARE FUNCTION enter_or_add_new(state as MenuState) as bool
DECLARE FUNCTION attackgrabber (byref datum as integer, state as MenuState, offset as integer = 0, min as integer = 0, intgrab as bool = YES) as bool
DECLARE FUNCTION enemygrabber (byref datum as integer, state as MenuState, offset as integer = 0, min as integer = 0, intgrab as bool = YES) as bool
DECLARE FUNCTION textboxgrabber (byref datum as integer, state as MenuState, offset as integer = 0, min as integer = 0, intgrab as bool = YES) as integer

DECLARE SUB ui_color_editor(palnum as integer)
DECLARE SUB make_ui_color_editor_menu(m() as string, colors() as integer)
DECLARE SUB ui_boxstyle_editor(palnum as integer)
DECLARE SUB make_ui_boxstyle_editor_menu(m() as string, boxes() as BoxStyle)

TYPE FnRecordName as FUNCTION(idx as integer) as string

DECLARE FUNCTION generic_add_new (what as string, maxindex as integer, getname as FnRecordName, previewer as RecordPreviewer ptr = NULL, helpkey as string = "") as integer
DECLARE FUNCTION needaddset (byref pt as integer, byref check as integer, what as string) as bool
DECLARE FUNCTION intgrabber_with_addset (byref pt as integer, byval min as integer, byval max as integer, byval maxmax as integer=32767, what as string, byval less as KBScancode=ccLeft, byval more as KBScancode=ccRight) as bool

DECLARE FUNCTION load_vehicle_name(vehID as integer) as string
DECLARE FUNCTION load_item_name (it as integer, hidden as integer, offbyone as integer) as string
DECLARE SUB onetimetog(byref tagnum as integer)

DECLARE FUNCTION pal16browse OVERLOAD (curpal as integer, sprite as Frame ptr, show_default as bool=NO) as integer
DECLARE FUNCTION pal16browse OVERLOAD (curpal as integer, picset as SpriteType, picnum as integer, show_default as bool=NO) as integer

DECLARE FUNCTION step_estimate(freq as integer, low as integer, high as integer, infix as string="-", suffix as string= "", zero as string="never") as string
DECLARE FUNCTION speed_estimate(speed as integer) as string
DECLARE FUNCTION seconds_estimate(ticks as integer) as string

DECLARE SUB load_text_box_portrait (byref box as TextBox, byref gfx as GraphicPair)
DECLARE SUB xy_position_on_slice (sl as Slice Ptr, byref x as integer, byref y as integer, caption as string, helpkey as string)
DECLARE SUB xy_position_on_sprite (spr as GraphicPair, byref x as integer, byref y as integer, byval frame as integer, byval wide as integer, byval high as integer, caption as string, helpkey as string)
DECLARE FUNCTION sublist (s() as string, helpkey as string="", byval x as integer=0, byval y as integer=0, byval page as integer=-1) as integer
DECLARE SUB edit_global_text_strings()
DECLARE SUB writeglobalstring (index as integer, s as string, maxlen as integer)
DECLARE SUB update_attack_editor_for_chain (byval mode as integer, byref caption1 as string, byref max1 as integer, byref min1 as integer, byref menutype1 as integer, byref caption2 as string, byref max2 as integer, byref min2 as integer, byref menutype2 as integer, rate as integer, stat as integer)
DECLARE FUNCTION attack_chain_browser (byval start_attack as integer) as integer
DECLARE SUB get_menu_hotkeys (menu() as string, byval menumax as integer, menukeys() as string, excludewords as string = "")
DECLARE FUNCTION experience_chart (byval expcurve as double=0.2) as double
DECLARE SUB stat_growth_chart ()
DECLARE SUB spawn_game_menu(gdb as bool = NO, valgrind as bool = NO)

DECLARE FUNCTION write_rpg_or_rpgdir (lumpsdir as string, filetolump as string) as bool
DECLARE SUB move_unwriteable_rpg (filetolump as string)
DECLARE SUB save_edit_time ()
DECLARE FUNCTION save_current_game(byval genDebugMode_override as integer=-1) as bool
DECLARE SUB automatic_backup (rpgfile as string)

DECLARE SUB check_used_onetime_npcs(bits() as integer)

DECLARE SUB menu_of_reorderable_nodes(st as MenuState, menu as MenuDef)
DECLARE FUNCTION reorderable_node(byval node as NodePtr) as integer

DECLARE SUB edit_platform_controls ()
DECLARE FUNCTION prompt_for_scancode () as KBScancode
DECLARE FUNCTION scancode_to_name(byval sc as KBScancode) as string
DECLARE SUB edit_purchase_options ()
DECLARE SUB edit_purchase_details (byval prod as NodePtr)

DECLARE SUB edit_savegame_options ()

DECLARE FUNCTION npc_preview_text(byref npc as NPCType) as string

DECLARE SUB mark_non_elemental_elementals ()

DECLARE FUNCTION custom_setoption(opt as string, arg as string) as integer

#endif
