'OHRRPGCE CUSTOM - Enemy Editor
'(C) Copyright 1997-2018 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
#include "config.bi"
#include "const.bi"
#include "udts.bi"
#include "custom.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "customsubs.bi"
#include "slices.bi"
#include "thingbrowser.bi"
#include "cglobals.bi"

#include "uiconst.bi"
#include "scrconst.bi"

#include "flexmenu.bi"

'Defined in this file:

DECLARE FUNCTION enemy_edit_add_new (recbuf() as integer, preview_box as Slice ptr) as bool
DECLARE SUB enemy_edit_update_menu(byval recindex as integer, state as MenuState, recbuf() as integer, menu() as string, menuoff() as integer, menutype() as integer, menulimits() as integer, min() as integer, max() as integer, dispmenu() as string, workmenu() as integer, caption() as string, menucapoff() as integer, byref preview_sprite as Frame ptr, preview as Slice Ptr, byval dissolve_ticks as integer, byval EnLimSpawn as integer, byval EnLimAtk as integer, byval EnLimPic as integer, byval EnDatPic as integer, byval EnDatPal as integer, byval EnDatPicSize as integer)
DECLARE SUB enemy_edit_load(byval recnum as integer, recbuf() as integer, state as MenuState, caption() as string, byval EnCapElemResist as integer)
DECLARE SUB enemy_edit_pushmenu (state as MenuState, byref lastptr as integer, byref lasttop as integer, byref menudepth as bool)
DECLARE SUB enemy_edit_backmenu (state as MenuState, byval lastptr as integer, byval lasttop as integer, byref menudepth as bool, workmenu() as integer, mainMenu() as integer)


SUB update_enemy_editor_for_elementals(recbuf() as integer, caption() as string, byval EnCapElemResist as integer)
 FOR i as integer = 0 TO gen(genNumElements) - 1
  caption(EnCapElemResist + i) = format_percent(DeSerSingle(recbuf(), 239 + i*2))
 NEXT
END SUB

SUB enemy_editor_main ()
 DIM b as EnemyBrowser
 b.browse(-1, , @enemy_editor)
END SUB

FUNCTION enemy_picker (recindex as integer = -1) as integer
 DIM b as EnemyBrowser
 RETURN b.browse(recindex, , @enemy_editor, NO)
END FUNCTION

FUNCTION enemy_picker_or_none (recindex as integer = -1) as integer
 DIM b as EnemyBrowser
 RETURN b.browse(recindex - 1, YES , @enemy_editor, NO) + 1
END FUNCTION

CONST EnLimDeathSFX = 26

'recindex: which enemy to show. If -1, same as last time. If >= max, ask to add a new attack,
'(and exit and return -1 if cancelled).
'Otherwise, returns the enemy number we were last editing.
'Note: the enemy editor can be entered recursively!
FUNCTION enemy_editor (recindex as integer = -1) as integer

DIM elementnames() as string
getelementnames elementnames()

'-------------------------------------------------------------------------

'--bitsets
DIM enemybits() as IntStrPair

a_append enemybits(), -1, ""
a_append enemybits(), -1, " Appearance"
a_append enemybits(), 59, "Flee instead of die"
a_append enemybits(), 63, "Never flinch when attacked"

a_append enemybits(), -1, ""
a_append enemybits(), -1, " Behavior"
a_append enemybits(), 55, "MP idiot"
a_append enemybits(), 58, "Die without boss"

a_append enemybits(), -1, ""
a_append enemybits(), -1, " Type"
a_append enemybits(), 64, "Ignored for ""Alone"" AI"
a_append enemybits(), 56, "Boss"
a_append enemybits(), 57, "Unescapable"
a_append enemybits(), 62, "Win battle even if alive"
a_append enemybits(), 61, "Untargetable by heroes & win even if alive"
a_append enemybits(), 60, "Untargetable by enemies"

a_append enemybits(), -1, ""
a_append enemybits(), -1, " Other"
a_append enemybits(), 54, "Harmed by cure"


'-------------------------------------------------------------------------

'--record buffer
DIM recbuf(dimbinsize(binDT1)) as integer

CONST EnDatName = 0' to 16
CONST EnDatStealAvail = 17
CONST EnDatStealItem = 18
CONST EnDatStealItemP = 19
CONST EnDatStealRItem = 20
CONST EnDatStealRItemP = 21
CONST EnDatDissolve = 22
CONST EnDatDissolveTime = 23
CONST EnDatDeathSFX = 24
CONST EnDatCursorX = 25
CONST EnDatCursorY = 26
'27 to 52 unused
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
CONST EnDatElemCtr = 107' to 114
CONST EnDatStatCtr = 115' to 126
CONST EnDatElemCtr2 = 127' to 182
CONST EnDatSpawnElement2 = 183' to 238
CONST EnDatElemResist = 239' to 366
CONST EnDatAtkBequest = 367
CONST EnDatNonElemCtr = 368
CONST EnDatDissolveIn = 369
CONST EnDatDissolveInTime = 370
CONST EnDatSpawnAllElementsOnHit = 371

'-------------------------------------------------------------------------

DIM capindex as integer = 0
REDIM caption(-1 TO -1) as string
DIM max(29) as integer
DIM min(29) as integer
'Limit 0 is not used

CONST EnLimPic = 1
max(EnLimPic) = gen(genMaxEnemy1Pic) 'or 28 or 29. Must be updated!

CONST EnLimUInt = 2
max(EnLimUInt) = 32767

