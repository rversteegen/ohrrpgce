'OHRRPGCE GAME - Saving and loading games
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
#ifdef TRY_LANG_FB
 #define __langtok #lang
 __langtok "fb"
#else
 OPTION STATIC
 OPTION EXPLICIT
#endif

#include "config.bi"
#include "ver.txt"
#include "udts.bi"
#include "allmodex.bi"
#include "common.bi"
#include "gglobals.bi"
#include "const.bi"
#include "loading.bi"
#include "reload.bi"
#include "reloadext.bi"
#include "savegame.bi"
#include "moresubs.bi"
#include "menustuf.bi"
#include "yetmore.bi"

USING Reload
USING Reload.Ext

'--Local subs and functions

DECLARE SUB gamestate_to_reload(byval node as Reload.NodePtr)
DECLARE SUB gamestate_state_to_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_script_to_reload(byval parent as Reload.NodePtr)
DECLARE FUNCTION script_trigger_from_reload(byval parent as Reload.NodePtr, node_name as STRING) as integer
DECLARE SUB gamestate_globals_to_reload(byval parent as Reload.NodePtr, byval first as integer=0, byval last as integer=4095)
DECLARE SUB gamestate_maps_to_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_npcs_to_reload(byval parent as Reload.NodePtr, byval map as integer)
DECLARE SUB gamestate_tags_to_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_onetime_to_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_party_to_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_spelllist_to_reload(byval hero_slot as integer, byval spell_list as integer, byval parent as Reload.NodePtr)
DECLARE SUB gamestate_inventory_to_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_shops_to_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_vehicle_to_reload(byval parent as Reload.NodePtr)

DECLARE SUB new_loadgame(byval slot as integer)
DECLARE SUB gamestate_from_reload(byval node as Reload.NodePtr)
DECLARE SUB gamestate_state_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_script_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB script_trigger_to_reload(byval parent as Reload.NodePtr, node_name as STRING, byval script_id as integer)
DECLARE SUB gamestate_globals_from_reload(byval parent as Reload.NodePtr, byval first as integer=0, byval last as integer=4095)
DECLARE SUB gamestate_maps_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_npcs_from_reload(byval parent as Reload.NodePtr, byval map as integer)
DECLARE SUB gamestate_tags_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_onetime_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_party_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_spelllist_from_reload(byval hero_slot as integer, byval spell_list as integer, byval parent as Reload.NodePtr)
DECLARE SUB gamestate_inventory_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_shops_from_reload(byval parent as Reload.NodePtr)
DECLARE SUB gamestate_vehicle_from_reload(byval parent as Reload.NodePtr)

DECLARE SUB rsav_warn (s as STRING)
DECLARE SUB rsav_warn_wrong (expected as STRING, byval n as Reload.NodePtr)
DECLARE SUB rsav_check_children_names (byval n as Reload.NodePtr, expected as STRING)

DECLARE SUB new_loadglobalvars (byval slot as integer, byval first as integer, byval last as integer)

DECLARE FUNCTION new_save_slot_used (byval slot as integer) as integer
DECLARE FUNCTION new_count_used_save_slots() as integer
DECLARE SUB new_get_save_slot_preview(byval slot as integer, pv as SaveSlotPreview)

'--old save/load support
DECLARE SUB old_loadgame (byval slot as integer)
DECLARE SUB old_loadglobalvars (byval slot as integer, byval first as integer, byval last as integer)
DECLARE SUB old_get_save_slot_preview(byval slot as integer, pv as SaveSlotPreview)
DECLARE SUB show_load_index(byval z as integer, caption as string, byval slot as integer=0)
DECLARE SUB rebuild_inventory_captions (invent() as InventSlot)
DECLARE FUNCTION old_save_slot_used (byval slot as integer) as integer
DECLARE FUNCTION old_count_used_save_slots() as integer

DIM SHARED old_savefile as STRING
DIM SHARED savedir as STRING

DIM SHARED current_save_slot as integer '--used in rsav_warn

'-----------------------------------------------------------------------

SUB init_save_system()

 '--set up old savegame file
 old_savefile = trimextension(sourcerpg) + ".sav"
 #IFDEF __UNIX__
 IF NOT fileisreadable(old_savefile) THEN
  'for a systemwide linux install, save files go in the prefs dir
  old_savefile = prefsdir & SLASH & trimpath(old_savefile)
 END IF
 #ENDIF
 
 '--set up new rsav folder
 
 DIM rpg_folder as STRING = trimfilename(sourcerpg)
 IF diriswriteable(rpg_folder) THEN
  '--default location is same as the RPG file (if possible)
  savedir = trimextension(sourcerpg) & ".saves"
 ELSE
  '--fallback location is prefsdir
  savedir = prefsdir & SLASH & "saves"
 END IF
 IF NOT isdir(savedir) THEN MKDIR savedir

END SUB

SUB loadgame (byval slot as integer)
 '--Works under the assumption that resetgame has already been called.
 IF keyval(scLeftShift) = 0 AND keyval(scRightShift) = 0 THEN
  'bypass new loading if shift is held down when you load
  DIM filename as STRING
  filename = savedir & SLASH & slot & ".rsav"
  IF isfile(filename) THEN
   debuginfo "loading awesome new loadgame from " & filename
   new_loadgame slot
   EXIT SUB
  END IF
 END IF
 debuginfo "loading from slot " & slot & " of boring old " & old_savefile
 old_loadgame slot
END SUB

SUB loadglobalvars (byval slot as integer, byval first as integer, byval last as integer)
 IF keyval(scLeftShift) = 0 AND keyval(scRightShift) = 0 THEN
  'bypass new loading if shift is held down when you load
  DIM filename as STRING
  filename = savedir & SLASH & slot & ".rsav"
  IF isfile(filename) THEN
   debuginfo "loading awesome new loadglobalvars from " & filename
   new_loadglobalvars slot, first, last
   EXIT SUB
  END IF
 END IF
 debuginfo "loadglobalvars from slot " & slot & " of boring old " & old_savefile
 old_loadglobalvars slot, first, last
END SUB

SUB get_save_slot_preview(byval slot as integer, pv as SaveSlotPreview)
 IF new_save_slot_used(slot) THEN
  debuginfo "use nifty new save slot preview for slot " & slot
  new_get_save_slot_preview slot, pv
 ELSE
  debuginfo "fall back to boring old save slot preview for " & slot
  old_get_save_slot_preview slot, pv
 END IF
END SUB

FUNCTION save_slot_used (byval slot as integer) as integer
 IF new_save_slot_used(slot) THEN
  RETURN YES
 END IF
 RETURN old_save_slot_used(slot)
END FUNCTION

FUNCTION count_used_save_slots() as integer
 DIM count as integer = new_count_used_save_slots()
 IF count > 0 THEN
  RETURN count
 END IF
 RETURN old_count_used_save_slots()
END FUNCTION

'-----------------------------------------------------------------------

SUB savegame (byval slot as integer)
 current_save_slot = slot
 
 DIM doc as DocPtr
 doc = CreateDocument()
 
 DIM node as NodePtr
 node = CreateNode(doc, "rsav")
 SetRootNode(doc, node)
 gamestate_to_reload node
 
 DIM filename as STRING
 filename = savedir & SLASH & slot & ".rsav"
 SerializeBin filename, doc
 
 FreeDocument doc
 current_save_slot = -1
END SUB

SUB new_loadgame(byval slot as integer)
 current_save_slot = slot
 
 DIM filename as STRING
 filename = savedir & SLASH & slot & ".rsav"

 IF NOT isfile(filename) THEN
  debug "Save file missing: " & filename
  current_save_slot = -1
  EXIT SUB
 END IF

 DIM doc as DocPtr
 doc = LoadDocument(filename)
 
 DIM node as NodePtr
 node = DocumentRoot(doc)
 
 gamestate_from_reload node
 
 FreeDocument doc
 current_save_slot = -1
END SUB

SUB rsav_warn (s as STRING)
 debug "Save slot " & current_save_slot & ": " & s
END SUB

