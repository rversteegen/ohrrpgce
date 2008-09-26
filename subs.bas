'OHRRPGCE CUSTOM - Misc unsorted routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
'$DYNAMIC
DEFINT A-Z
'basic subs and functions

#include "const.bi"
#include "udts.bi"
#include "custom_udts.bi"
#include "scancodes.bi"

DECLARE FUNCTION str2lng& (stri$)
DECLARE FUNCTION str2int% (stri$)
DECLARE FUNCTION filenum$ (n%)
DECLARE SUB clearallpages ()
DECLARE SUB enforceflexbounds (menuoff%(), menutype%(), menulimits%(), recbuf%(), min%(), max%())
DECLARE FUNCTION editflexmenu% (nowindex%, menutype%(), menuoff%(), menulimits%(), datablock%(), mintable%(), maxtable%())
DECLARE SUB updateflexmenu (mpointer%, nowmenu$(), nowdat%(), size%, menu$(), menutype%(), menuoff%(), menulimits%(), datablock%(), caption$(), maxtable%(), recindex%)
DECLARE SUB addcaption (caption$(), indexer%, cap$)
DECLARE SUB testflexmenu ()
DECLARE SUB cropafter (index%, limit%, flushafter%, lump$, bytes%, prompt%)
DECLARE SUB herotags (BYREF hero AS HeroDef)
DECLARE SUB testanimpattern (tastuf%(), taset%)
DECLARE SUB editbitset (array%(), wof%, last%, names() AS STRING)
DECLARE SUB formation ()
DECLARE SUB enemydata ()
DECLARE SUB herodata ()
DECLARE SUB attackdata ()
DECLARE SUB getnames (stat$(), max%)
DECLARE SUB statname ()
DECLARE FUNCTION sublist% (num%, s$())
DECLARE SUB maptile (font%())
DECLARE FUNCTION isStringField(mnu%)
DECLARE FUNCTION scriptbrowse$ (trigger%, triggertype%, scrtype$)
DECLARE FUNCTION scrintgrabber (n%, BYVAL min%, BYVAL max%, BYVAL less%, BYVAL more%, scriptside%, triggertype%)
DECLARE sub formsprite(z() as integer, w() as integer, a() as integer, h() as integer, pal16() as integer, byval csr2 as integer)
DECLARE sub loadform(a() as integer, pt as integer)
DECLARE sub saveform(a() as integer, pt as integer)
DECLARE sub formpics(ename() as string, a() as integer, b() as integer, s() as integer, w() as integer, h() as integer, pal16() as integer)


#include "compat.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "customsubs.bi"
#include "cglobals.bi"

#include "uiconst.bi"
#include "scrconst.bi"

DECLARE SUB setactivemenu (workmenu(), newmenu(), BYREF state AS MenuState)

DECLARE SUB load_item_names (item_strings() AS STRING)
DECLARE FUNCTION item_attack_name(n AS INTEGER) AS STRING
DECLARE SUB generate_item_edit_menu (menu() AS STRING, itembuf() AS INTEGER, csr AS INTEGER, pt AS INTEGER, item_name AS STRING, info_string AS STRING, equip_types() AS STRING)

DECLARE SUB update_hero_appearance_menu(BYREF st AS HeroEditState, menu() AS STRING, her AS HeroDef)
DECLARE SUB update_hero_preview_pics(BYREF st AS HeroEditState, her AS HeroDef)
DECLARE SUB animate_hero_preview(BYREF st AS HeroEditState)
DECLARE SUB clear_hero_preview_pics(BYREF st AS HeroEditState)
DECLARE SUB draw_hero_preview(st AS HeroEditState, her AS HeroDef)
DECLARE SUB hero_appearance_editor(BYREF st AS HeroEditState, BYREF her AS HeroDef)

REM $STATIC

SUB clearallpages

clearpage 0 'this is actually smaller. See, I happened to look at the ASM for
clearpage 1 'the loop that used to be here. It wasn't very optimized. So, I
clearpage 2 'guess the compiler isn't *always* right.
clearpage 3 '~Mike

END SUB

SUB enemydata

'--stat names
DIM names(32) AS STRING, nof(11), elemtype$(2)
elemtype$(0) = readglobalstring$(127, "Weak to", 10)
elemtype$(1) = readglobalstring$(128, "Strong to", 10)
elemtype$(2) = readglobalstring$(129, "Absorbs ", 10)
getnames names(), 32
'--name offsets
nof(0) = 0
nof(1) = 1
nof(2) = 2
nof(3) = 3
nof(4) = 5
nof(5) = 6
nof(6) = 29
nof(7) = 30
nof(8) = 8
nof(9) = 7
nof(10) = 31
nof(11) = 4

'--preview stuff
DIM workpal(7), previewsize(2)
previewsize(0) = 34
previewsize(1) = 50
previewsize(2) = 80

clearallpages
edgebox 219, 99, 82, 82, uilook(uiDisabledItem), uilook(uiMenuItem), 3

'-------------------------------------------------------------------------

'--bitsets
DIM ebit$(62)

FOR i = 0 TO 7
 ebit$(0 + i) = elemtype$(0) & " " & names(17 + i)
 ebit$(8 + i) = elemtype$(1) & " " & names(17 + i)
 ebit$(16 + i) = elemtype$(2) & " " & names(17 + i)
 ebit$(24 + i) = "Is " & names(9 + i)
NEXT i
FOR i = 32 TO 53
 ebit$(i) = "" 'preferable to be blank, so we can hide it
NEXT i
ebit$(54) = "Harmed by Cure"
ebit$(55) = "MP Idiot"
ebit$(56) = "Boss"
ebit$(57) = "Unescapable"
ebit$(58) = "Die Without Boss"
ebit$(59) = "Flee instead of Die"
ebit$(60) = "Untargetable by Enemies"
ebit$(61) = "Untargetable by Heros"
ebit$(62) = "Win battle even if alive"

'-------------------------------------------------------------------------

'--record buffer
DIM recbuf(160)

CONST EnDatName = 0' to 16
CONST EnDatStealAvail = 17
CONST EnDatStealItem = 18
CONST EnDatStealItemP = 19
CONST EnDatStealRItem = 20
CONST EnDatStealRItemP = 21
CONST EnDatDissolve = 22
CONST EnDatDissolveTime = 23
CONST EnDatDeathSFX = 24
'25 to 52 unused
CONST EnDatPic = 53
CONST EnDatPal = 54
CONST EnDatPicSize = 55
CONST EnDatGold = 56
CONST EnDatExp = 57
CONST EnDatItem = 58
CONST EnDatItemP = 59
CONST EnDatRareItem = 60
CONST EnDatRareItemP = 61
CONST EnDatStat = 62' to 73
CONST EnDatBitset = 74' to 78
CONST EnDatSpawnDeath = 79
CONST EnDatSpawnNEDeath = 80
CONST EnDatSpawnAlone = 81
CONST EnDatSpawnNEHit = 82
CONST EnDatSpawnElement = 83' to 90
CONST EnDatSpawnNum = 91
CONST EnDatAtkNormal = 92' to 96
CONST EnDatAtkDesp = 97'   to 101
CONST EnDatAtkAlone = 102' to 106
'107 to 114 unimplemented elemental triggers
'115 to 158 unused

'-------------------------------------------------------------------------

capindex = 0
DIM caption$(10)
DIM max(26), min(26)
'Limit 0 is not used

CONST EnLimPic = 1
max(EnLimPic) = gen(27) 'or 28 or 29. Must be updated!

CONST EnLimUInt = 2
max(EnLimUInt) = 32767

CONST EnLimPicSize = 3
max(EnLimPicSize) = 2
EnCapPicSize = capindex
addcaption caption$(), capindex, "Small 34x34"
addcaption caption$(), capindex, "Medium 50x50"
addcaption caption$(), capindex, "Big 80x80"

CONST EnLimItem = 4
max(EnLimItem) = gen(genMaxItem)

CONST EnLimPercent = 5
max(EnLimPercent) = 100

CONST EnLimStat = 6' to 17
FOR i = 0 TO 1:  max(EnLimStat + i) = 32767: NEXT i ' HP and MP
FOR i = 2 TO 8:  max(EnLimStat + i) = 999:   NEXT i ' regular stats
FOR i = 9 TO 10: max(EnLimStat + i) = 100:   NEXT i ' focus, counter
max(EnLimStat + 11) = 10        ' max hits

CONST EnLimSpawn = 18
max(EnLimSpawn) = gen(36) + 1 'must be updated!

CONST EnLimSpawnNum = 19
max(EnLimSpawnNum) = 8

CONST EnLimAtk = 20
max(EnLimAtk) = gen(34) + 1

CONST EnLimStr16 = 21
max(EnLimStr16) = 16

CONST EnLimStealAvail = 22
min(EnLimStealAvail) = -1
max(EnLimStealAvail) = 1
addcaption caption$(), capindex, "Disabled"
EnCapStealAvail = capindex
addcaption caption$(), capindex, "Only one"
addcaption caption$(), capindex, "Unlimited"

CONST EnLimPal16 = 23
max(EnLimPal16) = 32767
min(EnLimPal16) = -1

CONST EnLimDissolve = 24
min(EnLimDissolve) = 0
max(EnLimDissolve) = 4
EnCapDissolve = capindex
addcaption caption$(), capindex, "Global Default"
addcaption caption$(), capindex, "Default"
addcaption caption$(), capindex, "Crossfade"
addcaption caption$(), capindex, "Diagonal vanish"
addcaption caption$(), capindex, "Sink into ground"

CONST EnLimDissolveTime = 25
min(EnLimDissolveTime) = 0
max(EnLimDissolveTime) = 99

CONST EnLimDeathSFX = 26
min(EnLimDeathSFX) = -1
max(EnLimDeathSFX) = gen(genMaxSFX) + 1

'--next limit 27, remeber to update dim!

'-------------------------------------------------------------------------
'--menu content
DIM menu$(66), menutype(66), menuoff(66), menulimits(66)

CONST EnMenuBackAct = 0
menu$(EnMenuBackAct) = "Previous Menu"
menutype(EnMenuBackAct) = 1

CONST EnMenuChooseAct = 1
menu$(EnMenuChooseAct) = "Enemy"
menutype(EnMenuChooseAct) = 5