CONST EnLimPicSize = 3
max(EnLimPicSize) = 2
DIM EnCapPicSize as integer = capindex
addcaption caption(), capindex, "Small 34x34"
addcaption caption(), capindex, "Medium 50x50"
addcaption caption(), capindex, "Big 80x80"

CONST EnLimItem = 4
max(EnLimItem) = gen(genMaxItem)

CONST EnLimPercent = 5
max(EnLimPercent) = 100

CONST EnLimStat = 6' to 17
FOR i as integer = 0 TO statLast
 max(EnLimStat + i) = 32767  ' By default
NEXT
max(EnLimStat + statFocus) = 100
max(EnLimStat + statHitX) = 20

CONST EnLimSpawn = 18
max(EnLimSpawn) = gen(genMaxEnemy) + 1 'must be updated!

CONST EnLimSpawnNum = 19
max(EnLimSpawnNum) = 8

CONST EnLimAtk = 20
max(EnLimAtk) = gen(genMaxAttack) + 1 'Must be updated!

CONST EnLimStr16 = 21
max(EnLimStr16) = 16

CONST EnLimStealAvail = 22
min(EnLimStealAvail) = -1
max(EnLimStealAvail) = 1
addcaption caption(), capindex, "Disabled"
DIM EnCapStealAvail as integer = capindex
addcaption caption(), capindex, "Only one"
addcaption caption(), capindex, "Unlimited"

CONST EnLimPal16 = 23
max(EnLimPal16) = 32767
min(EnLimPal16) = -1

CONST EnLimDissolve = 24
min(EnLimDissolve) = 0
max(EnLimDissolve) = dissolveTypeMax + 1
DIM EnCapDissolve as integer = capindex
addcaption caption(), capindex, "Global Default"
FOR i as integer = 0 TO dissolveTypeMax
 addcaption caption(), capindex, dissolve_type_caption(i)
NEXT

CONST EnLimDissolveTime = 25
min(EnLimDissolveTime) = 0
max(EnLimDissolveTime) = 99

min(EnLimDeathSFX) = -1
max(EnLimDeathSFX) = gen(genMaxSFX) + 1

DIM EnCapElemResist as integer = capindex
FOR i as integer = 0 TO gen(genNumElements) - 1
 addcaption caption(), capindex, ""  '--updated in update_enemy_editor_for_elementals
NEXT

CONST EnLimDissolveIn = 27
min(EnLimDissolveIn) = 0
max(EnLimDissolveIn) = dissolveTypeMax + 1
DIM EnCapDissolveIn as integer = capindex
addcaption caption(), capindex, "Appear Instantly"
FOR i as integer = 0 TO dissolveTypeMax
 addcaption caption(), capindex, appear_type_caption(i)
NEXT

CONST EnLimDissolveInTime = 28
min(EnLimDissolveInTime) = 0
max(EnLimDissolveInTime) = 99

CONST EnLimSpawnAllElementsOnHit = 29
min(EnLimSpawnAllElementsOnHit) = 0
max(EnLimSpawnAllElementsOnHit) = 1
DIM EnCapSpawnAllElementsOnHit as integer = capindex
addcaption caption(), capindex, "Only first matching element"
addcaption caption(), capindex, "All of the above"

'--next limit 30, remember to update min() and max() dim!

'-------------------------------------------------------------------------
'--menu content
CONST MnuItems = 269
DIM menu(MnuItems) as string
DIM menutype(MnuItems) as integer
DIM menuoff(MnuItems) as integer
DIM menulimits(MnuItems) as integer
DIM menucapoff(MnuItems) as integer

CONST EnMenuBackAct = 0
menu(EnMenuBackAct) = "Previous Menu"
menutype(EnMenuBackAct) = 1

CONST EnMenuChooseAct = 1
menu(EnMenuChooseAct) = "Enemy"
menutype(EnMenuChooseAct) = 5

CONST EnMenuName = 2
menu(EnMenuName) = "Name:"
menutype(EnMenuName) = 4
menuoff(EnMenuName) = EnDatName
menulimits(EnMenuName) = EnLimStr16

CONST EnMenuAppearAct = 3
menu(EnMenuAppearAct) = "Appearance & Sounds..."
menutype(EnMenuAppearAct) = 1

CONST EnMenuRewardAct = 4
menu(EnMenuRewardAct) = "Rewards..."
menutype(EnMenuRewardAct) = 1

CONST EnMenuStatAct = 5
menu(EnMenuStatAct) = "Stats..."
menutype(EnMenuStatAct) = 1

CONST EnMenuBitsetAct = 6
menu(EnMenuBitsetAct) = "Bitsets..."
menutype(EnMenuBitsetAct) = 1

CONST EnMenuSpawnAct = 7
menu(EnMenuSpawnAct) = "Spawning..."
menutype(EnMenuSpawnAct) = 1

CONST EnMenuAtkAct = 8
menu(EnMenuAtkAct) = "Attacks..."
menutype(EnMenuAtkAct) = 1

CONST EnMenuPic = 9
menu(EnMenuPic) = "Picture:"
menutype(EnMenuPic) = 0
menuoff(EnMenuPic) = EnDatPic
menulimits(EnMenuPic) = EnLimPic

CONST EnMenuPal = 10
menu(EnMenuPal) = "Palette:"
menutype(EnMenuPal) = 12
menuoff(EnMenuPal) = EnDatPal
menulimits(EnMenuPal) = EnLimPal16

CONST EnMenuPicSize = 11
menu(EnMenuPicSize) = "Picture Size:"
menutype(EnMenuPicSize) = 2000 + EnCapPicSize
menuoff(EnMenuPicSize) = EnDatPicSize
menulimits(EnMenuPicSize) = EnLimPicSize

