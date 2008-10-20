'OHRRPGCE CUSTOM - Miscellaneous unsorted routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
'$DYNAMIC
DEFINT A-Z

#include "const.bi"
#include "udts.bi"
#include "custom_udts.bi"

'basic subs and functions
DECLARE FUNCTION addmaphow () AS INTEGER
DECLARE FUNCTION filenum$ (n%)
DECLARE FUNCTION animadjust% (tilenum%, tastuf%())
DECLARE SUB writeglobalstring (index%, s$, maxlen%)
DECLARE SUB importbmp (f$, cap$, count%)
DECLARE SUB loadpasdefaults (array%(), tilesetnum%)
DECLARE SUB fixorder (f$)
DECLARE SUB vehicles ()
DECLARE SUB verifyrpg ()
DECLARE FUNCTION numbertail$ (s$)
DECLARE SUB cropafter (index%, limit%, flushafter%, lump$, bytes%, prompt%)
DECLARE FUNCTION exclude$ (s$, x$)
DECLARE FUNCTION exclusive$ (s$, x$)
DECLARE SUB fontedit (font%(), gamedir$)
DECLARE SUB testanimpattern (tastuf%(), taset%)
DECLARE SUB resizetiledata (array%(), xoff%, yoff%, neww%, newh%, yout%, page%, layer%)
DECLARE SUB mapmaker (font%())
DECLARE SUB npcdef (npc() AS NPCType, npc_img() AS GraphicPair, pt%)
DECLARE SUB shopdata ()
DECLARE SUB importsong ()
DECLARE SUB gendata ()
DECLARE SUB itemdata ()
DECLARE SUB formation ()
DECLARE SUB enemydata ()
DECLARE SUB herodata ()
DECLARE SUB attackdata (atkdat$(), atklim%())
DECLARE SUB getnames (stat$(), max%)
DECLARE SUB statname ()
DECLARE SUB textage ()
DECLARE FUNCTION sublist% (num%, s$())
DECLARE SUB maptile (font())
DECLARE SUB paint_map_area(oldTile%, x%, y%, layer%, usetile%(), map%(), pass%(), defaults() AS DefArray, tilesets%(), defpass%)

DECLARE Function LayerIsVisible(vis() as integer, byval l as integer) as integer
DECLARE Function LayerIsEnabled(gmap() as integer, byval l as integer) as integer
DECLARE Sub SetLayerVisible(vis() as integer, byval l as integer, byval v as integer)
DECLARE Sub SetLayerEnabled(gmap() as integer, byval l as integer, byval v as integer)
DECLARE Sub ToggleLayerVisible(vis() as integer, byval l as integer)
DECLARE Sub ToggleLayerEnabled(vis() as integer, byval l as integer)

DECLARE SUB DrawDoorPair(curmap as integer, cur as integer, map(), pass(), tilesets() as TilesetData ptr, doors() as door, link() as doorlink, gmap())

DECLARE SUB calculatepassblock(x AS INTEGER, y AS INTEGER, map() AS INTEGER, pass() AS INTEGER, defaults() AS DefArray, tilesets() AS TilesetData ptr)
DECLARE SUB resizemapmenu (map(), tilesets() AS TilesetData ptr, byref newwide, byref newhigh, byref tempx, byref tempy)

DECLARE SUB make_top_map_menu(maptop, topmenu$())
DECLARE SUB update_tilepicker(BYREF tilepick AS XYPair, layer AS INTEGER, usetile() AS INTEGER, menubarstart() AS INTEGER)
DECLARE SUB verify_map_size (mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, mapname AS STRING)
DECLARE SUB mapedit_loadmap (BYREF st AS MapEditState, mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, visible() AS INTEGER, tilesets() AS TilesetData ptr, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, defaults() AS DefArray, mapname AS STRING)
DECLARE SUB mapedit_savemap (BYREF st AS MapEditState, mapnum AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, mapname AS STRING)
DECLARE SUB new_blank_map (BYREF st AS MapEditState, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink)
DECLARE SUB mapedit_addmap(BYREF st AS MapEditState, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, tilesets() AS TilesetData ptr)
DECLARE SUB mapedit_resize(BYREF st AS MapEditState, mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, BYREF x AS INTEGER, BYREF y AS INTEGER, BYREF mapx AS INTEGER, BYREF mapy AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, tilesets() AS TilesetData ptr, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, mapname AS STRING)
DECLARE SUB mapedit_delete(BYREF st AS MapEditState, mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, BYREF x AS INTEGER, BYREF y AS INTEGER, BYREF mapx AS INTEGER, BYREF mapy AS INTEGER, BYREF layer AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink)
DECLARE SUB link_one_door(mapnum AS INTEGER, linknum AS INTEGER, link() AS DoorLink, doors() AS Door, map() AS INTEGER, pass() AS INTEGER, gmap() AS INTEGER, tilesets() AS TilesetData ptr)
DECLARE SUB mapedit_linkdoors (BYREF st AS MapEditState, mapnum AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, tilesets() AS TilesetData ptr, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, mapname AS STRING)
DECLARE SUB mapedit_layers (gmap() AS INTEGER, visible() AS INTEGER, tilesets() AS TilesetData ptr, defaults() AS DefArray, startlayer AS INTEGER = -1)
DECLARE FUNCTION find_last_used_doorlink(link() AS DoorLink) AS INTEGER
DECLARE FUNCTION find_door_at_spot (x AS INTEGER, y AS INTEGER, doors() AS Door) AS INTEGER
DECLARE FUNCTION find_first_free_door (doors() AS Door) AS INTEGER
DECLARE FUNCTION find_first_doorlink_by_door(doornum AS INTEGER, link() AS DoorLink) AS INTEGER
DECLARE SUB resize_rezoom_mini_map(BYREF zoom AS INTEGER, wide AS INTEGER, high AS INTEGER, tempx AS INTEGER, tempy AS INTEGER, tempw AS INTEGER, temph AS INTEGER, minimap() AS UBYTE, map() AS INTEGER, tilesets() AS TilesetData ptr)
DECLARE SUB show_minimap(map() AS INTEGER, tilesets() AS TilesetData ptr)

#include "compat.bi"
#include "allmodex.bi"
#include "common.bi"
#include "customsubs.bi"
#include "cglobals.bi"

#include "scrconst.bi"
#include "scancodes.bi"
#include "loading.bi"

REM $STATIC

FUNCTION addmaphow () AS INTEGER
'--Return values
'  -2  =Cancel
'  -1  =New blank
'  >=0 =Copy

DIM temp$(2)
DIM need_update AS INTEGER
DIM maptocopy AS INTEGER = 0
DIM pt AS INTEGER = 0

need_update = YES
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN
  '--return cancel
  RETURN -2
 END IF
 IF usemenu(pt, 0, 0, 2, 22) THEN need_update = YES
 IF pt = 2 THEN
  IF intgrabber(maptocopy, 0, gen(genMaxMap)) THEN need_update = YES
 END IF
 IF enter_or_space() THEN
  SELECT CASE pt
   CASE 0 ' cancel
    RETURN -2
   CASE 1 ' blank
    RETURN -1
   CASE 2 ' copy
    RETURN maptocopy
  END SELECT
 END IF
 IF need_update THEN
  need_update = NO
  temp$(0) = "Cancel"
  temp$(1) = "New Blank Map"
  temp$(2) = "Copy of map " & maptocopy & " " & getmapname$(maptocopy)
 END IF
 standardmenu temp$(), 2, 22, pt, 0, 0, 0, dpage, 0
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
END FUNCTION

FUNCTION animadjust (tilenum, tastuf())
'given a tile number and the tile-animation data,
'adjusts to make sure the tile is non-animated
pic = tilenum
IF pic >= 208 THEN pic = (pic - 208) + tastuf(20)
IF pic >= 160 THEN pic = (pic - 160) + tastuf(0)
animadjust = pic
END FUNCTION

SUB mapmaker (font())
DIM st AS MapEditState
DIM npc(1500)
DIM menubar(82), cursor(600), mode$(12), list$(13), temp$(12), menu$(-1 TO 20), topmenu$(24), gmap(dimbinsize(4)), gd$(0 TO 20), gdmax(20), gdmin(20), sampmap(2), cursorpal(8), pal16(288), gmapscr$(5), gmapscrof(5), npcnum(max_npc_defs)
DIM her AS HeroDef
DIM tilesets(2) as TilesetData ptr
DIM defaults(2) as DefArray

redim doors(99) as door, link(199) as doorlink

DIM as integer usetile(0 to 2)
DIM as integer menubarstart(0 to 2)
DIM as integer layer
DIM as integer jiggle(0)
DIM as integer visible(0) = {&b111} 'used as bitsets

'FIXME: heroimg is a hack and should be replaced with a GraphicPair object
DIM heroimg(102), heropal(8)

DIM npc_img(max_npc_defs) AS GraphicPair

REDIM map(2) ' dummy empty map data, will be resized later
REDIM pass(2)
REDIM emap(2)

DIM tilepick AS XYPair

DIM foe AS INTEGER = 0 ' Formation number for foemapping mode

textcolor uilook(uiText), 0

wide = 0: high = 0: nptr = 0
mapname$ = ""

xtemp$ = ""
FOR i = 0 TO 15: xtemp$ = xtemp$ + CHR$(i): NEXT i ' Populate this 16-palette with the first 16 colors of the master palette, just... because...
str2array xtemp$, cursorpal(), 0
'Correct the colors that actually get used
poke8bit cursorpal(), 15, uilook(uiText)
poke8bit cursorpal(), 7, uilook(uiMenuItem)

'--create cursor
'-- there is a good reason this doesn't use uilook(). getsprite expects voodoo like this.
'-- See also the construction of cursorpal() above
clearpage 2
rectangle 0, 0, 20, 20, 15, 2
rectangle 1, 1, 18, 18, 0, 2
rectangle 2, 2, 16, 16, 7, 2
rectangle 3, 3, 14, 14, 0, 2
getsprite cursor(), 200, 0, 0, 20, 20, 2
clearpage 2
rectangle 0, 0, 20, 20, 15, 2
rectangle 1, 1, 18, 18, 0, 2
rectangle 3, 3, 14, 14, 7, 2
rectangle 4, 4, 12, 12, 0, 2
getsprite cursor(), 400, 0, 0, 20, 20, 2

mode$(0) = "Picture Mode"
mode$(1) = "Passability Mode"
mode$(2) = "Door Placement Mode"
mode$(3) = "NPC Placement Mode"
mode$(4) = "Foe Mapping Mode"
menubar(0) = 160: menubar(1) = 1
sampmap(0) = 1
sampmap(1) = 1
setmapdata menubar(), pass(), 180, 0
FOR i = 0 TO 159
 setmapblock i, 0, 0, i