CONST EnMenuName = 2
menu$(EnMenuName) = "Name:"
menutype(EnMenuName) = 4
menuoff(EnMenuName) = EnDatName
menulimits(EnMenuName) = EnLimStr16

CONST EnMenuAppearAct = 3
menu$(EnMenuAppearAct) = "Appearance..."
menutype(EnMenuAppearAct) = 1

CONST EnMenuRewardAct = 4
menu$(EnMenuRewardAct) = "Rewards..."
menutype(EnMenuRewardAct) = 1

CONST EnMenuStatAct = 5
menu$(EnMenuStatAct) = "Stats..."
menutype(EnMenuStatAct) = 1

CONST EnMenuBitsetAct = 6
menu$(EnMenuBitsetAct) = "Bitsets..."
menutype(EnMenuBitsetAct) = 1

CONST EnMenuSpawnAct = 7
menu$(EnMenuSpawnAct) = "Spawning..."
menutype(EnMenuSpawnAct) = 1

CONST EnMenuAtkAct = 8
menu$(EnMenuAtkAct) = "Attacks..."
menutype(EnMenuAtkAct) = 1

CONST EnMenuPic = 9
menu$(EnMenuPic) = "Picture:"
menutype(EnMenuPic) = 0
menuoff(EnMenuPic) = EnDatPic
menulimits(EnMenuPic) = EnLimPic

CONST EnMenuPal = 10
menu$(EnMenuPal) = "Palette:"
menutype(EnMenuPal) = 12
menuoff(EnMenuPal) = EnDatPal
menulimits(EnMenuPal) = EnLimPal16

CONST EnMenuPicSize = 11
menu$(EnMenuPicSize) = "Picture Size:"
menutype(EnMenuPicSize) = 2000 + EnCapPicSize
menuoff(EnMenuPicSize) = EnDatPicSize
menulimits(EnMenuPicSize) = EnLimPicSize

CONST EnMenuGold = 12
menu$(EnMenuGold) = "Gold:"
menutype(EnMenuGold) = 0
menuoff(EnMenuGold) = EnDatGold
menulimits(EnMenuGold) = EnLimUInt

CONST EnMenuExp = 13
menu$(EnMenuExp) = "Experience Points:"
menutype(EnMenuExp) = 0
menuoff(EnMenuExp) = EnDatExp
menulimits(EnMenuExp) = EnLimUInt

CONST EnMenuItem = 14
menu$(EnMenuItem) = "Item:"
menutype(EnMenuItem) = 8
menuoff(EnMenuItem) = EnDatItem
menulimits(EnMenuItem) = EnLimItem

CONST EnMenuItemP = 15
menu$(EnMenuItemP) = "Item%:"
menutype(EnMenuItemP) = 0
menuoff(EnMenuItemP) = EnDatItemP
menulimits(EnMenuItemP) = EnLimPercent

CONST EnMenuRareItem = 16
menu$(EnMenuRareItem) = "Rare Item:"
menutype(EnMenuRareItem) = 8
menuoff(EnMenuRareItem) = EnDatRareItem
menulimits(EnMenuRareItem) = EnLimItem

CONST EnMenuRareItemP = 17
menu$(EnMenuRareItemP) = "Rare Item%:"
menutype(EnMenuRareItemP) = 0
menuoff(EnMenuRareItemP) = EnDatRareItemP
menulimits(EnMenuRareItemP) = EnLimPercent

CONST EnMenuStat = 18' to 29
FOR i = 0 TO 11
 menu$(EnMenuStat + i) = names(nof(i)) & ":"
 menutype(EnMenuStat + i) = 0
 menuoff(EnMenuStat + i) = EnDatStat + i
 menulimits(EnMenuStat + i) = EnLimStat + i
NEXT i
menutype(EnMenuStat + 8) = 15 'Speed should show turn-time estimate

CONST EnMenuSpawnDeath = 30
menu$(EnMenuSpawnDeath) = "Spawn on Death:"
menutype(EnMenuSpawnDeath) = 9
menuoff(EnMenuSpawnDeath) = EnDatSpawnDeath
menulimits(EnMenuSpawnDeath) = EnLimSpawn

CONST EnMenuSpawnNEDeath = 31
menu$(EnMenuSpawnNEDeath) = "on Non-Elemental Death:"
menutype(EnMenuSpawnNEDeath) = 9
menuoff(EnMenuSpawnNEDeath) = EnDatSpawnNEDeath
menulimits(EnMenuSpawnNEDeath) = EnLimSpawn

CONST EnMenuSpawnAlone = 32
menu$(EnMenuSpawnAlone) = "Spawn When Alone:"
menutype(EnMenuSpawnAlone) = 9
menuoff(EnMenuSpawnAlone) = EnDatSpawnAlone
menulimits(EnMenuSpawnAlone) = EnLimSpawn

CONST EnMenuSpawnNEHit = 33
menu$(EnMenuSpawnNEHit) = "on Non-Elemental Hit:"
menutype(EnMenuSpawnNEHit) = 9
menuoff(EnMenuSpawnNEHit) = EnDatSpawnNEHit
menulimits(EnMenuSpawnNEHit) = EnLimSpawn

CONST EnMenuSpawnElement = 34' to 41
FOR i = 0 TO 7
 menu$(EnMenuSpawnElement + i) = "on " + names(17 + i) + " Hit:"
 menutype(EnMenuSpawnElement + i) = 9
 menuoff(EnMenuSpawnElement + i) = EnDatSpawnElement + i
 menulimits(EnMenuSpawnElement + i) = EnLimSpawn
NEXT i

CONST EnMenuSpawnNum = 42
menu$(EnMenuSpawnNum) = "How Many to Spawn:"
menutype(EnMenuSpawnNum) = 0
menuoff(EnMenuSpawnNum) = EnDatSpawnNum
menulimits(EnMenuSpawnNum) = EnLimSpawnNum

CONST EnMenuAtkNormal = 43' to 47
FOR i = 0 TO 4
 menu$(EnMenuAtkNormal + i) = "Normal:"
 menutype(EnMenuAtkNormal + i) = 7
 menuoff(EnMenuAtkNormal + i) = EnDatAtkNormal + i
 menulimits(EnMenuAtkNormal + i) = EnLimAtk
NEXT i

CONST EnMenuAtkDesp = 48' to 52
FOR i = 0 TO 4
 menu$(EnMenuAtkDesp + i) = "Desperation:"
 menutype(EnMenuAtkDesp + i) = 7
 menuoff(EnMenuAtkDesp + i) = EnDatAtkDesp + i
 menulimits(EnMenuAtkDesp + i) = EnLimAtk
NEXT i

CONST EnMenuAtkAlone = 53' to 57
FOR i = 0 TO 4
 menu$(EnMenuAtkAlone + i) = "Alone:"
 menutype(EnMenuAtkAlone + i) = 7
 menuoff(EnMenuAtkAlone + i) = EnDatAtkAlone + i
 menulimits(EnMenuAtkAlone + i) = EnLimAtk
NEXT i

CONST EnMenuStealItem = 58
menu$(EnMenuStealItem) = "Stealable Item:"
menutype(EnMenuStealItem) = 8
menuoff(EnMenuStealItem) = EnDatStealItem
menulimits(EnMenuStealItem) = EnLimItem

CONST EnMenuStealRItem = 59
menu$(EnMenuStealRItem) = "Rare Stealable Item:"
menutype(EnMenuStealRItem) = 8
menuoff(EnMenuStealRItem) = EnDatStealRItem
menulimits(EnMenuStealRItem) = EnLimItem

CONST EnMenuStealItemP = 60
menu$(EnMenuStealItemP) = "Steal Rate%:"
menutype(EnMenuStealItemP) = 0
menuoff(EnMenuStealItemP) = EnDatStealItemP
menulimits(EnMenuStealItemP) = EnLimPercent

CONST EnMenuStealRItemP = 61
menu$(EnMenuStealRItemP) = "Rare Steal Rate%:"
menutype(EnMenuStealRItemP) = 0
menuoff(EnMenuStealRItemP) = EnDatStealRItemP
menulimits(EnMenuStealRItemP) = EnLimPercent

CONST EnMenuStealAvail = 62
menu$(EnMenuStealAvail) = "Steal Availability:"
menutype(EnMenuStealAvail) = 2000 + EnCapStealAvail
menuoff(EnMenuStealAvail) = EnDatStealAvail
menulimits(EnMenuStealAvail) = EnLimStealAvail

CONST EnMenuDissolve = 63
menu$(EnMenuDissolve) = "Death Animation:"
menutype(EnMenuDissolve) = 2000 + EnCapDissolve
menuoff(EnMenuDissolve) = EnDatDissolve
menulimits(EnMenuDissolve) = EnLimDissolve

CONST EnMenuDissolveTime = 64
menu$(EnMenuDissolveTime) = "Death Animation ticks:"
menutype(EnMenuDissolveTime) = 13
menuoff(EnMenuDissolveTime) = EnDatDissolveTime
menulimits(EnMenuDissolveTime) = EnLimDissolveTime

CONST EnMenuDeathSFX = 65
menu$(EnMenuDeathSFX) = "Death Sound Effect:"
menutype(EnMenuDeathSFX) = 14
menuoff(EnMenuDeathSFX) = EnDatDeathSFX
menulimits(EnMenuDeathSFX) = EnLimDeathSFX

'-------------------------------------------------------------------------
'--menu structure
DIM workmenu(15), dispmenu$(15)
DIM state AS MenuState
state.size = 22

DIM mainMenu(8)
mainMenu(0) = EnMenuBackAct
mainMenu(1) = EnMenuChooseAct
mainMenu(2) = EnMenuName
mainMenu(3) = EnMenuAppearAct
mainMenu(4) = EnMenuRewardAct
mainMenu(5) = EnMenuStatAct
mainMenu(6) = EnMenuBitsetAct
mainMenu(7) = EnMenuSpawnAct
mainMenu(8) = EnMenuAtkAct

DIM appearMenu(6)
appearMenu(0) = EnMenuBackAct
appearMenu(1) = EnMenuPicSize
appearMenu(2) = EnMenuPic
appearMenu(3) = EnMenuPal
appearMenu(4) = EnMenuDissolve
appearMenu(5) = EnMenuDissolveTime
appearMenu(6) = EnMenuDeathSFX