CONST EnMenuGold = 12
menu(EnMenuGold) = "Gold:"
menutype(EnMenuGold) = 0
menuoff(EnMenuGold) = EnDatGold
menulimits(EnMenuGold) = EnLimUInt

CONST EnMenuExp = 13
menu(EnMenuExp) = "Experience Points:"
menutype(EnMenuExp) = 0
menuoff(EnMenuExp) = EnDatExp
menulimits(EnMenuExp) = EnLimUInt

CONST EnMenuItem = 14
menu(EnMenuItem) = "Item:"
menutype(EnMenuItem) = 8
menuoff(EnMenuItem) = EnDatItem
menulimits(EnMenuItem) = EnLimItem

CONST EnMenuItemP = 15
menu(EnMenuItemP) = "Item%:"
menutype(EnMenuItemP) = 0
menuoff(EnMenuItemP) = EnDatItemP
menulimits(EnMenuItemP) = EnLimPercent

CONST EnMenuRareItem = 16
menu(EnMenuRareItem) = "Rare Item:"
menutype(EnMenuRareItem) = 8
menuoff(EnMenuRareItem) = EnDatRareItem
menulimits(EnMenuRareItem) = EnLimItem

CONST EnMenuRareItemP = 17
menu(EnMenuRareItemP) = "Rare Item%:"
menutype(EnMenuRareItemP) = 0
menuoff(EnMenuRareItemP) = EnDatRareItemP
menulimits(EnMenuRareItemP) = EnLimPercent

CONST EnMenuStat = 18' to 29
FOR i as integer = 0 TO 11
 menu(EnMenuStat + i) = statnames(i) + ":"
 menutype(EnMenuStat + i) = 0
 menuoff(EnMenuStat + i) = EnDatStat + i
 menulimits(EnMenuStat + i) = EnLimStat + i
NEXT i
menutype(EnMenuStat + 8) = 15 'Speed should show turn-time estimate

CONST EnMenuSpawnDeath = 30
menu(EnMenuSpawnDeath) = "Spawn on Death:"
menutype(EnMenuSpawnDeath) = 9
menuoff(EnMenuSpawnDeath) = EnDatSpawnDeath
menulimits(EnMenuSpawnDeath) = EnLimSpawn

CONST EnMenuSpawnNEDeath = 31
menu(EnMenuSpawnNEDeath) = "on Non-Elemental Death:"
menutype(EnMenuSpawnNEDeath) = 9
menuoff(EnMenuSpawnNEDeath) = EnDatSpawnNEDeath
menulimits(EnMenuSpawnNEDeath) = EnLimSpawn

CONST EnMenuSpawnAlone = 32
menu(EnMenuSpawnAlone) = "Spawn When Alone:"
menutype(EnMenuSpawnAlone) = 9
menuoff(EnMenuSpawnAlone) = EnDatSpawnAlone
menulimits(EnMenuSpawnAlone) = EnLimSpawn

CONST EnMenuSpawnNEHit = 33
menu(EnMenuSpawnNEHit) = "on Non-Elemental Hit:"
menutype(EnMenuSpawnNEHit) = 9
menuoff(EnMenuSpawnNEHit) = EnDatSpawnNEHit
menulimits(EnMenuSpawnNEHit) = EnLimSpawn

CONST EnMenuSpawnElement = 34' to 93
FOR i as integer = 0 TO gen(genNumElements) - 1
 menu(EnMenuSpawnElement + i) = "on " & elementnames(i) & " Hit:"
 menutype(EnMenuSpawnElement + i) = 9
 IF i < 8 THEN
  menuoff(EnMenuSpawnElement + i) = EnDatSpawnElement + i
 ELSE
  menuoff(EnMenuSpawnElement + i) = EnDatSpawnElement2 + (i - 8)
 END IF
 menulimits(EnMenuSpawnElement + i) = EnLimSpawn
NEXT i

CONST EnMenuSpawnNum = 98
menu(EnMenuSpawnNum) = "How Many to Spawn:"
menutype(EnMenuSpawnNum) = 0
menuoff(EnMenuSpawnNum) = EnDatSpawnNum
menulimits(EnMenuSpawnNum) = EnLimSpawnNum

CONST EnMenuAtkNormal = 99' to 103
FOR i as integer = 0 TO 4
 menu(EnMenuAtkNormal + i) = "Normal:"
 menutype(EnMenuAtkNormal + i) = 7
 menuoff(EnMenuAtkNormal + i) = EnDatAtkNormal + i
 menulimits(EnMenuAtkNormal + i) = EnLimAtk
NEXT i

CONST EnMenuAtkDesp = 104' to 108
FOR i as integer = 0 TO 4
 menu(EnMenuAtkDesp + i) = "Desperation:"
 menutype(EnMenuAtkDesp + i) = 7
 menuoff(EnMenuAtkDesp + i) = EnDatAtkDesp + i
 menulimits(EnMenuAtkDesp + i) = EnLimAtk
NEXT i

CONST EnMenuAtkAlone = 109' to 113
FOR i as integer = 0 TO 4
 menu(EnMenuAtkAlone + i) = "Alone:"
 menutype(EnMenuAtkAlone + i) = 7
 menuoff(EnMenuAtkAlone + i) = EnDatAtkAlone + i
 menulimits(EnMenuAtkAlone + i) = EnLimAtk
NEXT i

CONST EnMenuStealItem = 114
menu(EnMenuStealItem) = "Stealable Item:"
menutype(EnMenuStealItem) = 8
menuoff(EnMenuStealItem) = EnDatStealItem
menulimits(EnMenuStealItem) = EnLimItem