NEXT

maptop = 0
pt = 0
csr = 0
make_top_map_menu maptop, topmenu$()
setkeys
DO
 setwait 55
 setkeys
 IF keyval(1) > 1 THEN EXIT DO
 oldtop = maptop
 usemenu pt, maptop, 0, 2 + gen(0), 24
 IF oldtop <> maptop THEN make_top_map_menu maptop, topmenu$()
 IF enter_or_space() THEN
  IF pt = 0 THEN EXIT DO
  IF pt > 0 AND pt <= gen(0) + 1 THEN
   '--silly backcompat pt adjustment
   pt = pt - 1
   mapedit_loadmap st, pt, wide, high, map(), pass(), emap(), gmap(), visible(), tilesets(), npc(), doors(), link(), defaults(), mapname$
   GOSUB whattodo
   pt = pt + 1
   make_top_map_menu maptop, topmenu$()
  END IF
  IF pt = gen(0) + 2 THEN
   mapedit_addmap st, map(), pass(), emap(), gmap(), npc(), doors(), link(), tilesets()
   make_top_map_menu maptop, topmenu$()
  END IF
 END IF
 tog = tog XOR 1
 FOR i = 0 TO 24
  textcolor uilook(uiMenuItem), 0
  IF pt = maptop + i THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr topmenu$(i), 0, i * 8, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
clearpage 0
clearpage 1
clearpage 2
clearpage 3
unloadmaptilesets tilesets()
EXIT SUB

whattodo:
x = 0: y = 0: mapx = 0: mapy = 0
list$(0) = "Return to Map Menu"
list$(1) = "Edit General Map Data..."
list$(2) = "Resize Map..."
list$(3) = "Layers and Tilesets..."
list$(4) = "Edit NPCs..."
list$(5) = "Edit Tilemap..."
list$(6) = "Edit Wallmap..."
list$(7) = "Place Doors..."
list$(8) = "Place NPCs..."
list$(9) = "Edit Foemap..."
list$(10) = "Link Doors..."
list$(11) = "Erase Map Data"
list$(12) = "Re-load Default Passability"
list$(13) = "Map name:"

'--load NPC graphics--
FOR i = 0 TO max_npc_defs
 'Load the picture and palette
 WITH npc_img(i)
  .sprite = sprite_load(game + ".pt4", st.npc_def(i).picture, 8, 20, 20)
  .pal    = palette16_load(game + ".pal", st.npc_def(i).palette, 4, st.npc_def(i).picture)
 END WITH
NEXT i

setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN
  mapedit_savemap st, pt, map(), pass(), emap(), gmap(), npc(), doors(), link(), mapname$
  EXIT DO
 END IF
 usemenu csr, 0, 0, 13, 24
 IF enter_or_space() THEN
  IF csr = 0 THEN
   mapedit_savemap st, pt, map(), pass(), emap(), gmap(), npc(), doors(), link(), mapname$
   EXIT DO
  END IF
  IF csr = 1 THEN
   GOSUB gmapdata
  END IF
  IF csr = 2 THEN
   mapedit_resize st, pt, wide, high, x, y, mapx, mapy, map(), pass(), emap(), gmap(), tilesets(), npc(), doors(), link(), mapname$
  END IF
  IF csr = 3 THEN
   mapedit_layers gmap(), visible(), tilesets(), defaults()
  END IF
  IF csr = 4 THEN
   npcdef st.npc_def(), npc_img(), pt
  END IF
  IF csr >= 5 AND csr <= 9 THEN editmode = csr - 5: GOSUB mapping
  IF csr = 10 THEN mapedit_linkdoors st, pt, map(), pass(), emap(), gmap(), tilesets(), npc(), doors(), link(), mapname$
  IF csr = 11 THEN mapedit_delete st, pt, wide, high, x, y, mapx, mapy, layer, map(), pass(), emap(), npc(), doors(), link()
  IF csr = 12 THEN
   '--reload default passability
   temp$(0) = "No, Nevermind. No passability changes"
   temp$(1) = "Set default passability for whole map"
   IF sublist(1, temp$()) = 1 THEN
    FOR tx = 0 TO pass(0) - 1
     FOR ty = 0 TO pass(1) - 1
      calculatepassblock tx, ty, map(), pass(), defaults(), tilesets()
     NEXT ty
    NEXT tx
   END IF
  END IF
 END IF
 IF csr = 13 THEN strgrabber mapname$, 39
 list$(13) = "Map name:" + mapname$
 IF LEN(list$(13)) > 40 THEN list$(13) = mapname$
 
 standardmenu list$(), 13, 13, csr, 0, 0, 0, dpage, 0
 
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
'Unload NPC graphics
FOR i = 0 TO max_npc_defs
 WITH npc_img(i)
  if .sprite then sprite_unload(@.sprite)
  if .pal then palette16_unload(@.pal)
 END WITH
NEXT i
RETRACE

gmapdata:
gmapmax = 18
gd = 0
gd$(0) = "Previous Menu"
gd$(1) = "Ambient Music:"
gd$(2) = "Minimap Available:"
gd$(3) = "Save Anywhere:"
gd$(4) = "Display Map Name:"
gd$(5) = "Map Edge Mode:"
gd$(6) = "Default Edge Tile:"
gd$(7) = "Autorun Script: "
gd$(8) = "Script Argument:"
gd$(9) = "Harm-Tile Damage:"
gd$(10) = "Harm-Tile Flash:"
gd$(11) = "Foot Offset:"
gd$(12) = "After-Battle Script:"
gd$(13) = "Instead-of-Battle Script:"
gd$(14) = "Each-Step Script:"
gd$(15) = "On-Keypress Script:"
gd$(16) = "Walkabout Layering:"
gd$(17) = "NPC Data:"
gd$(18) = "Tile Data:"
gdmax(1) = gen(genMaxSong) + 1:        gdmin(1) = -1
gdmax(2) = 1:                              gdmin(2) = 0
gdmax(3) = 1:                              gdmin(3) = 0
gdmax(4) = 255:                            gdmin(4) = 0
gdmax(5) = 2:                              gdmin(5) = 0
gdmax(6) = 255:                            gdmin(6) = 0
gdmax(7) = 32767:                          gdmin(7) = 0
gdmax(8) = 32767:                          gdmin(8) = -32767
gdmax(9) = 32767:                          gdmin(9) = -32767
gdmax(10) = 255:                           gdmin(10) = 0
gdmax(11) = 20:                            gdmin(11) = -20
gdmax(12) = 32767:                         gdmin(12) = 0
gdmax(13) = 32767:                         gdmin(13) = 0
gdmax(14) = 32767:                         gdmin(14) = 0
gdmax(15) = 32767:                         gdmin(15) = 0
gdmax(16) = 1:                             gdmin(16) = 0
gdmax(17) = 2:                             gdmin(16) = 0
gdmax(18) = 2:                             gdmin(16) = 0

gmapscrof(0) = 7
gmapscrof(1) = 12
gmapscrof(2) = 13
gmapscrof(3) = 14
gmapscrof(4) = 15

IF gmap(16) > 1 THEN gmap(16) = 0
FOR i = 1 TO gmapmax
 gmap(i) = bound(gmap(i), gdmin(i), gdmax(i))
NEXT i
FOR i = 0 TO 4
 gmapscr$(i) = scriptname$(gmap(gmapscrof(i)), plottrigger)
NEXT i
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 usemenu gd, 0, 0, gmapmax, 24
 SELECT CASE gd
  CASE 0
   IF enter_or_space() THEN EXIT DO
  CASE 1
   zintgrabber(gmap(gd), gdmin(gd) - 1, gdmax(gd) - 1) 'song is optional
  CASE 7, 12 TO 15
   IF gd = 7 THEN idx = 0 ELSE idx = gd - 11
   IF enter_or_space() THEN
    gmapscr$(idx) = scriptbrowse$(gmap(gd), plottrigger, "plotscript")
   ELSEIF scrintgrabber(gmap(gd), 0, 0, 75, 77, 1, plottrigger) THEN
    gmapscr$(idx) = scriptname$(gmap(gd), plottrigger)
   END IF
  CASE 10' Harm tile color
   intgrabber gmap(gd), gdmin(gd), gdmax(gd)
   IF enter_or_space() THEN
    gmap(gd) = color_browser_256(gmap(gd))
   END IF
  CASE ELSE
   intgrabber gmap(gd), gdmin(gd), gdmax(gd)
 END SELECT
 scri = 0
 FOR i = 0 TO gmapmax
  xtemp$ = ""
  SELECT CASE i
   CASE 1
    IF gmap(1) = 0 THEN
     xtemp$ = " -silence-"
    ELSEIF gmap(1) = -1 THEN
     xtemp$ = " -same as previous map-"
    ELSE
     xtemp$ = XSTR$(gmap(1) - 1) + " " + getsongname$(gmap(1) - 1)
    END IF
   CASE 2, 3
    IF gmap(i) = 0 THEN xtemp$ = " NO" ELSE xtemp$ = " YES"
   CASE 4
    IF gmap(i) = 0 THEN xtemp$ = " NO" ELSE xtemp$ = XSTR$(gmap(i)) + " ticks"
   CASE 5
    SELECT CASE gmap(i)
     CASE 0
      xtemp$ = " Crop"
     CASE 1
      xtemp$ = " Wrap"
     CASE 2
      xtemp$ = " use default edge tile"
    END SELECT
   CASE 6
    IF gmap(5) = 2 THEN
     xtemp$ = XSTR$(gmap(i))
    ELSE
     xtemp$ = " N/A"
    END IF
   CASE 7, 12 TO 15
    xtemp$ = gmapscr$(scri)
    scri = scri + 1
   CASE 8
    IF gmap(7) = 0 THEN
     xtemp$ = " N/A"
    ELSE
     xtemp$ = XSTR$(gmap(i))
    END IF
   CASE 9
    xtemp$ = XSTR$(gmap(i))
   CASE 10
    IF gmap(i) = 0 THEN
     xtemp$ = " none"
    ELSE
     xtemp$ = XSTR$(gmap(i))
    END IF
   CASE 11
    SELECT CASE gmap(i)
     CASE 0
      xtemp$ = " none"
     CASE IS < 0
      xtemp$ = " up" + XSTR$(ABS(gmap(i))) + " pixels"
     CASE IS > 0
      xtemp$ = " down" + XSTR$(gmap(i)) + " pixels"
    END SELECT
   CASE 16
    IF gmap(i) = 1 THEN
     xtemp$ = " NPCs over Heroes"
    ELSE
     xtemp$ = " Heroes over NPCs"
    END IF
   CASE 17, 18
    SELECT CASE gmap(i)
     CASE 0
      xtemp$ = " Don't save state when leaving"
     CASE 1
      xtemp$ = " Remember state when leaving"
     CASE 2
      xtemp$ = " Ignore saved state, load anew"
    END SELECT
  END SELECT
  textcolor uilook(uiMenuItem), 0
  IF i = gd THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr gd$(i) + xtemp$, 0, 8 * i, dpage
  IF i = 10 THEN rectangle 4 + (8 * LEN(gd$(i) + xtemp$)), 8 * i, 8, 8, gmap(i), dpage
 NEXT i
 IF gmap(5) = 2 THEN
  '--show default edge tile
  setmapdata sampmap(), sampmap(), 180, 0
  setmapblock 0, 0, 0, gmap(6)
  drawmap 0, -180, 0, 0, tilesets(0), dpage
  rectangle 20, 180, 300, 20, uilook(uiBackground), dpage
 END IF
 
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
RETRACE

