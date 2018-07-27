'OHRRPGCE - loading.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#IFNDEF LOADING_BI
#DEFINE LOADING_BI

#include "reload.bi"

USING RELOAD

'*** NOTE ***
'As documented here, some types require initialisation, done by Clean*/Clear* (same thing) or Load*,
'and destruction, done by Unload*/Delete* (same thing). (ARRRGH! Can't we get anything straight??)
'Clean*/Clear* SUBs can also blank out already-initialised data; for objects that don't require
'initialisation that is all they do.

declare sub SerSingle (buf() as integer, byval index as integer, byval sing as single)
declare function DeSerSingle (buf() as integer, byval index as integer) as single

declare Sub SaveInventory16bit(invent() as InventSlot, byref z as integer, buf() as integer, byval first as integer=0, byval last as integer=-1)
declare Sub LoadInventory16Bit(invent() as InventSlot, byref z as integer, buf() as integer, byval first as integer=0, byval last as integer=-1)
declare sub serinventory8bit(invent() as inventslot, byref z as integer, buf() as integer)
declare sub deserinventory8bit(invent() as inventslot, byref z as integer, buf() as integer)
declare sub cleaninventory(invent() as inventslot)

'' Maps

declare function read_map_layer_name(gmap() as integer, layernum as integer) as string
declare sub write_map_layer_name(gmap() as integer, layernum as integer, newname as string)

declare sub LoadNPCD(file as string, dat() as NPCType)
declare sub SaveNPCD(file as string, dat() as NPCType)
declare sub SetNPCD(npcdata as NPCType, intoffset as integer, value as integer)
declare function GetNPCD(npcdata as NPCType, intoffset as integer) as integer

'Sprites are not loaded by these functions; can use CleanNPCInst to free them if you load them
declare sub LoadNPCL(file as string, dat() as npcinst)
declare sub SaveNPCL(file as string, dat() as npcinst)
declare sub DeserNPCL(npc() as npcinst, byref z as integer, buffer() as integer, byval num as integer, byval xoffset as integer, byval yoffset as integer)
declare sub CleanNPCInst(inst as NPCInst)
declare sub CleanNPCL(dat() as npcinst)


'*** Requires construction + destruction ***
declare sub UnloadTilemap(map as TileMap)
declare sub UnloadTilemaps(layers() as TileMap)
declare sub LoadTilemap(map as TileMap, filename as string)
declare function LoadTilemaps(layers() as TileMap, filename as string, allowfail as bool = NO) as bool
declare sub SaveTilemap(tmap as TileMap, filename as string)
declare sub SaveTilemaps(tmaps() as TileMap, filename as string)
declare sub CleanTilemap(map as TileMap, byval wide as integer, byval high as integer, byval layernum as integer = 0)
declare sub CleanTilemaps(layers() as TileMap, byval wide as integer, byval high as integer, byval numlayers as integer)
declare sub CopyTilemap(dest as TileMap, src as TileMap)
declare function GetTilemapInfo(filename as string, info as TilemapInfo) as bool
declare sub MergeTileMap(mine as TileMap, theirs_file as string, base_file as string)
declare sub MergeTileMaps(mine() as TileMap, theirs_file as string, base_file as string)

'*** Requires construction + destruction ***
declare sub CleanZoneMap(zmap as ZoneMap, byval wide as integer, byval high as integer)
declare sub DeleteZoneMap(zmap as ZoneMap)
declare function SetZoneTile(zmap as ZoneMap, byval id as integer, byval x as integer, byval y as integer) as integer
declare sub UnsetZoneTile(zmap as ZoneMap, byval id as integer, byval x as integer, byval y as integer)
declare function WriteZoneTile(zmap as ZoneMap, id as integer, x as integer, y as integer, value as integer) as bool
declare function CheckZoneAtTile(zmap as ZoneMap, id as integer, x as integer, y as integer) as bool
declare sub GetZonesAtTile OVERLOAD (zmap as ZoneMap, zones() as integer, x as integer, y as integer, maxid as integer = 65534)
declare function GetZonesAtTile OVERLOAD (zmap as ZoneMap, x as integer, y as integer, maxid as integer = 65534) as integer vector
declare function GetZoneInfo(zmap as ZoneMap, byval id as integer) as ZoneInfo ptr
declare sub DebugZoneMap(zmap as ZoneMap, byval x as integer = -1, byval y as integer = -1)
declare sub ZoneToTileMap(zmap as ZoneMap, tmap as TileMap, byval id as integer, byval bitnum as integer)
declare sub SaveZoneMap(zmap as ZoneMap, filename as string, rsrect as RectType ptr = NULL)
declare sub LoadZoneMap(zmap as ZoneMap, filename as string)