CONST EnMenuStealRItem = 115
menu(EnMenuStealRItem) = "Rare Stealable Item:"
menutype(EnMenuStealRItem) = 8
menuoff(EnMenuStealRItem) = EnDatStealRItem
menulimits(EnMenuStealRItem) = EnLimItem

CONST EnMenuStealItemP = 116
menu(EnMenuStealItemP) = "Steal Rate%:"
menutype(EnMenuStealItemP) = 0
menuoff(EnMenuStealItemP) = EnDatStealItemP
menulimits(EnMenuStealItemP) = EnLimPercent

CONST EnMenuStealRItemP = 117
menu(EnMenuStealRItemP) = "Rare Steal Rate%:"
menutype(EnMenuStealRItemP) = 0
menuoff(EnMenuStealRItemP) = EnDatStealRItemP
menulimits(EnMenuStealRItemP) = EnLimPercent

CONST EnMenuStealAvail = 118
menu(EnMenuStealAvail) = "Steal Availability:"
menutype(EnMenuStealAvail) = 2000 + EnCapStealAvail
menuoff(EnMenuStealAvail) = EnDatStealAvail
menulimits(EnMenuStealAvail) = EnLimStealAvail

CONST EnMenuDissolve = 119
menu(EnMenuDissolve) = "Death Animation:"
menutype(EnMenuDissolve) = 2000 + EnCapDissolve
menuoff(EnMenuDissolve) = EnDatDissolve
menulimits(EnMenuDissolve) = EnLimDissolve

CONST EnMenuDissolveTime = 120
menu(EnMenuDissolveTime) = "Death Animation ticks:"
menutype(EnMenuDissolveTime) = 13
menuoff(EnMenuDissolveTime) = EnDatDissolveTime
menulimits(EnMenuDissolveTime) = EnLimDissolveTime

CONST EnMenuDeathSFX = 121
menu(EnMenuDeathSFX) = "Death Sound Effect:"
menutype(EnMenuDeathSFX) = 14
menuoff(EnMenuDeathSFX) = EnDatDeathSFX
menulimits(EnMenuDeathSFX) = EnLimDeathSFX

CONST EnMenuCursorOffset = 122
menu(EnMenuCursorOffset) = "Cursor Offset..."
menutype(EnMenuCursorOffset) = 1

CONST EnMenuElemCtr = 123' to 186
FOR i as integer = 0 TO gen(genNumElements) - 1
 menu(EnMenuElemCtr + i) = "Counter element " & elementnames(i) & ":"
 menutype(EnMenuElemCtr + i) = 7
 IF i < 8 THEN
  menuoff(EnMenuElemCtr + i) = EnDatElemCtr + i
 ELSE
  menuoff(EnMenuElemCtr + i) = EnDatElemCtr2 + (i - 8)
 END IF
 menulimits(EnMenuElemCtr + i) = EnLimAtk
NEXT i

CONST EnMenuStatCtr = 187' to 198
FOR i as integer = 0 TO 11
 menu(EnMenuStatCtr + i) = "Counter damage to " & statnames(i) & ":"
 menutype(EnMenuStatCtr + i) = 7
 menuoff(EnMenuStatCtr + i) = EnDatStatCtr + i
 menulimits(EnMenuStatCtr + i) = EnLimAtk
NEXT i

CONST EnMenuElementalsAct = 199
menu(EnMenuElementalsAct) = "Elemental Resistances..."
menutype(EnMenuElementalsAct) = 1

CONST EnMenuElemDmg = 200' to 263
FOR i as integer = 0 TO gen(genNumElements) - 1
 menu(EnMenuElemDmg + i) = "Damage from " + rpad(elementnames(i), " ", 15) + ":"
 menutype(EnMenuElemDmg + i) = 5000 + EnCapElemResist + i  'percent_grabber
 menuoff(EnMenuElemDmg + i) = 239 + i*2 
NEXT

CONST EnMenuAtkBequest = 264
menu(EnMenuAtkBequest) = "On-Death Bequest Attack:"
menutype(EnMenuAtkBequest) = 7
menuoff(EnMenuAtkBequest) = EnDatAtkBequest
menulimits(EnMenuAtkBequest) = EnLimAtk

CONST EnMenuNonElemCtr = 265
menu(EnMenuNonElemCtr) = "Counter non-elemental attacks:"
menutype(EnMenuNonElemCtr) = 7
menuoff(EnMenuNonElemCtr) = EnDatNonElemCtr
menulimits(EnMenuNonElemCtr) = EnLimAtk

CONST EnMenuDissolveIn = 266
menu(EnMenuDissolveIn) = "Appear Animation:"
menutype(EnMenuDissolveIn) = 2000 + EnCapDissolveIn
menuoff(EnMenuDissolveIn) = EnDatDissolveIn
menulimits(EnMenuDissolveIn) = EnLimDissolveIn

CONST EnMenuDissolveInTime = 267
menu(EnMenuDissolveInTime) = "Appear Animation ticks:"
menutype(EnMenuDissolveInTime) = 13
menuoff(EnMenuDissolveInTime) = EnDatDissolveInTime
menulimits(EnMenuDissolveInTime) = EnLimDissolveInTime

CONST EnMenuSpawnAllElementsOnHit = 268
menu(EnMenuSpawnAllElementsOnHit) = "on Multi-Element Hit:"
menutype(EnMenuSpawnAllElementsOnHit) = 2000 + EnCapSpawnAllElementsOnHit
menuoff(EnMenuSpawnAllElementsOnHit) = EnDatSpawnAllElementsOnHit
menulimits(EnMenuSpawnAllElementsOnHit) = EnLimSpawnAllElementsOnHit