mapping:
clearpage 2
'--load hero graphics--
'FIXME this is a hack. heroimg() should be replaced with a Frame object
loadherodata @her, 0
loadrecord heroimg(), game + ".pt4", 100, her.walk_sprite * 8 + 4
fixspriterecord heroimg(), 20, 20
getpal16 heropal(), 0, her.walk_sprite_pal, 4, her.walk_sprite
defpass = 1
IF readbit(gen(), genBits, 15) THEN defpass = 0 ' option to default the defaults to OFF
doorid = 0
doorlinkid = 0

setkeys
DO
 setwait 55
 setkeys
 IF keyval(1) > 1 THEN EXIT DO
 if keyval(scCtrl) = 0 AND keyval(scAlt) = 0 then
  IF keyval(59) > 1 THEN
   editmode = 0
  END IF
  IF keyval(60) > 1 THEN
   editmode = 1
  END IF
  IF keyval(61) > 1 THEN
   editmode = 2
  END IF
  IF keyval(62) > 1 THEN
   editmode = 3
  END IF
  IF keyval(63) > 1 THEN
   editmode = 4
  END IF
 else
  for i = 0 to 2
   if keyval(scAlt) > 0 AND keyval(sc1 + i) > 1 then
    clearkey(sc1 + i)
    togglelayerenabled(gmap(), i)
    if not layerisenabled(gmap(), i) then
     if layer = i then
      do until layerisenabled(gmap(), layer): layer -= 1: loop
     end if
    end if
   end if
   #IFNDEF __FB_LINUX__
   if keyval(scCtrl) > 0 AND keyval(scF1 + i) > 1 then
    clearkey(scF1 + i)
    if layerisenabled(gmap(), i) then togglelayervisible(visible(), i)
   end if
   #ENDIF
  next
  
  if keyval(scTilde) > 1 then
   togglelayervisible(visible(), layer)
   clearkey(scTilde)
  end if
 end if
 
 IF keyval(29) > 0 AND keyval(38) > 1 THEN mapedit_layers gmap(), visible(), tilesets(), defaults(), layer  'ctrl-L
 IF keyval(15) > 1 THEN tiny = tiny XOR 1
 IF keyval(29) > 0 AND keyval(14) > 1 THEN
   'delete tile
   setmapdata map(), pass(), 20, 0
   FOR i = 0 TO 2
    setmapblock x, y, i, 0
   NEXT i
   'delete passability
   setmapdata map(), pass(), 20, 0
   setpassblock x, y, 0
   'delete foemap
   setmapdata emap(), pass(), 20, 0
   setmapblock x, y, 0, 0
   'setmapdata sucks. we should find a better way...
   setmapdata map(), pass(), 20, 0
   'delete NPC
   FOR i = 0 TO 299
    IF npc(i + 600) > 0 THEN
     IF npc(i + 0) = x AND npc(i + 300) = y + 1 THEN npc(i + 600) = 0
    END IF
   NEXT i
   'delete door
   doorid = find_door_at_spot(x, y, doors())
   IF doorid >= 0 THEN
    setbit doors(doorid).bits(), 0, 0, 1
   END IF
 END IF
 IF keyval(29) > 0 AND keyval(35) > 1 THEN 'Ctrl+H for hero start position
  gen(genStartMap) = pt
  gen(genStartX) = x
  gen(genStartY) = y
 END IF
 SELECT CASE editmode
  '---TILEMODE------
  CASE 0
   setmapdata map(), pass(), 20, 0
   IF keyval(33) > 1 AND keyval(29) > 0 THEN' Ctrl+F Fill screen
    FOR tx = 0 TO 14
     FOR ty = 0 TO 8
      setmapblock mapx \ 20 + tx, mapy \ 20 + ty, layer, usetile(layer)
      IF defpass THEN calculatepassblock mapx \ 20 + tx, mapy \ 20 + ty, map(), pass(), defaults(), tilesets()
     NEXT ty
    NEXT tx
   END IF
   IF keyval(19) > 1 AND keyval(29) > 0 THEN' Ctrl+R to replace-all
    old = readmapblock(x, y, layer)
    FOR ty = 0 to map(1)
     FOR tx = 0 to map(0)
      IF readmapblock(tx, ty, layer) = old THEN setmapblock tx, ty, layer, usetile(layer)
     NEXT tx
    NEXT ty
   END IF
   IF keyval(25) > 1 AND keyval(29) > 0 THEN' Ctrl+P to paint a continuous section of maptiles
    old = readmapblock(x, y, layer)
    paint_map_area old, x, y, layer, usetile(), map(), pass(), defaults(), tilesets(), defpass
   END IF
   IF keyval(29) > 0 AND keyval(36) > 1 THEN
     setbit jiggle(), 0, layer, (readbit(jiggle(), 0, layer) XOR 1)
   END IF
   IF keyval(41) > 1 THEN show_minimap map(), tilesets()
   IF keyval(28) > 1 THEN GOSUB pickblock
   IF keyval(57) > 0 THEN
    setmapblock x, y, layer, usetile(layer)
    IF defpass THEN calculatepassblock x, y, map(), pass(), defaults(), tilesets()
   END IF
   IF keyval(83) > 1 THEN 'delete
    setmapblock x, y, layer, 0
   END IF
   IF keyval(58) > 1 THEN 'grab tile
    usetile(layer) = animadjust(readmapblock(x, y, layer), tilesets(layer)->tastuf())
    update_tilepicker tilepick, layer, usetile(), menubarstart()
   END IF
   IF keyval(29) > 0 AND keyval(32) > 1 THEN defpass = defpass XOR 1   
   FOR i = 0 TO 1 
    IF keyval(2 + i) > 1 THEN 'animate tile
     newtile = -1
     old = readmapblock(x, y, layer)
     IF old >= 160 + i * 48 AND old < 160 + i * 48 + 48 THEN
      newtile = (old - (160 + (i * 48))) + tilesets(layer)->tastuf(i * 20)
     ELSEIF old >= tilesets(layer)->tastuf(i * 20) AND old < tilesets(layer)->tastuf(i * 20) + 48 THEN
      newtile = 160 + (i * 48) + (old - tilesets(layer)->tastuf(i * 20))
     END IF
     IF newtile >= 0 THEN
      IF keyval(29) = 0 THEN
       setmapblock x, y, layer, newtile
      ELSE
       FOR tx = 0 TO map(0) - 1
        FOR ty = 0 TO map(1) - 1
         IF readmapblock(tx, ty, layer) = old THEN setmapblock tx, ty, layer, newtile
        NEXT ty
       NEXT tx
      END IF
     END IF
    END IF
   NEXT i
   IF keyval(51) > 1 AND usetile(layer) > 0 THEN
    usetile(layer) = usetile(layer) - 1
    update_tilepicker tilepick, layer, usetile(), menubarstart()
   END IF
   IF keyval(52) > 1 AND usetile(layer) < 159 THEN
    usetile(layer) = usetile(layer) + 1
    update_tilepicker tilepick, layer, usetile(), menubarstart()
   END IF
   '---PASSMODE-------
  CASE 1
   setmapdata pass(), pass(), 20, 0
   over = readmapblock(x, y, 0)
   IF keyval(57) > 1 AND (over AND 15) = 0 THEN setmapblock x, y, 0, 15
   IF keyval(57) > 1 AND (over AND 15) = 15 THEN setmapblock x, y, 0, 0
   IF keyval(57) > 1 AND (over AND 15) > 0 AND (over AND 15) < 15 THEN setmapblock x, y, 0, 0
   IF keyval(83) > 1 THEN 'delete
    setmapblock x, y, 0, 0
   END IF
   IF keyval(29) > 0 THEN
    IF keyval(72) > 1 THEN setmapblock x, y, 0, (over XOR 1)
    IF keyval(77) > 1 THEN setmapblock x, y, 0, (over XOR 2)
    IF keyval(80) > 1 THEN setmapblock x, y, 0, (over XOR 4)
    IF keyval(75) > 1 THEN setmapblock x, y, 0, (over XOR 8)
   END IF
   IF keyval(30) > 1 THEN setmapblock x, y, 0, (over XOR 16) 'vehicle A
   IF keyval(48) > 1 THEN setmapblock x, y, 0, (over XOR 32) 'vehicle B
   IF keyval(35) > 1 THEN setmapblock x, y, 0, (over XOR 64) 'harm tile
   IF keyval(24) > 1 THEN setmapblock x, y, 0, (over XOR 128)'overhead
   '---DOORMODE-----
  CASE 2
   IF keyval(28) > 1 THEN ' enter to link a door
    doorid = find_door_at_spot(x, y, doors())
    IF doorid >= 0 THEN
     'Save currently-worked-on map data
     mapedit_savemap st, pt, map(), pass(), emap(), gmap(), npc(), doors(), link(), mapname$
     doorlinkid = find_first_doorlink_by_door(doorid, link())
     IF doorlinkid >= 0 THEN
      link_one_door pt, doorlinkid, link(), doors(), map(), pass(), gmap(), tilesets()
     ELSE
      doorlinkid = find_last_used_doorlink(link()) + 1
      IF doorlinkid >= 0 AND doorlinkid <= UBOUND(link) THEN
       link(doorlinkid).source = doorid
       link_one_door pt, doorlinkid, link(), doors(), map(), pass(), gmap(), tilesets()
      END IF
     END IF
    END IF
   END IF
   IF keyval(57) > 1 THEN ' space to place a door
    doorid = find_door_at_spot(x, y, doors())
    IF doorid >= 0 THEN
     'clear an existing door
     setbit doors(doorid).bits(), 0, 0, 0
    ELSE
     'place a new door
     doorid = find_first_free_door(doors())
     IF doorid >= 0 THEN
      doors(doorid).x = x
      doors(doorid).y = y + 1
      setbit doors(doorid).bits(), 0, 0, 1
     END IF
    END IF
   END IF
   IF keyval(83) > 1 THEN 'delete
    doorid = find_door_at_spot(x, y, doors())
    IF doorid >= 0 THEN
     setbit doors(doorid).bits(), 0, 0, 0
    END IF
   END IF
   '---NPCMODE------
  CASE 3
   IF keyval(83) > 1 THEN 'delete
    FOR i = 0 TO 299
     IF npc(i + 600) > 0 THEN
      IF npc(i + 0) = x AND npc(i + 300) = y + 1 THEN npc(i + 600) = 0
     END IF
    NEXT i
   END IF
   nd = -1
   IF keyval(29) > 0 THEN
    IF slowkey(72, 12) THEN nd = 0
    IF slowkey(77, 12) THEN nd = 1
    IF slowkey(80, 12) THEN nd = 2
    IF slowkey(75, 12) THEN nd = 3
   END IF
   IF keyval(57) > 1 OR nd > -1 THEN
    temp = 0
    IF nd = -1 THEN
     FOR i = 0 TO 299
      IF npc(i + 600) > 0 THEN
       IF npc(i + 0) = x AND npc(i + 300) = y + 1 THEN npc(i + 600) = 0: temp = 1
      END IF
     NEXT i
    END IF
    IF nd = -1 THEN nd = 2
    IF temp = 0 THEN
     temp = -1
     FOR i = 299 TO 0 STEP -1
      IF npc(i + 600) = 0 THEN temp = i
     NEXT i
     IF temp >= 0 THEN npc(temp + 0) = x: npc(temp + 300) = y + 1: npc(temp + 600) = nptr + 1: npc(temp + 900) = nd
    END IF
   END IF
   intgrabber(nptr, 0, max_npc_defs, 51, 52)
   '---FOEMODE--------
  CASE 4
   intgrabber(foe, 0, 255, 51, 52)
   IF keyval(57) > 0 THEN
    setmapdata emap(), pass(), 20, 0
    setmapblock x, y, 0, foe
    setmapdata map(), pass(), 20, 0
   END IF
   IF keyval(83) > 1 THEN 'delete
    setmapdata emap(), pass(), 20, 0
    setmapblock x, y, 0, 0
    setmapdata map(), pass(), 20, 0
   END IF
   IF keyval(33) > 1 AND keyval(29) > 0 THEN
    setmapdata emap(), pass(), 20, 0
    FOR i = 0 TO 14
     FOR o = 0 TO 8
      setmapblock INT(mapx / 20) + i, INT(mapy / 20) + o, 0, foe
     NEXT o
    NEXT i
    setmapdata map(), pass(), 20, 0
   END IF
   IF keyval(58) > 1 THEN foe = readmapblock(x, y, 0)
   '--done input-modes-------
 END SELECT
 
 setmapdata map(), pass(), 20, 0
 
 '--general purpose controls----
 IF keyval(scLeftShift) > 0 OR keyval(scRightShift) > 0 THEN
  xrate = 8
  yrate = 5
 ELSE
  xrate = 1
  yrate = 1
 END IF
 IF keyval(56) = 0 AND keyval(29) = 0 THEN
  IF slowkey(72, 2) THEN y = large(y - yrate, 0): IF y < INT(mapy / 20) THEN mapy = y * 20
  IF slowkey(80, 2) THEN y = small(y + yrate, high - 1): IF y > INT(mapy / 20) + 8 THEN mapy = y * 20 - 160
  IF slowkey(75, 2) THEN x = large(x - xrate, 0): IF x < INT(mapx / 20) THEN mapx = x * 20
  IF slowkey(77, 2) THEN x = small(x + xrate, wide - 1): IF x > INT(mapx / 20) + 14 THEN mapx = x * 20 - 280
 END IF
 IF keyval(56) > 0 AND keyval(29) = 0 THEN
  oldrelx = x - mapx / 20
  oldrely = y - mapy / 20
  IF slowkey(72, 2) THEN mapy = large(mapy - 20 * yrate, 0)
  IF slowkey(80, 2) THEN mapy = small(mapy + 20 * yrate, high * 20 - 180)
  IF slowkey(75, 2) THEN mapx = large(mapx - 20 * xrate, 0)
  IF slowkey(77, 2) THEN mapx = small(mapx + 20 * xrate, wide * 20 - 300)
  x = mapx / 20 + oldrelx
  y = mapy / 20 + oldrely
 END IF
 
 IF editmode = 0 THEN 'tilemode, uses layers
  IF keyval(scPageup) > 1 THEN
   FOR i = layer+1 TO 2
    IF layerisenabled(gmap(), i) THEN
     layer = i
     setlayervisible(visible(), layer, 1)
     update_tilepicker tilepick, layer, usetile(), menubarstart()
     EXIT FOR
    END IF
   NEXT i
  END IF

  IF keyval(scPageDown) > 1 THEN
   FOR i = layer-1 TO 0 STEP -1
    IF layerisenabled(gmap(), i) THEN
     layer = i
     setlayervisible(visible(), layer, 1)
     update_tilepicker tilepick, layer, usetile(), menubarstart()
     EXIT FOR
    END IF
   NEXT
  END IF
 END IF
 
 tog = tog XOR 1
 flash = loopvar(flash, 0, 3, 1)
 
 '--draw menubar
 IF editmode = 0 THEN
  setmapdata menubar(), pass(), 0, 180
  drawmap menubarstart(layer) * 20, 0, 0, 0, tilesets(layer), dpage
 ELSE
  rectangle 0, 0, 320, 20, uilook(uiBackground), dpage
 END IF
 
 '--draw map
 setmapdata map(), pass(), 20, 0
 animatetilesets tilesets()
 rectangle 0, 20, 320, 180, uilook(uiBackground), dpage
 for i = 0 to 2
 	if layerisvisible(visible(), i) AND layerisenabled(gmap(), i) then
		jigx = 0: jigy = 0
		if readbit(jiggle(), 0, i) and tog then
			if i = 0 then jigx = 1
			if i = 1 then jigy = 1
			if i = 2 then jigx = -1: jigy = -1
		end if
		if i = 0 then
			drawmap mapx + jigx, mapy + jigy - 20, 0, 1, tilesets(0), dpage, 0
		elseif i = 1 then
			drawmap mapx + jigx, mapy + jigy - 20, 1, 0, tilesets(1), dpage, 1
		elseif i = 2 then
			drawmap mapx + jigx, mapy + jigy - 20, 2, 0, tilesets(2), dpage, 1
		end if
	end if
 next
 if layerisvisible(visible(), 0) AND layerisenabled(gmap(), 0) then
	if readbit(jiggle(), 0, 0) and tog then
		drawmap mapx + 1, mapy - 20, 0, 2, tilesets(0), dpage, 0
	else
		drawmap mapx, mapy - 20, 0, 2, tilesets(0), dpage, 0
	end if
 end if
 
 '--show passmode overlay
 IF editmode = 1 THEN
  setmapdata pass(), pass(), 20, 0
  FOR o = 0 TO 8
   FOR i = 0 TO 15
    over = readmapblock((mapx \ 20) + i, (mapy \ 20) + o, 0)
    IF (over AND 1) THEN rectangle i * 20, o * 20 + 20, 20, 3, uilook(uiMenuItem + tog), dpage
    IF (over AND 2) THEN rectangle i * 20 + 17, o * 20 + 20, 3, 20, uilook(uiMenuItem + tog), dpage
    IF (over AND 4) THEN rectangle i * 20, o * 20 + 37, 20, 3, uilook(uiMenuItem + tog), dpage
    IF (over AND 8) THEN rectangle i * 20, o * 20 + 20, 3, 20, uilook(uiMenuItem + tog), dpage
    textcolor uilook(uiSelectedItem + tog), 0
    IF (over AND 16) THEN printstr "A", i * 20, o * 20 + 20, dpage
    IF (over AND 32) THEN printstr "B", i * 20 + 10, o * 20 + 20, dpage
    IF (over AND 64) THEN printstr "H", i * 20, o * 20 + 30, dpage
    IF (over AND 128) THEN printstr "O", i * 20 + 10, o * 20 + 30, dpage
   NEXT i
  NEXT o
 END IF
 
 '--door display--
 IF editmode = 2 THEN
  textcolor uilook(uiBackground), 0
  FOR i = 0 TO 99
   IF doors(i).x >= INT(mapx / 20) AND doors(i).x < INT(mapx / 20) + 16 AND doors(i).y > INT(mapy / 20) AND doors(i).y <= INT(mapy / 20) + 9 AND readbit(doors(i).bits(),0,0) = 1 THEN
    rectangle doors(i).x * 20 - mapx, doors(i).y * 20 - mapy, 20, 20, uilook(uiSelectedItem + tog), dpage
    printstr STR$(i), doors(i).x * 20 - mapx + 10 - (4 * LEN(STR$(i))), doors(i).y * 20 - mapy + 6, dpage
   END IF
  NEXT
 END IF

 '--hero start location display--
 IF gen(genStartMap) = pt THEN
  IF gen(genStartX) >= INT(mapx / 20) AND gen(genStartX) < INT(mapx / 20) + 16 AND gen(genStartY) > INT(mapy / 20) AND gen(genStartY) <= INT(mapy / 20) + 9 THEN
   drawsprite heroimg(), 0, heropal(), 0, gen(genStartX) * 20 - mapx, gen(genStartY) * 20 + 20 - mapy, dpage
   printstr "Hero", gen(genStartX) * 20 - mapx, gen(genStartY) * 20 + 30 - mapy, dpage
  END IF
 END IF

 '--npc display--
 IF editmode = 3 THEN
  FOR i = 0 to max_npc_defs
   npcnum(i) = 0
  NEXT
  walk = walk + 1: IF walk > 3 THEN walk = 0
  FOR i = 0 TO 299
   IF npc(i + 600) > 0 THEN
    IF npc(i + 0) >= INT(mapx / 20) AND npc(i + 0) < INT(mapx / 20) + 16 AND npc(i + 300) > INT(mapy / 20) AND npc(i + 300) <= INT(mapy / 20) + 9 THEN
     WITH npc_img(npc(i + 600) - 1)
      sprite_draw .sprite + (2 * npc(i + 900)) + walk \ 2, .pal, npc(i) * 20 - mapx, npc(i + 300) * 20 - mapy, 1, -1, dpage
     END WITH
     textcolor uilook(uiSelectedItem + tog), 0
     xtemp$ = STR$(npc(i + 600) - 1)
     printstr xtemp$, npc(i) * 20 - mapx, npc(i + 300) * 20 - mapy + 3, dpage
     xtemp$ = STR$(npcnum(npc(i + 600)-1))
     printstr xtemp$, npc(i) * 20 - mapx, npc(i + 300) * 20 - mapy + 12, dpage
    END IF
    npcnum(npc(i + 600) - 1) = npcnum(npc(i + 600) - 1) + 1
   END IF
  NEXT
 END IF
 
 '--position finder--
 IF tiny = 1 THEN
  fuzzyrect 0, 20, wide, high, uilook(uiHighlight), dpage
  rectangle mapx / 20, (mapy / 20) + 20, 15, 9, uilook(uiDescription), dpage
 END IF
 
 '--normal cursor--
 IF editmode <> 3 THEN
  drawsprite cursor(), 200 * (1 + tog), cursorpal(), 0, (x * 20) - mapx, (y * 20) - mapy + 20, dpage
  IF editmode = 0 THEN drawsprite cursor(), 200 * (1 + tog), cursorpal(), 0, ((usetile(layer) - menubarstart(layer)) * 20), 0, dpage
 END IF
 
 '--npc placement cursor--
 IF editmode = 3 THEN
  WITH npc_img(nptr)
   sprite_draw .sprite + (2 * walk), .pal, x * 20 - mapx, y * 20 - mapy + 20, 1, -1, dpage
  END WITH
  textcolor uilook(uiSelectedItem + tog), 0
  xtemp$ = STR$(nptr)
  printstr xtemp$, (x * 20) - mapx, (y * 20) - mapy + 28, dpage
 END IF
 
 '--show foemap--
 IF editmode = 4 THEN
  setmapdata emap(), pass(), 20, 0
  textcolor uilook(uiSelectedItem + tog), 0
  FOR i = 0 TO 14
   FOR o = 0 TO 8
    temp = readmapblock(INT(mapx / 20) + i, INT(mapy / 20) + o, 0)
    IF temp > 0 THEN printstr STR$(temp), i * 20 - ((temp < 10) * 5), o * 20 + 26, dpage
   NEXT o
  NEXT i
 END IF
 
 textcolor uilook(uiSelectedItem + tog), 0
 if editmode = 0 then
 printstr "Layer " & layer, 0, 180, dpage
 end if
 printstr "X " & x & "   Y " & y, 0, 192, dpage
 setmapdata map(), pass(), 20, 0
 rectangle 300, 0, 20, 200, uilook(uiBackground), dpage
 rectangle 0, 19, 320, 1, uilook(uiText), dpage
 IF editmode = 0 THEN
  status$ = "Default Passability "
  IF defpass THEN status$ = status$ + "On" ELSE status$ = status$ + "Off"
  printstr status$, 124, 192, dpage
 END IF
 textcolor uilook(uiText), 0
 printstr mode$(editmode), 0, 24, dpage
 IF editmode = 4 THEN textcolor uilook(uiText), uilook(uiHighlight): printstr "Formation Set: " & foe, 0, 16, dpage
 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP
RETRACE '--end of mapping GOSUB block

pickblock:
setkeys
menubar(0) = 16
menubar(1) = 10
setmapdata menubar(), pass(), 0, 0
DO
 setwait 80
 setkeys
 IF keyval(28) > 1 OR keyval(1) > 1 THEN menu = usetile(layer): EXIT DO
 IF (keyval(72) AND 5) AND tilepick.y > 0 THEN tilepick.y -= 1: usetile(layer) = usetile(layer) - 16
 IF (keyval(80) AND 5) AND tilepick.y < 9 THEN tilepick.y += 1: usetile(layer) = usetile(layer) + 16
 IF (keyval(75) AND 5) AND tilepick.x > 0 THEN tilepick.x -= 1: usetile(layer) = usetile(layer) - 1
 IF (keyval(77) AND 5) AND tilepick.x < 15 THEN tilepick.x += 1: usetile(layer) = usetile(layer) + 1
 IF (keyval(51) AND 5) AND usetile(layer) > 0 THEN
  usetile(layer) -= 1
  tilepick.x -= 1
  IF tilepick.x < 0 THEN tilepick.x = 15: tilepick.y -= 1
 END IF
 IF (keyval(52) AND 5) AND usetile(layer) < 159 THEN
  usetile(layer) += 1
  tilepick.x += 1
  IF tilepick.x > 15 THEN tilepick.x = 0: tilepicky += 1
 END IF
 tog = tog XOR 1
 drawmap 0, 0, 0, 0, tilesets(layer), dpage
 loadsprite cursor(), 0, 0, 0, 20, 20, 2
 drawsprite cursor(), 200 * (1 + tog), cursorpal(), 0, tilepick.x * 20, tilepick.y * 20, dpage
