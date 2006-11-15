'OHRRPGCE CUSTOM - Mostly menu-related routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
DEFINT A-Z
'$DYNAMIC
DECLARE FUNCTION pal16browse% (curpal%, usepic%, picx%, picy%, picw%, pich%, picpage%)
DECLARE SUB clearallpages ()
DECLARE SUB writeattackdata (array%(), index%)
DECLARE SUB readattackdata (array%(), index%)
DECLARE SUB standardmenu (menu$(), size%, vis%, pt%, top%, x%, y%, page%, edge%)
DECLARE SUB enforceflexbounds (menuoff%(), menutype%(), menulimits%(), recbuf%(), min%(), max%())
DECLARE SUB setactivemenu (workmenu%(), newmenu%(), pt%, top%, size%)
DECLARE SUB addcaption (caption$(), indexer%, cap$)
DECLARE FUNCTION readenemyname$ (index%)
DECLARE FUNCTION zintgrabber% (n%, min%, max%, less%, more%)
DECLARE FUNCTION readitemname$ (index%)
DECLARE SUB fatalerror (e$)
DECLARE FUNCTION editflexmenu% (nowindex%, menutype%(), menuoff%(), menulimits%(), datablock%(), mintable%(), maxtable%())
DECLARE SUB updateflexmenu (mpointer%, nowmenu$(), nowdat%(), size%, menu$(), menutype%(), menuoff%(), menulimits%(), datablock%(), caption$(), maxtable%(), recindex%)
DECLARE FUNCTION tagstring$ (tag%, zero$, one$, negone$)
DECLARE FUNCTION getbinsize% (id%)
DECLARE SUB setbinsize (id%, size%)
DECLARE FUNCTION readattackname$ (index%)
DECLARE SUB writeglobalstring (index%, s$, maxlen%)
DECLARE FUNCTION readglobalstring$ (index%, default$, maxlen%)
DECLARE SUB importbmp (f$, cap$, count%)
DECLARE SUB getpal16 (array%(), aoffset%, foffset%)
DECLARE SUB upgrade (font%())
DECLARE SUB loadpasdefaults (array%(), tilesetnum%)
DECLARE SUB textxbload (f$, array%(), e$)
DECLARE SUB fixorder (f$)
DECLARE FUNCTION unlumpone% (lumpfile$, onelump$, asfile$)
DECLARE SUB vehicles ()
DECLARE SUB verifyrpg ()
DECLARE FUNCTION getmapname$ (m%)
DECLARE FUNCTION numbertail$ (s$)
DECLARE SUB cropafter (index%, limit%, flushafter%, lump$, bytes%, prompt%)
DECLARE FUNCTION exclude$ (s$, x$)
DECLARE FUNCTION exclusive$ (s$, x$)
DECLARE SUB writescatter (s$, lhold%, start%)
DECLARE SUB readscatter (s$, lhold%, start%)
DECLARE SUB fontedit (font%(), gamedir$)
DECLARE SUB savetanim (n%, tastuf%())
DECLARE SUB loadtanim (n%, tastuf%())
DECLARE SUB cycletile (cycle%(), tastuf%(), pt%(), skip%())
DECLARE SUB testanimpattern (tastuf%(), taset%)
DECLARE FUNCTION heroname$ (num%, cond%(), a%())
DECLARE FUNCTION onoroff$ (n%)
DECLARE FUNCTION lmnemonic$ (index%)
DECLARE SUB smnemonic (tagname$, index%)
DECLARE SUB tagnames ()
DECLARE SUB sizemar (array%(), wide%, high%, tempx%, tempy%, tempw%, temph%, yout%, page%)
DECLARE SUB drawmini (high%, wide%, cursor%(), page%, tastuf%())
DECLARE FUNCTION rotascii$ (s$, o%)
DECLARE SUB mapmaker (font%(), map%(), pass%(), emap%(), doors%(), link%(), npc%(), npcstat%())
DECLARE SUB npcdef (npc%(), pt%)
DECLARE SUB editbitset (array%(), wof%, last%, name$())
DECLARE SUB sprite (xw%, yw%, sets%, perset%, soff%, foff%, atatime%, info$(), size%, zoom%, fileset%, font%())
DECLARE FUNCTION needaddset (pt%, check%, what$)
DECLARE SUB shopdata ()
DECLARE FUNCTION intgrabber (n%, min%, max%, less%, more%)
DECLARE SUB strgrabber (s$, maxl%)
DECLARE SUB importsong ()
DECLARE SUB gendata ()
DECLARE SUB itemdata ()
DECLARE SUB enemydata ()
DECLARE SUB herodata ()
DECLARE SUB attackdata ()
DECLARE SUB getnames (stat$(), max%)
DECLARE SUB statname ()
DECLARE FUNCTION sublist% (num%, s$())
DECLARE SUB maptile (font())
DECLARE FUNCTION itemstr$ (it%, hiden%, offbyone%)
DECLARE FUNCTION isStringField(mnu%)
DECLARE FUNCTION getsfxname$ (num%)

'$INCLUDE: 'compat.bi'
'$INCLUDE: 'allmodex.bi'
'$INCLUDE: 'common.bi'
'$INCLUDE: 'cglobals.bi'

'$INCLUDE: 'const.bi'

REM $STATIC
SUB addcaption (caption$(), indexer, cap$)
IF indexer > UBOUND(caption$) THEN
 fatalerror "caption$(" + STR$(indexer) + ") overflow on " + cap$
ELSE
 caption$(indexer) = cap$
 indexer = indexer + 1
END IF
END SUB

SUB attackdata

DIM sname$(32)
getnames sname$(), 32

DIM workpal(7)

clearallpages
rectangle 259, 139, 52, 52, 7, 3
rectangle 260, 140, 50, 50, 8, 3

'----------------------------------------------------------
'--bitsets

DIM atkbit$(-1 TO 128)

atkbit$(0) = "Cure Instead of Harm"
atkbit$(1) = "Divide Spread Damage"
atkbit$(2) = "Absorb Damage"          'was bounceable!
atkbit$(3) = "Unreversable Picture"
atkbit$(4) = "Steal Item"

FOR i = 0 TO 7
 atkbit$(i + 5) = sname$(i + 17) + " Damage"                   '05-12
 atkbit$(i + 13) = "Bonus vs " + sname$(i + 9)                 '13-20
 atkbit$(i + 21) = "Fail vs " + sname$(i + 17) + " resistance" '21-28
 atkbit$(i + 29) = "Fail vs " + sname$(i + 9)                  '29-36
NEXT i

FOR i = 0 TO 7
 atkbit$(i + 37) = "Cannot target enemy slot" + XSTR$(i)
NEXT i
FOR i = 0 TO 3
 atkbit$(i + 45) = "Cannot target hero slot" + XSTR$(i)
NEXT i