CONST EnMenuChooseAct2 = 269
menu(EnMenuChooseAct2) = "Enemy"
menutype(EnMenuChooseAct2) = 55

'Next is 269, don't forget to update MnuItems

'-------------------------------------------------------------------------
'--menu structure
'WARNING: make these big enough to hold atkMenu when genNumElements is maxed out
DIM workmenu(93) as integer
DIM dispmenu(93) as string
DIM state as MenuState
state.autosize = YES
state.autosize_ignore_pixels = 12
state.need_update = YES
DIM menuopts as MenuOptions
menuopts.fullscreen_scrollbar = YES

DIM mainMenu(10) as integer
mainMenu(0) = EnMenuBackAct
mainMenu(1) = EnMenuChooseAct
mainMenu(2) = EnMenuChooseAct2
mainMenu(3) = EnMenuName
mainMenu(4) = EnMenuAppearAct
mainMenu(5) = EnMenuRewardAct
mainMenu(6) = EnMenuStatAct
mainMenu(7) = EnMenuBitsetAct
mainMenu(8) = EnMenuElementalsAct
mainMenu(9) = EnMenuSpawnAct
mainMenu(10) = EnMenuAtkAct

DIM appearMenu(9) as integer
appearMenu(0) = EnMenuBackAct
appearMenu(1) = EnMenuPicSize
appearMenu(2) = EnMenuPic
appearMenu(3) = EnMenuPal
appearMenu(4) = EnMenuDissolve
appearMenu(5) = EnMenuDissolveTime
appearMenu(6) = EnMenuDeathSFX
appearMenu(7) = EnMenuDissolveIn
appearMenu(8) = EnMenuDissolveInTime
appearMenu(9) = EnMenuCursorOffset

DIM rewardMenu(11) as integer
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

DIM statMenu(12) as integer
statMenu(0) = EnMenuBackAct
FOR i as integer = 0 TO 11
 statMenu(1 + i) = EnMenuStat + i
NEXT i

DIM spawnMenu(6 + gen(genNumElements)) as integer
spawnMenu(0) = EnMenuBackAct
spawnMenu(1) = EnMenuSpawnNum
spawnMenu(2) = EnMenuSpawnDeath
spawnMenu(3) = EnMenuSpawnNEDeath
spawnMenu(4) = EnMenuSpawnAlone
spawnMenu(5) = EnMenuSpawnNEHit
FOR i as integer = 0 TO gen(genNumElements) - 1
 spawnMenu(6 + i) = EnMenuSpawnElement + i
NEXT i
spawnMenu(6 + gen(genNumElements)) = EnMenuSpawnAllElementsOnHit

DIM atkMenu(29 + gen(genNumElements)) as integer
atkMenu(0) = EnMenuBackAct
FOR i as integer = 0 TO 4
 atkMenu(1 + i) = EnMenuAtkNormal + i
 atkMenu(6 + i) = EnMenuAtkDesp + i
 atkMenu(11 + i) = EnMenuAtkAlone + i
NEXT i
atkMenu(16) = EnMenuAtkBequest
FOR i as integer = 0 TO gen(genNumElements) - 1
 atkMenu(17 + i) = EnMenuElemCtr + i
NEXT i
atkMenu(17 + gen(genNumElements)) = EnMenuNonElemCtr
FOR i as integer = 0 TO 11
 atkMenu(18 + gen(genNumElements) + i) = EnMenuStatCtr + i
NEXT i

DIM elementalMenu(gen(genNumElements)) as integer
elementalMenu(0) = EnMenuBackAct
FOR i as integer = 0 TO gen(genNumElements) - 1
 elementalMenu(1 + i) = EnMenuElemDmg + i
NEXT i

DIM helpkey as string = "enemy"

'--Create the box that holds the preview
DIM preview_box as Slice Ptr
preview_box = NewSliceOfType(slRectangle)
ChangeRectangleSlice preview_box, ,uilook(uiDisabledItem), uilook(uiMenuItem), , transOpaque
'--Align the box in the bottom right
WITH *preview_box
 .X = -8
 .Y = -8
 .Width = 82
 .Height = 82
 .AnchorHoriz = 2
 .AlignHoriz = 2
 .AnchorVert = 2
 .AlignVert = 2
END WITH

'--Create the preview sprite. It will be updated before it is drawn.
DIM preview as Slice Ptr
preview = NewSliceOfType(slSprite, preview_box)
'--Align the sprite to the bottom center of the containing box
WITH *preview
 .Y = -1
 .AnchorHoriz = 1
 .AlignHoriz = 1
 .AnchorVert = 2
 .AlignVert = 2
END WITH

'--Need a copy of the sprite to call frame_dissolved on
DIM preview_sprite as Frame ptr
DIM setup_preview_dissolve as bool = NO
DIM setup_preview_appear as bool = NO

'--dissolve_ticks is >= 0 while playing a dissolve; > dissolve_time while during lag period afterwards
DIM as integer dissolve_time, dissolve_type, dissolve_ticks
DIM as bool dissolve_backwards = NO
dissolve_ticks = -1

'--default starting menu
setactivemenu workmenu(), mainMenu(), state
state.pt = 1  'Select <-Enemy ..-> line
state.size = 25

DIM menudepth as bool = NO
DIM lastptr as integer = 0
DIM lasttop as integer = 0