' copypage dpage, vpage
 setvispage dpage
 dowait
LOOP
menubar(0) = 160
menubar(1) = 1
update_tilepicker tilepick, layer, usetile(), menubarstart()
RETRACE

'----
'gmap(20)
'0=tileset
'1=ambient music
'2=minimap
'3=save anywhere
'4=show map name
'5=map edge mode
'6=default edge tile
'7=autorun script
'8=script argument
'9=harm tile damage
'10=harm tile flash
'11=default foot-offset
'12=afterbattle script
'13=instead-of-battle script
'14=eachstep script
'15=onkeypress script

'tiles
'1   north
'2   east
'4   south
'8   west
'16  vehicle A
'32  vehicle B
'64  harm tile
'128 overhead
END SUB

SUB mapedit_layers (gmap() AS INTEGER, visible() AS INTEGER, tilesets() AS TilesetData ptr, defaults() AS DefArray, startlayer AS INTEGER)
 DIM state AS MenuState
 DIM menu$(10)
 DIM enabled(10) AS INTEGER
 DIM itemcol(10) AS INTEGER

 DIM backpage, currentset
 currentset = -1
 clearpage 2

 state.pt = (startlayer + 1) * 3
 state.top = 0
 state.last = UBOUND(menu$)
 state.size = 19

 GOSUB makelayermenu
 DO 
  setwait 55
  setkeys
  tog = tog XOR 1

  IF keyval(1) > 1 THEN clearkey(1): EXIT DO

  IF usemenu(state, enabled()) THEN
   state.need_update = YES
  END IF

  layerno = (state.pt - 2) \ 3
  IF state.pt <= 1 THEN layerno = -1

  SELECT CASE state.pt
   CASE 0
    IF enter_or_space() THEN
     EXIT DO
    END IF
   case 1
    intgrabber gmap(0), 0, gen(genMaxTile)
    state.need_update = YES
   CASE 3,6,9
    IF enter_or_space() THEN
     ToggleLayerEnabled(gmap(), layerno)
     state.need_update = YES
    END IF
    IF layerisenabled(gmap(), layerno) AND (keyval(75) > 1 OR keyval(77) > 1) THEN
     ToggleLayerVisible(visible(), layerno)
     state.need_update = YES
    END IF
   CASE 4,7,10
    zintgrabber gmap(22 + layerno), -1, gen(genMaxTile)
    state.need_update = YES
  END SELECT

  IF state.need_update THEN
   state.need_update = NO
   GOSUB makelayermenu
  END IF

  copypage backpage, dpage

  SELECT CASE layerno
   CASE 0
    edgeprint "  Opaque       Underneath NPCs/Heroes", 0, 190, uilook(uiText), dpage
   CASE 1
    edgeprint "  Transparent  Underneath NPCs/Heroes", 0, 190, uilook(uiText), dpage
   CASE 2
    edgeprint "  Transparent  Above NPCs/Heroes", 0, 190, uilook(uiText), dpage
  END SELECT
  
  FOR i = state.top TO state.top + state.size
   IF i <= state.last THEN
    col = itemcol(i)
    'IF enabled(i) = 0 THEN col = uilook(uiDisabledItem)
    IF state.pt = i THEN col = uilook(uiSelectedItem + tog)
    edgeprint menu$(i), 0, (i - state.top) * 9, col, dpage
   END IF
  NEXT

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 clearpage dpage
 loadmaptilesets tilesets(), gmap()
 FOR i = 0 TO 2
  loadpasdefaults defaults(i).a(), tilesets(i)->num
 NEXT

 EXIT SUB

updateback:
 wantset = currentset
 SELECT CASE state.pt
  CASE 1
   wantset = gmap(0)
   backpage = 3
  CASE 4,7,10
   wantset = gmap(22 + (state.pt - 2) \ 3) - 1
   IF wantset = -1 THEN wantset = gmap(0)
   backpage = 3
  CASE ELSE
   backpage = 2
 END SELECT
 IF wantset <> currentset THEN
  loadpage game + ".til", wantset, 3
  currentset = wantset
 END IF
 RETRACE

makelayermenu:
 flusharray enabled(), UBOUND(enabled), YES
 flusharray itemcol(), UBOUND(itemcol), uilook(uiMenuItem)
 menu$(0) = "Go back"
 menu$(1) = "Default tileset: "
' menu$(1) = "Bottom Layer "
' menu$(2) = "Middle Layer "
' menu$(3) = "Top Layer    "
 
 needdefault = NO
 
 temp = 2
 FOR i = 0 TO 2
  enabled(temp) = NO
  menu$(temp) = "Layer " & i
  temp += 1

  IF layerisenabled(gmap(), i) THEN
   IF layerisvisible(visible(), i) THEN
    menu$(temp) = " Enabled (" & CHR$(27) & "Visible in editor" & CHR$(26) & ")"
    itemcol(temp - 1) = uilook(uiSelectedDisabled)
   ELSE
    menu$(temp) = " Enabled (" & CHR$(27) & "Invisible in editor" & CHR$(26) & ")"
    itemcol(temp - 1) = uilook(uiDisabledItem)
   END IF
  ELSE
   menu$(temp) = " Disabled in-game"
   itemcol(temp - 1) = uilook(uiDisabledItem)
  END IF
  temp += 1

  IF gmap(22 + i) = 0 THEN
   menu$(temp) = " Tileset: Default"
   needdefault = YES
  ELSE
   menu$(temp) = " Tileset: " & gmap(22 + i) - 1
  END IF
  temp += 1
 NEXT
 
 IF needdefault THEN
  menu$(1) += STR$(gmap(0))
 ELSE
  menu$(1) += "(Not used)"
  enabled(1) = NO
  itemcol(1) = uilook(uiDisabledItem)
 END IF

 GOSUB updateback
 RETRACE

END SUB

FUNCTION find_door_at_spot (x AS INTEGER, y AS INTEGER, doors() AS Door) AS INTEGER
 DIM i AS INTEGER
 FOR i = 0 TO UBOUND(doors)
  IF doors(i).x = x AND doors(i).y = y + 1 AND readbit(doors(i).bits(),0,0) = 1 THEN
   RETURN i
  END IF
 NEXT i
 RETURN -1
END FUNCTION