atkbit$(49) = "Ignore attacker's extra hits"
atkbit$(50) = "Erase rewards (Enemy target only)"
atkbit$(51) = "Show damage without inflicting"
atkbit$(52) = "Store Target"
atkbit$(53) = "Delete Stored Target"
atkbit$(54) = "Automaticaly choose target"
atkbit$(55) = "Show attack name"
atkbit$(56) = "Do not display Damage"
atkbit$(57) = "Reset target stat to max before hit"
atkbit$(58) = "Allow Cure to exceed maximum"
atkbit$(59) = "Useable Outside of Battle"
atkbit$(60) = "Damage " + sname$(1) + " (obsolete)"
atkbit$(61) = "Do not randomize"
atkbit$(62) = "Damage can be Zero"
atkbit$(63) = "Cause heroes to run away"
atkbit$(64) = "Mutable"
atkbit$(65) = "Fail if target is poisoned"
atkbit$(66) = "Fail if target is regened"
atkbit$(67) = "Fail if target is stunned"
atkbit$(68) = "Fail if target is muted"
atkbit$(69) = "% based attacks damage instead of set"
'             ^---------------------------------------^
'               the amount of room you have (39 chars)

'--191 attack bits allowed in menu.
'--Data is split, See AtkDatBits and AtkDatBits2 for offsets

'----------------------------------------------------------
DIM recbuf(40 + curbinsize(0) / 2) '--stores the 200 bytes of attack data

CONST AtkDatPic = 0
CONST AtkDatPal = 1
CONST AtkDatAnimPattern = 2
CONST AtkDatTargClass = 3
CONST AtkDatTargSetting = 4
CONST AtkDatDamageEq = 5
CONST AtkDatAimEq = 6
CONST AtkDatBaseAtk = 7
CONST AtkDatMPCost = 8
CONST AtkDatHPCost = 9
CONST AtkDatMoneyCost = 10
CONST AtkDatExtraDamage = 11
CONST AtkDatChainTo = 12
CONST AtkDatChainRate = 13
CONST AtkDatAnimAttacker = 14
CONST AtkDatAnimAttack = 15
CONST AtkDatDelay = 16
CONST AtkDatHitX = 17
CONST AtkDatTargStat = 18
CONST AtkDatBitsets = 20' to 23
CONST AtkDatName = 24'to 35
CONST AtkDatCapTime = 36
CONST AtkDatCaption = 37'to 56
CONST AtkDatCaptDelay = 57
CONST AtkDatBaseDef = 58
CONST AtkDatTag = 59
CONST AtkDatTagIf = 60
CONST AtkDatTagAnd = 61
CONST AtkDatTag2 = 62
CONST AtkDatTagIf2 = 63
CONST AtkDatTagAnd2 = 64
CONST AtkDatBitsets2 = 65' to 72
CONST AtkDatDescription = 73'to 92
CONST AtkDatItem = 93', 95, 97
CONST AtkDatItemCost = 94', 96, 98
CONST AtkDatSoundEffect = 99

'anything past this requires expanding the data


'----------------------------------------------------------
capindex = 0
DIM caption$(120)
DIM max(27), min(27)

'Limit(0) is not used

CONST AtkLimUInt = 8
max(AtkLimUInt) = 32767

CONST AtkLimInt = 9
max(AtkLimInt) = 32767
min(AtkLimInt) = -32767

CONST AtkLimStr10 = 10
max(AtkLimStr10) = 10

CONST AtkLimStr38 = 19
max(AtkLimStr38) = 38

CONST AtkLimPic = 1
max(AtkLimPic) = gen(32)

CONST AtkLimAnimPattern = 2
max(AtkLimAnimPattern) = 3
AtkCapAnimPattern = capindex
addcaption caption$(), capindex, "Cycle Forward"
addcaption caption$(), capindex, "Cycle Back"
addcaption caption$(), capindex, "Oscillate"
addcaption caption$(), capindex, "Random"

CONST AtkLimTargClass = 3
max(AtkLimTargClass) = 10
AtkCapTargClass = capindex
addcaption caption$(), capindex, "Enemy"
addcaption caption$(), capindex, "Ally"
addcaption caption$(), capindex, "Self"
addcaption caption$(), capindex, "All"
addcaption caption$(), capindex, "Ally (Including Dead)"
addcaption caption$(), capindex, "Ally Not Self"
addcaption caption$(), capindex, "Revenge (last hit)"
addcaption caption$(), capindex, "Revenge (whole battle)"
addcaption caption$(), capindex, "Previous target"
addcaption caption$(), capindex, "Recorded target"
addcaption caption$(), capindex, "Dead Allies (hero only)"

CONST AtkLimTargSetting = 4
max(AtkLimTargSetting) = 4
AtkCapTargSetting = capindex
addcaption caption$(), capindex, "Focused"
addcaption caption$(), capindex, "Spread"
addcaption caption$(), capindex, "Optional Spread"
addcaption caption$(), capindex, "Random Focus"
addcaption caption$(), capindex, "First Target"

CONST AtkLimDamageEq = 5
max(AtkLimDamageEq) = 6
AtkCapDamageEq = capindex
addcaption caption$(), capindex, "Normal: ATK - DEF*.5"
addcaption caption$(), capindex, "Blunt: ATK*.8 - DEF*.1"
addcaption caption$(), capindex, "Sharp: ATK*1.3 - DEF"
addcaption caption$(), capindex, "Pure Damage"
addcaption caption$(), capindex, "No Damage"
addcaption caption$(), capindex, "Set = N% of Max"
addcaption caption$(), capindex, "Set = N% of Current"

CONST AtkLimAimEq = 6
max(AtkLimAimEq) = 4
AtkCapAimEq = capindex
addcaption caption$(), capindex, "Normal: " + sname$(3) + "*4 ~ " + sname$(6)
addcaption caption$(), capindex, "Poor: " + sname$(3) + "*2 ~ " + sname$(6)
addcaption caption$(), capindex, "Bad: " + sname$(3) + " ~ " + sname$(6)
addcaption caption$(), capindex, "Never Misses"
addcaption caption$(), capindex, "Magic: " + sname$(29) + " ~ " + sname$(30) + "*1.25"

CONST AtkLimBaseAtk = 7
max(AtkLimBaseAtk) = 20
AtkCapBaseAtk = capindex
addcaption caption$(), capindex, sname$(2)  'str
addcaption caption$(), capindex, sname$(29)  'mag
addcaption caption$(), capindex, sname$(0)   'hp
addcaption caption$(), capindex, "Lost " + sname$(0)  'hp
addcaption caption$(), capindex, "Random 0 to 999"
addcaption caption$(), capindex, "100"
addcaption caption$(), capindex, sname$(0) 'hp
addcaption caption$(), capindex, sname$(1) 'mp
addcaption caption$(), capindex, sname$(2) 'atk
addcaption caption$(), capindex, sname$(3) 'aim
addcaption caption$(), capindex, sname$(5) 'def
addcaption caption$(), capindex, sname$(6) 'dog
addcaption caption$(), capindex, sname$(29) 'mag
addcaption caption$(), capindex, sname$(30) 'wil
addcaption caption$(), capindex, sname$(8) 'spd
addcaption caption$(), capindex, sname$(7)'ctr
addcaption caption$(), capindex, sname$(31)'focus
addcaption caption$(), capindex, sname$(4) 'hitX
addcaption caption$(), capindex, "previous attack"
addcaption caption$(), capindex, "last damage to attacker"
addcaption caption$(), capindex, "last damage to target"