STATIC rememberindex as integer = -1   'Record to switch to with TAB
DIM show_name_ticks as integer = 0  'Number of ticks to show name (after switching record with TAB)

DIM remember_bit as integer = -1
DIM drawpreview as bool = YES

'Which enemy to show?
STATIC remember_recindex as integer = 0
IF recindex < 0 THEN
 recindex = remember_recindex
ELSE
 IF recindex > gen(genMaxEnemy) THEN
  IF enemy_edit_add_new(recbuf(), preview_box) THEN
   'Added a new record (blank or copy)
   saveenemydata recbuf(), recindex
   recindex = gen(genMaxEnemy) + 1
  ELSE
   DeleteSlice @preview_box
   RETURN -1
  END IF
 END IF
END IF

'load data here
enemy_edit_load recindex, recbuf(), state, caption(), EnCapElemResist

'------------------------------------------------------------------------
'--main loop

setkeys YES
DO
 setwait 55
 setkeys YES
 IF keyval(scESC) > 1 THEN
  IF menudepth THEN
   enemy_edit_backmenu state, lastptr, lasttop, menudepth, workmenu(), mainMenu()
   helpkey = "enemy"
   drawpreview = YES
  ELSE
   EXIT DO
  END IF
 END IF

 '--SHIFT+BACKSPACE
 IF cropafter_keycombo(workmenu(state.pt) = EnMenuChooseAct) THEN
  cropafter recindex, gen(genMaxEnemy), 0, game + ".dt1", getbinsize(binDT1)
 END IF

 usemenu state

 IF workmenu(state.pt) = EnMenuChooseAct OR (keyval(scAlt) > 0 and NOT isStringField(menutype(workmenu(state.pt)))) THEN
  DIM lastindex as integer = recindex
  IF intgrabber_with_addset(recindex, 0, gen(genMaxEnemy), 32767, "enemy") THEN
   saveenemydata recbuf(), lastindex
   IF recindex > gen(genMaxEnemy) THEN
    '--adding a new set
    IF enemy_edit_add_new(recbuf(), preview_box) THEN
     'Added a new record (blank or copy)
     saveenemydata recbuf(), recindex
     enemy_edit_load recindex, recbuf(), state, caption(), EnCapElemResist
    ELSE
     'cancelled add, reload the old last record
     recindex -= 1
     enemy_edit_load recindex, recbuf(), state, caption(), EnCapElemResist
    END IF
   ELSE
    enemy_edit_load recindex, recbuf(), state, caption(), EnCapElemResist
   END IF
   state.need_update = YES
  END IF
 END IF

 IF keyval(scF1) > 1 THEN show_help helpkey

 IF keyval(scTab) > 1 THEN
  IF keyval(scShift) > 0 THEN
   rememberindex = recindex
  ELSEIF rememberindex >= 0 AND rememberindex <= gen(genMaxEnemy) THEN
   saveenemydata recbuf(), recindex
   SWAP rememberindex, recindex
   enemy_edit_load recindex, recbuf(), state, caption(), EnCapElemResist
   show_name_ticks = 23
  END IF
 END IF

 IF enter_space_click(state) THEN
  DIM nowindex as integer = workmenu(state.pt)
  SELECT CASE menutype(nowindex)
   CASE 8 ' Item
    recbuf(menuoff(nowindex)) = item_picker(recbuf(menuoff(nowindex)))
    max(EnLimItem) = gen(genMaxItem)
    state.need_update = YES
   CASE 10 ' Item with offset
    recbuf(menuoff(nowindex)) = item_picker_or_none(recbuf(menuoff(nowindex)))
    max(EnLimItem) = gen(genMaxItem)
    state.need_update = YES
  END SELECT
  SELECT CASE nowindex
   CASE EnMenuChooseAct
    'The <-Enemy #-> line; enter exits so that if we were called from another menu
    'it is easy to select an enemy and return to it.
    EXIT DO
   CASE EnMenuBackAct
    IF menudepth THEN
     enemy_edit_backmenu state, lastptr, lasttop, menudepth, workmenu(), mainMenu()
     helpkey = "enemy"
     drawpreview = YES
    ELSE
     EXIT DO
    END IF
   CASE EnMenuAppearAct
    enemy_edit_pushmenu state, lastptr, lasttop, menudepth
    setactivemenu workmenu(), appearMenu(), state
    helpkey = "enemy_appearance"
    state.need_update = YES
   CASE EnMenuRewardAct
    enemy_edit_pushmenu state, lastptr, lasttop, menudepth
    setactivemenu workmenu(), rewardMenu(), state
    helpkey = "enemy_rewards"
    state.need_update = YES
   CASE EnMenuStatAct
    enemy_edit_pushmenu state, lastptr, lasttop, menudepth
    setactivemenu workmenu(), statMenu(), state
    helpkey = "enemy_stats"
    state.need_update = YES
   CASE EnMenuSpawnAct
    enemy_edit_pushmenu state, lastptr, lasttop, menudepth
    setactivemenu workmenu(), spawnMenu(), state
    helpkey = "enemy_spawning"
    drawpreview = NO
    state.need_update = YES
   CASE EnMenuAtkAct
    enemy_edit_pushmenu state, lastptr, lasttop, menudepth
    setactivemenu workmenu(), atkMenu(), state
    helpkey = "enemy_attacks"
    drawpreview = NO
    state.need_update = YES
   CASE EnMenuElementalsAct
    enemy_edit_pushmenu state, lastptr, lasttop, menudepth
    setactivemenu workmenu(), elementalMenu(), state
    helpkey = "enemy_elementals"
    drawpreview = NO
    state.need_update = YES
   CASE EnMenuPic
    DIM enemyb as EnemySpriteBrowser
    enemyb.size_group = recbuf(EnDatPicSize)
    recbuf(EnDatPic) = enemyb.browse(recbuf(EnDatPic))
    state.need_update = YES
   CASE EnMenuPal
    recbuf(EnDatPal) = pal16browse(recbuf(EnDatPal), CAST(SpriteType, recbuf(EnDatPicSize) + sprTypeSmallEnemy), recbuf(EnDatPic), YES)
    state.need_update = YES
   CASE EnMenuDeathSFX
    DIM old_sfx as integer = recbuf(EnDatDeathSFX)
    recbuf(EnDatDeathSFX) = sfx_picker_or_none(old_sfx)
    state.need_update = (recbuf(EnDatDeathSFX) <> old_sfx)
    IF recbuf(EnDatDeathSFX) = 0 THEN playsfx gen(genDefaultDeathSFX) - 1
   CASE EnMenuBitsetAct
    editbitset recbuf(), EnDatBitset, enemybits(), "enemy_bitsets", remember_bit
   CASE EnMenuDissolve, EnMenuDissolveTime
    setup_preview_dissolve = YES
   CASE EnMenuDissolveIn, EnMenuDissolveInTime
    setup_preview_appear = YES
   CASE EnMenuCursorOffset
    '--temporarily move the preview image, centering it on the screen
    OrphanSlice preview
    preview->AnchorVert = alignCenter
    preview->AlignVert = alignCenter
    recbuf(EnDatCursorX) += preview->Size.x / 2 '--offset relative to the top middle
    xy_position_on_slice preview, recbuf(EnDatCursorX), recbuf(EnDatCursorY), "Targetting Cursor Offset", "xy_target_cursor"
    recbuf(EnDatCursorX) -= preview->Size.x / 2
    '--move the preview image back how it was before
    SetSliceParent(preview, preview_box)
    preview->AnchorVert = alignBottom
    preview->AlignVert = alignBottom
  END SELECT
 END IF

 IF keyval(scAlt) = 0 or isStringField(menutype(workmenu(state.pt))) THEN 'not pressing ALT, or not allowed to
  IF editflexmenu(state, workmenu(state.pt), menutype(), menuoff(), menulimits(), recbuf(), caption(), min(), max()) THEN
   state.need_update = YES
  END IF
 END IF

 IF setup_preview_dissolve THEN
  IF recbuf(EnDatDissolve) THEN dissolve_type = recbuf(EnDatDissolve) - 1 ELSE dissolve_type = gen(genEnemyDissolve)
  dissolve_time = recbuf(EnDatDissolveTime) 
  IF dissolve_time = 0 THEN dissolve_time = default_dissolve_time(dissolve_type, preview_sprite->w, preview_sprite->h)
  dissolve_ticks = 0
  dissolve_backwards = NO
  setup_preview_dissolve = NO
 END IF 
 IF setup_preview_appear THEN
  IF recbuf(EnDatDissolveIn) > 0 THEN
   dissolve_type = recbuf(EnDatDissolveIn) - 1
   dissolve_time = recbuf(EnDatDissolveInTime) 
   IF dissolve_time = 0 THEN dissolve_time = default_dissolve_time(dissolve_type, preview_sprite->w, preview_sprite->h)
   dissolve_ticks = 0
  END IF
  dissolve_backwards = YES
  setup_preview_appear = NO
 END IF

 IF flexmenu_handle_crossrefs(state, workmenu(state.pt), menutype(), menuoff(), recindex, recbuf(), NO) THEN
  'Reload this enemy in case it was changed in recursive call to the editor (in fact, this record might be deleted!)
  recindex = small(recindex, gen(genMaxEnemy))
  enemy_edit_load recindex, recbuf(), state, caption(), EnCapElemResist
  show_name_ticks = 23
  state.need_update = YES
 END IF

 IF dissolve_ticks >= 0 THEN
  dissolve_ticks += 1
  DIM stop_at as integer = dissolve_time + 15
  IF dissolve_backwards THEN stop_at = dissolve_time
  IF dissolve_ticks > stop_at THEN
   dissolve_ticks = -1
   state.need_update = YES
  ELSE
   IF dissolve_ticks <= dissolve_time THEN
    DIM dticks as integer = dissolve_ticks
    IF dissolve_backwards THEN dticks = dissolve_time - dissolve_ticks
    SetSpriteToFrame preview, frame_dissolved(preview_sprite, dissolve_time, dticks, dissolve_type), , _
                     abs_pal_num(recbuf(EnDatPal), sprTypeSmallEnemy + recbuf(EnDatPicSize), recbuf(EnDatPic))
   END IF
  END IF
 END IF
 'lag time after fading out, to give a more realistic preview
 preview->Visible = (dissolve_ticks <= dissolve_time)

 IF state.need_update THEN
  state.need_update = NO
  enemy_edit_update_menu recindex, state, recbuf(), menu(), menuoff(), menutype(), menulimits(), min(), max(), dispmenu(), workmenu(), caption(), menucapoff(), preview_sprite, preview, dissolve_ticks, EnLimSpawn, EnLimAtk, EnLimPic, EnDatPic, EnDatPal, EnDatPicSize
 END IF

 clearpage vpage
 IF drawpreview THEN
  DrawSlice preview_box, vpage
 END IF

 standardmenu dispmenu(), state, 0, 0, vpage, menuopts
 draw_fullscreen_scrollbar state, , vpage
 IF keyval(scAlt) > 0 OR show_name_ticks > 0 THEN 'holding ALT or just pressed TAB
  show_name_ticks = large(0, show_name_ticks - 1)
  DIM tmpstr as string = readbadbinstring(recbuf(), EnDatName, 15, 0) & " " & recindex
  textcolor uilook(uiText), uilook(uiHighlight)
  printstr tmpstr, pRight, 0, vpage
 END IF
 edgeprint flexmenu_tooltip(workmenu(state.pt), menutype()), pLeft, pBottom, uilook(uiDisabledItem), vpage

 setvispage vpage
 dowait
