'OHRRPGCE GAME
'(C) Copyright 1997-2015 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'
' This module contains code for:
' -creating and updating walkabout slices for heroes and NPCs
' -updating hero/NPC visibility
' -utility functions (not related to slices) for hero/NPC movement/collision/map-wrapping
' -vehicles
' Note that the hero/NPC movement code itself is in game.bas (eg update_npcs())

#include "config.bi"
#include "udts.bi"
#include "gglobals.bi"
#include "common.bi"
#include "loading.bi"
#include "allmodex.bi"
#include "game.bi"
#include "scripting.bi"
#include "scriptcommands.bi"
#include "moresubs.bi"
#include "walkabouts.bi"

'local subs and functions
' DECLARE FUNCTION should_hide_hero_caterpillar() as integer
' DECLARE FUNCTION should_show_normal_caterpillar() as integer


'==========================================================================================
'                          Creating/modifying walkabout slices
'==========================================================================================


FUNCTION create_walkabout_slices(byval parent as Slice Ptr) as Slice Ptr
 DIM sl as Slice Ptr
 sl = NewSliceOfType(slContainer, parent)
 WITH *sl
  .Width = 20
  .Height = 20
  .Protect = YES
 END WITH
 DIM sprsl as Slice Ptr
 sprsl = NewSliceOfType(slSprite, sl, SL_WALKABOUT_SPRITE_COMPONENT)
 WITH *sprsl
  'Anchor and align NPC sprite in the bottom center of the NPC container
  .AnchorHoriz = 1
  .AnchorVert = 2
  .AlignHoriz = 1
  .AlignVert = 2
  .Protect = YES
 END WITH
 RETURN sl
END FUNCTION

SUB create_walkabout_shadow (byval walkabout_cont as Slice Ptr)
 IF walkabout_cont = 0 THEN debug "create_walkabout_shadow: null walkabout container": EXIT SUB
 DIM sprsl as Slice Ptr
 sprsl = LookupSlice(SL_WALKABOUT_SPRITE_COMPONENT, walkabout_cont)
 IF sprsl = 0 THEN debug "create_walkabout_shadow: null walkabout sprite": EXIT SUB
 DIM shadow as Slice Ptr
 shadow = NewSliceOfType(slEllipse, ,SL_WALKABOUT_SHADOW_COMPONENT)
 WITH *shadow
  .Width = 12
  .Height = 6
  .AnchorHoriz = 1
  .AlignHoriz = 1
  .AnchorVert = 2
  .AlignVert = 2
  .Y = gmap(11) 'foot offset
  .Visible = NO
 END WITH
 ChangeEllipseSlice shadow, uilook(uiShadow), uilook(uiShadow)
 InsertSliceBefore(sprsl, shadow)
END SUB

SUB delete_walkabout_shadow (byval walkabout_cont as Slice Ptr)
 IF walkabout_cont = 0 THEN debug "delete_walkabout_shadow: null walkabout container": EXIT SUB
 DIM shadow as Slice Ptr
 shadow = LookupSlice(SL_WALKABOUT_SHADOW_COMPONENT, walkabout_cont)
 IF shadow = 0 THEN debug "delete_walkabout_shadow: no shadow to delete" : EXIT SUB
 DeleteSlice @shadow
END SUB

'Change picture and/or palette of a walkabout slice.
'
'Here is an exhaustive list of the conditions under which a walkabout sprite slice gets updated,
'(picture and/or palette is changed), wiping out any modifications by scripts.
'Note everything else such as extra data and child slices of the walkabout sprite and container
'slices always remain untouched, except for the container position, shadow slice, and walking animation.
'
'-When a specific NPC is enabled or disabled by tag changes
' (disabled NPCs have their container slices deleted, not just hidden)
'-When alternpc, changenpcid, etc, is used, affecting a specific NPC/NPC ID
'-When reset_npc_graphics gets called, which happens when loading map state (sometimes after
' a battle, changing maps, loadmapstate) or when live previewing (changes to NPC data)
'ALL hero sprite slices get reloaded (vishero is called) when:
'-calling reset/setheropicture/palette(outsidebattle) on a walkabout party hero
'-the hero party changes, such as when changing the order of heroes
'Unlike NPCs, hero container slices are hidden rather than disabled when a hero slot is empty.
'Hero container slices are never recreated when changing maps, etc.
'
SUB set_walkabout_sprite (byval cont as Slice Ptr, byval pic as integer=-1, byval pal as integer=-2)
 DIM sprsl as Slice Ptr
 IF cont = 0 THEN
  debug "null container slice in set_walkabout_sprite"
 ELSE
  sprsl = LookupSlice(SL_WALKABOUT_SPRITE_COMPONENT, cont)
  IF sprsl = 0 THEN
   debug "null sprite slice in set_walkabout_sprite"
  ELSE
   ChangeSpriteSlice sprsl, sprTypeWalkabout, pic, pal
  END IF
 END IF
END SUB

SUB set_walkabout_frame (byval cont as Slice Ptr, byval direction as DirNum, byval frame as integer)
 DIM sprsl as Slice Ptr
 IF cont = 0 THEN
  debug "null container slice in set_walkabout_frame"
 ELSE
  sprsl = LookupSlice(SL_WALKABOUT_SPRITE_COMPONENT, cont)
  IF sprsl = 0 THEN
   debug "null sprite slice in set_walkabout_frame"
  ELSE
   ChangeSpriteSlice sprsl, , , , direction * 2 + frame
  END IF
 END IF
END SUB

SUB set_walkabout_vis (byval cont as Slice Ptr, byval vis as integer)
 IF cont = 0 THEN
  debug "null container slice in set_walkabout_vis"
 ELSE
  cont->Visible = vis
 END IF
END SUB

SUB update_walkabout_pos (byval walkabout_cont as slice ptr, byval x as integer, byval y as integer, byval z as integer)
 IF walkabout_cont = 0 THEN
  'Exit silently on null slices. It is normal to call this on hero slices that don't exist when the party is non-full
  EXIT SUB
 END IF

 DIM where as XYPair
 '+ gmap(11)
 framewalkabout XY(x, y), where, mapsizetiles * 20, gmap(5)
 walkabout_cont->Pos = where + XY(mapx, mapy)

 DIM sprsl as Slice Ptr
 sprsl = LookupSlice(SL_WALKABOUT_SPRITE_COMPONENT, walkabout_cont)
 IF sprsl = 0 THEN
  debug "update_walkabout_pos: null sprite slice for walkabout slice " & walkabout_cont
 ELSE
  sprsl->Y = gmap(11) - z
 END IF
END SUB


'==========================================================================================
'                           Fixup slices after NPCType changes
'==========================================================================================