CONST AtkLimExtraDamage = 11
max(AtkLimExtraDamage) = 1000
min(AtkLimExtraDamage) = -100

CONST AtkLimChainTo = 12
max(AtkLimChainTo) = gen(34) + 1'--must be updated!

CONST AtkLimChainRate = 13
max(AtkLimChainRate) = 100

CONST AtkLimAnimAttacker = 14
max(AtkLimAnimAttacker) = 8
AtkCapAnimAttacker = capindex
addcaption caption$(), capindex, "Strike"
addcaption caption$(), capindex, "Cast"
addcaption caption$(), capindex, "Dash In"
addcaption caption$(), capindex, "SpinStrike"
addcaption caption$(), capindex, "Jump (chain to Land)"
addcaption caption$(), capindex, "Land"
addcaption caption$(), capindex, "Null"
addcaption caption$(), capindex, "Standing Cast"
addcaption caption$(), capindex, "Teleport"

CONST AtkLimAnimAttack = 15
max(AtkLimAnimAttack) = 10
AtkCapAnimAttack = capindex
addcaption caption$(), capindex, "Normal"
addcaption caption$(), capindex, "Projectile"
addcaption caption$(), capindex, "Reverse Projectile"
addcaption caption$(), capindex, "Drop"
addcaption caption$(), capindex, "Ring"
addcaption caption$(), capindex, "Wave"
addcaption caption$(), capindex, "Scatter"
addcaption caption$(), capindex, "Sequential Projectile"
addcaption caption$(), capindex, "Meteor"
addcaption caption$(), capindex, "Driveby"
addcaption caption$(), capindex, "Null"

CONST AtkLimDelay = 16
max(AtkLimDelay) = 1000

CONST AtkLimHitX = 17
max(AtkLimHitX) = 20
min(AtkLimHitX) = 1

CONST AtkLimTargStat = 18
max(AtkLimTargStat) = 15
AtkCapTargStat = capindex
addcaption caption$(), capindex, sname$(0) 'hp
addcaption caption$(), capindex, sname$(1) 'mp
addcaption caption$(), capindex, sname$(2) 'atk
addcaption caption$(), capindex, sname$(3) 'aim
addcaption caption$(), capindex, sname$(5) 'def
addcaption caption$(), capindex, sname$(6) 'dog
addcaption caption$(), capindex, sname$(29) 'mag
addcaption caption$(), capindex, sname$(30) 'wil
addcaption caption$(), capindex, sname$(8) 'spd
addcaption caption$(), capindex, sname$(7) 'ctr
addcaption caption$(), capindex, sname$(31) 'focus
addcaption caption$(), capindex, sname$(4) 'hitX
addcaption caption$(), capindex, "poison register"
addcaption caption$(), capindex, "regen register"
addcaption caption$(), capindex, "stun register"
addcaption caption$(), capindex, "mute register"

CONST AtkLimCapTime = 20
max(AtkLimCapTime) = 16383
min(AtkLimCapTime) = -1
addcaption caption$(), capindex, "Ticks"
AtkCapCapTime = capindex
addcaption caption$(), capindex, "Full Duration of Attack"
addcaption caption$(), capindex, "Not at All"

CONST AtkLimCaptDelay = 21
max(AtkLimCaptDelay) = 16383
min(AtkLimCaptDelay) = 0

CONST AtkLimBaseDef = 22
max(AtkLimBaseDef) = 12
AtkCapBaseDef = capindex
addcaption caption$(), capindex, "Default"
addcaption caption$(), capindex, sname$(0) 'hp
addcaption caption$(), capindex, sname$(1) 'mp
addcaption caption$(), capindex, sname$(2) 'atk
addcaption caption$(), capindex, sname$(3) 'aim
addcaption caption$(), capindex, sname$(5) 'def
addcaption caption$(), capindex, sname$(6) 'dog
addcaption caption$(), capindex, sname$(29) 'mag
addcaption caption$(), capindex, sname$(30) 'wil
addcaption caption$(), capindex, sname$(8) 'spd
addcaption caption$(), capindex, sname$(7) 'ctr
addcaption caption$(), capindex, sname$(31) 'focus
addcaption caption$(), capindex, sname$(4) 'hitX

CONST AtkLimTag = 23
max(AtkLimTag) = 1000
min(AtkLimTag) = -1000

CONST AtkLimTagIf = 24
max(AtkLimTagIf) = 4
AtkCapTagIf = capindex
addcaption caption$(), capindex, "Never" '0
addcaption caption$(), capindex, "Use"   '1
addcaption caption$(), capindex, "Hit"   '2
addcaption caption$(), capindex, "Miss"  '3
addcaption caption$(), capindex, "Kill"  '4

CONST AtkLimTagAnd = 25
max(AtkLimTag) = 1000
min(AtkLimTag) = -1000

CONST AtkLimItem = 26
max(AtkLimItem) = 255
min(AtkLimItem) = 0

CONST AtkLimSfx = 27
max(AtkLimSfx) = gen(genMaxSFX) + 1
min(AtkLimSfx) = 0

'next limit is 28 (remember to update the dim)

'----------------------------------------------------------------------
'--menu content
CONST MnuItems = 46
DIM menu$(MnuItems), menutype(MnuItems), menuoff(MnuItems), menulimits(MnuItems)

CONST AtkBackAct = 0
menu$(AtkBackAct) = "Previous Menu"
menutype(AtkBackAct) = 1

CONST AtkName = 1
menu$(AtkName) = "Name:"
menutype(AtkName) = 6
menuoff(AtkName) = AtkDatName
menulimits(AtkName) = AtkLimStr10

CONST AtkAppearAct = 2
menu$(AtkAppearAct) = "Appearance..."
menutype(AtkAppearAct) = 1

CONST AtkDmgAct = 3
menu$(AtkDmgAct) = "Damage Settings..."
menutype(AtkDmgAct) = 1

CONST AtkTargAct = 4
menu$(AtkTargAct) = "Target Settings..."
menutype(AtkTargAct) = 1

CONST AtkCostAct = 5
menu$(AtkCostAct) = "Cost..."
menutype(AtkCostAct) = 1

CONST AtkChainAct = 6
menu$(AtkChainAct) = "Chaining..."
menutype(AtkChainAct) = 1

CONST AtkBitAct = 7
menu$(AtkBitAct) = "Bitsets..."
menutype(AtkBitAct) = 1

CONST AtkPic = 8
menu$(AtkPic) = "Picture:"
menutype(AtkPic) = 0
menuoff(AtkPic) = AtkDatPic
menulimits(AtkPic) = AtkLimPic

CONST AtkPal = 9
menu$(AtkPal) = "Palette:"
menutype(AtkPal) = 0
menuoff(AtkPal) = AtkDatPal
menulimits(AtkPal) = AtkLimUInt

CONST AtkAnimPattern = 10
menu$(AtkAnimPattern) = "Animation Pattern:"
menutype(AtkAnimPattern) = 2000 + AtkCapAnimPattern
menuoff(AtkAnimPattern) = AtkDatAnimPattern
menulimits(AtkAnimPattern) = AtkLimAnimPattern