declare SUB DeserDoorLinks(filename as string, array() as doorlink)
declare Sub SerDoorLinks(filename as string, array() as doorlink, byval withhead as bool = YES)
declare sub CleanDoorLinks(array() as doorlink)
declare Sub DeSerDoors(filename as string, array() as door, byval record as integer)
declare Sub SerDoors(filename as string, array() as door, byval record as integer)
declare Function read_one_door(byref thisdoor as door, byval map_id as integer, byval door_id as integer) as bool
declare Sub CleanDoors(array() as door)


declare Sub LoadStats(byval fh as integer, sta as stats ptr)
declare Sub SaveStats(byval fh as integer, sta as stats ptr)
declare Sub LoadStats2(byval fh as integer, lev0 as stats ptr, levMax as stats ptr)
declare Sub SaveStats2(byval fh as integer, lev0 as stats ptr, levMax as stats ptr)

declare sub loadherodata (hero as herodef, byval index as integer)
declare sub saveherodata (hero as herodef, byval index as integer)
declare sub ClearHeroData (hero as HeroDef)
declare function GetHeroHandPos(byval hero_id as integer, byval which_frame as integer, byval isy as integer) as integer

declare Sub LoadVehicle OVERLOAD (file as string, vehicle as VehicleData, byval record as integer)
declare Sub LoadVehicle OVERLOAD (file as string, veh() as integer, vehname as string, byval record as integer)
declare Sub SaveVehicle OVERLOAD (file as string, veh() as integer, vehname as string, byval record as integer)
declare Sub SaveVehicle OVERLOAD (file as string, vehicle as VehicleData, byval record as integer)
declare Sub ClearVehicle (vehicle as VehicleData)

declare Sub SaveUIColors (colarray() as integer, boxarray() as BoxStyle, byval palnum as integer)
declare Sub LoadUIColors (colarray() as integer, boxarray() as BoxStyle, byval palnum as integer=-1)
declare Sub DefaultUIColors (colarray() as integer, boxarray() as BoxStyle)
declare Sub OldDefaultUIColors (colarray() as integer, boxarray() as BoxStyle)
declare Sub GuessDefaultUIColors (masterpal() as RGBcolor, colarray() as integer, boxarray() as BoxStyle)
declare Function UiColorCaption(byval n as integer) as string
DECLARE FUNCTION LowColorCode () as integer
declare Function ColorIndex(n as integer, autotoggle as bool = YES) as integer
declare Function mouse_hover_tinted_color(text_col as integer = -1) as integer

declare Sub LoadTextBox (byref box as TextBox, byval record as integer)
declare Sub SaveTextBox (byref box as TextBox, byval record as integer)
declare Sub ClearTextBox (byref box as TextBox)
declare Function textbox_lines_to_string(byref box as TextBox) as string
DECLARE FUNCTION textbox_preview_line OVERLOAD (boxnum as integer, maxwidth as integer = 700) as string
DECLARE FUNCTION textbox_preview_line OVERLOAD (box as TextBox, maxwidth as integer = 700) as string

DECLARE SUB initattackdata OVERLOAD (recbuf() as integer)
DECLARE SUB initattackdata OVERLOAD (byref atk as AttackData)
DECLARE SUB loadoldattackelementalfail (byref cond as AttackElementCondition, buf() as integer, byval element as integer)
DECLARE SUB loadoldattackdata (array() as integer, byval index as integer)
DECLARE SUB saveoldattackdata (array() as integer, byval index as integer)
DECLARE SUB loadnewattackdata (array() as integer, byval index as integer)
DECLARE SUB savenewattackdata (array() as integer, byval index as integer)
DECLARE SUB loadattackdata OVERLOAD (array() as integer, byval index as integer)
DECLARE SUB loadattackdata OVERLOAD (byref atkdat as AttackData, byval index as integer)
DECLARE SUB SerAttackElementCond (cond as AttackElementCondition, buf() as integer, byval index as integer)
DECLARE SUB DeSerAttackElementCond (byref cond as AttackElementCondition, buf() as integer, byval index as integer)
DECLARE SUB convertattackdata(buf() as integer, byref atkdat as AttackData)
DECLARE SUB saveattackdata (array() as integer, byval index as integer)

DECLARE SUB load_tile_anims (byval tileset_num as integer, tastuf() as integer)
DECLARE SUB save_tile_anims (byval tileset_num as integer, tastuf() as integer)
DECLARE FUNCTION tile_anim_deanimate_tile (tileid as integer, tastuf() as integer) as integer
DECLARE FUNCTION tile_anim_animate_tile (tileid as integer, pattern_num as integer, tastuf() as integer) as integer
DECLARE FUNCTION tile_anim_is_empty(pattern_num as integer, tastuf() as integer) as bool