SUB rsav_warn_wrong (expected as STRING, byval n as Reload.NodePtr)
 rsav_warn "expected " & expected & " but found " & NodeName(n)
END SUB

SUB rsav_check_children_names (byval n as Reload.NodePtr, expected as STRING)
 DIM child as Reload.NodePtr = FirstChild(n)
 WHILE child
  IF NodeName(child) <> expected THEN rsav_warn_wrong expected, child
  child = NextSibling(child)
 WEND
END SUB

'-----------------------------------------------------------------------

SUB gamestate_from_reload(byval node as Reload.NodePtr)
 IF NodeName(node) <> "rsav" THEN rsav_warn "root node is not rsav"

 IF GetChildNodeInt(node, "ver") > CURRENT_RSAV_VERSION THEN
  rsav_warn "new save file on old game player. Some data might get lost"
  fadein
  pop_warning "This save file was created with a more recent version of the OHRRPGCE, and some things will not load correctly. Download the latest version at http://HamsterRepublic.com"
  fadeout 0, 0, 0
 END IF 

 gamestate_state_from_reload node
 gamestate_script_from_reload node
 gamestate_maps_from_reload node
 gamestate_tags_from_reload node
 gamestate_onetime_from_reload node
 gamestate_party_from_reload node
 gamestate_inventory_from_reload node
 gamestate_shops_from_reload node
 gamestate_vehicle_from_reload node

END SUB

SUB gamestate_state_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "state")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 DIM i as integer
 
 gam.map.id = GetChildNodeInt(node, "current_map")

 DIM map_offset as XYPair
 map_offset = load_map_pos_save_offset(gam.map.id)

 ch = GetChildByName(node, "caterpillar")
 rsav_check_children_names(ch, "hero")
 n = FirstChild(ch, "hero")
 DO WHILE n
  i = GetInteger(n)
  SELECT CASE i
   CASE 0 TO 3
    catx(i * 5) = GetChildNodeInt(n, "x") + map_offset.x * 20
    caty(i * 5) = GetChildNodeInt(n, "y") + map_offset.y * 20
    catd(i * 5) = GetChildNodeInt(n, "d")
   CASE ELSE
    rsav_warn "invalid caterpillar hero index " & i
  END SELECT
  n = NextSibling(n, "hero")
 LOOP

 gam.random_battle_countdown = GetChildNodeInt(node, "random_battle_countdown") 

 ch = GetChildByName(node, "camera") 
 mapx = GetChildNodeInt(ch, "x")
 mapy = GetChildNodeInt(ch, "y")
 gen(genCamera) = GetChildNodeInt(ch, "mode")
 FOR i = 0 TO 3
  gen(genCamArg1 + i) = GetChildNodeInt(ch, "arg" & i+1)
 NEXT i
 
 gold = GetChildNodeInt(node, "gold")

 ch = GetChildByName(node, "playtime")
 gen(genDays) = GetChildNodeInt(ch, "days")
 gen(genHours) = GetChildNodeInt(ch, "hours")
 gen(genMinutes) = GetChildNodeInt(ch, "minutes")
 gen(genSeconds) = GetChildNodeInt(ch, "seconds")

 ch = GetChildByName(node, "textbox")
 gen(genTextboxBackdrop) = GetChildNodeInt(ch, "backdrop")

 ch = GetChildByName(node, "status_char")
 gen(genPoison) = GetChildNodeInt(ch, "poison")
 gen(genStun) = GetChildNodeInt(ch, "stun")
 gen(genMute) = GetChildNodeInt(ch, "mute")

 gen(genDamageCap) = GetChildNodeInt(node, "damage_cap")
 gen(genLevelCap) = GetChildNodeInt(node, "level_cap", 99)
 gen(genLevelCap) = small(gen(genLevelCap), gen(genMaxLevel))
 

 ch = GetChildByName(node, "stats")
 rsav_check_children_names(ch, "stat")
 n = FirstChild(ch, "stat")
 DO WHILE n
  i = GetInteger(n)
  SELECT CASE i
   CASE 0 TO 11
    gen(genStatCap + i) = GetChildNodeInt(n, "cap")
   CASE ELSE
    rsav_warn "invalid stat cap index " & i
  END SELECT
  n = NextSibling(n, "stat")
 LOOP

END SUB

SUB gamestate_script_from_reload(byval parent as Reload.NodePtr)

 DIM node as NodePtr
 node = GetChildByName(parent, "script")
 DIM ch as NodePtr 'used for sub-containers

 gamestate_globals_from_reload node

 IF readbit(gen(), genBits2, 2) = 0 THEN
  gen(genGameoverScript) = script_trigger_from_reload(node, "gameover_script")
  gen(genLoadgameScript) = script_trigger_from_reload(node, "loadgame_script")
 END IF
 
 ch = GetChildByName(node, "suspend")
 
 setbit gen(), genSuspendBits, 0, GetChildNodeExists(ch, "npcs")
 setbit gen(), genSuspendBits, 1, GetChildNodeExists(ch, "player")
 setbit gen(), genSuspendBits, 2, GetChildNodeExists(ch, "obstruction")
 setbit gen(), genSuspendBits, 3, GetChildNodeExists(ch, "herowalls")
 setbit gen(), genSuspendBits, 4, GetChildNodeExists(ch, "npcwalls")
 setbit gen(), genSuspendBits, 5, GetChildNodeExists(ch, "caterpillar")
 setbit gen(), genSuspendBits, 6, GetChildNodeExists(ch, "randomenemies")
 setbit gen(), genSuspendBits, 7, GetChildNodeExists(ch, "boxadvance")
 setbit gen(), genSuspendBits, 8, GetChildNodeExists(ch, "overlay")
 setbit gen(), genSuspendBits, 9, GetChildNodeExists(ch, "ambientmusic")
 
 gen(genScrBackdrop) = GetChildNodeInt(node, "backdrop")
END SUB

FUNCTION script_trigger_from_reload(byval parent as Reload.NodePtr, node_name as STRING) as integer
 DIM node as NodePtr
 node = GetChildByName(parent, node_name)
 IF node = 0 THEN RETURN 0
 IF GetChildNodeExists(node, "name") THEN
  rsav_warn "still don't have code to lookup a script id by string!"
  'FIXME: this doesn't work yet!
  RETURN 0
 END IF
 IF GetChildNodeExists(node, "id") THEN
  RETURN GetChildNodeInt(node, "id")
 END IF
 rsav_warn "neither 'id' nor 'name' found in script trigger node"
 RETURN 0 
END FUNCTION

SUB gamestate_globals_from_reload(byval parent as Reload.NodePtr, byval first as integer=0, byval last as integer=4095)

 DIM node as NodePtr
 node = GetChildByName(parent, "globals")
 DIM n as NodePtr 'used for numbered containers
 DIM i as integer

 rsav_check_children_names(node, "global")
 n = FirstChild(node, "global")
 DO WHILE n
  i = GetInteger(n)
  SELECT CASE i
   CASE first TO last
    global(i) = GetChildNodeInt(n, "int")
   CASE ELSE
    SELECT CASE i
     CASE 0 TO 4095
     CASE ELSE
      rsav_warn "invalid global id " & i
    END SELECT
  END SELECT
  n = NextSibling(n, "global")
 LOOP
END SUB

SUB gamestate_maps_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "maps")
 DIM n as NodePtr 'used for numbered containers
 DIM i as integer
 DIM loaded_current as integer = NO
 
 'FIXME: currently only supports saving the current map
 rsav_check_children_names(node, "map")
 n = FirstChild(node, "map")
 DO WHILE n
  i = GetInteger(n)
  IF i = gam.map.id THEN
   gamestate_npcs_from_reload n, gam.map.id
   loaded_current = YES
  END IF
  n = NextSibling(n, "map")
 LOOP

 IF loaded_current = NO THEN
  rsav_warn "couldn't find saved data for current map " & gam.map.id
 END IF
 
END SUB