CONST AtkTargClass = 11
menu$(AtkTargClass) = "Target Class:"
menutype(AtkTargClass) = 2000 + AtkCapTargClass
menuoff(AtkTargClass) = AtkDatTargClass
menulimits(AtkTargClass) = AtkLimTargClass

CONST AtkTargSetting = 12
menu$(AtkTargSetting) = "Target Setting:"
menutype(AtkTargSetting) = 2000 + AtkCapTargSetting
menuoff(AtkTargSetting) = AtkDatTargSetting
menulimits(AtkTargSetting) = AtkLimTargSetting

CONST AtkChooseAct = 13
menu$(AtkChooseAct) = "Attack"
menutype(AtkChooseAct) = 5

CONST AtkDamageEq = 14
menu$(AtkDamageEq) = "Damage Math:"
menutype(AtkDamageEq) = 2000 + AtkCapDamageEq
menuoff(AtkDamageEq) = AtkDatDamageEq
menulimits(AtkDamageEq) = AtkLimDamageEq

CONST AtkAimEq = 15
menu$(AtkAimEq) = "Aim Math:"
menutype(AtkAimEq) = 2000 + AtkCapAimEq
menuoff(AtkAimEq) = AtkDatAimEq
menulimits(AtkAimEq) = AtkLimAimEq

CONST AtkBaseAtk = 16
menu$(AtkBaseAtk) = "Base ATK Stat:"
menutype(AtkBaseAtk) = 2000 + AtkCapBaseAtk
menuoff(AtkBaseAtk) = AtkDatBaseAtk
menulimits(AtkBaseAtk) = AtkLimBaseAtk

CONST AtkMPCost = 17
menu$(AtkMPCost) = sname$(1) + " Cost:"
menutype(AtkMPCost) = 0
menuoff(AtkMPCost) = AtkDatMPCost
menulimits(AtkMPCost) = AtkLimInt

CONST AtkHPCost = 18
menu$(AtkHPCost) = sname$(0) + " Cost:"
menutype(AtkHPCost) = 0
menuoff(AtkHPCost) = AtkDatHPCost
menulimits(AtkHPCost) = AtkLimInt

CONST AtkMoneyCost = 19
menu$(AtkMoneyCost) = sname$(32) + " Cost:"
menutype(AtkMoneyCost) = 0
menuoff(AtkMoneyCost) = AtkDatMoneyCost
menulimits(AtkMoneyCost) = AtkLimInt

CONST AtkExtraDamage = 20
menu$(AtkExtraDamage) = "Extra Damage%:"
menutype(AtkExtraDamage) = 0
menuoff(AtkExtraDamage) = AtkDatExtraDamage
menulimits(AtkExtraDamage) = AtkLimExtraDamage

CONST AtkChainTo = 21
menu$(AtkChainTo) = "Chain to:"
menutype(AtkChainTo) = 7 '--special class for showing an attack name
menuoff(AtkChainTo) = AtkDatChainTo
menulimits(AtkChainTo) = AtkLimChainTo

CONST AtkChainRate = 22
menu$(AtkChainRate) = "Chain Rate%:"
menutype(AtkChainRate) = 0
menuoff(AtkChainRate) = AtkDatChainRate
menulimits(AtkChainRate) = AtkLimChainRate

CONST AtkAnimAttacker = 23
menu$(AtkAnimAttacker) = "Attacker Animation:"
menutype(AtkAnimAttacker) = 2000 + AtkCapAnimAttacker
menuoff(AtkAnimAttacker) = AtkDatAnimAttacker
menulimits(AtkAnimAttacker) = AtkLimAnimAttacker

CONST AtkAnimAttack = 24
menu$(AtkAnimAttack) = "Attack Animation:"
menutype(AtkAnimAttack) = 2000 + AtkCapAnimAttack
menuoff(AtkAnimAttack) = AtkDatAnimAttack
menulimits(AtkAnimAttack) = AtkLimAnimAttack

CONST AtkDelay = 25
menu$(AtkDelay) = "Delay Before Attack:"
menutype(AtkDelay) = 0
menuoff(AtkDelay) = AtkDatDelay
menulimits(AtkDelay) = AtkLimDelay

CONST AtkHitX = 26
menu$(AtkHitX) = "Number of Hits:"
menutype(AtkHitX) = 0
menuoff(AtkHitX) = AtkDatHitX
menulimits(AtkHitX) = AtkLimHitX

CONST AtkTargStat = 27
menu$(AtkTargStat) = "Target Stat:"
menutype(AtkTargStat) = 2000 + AtkCapTargStat
menuoff(AtkTargStat) = AtkDatTargStat
menulimits(AtkTargStat) = AtkLimTargStat

CONST AtkCaption = 28
menu$(AtkCaption) = "Caption:"
menutype(AtkCaption) = 3'goodstring
menuoff(AtkCaption) = AtkDatCaption
menulimits(AtkCaption) = AtkLimStr38

CONST AtkCapTime = 29
menu$(AtkCapTime) = "Display Caption:"
menutype(AtkCapTime) = 3000 + AtkCapCapTime
menuoff(AtkCapTime) = AtkDatCapTime
menulimits(AtkCapTime) = AtkLimCapTime

CONST AtkCaptDelay = 30
menu$(AtkCaptDelay) = "Delay Before Caption:"
menutype(AtkCaptDelay) = 0
menuoff(AtkCaptDelay) = AtkDatCaptDelay
menulimits(AtkCaptDelay) = AtkLimCaptDelay

CONST AtkBaseDef = 31
menu$(AtkBaseDef) = "Base DEF Stat:"
menutype(AtkBaseDef) = 2000 + AtkCapBaseDef
menuoff(AtkBaseDef) = AtkDatBaseDef
menulimits(AtkBaseDef) = AtkLimBaseDef

CONST AtkTag = 32
menu$(AtkTag) = "Set Tag"
menutype(AtkTag) = 2
menuoff(AtkTag) = AtkDatTag
menulimits(AtkTag) = AtkLimTag

CONST AtkTagIf = 33
menu$(AtkTagIf) = "On"
menutype(AtkTagIf) = 2000 + AtkCapTagIf
menuoff(AtkTagIf) = AtkDatTagIf
menulimits(AtkTagIf) = AtkLimTagIf

CONST AtkTagAnd = 34
menu$(AtkTagAnd) = "If Tag"
menutype(AtkTagAnd) = 2
menuoff(AtkTagAnd) = AtkDatTagAnd
menulimits(AtkTagAnd) = AtkLimTagAnd

CONST AtkTag2 = 35
menu$(AtkTag2) = "Set Tag"
menutype(AtkTag2) = 2
menuoff(AtkTag2) = AtkDatTag2
menulimits(AtkTag2) = AtkLimTag

CONST AtkTagIf2 = 36
menu$(AtkTagIf2) = "On"
menutype(AtkTagIf2) = 2000 + AtkCapTagIf
menuoff(AtkTagIf2) = AtkDatTagIf2
menulimits(AtkTagIf2) = AtkLimTagIf