FUNCTION find_first_free_door (doors() AS Door) AS INTEGER
 DIM i AS INTEGER
 FOR i = 0 TO UBOUND(doors)
  IF readbit(doors(i).bits(), 0, 0) = 0 THEN
   RETURN i
  END IF
 NEXT i
 RETURN -1
END FUNCTION

FUNCTION find_first_doorlink_by_door(doornum AS INTEGER, link() AS DoorLink) AS INTEGER
 DIM i AS INTEGER
 FOR i = 0 TO UBOUND(link)
  IF link(i).source = doornum THEN RETURN i
 NEXT i
 RETURN -1
END FUNCTION

SUB mapedit_addmap(BYREF st AS MapEditState, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, tilesets() AS TilesetData ptr)
 DIM how AS INTEGER
 
 'Temporary buffers for making the copy
 DIM copyname AS STRING
 DIM copysize AS XYPair
 DIM visible(0) AS INTEGER
 visible(0) = &b111 'used as bitsets
 DIM defaults(2) AS DefArray
 
 how = addmaphow()
 '-- -2  =Cancel
 '-- -1  =New blank
 '-- >=0 =Copy
 IF how = -1 THEN
  gen(genMaxMap) += 1
  new_blank_map st, map(), pass(), emap(), gmap(), npc(), doors(), link()
  mapedit_savemap st, gen(genMaxMap), map(), pass(), emap(), gmap(), npc(), doors(), link(), ""
 ELSEIF how >= 0 THEN
  gen(genMaxMap) += 1
  mapedit_loadmap st, how, copysize.x, copysize.y, map(), pass(), emap(), gmap(), visible(), tilesets(), npc(), doors(), link(), defaults(), copyname
  mapedit_savemap st, gen(genMaxMap), map(), pass(), emap(), gmap(), npc(), doors(), link(), copyname
 END IF
END SUB

SUB new_blank_map (BYREF st AS MapEditState, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink)
 '--flush map buffers
 cleantiledata map(), 64, 64, 3
 cleantiledata pass(), 64, 64
 cleantiledata emap(), 64, 64
 flusharray gmap(), 19, 0
 flusharray npc(), 900, 0
 CleanNPCD st.npc_def()
 cleandoors doors()
 cleandoorlinks link()
END SUB

SUB mapedit_loadmap (BYREF st AS MapEditState, mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, visible() AS INTEGER, tilesets() AS TilesetData ptr, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, defaults() AS DefArray, mapname AS STRING)
 loadrecord gmap(), game & ".map", dimbinsize(binMAP), mapnum
 visible(0) = &b111   'default all layers to visible, if they're enabled too, of course
 loadmaptilesets tilesets(), gmap()
 FOR i = 0 TO 2
  loadpasdefaults defaults(i).a(), tilesets(i)->num
 NEXT
 loadtiledata maplumpname$(mapnum, "t"), map(), 3, wide, high
 loadtiledata maplumpname$(mapnum, "p"), pass()
 loadtiledata maplumpname$(mapnum, "e"), emap()
 xbload maplumpname$(mapnum, "l"), npc(), "npclocation lump is missing!"
 LoadNPCD maplumpname(mapnum, "n"), st.npc_def()
 deserdoors game & ".dox", doors(), mapnum
 deserdoorlinks maplumpname$(mapnum, "d"), link()
 mapname$ = getmapname$(mapnum)
 verify_map_size mapnum, wide, high, map(), pass(), emap(), mapname
END SUB

SUB mapedit_savemap (BYREF st AS MapEditState, mapnum AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, mapname AS STRING)
 storerecord gmap(), game & ".map", getbinsize(binMAP) / 2, mapnum
 savetiledata maplumpname$(mapnum, "t"), map(), 3
 savetiledata maplumpname$(mapnum, "p"), pass()
 savetiledata maplumpname$(mapnum, "e"), emap()
 xBSAVE maplumpname$(mapnum, "l"), npc(), 3000
 SaveNPCD maplumpname(mapnum, "n"), st.npc_def()
 serdoors game & ".dox", doors(), mapnum
 serdoorlinks maplumpname$(mapnum, "d"), link()
 '--save map name
 DIM mapsave(39) AS INTEGER
 mapsave(0) = LEN(mapname)
 str2array LEFT(mapname, 39), mapsave(), 1
 storerecord mapsave(), game & ".mn", 40, mapnum
END SUB

SUB verify_map_size (mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, mapname AS STRING)
 IF map(0) = pass(0) AND map(0) = emap(0) AND map(1) = pass(1) AND map(1) = emap(1) THEN EXIT SUB
 '--Map's X and Y do not match
 wide = map(0)
 high = map(1)
 clearpage vpage
 DIM j AS INTEGER
 j = 0
 textcolor uilook(uiText), 0
 printstr "Map" & filenum$(mapnum) & ":" & mapname, 0, j * 8, vpage
 j += 2
 printstr "this map seems to be corrupted", 0, j * 8, vpage
 j += 2
 printstr " TileMap " & map(0) & "*" & map(1) & " tiles", 0, j * 8, vpage: j += 1
 printstr " WallMap " & pass(0) & "*" & pass(1) & " tiles", 0, j * 8, vpage: j += 1
 printstr " FoeMap " & emap(0) & "*" & emap(1) & " tiles", 0, j * 8, vpage: j += 1
 j += 1
 printstr "Fixing to " & wide & "*" & high, 0, j * 8, vpage: j += 1
 'A map's size might be due to corruption, besides, the tilemap is far away the most important
 'wide = large(map(0), large(pass(0), emap(0)))
 'high = large(map(1), large(pass(1), emap(1)))
 'map(0) = wide: map(1) = high
 pass(0) = wide: pass(1) = high
 emap(0) = wide: emap(1) = high
 savetiledata maplumpname$(mapnum, "t"), map(), 3
 savetiledata maplumpname$(mapnum, "p"), pass()
 savetiledata maplumpname$(mapnum, "e"), emap()
 loadtiledata maplumpname$(mapnum, "t"), map(), 3, wide, high
 loadtiledata maplumpname$(mapnum, "p"), pass()
 loadtiledata maplumpname$(mapnum, "e"), emap()
 j += 1
 printstr "please report this error to", 0, j * 8, vpage: j += 1
 printstr "ohrrpgce@HamsterRepublic.com", 0, j * 8, vpage: j += 1
 setvispage vpage
 waitforanykey
END SUB

SUB mapedit_resize(BYREF st AS MapEditState, mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, BYREF x AS INTEGER, BYREF y AS INTEGER, BYREF mapx AS INTEGER, BYREF mapy AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, tilesets() AS TilesetData ptr, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, mapname AS STRING)
'sizemap:
 DIM size AS XYPair
 DIM spot AS XYPair
 size.x = 0
 size.y = 0
 spot.x = 0
 spot.y = 0
 resizemapmenu map(), tilesets(), size.x, size.y, spot.x, spot.y
 IF size.x = -1 THEN EXIT SUB

 clearpage 0
 clearpage 1
 
 DIM yout AS INTEGER = 0
 edgeprint "TILEMAP", 0, yout * 10, uilook(uiText), vpage: setvispage vpage: yout += 1
 resizetiledata map(), spot.x, spot.y, size.x, size.y, yout, vpage, 3
 edgeprint "PASSMAP", 0, yout * 10, uilook(uiText), vpage: setvispage vpage: yout += 1
 resizetiledata pass(), spot.x, spot.y, size.x, size.y, yout, vpage, 1
 edgeprint "FOEMAP", 0, yout * 10, uilook(uiText), vpage: setvispage vpage: yout += 1
 resizetiledata emap(), spot.x, spot.y, size.x, size.y, yout, vpage, 1
 ' update SAV x/y offset in MAP lump
 gmap(20) += spot.x * - 1
 gmap(21) += spot.y * - 1
 ' update hero's starting position (if on current map)
 IF gen(genStartMap) = mapnum THEN
  gen(genStartX) += spot.x * -1
  gen(genStartY) += spot.y * -1 
 END IF
 setmapdata map(), pass(), 20, 0
 wide = map(0)
 high = map(1)
 '--reset map scroll position
 x = 0
 y = 0
 mapx = 0
 mapy = 0
 edgeprint "Aligning and truncating doors", 0, yout * 10, uilook(uiText), vpage: yout += 1
 DIM i AS INTEGER
 FOR i = 0 TO 99
  doors(i).x -= spot.x
  doors(i).y -= spot.y
  IF doors(i).x < 0 OR doors(i).y < 0 OR doors(i).x >= wide OR doors(i).y >= high THEN
   setbit(doors(i).bits(),0,0,0)
  END IF
 NEXT
 edgeprint "Aligning and truncating NPCs", 0, yout * 10, uilook(uiText), vpage: setvispage vpage: yout += 1
 FOR i = 0 TO 299
  npc(i + 0) = npc(i + 0) - spot.x
  npc(i + 300) = npc(i + 300) - spot.y
  IF npc(i + 0) < 0 OR npc(i + 300) < 0 OR npc(i + 0) >= wide OR npc(i + 300) >= high THEN
   npc(i + 600) = 0
  END IF
 NEXT i
 verify_map_size mapnum, wide, high, map(), pass(), emap(), mapname
END SUB

SUB mapedit_delete(BYREF st AS MapEditState, mapnum AS INTEGER, BYREF wide AS INTEGER, BYREF high AS INTEGER, BYREF x AS INTEGER, BYREF y AS INTEGER, BYREF mapx AS INTEGER, BYREF mapy AS INTEGER, BYREF layer AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, npc() AS INTEGER, doors() AS Door, link() AS DoorLink)
 setvispage vpage
 IF yesno("Delete this map?", NO) THEN
  printstr "Please Wait...", 0, 40, vpage
  setvispage vpage

  cleantiledata map(), wide, high, 3
  cleantiledata pass(), wide, high
  cleantiledata emap(), wide, high
  flusharray npc(), 900, 0
  cleandoorlinks link()
  cleandoors doors()

  savetiledata maplumpname$(mapnum, "t"), map(), 3
  savetiledata maplumpname$(mapnum, "p"), pass()
  savetiledata maplumpname$(mapnum, "e"), emap()
  xBSAVE maplumpname$(mapnum, "l"), npc(), 3000
  serdoorlinks maplumpname$(mapnum, "d"), link()
  serdoors game + ".dox", doors(), mapnum
  '--reset scroll position
  x = 0
  y = 0
  mapx = 0
  mapy = 0
  layer = 0
 END IF
END SUB

SUB update_tilepicker(BYREF tilepick AS XYPair, layer AS INTEGER, usetile() AS INTEGER, menubarstart() AS INTEGER)
 menubarstart(layer) = bound(menubarstart(layer), large(usetile(layer) - 14, 0), small(usetile(layer), 145))
 tilepick.y = usetile(layer) \ 16
 tilepick.x = usetile(layer) - (tilepick.y * 16)