DIM rewardMenu(11)
rewardMenu(0) = EnMenuBackAct
rewardMenu(1) = EnMenuGold
rewardMenu(2) = EnMenuExp
rewardMenu(3) = EnMenuItem
rewardMenu(4) = EnMenuItemP
rewardMenu(5) = EnMenuRareItem
rewardMenu(6) = EnMenuRareItemP
rewardMenu(7) = EnMenuStealAvail
rewardMenu(8) = EnMenuStealItem
rewardMenu(9) = EnMenuStealItemP
rewardMenu(10) = EnMenuStealRItem
rewardMenu(11) = EnMenuStealRItemP

DIM statMenu(12)
statMenu(0) = EnMenuBackAct
FOR i = 0 TO 11
 statMenu(1 + i) = EnMenuStat + i
NEXT i

DIM spawnMenu(13)
spawnMenu(0) = EnMenuBackAct
spawnMenu(1) = EnMenuSpawnNum
spawnMenu(2) = EnMenuSpawnDeath
spawnMenu(3) = EnMenuSpawnNEDeath
spawnMenu(4) = EnMenuSpawnAlone
spawnMenu(5) = EnMenuSpawnNEHit
FOR i = 0 TO 7
 spawnMenu(6 + i) = EnMenuSpawnElement + i
NEXT i

DIM atkMenu(15)
atkMenu(0) = EnMenuBackAct
FOR i = 0 TO 4
 atkMenu(1 + i) = EnMenuAtkNormal + i
 atkMenu(6 + i) = EnMenuAtkDesp + i
 atkMenu(11 + i) = EnMenuAtkAlone + i
NEXT i

'--default starting menu
setactivemenu workmenu(), mainMenu(), state

menudepth = 0
lastptr = 0
lasttop = 0
recindex = 0

'load data here
GOSUB EnLoadSub

'------------------------------------------------------------------------
'--main loop

setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN     'ESC
  IF menudepth = 1 THEN
   GOSUB EnBackSub
  ELSE
   EXIT DO
  END IF
 END IF

 '--CTRL+BACKSPACE
 IF keyval(29) > 0 AND keyval(14) > 0 THEN
  cropafter recindex, gen(36), 0, game + ".dt1", 320, 1
 END IF

 usemenu state

 IF workmenu(state.pt) = EnMenuChooseAct OR (keyval(56) > 0 and NOT isStringField(menutype(workmenu(state.pt)))) THEN
  lastindex = recindex
  IF keyval(77) > 1 AND recindex = gen(36) AND recindex < 32767 THEN
   '--attempt to add a new set
   '--save current
   saveenemydata recbuf(), lastindex
   '--increment
   recindex = recindex + 1
   '--make sure we really have permission to increment
   IF needaddset(recindex, gen(genMaxEnemy), "enemy") THEN
    flusharray recbuf(), 159, 0
    recbuf(54) = -1 'default palette
    GOSUB EnUpdateMenu
   END IF
  ELSE
   IF intgrabber(recindex, 0, gen(genMaxEnemy)) THEN
    saveenemydata recbuf(), lastindex
    GOSUB EnLoadSub
   END IF
  END IF
 END IF

 IF enter_or_space() THEN
  SELECT CASE workmenu(state.pt)
   CASE EnMenuBackAct
    IF menudepth = 1 THEN
     GOSUB EnBackSub
    ELSE
     EXIT DO
    END IF
   CASE EnMenuAppearAct
    GOSUB EnPushPtrSub
    setactivemenu workmenu(), appearMenu(), state
    GOSUB EnUpdateMenu
   CASE EnMenuRewardAct
    GOSUB EnPushPtrSub
    setactivemenu workmenu(), rewardMenu(), state
    GOSUB EnUpdateMenu
   CASE EnMenuStatAct
    GOSUB EnPushPtrSub
    setactivemenu workmenu(), statMenu(), state
    GOSUB EnUpdateMenu
   CASE EnMenuSpawnAct
    GOSUB EnPushPtrSub
    setactivemenu workmenu(), spawnMenu(), state
    GOSUB EnUpdateMenu
   CASE EnMenuAtkAct
    GOSUB EnPushPtrSub
    setactivemenu workmenu(), atkMenu(), state
    GOSUB EnUpdateMenu
   CASE EnMenuPal
    recbuf(EnDatPal) = pal16browse(recbuf(EnDatPal), recbuf(EnDatPicSize) + 1, recbuf(EnDatPic), 1, previewsize(recbuf(EnDatPicSize)), previewsize(recbuf(EnDatPicSize)))
    GOSUB EnUpdateMenu
   CASE EnMenuBitsetAct
    editbitset recbuf(), EnDatBitset, 62, ebit$()
  END SELECT
 END IF

 IF keyval(56) = 0 or isStringField(menutype(workmenu(state.pt))) THEN 'not pressing ALT, or not allowed to
  IF editflexmenu(workmenu(state.pt), menutype(), menuoff(), menulimits(), recbuf(), min(), max()) THEN
   GOSUB EnUpdateMenu
  END IF
 END IF

 GOSUB EnPreviewSub

 standardmenu dispmenu$(), state, 0, 0, dpage
 IF keyval(56) > 0 THEN 'holding ALT
  tmp$ = readbadbinstring$(recbuf(), EnDatName, 15, 0) & " " & recindex
  textcolor uilook(uiText), uilook(uiHighlight)
  printstr tmp$, 320 - LEN(tmp$) * 8, 0, dpage
 END IF

 SWAP vpage, dpage
 setvispage vpage
 copypage 3, dpage
 dowait
LOOP

'--save what we were last working on
saveenemydata recbuf(), recindex

clearallpages

EXIT SUB

'-----------------------------------------------------------------------

EnUpdateMenu:

'--in case new enemies have been added
max(EnLimSpawn) = gen(36) + 1

'--in case the PicSize has changed
max(EnLimPic) = gen(27 + bound(recbuf(EnDatPicSize), 0, 2))

'--re-enforce bounds, as they might have just changed
enforceflexbounds menuoff(), menutype(), menulimits(), recbuf(), min(), max()

updateflexmenu state.pt, dispmenu$(), workmenu(), state.last, menu$(), menutype(), menuoff(), menulimits(), recbuf(), caption$(), max(), recindex

'--load the picture and palette
setpicstuf buffer(), (previewsize(recbuf(EnDatPicSize)) ^ 2) / 2, 2
loadset game + ".pt" + STR$(1 + recbuf(EnDatPicSize)), recbuf(EnDatPic), 0
getpal16 workpal(), 0, recbuf(EnDatPal), 1 + recbuf(EnDatPicSize), recbuf(EnDatPic)

RETRACE

'-----------------------------------------------------------------------

EnPreviewSub:
loadsprite buffer(), 0, 0, 0, previewsize(recbuf(EnDatPicSize)), previewsize(recbuf(EnDatPicSize)), 2
wardsprite buffer(), 0, workpal(), 0, 260 - previewsize(recbuf(EnDatPicSize)) / 2, 180 - previewsize(recbuf(EnDatPicSize)), dpage
RETRACE

'-----------------------------------------------------------------------

EnBackSub:
setactivemenu workmenu(), mainMenu(), state
menudepth = 0
state.pt = lastptr
state.top = lasttop
GOSUB EnUpdateMenu
RETRACE

'-----------------------------------------------------------------------

EnPushPtrSub:
lastptr = state.pt
lasttop = state.top
menudepth = 1
RETRACE

'-----------------------------------------------------------------------

EnLoadSub:
loadenemydata recbuf(), recindex
GOSUB EnUpdateMenu
RETRACE

'-----------------------------------------------------------------------
END SUB

SUB formation

clearallpages

DIM a(40), b(160), c(24), s(7), w(7), h(7), menu$(10), max(10), min(10), z(7), bmenu$(22), pal16(64)
dim as integer col, csr, bcsr, csr2, csr3, tog, pt, gptr, i, o, movpix

DIM as string ename(7)

menu$(0) = "Return to Main Menu"
menu$(1) = "Edit Individual Formations..."
menu$(2) = "Construct Formation Sets..."
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 usemenu csr, 0, 0, 2, 24
 IF enter_or_space() THEN
  IF csr = 0 THEN EXIT DO
  IF csr = 1 THEN GOSUB editform
  IF csr = 2 THEN GOSUB formsets
 END IF

 standardmenu menu$(), 2, 22, csr, 0, 0, 0, dpage, 0

 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
clearpage 0
clearpage 1
clearpage 2
clearpage 3
EXIT SUB

formsets:
bmenu$(0) = "Previous Menu"
pt = 0
GOSUB loadfset
GOSUB lpreviewform
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN
  GOSUB savefset
  RETRACE
 END IF
 IF usemenu(bcsr, 0, 0, 22, 24) THEN GOSUB lpreviewform
 IF enter_or_space() THEN
  IF bcsr = 0 THEN
   GOSUB savefset
   RETRACE
  END IF
 END IF
 IF bcsr = 1 THEN
  IF keyval(75) > 1 THEN
   GOSUB savefset
   gptr = large(gptr - 1, 0)
   GOSUB loadfset
  END IF
  IF keyval(77) > 1 THEN
   GOSUB savefset
   gptr = small(gptr + 1, 255)
   GOSUB loadfset
  END IF
 END IF
 IF bcsr = 2 THEN intgrabber c(0), 0, 99
 IF bcsr > 2 THEN
  IF zintgrabber(c(bcsr - 2), -1, gen(genMaxFormation)) THEN
   GOSUB lpreviewform
  END IF
  IF pt >= 0 THEN
   '--preview form
   formsprite z(),w(),a(),h(),pal16(),-1
  END IF
 END IF
 bmenu$(1) = CHR(27) & "Formation Set " & (gptr + 1) & CHR(26)
 bmenu$(2) = "Battle Frequency: " & c(0) & " (" & step_estimate(c(0), 60, 100, "-", " steps") & ")"
 FOR i = 3 TO 22
  bmenu$(i) = "Formation " & c(i - 2) - 1
  IF c(i - 2) = 0 THEN bmenu$(i) = "Empty"
 NEXT i

 standardmenu bmenu$(), 22, 22, bcsr, 0, 0, 0, dpage, 1

 SWAP vpage, dpage
 setvispage vpage
 IF bcsr > 2 AND pt >= 0 THEN
  copypage 2, dpage
 ELSE
  clearpage dpage
 END IF
 dowait