LOOP

'--save what we were last working on
saveenemydata recbuf(), recindex

resetsfx
DeleteSlice @preview_box
frame_unload @preview_sprite

remember_recindex = recindex
RETURN recindex

END FUNCTION

SUB enemy_edit_backmenu (state as MenuState, byval lastptr as integer, byval lasttop as integer, byref menudepth as bool, workmenu() as integer, mainMenu() as integer)
 setactivemenu workmenu(), mainMenu(), state
 menudepth = NO
 state.pt = lastptr
 state.top = lasttop
 state.need_update = YES
END SUB

SUB enemy_edit_pushmenu (state as MenuState, byref lastptr as integer, byref lasttop as integer, byref menudepth as bool)
 lastptr = state.pt
 lasttop = state.top
 menudepth = YES
END SUB

SUB enemy_edit_load(byval recnum as integer, recbuf() as integer, state as MenuState, caption() as string, byval EnCapElemResist as integer)
 loadenemydata recbuf(), recnum
 update_enemy_editor_for_elementals recbuf(), caption(), EnCapElemResist
 state.need_update = YES
END SUB

SUB enemy_edit_update_menu(byval recindex as integer, state as MenuState, recbuf() as integer, menu() as string, menuoff() as integer, menutype() as integer, menulimits() as integer, min() as integer, max() as integer, dispmenu() as string, workmenu() as integer, caption() as string, menucapoff() as integer, byref preview_sprite as Frame ptr, preview as Slice Ptr, byval dissolve_ticks as integer, byval EnLimSpawn as integer, byval EnLimAtk as integer, byval EnLimPic as integer, byval EnDatPic as integer, byval EnDatPal as integer, byval EnDatPicSize as integer)

 '--in case new enemies/attacks have been added
 max(EnLimSpawn) = gen(genMaxEnemy) + 1
 max(EnLimAtk) = gen(genMaxAttack) + 1
 max(EnLimDeathSFX) = gen(genMaxSFX) + 1

 '--in case the PicSize has changed
 max(EnLimPic) = gen(genMaxEnemy1Pic + bound(recbuf(EnDatPicSize), 0, 2))
 
 '--re-enforce bounds, as they might have just changed
 enforceflexbounds menuoff(), menutype(), menulimits(), recbuf(), min(), max()
 
 updateflexmenu state.pt, dispmenu(), workmenu(), state.last, menu(), menutype(), menuoff(), menulimits(), recbuf(), caption(), max(), recindex, menucapoff()
 
 '--stop sounds
 resetsfx
 '--update the picture and palette preview
 frame_unload @preview_sprite
 preview_sprite = frame_load(sprTypeSmallEnemy + recbuf(EnDatPicSize), recbuf(EnDatPic))
 dissolve_ticks = -1
 '--resets if dissolved
 ChangeSpriteSlice preview, sprTypeSmallEnemy + recbuf(EnDatPicSize), recbuf(EnDatPic), recbuf(EnDatPal), ,YES