SUB gamestate_npcs_from_reload(byval parent as Reload.NodePtr, byval map as integer)
 DIM node as NodePtr
 node = GetChildByName(parent, "npcs")

 DIM map_offset as XYPair
 map_offset = load_map_pos_save_offset(map)

 DIM i as integer
 DIM n as NodePtr
 rsav_check_children_names(node, "npc")
 n = FirstChild(node, "npc")
 DO WHILE n
  i = GetInteger(n)
  SELECT CASE i
   CASE 0 TO 299
    load_npc_loc n, npc(i), map_offset
   CASE ELSE
    rsav_warn "invalid npc instance " & i
  END SELECT
  n = NextSibling(n, "npc")
 LOOP

END SUB

SUB gamestate_tags_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "tags")
 
 DIM count as integer
 count = GetChildNodeInt(node, "count")
 IF count > 1000 THEN
  rsav_warn "too many saved tags 1000 < " & count
  count = 1000
 END IF

 DIM buf(INT(count / 16)) as integer

 DIM ch as NodePtr
 ch = GetChildByName(node, "data")
 LoadBitsetArray(ch, buf(), UBOUND(buf))
 
 FOR i as integer = 0 TO count - 1
  settag i, readbit(buf(), 0, i)
 NEXT i
 
END SUB

SUB gamestate_onetime_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "onetime")
 
 DIM count as integer
 count = GetChildNodeInt(node, "count")
 IF count > 1032 THEN
  rsav_warn "too many saved tags 1032 < " & count
  count = 1032
 END IF

 DIM buf(INT(count / 16)) as integer

 DIM ch as NodePtr
 ch = GetChildByName(node, "data")
 LoadBitsetArray(ch, buf(), UBOUND(buf))
 
 FOR i as integer = 0 TO count - 1
  settag 1000 + i, readbit(buf(), 0, i)
 NEXT i
 
END SUB

SUB gamestate_party_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "party")
 DIM slot as NodePtr
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 DIM i as integer
 DIM her as HeroDef 'used to provide default values when missing
 
 slot = FirstChild(node)
 DO WHILE slot
  IF NodeName(slot) = "slot" THEN
   i = GetInteger(slot)
   SELECT CASE i
    CASE 0 TO 40
    
     IF GetChildNodeExists(slot, "id") THEN
      hero(i) = GetChildNodeInt(slot, "id") + 1
      loadherodata @her, hero(i) - 1      
     END IF
     
     names(i) = GetChildNodeStr(slot, "name")
     
     IF GetChildNodeExists(slot, "locked") THEN
      setbit hmask(), 0, i, YES
     END IF

     ch = GetChildByName(slot, "stats")
     rsav_check_children_names(ch, "stat")
     DIM j as integer
     n = FirstChild(ch, "stat")
     DO WHILE n
      j = GetInteger(n)
      SELECT CASE j
       CASE 0 TO 11
        gam.hero(i).stat.cur.sta(j) = GetChildNodeInt(n, "cur")
        gam.hero(i).stat.max.sta(j) = GetChildNodeInt(n, "max")
       CASE ELSE
        rsav_warn "invalid stat id " & j
      END SELECT
      n = NextSibling(n, "stat")
     LOOP

     WITH gam.hero(i)
     
      .lev = GetChildNodeInt(slot, "lev")
      .lev_gain = GetChildNodeInt(slot, "lev_gain")
      .exp_cur = GetChildNodeInt(slot, "exp")
      .exp_next = GetChildNodeInt(slot, "exp_next")
      .def_wep = GetChildNodeInt(slot, "def_wep")

      ch = GetChildByName(slot, "wep")
      .wep_pic = GetChildNodeInt(ch, "pic")
      .wep_pal = GetChildNodeInt(ch, "pal")

      ch = GetChildByName(slot, "in_battle")
      .battle_pic = GetChildNodeInt(ch, "pic")
      .battle_pal = GetChildNodeInt(ch, "pal")

      ch = GetChildByName(slot, "walkabout")
      .pic = GetChildNodeInt(ch, "pic")
      .pal = GetChildNodeInt(ch, "pal")


      'elements/[weak|strong|absorb] are here, but we ignore them
      'rename_on_add and hide_empty_lists are here, but have been abandoned

      'Load defaults (for older saves which don't contain elemental data)
      IF hero(i) THEN
       FOR j = 0 TO gen(genNumElements) - 1
        .elementals(j) = her.elementals(j)
       NEXT
      END IF

      ch = GetChildByName(slot, "elements")
      IF ch THEN
       n = FirstChild(ch, "element")
       DO WHILE n
        DIM j as integer = GetInteger(n)
        IF j < gen(genNumElements) THEN
         .elementals(j) = GetChildNodeFloat(n, "damage", 1.0)
        END IF
        n = NextSibling(n, "element")
       LOOP
      END IF

      .rename_on_status = GetChildNodeExists(slot, "rename_on_status")

     END WITH 'gam.hero(i)
     
     ch = GetChildByName(slot, "battle_menus")
     rsav_check_children_names(ch, "menu")
     n = FirstChild(ch, "menu")
     DO WHILE n
      j = GetInteger(n)
      SELECT CASE j
       CASE 0 TO 5
        IF GetChildNodeExists(n, "attack") THEN
         bmenu(i, j) = GetChildNodeInt(n, "attack") + 1
        ELSEIF GetChildNodeExists(n, "items") THEN
         bmenu(i, j) = -10
        ELSEIF GetChildNodeExists(n, "spells") THEN
         bmenu(i, j) = (GetChildNodeInt(n, "spells") + 1) * -1
        END IF
       CASE ELSE
        rsav_warn "invalid battle menu id " & j
      END SELECT
      n = NextSibling(n, "menu")
     LOOP
     
     ch = GetChildByName(slot, "spell_lists")
     rsav_check_children_names(ch, "list")
     n = FirstChild(ch, "list")
     DO WHILE n
      j = GetInteger(n)
      SELECT CASE j
       CASE 0 TO 3
        gamestate_spelllist_from_reload(i, j, n)
       CASE ELSE
        rsav_warn "invalid spell list id " & j
      END SELECT
      n = NextSibling(n, "list")
     LOOP 

     ch = GetChildByName(slot, "level_mp")
     rsav_check_children_names(ch, "lev")
     n = FirstChild(ch, "lev")
     DO WHILE n
      j = GetInteger(n)
      SELECT CASE j
       CASE 0 TO 7
        lmp(i, j) = GetChildNodeInt(n, "val")
       CASE ELSE
        rsav_warn "invalid level mp slot " & j
      END SELECT
      n = NextSibling(n, "lev")
     LOOP 

     ch = GetChildByName(slot, "equipment")
     rsav_check_children_names(ch, "equip")
     n = FirstChild(ch, "equip")
     DO WHILE n
      j = GetInteger(n)
      SELECT CASE j
       CASE 0 TO 4
        eqstuf(i, j) = GetChildNodeInt(n, "item") + 1
       CASE ELSE
        rsav_warn "invalid equip slot " & j
      END SELECT
      n = NextSibling(n, "equip")
     LOOP 

    CASE ELSE
     rsav_warn "invalid hero party slot " & i
   END SELECT
  ELSE
   rsav_warn_wrong "slot", slot
  END IF
  slot = NextSibling(slot)
 LOOP
END SUB

SUB gamestate_spelllist_from_reload(byval hero_slot as integer, byval spell_list as integer, byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "spells")
 IF spell_list <> GetInteger(node) THEN
  rsav_warn "spell list id mismatch " & spell_list & "<>" & GetInteger(node)
 END IF
 
 DIM n as NodePtr 'used for numbered containers
 DIM i as integer

 DIM atk_id as integer
 rsav_check_children_names(node, "spell")
 n = FirstChild(node, "spell")
 DO WHILE n
  i = GetInteger(n)
  SELECT CASE i
   CASE 0 TO 23
    atk_id = GetChildNodeInt(n, "attack")
    spell(hero_slot, spell_list, i) = atk_id + 1
   CASE ELSE
    rsav_warn "invalid spell list slot " & i
  END SELECT
  n = NextSibling(n, "spell")
 LOOP
 
END SUB