DECLARE SUB palette16_save (pal as Palette16 ptr, pal_num as integer)

DECLARE SUB save_animations_node(sprset_node as Node ptr, sprset as SpriteSet ptr)
DECLARE SUB load_animations_node(sprset_node as Node ptr, sprset as SpriteSet ptr)

DECLARE SUB convert_mxs_to_rgfx(infile as string, outfile as string, sprtype as SpriteType)
DECLARE SUB convert_pt_to_rgfx(dest_type as SpriteType)
DECLARE SUB initialise_backcompat_pt_frameids (fr as Frame ptr, sprtype as SpriteType)

DECLARE FUNCTION rgfx_open OVERLOAD (filename as string, expect_exists as bool = NO) as DocPtr
DECLARE FUNCTION rgfx_open OVERLOAD (sprtype as SpriteType, expect_exists as bool = NO) as DocPtr
DECLARE FUNCTION rgfx_find_spriteset (rgfxdoc as DocPtr, sprtype as SpriteType, setnum as integer) as Node ptr
DECLARE FUNCTION rgfx_num_spritesets (rgfxdoc as DocPtr, sprtype as SpriteType) as integer
DECLARE FUNCTION rgfx_load_spriteset OVERLOAD (rgfxdoc as Reload.DocPtr, sprtype as SpriteType, setnum as integer, cache_def_anims as bool = NO) as Frame ptr
DECLARE FUNCTION rgfx_load_spriteset OVERLOAD (sprtype as SpriteType, setnum as integer, expect_exists as bool = YES) as Frame ptr
DECLARE SUB rgfx_save_spriteset OVERLOAD (rgfxdoc as DocPtr, fr as Frame ptr, sprtype as SpriteType, setnum as integer, defpal as integer = -1)
DECLARE SUB rgfx_save_spriteset OVERLOAD (fr as Frame ptr, sprtype as SpriteType, setnum as integer, defpal as integer = -1)
DECLARE SUB rgfx_save_global_animations (rgfxdoc as DocPtr, def_anim as SpriteSet ptr)
DECLARE FUNCTION read_sprite_idx_backcompat_translation (rgfxdoc as DocPtr, sprtype as SpriteType, oldidx as integer) as integer
DECLARE SUB add_sprite_idx_backcompat_translation (rgfxdoc as DocPtr, sprtype as SpriteType, oldidx as integer, newidx as integer)
DECLARE FUNCTION rgfx_load_global_animations (rgfxdoc as Doc ptr) as SpriteSet ptr
DECLARE FUNCTION default_global_animations (sprtype as SpriteType) as SpriteSet ptr
DECLARE SUB default_frame_group_info(sprtype as SpriteType, info() as FrameGroupInfo)

DECLARE FUNCTION spriteset_to_basic_spritesheet(ss as Frame ptr) as Frame ptr
DECLARE FUNCTION spriteset_from_basic_spritesheet(sheet as Frame ptr, sprtype as SpriteType, numframes as integer) as Frame ptr

DECLARE SUB loaditemdata (array() as integer, byval index as integer)
DECLARE SUB saveitemdata (array() as integer, byval index as integer)
DECLARE FUNCTION LoadOldItemElemental (itembuf() as integer, byval element as integer) as single
DECLARE SUB LoadItemElementals (byval index as integer, itemresists() as single)
DECLARE FUNCTION get_item_stack_size (byval item_id as integer) as integer
DECLARE FUNCTION item_read_equipbit(itembuf() as integer, hero_id as integer) as bool
DECLARE SUB item_write_equipbit(itembuf() as integer, hero_id as integer, value as bool)

DECLARE FUNCTION backcompat_element_dmg (byval weak as integer, byval strong as integer, byval absorb as integer) as double
DECLARE FUNCTION loadoldenemyresist (array() as integer, byval element as integer) as single
DECLARE SUB clearenemydata OVERLOAD (enemy as EnemyDef)
DECLARE SUB clearenemydata OVERLOAD (buf() as integer)
DECLARE SUB loadenemydata OVERLOAD (array() as integer, byval index as integer, byval altfile as bool = NO)
DECLARE SUB loadenemydata OVERLOAD (enemy as EnemyDef, byval index as integer, byval altfile as bool = NO)
DECLARE SUB saveenemydata OVERLOAD (array() as integer, byval index as integer, byval altfile as bool = NO)
DECLARE SUB saveenemydata OVERLOAD (enemy as EnemyDef, byval index as integer, byval altfile as bool = NO)