'Reset npc sprite slices to match npc definitions.
'Used only when reloading all npcs. See set_walkabout_sprite documentation.
'reset_npc_graphics is always called after visnpc (though it's not necessarily so),
'which enables or disables npcs and also creates the slices for any npcs that were enabled.
SUB reset_npc_graphics ()
 DIM npc_id as integer
 FOR i as integer = 0 TO UBOUND(npc)
  npc_id = npc(i).id - 1
  IF npc_id >= 0 THEN
   IF npc_id > UBOUND(npcs) THEN
    debug "reset_npc_graphics: ignore npc " & i & " because npc def " & npc_id & " is out of range (>" & UBOUND(npcs) & ")"
   ELSE
    'Update/load sprite
    set_walkabout_sprite npc(i).sl, npcs(npc_id).picture, npcs(npc_id).palette
    set_walkabout_vis npc(i).sl, YES
   END IF
  END IF
 NEXT i
END SUB

SUB change_npc_def_sprite (byval npc_id as integer, byval walkabout_sprite_id as integer)
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id - 1 = npc_id THEN
   'found a match!
   set_walkabout_sprite npc(i).sl, walkabout_sprite_id
  END IF
 NEXT i
END SUB

SUB change_npc_def_pal (byval npc_id as integer, byval palette_id as integer)
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id - 1 = npc_id THEN
   'found a match!
   set_walkabout_sprite npc(i).sl, , palette_id
  END IF
 NEXT i
END SUB


'==========================================================================================
'                         Updating slices to match Hero/NPC data
'==========================================================================================


PRIVATE FUNCTION should_hide_hero_caterpillar() as integer
 RETURN vstate.active = YES _
   ANDALSO vstate.mounting = NO _
   ANDALSO vstate.trigger_cleanup = NO _
   ANDALSO vstate.ahead = NO _
   ANDALSO vstate.dat.do_not_hide_leader = NO _
   ANDALSO vstate.dat.do_not_hide_party = NO
END FUNCTION

PRIVATE FUNCTION should_show_normal_caterpillar() as integer
 '"Enable Caterpillar Party"
 RETURN prefbit(1) ANDALSO (vstate.active = NO ORELSE vstate.dat.do_not_hide_leader = NO)
END FUNCTION

PRIVATE SUB update_walkabout_hero_slices()

 DIM should_hide as integer = should_hide_hero_caterpillar()
 FOR i as integer = 0 TO UBOUND(herow)
  set_walkabout_vis herow(i).sl, NOT should_hide
 NEXT i

 IF should_show_normal_caterpillar() THEN
  FOR i as integer = 0 TO UBOUND(herow)
   update_walkabout_pos herow(i).sl, herox(i), heroy(i), heroz(i)
  NEXT i

  DIM cat_slot as integer = 0
  FOR party_slot as integer = 0 TO 3
   IF gam.hero(party_slot).id >= 0 THEN
    set_walkabout_frame herow(cat_slot).sl, herodir(cat_slot), (herow(cat_slot).wtog \ 2)
    cat_slot += 1
   END IF
  NEXT party_slot
  FOR i as integer = cat_slot TO UBOUND(herow)
   set_walkabout_vis herow(i).sl, NO
  NEXT i

 ELSE
  '--non-caterpillar party, vehicle no-hide-leader (or backcompat pref)
  update_walkabout_pos herow(0).sl, herox(0), heroy(0), heroz(0)
  set_walkabout_frame herow(0).sl, herodir(0), (herow(0).wtog \ 2)
  FOR i as integer = 1 TO UBOUND(herow)
   set_walkabout_vis herow(i).sl, NO
  NEXT i
 END IF

 '--Move the heroes to the end of their walkabout layer sibling list.
 '--This forces tie-breaking of heroes and NPCs with equal Y coord so that the
 '--leader is on top, then 2nd hero, etc, then NPCs if they're on the same layer.
 FOR cat_rank as integer = 3 TO 0 STEP -1
  IF herow(cat_rank).sl <> 0 THEN
   SetSliceParent herow(cat_rank).sl, SliceGetParent(herow(cat_rank).sl)
  END IF
 NEXT cat_rank
END SUB

PRIVATE SUB update_walkabout_npc_slices()
 DIM shadow as Slice Ptr

 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id > 0 THEN '-- if visible
   IF vstate.active AND vstate.npc = i THEN
    '--This NPC is a currently active vehicle, so lets do some extra voodoo.
    IF npc(i).sl <> 0 THEN
     shadow = LookupSlice(SL_WALKABOUT_SHADOW_COMPONENT, npc(i).sl)
     IF shadow <> 0 THEN
      shadow->Visible = (npc(i).z > 0 ANDALSO vstate.dat.disable_flying_shadow = NO)
     END IF
    END IF
   END IF
   update_walkabout_pos npc(i).sl, npc(i).x, npc(i).y, npc(i).z
   IF npc(i).sl <> 0 THEN
    '--default NPC sort is by instance id
    npc(i).sl->Sorter = i
   END IF
  ELSEIF npc(i).id <= 0 THEN
   '--remove unused and hidden NPC slices
   IF npc(i).sl <> 0 THEN
    debug "Sloppy housekeeping: delete npc sl " & i & " [update_walkabout_npc_slices]"
    DeleteSlice @npc(i).sl
   END IF
  END IF
 NEXT i

 '--now apply sprite frame changes
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id > 0 THEN '-- if visible
   set_walkabout_frame npc(i).sl, npc(i).dir, npc(i).frame \ 2
  END IF
 NEXT i
END SUB

'Does not create or delete NPC/hero slices (vishero/visnpc), but only updates their graphical state.
SUB update_walkabout_slices()
 update_walkabout_hero_slices()
 update_walkabout_npc_slices()
END SUB

'Reload party walkabout graphics
SUB vishero ()
 DIM cater_slot as integer = 0
 FOR party_slot as integer = 0 TO 3
  IF gam.hero(party_slot).id >= 0 THEN
   set_walkabout_sprite herow(cater_slot).sl, gam.hero(party_slot).pic, gam.hero(party_slot).pal
   cater_slot += 1
  END IF
 NEXT
END SUB

SUB visnpc()
 'Hide/Unhide NPCs based on tag requirements. (No other function should do so)
 'This SUB will be called when a map is incompletely loaded (NPC instances before definitions
 'or vice versa), and that's hard to avoid, because a script could load them with two separate loadmapstate
 'calls. So we must tolerate invalid NPC IDs and anything else. So here we mark all NPCs as hidden which
 'would otherwise cause problems

 'To scripts, hiding an NPC is like deleting it, and unhiding an NPC is like creating it.
 'Therefore, zone exit triggers *do not* happen when hiding an NPC, and zone entry triggers *do*
 'happen when unhiding an NPC (rather than remembering the old zones)
 'However, we run the zone entry triggers elsewhere (update_npcs), otherwise tags toggled by the
 'triggers would immediately affect NPCs not yet processed (it's better if the order doesn't
 'matter), and worse, visnpc might be called several times per tick!

 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id = 0 THEN CONTINUE FOR

  DIM npc_id as integer = ABS(npc(i).id) - 1

  IF npc_id > UBOUND(npcs) THEN
   'Invalid ID number; hide. Probably a partially loaded map.
   npc(i).id = -npc_id - 1
   CONTINUE FOR
  END IF
 
  '--check tags
  IF istag(npcs(npc_id).tag1, 1) ANDALSO istag(npcs(npc_id).tag2, 1) ANDALSO istag(onetime(), npcs(npc_id).usetag, 0) = NO THEN
   npc(i).id = npc_id + 1
  ELSE
   npc(i).id = -npc_id - 1
  END IF
  
  IF npc(i).id > 0 THEN
   '--NPC exists and is visible
   IF npc(i).sl = 0 THEN
    npc(i).sl = create_walkabout_slices(npc_layer())
    DIM meta as NPCSliceContext ptr = NEW NPCSliceContext
    meta->npcindex = i
    npc(i).sl->Context = meta
    'debug "npc(" & i & ").sl=" & npc(i).sl & " [visnpc]"
    '--set sprite
    set_walkabout_sprite npc(i).sl, npcs(npc_id).picture, npcs(npc_id).palette
   END IF
  ELSE
   '--hidden
   IF npc(i).sl <> 0 THEN
    'debug "delete npc sl " & i & " [visnpc]"
    DeleteSlice @npc(i).sl
   END IF
   v_free npc(i).curzones
  END IF

 NEXT i