CONST AtkTagAnd2 = 37
menu$(AtkTagAnd2) = "If Tag"
menutype(AtkTagAnd2) = 2
menuoff(AtkTagAnd2) = AtkDatTagAnd2
menulimits(AtkTagAnd2) = AtkLimTagAnd

CONST AtkTagAct = 38
menu$(AtkTagAct) = "Tags..."
menutype(AtkTagAct) = 1

CONST AtkDescription = 39
menu$(AtkDescription) = "Description: "
menutype(AtkDescription) = 3
menuoff(AtkDescription) = AtkDatDescription
menulimits(AtkDescription) = AtkLimStr38

CONST AtkItem1 = 40
menu$(AtkItem1) = "Item 1:"
menutype(AtkItem1) = 10
menuoff(AtkItem1) = AtkDatItem
menulimits(AtkItem1) = AtkLimItem

CONST AtkItemCost1 = 41
menu$(AtkItemCost1) = "  Cost:"
menutype(AtkItemCost1) = 0
menuoff(AtkItemCost1) = AtkDatItemCost
menulimits(AtkItemCost1) = AtkLimInt

CONST AtkItem2 = 42
menu$(AtkItem2) = "Item 2:"
menutype(AtkItem2) = 10
menuoff(AtkItem2) = AtkDatItem + 2
menulimits(AtkItem2) = AtkLimItem

CONST AtkItemCost2 = 43
menu$(AtkItemCost2) = "  Cost:"
menutype(AtkItemCost2) = 0
menuoff(AtkItemCost2) = AtkDatItemCost + 2
menulimits(AtkItemCost2) = AtkLimInt

CONST AtkItem3 = 44
menu$(AtkItem3) = "Item 3:"
menutype(AtkItem3) = 10
menuoff(AtkItem3) = AtkDatItem + 4
menulimits(AtkItem3) = AtkLimItem

CONST AtkItemCost3 = 45
menu$(AtkItemCost3) = "  Cost:"
menutype(AtkItemCost3) = 0
menuoff(AtkItemCost3) = AtkDatItemCost + 4
menulimits(AtkItemCost3) = AtkLimInt

CONST AtkSoundEffect = 46
menu$(AtkSoundEffect) = "Sound Effect:"
menutype(AtkSoundEffect) = 11
menuoff(AtkSoundEffect) = AtkDatSoundEffect
menulimits(AtkSoundEffect) = AtkLimSFX

'Next menu item is 47 (remember to update the dims)

'----------------------------------------------------------
'--menu structure
DIM workmenu(20), dispmenu$(20)
pt = 0: top = 0: size = 0

DIM mainMenu(10)
mainMenu(0) = AtkBackAct
mainMenu(1) = AtkChooseAct
mainMenu(2) = AtkName
mainMenu(3) = AtkCaption
mainMenu(4) = AtkAppearAct
mainMenu(5) = AtkDmgAct
mainMenu(6) = AtkTargAct
mainMenu(7) = AtkCostAct
mainMenu(8) = AtkChainAct
mainMenu(9) = AtkBitAct
mainMenu(10) = AtkTagAct

DIM appearMenu(9)
appearMenu(0) = AtkBackAct
appearMenu(1) = AtkPic
appearMenu(2) = AtkPal
appearMenu(3) = AtkAnimAttack
appearMenu(4) = AtkAnimPattern
appearMenu(5) = AtkAnimAttacker
appearMenu(6) = AtkCapTime
appearMenu(7) = AtkCaptDelay
appearMenu(8) = AtkDescription
appearMenu(9) = AtkSoundEffect

DIM dmgMenu(8)
dmgMenu(0) = AtkBackAct
dmgMenu(1) = AtkDamageEq
dmgMenu(2) = AtkBaseAtk
dmgMenu(3) = AtkBaseDef
dmgMenu(4) = AtkTargStat
dmgMenu(5) = AtkExtraDamage
dmgMenu(6) = AtkAimEq
dmgMenu(7) = AtkHitX
dmgMenu(8) = AtkDelay

DIM targMenu(2)
targMenu(0) = AtkBackAct
targMenu(1) = AtkTargClass
targMenu(2) = AtkTargSetting

DIM costMenu(9)
costMenu(0) = AtkBackAct
costMenu(1) = AtkMPCost
costMenu(2) = AtkHPCost
costMenu(3) = AtkMoneyCost
costMenu(4) = AtkItem1
costMenu(5) = AtkItemCost1
costMenu(6) = AtkItem2
costMenu(7) = AtkItemCost2
costMenu(8) = AtkItem3
costMenu(9) = AtkItemCost3

DIM chainMenu(2)
chainMenu(0) = AtkBackAct
chainMenu(1) = AtkChainTo
chainMenu(2) = AtkChainRate

DIM tagMenu(6)
tagMenu(0) = AtkBackAct
tagMenu(1) = AtkTagIf
tagMenu(2) = AtkTagAnd
tagMenu(3) = AtkTag
tagMenu(4) = AtkTagIf2
tagMenu(5) = AtkTagAnd2
tagMenu(6) = AtkTag2

'--default starting menu
setactivemenu workmenu(), mainMenu(), pt, top, size

menudepth = 0
lastptr = 0
lasttop = 0
recindex = 0

'load data here
GOSUB AtkLoadSub

'------------------------------------------------------------------------
'--main loop