DECLARE SUB ClearFormation (form as Formation)
DECLARE SUB LoadFormation OVERLOAD (form as Formation, byval index as integer)
DECLARE SUB LoadFormation OVERLOAD (form as Formation, filename as string, byval index as integer)
DECLARE SUB SaveFormation OVERLOAD (form as Formation, byval index as integer)
DECLARE SUB SaveFormation OVERLOAD (form as Formation, filename as string, byval index as integer)
'index is formation set number, starting from 1!
DECLARE SUB LoadFormationSet (formset as FormationSet, byval index as integer)
DECLARE SUB SaveFormationSet (formset as FormationSet, byval index as integer)

DECLARE SUB load_hero_formation(byref hform as HeroFormation, byval form_num as integer)
DECLARE SUB default_hero_formation(byref hform as HeroFormation)
DECLARE FUNCTION last_hero_formation_id() as integer
DECLARE SUB save_hero_formation(byref hform as HeroFormation, byval form_num as integer)
DECLARE SUB write_hero_formation(byval par as NodePtr, byref hform as HeroFormation)

DECLARE SUB load_hsp_header(filename as string, header as HSHeader)
DECLARE SUB load_script_triggers_and_names()

DECLARE SUB save_string_list(array() as string, filename as string)
DECLARE SUB load_string_list(array() as string, filename as string)

DECLARE FUNCTION load_map_pos_save_offset(byval mapnum as integer) as XYPair

DECLARE SUB save_npc_instances OVERLOAD (filename as string, npc() as NPCInst)
DECLARE SUB save_npc_instances OVERLOAD (byval npcs_node as NodePtr, npc() as NPCInst)
DECLARE SUB save_npc_instance OVERLOAD (byval parent as NodePtr, byval index as integer, npc as NPCInst)
DECLARE SUB save_npc_instance OVERLOAD (byval parent as NodePtr, byval index as integer, npc as NPCInst, map_offset as XYPair)

DECLARE SUB load_npc_instances OVERLOAD (filename as string, npc() as NPCInst)
DECLARE SUB load_npc_instances OVERLOAD (byval npcs_node as NodePtr, npc() as NPCInst)
DECLARE SUB load_npc_instance OVERLOAD (byval n as NodePtr, npc as NPCInst)
DECLARE SUB load_npc_instance OVERLOAD (byval n as NodePtr, npc as NPCInst, map_offset as XYPair)

DECLARE FUNCTION load_gamename (filename as string="") as string
DECLARE FUNCTION load_aboutline (filename as string="") as string
DECLARE SUB save_gamename (s as string, filename as string="")
DECLARE SUB save_aboutline (s as string, filename as string="")
DECLARE SUB write_engine_version_node (byval parent as NodePtr, nodename as string)
DECLARE FUNCTION read_engine_version_node (vernode as Node ptr) as EngineVersion
DECLARE FUNCTION read_last_editor_version () as EngineVersion
DECLARE FUNCTION read_archinym_version () as string

DECLARE SUB update_general_data ()

DECLARE SUB load_distrib_state OVERLOAD (byref distinfo as DistribState)
DECLARE SUB load_distrib_state OVERLOAD (byref distinfo as DistribState, filename as string)
DECLARE SUB load_distrib_state OVERLOAD (byref distinfo as DistribState, byval node as Reload.NodePtr)
DECLARE SUB save_distrib_state OVERLOAD (byref distinfo as DistribState)
DECLARE SUB save_distrib_state OVERLOAD (byref distinfo as DistribState, filename as string)
DECLARE SUB save_distrib_state OVERLOAD (byref distinfo as DistribState, byval node as Reload.NodePtr)

DECLARE FUNCTION WriteXYPairNode (byval parent as NodePtr, nodename as string, pair as XYPair) as NodePtr
DECLARE FUNCTION WritePicPalNode (byval parent as NodePtr, nodename as string, byval pic as integer, byval pal as integer=-1) as NodePtr
DECLARE FUNCTION WriteStatsNode (byval parent as NodePtr, nodename as string, statobj as Stats) as NodePtr

DECLARE SUB ReadStatsNode (byval stats as NodePtr, statobj as Stats)

DECLARE FUNCTION get_general_reld() as NodePtr
DECLARE SUB write_general_reld()
DECLARE SUB close_general_reld()
DECLARE FUNCTION get_buttonname_code(byval n as integer) as string
DECLARE FUNCTION default_button_name_for_platform(platform_key as string, byval button_name_id as integer) as string

DECLARE SUB load_shop_stuff(byval shop_id as integer, byval stuff_list as NodePtr)

DECLARE SUB load_non_elemental_elements (elem() as bool)

DECLARE SUB cropafter (byval index as integer, byref limit as integer, byval flushafter as bool, lump as string, byval bytes as integer, byval prompt as integer=YES)


EXTERN rgfx_lumpnames() as string

#ENDIF