LOOP

lpreviewform:
IF bcsr > 2 THEN
 '--have form selected
 pt = c(bcsr - 2) - 1
 IF pt >= 0 THEN
  '--form not empty
  loadform(a(),pt)
  formpics(ename(), a(), b(), s(), w(), h(), pal16())
 END IF
END IF
RETRACE

savefset:
setpicstuf c(), 50, -1
storeset game + ".efs", gptr, 0
RETRACE

loadfset:
setpicstuf c(), 50, -1
loadset game + ".efs", gptr, 0
RETRACE

editform:
'--???  well, you see..
max(1) = gen(genMaxBackdrop) - 1   'genMaxBackdrop is number of backdrops, but is necessary
max(2) = 50
max(3) = 1000
max(4) = gen(genMaxSong) + 1   'genMaxSongs is number of last song, but is optional
pt = 0: csr2 = -6: csr3 = 0
bgwait = 0
bgctr = 0
loadform(a(),pt)
formpics(ename(), a(), b(), s(), w(), h(), pal16())
setkeys

menu$(3) = "Previous Menu"

DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF csr3 = 1 THEN
  '--enemy positioning mode
  IF keyval(1) > 1 OR enter_or_space() THEN setkeys: csr3 = 0
  movpix = 1 + (7 * SGN(keyval(56)))
  IF keyval(72) > 0 AND a(csr2 * 4 + 2) > 0 THEN a(csr2 * 4 + 2) = a(csr2 * 4 + 2) - movpix
  IF keyval(80) > 0 AND a(csr2 * 4 + 2) < 199 - w(csr2) THEN a(csr2 * 4 + 2) = a(csr2 * 4 + 2) + movpix
  IF keyval(75) > 0 AND a(csr2 * 4 + 1) > 0 THEN a(csr2 * 4 + 1) = a(csr2 * 4 + 1) - movpix
  IF keyval(77) > 0 AND a(csr2 * 4 + 1) < 250 - w(csr2) THEN a(csr2 * 4 + 1) = a(csr2 * 4 + 1) + movpix
 END IF
 IF csr3 = 0 THEN
  '--menu mode
  IF keyval(1) > 1 THEN
   saveform(a(),pt)
   RETRACE
  END IF
  IF keyval(29) > 0 AND keyval(14) > 0 THEN cropafter pt, gen(37), 0, game + ".for", 80, 1
  usemenu csr2, -6, -6, 7, 25
  IF enter_or_space() THEN
   IF csr2 = -6 THEN
    saveform(a(),pt)
    RETRACE
   END IF
   IF csr2 >= 0 THEN IF a(csr2 * 4 + 0) > 0 THEN csr3 = 1
  END IF
  IF csr2 = -4 THEN 'background
   IF intgrabber(a(32), 0, max(csr2 + 5)) THEN
    loadpage game + ".mxs", a(32), 2
    bgwait = 0
    bgctr = 0
   END IF
  END IF
  IF csr2 = -3 THEN 'backdrop frames
   IF xintgrabber(a(34), 2, max(csr2 + 5), 0, 0) THEN
    IF bgctr > a(34) THEN
     bgctr = 0
     loadpage game + ".mxs", a(32), 2
    END IF
   END IF
  END IF
  IF csr2 = -2 THEN 'background ticks
   IF intgrabber(a(35), 0, max(csr2 + 5)) THEN
    bgwait = 0
   END IF
  END IF
  IF csr2 = -1 THEN 'formation music
   zintgrabber(a(33), -2, max(csr2 + 5))
  END IF
  IF csr2 = -5 THEN '---SELECT A DIFFERENT FORMATION
   dim as integer remptr = pt
   IF intgrabber(pt, 0, gen(genMaxFormation), 51, 52) THEN
    saveform(a(),remptr)
    loadform(a(),pt)
    formpics(ename(), a(), b(), s(), w(), h(), pal16())
    bgwait = 0
    bgctr = 0
   END IF
   IF keyval(75) > 1 AND pt > 0 THEN
    saveform(a(),pt)
    pt = large(pt - 1, 0)
    loadform(a(),pt)
    formpics(ename(), a(), b(), s(), w(), h(), pal16())
    bgwait = 0
    bgctr = 0
   END IF
   IF keyval(77) > 1 AND pt < 32767 THEN
    saveform(a(),pt)
    pt = pt + 1
    IF needaddset(pt, gen(37), "formation") THEN GOSUB clearformation
    loadform(a(),pt)
    formpics(ename(), a(), b(), s(), w(), h(), pal16())
    bgwait = 0
    bgctr = 0
   END IF
  END IF'--DONE SELECTING DIFFERENT FORMATION
  IF csr2 >= 0 THEN
   oldenemy = a(csr2 * 4)
   IF zintgrabber(a(csr2 * 4 + 0), -1, gen(36)) THEN
    'this would treat the x/y position as being the bottom middle of enemies, but that changing spawning in slots
    'a(csr2 * 4 + 1) += w(csr2) \ 2
    'a(csr2 * 4 + 2) += h(csr2)
    formpics(ename(), a(), b(), s(), w(), h(), pal16())
    'default to middle of field
    IF oldenemy = 0 AND a(csr2 * 4 + 1) = 0 AND a(csr2 * 4 + 2) = 0 THEN
     a(csr2 * 4 + 1) = 70
     a(csr2 * 4 + 2) = 95
    END IF
    'a(csr2 * 4 + 1) -= w(csr2) \ 2
    'a(csr2 * 4 + 2) -= h(csr2)
   END IF
  END IF
 END IF

 IF a(34) > 0 AND a(35) > 0 THEN
  bgwait = (bgwait + 1) MOD a(35)
  IF bgwait = 0 THEN
   bgctr = loopvar(bgctr, 0, a(34), 1)
   loadpage game + ".mxs", (bgctr + a(32)) MOD gen(genMaxBackdrop), 2
  END IF
 END IF
 copypage 2, dpage

 formsprite z(),w(),a(),h(),pal16(),csr2
 FOR i = 0 TO 3
  edgeboxstyle 240 + i * 8, 75 + i * 22, 32, 40, 0, dpage, NO, YES
 NEXT i
 IF csr3 = 0 THEN
  menu$(4) = CHR(27) + "Formation " & pt & CHR(26)
  menu$(5) = "Backdrop: " & a(32)
  IF a(34) = 0 THEN menu$(6) = "Backdrop Animation: none" ELSE menu$(6) = "Backdrop Animation: " & (a(34) + 1) & " frames"
  menu$(7) = " Ticks per Backdrop Frame: " & a(35)
  IF a(34) = 0 THEN menu$(7) = " Ticks per Backdrop Frame: -NA-"
  menu$(8) = "Battle Music:"
  IF a(33) = -1 THEN
    menu$(8) = menu$(8) & " -same music as map-"
  ELSEIF a(33) = 0 THEN
    menu$(8) = menu$(8) & " -silence-"
  ELSEIF a(33) > 0 THEN
    menu$(8) = menu$(8) & " " & (a(33) - 1) & " " & getsongname$(a(33) - 1)
  END IF
  FOR i = 0 TO 5
   col = uilook(uiMenuItem): IF csr2 + 6 = i THEN col = uilook(uiSelectedItem + tog)
   IF i = 4 AND a(34) = 0 THEN col = uilook(uiDisabledItem): IF csr2 + 6 = i THEN col = uilook(uiSelectedDisabled + tog)
   edgeprint menu$(i + 3), 1, 1 + (i * 10), col, dpage
  NEXT i
  FOR i = 0 TO 7
   col = uilook(uiMenuItem): IF csr2 = i THEN col = uilook(uiSelectedItem + tog)
   edgeprint "Enemy:" + ename(i), 1, 61 + (i * 10), col, dpage
  NEXT i
 END IF
 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP

clearformation:
FOR i = 0 TO 40
 a(i) = 0
NEXT i
a(33) = gen(4)
setpicstuf a(), 80, -1
storeset game + ".for", pt, 0
RETRACE

END SUB

sub loadform(a() as integer, pt as integer)
 setpicstuf a(), 80, -1
 loadset game + ".for", pt, 0
 loadpage game + ".mxs", a(32), 2
end sub

sub saveform(a() as integer, pt as integer)
 setpicstuf a(), 80, -1
 storeset game + ".for", pt, 0
end sub

sub formpics(ename() as string, a() as integer, b() as integer, s() as integer, w() as integer, h() as integer, pal16() as integer)
 FOR i as integer = 0 TO 7
  ename(i) = "-EMPTY-"
  IF a(i * 4 + 0) > 0 THEN
   loadenemydata b(), a(i * 4 + 0) - 1
   ename(i) = STR$(a(i * 4 + 0) - 1) + ":"
   FOR o as integer = 1 TO b(0)
    ename(i) = ename(i) + CHR$(b(o))
   NEXT o
   getpal16 pal16(), i, b(54), 1 + b(55), b(53)
   dim as string f
   IF b(55) = 0 THEN s(i) = 578: w(i) = 34: h(i) = 34: f = ".pt1"
   IF b(55) = 1 THEN s(i) = 1250: w(i) = 50: h(i) = 50: f = ".pt2"
   IF b(55) = 2 THEN s(i) = 3200: w(i) = 80: h(i) = 80: f = ".pt3"
   setpicstuf buffer(), s(i), 3
   loadset game + f, b(53), i * 10
  ELSE
   w(i) = 0: h(i) = 0
  END IF
 NEXT i
end sub