SUB gamestate_inventory_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "inventory")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 DIM i as integer
 
 gen(genMaxInventory) = GetChildNodeInt(node, "size")

 ch = GetChildByName(node, "slots")
 DIM last as integer
 last = small(inventoryMax, UBOUND(inventory))
 
 rsav_check_children_names(ch, "slot")
 n = FirstChild(ch, "slot")
 DO WHILE n
  i = GetInteger(n)
  SELECT CASE i
   CASE 0 TO last
    WITH inventory(i)
     .used = YES
     .id = GetChildNodeInt(n, "item")
     .num = GetChildNodeInt(n, "num")
    END WITH
   CASE ELSE
    rsav_warn "invalid inventory slot id " & i
  END SELECT
  n = NextSibling(n, "slot")
 LOOP
 
 rebuild_inventory_captions inventory()
 
END SUB

SUB gamestate_shops_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "shops")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 DIM n2 as NodePtr 'also used for numbered containers
 DIM i as integer
 DIM j as integer

 DIM shoptmp(19) as integer

 n = FirstChild(node)
 DO WHILE n
  IF NodeName(n) = "shop" THEN
   i = GetInteger(n)
   SELECT CASE i
    CASE 0 TO gen(genMaxShop)
     loadrecord shoptmp(), game & ".sho", 20, i
     ch = GetChildByName(n, "slots")
     
     n2 = FirstChild(ch)
     DO WHILE n2
      IF NodeName(n2) = "slot" THEN
       j = GetInteger(n2)
       SELECT CASE j
        CASE 0 TO shoptmp(16)
         gam.stock(i, j) = GetChildNodeInt(n2, "stock", -1)
        CASE ELSE
         rsav_warn "invalid shop " & i & " stuff slot " & j
       END SELECT
      ELSE
       rsav_warn_wrong "slot", n2
      END IF
      n2 = NextSibling(n2)
     LOOP
     
    CASE ELSE
     rsav_warn "invalid shop id " & i
   END SELECT
  ELSE
   rsav_warn_wrong "shop", n
  END IF
  n = NextSibling(n)
 LOOP
 
END SUB

SUB gamestate_vehicle_from_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = GetChildByName(parent, "vehicle")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 
 WITH vstate

  IF GetChildNodeExists(node, "id") THEN
   ch = GetChildByName(node, "state")
   .active    = GetChildNodeInt(ch, "active")
   .npc       = GetChildNodeInt(ch, "npc")
   .old_speed = GetChildNodeInt(ch, "old_speed")
   IF GetChildNodeExists(ch, "mounting")        THEN .mounting = YES
   IF GetChildNodeExists(ch, "rising")          THEN .rising = YES
   IF GetChildNodeExists(ch, "falling")         THEN .falling = YES
   IF GetChildNodeExists(ch, "init_dismount")   THEN .init_dismount = YES
   IF GetChildNodeExists(ch, "trigger_cleanup") THEN .trigger_cleanup = YES
   IF GetChildNodeExists(ch, "ahead")           THEN .ahead = YES

   .id = GetChildNodeInt(node, "id")
   IF .id >= 0 THEN
    LoadVehicle game & ".veh", .dat, .id
   END IF
  END IF
  
 END WITH
END SUB

'-----------------------------------------------------------------------

SUB gamestate_to_reload(byval node as Reload.NodePtr)
 'increment this to produce a warning message when
 'loading a new rsav file in an old game player
 SetChildNode(node, "ver", CURRENT_RSAV_VERSION)

 DIM ch as NodePtr
 ch = SetChildNode(node, "game_client", "OHRRPGCE")
 SetChildNode(ch, "branch_name", version_branch)
 'version_revision is 0 if verprint could not determine it
 IF version_revision <> 0 THEN SetChildNode(ch, "revision", version_revision)
 
 gamestate_state_to_reload node
 gamestate_script_to_reload node
 gamestate_maps_to_reload node
 gamestate_tags_to_reload node
 gamestate_onetime_to_reload node
 gamestate_party_to_reload node
 gamestate_inventory_to_reload node
 gamestate_shops_to_reload node
 gamestate_vehicle_to_reload node
END SUB

SUB gamestate_state_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "state")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 
 SetChildNode(node, "current_map", gam.map.id)

 DIM map_offset as XYPair
 map_offset = load_map_pos_save_offset(gam.map.id)

 ch = SetChildNode(node, "caterpillar")
 FOR i as integer = 0 TO 3
  n = AppendChildNode(ch, "hero", i)
  SetChildNode(n, "x", catx(i * 5) - map_offset.x * 20)
  SetChildNode(n, "y", caty(i * 5) - map_offset.y * 20)
  SetChildNode(n, "d", catd(i * 5))
 NEXT i

 SetChildNode(node, "random_battle_countdown", gam.random_battle_countdown)
 
 ch = SetChildNode(node, "camera")
 SetChildNode(ch, "x", mapx)
 SetChildNode(ch, "y", mapy)
 SetChildNode(ch, "mode", gen(genCamera))
 FOR i as integer = 0 TO 3
  SetChildNode(ch, "arg" & i+1, gen(genCamArg1 + i))
 NEXT i
 
 SetChildNode(node, "gold", gold)

 ch = SetChildNode(node, "playtime")
 SetChildNode(ch, "days", gen(genDays))
 SetChildNode(ch, "hours", gen(genHours))
 SetChildNode(ch, "minutes", gen(genMinutes))
 SetChildNode(ch, "seconds", gen(genSeconds))

 ch = SetChildNode(node, "textbox")
 SetChildNode(ch, "backdrop", gen(genTextboxBackdrop))
 
 ch = SetChildNode(node, "status_char")
 SetChildNode(ch, "poison", gen(genPoison))
 SetChildNode(ch, "stun", gen(genStun))
 SetChildNode(ch, "mute", gen(genMute))

 SetChildNode(node, "damage_cap", gen(genDamageCap))
 SetChildNode(node, "level_cap", gen(genLevelCap))

 ch = SetChildNode(node, "stats")
 FOR i as integer = 0 TO 11
  n = AppendChildNode(ch, "stat", i)
  SetChildNode(n, "cap", gen(genStatCap + i))
 NEXT i

END SUB

SUB gamestate_script_to_reload(byval parent as Reload.NodePtr)
 'FIXME: currently only stores a tiny bit of script state, but could store
 'a lot more in the future

 DIM node as NodePtr
 node = SetChildNode(parent, "script")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers

 gamestate_globals_to_reload node

 script_trigger_to_reload(node, "gameover_script", gen(genGameoverScript))
 script_trigger_to_reload(node, "loadgame_script", gen(genLoadgameScript))
 
 ch = SetChildNode(node, "suspend")
 IF xreadbit(gen(), 0, genSuspendBits) THEN SetChildNode(ch, "npcs")
 IF xreadbit(gen(), 1, genSuspendBits) THEN SetChildNode(ch, "player")
 IF xreadbit(gen(), 2, genSuspendBits) THEN SetChildNode(ch, "obstruction")
 IF xreadbit(gen(), 3, genSuspendBits) THEN SetChildNode(ch, "herowalls")
 IF xreadbit(gen(), 4, genSuspendBits) THEN SetChildNode(ch, "npcwalls")
 IF xreadbit(gen(), 5, genSuspendBits) THEN SetChildNode(ch, "caterpillar")
 IF xreadbit(gen(), 6, genSuspendBits) THEN SetChildNode(ch, "randomenemies")
 IF xreadbit(gen(), 7, genSuspendBits) THEN SetChildNode(ch, "boxadvance")
 IF xreadbit(gen(), 8, genSuspendBits) THEN SetChildNode(ch, "overlay")
 IF xreadbit(gen(), 9, genSuspendBits) THEN SetChildNode(ch, "ambientmusic")
 
 SetChildNode(node, "backdrop", gen(genScrBackdrop))
END SUB

