#ifndef MORESUBS_BI
#define MORESUBS_BI

#include "gfx.bi"

DECLARE SUB addhero (byval who as integer, byval slot as integer, byval forcelevel as integer=-1)
DECLARE FUNCTION averagelev () as integer
DECLARE SUB calibrate

DECLARE FUNCTION consumeitem (byval invslot as integer) as bool
DECLARE FUNCTION countitem (byval item_id as integer) as integer
DECLARE FUNCTION count_equipped_item(byval item_id as integer) as integer
DECLARE SUB getitem (byval item_id as integer, byval num as integer=1)
DECLARE SUB delitem (byval item_id as integer, byval amount as integer=1)
DECLARE FUNCTION room_for_item (byval itemid as integer, byval num as integer = 1) as bool

DECLARE SUB update_textbox ()
DECLARE SUB choicebox_controls()
DECLARE FUNCTION user_textbox_advance() as bool

DECLARE SUB doswap (byval s as integer, byval d as integer)
DECLARE SUB party_change_updates ()
DECLARE SUB evalherotags ()
DECLARE SUB evalitemtags ()
DECLARE SUB hero_swap_menu (byval reserve_too as bool)
DECLARE SUB settag OVERLOAD (byval tagnum as integer, byval value as integer = 4444)
DECLARE SUB settag OVERLOAD (tagbits() as integer, byval tagnum as integer, byval value as integer = 4444)
DECLARE FUNCTION istag OVERLOAD (num as integer, zero as bool=NO) as bool
DECLARE FUNCTION istag OVERLOAD (tagbits() as integer, num as integer, zero as bool=NO) as bool
DECLARE SUB minimap (byval x as integer, byval y as integer)
DECLARE FUNCTION teleporttool () as bool
DECLARE FUNCTION onwho (caption as string, skip_if_alone as bool = YES) as integer
DECLARE FUNCTION renamehero (who as integer, escapable as bool) as bool
DECLARE SUB resetgame ()
DECLARE SUB get_max_levelmp (ret() as integer, byval hero_level as integer)
DECLARE SUB reset_levelmp (byref hero as HeroState)
DECLARE SUB reset_game_state ()
DECLARE SUB reset_map_state (map as MapModeState)

DECLARE FUNCTION settingstring (searchee as string, setting as string, result as string) as bool
DECLARE SUB shop (byval id as integer)
DECLARE FUNCTION useinn (byval price as integer, byval holdscreen as integer) as bool

DECLARE SUB tagdisplay (page as integer)
DECLARE SUB show_hero_zones (page as integer)

DECLARE SUB readjoysettings
DECLARE SUB writejoysettings

DECLARE FUNCTION gamepadmap_from_reload(gamepad as NodePtr, byval use_dpad as bool=NO) as GamePadMap
DECLARE FUNCTION use_touch_textboxes() as bool
DECLARE FUNCTION should_disable_virtual_gamepad() as bool
DECLARE FUNCTION should_hide_virtual_gamepad_when_suspendplayer() as bool
DECLARE SUB remap_virtual_gamepad(nodename as string)

DECLARE FUNCTION default_margin() as integer
DECLARE FUNCTION default_margin_for_game() as integer

DECLARE FUNCTION playtime (byval d as integer, byval h as integer, byval m as integer) as string
DECLARE SUB playtimer

#endif