END SUB

FUNCTION NPCSliceContext.description() as string
 RETURN "NPC ID " & npc(npcindex).id & " ref " & -(1 + npcindex)
END FUNCTION

FUNCTION HeroSliceContext.description() as string
 DIM slot as integer = rank_to_party_slot(rank)
 IF slot = -1 THEN RETURN "Hero rank " & rank & " (doesn't exist)"  'FIXME: why do we create unused hero slices???
 RETURN "Hero rank " & rank & ": ID " & gam.hero(slot).id & " " & gam.hero(slot).name
END FUNCTION


'==========================================================================================
'                                 Walkabout slice layers
'==========================================================================================


FUNCTION hero_layer() as Slice Ptr
 DIM layer as Slice Ptr
 IF gmap(16) = 2 THEN ' heroes and NPCs together
  layer = SliceTable.Walkabout
 ELSE ' heroes and NPCs on separate layers
  layer = SliceTable.HeroLayer
 END IF
 IF layer = 0 THEN
  debug "Warning: null hero layer, gmap(16)=" & gmap(16)
 END IF
 RETURN layer
END FUNCTION

FUNCTION npc_layer() as Slice Ptr
 DIM layer as Slice Ptr
 IF gmap(16) = 2 THEN ' heroes and NPCs together
  layer = SliceTable.Walkabout
 ELSE ' heroes and NPCs on separate layers
  layer = SliceTable.NPCLayer
 END IF
 IF layer = 0 THEN
  debug "Warning: null npc layer, gmap(16)=" & gmap(16)
 END IF
 RETURN layer
END FUNCTION

SUB reparent_hero_slices()
 FOR i as integer = 0 TO UBOUND(herow)
  SetSliceParent herow(i).sl, hero_layer()
 NEXT i
END SUB

SUB orphan_hero_slices()
 FOR i as integer = 0 TO UBOUND(herow)
  OrphanSlice herow(i).sl
 NEXT i
END SUB

SUB reparent_npc_slices()
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).sl THEN
   SetSliceParent npc(i).sl, npc_layer()
  END IF
 NEXT i
END SUB

SUB orphan_npc_slices()
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).sl THEN
   OrphanSlice npc(i).sl
  END IF
 NEXT i
END SUB

SUB refresh_walkabout_layer_sort()
 orphan_hero_slices
 orphan_npc_slices
 IF gmap(16) = 2 THEN ' Heroes and NPCs Together
  DeleteSlice @SliceTable.HeroLayer
  DeleteSlice @SliceTable.NPCLayer
  SliceTable.Walkabout->AutoSort = slAutoSortY
 ELSE
  'Hero and NPC in separate layers
  SliceTable.Walkabout->AutoSort = slAutoSortNone
  IF SliceTable.HeroLayer = 0 THEN
   '--create the hero layer if it is needed
   SliceTable.HeroLayer = NewSliceOfType(slContainer, SliceTable.Walkabout, SL_HERO_LAYER)
   SliceTable.HeroLayer->Fill = YES
   SliceTable.HeroLayer->Protect = YES
   SliceTable.HeroLayer->AutoSort = slAutoSortY
  END IF
  IF SliceTable.NPCLayer = 0 THEN
   SliceTable.NPCLayer = NewSliceOfType(slContainer, SliceTable.Walkabout, SL_NPC_LAYER)
   SliceTable.NPCLayer->Fill = YES
   SliceTable.NPCLayer->Protect = YES
   SliceTable.NPCLayer->AutoSort = slAutoSortCustom
  END IF
  IF gmap(16) = 1 THEN
   SliceTable.HeroLayer->Sorter = 0
   SliceTable.NPCLayer->Sorter = 1
  ELSE
   SliceTable.NPCLayer->Sorter = 0
   SliceTable.HeroLayer->Sorter = 1
  END IF
  CustomSortChildSlices SliceTable.Walkabout, YES
 END IF
 reparent_hero_slices
 reparent_npc_slices
END SUB


'==========================================================================================
'                       Movement, collision & map-wrapping funcs
'==========================================================================================


FUNCTION movdivis (byval xygo as integer) as bool
 IF (xygo \ 20) * 20 = xygo AND xygo <> 0 THEN
  movdivis = YES
 ELSE
  movdivis = NO
 END IF
END FUNCTION

SUB aheadxy (byref x as integer, byref y as integer, byval direction as DirNum, byval distance as integer)
 '--alters the input X and Y, moving them "ahead" by distance in direction

 IF direction = dirUp    THEN y = y - distance
 IF direction = dirRight THEN x = x + distance
 IF direction = dirDown  THEN y = y + distance
 IF direction = dirLeft  THEN x = x - distance
END SUB

SUB aheadxy (byref p as XYPair, byval direction as DirNum, byval distance as integer)
 '--alters the input X and Y, moving them "ahead" by distance in direction

 IF direction = dirUp    THEN p.y = p.y - distance
 IF direction = dirRight THEN p.x = p.x + distance
 IF direction = dirDown  THEN p.y = p.y + distance
 IF direction = dirLeft  THEN p.x = p.x - distance
END SUB

SUB wrapxy (byref x as integer, byref y as integer, byval unitsize as integer = 1)
 '--wraps the given X and Y values within the bounds of the map.
 '--unitsize should be 1 if X/Y are in tiles, or 20 if X/Y are in pixels
 x = x MOD mapsizetiles.w * unitsize
 IF x < 0 THEN x += mapsizetiles.w * unitsize  'negative modulo is the devil's creation and never helped me once
 y = y MOD mapsizetiles.h * unitsize
 IF y < 0 THEN y += mapsizetiles.h * unitsize
END SUB

SUB wrapxy (byref p as XYPair, byval unitsize as integer = 1)
 '--wraps the given X and Y values within the bounds of the map.
 '--unitsize should be 1 if X/Y are in tiles, or 20 if X/Y are in pixels
 p.x = p.x MOD mapsizetiles.w * unitsize
 IF p.x < 0 THEN p.x += mapsizetiles.w * unitsize
 p.y = p.y MOD mapsizetiles.h * unitsize
 IF p.y < 0 THEN p.y += mapsizetiles.h * unitsize