setkeys
DO
 setwait timing(), 100
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN
  IF menudepth = 1 THEN
   GOSUB AtkBackSub
  ELSE
   EXIT DO
  END IF
 END IF

 '--CTRL+BACKSPACE
 IF keyval(29) > 0 AND keyval(14) THEN
  cropafter recindex, gen(34), 0, game$ + ".dt6", 80, 1
  '--this is a hack to detect if it is safe to erase the extended data
  '--in the second file
  IF recindex = gen(34) THEN
   '--delete the end of attack.bin without the need to prompt
   cropafter recindex, gen(34), 0, workingdir$ + SLASH + "attack.bin", getbinsize(0), 0
  END IF
 END IF

 dummy = usemenu(pt, top, 0, size, 22)

 IF workmenu(pt) = AtkChooseAct OR (keyval(56) > 0 and NOT isStringField(menutype(workmenu(pt)))) THEN
  lastindex = recindex
  IF keyval(77) > 1 AND recindex = gen(34) AND recindex < 32767 THEN
   '--attempt to add a new set
   '--save current
   writeattackdata recbuf(), lastindex
   '--increment
   recindex = recindex + 1
   '--make sure we really have permission to increment
   IF needaddset(recindex, gen(34), "attack") THEN
    flusharray recbuf(), 39 + curbinsize(0) / 2, 0
    GOSUB AtkUpdateMenu
   END IF
  ELSE
   IF intgrabber(recindex, 0, gen(34), 75, 77) THEN
    writeattackdata recbuf(), lastindex
    GOSUB AtkLoadSub
   END IF
  END IF
 END IF

 IF keyval(28) > 1 OR keyval(57) > 1 THEN
  SELECT CASE workmenu(pt)
   CASE AtkBackAct
    IF menudepth = 1 THEN
     GOSUB AtkBackSub
    ELSE
     EXIT DO
    END IF
   CASE AtkAppearAct
    GOSUB AtkPushPtrSub
    setactivemenu workmenu(), appearMenu(), pt, top, size
    GOSUB AtkUpdateMenu
   CASE AtkDmgAct
    GOSUB AtkPushPtrSub
    setactivemenu workmenu(), dmgMenu(), pt, top, size
    GOSUB AtkUpdateMenu
   CASE AtkTargAct
    GOSUB AtkPushPtrSub
    setactivemenu workmenu(), targMenu(), pt, top, size
    GOSUB AtkUpdateMenu
   CASE AtkCostAct
    GOSUB AtkPushPtrSub
    setactivemenu workmenu(), costMenu(), pt, top, size
    GOSUB AtkUpdateMenu
   CASE AtkChainAct
    GOSUB AtkPushPtrSub
    setactivemenu workmenu(), chainMenu(), pt, top, size
    GOSUB AtkUpdateMenu
   CASE AtkTagAct
    GOSUB AtkPushPtrSub
    setactivemenu workmenu(), tagMenu(), pt, top, size
    GOSUB AtkUpdateMenu
   CASE AtkPal
    recbuf(AtkDatPal) = pal16browse(recbuf(AtkDatPal), 3, 0, 0, 50, 50, 2)
    GOSUB AtkUpdateMenu
   CASE AtkBitAct
    'merge the two blocks of bitsets into the buffer
    FOR i = 0 TO 3
     buffer(i) = recbuf(AtkDatBitsets + i)
    NEXT i
    FOR i = 0 TO 7
     buffer(4 + i) = recbuf(AtkDatBitsets2 + i)
    NEXT i
    editbitset buffer(), 0, UBOUND(atkbit$), atkbit$()
    'split the buffer to the two bitset blocks
    FOR i = 0 TO 3
     recbuf(AtkDatBitsets + i) = buffer(i)
    NEXT i
    FOR i = 0 TO 7
     recbuf(AtkDatBitsets2 + i) = buffer(4 + i)
    NEXT i
  END SELECT
 END IF

 IF keyval(56) = 0 or isStringField(menutype(workmenu(pt))) THEN 'not pressing ALT, or not allowed to
  IF editflexmenu(workmenu(pt), menutype(), menuoff(), menulimits(), recbuf(), min(), max()) THEN
   GOSUB AtkUpdateMenu
  END IF
 END IF

 GOSUB AtkPreviewSub

 standardmenu dispmenu$(), size, 22, pt, top, 0, 0, dpage, 0
 IF keyval(56) > 0 THEN 'holding ALT
   tmp$ = readbadbinstring$(recbuf(), AtkDatName, 10, 1) + XSTR$(recindex)
   textcolor 15, 1
   printstr tmp$, 320 - LEN(tmp$) * 8, 0, dpage
 END IF

 SWAP vpage, dpage
 setvispage vpage
 copypage 3, dpage
 dowait
LOOP

'--save what we were last working on
writeattackdata recbuf(), recindex

clearallpages

EXIT SUB

'-----------------------------------------------------------------------

AtkUpdateMenu:

'--in case new attacks have been added
max(AtkLimChainTo) = gen(34) + 1

'--re-enforce bounds, as they might have just changed
enforceflexbounds menuoff(), menutype(), menulimits(), recbuf(), min(), max()

'--damage eqation shows current base stats
''caption$(AtkCapDamageEq) = "Normal: " + caption$(AtkCapBaseAtk + recbuf(AtkDatBaseAtk)) + " - " + sname$(5) + "*.5"
''caption$(AtkCapDamageEq + 1) = "Blunt: " + caption$(AtkCapBaseAtk + recbuf(AtkDatBaseAtk)) + "*.8 - " + sname$(5) + "*.1"
''caption$(AtkCapDamageEq + 2) = "Sharp: " + caption$(AtkCapBaseAtk + recbuf(AtkDatBaseAtk)) + "*1.3 - " + sname$(5)
''caption$(AtkCapDamageEq + 3) = "Pure Damage: " + caption$(AtkCapBaseAtk + recbuf(AtkDatBaseAtk))

'--percentage damage shows target stat
caption$(AtkCapDamageEq + 5) = caption$(AtkCapTargStat + recbuf(AtkDatTargStat)) + " =" + XSTR$(100 + recbuf(AtkDatExtraDamage)) + "% of Maximum"
caption$(AtkCapDamageEq + 6) = caption$(AtkCapTargStat + recbuf(AtkDatTargStat)) + " =" + XSTR$(100 + recbuf(AtkDatExtraDamage)) + "% of Current"

updateflexmenu pt, dispmenu$(), workmenu(), size, menu$(), menutype(), menuoff(), menulimits(), recbuf(), caption$(), max(), recindex

'--load the picture and palette
setpicstuf buffer(), 3750, 2
loadset game$ + ".pt6", recbuf(AtkDatPic), 0
getpal16 workpal(), 0, recbuf(AtkDatPal)

RETRACE

'-----------------------------------------------------------------------

AtkPreviewSub:
anim0 = anim0 + 1
IF anim0 > 3 THEN
 anim0 = 0
 IF recbuf(AtkDatAnimPattern) = 0 THEN anim1 = anim1 + 1: IF anim1 > 2 THEN anim1 = 0
 IF recbuf(AtkDatAnimPattern) = 1 THEN anim1 = anim1 - 1: IF anim1 < 0 THEN anim1 = 2
 IF recbuf(AtkDatAnimPattern) = 2 THEN anim1 = anim1 + 1: IF anim1 > 2 THEN anim1 = -1
 IF recbuf(AtkDatAnimPattern) = 3 THEN anim1 = INT(RND * 3)
END IF

loadsprite buffer(), 0, 1250 * ABS(anim1), 0, 50, 50, 2
drawsprite buffer(), 0, workpal(), 0, 260, 140, dpage
RETRACE

'-----------------------------------------------------------------------

AtkBackSub:
setactivemenu workmenu(), mainMenu(), pt, top, size
menudepth = 0
pt = lastptr
top = lasttop
GOSUB AtkUpdateMenu
RETRACE

'-----------------------------------------------------------------------

AtkPushPtrSub:
lastptr = pt
lasttop = top
menudepth = 1
RETRACE

'-----------------------------------------------------------------------

AtkLoadSub:
readattackdata recbuf(), recindex
GOSUB AtkUpdateMenu
RETRACE

'-----------------------------------------------------------------------
'DATA Picture,Palette,"Animation:","Target Class:","Target Setting:",Damage,Aim,"Base Stat:","","",Money Cost,"Extra Damage%","Chain to:",Chain%,"Attacker Motion:","Attack Motion:",Delay,Number of Hits,"Target Stat:",Edit Bitsets...,"Name="
'DATA 0,0,0,0,0,0,0,0,-999,-9999,-32767,-100,0,0,0,0,0,1,0
'DATA 99,32767,3,9,4,6,4,20,999,9999,32767,1000,300,100,8,10,1000,20,11

END SUB

FUNCTION editflexmenu (nowindex, menutype(), menuoff(), menulimits(), datablock(), mintable(), maxtable())
'--returns true if data has changed, false it not