END SUB

'Returns YES if a new record was added, or NO if cancelled.
'When YES, gen(genMaxEnemy) gets updated, and recbuf() will be populated with
'blank or cloned record, and unsaved! Previous contents are discarded.
'TODO: convert to generic_add_new
FUNCTION enemy_edit_add_new (recbuf() as integer, preview_box as Slice ptr) as bool
  DIM enemy as EnemyDef
  DIM menu(2) as string
  DIM enemytocopy as integer = 0
  DIM preview as Slice ptr = preview_box->FirstChild
  DIM state as MenuState
  state.last = UBOUND(menu)
  state.size = 24
  state.pt = 1

  state.need_update = YES
  setkeys
  DO
    setwait 55
    setkeys
    IF keyval(scESC) > 1 THEN setkeys : RETURN NO 'cancel
    IF keyval(scF1) > 1 THEN show_help "enemy_new"
    usemenu state
    IF state.pt = 2 THEN
      IF intgrabber(enemytocopy, 0, gen(genMaxEnemy)) THEN state.need_update = YES
    END IF
    IF state.need_update THEN
      state.need_update = NO
      loadenemydata recbuf(), enemytocopy
      loadenemydata enemy, enemytocopy
      ChangeSpriteSlice preview, 1 + enemy.size, enemy.pic, enemy.pal, , YES

      menu(0) = "Cancel"
      menu(1) = "New Blank Enemy"
      menu(2) = "Copy of Enemy " & enemytocopy & " " & enemy.name
    END IF
    IF enter_space_click(state) THEN
      setkeys
      SELECT CASE state.pt
        CASE 0 ' cancel
          RETURN NO
        CASE 1 ' blank
          gen(genMaxEnemy) += 1
          clearenemydata recbuf()
          RETURN YES
        CASE 2 ' copy
          gen(genMaxEnemy) += 1
          RETURN YES
      END SELECT
    END IF

    clearpage vpage
    standardmenu menu(), state, 20, 20, vpage
    IF state.pt = 2 THEN DrawSlice preview_box, vpage
    setvispage vpage
    dowait
  LOOP
END FUNCTION