SUB formsprite(z() as integer, w() as integer, a() as integer, h() as integer, pal16() as integer, byval csr2 as integer)
 dim as integer insertval, searchval, i
 static flash as integer = 0
 flash = (flash + 1) MOD 256
 FOR i = 0 TO 7
  z(i) = i
 NEXT
 FOR o as integer = 1 TO 7
  insertval = z(o)
  searchval = a(insertval * 4 + 2) + h(insertval)
  FOR i = o - 1 TO 0 STEP -1
   IF searchval < a(z(i) * 4 + 2) + h(z(i)) THEN
    z(i + 1) = z(i)
   ELSE
    EXIT FOR
   END IF
  NEXT
  z(i + 1) = insertval
 NEXT
 FOR i = 0 TO 7
  IF a(z(i) * 4 + 0) > 0 THEN
   loadsprite buffer(), 0, 0, z(i) * 10, w(z(i)), w(z(i)), 3
   drawsprite buffer(), 0, pal16(), 16 * z(i), a(z(i) * 4 + 1), a(z(i) * 4 + 2), dpage
   IF csr2 = z(i) THEN textcolor flash, 0: printstr CHR$(25), a(z(i) * 4 + 1) + (w(z(i)) * .5) - 4, a(z(i) * 4 + 2), dpage
  END IF
 NEXT
END SUB

SUB herodata
DIM names(100) AS STRING, menu$(8), bmenu$(40), max(40), min(40), nof(12), attack$(24), b(40), opt$(10), hbit$(-1 TO 26), hmenu$(4), elemtype$(2)
DIM AS HeroDef her, blankhero
DIM st AS HeroEditState
WITH st
 .preview_walk_direction = 1
 .preview_steps = 0
 .preview_walk_pos.x = 0
 .preview_walk_pos.y = 0
END WITH
hmax = 32
leftkey = 0: rightkey = 0
nof(0) = 0: nof(1) = 1: nof(2) = 2: nof(3) = 3: nof(4) = 5: nof(5) = 6: nof(6) = 29: nof(7) = 30: nof(8) = 8: nof(9) = 7: nof(10) = 31: nof(11) = 4
clearpage 0
clearpage 1
clearpage 2
clearpage 3
getnames names(), hmax
elemtype$(0) = readglobalstring$(127, "Weak to", 10)
elemtype$(1) = readglobalstring$(128, "Strong to", 10)
elemtype$(2) = readglobalstring$(129, "Absorbs ", 10)
st.previewframe = -1

pt = 0
csr = 1
FOR i = 0 TO 7
 hbit$(i) = elemtype$(0) + " " + names(17 + i)
 hbit$(i + 8) = elemtype$(1) + " " + names(17 + i)
 hbit$(i + 16) = elemtype$(2) + " " + names(17 + i)
NEXT i
hbit$(24) = "Rename when added to party"
hbit$(25) = "Permit renaming on status screen"
hbit$(26) = "Do not show spell lists if empty"

menu$(0) = "Return to Main Menu"
menu$(1) = CHR(27) + "Pick Hero " & pt & CHR(26)
menu$(2) = "Name:"
menu$(3) = "Appearance and Misc..."
menu$(4) = "Edit Stats..."
menu$(5) = "Edit Spell Lists..."
menu$(6) = "Name Spell Lists..."
menu$(7) = "Bitsets..."
menu$(8) = "Hero Tags..."
nam$ = ""
GOSUB thishero

setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 animate_hero_preview st
 IF keyval(1) > 1 THEN EXIT DO
 IF keyval(29) > 0 AND keyval(14) > 0 THEN
  cropafter pt, gen(genMaxHero), -1, game + ".dt0", 636, 1
 END IF
 usemenu csr, 0, 0, 8, 24
 IF enter_or_space() THEN
  IF csr = 0 THEN EXIT DO
  IF csr = 3 THEN hero_appearance_editor st, her
  IF csr = 4 THEN GOSUB levstats
  IF csr = 5 THEN GOSUB speltypes '--spell list contents
  IF csr = 6 THEN GOSUB heromenu '--spell list names
  IF csr = 7 THEN editbitset her.bits(), 0, 26, hbit$()
  IF csr = 8 THEN herotags her
 END IF
 IF csr = 1 THEN
  remptr = pt
  IF intgrabber(pt, 0, gen(genMaxHero), 51, 52) THEN
   SWAP pt, remptr
   GOSUB lasthero
   SWAP pt, remptr
   GOSUB thishero
  END IF
  IF keyval(75) > 1 AND pt > 0 THEN
   GOSUB lasthero
   pt = pt - 1
   GOSUB thishero
  END IF
  IF keyval(77) > 1 AND pt < 59 THEN
   GOSUB lasthero
   pt = pt + 1
   IF needaddset(pt, gen(genMaxHero), "hero") THEN GOSUB clearhero
   GOSUB thishero
  END IF
 END IF
 IF csr = 2 THEN
  strgrabber nam$, 16
  menu$(2) = "Name:" + nam$
 END IF

 standardmenu menu$(), 8, 22, csr, 0, 0, 0, dpage, 0

 draw_hero_preview st, her
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
GOSUB lasthero
clear_hero_preview_pics st
clearpage 0
clearpage 1
clearpage 2
clearpage 3
EXIT SUB

heromenu:
bmenu$(0) = "Previous Menu": bctr = 0
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN RETRACE
 IF enter_or_space() AND bctr = 0 THEN RETRACE
 usemenu bctr, 0, 0, 4, 24
 IF bctr > 0 THEN
  strgrabber hmenu$(bctr - 1), 10
 END IF
 bmenu$(1) = "Spell List 1:" + hmenu$(0)
 bmenu$(2) = "Spell List 2:" + hmenu$(1)
 bmenu$(3) = "Spell List 3:" + hmenu$(2)
 bmenu$(4) = "Spell List 4:" + hmenu$(3)

 standardmenu bmenu$(), 4, 22, bctr, 0, 0, 0, dpage, 0

 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP

speltypes:
FOR i = 0 TO 3
 IF her.list_type(i) > 10 OR her.list_type(i) < 0 THEN her.list_type(i) = 0
NEXT i
bctr = -1
opt$(0) = "Spells (MP Based)"
opt$(1) = "Spells (FF1 Style)"
opt$(2) = "Random Effects"
opt$(3) = "Item Consuming (not implemented)"
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN RETRACE
 usemenu bctr, -1, -1, 3, 24
 IF bctr >= 0 THEN intgrabber her.list_type(bctr), 0, 2
 IF enter_or_space() THEN
  IF bctr = -1 THEN RETRACE
  IF bctr >= 0 AND bctr < 4 THEN
   listnum = bctr
   GOSUB spells
   bctr = listnum
  END IF
 END IF
 textcolor uilook(uiMenuItem), 0: IF bctr = -1 THEN textcolor uilook(uiSelectedItem + tog), 0
 printstr "Previous Menu", 0, 0, dpage
 FOR i = 0 TO 3
  textcolor uilook(uiMenuItem), 0: IF bctr = i THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr "Type " & i & " Spells: " & opt$(her.list_type(i)), 0, 8 + i * 8, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP

levstats:
bctr = 0
bmenu$(0) = "Previous Menu"
FOR i = 1 TO 24: min(i) = 0: max(i) = 999: NEXT
FOR i = 1 TO 4: max(i) = 9999: NEXT i
FOR i = 21 TO 22: max(i) = 100: NEXT i
FOR i = 23 TO 24: max(i) = 10: NEXT i
GOSUB smi
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN RETRACE
 IF keyval(72) > 1 THEN bctr = large(bctr - 2, 0)
 IF keyval(80) > 1 AND bctr > 0 THEN bctr = small(bctr + 2, 24)
 IF keyval(80) > 1 AND bctr = 0 THEN bctr = bctr + 1
 IF keyval(75) > 1 AND bctr > 0 THEN bctr = bctr - 1
 IF keyval(77) > 1 AND bctr < 24 THEN bctr = bctr + 1
 IF enter_or_space() AND bctr = 0 THEN RETRACE
 IF bctr > 0 THEN
  changed = 0
  IF (bctr AND 1) = 1 THEN ' odd numbers are level 0
   IF intgrabber(her.Lev0.sta((bctr - 1) \ 2), min(bctr), max(bctr), 51, 52) THEN changed = -1
  ELSE' even numbers are level 99
   IF intgrabber(her.Lev99.sta((bctr - 2) \ 2), min(bctr), max(bctr), 51, 52) THEN changed = -1
  END IF
  IF changed THEN GOSUB smi
 END IF
 textcolor uilook(uiMenuItem), 0
 IF 0 = bctr THEN textcolor uilook(uiSelectedItem + tog), 0
 printstr bmenu$(0), 8, 0, dpage
 textcolor uilook(uiDescription), 0
 printstr "LEVEL ZERO", 8, 12, dpage
 printstr "LEVEL NINETY-NINE", 160, 12, dpage
 FOR i = 0 TO 11
  textcolor uilook(uiMenuItem), 0
  IF 1 + i * 2 = bctr THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr bmenu$(1 + i * 2), 8, 20 + i * 8, dpage
  textcolor uilook(uiMenuItem), 0
  IF 2 + i * 2 = bctr THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr bmenu$(2 + i * 2), 160, 20 + i * 8, dpage
 NEXT i
 IF bctr > 0 THEN GOSUB graph
 IF (bctr - 1) \ 2 = 8 THEN 'Speed
  textcolor uilook(uiDescription), 0
  printstr "Lev0:  1 turn every " & speed_estimate(her.Lev0.spd), 0, 182, dpage
  printstr "Lev99: 1 turn every " & speed_estimate(her.Lev99.spd), 0, 190, dpage
 END IF
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP

spells:
bctr = 0
colcsr = 0
sticky = 0
GOSUB setsticky
FOR o = 1 TO 24
 GOSUB gosubatkname
