#ifndef YETMORE2_BI
#define YETMORE2_BI

#include "reload.bi"

DECLARE SUB apply_game_window_settings (reloading as bool = NO)
DECLARE SUB set_speedcontrol ()

DECLARE SUB initgamedefaults
DECLARE SUB innRestore ()
DECLARE SUB setmapxy
DECLARE SUB limitcamera (byref x as integer, byref y as integer)
DECLARE SUB showplotstrings
DECLARE SUB makebackups
DECLARE SUB make_map_backups
DECLARE SUB update_backdrop_slice
DECLARE FUNCTION checkfordeath () as bool
DECLARE SUB exitprogram (byval need_fade_out as bool = NO, byval errorout as integer = 0)
DECLARE SUB verify_quit
DECLARE FUNCTION titlescreen () as bool
DECLARE FUNCTION mapstatetemp(mapnum as integer, prefix as string) as string
DECLARE SUB savemapstate_gmap(mapnum as integer, prefix as string)
DECLARE SUB savemapstate_npcl OVERLOAD (mapnum as integer, prefix as string)
'DECLARE SUB savemapstate_npcl OVERLOAD (byval node as Reload.NodePtr)   'where did this come from?
DECLARE SUB savemapstate_npcd(mapnum as integer, prefix as string)
DECLARE SUB savemapstate_tilemap(mapnum as integer, prefix as string)
DECLARE SUB savemapstate_passmap(mapnum as integer, prefix as string)
DECLARE SUB savemapstate_zonemap(mapnum as integer, prefix as string)
DECLARE SUB savemapstate_bitmask (mapnum as integer, savemask as integer = 255, prefix as string)
DECLARE SUB loadmapstate_gmap (mapnum as integer, prefix as string, dontfallback as bool = NO)
DECLARE SUB loadmapstate_npcl (mapnum as integer, prefix as string, dontfallback as bool = NO)
DECLARE SUB loadmapstate_npcd (mapnum as integer, prefix as string, dontfallback as bool = NO)
DECLARE SUB loadmapstate_tilemap (mapnum as integer, prefix as string, dontfallback as bool = NO)
DECLARE SUB loadmapstate_passmap (mapnum as integer, prefix as string, dontfallback as bool = NO)
DECLARE SUB loadmapstate_zonemap (mapnum as integer, prefix as string, dontfallback as bool = NO)
DECLARE SUB loadmapstate_bitmask (mapnum as integer, loadmask as integer, prefix as string, dontfallback as bool = NO)
DECLARE SUB deletemapstate (mapnum as integer, killmask as integer, prefix as string)
DECLARE FUNCTION gmap_index_affects_tiles(byval index as integer) as bool
DECLARE SUB reloadmap_gmap_no_tilesets()
DECLARE SUB reloadmap_npcd()
DECLARE SUB reloadmap_npcl(merge as bool)
DECLARE SUB reloadmap_tilemap_and_tilesets(merge as bool)
DECLARE SUB reloadmap_passmap(merge as bool)
DECLARE SUB reloadmap_foemap(merge as bool)
DECLARE SUB reloadmap_zonemap()
DECLARE SUB deletetemps
DECLARE SUB debug_npcs ()
DECLARE SUB npc_debug_display (draw_walls as bool)
DECLARE FUNCTION game_setoption(opt as string, arg as string) as integer
DECLARE SUB handshake_with_master ()
DECLARE SUB wrong_spawned_version_fatal_error ()
DECLARE SUB check_game_custom_versions_match ()
DECLARE SUB receive_file_updates ()
DECLARE SUB try_to_reload_lumps_onmap ()
DECLARE SUB try_reload_lumps_anywhere ()
DECLARE SUB live_preview_menu ()


#endif