END SUB

'alters X and Y ahead by distance in direction, wrapping if neccisary
'unitsize is 20 for pixels, 1 for tiles
SUB wrapaheadxy (byref x as integer, byref y as integer, byval direction as DirNum, byval distance as integer, byval unitsize as integer)
 aheadxy x, y, direction, distance
 
 IF gmap(5) = mapEdgeWrap THEN
  wrapxy x, y, unitsize
 END IF
END SUB

'alters X and Y ahead by distance in direction, wrapping if neccisary
'unitsize is 20 for pixels, 1 for tiles
SUB wrapaheadxy (byref p as XYPair, byval direction as DirNum, byval distance as integer, byval unitsize as integer)
 aheadxy p, direction, distance
 
 IF gmap(5) = mapEdgeWrap THEN
  wrapxy p, unitsize
 END IF
END SUB

SUB cropposition (byref x as integer, byref y as integer, byval unitsize as integer)
 IF gmap(5) = mapEdgeWrap THEN
  wrapxy x, y, unitsize
 ELSE
  x = bound(x, 0, (mapsizetiles.x - 1) * unitsize)
  y = bound(y, 0, (mapsizetiles.y - 1) * unitsize)
 END IF
END SUB

FUNCTION cropmovement (byref pos as XYPair, byref xygo as XYPair) as bool
 'crops movement at edge of map, or wraps
 'returns true if ran into wall at edge (and sets xgo OR ygo to 0)
 IF gmap(5) = mapEdgeWrap THEN
  '--wrap walking
  wrapxy pos, 20
  RETURN NO
 ELSE
  '--crop walking
  DIM old as XYPair = pos
  pos.x = bound(pos.x, 0, (mapsizetiles.x - 1) * 20)
  pos.y = bound(pos.y, 0, (mapsizetiles.y - 1) * 20)
  IF pos.x <> old.x THEN xygo.x = 0
  IF pos.y <> old.y THEN xygo.y = 0
  RETURN pos <> old
 END IF
END FUNCTION

' Checks the two facing edges (wall bits) between two adjacent tiles: the tile
' at tilex,tiley, and the tile one step in 'direction' from there.
' Returns true if there is a wall or vehicle obstruction.
' walls_over_edges: map edges are obstructions
' ignore_passmap: map edges are obstructions but walls are not (note: walls_over_edges is ignored)
FUNCTION check_wall_edges(tilex as integer, tiley as integer, direction as DirNum, isveh as bool = NO, walls_over_edges as bool = YES, ignore_passmap as bool = NO) as bool
 DIM wallbit as integer = 1 SHL direction
 DIM oppositebit as integer = 1 SHL ((direction + 2) AND 3)
 DIM defwalls as integer = IIF(walls_over_edges, 15, 0)
 DIM wallblock as integer

 'debug "check_wall_edges(" & tilex & "," & tiley & ", dir=" & direction & ", isveh=" & isveh & ", walls_over_edges=" & walls_over_edges & ", ignore_passmap=" & ignore_passmap & ")"

 IF gmap(5) = mapEdgeWrap THEN
  wrapxy tilex, tiley
 END IF
 IF ignore_passmap THEN    ' Check only for the map edge
  IF tilex < 0 OR tilex >= pass.wide OR tiley < 0 OR tiley >= pass.high THEN RETURN YES
 ELSE
  ' Ignore walls when exiting this tile?
  IF CheckZoneAtTile(zmap, zoneOneWayExit, tilex, tiley) = 0 THEN
   IF readblock(pass, tilex, tiley, defwalls) AND wallbit THEN RETURN YES
  END IF
 END IF

 wrapaheadxy tilex, tiley, direction, 1, 1
 wallblock = readblock(pass, tilex, tiley, defwalls)

 IF isveh ANDALSO vehpass(vstate.dat.blocked_by, wallblock, 0) THEN RETURN YES
 IF ignore_passmap THEN    ' Check only for the map edge
  RETURN tilex < 0 OR tilex >= pass.wide OR tiley < 0 OR tiley >= pass.high
 ELSE
  RETURN (wallblock AND oppositebit) = oppositebit
 END IF
END FUNCTION

' Check for an NPC/hero colliding with a wall.
' This is the old (and still used) crappy wall checking which breaks if not tile-aligned.
' Returns 1 (not YES) if blocked by terrain, otherwise 0
FUNCTION wrappass (x as integer, y as integer, byref xgo as integer, byref ygo as integer, isveh as bool, ignore_passmap as bool = NO) as integer
 wrappass = 0

 ' Only check for walls at the beginning of every 20px step. Why? Well, this is
 ' quite wrong, but we continue to do this for compatibility.
 IF movdivis(ygo) THEN
  IF ygo > 0 ANDALSO check_wall_edges(x, y, dirUp, isveh, , ignore_passmap) THEN ygo = 0: wrappass = 1
  IF ygo < 0 ANDALSO check_wall_edges(x, y, dirDown, isveh, , ignore_passmap) THEN ygo = 0: wrappass = 1
 END IF
 IF movdivis(xgo) THEN
  IF xgo > 0 ANDALSO check_wall_edges(x, y, dirLeft,  isveh, , ignore_passmap) THEN xgo = 0: wrappass = 1
  IF xgo < 0 ANDALSO check_wall_edges(x, y, dirRight,  isveh, , ignore_passmap) THEN xgo = 0: wrappass = 1
 END IF
END FUNCTION