NEXT o
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF sticky THEN
  IF keyval(1) > 1 THEN sticky = 0: GOSUB setsticky
 ELSE
  IF keyval(1) > 1 THEN RETRACE
  IF usemenu(bctr, 0, 0, 24, 24) THEN
   IF bctr > 0 THEN
    IF her.spell_lists(listnum, bctr-1).attack = 0 THEN colcsr = 0
   ELSE
    colcsr = 0
   END IF
  END IF
  IF keyval(75) > 1 OR keyval(77) > 1 THEN
   colcsr = colcsr XOR 1
   IF bctr > 0 THEN
    IF her.spell_lists(listnum, bctr-1).attack = 0 THEN colcsr = 0
   ELSE
    colcsr = 0
   END IF
  END IF
 END IF
 IF bctr > 0 THEN
  IF colcsr = 0 THEN
   IF zintgrabber(her.spell_lists(listnum, bctr-1).attack, -1, gen(genMaxAttack), leftkey, rightkey) THEN
    o = bctr
    GOSUB gosubatkname
   END IF
  END IF
  IF colcsr = 1 THEN zintgrabber her.spell_lists(listnum, bctr-1).learned, -1, 99, leftkey, rightkey
 END IF
 IF enter_or_space() THEN
  IF bctr = 0 THEN
   '--exit menu
   RETRACE
  ELSE
   '--sticky-typing mode
   sticky = sticky XOR 1
   GOSUB setsticky
  END IF
 END IF
 textcolor uilook(uiDescription), 0: printstr UCASE$(opt$(her.list_type(listnum))), 300 - LEN(opt$(her.list_type(listnum))) * 8, 0, dpage
 textcolor uilook(uiMenuItem), 0: IF bctr = 0 THEN textcolor uilook(uiSelectedItem + tog), 0
 printstr "Previous Menu", 0, 0, dpage
 FOR i = 1 TO 24
  textcolor uilook(uiMenuItem), 0: IF bctr = i THEN textcolor uilook(uiSelectedItem + tog), 0
  temp1$ = attack$(i)
  WITH her.spell_lists(listnum, i-1)
   IF .attack > 0 THEN
    IF .learned = 0 THEN temp2$ = "Learned from Item"
    IF .learned > 0 THEN temp2$ = "Learned at Level" & (.learned - 1)
   ELSE
    temp2$ = ""
   END IF
  END WITH
  textcolor uilook(uiMenuItem), 0: IF bctr = i AND colcsr = 0 THEN textcolor uilook(uiSelectedItem + tog), IIF(sticky, uilook(uiHighlight), 0)
  printstr temp1$, 0, 8 * i, dpage
  textcolor uilook(uiMenuItem), 0: IF bctr = i AND colcsr = 1 THEN textcolor uilook(uiSelectedItem + tog), IIF(sticky, uilook(uiHighlight), 0)
  printstr temp2$, 160, 8 * i, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP

setsticky:
IF sticky THEN
 leftkey = 75
 rightkey = 77
ELSE
 leftkey = 51
 rightkey = 52
END IF
RETRACE

gosubatkname:
WITH her.spell_lists(listnum, o-1)
 IF .attack = 0 THEN
  attack$(o) = "EMPTY"
 ELSE
  attack$(o) = STR$(.attack - 1) + ":" + readattackname$(.attack - 1)
 END IF
END WITH
RETRACE

graph:
o = INT((bctr - 1) / 2)
textcolor uilook(uiMenuItem), 0
printstr names(nof(o)), 310 - LEN(names(nof(o))) * 8, 180, dpage
FOR i = 0 TO 99 STEP 4
 ii = (.8 * i / 50) * i
 n0 = her.Lev0.sta(o)
 n99 = her.Lev99.sta(o)
 ii = ii * ((n99 - n0) / 100) + n0
 ii = large(ii, 0)
 j = (ii) * (100 / max(bctr))
 rectangle 290 + (i / 4), 176 - j, 1, j + 1, uilook(uiMenuItem), dpage
NEXT i
RETRACE

smi:
FOR i = 0 TO 11
 bmenu$(i * 2 + 1) = names(nof(i)) & " " & her.Lev0.sta(i)
 bmenu$(i * 2 + 2) = names(nof(i)) & " " & her.Lev99.sta(i)
NEXT i
RETRACE

clearhero:
blankhero.sprite_pal = -1      'default battle palette
blankhero.walk_sprite_pal = -1 'default walkabout palette
saveherodata @blankhero, pt
RETRACE

lasthero:
her.name = nam$
FOR i = 0 TO 3
 her.list_name(i) = hmenu$(i)
NEXT i
saveherodata @her, pt
RETRACE

thishero:
loadherodata @her, pt
nam$ = her.name
FOR i = 0 TO 3
 hmenu$(i) = her.list_name(i)
NEXT i
menu$(2) = "Name:" + nam$
menu$(1) = CHR(27) + "Pick Hero " & pt & CHR(26)
update_hero_preview_pics st, her
RETRACE

END SUB 'End of herodata

SUB herotags (BYREF hero AS HeroDef)
DIM tagnum AS INTEGER
DIM tagcaption AS STRING
DIM menu$(5)
menu$(0) = "Previous Menu"
menu$(1) = "have hero TAG"
menu$(2) = "is alive TAG"
menu$(3) = "is leader TAG"
menu$(4) = "is in party now TAG"

WITH hero

pt = 0
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 usemenu pt, 0, 0, 4, 24
 SELECT CASE pt
  CASE 0
   IF enter_or_space() THEN EXIT DO
  CASE 1
   tag_grabber .have_tag, 0
  CASE 2
   tag_grabber .alive_tag, 0
  CASE 3
   tag_grabber .leader_tag, 0
  CASE 4
   tag_grabber .active_tag, 0
 END SELECT
 FOR i = 0 TO 4
  textcolor uilook(uiMenuItem), 0
  IF pt = i THEN textcolor uilook(uiSelectedItem + tog), 0
  tagnum = 0
  SELECT CASE i
   CASE 1
    tagnum = .have_tag
   CASE 2
    tagnum = .alive_tag
   CASE 3
    tagnum = .leader_tag
   CASE 4
    tagnum = .active_tag
  END SELECT
  tagcaption = ": "
  SELECT CASE tagnum
   CASE 0
    tagcaption += "None"
   CASE 1
    tagcaption += "None (tag 1 not usable)"
   CASE ELSE
    tagcaption += load_tag_name(tagnum) & "(" & tagnum & ")"
  END SELECT
  IF i = 0 THEN tagcaption = ""
  printstr menu$(i) & tagcaption, 0, i * 8, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
END WITH
EXIT SUB

END SUB

SUB itemdata
DIM names(100) AS STRING, a(99), menu$(20), bmenu$(40), nof(12), b(40), ibit$(-1 TO 59), eqst$(5), max(18), min(18), sbmax(11), elemtype$(2), frame
DIM item$(maxMaxItems)
DIM her AS HeroDef ' This is only used in equipbit
DIM wep_img AS GraphicPair 'This is only used in edititem
imax = 32
nof(0) = 0: nof(1) = 1: nof(2) = 2: nof(3) = 3: nof(4) = 5: nof(5) = 6: nof(6) = 29: nof(7) = 30: nof(8) = 8: nof(9) = 7: nof(10) = 31: nof(11) = 4
clearpage 0
clearpage 1
clearpage 2
clearpage 3
getnames names(), imax
elemtype$(0) = readglobalstring$(127, "Weak to", 10)
elemtype$(1) = readglobalstring$(128, "Strong to", 10)
elemtype$(2) = readglobalstring$(129, "Absorbs ", 10)

eqst$(0) = "NEVER EQUIPPED"
eqst$(1) = "Weapon"
FOR i = 0 TO 3
 eqst$(i + 2) = names(25 + i)
NEXT i
FOR i = 0 TO 1
 sbmax(i) = 9999
NEXT i
FOR i = 2 TO 8
 sbmax(i) = 999
NEXT i
FOR i = 9 TO 10
 sbmax(i) = 100
NEXT i
sbmax(11) = 10

csr = 0: top = -1: pt = 0
DIM caption AS STRING
load_item_names item$()
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 IF keyval(29) > 0 AND keyval(14) > 0 AND csr >= 0 THEN
  cropafter csr, gen(genMaxItem), 0, game + ".itm", 200, 1
  load_item_names item$()
 END IF
 usemenu csr, top, -1, gen(genMaxItem) + 1, 23
 intgrabber csr, -1, gen(genMaxItem) + 1
 IF enter_or_space() THEN
  IF csr = -1 THEN EXIT DO
  IF csr = gen(genMaxItem) + 1 THEN
   IF gen(genMaxItem) < maxMaxItems THEN
    gen(genMaxItem) += 1
    flusharray a(), 99, 0
    saveitemdata a(), csr
   END IF
  END IF
  IF csr <= gen(genMaxItem) THEN
   GOSUB edititem
   saveitemdata a(), csr
   i = csr: GOSUB sitemname
  END IF
 END IF
 FOR i = top TO top + 23
  IF i <= gen(genMaxItem) + 1 THEN
   textcolor uilook(uiMenuItem), 0
   IF i = csr THEN textcolor uilook(uiSelectedItem + tog), 0
   SELECT CASE i
    CASE IS < 0
     caption = "Return to Main Menu"
    CASE IS > gen(genMaxItem)
     IF gen(genMaxItem) < maxMaxItems THEN
      caption = "Add a new item"
     ELSE
      caption = "No more items can be added"
      textcolor uilook(uiDisabledItem), 0
      IF i = csr THEN textcolor uilook(uiSelectedDisabled + tog), 0
     END IF
    CASE ELSE
     caption = i & " " & item$(i)
   END SELECT
   printstr caption, 0, (i - top) * 8, dpage
  END IF
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
EXIT SUB

edititem:
loaditemdata a(), csr
info$ = readbadbinstring$(a(), 9, 35, 0)

menu$(0) = "Back to Item Menu"
menu$(18) = "Stat Bonuses..."
menu$(19) = "Equipment Bits..."
menu$(20) = "Who Can Equip?..."
max(3) = 32767
max(4) = gen(34) + 1
max(5) = gen(34) + 1
max(6) = 5
max(7) = gen(34) + 1
max(8) = gen(34) + 1
max(9) = gen(31)
max(10) = 32767
min(10) = -1
max(11) = 2
max(12) = 999
max(13) = 999
max(14) = 999
max(15) = 999

loaditemdata a(), csr
generate_item_edit_menu menu$(), a(), csr, pt, item$(csr), info$, eqst$()

IF wep_img.sprite THEN sprite_unload @wep_img.sprite
IF wep_img.pal    THEN palette16_unload @wep_img.pal
wep_img.sprite = sprite_load(game & ".pt5", a(52), 2, 24, 24)
wep_img.pal    = palette16_load(game & ".pal", a(53), 5, a(52))

need_update = NO

setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 usemenu pt, 0, 0, 20, 24
 frame = 0
 IF pt = 16 THEN frame = 1
 IF pt = 17 THEN frame = 0
 IF enter_or_space() THEN
  IF pt = 0 THEN EXIT DO
  IF a(49) > 0 THEN
   IF pt = 16 THEN
    xy_position_on_sprite wep_img, a(80), a(81), 0, 24, 24, "weapon handle position"
    need_update = YES
   END IF
   IF pt = 17 THEN
    xy_position_on_sprite wep_img, a(78), a(79), 1, 24, 24, "weapon handle position"
    need_update = YES
   END IF
   IF pt = 18 THEN
    GOSUB statbon
    need_update = YES
   END IF
   IF pt = 19 THEN
    GOSUB ibitset
    need_update = YES
   END IF
   IF pt = 20 THEN
    GOSUB equipbit
    need_update = YES
   END IF
  END IF
  IF pt = 10 THEN '--palette picker
   a(46 + (pt - 3)) = pal16browse(a(53), 5, a(52), 2, 24, 24)
   need_update = YES
  END IF
 END IF
 SELECT CASE pt
  CASE 1
   strgrabber item$(csr), 8
   menu$(1) = "Name:" + item$(csr)
  CASE 2
   strgrabber info$, 34
   menu$(2) = "Info:" + info$
  CASE 3, 6, 9, 10
   IF intgrabber(a(46 + (pt - 3)), min(pt), max(pt)) THEN
    need_update = YES
   END IF
  CASE 4, 5, 7
   IF zintgrabber(a(46 + (pt - 3)), -1, max(pt)) THEN
    need_update = YES
   END IF
  CASE 8
   IF xintgrabber(a(46 + (pt - 3)), 0, max(pt), -1, gen(39) * -1) THEN
    need_update = YES
   END IF
  CASE 11
   IF intgrabber(a(73), 0, 2) THEN
    need_update = YES
   END IF
  CASE 12 TO 15
   IF tag_grabber(a(74 + (pt - 12)), 0) THEN
    need_update = YES
   END IF
 END SELECT
 IF need_update THEN
  need_update = NO
  generate_item_edit_menu menu$(), a(), csr, pt, item$(csr), info$, eqst$()
  IF wep_img.sprite THEN sprite_unload @wep_img.sprite
  IF wep_img.pal    THEN palette16_unload @wep_img.pal
  wep_img.sprite = sprite_load(game & ".pt5", a(52), 2, 24, 24)
  wep_img.pal    = palette16_load(game & ".pal", a(53), 5, a(52))
 END IF
 FOR i = 0 TO 20
  textcolor uilook(uiMenuItem), 0
  IF pt = i THEN textcolor uilook(uiSelectedItem + tog), 0
  IF (i >= 18 AND a(49) = 0) OR ((i = 16 OR i = 17) AND a(49) <> 1) THEN
   textcolor uilook(uiDisabledItem), 0
   IF pt = i THEN textcolor uilook(uiSelectedDisabled + tog), 0
  END IF
  printstr menu$(i), 0, i * 8, dpage
 NEXT i
 IF a(49) = 1 THEN
  sprite_draw wep_img.sprite + 1 - frame, wep_img.pal, 280, 160,,,dpage
  textcolor uilook(uiMenuItem), 0
  drawline 278 + a(78 + frame * 2),160 + a(79 + frame * 2),279 + a(78 + frame * 2), 160 + a(79 + frame * 2),14 + tog,dpage
  drawline 280 + a(78 + frame * 2),158 + a(79 + frame * 2),280 + a(78 + frame * 2), 159 + a(79 + frame * 2),14 + tog,dpage
  drawline 281 + a(78 + frame * 2),160 + a(79 + frame * 2),282 + a(78 + frame * 2), 160 + a(79 + frame * 2),14 + tog,dpage
  drawline 280 + a(78 + frame * 2),161 + a(79 + frame * 2),280 + a(78 + frame * 2), 162 + a(79 + frame * 2),14 + tog,dpage
 END IF
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
IF wep_img.sprite THEN sprite_unload @wep_img.sprite
IF wep_img.pal    THEN palette16_unload @wep_img.pal
RETRACE

statbon:
ptr2 = 0
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN RETRACE
 usemenu ptr2, 0, -1, 11, 24
 IF enter_or_space() THEN
  IF ptr2 = -1 THEN RETRACE
 END IF
 IF ptr2 >= 0 THEN
  intgrabber a(54 + ptr2), sbmax(ptr2) * -1, sbmax(ptr2)
 END IF
 textcolor uilook(uiMenuItem), 0
 IF ptr2 = -1 THEN textcolor uilook(uiSelectedItem + tog), 0
 printstr "Previous Menu", 0, 0, dpage
 FOR i = 0 TO 11
  textcolor uilook(uiMenuItem), 0
  IF ptr2 = i THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr names(nof(i)) + " Bonus: " & a(54 + i), 0, 8 + i * 8, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP

sitemname:
loaditemdata a(), i
a(0) = LEN(item$(i))
FOR o = 1 TO a(0)
 a(o) = ASC(MID$(item$(i), o, 1))
NEXT o
a(9) = LEN(info$)
FOR o = 10 TO 9 + a(9)
 a(o) = ASC(MID$(info$, o - 9, 1))
NEXT o
saveitemdata a(), i
RETRACE

ibitset:
FOR i = 0 TO 7
 ibit$(i) = elemtype$(0) + " " + names(17 + i)
 ibit$(i + 8) = elemtype$(1) + " " + names(17 + i)
 ibit$(i + 16) = elemtype$(2) + " " + names(17 + i)
NEXT i
editbitset a(), 70, 23, ibit$()
RETRACE

equipbit:
'"DIM her AS HeroDef" is only used here but is dimmed at the top of the itemdata sub to avoid branch crossing
FOR i = 0 TO 59
 loadherodata @her, i
 ibit$(i) = "Equipable by " + her.name
NEXT i
editbitset a(), 66, 59, ibit$()
RETRACE

END SUB

SUB generate_item_edit_menu (menu() AS STRING, itembuf() AS INTEGER, csr AS INTEGER, pt AS INTEGER, item_name AS STRING, info_string AS STRING, equip_types() AS STRING)
 menu(1) = "Name:" & item_name
 menu(2) = "Info:" & info_string
 menu(3) = "Value: " & itembuf(46)
 menu(4) = "When used in battle: " & item_attack_name(itembuf(47))
 menu(5) = "When used as a Weapon: " & item_attack_name(itembuf(48))
 menu(6) = "Equippable as: " & equip_types(bound(itembuf(49), 0, 5))
 menu(7) = "Teach Spell: " & item_attack_name(itembuf(50))
 IF itembuf(51) >= 0 THEN
  menu(8) = "When used out of battle: " & item_attack_name(itembuf(51))
 ELSE
  menu(8) = "When used out of battle: Text " & ABS(itembuf(51))
 END IF
 menu(9) = "Weapon Picture: " & itembuf(52)
 menu(10) = "Weapon Palette: " & defaultint$(itembuf(53))
 IF itembuf(49) <> 1 THEN menu(9) = "Weapon Picture: N/A": menu(10) = "Weapon Palette: N/A"
 menu(11) = "Unlimited Use"
 IF itembuf(73) = 1 THEN menu(11) = "Consumed By Use"
 IF itembuf(73) = 2 THEN menu(11) = "Cannot be Sold/Dropped"
 menu(12) = "own item TAG " & itembuf(74) & " " & load_tag_name(itembuf(74))
 menu(13) = "is in inventory TAG " & itembuf(75) & " " & load_tag_name(itembuf(75))
 menu(14) = "is equipped TAG " & itembuf(76) & " " & load_tag_name(itembuf(76))
 menu(15) = "eqpt by active hero TAG " & itembuf(77) & " " & load_tag_name(itembuf(77))
 menu(16) = "Handle position A..."
 menu(17) = "Handle position B..."
 IF itembuf(49) <> 1 THEN
  menu(16) = menu(16) & " N/A"
  menu(17) = menu(17) & " N/A"
 END IF
END SUB'

FUNCTION item_attack_name(n AS INTEGER) AS STRING
 IF n <= 0 THEN RETURN "NOTHING"
 RETURN n - 1 & " " & readattackname$(n - 1)
END FUNCTION

SUB load_item_names (item_strings() AS STRING)
 DIM i AS INTEGER
 FOR i = 0 TO gen(genMaxItem)
  item_strings(i) = load_item_name(i, YES, YES)
 NEXT i
END SUB

SUB npcdef (npc(), npc_img() AS GraphicPair, pt)

DIM boxpreview(max_npc_defs) AS STRING

clearpage 0: clearpage 1
setvispage vpage

csr = 0
cur = 0: top = 0
FOR i = 0 TO max_npc_defs
 boxpreview(i) = textbox_preview_line(npc(i * 15 + 4))
NEXT i
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 usemenu cur, top, 0, max_npc_defs, 7
 IF enter_or_space() THEN
  edit_npc cur, npc()
  '--Having edited the NPC, we must re-load the picture and palette
  WITH npc_img(cur)
   IF .sprite THEN sprite_unload(@.sprite)
   .sprite = sprite_load(game + ".pt4", npc(cur * 15 + 0), 8, 20, 20)
   IF .pal THEN palette16_unload(@.pal)
   .pal = palette16_load(game + ".pal", npc(cur * 15 + 1), 4, npc(cur * 15 + 0))
  END WITH
  '--Update box preview line
  boxpreview(cur) = textbox_preview_line(npc(cur * 15 + 4))
 END IF
 FOR i = top TO top + 7
  IF cur = i THEN edgebox 0, (i - top) * 25, 320, 22, uilook(uiDisabledItem), uilook(uiMenuItem), dpage
  textcolor uilook(uiMenuItem), 0
  IF cur = i THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr "" & i, 0, ((i - top) * 25) + 5, dpage
  WITH npc_img(i)
   sprite_draw .sprite + 4, .pal, 32, (i - top) * 25, 1, -1, dpage
  END WITH
  textcolor uilook(uiMenuItem), uilook(uiHighlight)
  IF cur = i THEN textcolor uilook(uiText), uilook(uiHighlight)
  printstr boxpreview(i), 56, ((i - top) * 25) + 5, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
clearpage 0
clearpage 1
clearpage 2
EXIT SUB

END SUB

SUB stredit (s$, maxl)
STATIC clip$

'--copy support
IF (keyval(29) > 0 AND keyval(82) > 1) OR ((keyval(42) > 0 OR keyval(54) > 0) AND keyval(83) > 0) OR (keyval(29) > 0 AND keyval(46) > 1) THEN clip$ = s$

