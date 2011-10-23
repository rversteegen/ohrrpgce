'OHRRPGCE - Some Custom common code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#ifndef CUSTOMSUBS_BI
#define CUSTOMSUBS_BI

#include "const.bi"
#include "slices.bi"
#include "custom_udts.bi"

TYPE FnScriptVisitor as function (byref trig as integer, description as string, caption as string) as integer

DECLARE FUNCTION tag_grabber (BYREF n AS INTEGER, min AS INTEGER=-999, max AS INTEGER=999) AS INTEGER
DECLARE FUNCTION tagnames (starttag AS INTEGER=0, picktag AS INTEGER=NO) AS INTEGER
DECLARE FUNCTION cond_grabber (cond AS Condition, BYVAL default AS INTEGER = 0, BYVAL alwaysedit AS INTEGER) AS INTEGER
DECLARE FUNCTION condition_string (cond AS Condition, BYVAL selected AS INTEGER, default AS STRING = "Always", BYVAL wide AS INTEGER = 40) AS STRING
DECLARE FUNCTION charpicker() AS STRING
DECLARE FUNCTION percent_grabber OVERLOAD (BYREF float AS DOUBLE, repr AS STRING, BYVAL min AS DOUBLE, BYVAL max AS DOUBLE, BYVAL decimalplaces AS INTEGER = 4) AS INTEGER
DECLARE FUNCTION percent_grabber OVERLOAD (BYREF float AS SINGLE, repr AS STRING, BYVAL min AS DOUBLE, BYVAL max AS DOUBLE, BYVAL decimalplaces AS INTEGER = 4) AS INTEGER
DECLARE FUNCTION format_percent_cond(BYREF cond AS AttackElementCondition, default AS STRING, BYVAL decimalplaces AS INTEGER = 4) AS STRING
DECLARE FUNCTION percent_cond_grabber(BYREF cond AS AttackElementCondition, repr AS STRING, default AS STRING, BYVAL min AS DOUBLE, BYVAL max AS DOUBLE, BYVAL decimalplaces AS INTEGER = 4) AS INTEGER
DECLARE SUB percent_cond_editor (cond as AttackElementCondition, BYVAL min AS DOUBLE, BYVAL max AS DOUBLE, BYVAL decimalplaces AS INTEGER = 4, do_what as string = "...", percent_of_what AS STRING = "")
DECLARE SUB ui_color_editor(palnum AS INTEGER)
DECLARE SUB make_ui_color_editor_menu(m() AS STRING, colors() AS INTEGER)
DECLARE FUNCTION pick_ogg_quality(BYREF quality AS INTEGER) AS INTEGER
DECLARE FUNCTION needaddset (BYREF pt AS INTEGER, BYREF check AS INTEGER, what AS STRING) AS INTEGER
DECLARE FUNCTION intgrabber_with_addset (BYREF pt AS INTEGER, BYVAL min AS INTEGER, BYVAL max AS INTEGER, BYVAL maxmax AS INTEGER=32767, what AS STRING, BYVAL less AS INTEGER=scLeft, BYVAL more AS INTEGER=scRight) AS INTEGER
DECLARE SUB keyboardsetup ()
DECLARE FUNCTION load_vehicle_name(vehID AS INTEGER) AS STRING
DECLARE FUNCTION load_item_name (it AS INTEGER, hidden AS INTEGER, offbyone AS INTEGER) AS STRING
DECLARE FUNCTION textbox_preview_line OVERLOAD (boxnum AS INTEGER) AS STRING
DECLARE FUNCTION textbox_preview_line OVERLOAD (box AS TextBox) AS STRING
DECLARE SUB onetimetog(BYREF tagnum AS INTEGER)
DECLARE SUB edit_npc (npcdata AS NPCType, gmap() AS integer, zmap AS ZoneMap)
DECLARE FUNCTION pal16browse (BYVAL curpal AS INTEGER, BYVAL picset AS INTEGER, BYVAL picnum AS INTEGER) AS INTEGER
DECLARE FUNCTION step_estimate(freq AS INTEGER, low AS INTEGER, high AS INTEGER, infix AS STRING="-", suffix AS STRING= "", zero AS STRING="never") AS STRING
DECLARE FUNCTION speed_estimate(speed AS INTEGER, suffix AS STRING=" seconds", zero AS STRING="infinity") AS STRING
DECLARE FUNCTION seconds_estimate(ticks AS INTEGER) AS STRING
DECLARE SUB load_text_box_portrait (BYREF box AS TextBox, BYREF gfx AS GraphicPair)
DECLARE FUNCTION export_textboxes (filename AS STRING, metadata() AS INTEGER) AS INTEGER
DECLARE FUNCTION import_textboxes (filename AS STRING, BYREF warn AS STRING) AS INTEGER
DECLARE FUNCTION askwhatmetadata (metadata() AS INTEGER, metadatalabels() AS STRING) AS INTEGER
DECLARE FUNCTION str2bool(q AS STRING, default AS INTEGER = NO, invert AS INTEGER = NO) AS INTEGER
DECLARE SUB xy_position_on_slice (sl AS Slice Ptr, BYREF x AS INTEGER, BYREF y AS INTEGER, caption AS STRING, helpkey AS STRING)
DECLARE SUB xy_position_on_sprite (spr AS GraphicPair, BYREF x AS INTEGER, BYREF y AS INTEGER, BYVAL frame AS INTEGER, BYVAL wide AS INTEGER, byval high AS INTEGER, caption AS STRING, helpkey AS STRING)
DECLARE SUB edit_menu_bits (menu AS MenuDef)
DECLARE SUB edit_menu_item_bits (mi AS MenuDefItem)
DECLARE SUB reposition_menu (menu AS MenuDef, mstate AS MenuState)
DECLARE SUB reposition_anchor (menu AS MenuDef, mstate AS MenuState)
DECLARE FUNCTION tag_toggle_caption(n AS INTEGER, prefix AS STRING="Toggle tag") AS STRING
DECLARE SUB editbitset (array() AS INTEGER, BYVAL wof AS INTEGER, BYVAL last AS INTEGER, names() AS STRING, helpkey AS STRING="editbitset")
DECLARE FUNCTION scriptbrowse_string (BYREF trigger AS INTEGER, BYVAL triggertype AS INTEGER, scrtype AS STRING) AS STRING
DECLARE SUB scriptbrowse (BYREF trigger AS INTEGER, BYVAL triggertype AS INTEGER, scrtype AS STRING)
DECLARE FUNCTION scrintgrabber (BYREF n AS INTEGER, BYVAL min AS INTEGER, BYVAL max AS INTEGER, BYVAL less AS INTEGER=75, BYVAL more AS INTEGER=77, BYVAL scriptside AS INTEGER, BYVAL triggertype AS INTEGER) AS INTEGER
DECLARE SUB visit_scripts(BYVAL visit AS FnScriptVisitor)
DECLARE SUB gather_script_usage(list() AS STRING, BYVAL id AS INTEGER, BYVAL trigger AS INTEGER=0, BYREF meter AS INTEGER, BYVAL meter_times AS INTEGER=1, box_instead_cache() AS INTEGER, box_after_cache() AS INTEGER, box_preview_cache() AS STRING)
DECLARE SUB script_usage_list ()
DECLARE SUB script_broken_trigger_list()
DECLARE FUNCTION decodetrigger (trigger as integer, trigtype as integer) as integer
DECLARE SUB autofix_broken_old_scripts()
DECLARE FUNCTION stredit (s AS STRING, BYREF insert AS INTEGER, BYVAL maxl AS INTEGER, BYVAL numlines AS INTEGER=1, BYVAL wrapchars AS INTEGER=1) AS INTEGER
DECLARE FUNCTION sublist (s() AS STRING, helpkey AS STRING="", BYVAL x AS INTEGER=0, BYVAL y AS INTEGER=0, BYVAL page AS INTEGER=-1) AS INTEGER
DECLARE SUB edit_global_text_strings()
DECLARE SUB writeglobalstring (index AS INTEGER, s AS STRING, maxlen AS INTEGER)
DECLARE FUNCTION safe_caption(caption_array() AS STRING, BYVAL index AS INTEGER, description AS STRING) AS STRING
DECLARE SUB update_attack_editor_for_chain (BYVAL mode AS INTEGER, BYREF caption1 AS STRING, BYREF max1 AS INTEGER, BYREF min1 AS INTEGER, BYREF menutype1 AS INTEGER, BYREF caption2 AS STRING, BYREF max2 AS INTEGER, BYREF min2 AS INTEGER, BYREF menutype2 AS INTEGER)
DECLARE FUNCTION attack_chain_browser (BYVAL start_attack AS INTEGER) AS INTEGER
DECLARE FUNCTION create_attack_preview_slice(caption AS STRING, BYVAL attack_id AS INTEGER, BYVAL parent AS Slice Ptr) AS Slice Ptr
DECLARE SUB init_attack_chain_screen(BYVAL attack_id AS INTEGER, state AS AttackChainBrowserState)
DECLARE SUB attack_preview_slice_focus(BYVAL sl AS Slice Ptr)
DECLARE SUB attack_preview_slice_defocus(BYVAL sl AS Slice Ptr)
DECLARE FUNCTION find_free_attack_preview_slot(slots() AS Slice Ptr) AS INTEGER
DECLARE SUB position_chain_preview_boxes(sl_list() AS Slice ptr, st AS MenuState)
DECLARE SUB fontedit ()
DECLARE SUB fontedit_export_font(font() AS INTEGER)
DECLARE SUB fontedit_import_font(font() AS INTEGER)
DECLARE SUB cropafter (BYVAL index AS INTEGER, BYREF limit AS INTEGER, BYVAL flushafter AS INTEGER, lump AS STRING, BYVAL bytes AS INTEGER, BYVAL prompt AS INTEGER=YES)
DECLARE FUNCTION numbertail (s AS STRING) AS STRING
DECLARE SUB get_menu_hotkeys (menu() AS STRING, BYVAL menumax AS INTEGER, menukeys() AS STRING, excludewords AS STRING = "")
DECLARE SUB experience_chart ()
DECLARE SUB stat_growth_chart ()
DECLARE SUB spawn_game_menu ()
DECLARE FUNCTION wget_download (url as string, dest as string) as integer
DECLARE FUNCTION can_run_windows_exes () as integer

#endif