END SUB

SUB mapedit_linkdoors (BYREF st AS MapEditState, mapnum AS INTEGER, map() AS INTEGER, pass() AS INTEGER, emap() AS INTEGER, gmap() AS INTEGER, tilesets() AS TilesetData ptr, npc() AS INTEGER, doors() AS Door, link() AS DoorLink, mapname AS STRING)
 mapedit_savemap st, mapnum, map(), pass(), emap(), gmap(), npc(), doors(), link(), mapname
 
 DIM state AS MenuState
 state.top = 0
 state.pt = 0
 state.last = small(find_last_used_doorlink(link()) + 1, UBOUND(link))
 state.size = 11
 state.need_update = YES

 DIM menu_temp AS STRING
 DIM col AS INTEGER

 setkeys
 DO
  setwait 55
  setkeys
  state.tog = state.tog XOR 1
  IF keyval(1) > 1 THEN
   serdoorlinks(maplumpname$(mapnum, "d"), link())
   EXIT DO
  END IF
  IF usemenu(state) THEN state.need_update = YES
  IF enter_or_space() THEN
   IF state.pt = state.last AND link(state.pt).source = -1 THEN link(state.pt).source = 0
   link_one_door mapnum, state.pt, link(), doors(), map(), pass(), gmap(), tilesets()
   state.need_update = YES
   IF state.pt = state.last AND link(state.pt).source >= 0 THEN
    state.last = small(state.last + 1, UBOUND(link))
   END IF
  END IF
  IF state.need_update THEN
   state.need_update = NO
   DrawDoorPair mapnum, state.pt, map(), pass(), tilesets(), doors(), link(), gmap()
  END IF
  FOR i = state.top TO small(state.top + state.size, state.last)
   col = uilook(uiMenuItem)
   IF state.pt = i THEN
    col = uilook(uiSelectedItem + state.tog)
    edgeboxstyle 0, 1 + (i - state.top) * 16, 280, 19, 0, dpage, YES
   END IF

   IF link(i).source >= 0 THEN
    menu_temp = "Door " & link(i).source & " leads to door " & link(i).dest & " on map " & link(i).dest_map
    edgeprint menu_temp, 0, 2 + (i - state.top) * 16, col, dpage

    IF link(i).tag1 = 0 AND link(i).tag2 = 0 THEN
     menu_temp = "  all the time"
    ELSE
     menu_temp = "  only if tag "
     IF link(i).tag1 <> 0 THEN
      menu_temp += ABS(link(i).tag1) & " = " & iif(link(i).tag1 > 0, 1, 0)
     END IF
     IF link(i).tag2 THEN
      IF link(i).tag1 THEN menu_temp += " and tag "
      menu_temp += ABS(link(i).tag2) & " = " & iif(link(i).tag2 > 0, 1, 0)
     END IF
    END IF
    edgeprint menu_temp, 0, 10 + (i - state.top) * 16, col, dpage
   ELSEIF i = state.last THEN
    menu_temp = "Create a new doorlink..."
    edgeprint menu_temp, 0, 2 + (i - state.top) * 16, col, dpage
   ELSE
    menu_temp = "Unused Door link #" & i
    edgeprint menu_temp, 0, 2 + (i - state.top) * 16, col, dpage
   END IF
  NEXT i
  SWAP vpage, dpage
  setvispage vpage
  copypage 2, dpage
  dowait
 LOOP
END SUB

SUB link_one_door(mapnum AS INTEGER, linknum AS INTEGER, link() AS DoorLink, doors() AS Door, map() AS INTEGER, pass() AS INTEGER, gmap() AS INTEGER, tilesets() AS TilesetData ptr)
 DIM ulim(4) AS INTEGER, llim(4) AS INTEGER
 ulim(0) = 99: llim(0) = -1
 ulim(1) = 99: llim(1) = 0
 ulim(2) = gen(genMaxMap): llim(2) = 0
 ulim(3) = 999: llim(3) = -999
 ulim(4) = 999: llim(4) = -999

 DIM menu(-1 TO 4) AS STRING
 menu(-1) = "Go Back"
 menu(0) = "Entrance Door"
 menu(1) = "Exit Door"
 menu(2) = "Exit Map"
 menu(3) = "Require Tag"
 menu(4) = "Require Tag"
 
 DIM state AS MenuState
 state.pt = -1
 state.top = -1
 state.size = 22
 state.first = LBOUND(menu)
 state.last = UBOUND(menu)
 
 DIM preview_delay AS INTEGER = 0
 DIM outmap AS STRING
 outmap = getmapname$(link(linknum).dest_map)
 DIM menu_temp AS STRING
 DIM col AS INTEGER

 DrawDoorPair mapnum, linknum, map(), pass(), tilesets(), doors(), link(), gmap()

 setkeys
 DO
  setwait 55
  setkeys
  state.tog = state.tog XOR 1
  IF preview_delay > 0 THEN
   preview_delay -= 1
   IF preview_delay = 0 THEN DrawDoorPair mapnum, linknum, map(), pass(), tilesets(), doors(), link(), gmap()
  END IF
  IF keyval(1) > 1 THEN EXIT DO
  usemenu state
  IF state.pt >= 0 THEN
   SELECT CASE state.pt
    CASE 0
     IF intgrabber(link(linknum).source, llim(state.pt), ulim(state.pt)) THEN preview_delay = 3
    CASE 1
     IF intgrabber(link(linknum).dest, llim(state.pt), ulim(state.pt)) THEN preview_delay = 3
    CASE 2
     IF intgrabber(link(linknum).dest_map, llim(state.pt), ulim(state.pt)) THEN
      preview_delay = 3
      outmap = getmapname$(link(linknum).dest_map)
     END IF
    CASE 3
     tag_grabber link(linknum).tag1
    CASE 4
     tag_grabber link(linknum).tag2
    CASE ELSE
     '...
   END SELECT
  ELSE
   IF enter_or_space() THEN EXIT DO
  END IF
  rectangle 0, 100, 320, 2, uilook(uiSelectedDisabled + state.tog), dpage
  FOR i = -1 TO 4
   menu_temp = ""
   SELECT CASE i
    CASE 0
     IF link(linknum).source >= 0 THEN
      menu_temp = STR(link(linknum).source)
     ELSE
      menu_temp = "Unused"
     END IF
    CASE 1
     menu_temp = STR(link(linknum).dest)
    CASE 2
     menu_temp = STR(link(linknum).dest_map)
    CASE 3
     menu_temp = tag_condition_caption(link(linknum).tag1, "", "No Tag Check")
    CASE 4
     menu_temp = tag_condition_caption(link(linknum).tag2, "", "No Tag Check")
   END SELECT
   col = uilook(uiMenuItem)
   IF state.pt = i THEN col = uilook(uiSelectedItem + state.tog)
   edgeprint menu(i) & " " & menu_temp, 1, 1 + (i + 1) * 10, col, dpage
  NEXT i
  edgeprint "ENTER", 275, 0, uilook(uiText), dpage
  edgeprint "EXIT", 283, 190, uilook(uiText), dpage
  edgeprint outmap, 0, 190, uilook(uiText), dpage
  SWAP vpage, dpage
  setvispage vpage
  copypage 2, dpage
  dowait
 LOOP
END SUB

FUNCTION find_last_used_doorlink(link() AS DoorLink) AS INTEGER
 DIM i AS INTEGER
 FOR i = UBOUND(link) TO 0 STEP -1
  IF link(i).source >= 0 THEN RETURN i
 NEXT i
 RETURN -1
END FUNCTION

Function LayerIsVisible(vis() as integer, byval l as integer) as integer
	'debug "layer #" & l & " is: " & readbit(vis(), 0, l)
	return readbit(vis(), 0, l)
end function

Function LayerIsEnabled(gmap() as integer, byval l as integer) as integer
	if l <= 0 then return 1
	'debug "layer #" & l & " is: " & readbit(gmap(), 19, l-1)
	return readbit(gmap(), 19, l-1)
end function

Sub SetLayerVisible(vis() as integer, byval l as integer, byval v as integer)
	setbit(vis(), 0, l, v)
end sub

Sub SetLayerEnabled(gmap() as integer, byval l as integer, byval v as integer)
	if l <= 0 then exit sub
	setbit(gmap(), 19, l-1 ,v)
end sub

Sub ToggleLayerVisible(vis() as integer, byval l as integer)
	setbit(vis(), 0, l, readbit(vis(), 0, l) xor 1)
end sub

Sub ToggleLayerEnabled(gmap() as integer, byval l as integer)
	if l <= 0 then exit sub
	setbit(gmap(), 19, l - 1, readbit(gmap(), 19, l-1) xor 1)
end sub

SUB DrawDoorPair(curmap as integer, cur as integer, map(), pass(), tilesets() as TilesetData ptr, doors() as door, link() as doorlink, gmap())
 DIM as integer dmx, dmy, i
 DIM caption$
 DIM destdoor(99) as door
 DIM gmap2(dimbinsize(4))
' DIM othertilesets(2) as TilesetData ptr
 
 clearpage 2
 IF link(cur).source = -1 THEN EXIT SUB

 setmapdata map(), pass(), 0, 101
 IF readbit(doors(link(cur).source).bits(),0,0) = 1 THEN
  dmx = doors(link(cur).source).x * 20 - 150
  dmy = doors(link(cur).source).y * 20 - 65
  dmx = small(large(dmx, 0), map(0) * 20 - 320)
  dmy = small(large(dmy, 0), map(1) * 20 - 100)
  FOR i = 0 to 2
   IF LayerIsEnabled(gmap(), i) THEN
     drawmap dmx, dmy, i, 0, tilesets(i), 2, i <> 0
   END IF
  NEXT i
  IF LayerIsEnabled(gmap(), 0) THEN
   drawmap dmx, dmy, 0, 2, tilesets(0), 2, 0
  END IF
  edgebox doors(link(cur).source).x * 20 - dmx, doors(link(cur).source).y * 20 - dmy - 20, 20, 20, uilook(uiMenuItem), uilook(uiBackground), 2
  textcolor uilook(uiBackground), 0
  caption$ = XSTR$(link(cur).source)
  printstr caption$, doors(link(cur).source).x * 20 - dmx + 10 - (4 * LEN(caption$)), doors(link(cur).source).y * 20 - dmy - 14, 2
 END IF
 '-----------------EXIT DOOR
 destmap = link(cur).dest_map
 loadrecord gmap2(), game + ".map", dimbinsize(binMAP), destmap
 deserdoors game + ".dox", destdoor(), destmap
 LoadTiledata maplumpname$(destmap, "t"), map(), 3
 LoadTiledata maplumpname$(destmap, "p"), pass()
