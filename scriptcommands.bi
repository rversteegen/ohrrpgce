#ifndef SCRIPTCOMMANDS_BI
#define SCRIPTCOMMANDS_BI

#include "slices.bi"
#include "plankmenu.bi"  'For FnEmbedCode (this could probably be avoided)

DECLARE FUNCTION checksaveslot (slot as integer) as integer
DECLARE SUB erasesaveslot (slot as integer)

DECLARE SUB embedtext (text as string, byval limit as integer = 0, byval saveslot as integer=-1)
DECLARE FUNCTION embed_text_codes (text_in as string, byval saveslot as integer=-1, byval callback as FnEmbedCode=0, byval arg0 as any ptr=0, byval arg1 as any ptr=0, byval arg2 as any ptr=0) as string
DECLARE FUNCTION standard_embed_codes(act as string, byval arg as integer) as string
DECLARE FUNCTION saveslot_embed_codes(byval saveslot as integer, act as string, byval arg as integer) as string

DECLARE FUNCTION herobyrank (byval slot as integer) as integer
DECLARE FUNCTION rank_to_party_slot (byval rank as integer) as integer
DECLARE FUNCTION party_slot_to_rank (byval slot as integer) as integer
DECLARE FUNCTION rankincaterpillar (byval heroid as integer) as integer

DECLARE SUB trigger_onkeypress_script ()
DECLARE SUB process_wait_conditions ()
DECLARE SUB script_functions (cmdid as integer)

DECLARE SUB wrappedsong (byval songnumber as integer)
DECLARE SUB stopsong
DECLARE FUNCTION backcompat_sound_id (byval id as integer) as integer

DECLARE FUNCTION getnpcref (byval seekid as integer, byval offset as integer) as integer
DECLARE FUNCTION get_valid_npc (byval seekid as integer, byval errlvl as scriptErrEnum = serrBadOp) as integer
DECLARE FUNCTION get_valid_npc_id (byval seekid as integer, byval errlvl as scriptErrEnum = serrBadOp) as integer

DECLARE FUNCTION valid_plotslice(byval handle as integer, byval errlev as scriptErrEnum = serrBadOp) as bool
DECLARE FUNCTION valid_plotsprite(byval handle as integer) as bool
DECLARE FUNCTION valid_plotrect(byval handle as integer) as bool
DECLARE FUNCTION valid_plottextslice(byval handle as integer) as bool
DECLARE FUNCTION valid_plotellipse(byval handle as integer) as bool
DECLARE FUNCTION valid_plotlineslice(byval handle as integer) as bool
DECLARE FUNCTION valid_plotgridslice(byval handle as integer) as bool
DECLARE FUNCTION valid_plotselectslice(byval handle as integer) as bool
DECLARE FUNCTION valid_plotscrollslice(byval handle as integer) as bool
DECLARE FUNCTION valid_plotpanelslice(byval handle as integer) as bool
DECLARE FUNCTION valid_resizeable_slice(byval handle as integer, axes as AxisSpecifier, want_to_fill as bool=NO) as bool
DECLARE FUNCTION create_plotslice_handle(byval sl as Slice Ptr) as integer
DECLARE FUNCTION find_plotslice_handle(byval sl as Slice Ptr) as integer
DECLARE SUB set_plotslice_handle(byval sl as Slice Ptr, handle as integer)
DECLARE FUNCTION load_sprite_plotslice(byval spritetype as SpriteType, byval record as integer, byval pal as integer=-2) as integer
DECLARE SUB replace_sprite_plotslice(byval handle as integer, byval spritetype as SpriteType, byval record as integer, byval pal as integer=-2)
DECLARE SUB change_rect_plotslice(byval handle as integer, byval style as integer=-2, byval bgcol as integer=-99, byval fgcol as integer=-99, byval border as RectBorderTypes=borderUndef, byval translucent as RectTransTypes=transUndef, byval fuzzfactor as integer=0, byval raw_box_border as RectBorderTypes=borderUndef)
DECLARE FUNCTION valid_spriteslice_dat(byval sl as Slice Ptr) as bool

DECLARE FUNCTION find_menu_id (byval id as integer) as integer
DECLARE FUNCTION find_menu_handle (byval handle as integer) as integer
DECLARE FUNCTION valid_menu_handle (handle as integer, byref menuslot as integer) as bool
DECLARE FUNCTION find_menu_item_handle (byval handle as integer, byref found_in_menuslot as integer) as integer
DECLARE FUNCTION valid_menu_item_handle (handle as integer, byref found_in_menuslot as integer, byref found_in_mislot as integer = 0) as bool
DECLARE FUNCTION valid_menu_item_handle_ptr (handle as integer, byref mi as MenuDefItem ptr, byref found_in_menuslot as integer = 0, byref found_in_mislot as integer = 0) as bool
DECLARE FUNCTION assign_menu_item_handle (byref mi as menudefitem) as integer
DECLARE FUNCTION assign_menu_handles (byref menu as menudef) as integer
DECLARE FUNCTION menu_item_handle_by_slot(byval menuslot as integer, byval mislot as integer, byval visible_only as bool=YES) as integer
DECLARE FUNCTION find_menu_item_slot_by_string(byval menuslot as integer, s as string, byval mislot as integer=0, byval visible_only as bool=YES) as integer

DECLARE FUNCTION valid_item_slot(byval item_slot as integer) as bool
DECLARE FUNCTION valid_item(byval itemid as integer) as bool
DECLARE FUNCTION valid_hero_caterpillar_rank(who as integer) as bool
DECLARE FUNCTION valid_hero_party(byval who as integer, byval minimum as integer=0) as bool
DECLARE FUNCTION really_valid_hero_party(byval who as integer, byval maxslot as integer=40, byval errlvl as scriptErrEnum = serrBadOp) as bool
DECLARE FUNCTION valid_stat(byval statid as integer) as bool
DECLARE FUNCTION valid_plotstr(byval n as integer, byval errlvl as scriptErrEnum = serrBound) as bool
DECLARE FUNCTION valid_formation(byval form as integer) as bool
DECLARE FUNCTION valid_formation_slot(byval form as integer, byval slot as integer) as bool
DECLARE FUNCTION valid_zone(byval id as integer) as bool
DECLARE FUNCTION valid_door OVERLOAD (byval id as integer) as bool
DECLARE FUNCTION valid_door(thisdoor as door, byval id as integer=-1) as bool
DECLARE FUNCTION valid_map(map_id as integer) as bool
DECLARE FUNCTION valid_map_layer(layer as integer, byval errlvl as scriptErrEnum = serrBadOp) as bool
DECLARE FUNCTION valid_tile_pos(byval x as integer, byval y as integer) as bool
DECLARE FUNCTION valid_save_slot(slot as integer) as bool
DECLARE FUNCTION valid_color(index as integer) as bool

DECLARE SUB greyscalepal
DECLARE SUB tweakpalette (byval r as integer, byval g as integer, byval b as integer, byval first as integer = 0, byval last as integer = 255)
DECLARE SUB write_checkpoint ()

#endif