SUB script_trigger_to_reload(byval parent as Reload.NodePtr, node_name as STRING, byval script_id as integer)
 DIM node as NodePtr
 node = SetChildNode(parent, node_name)
 'IF script_id <= 16383 THEN
  '--old style
  SetChildNode(node, "id", script_id)
 'ELSE
 ' '--new style
 ' 'FIXME: this isn't saved yet because we can't load it yet
 ' SetChildNode(node, "name", scriptname(script_id))
 'END IF
END SUB

SUB gamestate_globals_to_reload(byval parent as Reload.NodePtr, byval first as integer=0, byval last as integer=4095)

 DIM node as NodePtr
 node = SetChildNode(parent, "globals")
 DIM n as NodePtr 'used for numbered containers

 FOR i as integer = first TO last
  IF global(i) <> 0 THEN
   SetKeyValueNode(node, "global", i, global(i))
  END IF
 NEXT i
END SUB

SUB gamestate_maps_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "maps")
 DIM n as NodePtr 'used for numbered containers
 
 'FIXME: currently only supports saving the current map
 n = AppendChildNode(node, "map", gam.map.id)
 gamestate_npcs_to_reload n, gam.map.id
 
END SUB

SUB gamestate_npcs_to_reload(byval parent as Reload.NodePtr, byval map as integer)
 DIM node as NodePtr
 node = SetChildNode(parent, "npcs")

 DIM map_offset as XYPair
 map_offset = load_map_pos_save_offset(map)

 DIM n as NodePtr
 FOR i as integer = 0 TO 299
  IF npc(i).id <> 0 ANDALSO NO THEN 'currently disabled for all NPCs
   n = AppendChildNode(node, "npc", i)
   save_npc_loc n, i, npc(i), map_offset
  END IF
 NEXT i
END SUB

SUB gamestate_tags_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "tags")
 
 DIM count as integer = 1000
 SetChildNode(node, "count", count)
 
 DIM buf(INT(count / 16)) as integer
 FOR i as integer = 0 TO count - 1
  setbit buf(), 0, i, readbit(tag(), 0, i)
 NEXT i
 
 DIM ch as NodePtr
 ch = SetChildNode(node, "data")
 SaveBitsetArray(ch, buf(), UBOUND(buf))
END SUB

SUB gamestate_onetime_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "onetime")
 
 DIM count as integer = 1032
 SetChildNode(node, "count", count)
 
 DIM buf(INT(count / 16)) as integer
 FOR i as integer = 0 TO count - 1
  setbit buf(), 0, i, readbit(tag(), 0, 1000 + i)
 NEXT i
 
 DIM ch as NodePtr
 ch = SetChildNode(node, "data")
 SaveBitsetArray(ch, buf(), UBOUND(buf))
END SUB

SUB gamestate_party_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "party")
 DIM slot as NodePtr
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 
 FOR i as integer = 0 TO 40
  slot = AppendChildNode(node, "slot", i)
  
  IF hero(i) > 0 THEN SetChildNode(slot, "id", hero(i) - 1)
  SetChildNode(slot, "name", names(i))
  
  IF xreadbit(hmask(), i) THEN
   SetChildNode(slot, "locked")
  END IF
  
  ch = SetChildNode(slot, "stats")
  FOR j as integer = 0 TO 11
   WITH gam.hero(i).stat
    IF .cur.sta(j) <> 0 OR .max.sta(j) <> 0 THEN
     n = AppendChildNode(ch, "stat", j)
     SetChildNode(n, "cur", .cur.sta(j))
     SetChildNode(n, "max", .max.sta(j))
    END IF
   END WITH
  NEXT j
  
  SetChildNode(slot, "lev", gam.hero(i).lev)
  SetChildNode(slot, "lev_gain", gam.hero(i).lev_gain)
  SetChildNode(slot, "exp", gam.hero(i).exp_cur)
  SetChildNode(slot, "exp_next", gam.hero(i).exp_next)
  SetChildNode(slot, "def_wep", gam.hero(i).def_wep)
  
  ch = SetChildNode(slot, "wep")
  SetChildNode(ch, "pic", gam.hero(i).wep_pic)
  SetChildNode(ch, "pal", gam.hero(i).wep_pal)
  
  ch = SetChildNode(slot, "in_battle")
  SetChildNode(ch, "pic", gam.hero(i).battle_pic)
  SetChildNode(ch, "pal", gam.hero(i).battle_pal)

  ch = SetChildNode(slot, "walkabout")
  SetChildNode(ch, "pic", gam.hero(i).pic)
  SetChildNode(ch, "pal", gam.hero(i).pal)
  
  ch = SetChildNode(slot, "battle_menus")
  FOR j as integer = 0 TO 5
   n = AppendChildNode(ch, "menu", j)
   SELECT CASE bmenu(i, j)
    CASE IS > 0:
     '--attack from weapon
     SetChildNode(n, "attack", bmenu(i, j) - 1)
    CASE -10:
     '--items menu
     SetChildNode(n, "items")
    CASE -4 TO -1:
     '--spell list
     SetChildNode(n, "spells", ABS(bmenu(i, j)) - 1)
   END SELECT
  NEXT j
  
  ch = SetChildNode(slot, "spell_lists")
  FOR j as integer = 0 TO 3
   n = AppendChildNode(ch, "list", j)
   gamestate_spelllist_to_reload(i, j, n)
  NEXT j
  
  ch = SetChildNode(slot, "level_mp")
  FOR j as integer = 0 TO 7
   IF lmp(i, j) <> 0 THEN
    SetKeyValueNode(ch, "lev", j, lmp(i, j), "val")
   END IF
  NEXT j

  ch = SetChildNode(slot, "equipment")
  FOR j as integer = 0 TO 4
   IF eqstuf(i, j) > 0 THEN
    SetKeyValueNode(ch, "equip", j, eqstuf(i, j) - 1, "item")
   END IF
  NEXT j

  IF hero(i) THEN
   'Unlike all the other hero commands, hero elemental commands aren't allowed
   'to read/write empty hero slots, so don't need to save those

   ch = SetChildNode(slot, "elements")
   FOR j as integer = 0 TO gen(genNumElements) - 1
    n = AppendChildNode(ch, "element", j)
    SetChildNode(n, "damage", cast(double, gam.hero(i).elementals(j)))
   NEXT j

   IF gam.hero(i).rename_on_status THEN SetChildNode(slot, "rename_on_status")
  END IF
  
 NEXT i
END SUB

SUB gamestate_spelllist_to_reload(byval hero_slot as integer, byval spell_list as integer, byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "spells", spell_list)
 DIM n as NodePtr 'used for numbered containers

 DIM atk_id as integer
 FOR i as integer = 0 TO 23
  atk_id = spell(hero_slot, spell_list, i) - 1
  IF atk_id >= 0 THEN
   n = AppendChildNode(node, "spell", i)
   SetChildNode(n, "attack", atk_id)
  END IF
 NEXT i
 
END SUB

SUB gamestate_inventory_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "inventory")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 
 SetChildNode(node, "size", gen(genMaxInventory))

 ch = SetChildNode(node, "slots")
 DIM last as integer
 last = small(inventoryMax, UBOUND(inventory))
 FOR i as integer = 0 TO last
  WITH inventory(i)
   IF .used THEN
    n = AppendChildNode(ch, "slot", i)
    SetChildNode(n, "item", .id)
    SetChildNode(n, "num", .num)
   END IF
  END WITH
 NEXT i
END SUB

SUB gamestate_shops_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "shops")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 DIM n2 as NodePtr 'also used for numbered containers

 DIM shoptmp(19) as integer
 
 FOR i as integer = 0 TO gen(genMaxShop)
  n = AppendChildNode(node, "shop", i)
  loadrecord shoptmp(), game & ".sho", 20, i
  ch = SetChildNode(n, "slots")
  FOR j as integer = 0 TO shoptmp(16)
   IF gam.stock(i, j) >= 0 THEN
    n2 = AppendChildNode(ch, "slot", j)
    SetChildNode(n2, "stock", gam.stock(i, j))
   END IF
  NEXT j
 NEXT i
 
END SUB