' loadmaptilesets othertilesets(), gmap2()
 loadmaptilesets tilesets(), gmap2()

 setmapdata map(), pass(), 101, 0
 IF readbit(destdoor(link(cur).dest).bits(),0,0) = 1 THEN
  dmx = destdoor(link(cur).dest).x * 20 - 150
  dmy = destdoor(link(cur).dest).y * 20 - 65
  dmx = small(large(dmx, 0), map(0) * 20 - 320)
  dmy = small(large(dmy, 0), map(1) * 20 - 100)
  FOR i = 0 TO 2
   IF LayerIsEnabled(gmap2(), i) THEN
     drawmap dmx, dmy - 100, i, 0, tilesets(i), 2, i <> 0
   END IF
  NEXT i
  IF LayerIsEnabled(gmap2(), 0) THEN
   drawmap dmx, dmy - 100, 0, 2, tilesets(0), 2, 0
  END IF
  edgebox destdoor(link(cur).dest).x * 20 - dmx, destdoor(link(cur).dest).y * 20 - dmy + 80, 20, 20, uilook(uiMenuItem), uilook(uiBackground), 2
  textcolor uilook(uiBackground), 0
  caption$ = XSTR$(link(cur).dest)
  printstr caption$, destdoor(link(cur).dest).x * 20 - dmx + 10 - (4 * LEN(caption$)), destdoor(link(cur).dest).y * 20 - dmy + 86, 2
 END IF
 '-----------------RESET DATA
 LoadTiledata maplumpname$(curmap, "t"), map(), 3
 LoadTiledata maplumpname$(curmap, "p"), pass()
 loadmaptilesets tilesets(), gmap()
END SUB

SUB calculatepassblock(x AS INTEGER, y AS INTEGER, map() AS INTEGER, pass() AS INTEGER, defaults() AS DefArray, tilesets() AS TilesetData ptr)
 setmapdata map(), pass(), 0, 0
 n = 0
 FOR i = 0 TO 2
  tilenum = readmapblock(x, y, i)
  IF i = 0 OR tilenum > 0 THEN
   n = n OR defaults(i).a(animadjust(tilenum, tilesets(i)->tastuf()))
  END IF
 NEXT i
 setpassblock x, y, n
END SUB

SUB resizetiledata (array(), x_off, y_off, new_width, new_height, yout, page, layers)
 edgeprint "Resizing Map...", 0, yout * 10, uilook(uiText), page
 yout += 1
 setvispage page
' debug "sizemar"
' debug "old_width = " & old_width & ", " & _
'       "old_height = " & old_height & ", " & _
'       "old_x = " & old_x & ", " & _
'       "old_y = " & old_y & ", " & _
'       "new_width = " & new_width & ", " & _
'       "new_height = " & new_height

 dim as integer tmp(ubound(array)), i, x, y

 memcpy (@tmp(0), @array(0), sizeof(integer) * (ubound(array) + 1))  'why doesn't sizeof work on arrays?!
 cleantiledata array(), new_width, new_height, layers
 
 for i = 0 to layers - 1
	for x = large(x_off, 0) to small(tmp(0), new_width + x_off) - 1
		for y = large(y_off, 0) to small(tmp(1), new_height + y_off) - 1
			'newarray(i * newsize + (x - tempx) * tempw + (y - tempy) + 2) = tmp(i * oldsize + x * wide + y + 2)
			'this'll be fixed when the tile data format is fixed, of course	
			setmapdata tmp(), tmp(), 20, 0
			j = readmapblock(x,y,i)
			setmapdata array(), array(), 20, 0
			setmapblock(x - x_off,y - y_off,i,j)
		next
	next
 next
END SUB

SUB resizemapmenu (map(), tilesets() as TilesetData ptr, byref tempw, byref temph, byref tempx, byref tempy)
 'returns the new size and offset in passed args, or -1 width to cancel
REDIM minimap(0,0) AS UBYTE
DIM menu$(6), tog, csr = 1, zoom = 0
wide = map(0)
high = map(1)
tempw = wide
temph = high
tempx = 0
tempy = 0
setmapdata map(), map(), 20, 0
resize_rezoom_mini_map zoom, wide, high, tempx, tempy, tempw, temph, minimap(), map(), tilesets()
GOSUB buildmenu
setkeys
DO
 setwait 55
 setkeys
 tog = tog xor 1
 IF keyval(1) > 1 THEN EXIT DO
 usemenu csr, 0, 0, 4, 10
 IF keyval(56) > 0 THEN incval = 8 ELSE incval = 1
 SELECT CASE csr
  CASE 0
   IF keyval(28) > 1 THEN EXIT DO
  CASE 1
   IF keyval(75) > 0 THEN tempw -= incval 
   IF keyval(77) > 0 THEN tempw += incval
   GOSUB correctw
  CASE 2
   IF keyval(75) > 0 THEN temph -= incval 
   IF keyval(77) > 0 THEN temph += incval
   GOSUB correcth
  CASE 3
   IF keyval(75) > 0 THEN tempx -= incval: tempw += incval
   IF keyval(77) > 0 THEN tempx += incval: tempw -= incval
   GOSUB correctw
  CASE 4
   IF keyval(75) > 0 THEN tempy -= incval: temph += incval
   IF keyval(77) > 0 THEN tempy += incval: temph -= incval
   GOSUB correcth
 END SELECT
 IF keyval(28) > 1 THEN EXIT SUB

 clearpage dpage
 drawoffx = large(0, -tempx * zoom)
 drawoffy = large(0, -tempy * zoom)
 FOR i = 0 TO UBOUND(minimap, 1) - 1
  FOR j = 0 TO UBOUND(minimap, 2) - 1
   putpixel drawoffx + i, drawoffy + j, minimap(i, j), dpage
  NEXT
 NEXT
 standardmenu menu$(), UBOUND(menu$), 28, csr, 0, 0, 140, dpage, YES
 drawbox drawoffx + zoom * tempx, drawoffy + zoom * tempy, zoom * tempw, zoom * temph, 14 + tog, dpage

 SWAP dpage, vpage
 setvispage vpage
 dowait
LOOP
'cancel
tempw = -1
temph = -1
EXIT SUB

correctw:
tempw = bound(tempw, 16, 32000)
tempx = bound(tempx, -tempw + 1, wide - 1)
WHILE temph * tempw > 32000 AND temph > 10
 temph -= 1
WEND
GOTO dimchange

correcth:
temph = bound(temph, 10, 32000)
tempy = bound(tempy, -temph + 1, high - 1)
WHILE temph * tempw > 32000 AND tempw > 16
 tempw -= 1
WEND
GOTO dimchange

dimchange:
WHILE temph * tempw > 32000
 temph = large(temph - 1, 10)
 tempw = large(tempw - 1, 16)
WEND
resize_rezoom_mini_map zoom, wide, high, tempx, tempy, tempw, temph, minimap(), map(), tilesets()

buildmenu:
menu$(0) = "Cancel"
menu$(1) = "Width " & wide & CHR$(26) & tempw
menu$(2) = "Height " & high & CHR$(26) & temph
IF tempx > 0 THEN
 menu$(3) = "Left edge: trim " & tempx & " tiles"
ELSE
 menu$(3) = "Left edge: add " & -tempx & " tiles"
END IF
IF tempy > 0 THEN
 menu$(4) = "Top edge: trim " & tempy & " tiles"
ELSE
 menu$(4) = "Top edge: add " & -tempy & " tiles"
END IF
menu$(5) = "Area " & (wide * high) & CHR$(26) & (temph * tempw)
menu$(6) = zoom & "x zoom"
RETRACE

END SUB

SUB resize_rezoom_mini_map(BYREF zoom AS INTEGER, wide AS INTEGER, high AS INTEGER, tempx AS INTEGER, tempy AS INTEGER, tempw AS INTEGER, temph AS INTEGER, minimap() AS UBYTE, map() AS INTEGER, tilesets() AS TilesetData ptr)
 DIM lastzoom AS INTEGER
 lastzoom = zoom
 DIM AS INTEGER tw, th
 tw = large(wide, tempx + tempw) 'right most point
 IF tempx < 0 THEN tw -= tempx   'plus left most
 th = large(high, tempy + temph)
 IF tempy < 0 THEN th -= tempy
 zoom = bound(small(320 \ tw, 200 \ th), 1, 20)
 IF zoom <> lastzoom THEN
  createminimap minimap(), map(), tilesets(), zoom
 END IF
END SUB

SUB show_minimap(map() AS INTEGER, tilesets() AS TilesetData ptr)
 REDIM minimap(0,0) AS UBYTE
 createminimap minimap(), map(), tilesets()

 clearpage vpage
 DIM AS INTEGER i, j
 FOR i = 0 TO UBOUND(minimap, 1) - 1
  FOR j = 0 TO UBOUND(minimap, 2) - 1
   putpixel i, j, minimap(i, j), vpage
  NEXT
 NEXT

 edgeprint "Press Any Key", 0, 180, uilook(uiText), vpage
 setvispage vpage
 waitforanykey
END SUB

SUB make_top_map_menu(maptop, topmenu$())
DIM i AS INTEGER
FOR i = 0 TO 24
 SELECT CASE maptop + i
  CASE 0
   topmenu$(i) = "Return to Main Menu"
  CASE 1 TO gen(genMaxMap) + 1
   topmenu$(i) = "Map " + filenum$((maptop + i) - 1) + ": " + getmapname$((maptop + i) - 1)
  CASE gen(genMaxMap) + 2
   topmenu$(i) = "Add a New Map"
  CASE ELSE
   topmenu$(i) = ""
 END SELECT
NEXT i
END SUB

'recursively iterate through all contiguous maptiles, changing if the area continues, and stopping if it is blocked by a different kind of maptile
SUB paint_map_area(oldTile, x, y, layer, usetile(), map(), pass(), defaults() AS DefArray, tilesets(), defpass)
IF (y < map(1)) AND (y >= 0) AND (x < map(0)) AND (x >= 0) AND (oldTile = readmapblock(x, y, layer)) AND (oldTile <> usetile(layer)) THEN
 setmapblock x, y, layer, usetile(layer)
 IF defpass THEN calculatepassblock x, y, map(), pass(), defaults(), tilesets()
 
 paint_map_area oldTile, x + 1, y, layer, usetile(), map(), pass(), defaults(), tilesets(), defpass
 paint_map_area oldTile, x - 1, y, layer, usetile(), map(), pass(), defaults(), tilesets(), defpass
 paint_map_area oldTile, x, y + 1, layer, usetile(), map(), pass(), defaults(), tilesets(), defpass
 paint_map_area oldTile, x, y - 1, layer, usetile(), map(), pass(), defaults(), tilesets(), defpass
END IF
END SUB