' Check for a collision with the wallmap of an arbitrarily sized and positioned
' axis-aligned box moving in a straight line.
' (Only used by the "check wallmap collision" command currently.)
' Return value:
'  -0 if hit nothing
'  -a bitmask of 1 or 2 pass*Wall bits indicating the directions in which collision occurred
'  -one of the values passNortheastCorner, etc, if hit the end/corner of a wall diagonally
' Sets pos to be as far as possible along the line until the point of collision or to the target.
' NOTE: pos is NOT wrapped around the map (so can be used to calc distance moved).
' Walls already overlapping with the rectangle are ignored.
' Side-on walls are checked. xgo/ygo may be more than 20.
' walls_over_edges: true if edges of non-wrapping maps treated as walls.
' FIXME: if 'size' is smaller than a tile, it's possible to move a few pixels inside the
' walls of an off-map tile.
FUNCTION check_wallmap_collision (byval startpos as XYPair, byref pos as XYPair, byval size as XYPair, byval go as XYPair, isveh as bool, walls_over_edges as bool = YES) as integer

 DIM tilesize as XYPair = (20, 20)
 DIM as XYPair nextalign, dist, TL_tile, BR_tile

 ' Calculate the next X and Y positions (of the topleft of the box) at which the front X/Y edges of the
 ' box will be aligned with the wallmap.
 nextalign = startpos
 IF go.x > 0 THEN nextalign.x += size.x + (tilesize.x - 1)
 nextalign.x -= POSMOD(nextalign.x, tilesize.x)
 IF go.x > 0 THEN nextalign.x -= size.x
 IF go.y > 0 THEN nextalign.y += size.y + (tilesize.y - 1)
 nextalign.y -= POSMOD(nextalign.y, tilesize.y)
 IF go.y > 0 THEN nextalign.y -= size.y

 ' This loop advances nextalign to each successive tile-aligned position until go.x/y are exceeded.
 DO

  ' Displacement moved so far
  dist = nextalign - startpos

  IF ABS(dist.x) >= ABS(go.x) ANDALSO ABS(dist.y) >= ABS(go.y) THEN
   pos = startpos + go
   RETURN 0
  END IF

  ' Check whether X or Y alignment happens first and calculate that position (pos)

  DIM as double xfrac = 999., yfrac = 999.
  IF go.x <> 0 THEN xfrac = dist.x / go.x
  IF go.y <> 0 THEN yfrac = dist.y / go.y

  'debug "start = " & startpos & " size=" & size & " go=" & go & " nextalign=" & nextalign & " dist=" & dist

  ' min(xfrac,yfrac) is in the interval [0.0, 1.0)
  IF xfrac < yfrac THEN
   ' Due to rounding, pos.y might be 1 pixel past the collision point, but this
   ' should not allow it to exceed nextalign.y.
   pos.x = startpos.x + dist.x
   pos.y = startpos.y + (go.y / go.x) * dist.x
  ELSE
   pos.x = startpos.x + (go.x / go.y) * dist.y
   pos.y = startpos.y + dist.y
  END IF

  ' Tile positions of top-left/bottom-right corners of the colliding box
  ' (Bottom-right corner is exclusive)
  TL_tile = pos \ tilesize
  BR_tile = (pos + size - 1) \ tilesize

  'debug "  x/yfrac=" & xfrac & " , " & yfrac & "    pos = " & pos & " TL " & TL_tile & " BR " & BR_tile

  DIM as integer xtile, ytile
  DIM as DirNum whichdir

  ' Ignore coincidental alignment if not moving in that direction.

  DIM ret as integer

  ' Could write (pos.x - nextalign.x) MOD = 0 instead, though that would lose
  ' sub-pixel precision (which isn't important)
  IF pos.x = nextalign.x ANDALSO go.x <> 0 THEN
   ' xtile,ytile iterates over each of the tiles immediately in front of the box
   ' and dir is direction from that tile towards the box.
   IF go.x > 0 THEN
    whichdir = dirRight
    xtile = BR_tile.x + 1  'right
    nextalign.x += tilesize.x
   ELSE
    whichdir = dirLeft
    xtile = TL_tile.x - 1  'left
    nextalign.x -= tilesize.x
   END IF
   'debug "x-aligned, xtile=" & xtile
   FOR ytile = TL_tile.y TO BR_tile.y
    ' Check right/left walls
    IF check_wall_edges(xtile, ytile, whichdir XOR 2, isveh, walls_over_edges) THEN ret OR= 1 SHL whichdir

    IF ytile < BR_tile.y THEN
     ' Check edge-on tiles
     IF check_wall_edges(xtile, ytile, dirDown, isveh, walls_over_edges) THEN ret OR= 1 SHL whichdir
    END IF
   NEXT
  END IF

  IF pos.y = nextalign.y ANDALSO go.y <> 0 THEN
   IF go.y > 0 THEN
    whichdir = dirDown
    ytile = BR_tile.y + 1  'bottom
    nextalign.y += tilesize.y
   ELSE
    whichdir = dirUp
    ytile = TL_tile.y - 1  'top
    nextalign.y -= tilesize.y
   END IF
   'debug "y-aligned, ytile=" & ytile
   FOR xtile = TL_tile.x TO BR_tile.x
    ' Check up/down walls
    IF check_wall_edges(xtile, ytile, whichdir XOR 2, isveh, walls_over_edges) THEN ret OR= 1 SHL whichdir

    IF xtile < BR_tile.x THEN
     ' Check edge-on tiles
     IF check_wall_edges(xtile, ytile, dirRight, isveh, walls_over_edges) THEN ret OR= 1 SHL whichdir
    END IF
   NEXT
  END IF

  ' If we hit a wall, don't do a check for hitting a corner, because that's uninteresting and
  ' would cause strange return values
  IF ret THEN RETURN ret

  ' If both x and y sides collide, then must do a special check for hitting
  ' a corner exactly, since we need to check walls which are one tile further
  ' ahead, in both x and y directions (at xtile,ytile).
  ' Note that have to do this even if we hit the corner a fraction of a pixel in
  ' one axis before the other, in which case one of nextalign.x or .y have
  ' already been incremented, meaning that we can't check (pos = nextalign).
  IF go.x ANDALSO go.y ANDALSO (pos - nextalign) MOD tilesize = 0 THEN
   DIM as DirNum xdir, ydir
   IF go.x < 0 THEN
    xtile = TL_tile.x - 1
    xdir = dirRight
   ELSE
    xtile = BR_tile.x + 1
    xdir = dirLeft
   END IF
   IF go.y < 0 THEN
    ytile = TL_tile.y - 1
    ydir = dirDown
   ELSE
    ytile = BR_tile.y + 1
    ydir = dirUp
   END IF
   IF check_wall_edges(xtile, ytile, ydir, isveh, walls_over_edges) ORELSE _
      check_wall_edges(xtile, ytile, xdir, isveh, walls_over_edges) THEN
    RETURN ((1 SHL (xdir XOR 2)) OR (1 SHL (ydir XOR 2))) SHL 24
   END IF
  END IF

 LOOP
END FUNCTION

' See check_wallmap_collision.
' This is a wrapper to that, which implements friction/sliding down walls.
' Friction is a percentage value from 0 to 100, the amount to decrease the remaining
' xygo by when hitting a wall and sliding down it (100 prevents any sliding).
FUNCTION sliding_wallmap_collision (byval startpos as XYPair, byref pos as XYPair, byval size as XYPair, byval xygo as XYPair, isveh as bool, walls_over_edges as bool = YES, friction as integer = 100) as integer
 DIM ret as integer
 DO
  ret = check_wallmap_collision(startpos, pos, size, xygo, isveh, walls_over_edges)
  IF ret = 0 OR friction >= 100 THEN EXIT DO
  xygo -= (pos - startpos)
  'debug "after collisions, pos = " & pos & " xygo = " & xygo
  IF (ret AND passAllWalls) = 0 THEN
   ' Hit a corner. Break ties based on angle.
   ' If hitting the corner at 45, prefer vertical, for sidescrollers
   IF ABS(xygo.x) <= ABS(xygo.y) THEN
    xygo.x = 0
   ELSE
    xygo.y = 0
   END IF
  ELSE
   IF ret AND (passWestWall OR passEastWall) THEN xygo.x = 0
   IF ret AND (passNorthWall OR passSouthWall) THEN xygo.y = 0
  END IF
  startpos = pos
  'Decrease by friction %
  xygo = (xygo * (100 - friction)) \ 100
  IF xygo = 0 THEN EXIT DO
 LOOP
 RETURN ret