SUB gamestate_vehicle_to_reload(byval parent as Reload.NodePtr)
 DIM node as NodePtr
 node = SetChildNode(parent, "vehicle")
 DIM ch as NodePtr 'used for sub-containers
 DIM n as NodePtr 'used for numbered containers
 
 WITH vstate
  IF .id >= 0 THEN
   SetChildNode(node, "id", .id)
 
   ch = SetChildNode(node, "state")
   SetChildNode(ch, "active", .active)
   SetChildNode(ch, "npc", .npc)
   SetChildNode(ch, "old_speed", .old_speed)
   IF .mounting        THEN SetChildNode(ch, "mounting")
   IF .rising          THEN SetChildNode(ch, "rising")
   IF .falling         THEN SetChildNode(ch, "falling")
   IF .init_dismount   THEN SetChildNode(ch, "init_dismount")
   IF .trigger_cleanup THEN SetChildNode(ch, "trigger_cleanup")
   IF .ahead           THEN SetChildNode(ch, "ahead")
  END IF
 END WITH
END SUB

'-----------------------------------------------------------------------

SUB saveglobalvars (byval slot as integer, byval first as integer, byval last as integer)
 current_save_slot = slot
 
 DIM filename as STRING
 filename = savedir & SLASH & slot & ".rsav"

 DIM doc as DocPtr
 DIM rsav_node as NodePtr
 DIM script_node as NodePtr
 DIM globals_node as NodePtr

 IF NOT isfile(filename) THEN
  debuginfo "Save file missing: " & filename
  debuginfo "generating a globals-only file"
  doc = CreateDocument()
  rsav_node = CreateNode(doc, "rsav")
  SetRootNode(doc, rsav_node)
  script_node = SetChildNode(rsav_node, "script")
  globals_node = SetChildNode(script_node, "globals")
 ELSE
  '--save already exists
  doc = LoadDocument(filename)
 END IF
  
 '--get the old globals node
 rsav_node = DocumentRoot(doc)
 script_node = GetChildByName(rsav_node, "script")
 globals_node = GetChildByName(script_node, "globals")
 
 DIM n as NodePtr
 DIM i as integer
 
 '--delete any old global nodes in the range
 n = FirstChild(globals_node, "global")
 DO WHILE n
  i = GetInteger(n)
  SELECT CASE i
   CASE first TO last
    FreeNode(n)
  END SELECT
  n = NextSibling(n, "global")
 LOOP

 '--add nodes for the globals in the range
 gamestate_globals_to_reload script_node, first, last

 '--re-save with the changed globals
 SerializeBin filename, doc
 
 FreeDocument doc
 current_save_slot = -1
END SUB

SUB new_loadglobalvars (byval slot as integer, byval first as integer, byval last as integer)
 current_save_slot = slot
 
 DIM filename as STRING
 filename = savedir & SLASH & slot & ".rsav"

 IF NOT isfile(filename) THEN
  debug "Save file missing: " & filename
  current_save_slot = -1
  EXIT SUB
 END IF

 DIM doc as DocPtr
 doc = LoadDocument(filename)
 
 DIM node as NodePtr
 
 '--get the script node
 node = DocumentRoot(doc)
 node = GetChildByName(node, "script")

 '--wipe out the range of globals first
 FOR i as integer = first TO last
  global(i) = 0
 NEXT i

 '--load the globals in the range
 gamestate_globals_from_reload node, first, last
 
 FreeDocument doc
 current_save_slot = -1
END SUB

'-----------------------------------------------------------------------

SUB erase_save_slot (byval slot as integer)
 DIM filename as STRING
 filename = savedir & SLASH & slot & ".rsav"
 safekill filename
END SUB

FUNCTION new_save_slot_used (byval slot as integer) as integer
 DIM result as integer = NO

 DIM filename as STRING
 filename = savedir & SLASH & slot & ".rsav"
 
 IF isfile(filename) THEN
  DIM doc as DocPtr
  doc = LoadDocument(filename)
  DIM node as NodePtr
  node = DocumentRoot(doc)
  IF GetChildNodeInt(node, "ver", -1) >= 0 THEN
   result = YES
  END IF
  FreeDocument doc
 END IF
 
 RETURN result
END FUNCTION

FUNCTION new_count_used_save_slots() as integer
 DIM count as integer = 0
 
 FOR slot as integer = 0 TO 32
  IF new_save_slot_used(slot) THEN count += 1
 NEXT slot
 
 RETURN count
END FUNCTION

'-----------------------------------------------------------------------

SUB new_get_save_slot_preview(byval slot as integer, pv as SaveSlotPreview)
 current_save_slot = slot

 pv.valid = NO

 DIM filename as STRING
 filename = savedir & SLASH & slot & ".rsav"

 IF NOT isfile(filename) THEN
  current_save_slot = -1
  EXIT SUB
 END IF

 DIM doc as DocPtr
 doc = LoadDocument(filename)
 
 DIM parent as NodePtr
 parent = DocumentRoot(doc)

 '--if there is no version data, don't continue
 ' (this could happen if export globals was used into an empty slot)
 IF GetChildNodeInt(parent, "ver", -1) < 0 THEN
  FreeDocument doc
  current_save_slot = -1
  EXIT SUB
 END IF

 '--Loaded data okay! populate the SaveSlotPreview object
 pv.valid = YES

 DIM ch as NodePtr
 
 ch = NodeByPath(parent, "/state/current_map")
 pv.cur_map = GetInteger(ch) 

 DIM h as NodePtr
 DIM stat as NodePtr
 DIM picpal as NodePtr
 DIM foundleader as integer = NO
 FOR i as integer = 0 TO 3
  pv.hero_id(i) = 0
  h = NodeByPath(parent, "/party/slot[" & i & "]")
  IF h THEN
   IF GetChildNodeExists(h, "id") THEN
    pv.hero_id(i) = GetChildNodeInt(h, "id") + 1
    IF foundleader = NO THEN
     pv.leader_name = GetChildNodeStr(h, "name")
     pv.leader_lev = GetChildNodeInt(h, "lev")
     foundleader= YES
    END IF
    WITH pv.hero(i)
     .lev = GetChildNodeInt(h, "lev")
     FOR j as integer = 0 TO 11
      stat = NodeByPath(h, "/stats/stat[" & j & "]")
      IF stat THEN
       .stat.cur.sta(j) = GetChildNodeInt(stat, "cur")
       .stat.max.sta(j) = GetChildNodeInt(stat, "max")
      END IF
     NEXT j
     .def_wep = GetChildNodeInt(h, "def_wep")
     picpal = GetChildByName(h, "in_battle")
     .battle_pic = GetChildNodeInt(picpal, "pic")
     .battle_pal = GetChildNodeInt(picpal, "pal")
     picpal = GetChildByName(h, "walkabout")
     .pic = GetChildNodeInt(picpal, "pic")
     .pal = GetChildNodeInt(picpal, "pal")
    END WITH
   END IF
  END IF
 NEXT i
  
 ch = NodeByPath(parent, "/state/playtime")
 pv.playtime = playtime(GetChildNodeInt(ch, "days"), GetChildNodeInt(ch, "hours"), GetChildNodeInt(ch, "minutes"))
 
 FreeDocument doc
 current_save_slot = -1
END SUB

'-----------------------------------------------------------------------
'=======================================================================
'-----------------------------------------------------------------------

SUB old_loadgame (byval slot as integer)
DIM gmaptmp(dimbinsize(binMAP)) as integer

DIM as integer i, j, o, z

'--return gen to defaults
xbload game + ".gen", gen(), "General data is missing from " + sourcerpg

DIM sg as STRING = old_savefile
setpicstuf buffer(), 30000, -1
loadset sg, slot * 2, 0

DIM savver as integer = buffer(0)
IF savver < 2 OR savver > 3 THEN EXIT SUB
gam.map.id = buffer(1)
loadrecord gmaptmp(), game + ".map", getbinsize(binMAP) \ 2, gam.map.id
catx(0) = buffer(2) + gmaptmp(20) * 20
caty(0) = buffer(3) + gmaptmp(21) * 20
catd(0) = buffer(4)
gam.random_battle_countdown = buffer(5)
'leader = buffer(6)
mapx = buffer(7)
mapy = buffer(8)