'nowindex is the index into the menu data of the currently selected menuitem
'menutype() holds the type of each menu element.
'           0=int
'           1=action (usually triggering a different menu)
'           2=set tag
'           3=string(bybyte)
'           4=badly stored string(by word)
'           5=chooser (not connected with data)
'           6=extra badly stored string(by word with gap)
'           7=attack number (offset!)
'           8=item number (not offset)
'           10=item number (offset!)
'           1000-1999=postcaptioned int (caption-start-offset=n-1000)
'                     (be careful about negatives!)
'           2000-2999=caption-only int (caption-start-offset=n-1000)
'                     (be careful about negatives!)
'           3000-3999=multi-state (uses caption index -1 too!)
'menuoff() is the offsets into the data block where each menu data is stored
'menulimits() is the offsets into the mintable() and maxtable() arrays
'datablock() holds the actual data
'mintable() is minimum integer values
'maxtable() is maximum int values and string limits

changed = 0

SELECT CASE menutype(nowindex)
 CASE 0, 8, 1000 TO 3999' integers
  changed = intgrabber(datablock(menuoff(nowindex)), mintable(menulimits(nowindex)), maxtable(menulimits(nowindex)), 75, 77)
 CASE 7, 9 TO 11 'offset integers
  changed = zintgrabber(datablock(menuoff(nowindex)), mintable(menulimits(nowindex)) - 1, maxtable(menulimits(nowindex)) - 1, 75, 77)
 CASE 2' set tag
  changed = intgrabber(datablock(menuoff(nowindex)), -999, 999, 75, 77)
 CASE 3' string
  a$ = readbinstring$(datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)))
  old$ = a$
  strgrabber a$, maxtable(menulimits(nowindex))
  IF old$ <> a$ THEN changed = 1
  writebinstring a$, datablock(), menuoff(nowindex), maxtable(menulimits(nowindex))
 CASE 4' badly stored string
  a$ = readbadbinstring$(datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 0)
  old$ = a$
  strgrabber a$, maxtable(menulimits(nowindex))
  IF old$ <> a$ THEN changed = 1
  writebadbinstring a$, datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 0
 CASE 6' extra badly stored string
  a$ = readbadbinstring$(datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 1)
  old$ = a$
  strgrabber a$, maxtable(menulimits(nowindex))
  IF old$ <> a$ THEN changed = 1
  writebadbinstring a$, datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 1
END SELECT

editflexmenu = changed

END FUNCTION

SUB enforceflexbounds (menuoff(), menutype(), menulimits(), recbuf(), min(), max())

FOR i = 0 TO UBOUND(menuoff)
 SELECT CASE menutype(i)
  CASE 0, 1000 TO 3999
   '--bound ints
   IF menulimits(i) > 0 THEN
    '--only bound items that have real limits
    recbuf(menuoff(i)) = bound(recbuf(menuoff(i)), min(menulimits(i)), max(menulimits(i)))
   END IF
 END SELECT
NEXT i

END SUB

SUB setactivemenu (workmenu(), newmenu(), pt, top, size)
FOR i = 0 TO UBOUND(newmenu)
 workmenu(i) = newmenu(i)
NEXT i
pt = 0
top = 0
size = UBOUND(newmenu)
END SUB

FUNCTION tagstring$ (tag, zero$, one$, negone$)

SELECT CASE tag
 CASE 0
  result$ = zero$
 CASE 1
  result$ = one$
 CASE -1
  result$ = negone$
 CASE ELSE
  result$ = STR$(ABS(tag)) + "=" + onoroff$(tag) + " (" + lmnemonic$(ABS(tag)) + ")"
END SELECT

tagstring$ = result$
END FUNCTION

SUB testflexmenu
'
''--fake data block--------------------------------------------------------
'DIM dat(99)
'
'CONST TESTDATfingers = 0
'CONST TESTDATeyes = 1
'CONST TESTDATname = 2
'CONST TESTDATtag = 11
'CONST TESTDAThandedness = 12
'
''--dim the tables---------------------------------------------------------
'DIM caption$(10), min(10), max(10)
'
''--caption table----------------------------------------------------------
'
'CONST TESTCAPhandedness = 1
'caption$(1) = "Lefthand"
'caption$(2) = "Righthand"
'caption$(3) = "Abidexterous"
'
''--min/max tables---------------------------------------------------------
'
'CONST LIMITfingers = 0
'min(LIMITfingers) = 0
'max(LIMITfingers) = 10
'
'CONST LIMITeyes = 1
'min(LIMITeyes) = 0
'max(LIMITeyes) = 2
'
'CONST LIMITstring20 = 2
'max(LIMITstring20) = 20
'
'CONST LIMITstring8 = 3
'max(LIMITstring8) = 8
'
'CONST LIMITtristate = 4
'max(LIMITtristate) = 2
'
''--the menu---------------------------------------------------------------
'DIM menu$(20), menutype(20), menuoff(20), menulimits(20)
'
'CONST TESTmenuReturn = 0
'menu$(TESTmenuReturn) = "return to main menu"
'menutype(TESTmenuReturn) = 1'action
'
'CONST TESTmenuAct = 1
'menu$(TESTmenuAct) = "some action..."
'menutype(TESTmenuAct) = 1'action
'
'CONST TESTmenuFing = 2
'menu$(TESTmenuFing) = "number of fingers"
'menutype(TESTmenuFing) = 0
'menuoff(TESTmenuFing) = TESTDATfingers
'menulimits(TESTmenuFing) = LIMITfingers
'
'CONST TESTmenuEyes = 3
'menu$(TESTmenuEyes) = "number of eyes"
'menutype(TESTmenuEyes) = 0
'menuoff(TESTmenuEyes) = TESTDATeyes
'menulimits(TESTmenuEyes) = LIMITeyes
'
'CONST TESTmenuName = 4
'menu$(TESTmenuName) = "Name:"
'menutype(TESTmenuName) = 4'wordstring
'menuoff(TESTmenuName) = TESTDATname
'menulimits(TESTmenuName) = LIMITstring8
'
'CONST TESTmenuTag = 5
'menu$(TESTmenuTag) = "Tag:"
'menutype(TESTmenuTag) = 2'tag
'menuoff(TESTmenuTag) = TESTDATtag
'
'CONST TESTmenuhandedness = 6
'menu$(TESTmenuhandedness) = "Hand:"
'menutype(TESTmenuhandedness) = 2000 + TESTCAPhandedness
'menuoff(TESTmenuhandedness) = TESTDAThandedness
'menulimits(TESTmenuhandedness) = LIMITtristate
'
''--menu pointers---------------------------------------------------------
'DIM pt(3), top(3), size(3)
'
'--current working menu
'DIM thismenu(22), showmenu$(22)
'
'size(0) = 6
'thismenu(0) = TESTmenuReturn
'thismenu(1) = TESTmenuName
'thismenu(2) = TESTmenuEyes
'thismenu(3) = TESTmenuFing
'thismenu(4) = TESTmenuhandedness
'thismenu(5) = TESTmenuTag
'thismenu(6) = TESTmenuAct
'
''-------
'mode = 0
'
'updateflexmenu pt, showmenu$(), thismenu(), size(mode), menu$(), menutype(), menuoff(), menulimits(), dat(), caption$(), max(), recindex
'
'setkeys
'DO
'  setwait timing(), 100
'  setkeys
'  tog = tog XOR 1
'  IF keyval(1) > 1 THEN EXIT DO
'
'  dummy = usemenu(pt(mode), top(mode), 0, size(mode), 22)
'
'  IF editflexmenu(thismenu(pt(mode)), menutype(), menuoff(), menulimits(), dat(), min(), max()) THEN
'    updateflexmenu pt, showmenu$(), thismenu(), size(mode), menu$(), menutype(), menuoff(), menulimits(), dat(), caption$(), max(), recindex
'  END IF
'
'  standardmenu showmenu$(), size(mode), 22, pt(mode), top(mode), 0, 0, dpage, 0
'
'  FOR i = 0 TO 19
'    printstr XSTR$(dat(i)), i * 20, 180, dpage
'  NEXT i
'
'  SWAP vpage, dpage
'  setvispage vpage
'  copypage 3, dpage
'  dowait
'LOOP
'
END SUB