'--paste support
IF ((keyval(42) > 0 OR keyval(54) > 0) AND keyval(82) > 1) OR (keyval(29) > 0 AND keyval(47) > 1) THEN s$ = LEFT$(clip$, maxl)

'--insert cursor movement
IF keyval(29) = 0 THEN 'not CTRL
 IF keyval(75) > 1 THEN insert = large(0, insert - 1)
 IF keyval(77) > 1 THEN insert = small(LEN(s$), insert + 1)
ELSE 'CTRL
 IF keyval(75) > 1 THEN insert = 0
 IF keyval(77) > 1 THEN insert = LEN(s$)
END IF

IF insert < 0 THEN insert = LEN(s$)
insert = bound(insert, 0, LEN(s$))

pre$ = LEFT$(s$, insert)
post$ = RIGHT$(s$, LEN(s$) - insert)

'--BACKSPACE support
IF keyval(14) > 1 AND LEN(pre$) > 0 THEN
 pre$ = LEFT$(pre$, LEN(pre$) - 1)
 insert = large(0, insert - 1)
END IF

'--DEL support
IF keyval(83) > 1 AND LEN(post$) > 0 THEN post$ = RIGHT$(post$, LEN(post$) - 1)

'--SHIFT support
shift = 0
IF keyval(54) > 0 OR keyval(42) > 0 THEN shift = 1

'--ALT support
IF keyval(56) THEN shift = shift + 2

'--adding chars
IF LEN(pre$) + LEN(post$) < maxl THEN
 L = LEN(pre$)
 IF keyval(57) > 1 THEN
  IF keyval(29) = 0 THEN
   '--SPACE support
   pre$ = pre$ + " "
  ELSE
   '--charlist support
   pre$ = pre$ + charpicker$
  END IF
 ELSE
  IF keyval(29) = 0 THEN
   '--all other keys
   FOR i = 2 TO 53
    IF keyval(i) > 1 AND keyv(i, shift) > 0 THEN
     pre$ = pre$ + CHR$(keyv(i, shift))
     EXIT FOR
    END IF
   NEXT i
  END IF
 END IF
 IF LEN(pre$) > L THEN insert = insert + 1
END IF

s$ = pre$ + post$

END SUB

'======== FIXME: move this up as code gets cleaned up ===========
OPTION EXPLICIT


SUB update_hero_appearance_menu(BYREF st AS HeroEditState, menu() AS STRING, her AS HeroDef)
 menu(1) = "Battle Picture: " & her.sprite
 menu(2) = "Battle Palette: " & defaultint(her.sprite_pal)
 menu(3) = "Walkabout Picture: " & her.walk_sprite
 menu(4) = "Walkabout Palette: " & defaultint(her.walk_sprite_pal)
 menu(5) = "Base Level: " & her.def_level
 IF her.def_level < 0 THEN menu(5) = "Base Level: Party Average"
 menu(6) = "Default Weapon: " & load_item_name(her.def_weapon, 0, 1)
 menu(7) = "Max Name Length: " & zero_default(her.max_name_len)
 menu(8) = "Hand position A..."
 menu(9) = "Hand position B..."
 menu(10) = "Portrait Picture: " & defaultint(her.portrait, "None")
 menu(11) = "Portrait Palette: " & defaultint(her.portrait_pal)
 update_hero_preview_pics st, her
 st.changed = NO
END SUB

SUB update_hero_preview_pics(BYREF st AS HeroEditState, her AS HeroDef)
 clear_hero_preview_pics st
 WITH st
  .battle.sprite    = sprite_load(game & ".pt0", her.sprite, 8, 32, 40)
  .battle.pal       = palette16_load(game & ".pal", her.sprite_pal, 0, her.sprite)
  .walkabout.sprite = sprite_load(game & ".pt4", her.walk_sprite, 8, 20, 20)
  .walkabout.pal    = palette16_load(game & ".pal", her.walk_sprite_pal, 4, her.walk_sprite)
  IF her.portrait >= 0 THEN
   .portrait.sprite = sprite_load(game & ".pt8", her.portrait, 1, 50, 50)
   .portrait.pal    = palette16_load(game & ".pal", her.portrait_pal, 8, her.portrait)
  END IF
 END WITH
END SUB

SUB clear_hero_preview_pics(BYREF st AS HeroEditState)
 WITH st
  IF .battle.sprite    THEN sprite_unload    @.battle.sprite
  IF .battle.pal       THEN palette16_unload @.battle.pal
  IF .walkabout.sprite THEN sprite_unload    @.walkabout.sprite
  IF .walkabout.pal    THEN palette16_unload @.walkabout.pal
  IF .portrait.sprite  THEN sprite_unload    @.portrait.sprite
  IF .portrait.pal     THEN palette16_unload @.portrait.pal
 END WITH
END SUB

SUB draw_hero_preview(st AS HeroEditState, her AS HeroDef)
 STATIC tog AS INTEGER
 tog = tog XOR 1
 
 DIM frame AS INTEGER
 IF st.previewframe <> -1 THEN
  frame = st.previewframe + 2
 ELSE
  frame = tog
 END IF
 sprite_draw st.battle.sprite + frame, st.battle.pal, 250, 25,,,dpage
 frame = st.preview_walk_direction * 2 + tog
 sprite_draw st.walkabout.sprite + frame, st.walkabout.pal, 230 + st.preview_walk_pos.x, 5 + st.preview_walk_pos.y,,,dpage
 DIM hand AS XYPair
 IF st.previewframe <> -1 THEN
  IF st.previewframe = 0 THEN
   hand.x = her.hand_a_x
   hand.y = her.hand_a_y
  ELSE
   hand.x = her.hand_b_x
   hand.y = her.hand_b_y
  END IF
  drawline 248 + hand.x,25 + hand.y,249 + hand.x, 25 + hand.y,14 + tog, dpage
  drawline 250 + hand.x,23 + hand.y,250 + hand.x, 24 + hand.y,14 + tog, dpage
  drawline 251 + hand.x,25 + hand.y,252 + hand.x, 25 + hand.y,14 + tog, dpage
  drawline 250 + hand.x,26 + hand.y,250 + hand.x, 27 + hand.y,14 + tog, dpage
 END IF
 IF st.portrait.sprite THEN sprite_draw st.portrait.sprite, st.portrait.pal, 240, 110,,,dpage
END SUB

SUB animate_hero_preview(BYREF st AS HeroEditState)
 WITH st
  .preview_steps += 1
  IF .preview_steps >= 15 THEN
   .preview_steps = 0
   .preview_walk_direction = loopvar(.preview_walk_direction, 0, 3, 1)
  END IF
  IF .preview_walk_direction = 0 THEN .preview_walk_pos.y -= 4
  IF .preview_walk_direction = 1 THEN .preview_walk_pos.x += 4
  IF .preview_walk_direction = 2 THEN .preview_walk_pos.y += 4
  IF .preview_walk_direction = 3 THEN .preview_walk_pos.x -= 4
 END WITH
END SUB

SUB hero_appearance_editor(BYREF st AS HeroEditState, BYREF her AS HeroDef)
 
 DIM menu(11) AS STRING
 DIM min(11) AS INTEGER
 DIM max(11) AS INTEGER
 menu(0) = "Previous Menu"
 min(1) = 0: max(1) = gen(genMaxHeroPic)
 min(2) = -1: max(2) = 32767
 min(3) = 0: max(3) = gen(genMaxNPCPic)
 min(4) = -1: max(4) = 32767
 min(5) = -1: max(5) = 99
 min(6) = 0: max(6) = gen(genMaxItem)
 min(7) = 0: max(7) = 16
 min(8) = -100:max(8) = 100
 min(9) = -100:max(9) = 100
 min(10) = -1:max(10) = gen(genMaxPortrait)
 min(11) = -1:max(11) = 32767

 DIM state AS MenuState
 WITH state
  .pt = 0
  .last = UBOUND(menu)
  .size = 24
 END WITH

 update_hero_appearance_menu st, menu(), her
 st.changed = NO
 setkeys
 DO
  setwait 55
  setkeys
  state.tog = state.tog XOR 1
  animate_hero_preview st
  IF keyval(scEsc) > 1 THEN EXIT DO
  usemenu state
  st.previewframe = -1
  IF state.pt = 8 THEN st.previewframe = 0
  IF state.pt = 9 THEN st.previewframe = 1
  IF enter_or_space() AND state.pt = 0 THEN EXIT DO
  IF state.pt > 0 THEN
   SELECT CASE state.pt
    CASE 1
     IF intgrabber(her.sprite, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 2
     IF intgrabber(her.sprite_pal, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 3
     IF intgrabber(her.walk_sprite, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 4
     IF intgrabber(her.walk_sprite_pal, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 5
     IF intgrabber(her.def_level, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 6
     IF intgrabber(her.def_weapon, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 7
     IF intgrabber(her.max_name_len, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 10
     IF intgrabber(her.portrait, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
    CASE 11
     IF intgrabber(her.portrait_pal, min(state.pt), max(state.pt)) THEN
      st.changed = YES
     END IF
   END SELECT
   IF enter_or_space() THEN
    SELECT CASE state.pt
     CASE 2
      her.sprite_pal = pal16browse(her.sprite_pal, 0, her.sprite, 8, 32, 40)
     CASE 4
      her.walk_sprite_pal = pal16browse(her.walk_sprite_pal, 4, her.walk_sprite, 8, 20, 20)
     CASE 8
      xy_position_on_sprite st.battle, her.hand_a_x, her.hand_a_y, 2, 32, 40, "hand position (for weapon)"
     CASE 9
      xy_position_on_sprite st.battle, her.hand_b_x, her.hand_b_y, 3, 32, 40, "hand position (for weapon)"
     CASE 11
      her.portrait_pal = pal16browse(her.portrait_pal, 8, her.portrait, 1, 50, 50)
    END SELECT
    st.changed = YES
   END IF
  END IF

  IF st.changed THEN update_hero_appearance_menu st, menu(), her
  standardmenu menu(), state, 8, 0, dpage
  draw_hero_preview st, her
  SWAP vpage, dpage
  setvispage vpage
  clearpage dpage
  dowait
 LOOP
 st.previewframe = -1
END SUB