END FUNCTION

FUNCTION wrapzonecheck (byval zone as integer, byval pos as XYPair, byval xygo as XYPair) as bool
 'pos is in pixels
 'Warning: always wraps! But that isn't a problem on non-wrapping maps.

 pos -= xygo
 wrapxy pos, 20
 RETURN CheckZoneAtTile(zmap, zone, pos.x \ 20, pos.y \ 20)
END FUNCTION

FUNCTION wrapcollision (byval posa as XYPair, byval xygoa as XYPair, byval posb as XYPair, byval xygob as XYPair) as bool
FUNCTION wrapcollision (byval posa as XYPair, byval xygoa as XYPair, byval sizea as XYPair, byval posb as XYPair, byval xygob as XYPair, byval sizeb as XYPair) as bool
 DIM as XYPair dest1, dest2
 dest1.x = (posa.x - bound(xygoa.x, -20, 20)) \ 20
 dest2.x = (posb.x - bound(xygob.x, -20, 20)) \ 20
 dest1.y = (posa.y - bound(xygoa.y, -20, 20)) \ 20
 dest2.y = (posb.y - bound(xygob.y, -20, 20)) \ 20

 IF gmap(5) = mapEdgeWrap THEN
  RETURN (dest1 - dest2) MOD mapsizetiles = 0
 ELSE
  'RETURN dest1 = dest2
  ' Adapted from SliceCollide
  IF sizea.w + sizeb.w <= ABS(2 * dest1.x + sizea.w - 2 * dest2.x - sizeb.w) THEN RETURN NO
  IF sizea.h + sizeb.h <= ABS(2 * dest1.y + sizea.h - 2 * dest2.y - sizeb.h) THEN RETURN NO
  RETURN YES
 END IF
END FUNCTION

FUNCTION wraptouch (byval pos1 as XYPair, byval pos2 as XYPair, byval distance as integer) as bool
 'whether 2 walkabouts are within distance pixels horizontally + vertically
 IF gmap(5) = mapEdgeWrap THEN
  IF ABS((pos1 - pos2) MOD (mapsizetiles * 20 - distance)) <= distance THEN RETURN YES
 ELSE
  IF ABS(pos1 - pos2) <= 20 THEN RETURN YES
 END IF
 RETURN NO
END FUNCTION

'Called on the X or Y coordinate of a screen position to wrap it around the map
'so that's it's as close as possible to being on the screen.
PRIVATE FUNCTION closestwrappedpos (byval coord as integer, byval screenlen as integer, byval maplen as integer) as integer
 'consider two possibilities: one negative but as large as possible; and the one after that
 DIM as integer lowposs, highposs
 lowposs = (coord MOD maplen) + 10 'center of tile
 IF lowposs >= 0 THEN lowposs -= maplen
 highposs = lowposs + maplen

 'now evaluate which of lowposs or highposs are in or closer to the interval [0, screenlen]
 IF highposs - screenlen < 0 - lowposs THEN RETURN highposs - 10
 RETURN lowposs - 10
END FUNCTION

FUNCTION framewalkabout (byval mappos as XYPair, byref screenpos as XYPair, byval mapsize as XYPair, wrapmode as MapEdgeModeEnum, margin as integer = -1) as bool
 'Given a map position returns if a walkabout at that spot MIGHT be on-screen,
 'and sets screenpos to where on the screen to place it.
 'Due to slices attached to NPCs, it's practically impossible to tell, so by default
 'return YES. If you don't want that, pass 'margin' as the max number of pixels
 'that whatever you're drawing extends over the edge of the 20x20 tile (typically 0).
 'On a wraparound map, the position is wrapped to make it as close to a screen
 'edge as possible (might still appear bad for slices parented to a walkabout and offset)

 IF wrapmode = mapEdgeWrap THEN
  screenpos.x = closestwrappedpos(mappos.x - mapx, vpages(dpage)->w, mapsize.w)
  screenpos.y = closestwrappedpos(mappos.y - mapy, vpages(dpage)->h, mapsize.h)
 ELSE
  screenpos = mappos - XY(mapx, mapy)
 END IF
 IF margin = -1 THEN RETURN YES
 DIM bounds as RectType
 corners_to_rect XY(-20, -20) - margin, vpages(dpage)->size + margin, bounds
 RETURN rect_collide_point(bounds, screenpos)
END FUNCTION

FUNCTION xypair_direction_to (src_v as XYPair, dest_v as XYPair, default as DirNum = dirNone) as DirNum
 IF src_v = dest_v THEN RETURN default 'Same XY
 DIM diff as XYPair = dest_v - src_v
 IF ABS(diff.x) = ABS(diff.y) THEN RETURN default 'Make no attempt to resolve diagonals
 IF ABS(diff.x) > ABS(diff.y) THEN
  'Horizontal
  IF gmap(5) = mapEdgeWrap ANDALSO ABS(diff.x) > mapsizetiles.x / 2 THEN
   'Wraparound map
   IF diff.x < 0 THEN RETURN dirRight
   RETURN 3
  END IF
  IF diff.x < 0 THEN RETURN dirLeft
  RETURN 1
 ELSE
  'Vertical
  IF gmap(5) = mapEdgeWrap ANDALSO ABS(diff.y) > mapsizetiles.y / 2 THEN
   'Wraparound map
   IF diff.y < 0 THEN RETURN dirDown
   RETURN 0
  END IF
  IF diff.y < 0 THEN RETURN dirUp
  RETURN 2
 END IF
 RETURN default 'fallback should not be reached
END FUNCTION

'==========================================================================================
'                                        Vehicles
'==========================================================================================


FUNCTION vehicle_is_animating() as bool
 WITH vstate
  RETURN .mounting ORELSE .rising ORELSE .falling ORELSE .init_dismount ORELSE .ahead ORELSE .trigger_cleanup
 END WITH
END FUNCTION

SUB reset_vehicle(v as VehicleState)
 v.id = -1
 v.npc = 0
 v.old_speed = 0
 v.active   = NO
 v.mounting = NO
 v.rising   = NO
 v.falling  = NO
 v.init_dismount   = NO
 v.ahead           = NO
 v.trigger_cleanup = NO
 ClearVehicle v.dat
END SUB

SUB dump_vehicle_state()
 WITH vstate
  debug "active=" & .active & " npc=" & .npc & " id=" & .id & " mounting=" & .mounting & " rising=" & .rising & " falling=" & .falling & " dismount=" & .init_dismount & " cleanup=" & .trigger_cleanup & " ahead=" & .ahead
 END WITH
END SUB