SUB updateflexmenu (mpointer, nowmenu$(), nowdat(), size, menu$(), menutype(), menuoff(), menulimits(), datablock(), caption$(), maxtable(), recindex)

'--generates a nowmenu subset from generic menu data

'nowmenu$() contains the results. a menu ready to use with standardmenu
'nowdat() is a list of the indexes of which menu elements are currently on display
'size is the index of the last element in nowdat() and nowmenu$()
'menu$() holds all the available captions
'menutype() holds the type of each menu element.
'           0=int
'           1=action (usually triggering a different menu)
'           2=set tag
'           3=string(bybyte)
'           4=badly stored string(by word)
'           5=chooser (not connected with data)
'           6=extra badly stored string(by word with gap)
'           7=attack number (offset)
'           8=item number (not offset)
'           9=enemy name (offset)
'           1000-1999=postcaptioned int (caption-start-offset=n-1000)
'                     (be careful about negatives!)
'           2000-2999=caption-only int (caption-start-offset=n-1000)
'                     (be careful about negatives!)
'           3000-3999=Multi-state (0 and negatives are caption-only,
'                                  positive is postcaptioned. Captions are
'                                  numbered bass-ackwards )
'menuoff() tells us what index to look for the data for this menu item
'menulimits() is the offset to look in maxtable() for limits
'datablock() the actual data the menu represents
'caption$() available captions for postcaptioned ints
'maxtable() used here only for max string lengths

FOR i = 0 TO size
 nowmenu$(i) = menu$(nowdat(i))
 SELECT CASE menutype(nowdat(i))
  CASE 0 '--int
   nowmenu$(i) = nowmenu$(i) + XSTR$(datablock(menuoff(nowdat(i))))
  CASE 2 '--set tag
   nowmenu$(i) = nowmenu$(i) + " " + tagstring(datablock(menuoff(nowdat(i))), "NONE", "(Tag 1 cannot be changed)", "(Tag 1 cannot be changed)")
  CASE 3 '--goodstring
   maxl = maxtable(menulimits(nowdat(i)))
   nowmenu$(i) = nowmenu$(i) + readbinstring$(datablock(), menuoff(nowdat(i)), maxl)
  CASE 4 '--badstring
   maxl = maxtable(menulimits(nowdat(i)))
   nowmenu$(i) = nowmenu$(i) + readbadbinstring$(datablock(), menuoff(nowdat(i)), maxl, 0)
  CASE 5 '--record index
   nowmenu$(i) = CHR$(27) + nowmenu$(i) + XSTR$(recindex) + CHR$(26)
  CASE 6 '--extrabadstring
   maxl = maxtable(menulimits(nowdat(i)))
   nowmenu$(i) = nowmenu$(i) + readbadbinstring$(datablock(), menuoff(nowdat(i)), maxl, 1)
  CASE 7 '--attack number
   IF datablock(menuoff(nowdat(i))) <= 0 THEN
    nowmenu$(i) = nowmenu$(i) + " None"
   ELSE
    nowmenu$(i) = nowmenu$(i) + XSTR$(datablock(menuoff(nowdat(i))) - 1)
    nowmenu$(i) = nowmenu$(i) + " " + readattackname$(datablock(menuoff(nowdat(i))) - 1)
   END IF
  CASE 8 '--item number
   nowmenu$(i) = nowmenu$(i) + itemstr(datablock(menuoff(nowdat(i))), 0, 1)
  CASE 9 '--enemy number
   IF datablock(menuoff(nowdat(i))) <= 0 THEN
    nowmenu$(i) = nowmenu$(i) + " None"
   ELSE
    nowmenu$(i) = nowmenu$(i) + XSTR$(datablock(menuoff(nowdat(i))) - 1)
    nowmenu$(i) = nowmenu$(i) + " " + readenemyname$(datablock(menuoff(nowdat(i))) - 1)
   END IF
  CASE 10 '--item number, offset
    IF datablock(menuoff(nowdat(i))) <= 0 THEN
      nowmenu$(i) = nowmenu$(i) + " None"
    ELSE
      nowmenu$(i) = nowmenu$(i) + itemstr(datablock(menuoff(nowdat(i))) - 1, 0, 1)
    END IF
  CASE 11 '--sound effect number, offset
    IF datablock(menuoff(nowdat(i))) <= 0 THEN
      nowmenu$(i) = nowmenu$(i) + " None"
    ELSE
      nowmenu$(i) = nowmenu$(i) + str$(datablock(menuoff(nowdat(i))) - 1 ) + " (" + getsfxname(datablock(menuoff(nowdat(i))) - 1) + ")"
    END IF
  CASE 1000 TO 1999 '--captioned int
   capnum = menutype(nowdat(i)) - 1000
   nowmenu$(i) = nowmenu$(i) + XSTR$(datablock(menuoff(nowdat(i)))) + " " + caption$(capnum + datablock(menuoff(nowdat(i))))
  CASE 2000 TO 2999 '--caption-only int
   capnum = menutype(nowdat(i)) - 2000
   nowmenu$(i) = nowmenu$(i) + " " + caption$(capnum + datablock(menuoff(nowdat(i))))
  CASE 3000 TO 3999 '--multistate
   capnum = menutype(nowdat(i)) - 3000
   IF datablock(menuoff(nowdat(i))) > 0 THEN
    nowmenu$(i) = nowmenu$(i) + XSTR$(datablock(menuoff(nowdat(i)))) + " " + caption$(capnum - 1)
   ELSE
    nowmenu$(i) = nowmenu$(i) + " " + caption$(capnum + ABS(datablock(menuoff(nowdat(i)))))
   END IF
 END SELECT
 IF mpointer = i THEN
   nowmenu$(i) = RIGHT$(nowmenu$(i), 40)
 END IF
NEXT i

END SUB

FUNCTION isStringField(mnu)
  IF mnu = 3 OR mnu = 4 OR mnu = 6 THEN RETURN -1
  RETURN 0
END FUNCTION