DIM gold_str as STRING = ""
FOR i = 0 TO 24
 IF buffer(i + 9) < 0 OR buffer(i + 9) > 255 THEN buffer(i + 9) = 0
 IF buffer(i + 9) > 0 THEN gold_str &= CHR(buffer(i + 9))
NEXT i
gold = str2int(gold_str)

z = 34
show_load_index z, "gen"
FOR i = 0 TO 500
 SELECT CASE i
  'Only certain gen() values should be read from the saved game.
  'See http://rpg.HamsterRepublic.com/ohrrpgce/GEN
  CASE 42, 57 'genGameoverScript and genLoadgameScript
   IF readbit(gen(), genBits2, 2) = 0 THEN
    gen(i) = buffer(z)
   END IF
  CASE 44 TO 54, 58, 60 TO 76, 85
   gen(i) = buffer(z)
 END SELECT
 z = z + 1
NEXT i

show_load_index z, "npcl"
DeserNPCL npc(),z,buffer(),300,gmaptmp(20),gmaptmp(21)
show_load_index z, "unused"
z=z+1 'fix an old bug

show_load_index z, "tags"
FOR i = 0 TO 126
 tag(i) = buffer(z): z = z + 1
NEXT i
show_load_index z, "heroes"
FOR i = 0 TO 40
 hero(i) = buffer(z): z = z + 1
NEXT i
show_load_index z, "unused a"
FOR i = 0 TO 500
 '--used to be the useless a() buffer
 z = z + 1
NEXT i
show_load_index z, "stats"
FOR i = 0 TO 40
 FOR j = 0 TO 11
  gam.hero(i).stat.cur.sta(j) = buffer(z): z = z + 1
 NEXT j
 gam.hero(i).lev = buffer(z): z = z + 1
 gam.hero(i).wep_pic = buffer(z): z = z + 1
 FOR j = 0 TO 11
  gam.hero(i).stat.max.sta(j) = buffer(z): z = z + 1
 NEXT j
 gam.hero(i).lev_gain = buffer(z): z = z + 1
 gam.hero(i).wep_pal = buffer(z): z = z + 1
NEXT i
show_load_index z, "bmenu"
FOR i = 0 TO 40
 FOR o = 0 TO 5
  bmenu(i, o) = buffer(z): z = z + 1
 NEXT o
NEXT i
show_load_index z, "spell"
FOR i = 0 TO 40
 FOR o = 0 TO 3
  FOR j = 0 TO 23
   spell(i, o, j) = buffer(z): z = z + 1
  NEXT j
  z = z + 1'--skip extra data
 NEXT o
NEXT i
show_load_index z, "lmp"
FOR i = 0 TO 40
 FOR o = 0 TO 7
  lmp(i, o) = buffer(z): z = z + 1
 NEXT o
NEXT i
show_load_index z, "exlev"
DIM exp_str as STRING
FOR i = 0 TO 40
 FOR o = 0 TO 1
  exp_str = ""
  FOR j = 0 TO 25
   IF buffer(z) < 0 OR buffer(z) > 255 THEN buffer(z) = 0
   IF buffer(z) > 0 THEN exp_str &= CHR(buffer(z))
   z = z + 1
  NEXT j
  IF o = 0 THEN gam.hero(i).exp_cur = str2int(exp_str)
  IF o = 1 THEN gam.hero(i).exp_next = str2int(exp_str)
 NEXT o
NEXT i
show_load_index z, "names"
FOR i = 0 TO 40
 names(i) = ""
 FOR j = 0 TO 16
  IF buffer(z) < 0 OR buffer(z) > 255 THEN buffer(z) = 0
  IF buffer(z) > 0 THEN names(i) &= CHR(buffer(z))
  z = z + 1
 NEXT j
NEXT i

show_load_index z, "inv_mode"
DIM inv_mode as integer
inv_mode = buffer(z)
show_load_index z, "inv 8bit"
IF inv_mode = 0 THEN ' Read 8-bit inventory data from old SAV files
 DeserInventory8Bit inventory(), z, buffer()
ELSE
 'Skip this section
 z = 14595
END IF

show_load_index z, "eqstuff"
FOR i = 0 TO 40
 FOR o = 0 TO 4
  eqstuf(i, o) = buffer(z): z = z + 1
 NEXT o
NEXT i

show_load_index z, "inv 16bit"
IF inv_mode = 1 THEN ' Read 16-bit inventory data from newer SAV files
 LoadInventory16Bit inventory(), z, buffer(), 0, 99
END IF
show_load_index z, "after inv 16bit"

'RECORD 2

setpicstuf buffer(), 30000, -1
loadset sg, slot * 2 + 1, 0

z = 0

show_load_index z, "stock", 1
FOR i = 0 TO 99
 FOR o = 0 TO 49
  gam.stock(i, o) = buffer(z): z = z + 1
 NEXT o
NEXT i
show_load_index z, "hmask", 1
FOR i = 0 TO 3
 hmask(i) = buffer(z): z = z + 1
NEXT i
show_load_index z, "cathero", 1
FOR i = 1 TO 3
 catx(i * 5) = buffer(z) + gmaptmp(20) * 20: z = z + 1
 caty(i * 5) = buffer(z) + gmaptmp(21) * 20: z = z + 1
 catd(i * 5) = buffer(z): z = z + 1
NEXT i
show_load_index z, "globals low", 1
FOR i = 0 TO 1024
 global(i) = (buffer(z) AND &hFFFF): z = z + 1
NEXT i
show_load_index z, "vstate", 1
WITH vstate
 .active = buffer(z+0) <> 0
 .npc    = buffer(z+5)
 .id     = -1
 ' We set .id by looking at .npc's definition. But we can't do that here, npc() isn't loaded until preparemap
 .mounting        = xreadbit(buffer(), 0, z+6)
 .rising          = xreadbit(buffer(), 1, z+6)
 .falling         = xreadbit(buffer(), 2, z+6)
 .init_dismount   = xreadbit(buffer(), 3, z+6)
 .trigger_cleanup = xreadbit(buffer(), 4, z+6)
 .ahead           = xreadbit(buffer(), 5, z+6)
 .old_speed = buffer(z+7)
 WITH .dat
  .speed = buffer(z+8)
  .pass_walls = xreadbit(buffer(), 0, z+9)
  .pass_npcs  = xreadbit(buffer(), 1, z+9)
  .enable_npc_activation = xreadbit(buffer(), 2, z+9)
  .enable_door_use       = xreadbit(buffer(), 3, z+9)
  .do_not_hide_leader    = xreadbit(buffer(), 4, z+9)
  .do_not_hide_party     = xreadbit(buffer(), 5, z+9)
  .dismount_ahead        = xreadbit(buffer(), 6, z+9)
  .pass_walls_while_dismounting = xreadbit(buffer(), 7, z+9)
  .disable_flying_shadow        = xreadbit(buffer(), 8, z+9)
  .random_battles = buffer(z+11)
  .use_button     = buffer(z+12)
  .menu_button    = buffer(z+13)
  .riding_tag     = buffer(z+14)
  .on_mount       = buffer(z+15)
  .on_dismount    = buffer(z+16)
  .override_walls = buffer(z+17)
  .blocked_by     = buffer(z+18)
  .mount_from     = buffer(z+19)
  .dismount_to    = buffer(z+20)
  .elevation      = buffer(z+21)
 END WITH
END WITH
z += 22
'--picture and palette
show_load_index z, "picpal magic", 1
DIM picpalmagicnum as integer = buffer(z): z = z + 1
show_load_index z, "picpalwep", 1
FOR i = 0 TO 40
 IF picpalmagicnum = 4444 THEN
  gam.hero(i).battle_pic = buffer(z)
  gam.hero(i).battle_pal = buffer(z+1)
  gam.hero(i).def_wep = buffer(z+2)
  gam.hero(i).pic = buffer(z+3)
  gam.hero(i).pal = buffer(z+4)
 END IF
 z = z + 6