SUB update_vehicle_state ()
 STATIC aheadpos as XYPair

 IF vstate.mounting THEN '--scramble-----------------------
  '--part of the vehicle automount where heros scramble--
  IF npc(vstate.npc).xgo = 0 AND npc(vstate.npc).ygo = 0 THEN
   '--npc must stop before we mount
   IF vehscramble(npc(vstate.npc).pos) THEN
    'Finished scramble
    vstate.mounting = NO
    IF vstate.dat.elevation > 0 THEN vstate.rising = YES
   END IF
  END IF
 END IF'--scramble mount
 IF vstate.rising THEN '--rise----------------------
  DIM risen_count as integer = 0
  FOR i as integer = 0 TO 3
   IF heroz(i) < vstate.dat.elevation THEN
    (heroz(i)) = heroz(i) + large(1, small(4, (vstate.dat.elevation - heroz(i) + 1) \ 2))
   ELSE
    risen_count += 1
   END IF
  NEXT i
  IF risen_count = 4 THEN
   vstate.rising = NO
  END IF
 END IF
 IF vstate.falling THEN '--fall-------------------
  DIM fallen_count as integer = 0
  FOR i as integer = 0 TO 3
   IF heroz(i) > 0 THEN
    (heroz(i)) = heroz(i) - large(1, small(4, (vstate.dat.elevation - heroz(i) + 1) \ 2))
   ELSE
    fallen_count += 1
   END IF
  NEXT i
  IF fallen_count = 4 THEN
   FOR i as integer = 0 TO 3
    (heroz(i)) = 0
   NEXT i
   vstate.falling = NO
   vstate.init_dismount = YES
  END IF
 END IF
 IF vstate.init_dismount THEN '--dismount---------------
  vstate.init_dismount = NO
  DIM dismountpos as XYPair = herotpos(0)
  IF vstate.dat.dismount_ahead AND vstate.dat.pass_walls_while_dismounting THEN
   '--dismount-ahead is true, dismount-passwalls is true
   aheadxy dismountpos, herodir(0), 1
   cropposition dismountpos.x, dismountpos.y, 1
  END IF
  IF vehpass(vstate.dat.dismount_to, readblock(pass, dismountpos.x, dismountpos.y), -1) THEN
   '--dismount point is landable
   resetcaterpillar ()
   IF vstate.dat.dismount_ahead = YES THEN
    vstate.ahead = YES
    aheadpos = dismountpos * 20
   ELSE
    vstate.trigger_cleanup = YES
   END IF
  ELSE
   '--dismount point is unlandable
   IF vstate.dat.elevation > 0 THEN
    vstate.rising = YES '--riseagain
   END IF
  END IF
 END IF
 IF vstate.trigger_cleanup THEN '--clear
  IF vstate.dat.on_dismount < 0 THEN
   trigger_script ABS(vstate.dat.on_dismount), 0, YES, "vehicle dismount", "", mainFibreGroup
  END IF
  IF vstate.dat.on_dismount > 0 THEN loadsay vstate.dat.on_dismount
  settag vstate.dat.riding_tag, NO
  IF vstate.dat.dismount_ahead = YES AND vstate.dat.pass_walls_while_dismounting = NO THEN
   'FIXME: Why is this here, when dismounting is apparently also handled by vehscramble?
   'Does this have to do with Bug 764 - "Blocked by" vehicle setting does nothing ?
   SELECT CASE herodir(0)
    CASE dirUp
     herow(0).ygo = 20
    CASE dirRight
     herow(0).xgo = -20
    CASE dirDown
     herow(0).ygo = -20
    CASE dirLeft
     herow(0).xgo = 20
   END SELECT
  END IF
  change_hero_speed(0, vstate.old_speed)
  npc(vstate.npc).xgo = 0
  npc(vstate.npc).ygo = 0
  npc(vstate.npc).z = 0
  delete_walkabout_shadow npc(vstate.npc).sl
  '--clear vehicle (sets vstate.active=NO, etc)
  reset_vehicle vstate
  resetcaterpillar ()
  gam.random_battle_countdown = range(100, 60)
 END IF
 IF vstate.ahead THEN '--dismounting ahead
  IF vehscramble(aheadpos) THEN
   vstate.ahead = NO
   vstate.trigger_cleanup = YES '--clear (happens next tick, maybe not intentionally)
  END IF
 END IF

 'Handle Use and Menu keys according to vehicle-specific settings
 IF vstate.active = YES AND normal_controls_disabled() = NO THEN
  REDIM button(1) as integer
  button(0) = vstate.dat.use_button
  button(1) = vstate.dat.menu_button
  FOR i as integer = 0 TO 1
   IF carray(ccUse + i) > 1 AND herow(0).xgo = 0 AND herow(0).ygo = 0 THEN
    SELECT CASE button(i)
     CASE -2
      '-disabled
     CASE -1
      add_menu 0
      menusound gen(genAcceptSFX)
     CASE 0
      '--dismount
      vehicle_graceful_dismount
     CASE IS > 0
      trigger_script button(i), 0, YES, "vehicle button " & i, "", mainFibreGroup
    END SELECT
   END IF
  NEXT i
 END IF

 IF vstate.active THEN npc(vstate.npc).z = heroz(0)
END SUB

SUB vehicle_graceful_dismount ()
 herow(0).xgo = 0
 herow(0).ygo = 0
 IF vstate.dat.elevation > 0 THEN
  vstate.falling = YES
 ELSE
  vstate.init_dismount = YES
 END IF
END SUB

SUB forcemountvehicle (byval npci as integer)
 DIM npcid as integer = npc(npci).id
 IF npc(npci).id < 0 THEN
  'Hidden/tagdisabled NPC
  EXIT SUB
 END IF
 npcid = npcid - 1 'Adjust for actual ID
 DIM vehid as integer = npcs(npcid).vehicle - 1
 IF vehid < 0 THEN
  'This NPC is not a vehicle
  EXIT SUB
 END IF
 forcedismount()
 try_mount_vehicle vehid, npci, YES
END SUB

'If it's possible to mount this vehicle/NPC, or forced, start the mount animation
SUB try_mount_vehicle(vehid as integer, npci as integer, force_mount as bool = NO)
 reset_vehicle vstate
 vstate.id = vehid
 LoadVehicle game & ".veh", vstate.dat, vstate.id
 IF force_mount = NO THEN
  '--check mounting permissions first
  IF vehpass(vstate.dat.mount_from, readblock(pass, herotx(0), heroty(0)), -1) = NO THEN EXIT SUB
 END IF
 vstate.active = YES
 vstate.npc = npci
 vstate.old_speed = herow(0).speed
 change_hero_speed(0, 10)
 vstate.mounting = YES '--trigger mounting sequence
 settag vstate.dat.riding_tag, YES
 create_walkabout_shadow npc(vstate.npc).sl
END SUB

SUB forcedismount ()
 IF vstate.active THEN
  '--clear vehicle on loading new map--
  IF vstate.dat.dismount_ahead = YES AND vstate.dat.pass_walls_while_dismounting = NO THEN
   '--dismount-ahead is true, dismount-passwalls is false
   SELECT CASE herodir(0)
    CASE dirUp
     herow(0).ygo = 20
    CASE dirRight
     herow(0).xgo = -20
    CASE dirDown
     herow(0).ygo = -20
    CASE dirLeft
     herow(0).xgo = 20
   END SELECT
  END IF
  IF vstate.dat.on_dismount > 0 THEN
   loadsay vstate.dat.on_dismount
  END IF
  IF vstate.dat.on_dismount < 0 THEN
   trigger_script ABS(vstate.dat.on_dismount), 0, YES, "vehicle dismount", "", mainFibreGroup
  END IF
  settag vstate.dat.riding_tag, NO
  change_hero_speed(0, vstate.old_speed)
  reset_vehicle vstate
  resetcaterpillar ()
  gam.random_battle_countdown = range(100, 60)
 END IF