NEXT i
'native hero bitsets
show_load_index z, "hbit magic", 1
DIM nativebitmagicnum as integer = buffer(z): z = z + 1
show_load_index z, "hbits", 1
'Just totally ignore all the hero bits, as none of them are/were modifiable anyway;
'nativehbits() was removed
z += 205
'top global variable bits
show_load_index z, "global high", 1
FOR i = 0 TO 1024
 global(i) or= buffer(z) shl 16: z = z + 1
NEXT i
show_load_index z, "global ext", 1
FOR i = 1025 TO 4095
 global(i) = buffer(z) and &hFFFF: z = z + 1
 global(i) or= buffer(z) shl 16: z = z + 1
NEXT i
show_load_index z, "inv 16bit ext", 1
IF inv_mode = 1 THEN ' Read 16-bit inventory data from newer SAV files
 IF inventoryMax <> 599 THEN debug "Warning: inventoryMax=" & inventoryMax & ", does not fit in old SAV format"
 LoadInventory16Bit inventory(), z, buffer(), 100, 599
ELSE
 'skip this section for old saves
 z = 29680 - 15000
END IF
show_load_index z, "unused", 1
rebuild_inventory_captions inventory()

'---BLOODY BACKWARD COMPATABILITY---
'fix doors...
IF savver = 2 THEN gen(genVersion) = 3

DIM her as HeroDef

FOR i = 0 TO 40
 IF hero(i) > 0 THEN
  loadherodata @her, hero(i) - 1

  gam.hero(i).rename_on_status = readbit(her.bits(), 0, 25)

  '--fix appearance settings
  IF picpalmagicnum <> 4444 THEN
   gam.hero(i).battle_pic = her.sprite
   gam.hero(i).battle_pal = her.sprite_pal
   gam.hero(i).pic = her.walk_sprite
   gam.hero(i).pal = her.walk_sprite_pal
   gam.hero(i).def_wep = her.def_weapon + 1'default weapon
  END IF

  FOR j = 0 TO gen(genNumElements) - 1
   gam.hero(i).elementals(j) = her.elementals(j)
  NEXT
 END IF
NEXT i

'See http://rpg.hamsterrepublic.com/ohrrpgce/SAV for docs
END SUB

SUB old_loadglobalvars (byval slot as integer, byval first as integer, byval last as integer)
DIM i as integer
DIM buf((last - first + 1) * 2) as integer = ANY
IF isfile(old_savefile) THEN
 DIM fh as integer = FREEFILE
 OPEN old_savefile FOR BINARY as #fh

 IF first <= 1024 THEN
  'grab first-final
  DIM final as integer = small(1024, last)
  SEEK #fh, 60000 * slot + 2 * first + 40027  '20013 * 2 + 1
  loadrecord buf(), fh, final - first + 1, -1
  FOR i = 0 TO final - first
   global(first + i) = buf(i) and &hFFFF
  NEXT
  SEEK #fh, 60000 * slot + 2 * first + 43027  '21513 * 2 + 1
  loadrecord buf(), fh, final - first + 1, -1
  FOR i = 0 TO final - first
   global(first + i) or= buf(i) shl 16
  NEXT
 END IF
 IF last >= 1025 THEN
  'grab start-last
  DIM start as integer = large(1025, first)
  SEEK #fh, 60000 * slot + 4 * (start - 1025) + 45077  '22538 * 2 + 1
  loadrecord buf(), fh, (last - start + 1) * 2, -1
  FOR i = 0 TO last - start
   global(start + i) = buf(i * 2) and &hFFFF
   global(start + i) or= buf(i * 2 + 1) shl 16
  NEXT
 END IF

 CLOSE #fh
ELSE
 FOR i = first TO last
  global(i) = 0
 NEXT
END IF
END SUB

SUB show_load_index(byval z as integer, caption as string, byval slot as integer=0)
 'debug "SAV:" & LEFT(caption & STRING(20, " "), 20) & " int=" & z + slot * 15000
END SUB

SUB rebuild_inventory_captions (invent() as InventSlot)
 DIM i as integer
 FOR i = 0 TO inventoryMax
  update_inventory_caption i
 NEXT i
END SUB

SUB old_get_save_slot_preview(byval slot as integer, pv as SaveSlotPreview)

 setpicstuf buffer(), 30000, -1
 loadset old_savefile, slot * 2, 0
 
 IF buffer(0) <> 3 THEN
  '--currently only understands v3 binary sav format
  pv.valid = NO
  EXIT SUB
 END IF
 
 pv.valid = YES
 pv.cur_map = buffer(1)

 '-get stats
 DIM z as integer = 3305
 FOR i as integer = 0 TO 3
  FOR j as integer = 0 TO 11
   pv.hero(i).stat.cur.sta(j) = buffer(z): z += 1
  NEXT j
  pv.hero(i).lev = buffer(z): z += 1
  z += 1 'skip weapon pic because we could care less right now
  FOR j as integer = 0 TO 11
   pv.hero(i).stat.max.sta(j) = buffer(z): z += 1
  NEXT j
 NEXT i

 '--get play time
 z = 34 + 51
 pv.playtime = playtime(buffer(z), buffer(z + 1), buffer(z + 2))

 '--leader data
 DIM foundleader as integer = NO
 pv.leader_name = ""
 FOR o as integer = 0 TO 3
  '--load hero ID
  pv.hero_id(o) = buffer(2763 + o)
  '--leader name and level
  IF foundleader = NO AND pv.hero_id(o) > 0 THEN
   foundleader = YES
   FOR j as integer = 0 TO 15
    DIM k as integer = buffer(11259 + (o * 17) + j)
    IF k > 0 AND k < 255 THEN pv.leader_name &= CHR(k)
   NEXT j
   pv.leader_lev = pv.hero(o).lev
  END IF
 NEXT o

 '--load second record
 loadset old_savefile, slot * 2 + 1, 0

 z = 6060
 DIM use_saved_pics as integer = NO
 IF buffer(z) = 4444 THEN use_saved_pics = YES
 z += 1
 FOR i as integer = 0 TO 3
  IF use_saved_pics THEN
   pv.hero(i).battle_pic = buffer(z)
   pv.hero(i).battle_pal = buffer(z+1)
   pv.hero(i).def_wep = buffer(z+2)
   pv.hero(i).pic = buffer(z+3)
   pv.hero(i).pal = buffer(z+4)
   z += 6
  ELSE
   '--backcompat (for ancient SAV files)
   IF pv.hero_id(i) > 0 THEN
    DIM her as HeroDef
    loadherodata @her, pv.hero_id(i) - 1
    pv.hero(i).battle_pic = her.sprite
    pv.hero(i).battle_pal = her.sprite_pal
    pv.hero(i).pic = her.walk_sprite
    pv.hero(i).pal = her.walk_sprite_pal
    pv.hero(i).def_wep = her.def_weapon + 1
   END IF
  END IF
 NEXT i

END SUB

FUNCTION old_save_slot_used (byval slot as integer) as integer
 DIM as SHORT saveversion
 DIM savh as integer = FREEFILE
 OPEN old_savefile FOR BINARY as #savh
 GET #savh, 1 + 60000 * slot, saveversion
 CLOSE #savh
 RETURN (saveversion = 3)
END FUNCTION

SUB old_erase_save_slot (byval slot as integer)
 DIM as SHORT saveversion = 0
 IF fileisreadable(old_savefile) = NO THEN EXIT SUB
 DIM savh as integer = FREEFILE
 OPEN old_savefile FOR BINARY as #savh
 IF LOF(savh) > 60000 * slot THEN
  PUT #savh, 1 + 60000 * slot, saveversion
 END IF
 CLOSE #savh
END SUB

FUNCTION old_count_used_save_slots() as integer
 DIM i as integer
 DIM n as integer
 DIM savver as integer
 n = 0
 setpicstuf buffer(), 30000, -1
 FOR i = 0 TO 3
  loadset old_savefile, i * 2, 0
  savver = buffer(0)
  IF savver = 3 THEN n += 1
 NEXT i
 RETURN n
END FUNCTION