END SUB

FUNCTION vehpass (byval n as integer, byval tile as integer, byval default as integer) as integer
 'This feature was ill-planned and ill-implemented.
 
 'Especially bad is the "override walls" and "blocked by" features.
 'They are moot when the vehicle bit to ignore walls is turned on,
 'And the way in which they selectively ignore walls is useless for most purposes.
 
 'PLAN: Deprecate the "override walls" and "blocked by" features.
 'Don't remove them of course, just hide them in a "Deprecated Vehicle Options"
 'sub-menu. Add support for allowing vehicles to optionally
 'respect the zone-restrictions of the NPC they are attached to. 
 
 'vehpass functionality for "Mount from" and "Dismount to" features is just fine,
 'as far as I can tell, and does not need to be deprecated.

 'n is the type of passability override rules to use. See the SELECT CASE below
 '--true means passable
 '--false means impassable

 DIM v as integer = default

 SELECT CASE n
  CASE 1
   v = (tile AND passVehA)
  CASE 2
   v = (tile AND passVehB)
  CASE 3
   v = ((tile AND passVehA) = passVehA) AND ((tile AND passVehB) = passVehB)
  CASE 4
   v = ((tile AND passVehA) = passVehA) OR ((tile AND passVehB) = passVehB)
  CASE 5
   v = NOT ((tile AND passVehA) = passVehA)
  CASE 6
   v = NOT ((tile AND passVehB) = passVehB)
  CASE 7
   v = NOT (((tile AND passVehA) = passVehA) OR ((tile AND passVehB) = passVehB))
  CASE 8
   v = YES
 END SELECT
 
 RETURN v <> 0
END FUNCTION

'Returns true if the scramble is finished
FUNCTION vehscramble(byval target as XYPair) as bool
 DIM scrambled_heroes as integer = 0
 'Maybe this should actually be caterpillar_count(), so that if caterpillar
 'mode is suspended, the other heroes don't mount the vehicle?
 DIM count as integer = active_party_size()
 DIM scramx as integer
 DIM scramy as integer
 FOR i as integer = 0 TO count - 1
  scramx = herox(i)
  scramy = heroy(i)
  IF ABS(scramx - target.x) < large(herow(i).speed, 4) THEN
   scramx = target.x
   herow(i).xgo = 0
   herow(i).ygo = 0
  END IF
  IF ABS(scramy - target.y) < large(herow(i).speed, 4) THEN
   scramy = target.y
   herow(i).xgo = 0
   herow(i).ygo = 0
  END IF
  IF ABS(target.x - scramx) > 0 AND herow(i).xgo = 0 THEN
   herow(i).xgo = 20 * SGN(scramx - target.x)
  END IF
  IF ABS(target.y - scramy) > 0 AND herow(i).ygo = 0 THEN
   herow(i).ygo = 20 * SGN(scramy - target.y)
  END IF
  IF gmap(5) = mapEdgeWrap THEN
   '--this is a wrapping map
   IF ABS(scramx - target.x) > mapsizetiles.x * 20 / 2 THEN herow(i).xgo *= -1
   IF ABS(scramy - target.y) > mapsizetiles.y * 20 / 2 THEN herow(i).ygo *= -1
  END IF
  IF scramx - target.x = 0 AND scramy - target.y = 0 THEN scrambled_heroes += 1
  (herox(i)) = scramx
  (heroy(i)) = scramy
 NEXT i
 IF scrambled_heroes = count THEN
  'All heroes have reached the target
  IF vstate.dat.on_mount < 0 THEN
   trigger_script ABS(vstate.dat.on_mount), 0, YES, "vehicle on-mount", "", mainFibreGroup
  END IF
  IF vstate.dat.on_mount > 0 THEN loadsay vstate.dat.on_mount
  IF vstate.dat.speed = 3 THEN
   change_hero_speed(0, 10)
  ELSE
   change_hero_speed(0, vstate.dat.speed)
  END IF
  '--null out hero's movement
  FOR i as integer = 0 TO 3
   herow(i).xgo = 0
   herow(i).ygo = 0
  NEXT i
  RETURN YES
 END IF
 RETURN NO
END FUNCTION

FUNCTION walkrotate(byval d as DirNum, byval rota as integer, byval amount as integer=1) as DirNum
 'rota: 1 is a clockwise right turn.
 '    -1 is a counterclockwise left turn.
 RETURN POSMOD(d + amount * rota, 4)
END FUNCTION

SUB cancel_npc_walk(npci as NPCInst)
 'Cancel NPC movement, but allow them to finish their current step
 npci.xygo = npci.xygo MOD 20
END SUB

SUB cancel_hero_walk(byval rank as integer)
 'Cancel hero movement, but allow them to finish their current step
 herow(rank).xygo = herow(rank).xygo MOD 20
END SUB

FUNCTION npc_at_spot(tilepos as XYPair, byval copynum as integer=0) as integer
 'Return the index into the npc() NPCInst of the npc found at the given x,y coords
 'or -1 if not found
 DIM found as integer = 0
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id > 0 THEN
   IF npc(i).pos \ 20 = tilepos THEN
    IF found = copynum THEN
     RETURN i
    END IF
    found = found + 1
   END IF
  END IF
 NEXT i
 RETURN -1 'failure
END FUNCTION

FUNCTION count_npcs_at_spot(tilepos as XYPair) as integer
 'Return the count of npcs instances at the given x,y coords
 'or 0 if not found
 DIM found as integer = 0
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id > 0 THEN
   IF npc(i).pos \ 20 = tilepos THEN
    found = found + 1
   END IF
  END IF
 NEXT i
 RETURN found
END FUNCTION

FUNCTION npc_at_pixel(pixelpos as XYPair, byval copynum as integer=0, allow_disabled as bool=NO) as integer
 'Return the index into the npc() NPCInst of the npc found at the given x,y coords.
 ' This checks the location where the npc is currently displayed,
 ' not the tile they are considered to be occupying
 ' pixelpos should be in the map bounds.
 ' Note: if an NPC is partially over the map edge we may miss it.
 'Returns -1 if not found
 DIM found as integer = 0
 FOR i as integer = 0 TO UBOUND(npc)
  IF npc(i).id > 0 OR (allow_disabled ANDALSO npc(i).id <> 0) THEN
   DIM size as XYPair = (20, 20)
   DIM diff as XYPair = pixelpos - XY(npc(i).x, npc(i).y + gmap(11))
   IF diff.x >= 0 AND diff.x < size.w THEN
    IF diff.y >= 0 AND diff.y < size.h THEN
     IF found = copynum THEN
      RETURN i
     END IF
     found = found + 1
    END IF
   END IF
  END IF
 NEXT i
 RETURN -1 'failure
END FUNCTION

