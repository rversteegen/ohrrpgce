#IFNDEF __CONST_BI__
#DEFINE __CONST_BI__

'OHRRPGCE GAME - shared constants
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'

'---For some crazy reason TRUE and FALSE don't work well as const even though they are not reserved
CONST YES = -1
CONST NO = 0

CONST CURRENT_RPG_VERSION = 14
' It is a good idea to increment this number each time a major feature
' has been added, if opening a new game in an old editor would cause data-loss
' Don't be afraid to increment this. Backcompat warnings are a good thing!
'--version history
' 7 - ypsiliform wip added > 36 NPC defs (and many other features)
' 8 - ypsiliform wip added extended chaining data (and many other features)
' 9 - ypsiliform wip added text box sound effects
' 10 - ypsiliform wip added attack-based enemy transmogrification
' 11 - zenzizenzic wip added variable record size and record number .N## lumps
' 12 - zenzizenzic wip increased .N## record size
' 13 - zenzizenzic wip changed password format to PW4, older versions have broken genPassVersion handling
' 14 - zenzizenzic wip made .DT0 binsize-sized

CONST CURRENT_RSAV_VERSION = 1
' Increment this number any time that loading and resaving a game in either
' new or old versions of Game leads to data-loss, or major new features are
' added.
' 1 - zenzizenzic wip removed nativehbits related nodes

'---GENERAL GAME DATA (.GEN) constants---
CONST genMaxMap = 0             'max map ID
CONST genTitle = 1              'title screen backdrop
CONST genTitleMus = 2           'title music
CONST genVictMus  = 3           'victory music
CONST genBatMus = 4             'default battle music
CONST genPassVersion = 5        'passcode format number
CONST genPW3Rot = 6             'old (third style) passcode rotator
'7-25: first style or third style encoded passcode
CONST genMaxHeroPic = 26        'max hero graphic number in .PT0
CONST genMaxEnemy1Pic = 27      'max small enemy graphic number in .PT1
CONST genMaxEnemy2Pic = 28      'max medium enemy graphic number in .PT2
CONST genMaxEnemy3Pic = 29      'max large enemy graphic number in .PT3
CONST genMaxNPCPic = 30         'max npc graphic number in .PT4
CONST genMaxWeaponPic = 31      'max weapon graphic number in .PT5
CONST genMaxAttackPic = 32      'max attack graphic number in .PT6
CONST genMaxTile = 33           'max tileset number in .TIL
CONST genMaxAttack = 34         'max attack definition number in .DT6
CONST genMaxHero = 35           'max hero definition number in .DT0
CONST genMaxEnemy = 36          'max enemy definition number in .DT1
CONST genMaxFormation = 37      'max formation number in .FOR
CONST genMaxPal = 38            'max palette number in .PAL
CONST genMaxTextbox = 39        'max text box number in .SAY
CONST genNumPlotscripts = 40    'number of scripts of any kind (number of records in PLOTSCR.LST)
CONST genNewGameScript = 41     'id of new-game plotscript
CONST genGameoverScript = 42    'id of game-over plotscript
CONST genMaxRegularScript = 43  'id of highest numbered non-autonumbered plotscript
CONST genSuspendBits = 44       'suspend stuff bits
CONST genCamera = 45            'camera mode
CONST genCamArg1 = 46           'cameraarg1
CONST genCamArg2 = 47           'cameraarg2
CONST genCamArg3 = 48           'cameraarg3
CONST genCamArg4 = 49           'cameraarg4
CONST genScrBackdrop = 50       'currently displaying script backdrop in .MXS + 1, 0 for none
CONST genDays = 51              'days of play
CONST genHours = 52             'hours of play
CONST genMinutes = 53           'minutes of play
CONST genSeconds = 54           'seconds of play
CONST genMaxVehicle = 55        'max vehicle type number in .VEH
CONST genMaxTagname = 56        'last named tag
CONST genLoadGameScript = 57    'load-game script
CONST genTextboxBackdrop = 58   'currently displaying text box backdrop in .MXS + 1, 0 for none
CONST genEnemyDissolve = 59     'Default dissolve animation for dying enemies
CONST genJoy = 60               'enable/disable joystick
CONST genPoison = 61            'poison status indicator char
CONST genStun = 62              'Stun status indicator char
CONST genDamageCap = 63         'Damage cap
CONST genMute = 64              'Mute status indicator char
CONST genStatCap = 65           'Stat caps (genStatCap + stat) (65-76)
CONST genMaxSFX = 77            'last song number
CONST genMasterPal = 78         'master palette number
CONST genMaxMasterPal = 79      'max master palette number
CONST genMaxMenu = 80           'max menu def in MENUS.BIN
CONST genMaxMenuItem = 81       'max menu item def in MENUITEM.BIN
CONST genMaxItem = 82           'max item in .ITM
CONST genMaxBoxBorder = 83      'max box border number in .PT7
CONST genMaxPortrait = 84       'max portrait graphic number in .PT8
CONST genMaxInventory = 85      'max available inventory slot (0 means use inventoryMax)
CONST genErrorLevel = 86        'value to set err_suppress_lvl to, if nonzero
CONST genLevelCap = 87          'Default maximum level (0 to 99)

'Unused indices

CONST genPW4Hash = 92           'new (4th style) password hash
CONST genPW2Offset = 93         'old-old password offset
CONST genPW2Length = 94         'old-old password length
CONST genVersion = 95           'RPG file format version (see CURRENT_RPG_VERSION above for latest)
CONST genStartMoney = 96        'starting money
CONST genMaxShop = 97           'last shop in .SHO
CONST genPW1Offset = 98         'old-old-old password offset
CONST genPW1Length = 99         'old-old-old password length
CONST genNumBackdrops = 100     'number of screens in .MXS
CONST genBits = 101             'general bitsets
CONST genStartX = 102           'starting X
CONST genStartY = 103           'starting Y
CONST genStartMap = 104         'starting Map
CONST genOneTimeNPC = 105       'one-time-NPC indexer
CONST genDefaultDeathSFX = 171  'default enemy death sound effect
CONST genMaxSong = 172          'last song number
CONST genAcceptSFX = 173        'menu interface
CONST genCancelSFX = 174        ' "       "
CONST genCursorSFX = 175        ' "       "
CONST genTextboxLine = 176      'Text box 'click'
CONST genBits2 = 177            'More general bitsets
CONST genBits3 = 178            'More general bitsets
CONST genItemLearnSFX = 179     'learn spell oob item
CONST genCantLearnSFX = 180     'hero couldn't learn spell from item
CONST genBuySFX = 181           'buy item from shop
CONST genHireSFX = 182          'hire from shop
CONST genSellSFX = 183          'sell item to shop
CONST genCantBuySFX = 184       'can't afford item/hire
CONST genCantSellSFX = 185      'unsellable item
CONST genDamageDisplayTicks = 186 'number of ticks that battle damage displays
CONST genDamageDisplayRise = 187 'number of pixels that damage display rises
'188 to 198 unused
'199 to 359 used to be the scattertable for PW2, now zeroed out
'360 to 499 unused

'---Built in stats
CONST statHP = 0
CONST statMP = 1
CONST statAtk = 2
CONST statAim = 3
CONST statDef = 4
CONST statDodge = 5
CONST statMagic = 6
CONST statWill = 7
CONST statSpeed = 8
CONST statCtr = 9
CONST statFocus = 10
CONST statHitX = 11
CONST statUser = 12              'Additional user defined stats, if any, start here

'---Format fix bits
CONST fixAttackitems = 0         'zero out attack data for item cost (ammunition)
CONST fixWeapPoints  = 1         'add defaults for weapon points
CONST fixStunCancelTarg = 2      'turn on cancel target bitset for old stun attacks
CONST fixDefaultDissolve = 3     'Initialized genEnemyDissolve to default in GEN
CONST fixDefaultDissolveEnemy = 4'Initialized Enemy dissolves to default in DT1
CONST fixPushNPCBugCompat = 5    'Turned on the Simulate pushable NPC obstruction bug bitset
CONST fixDefaultMaxItem = 6      'Stored default max item id in GEN
CONST fixBlankDoorLinks = 7      'Marked redundant blank doorlinks as unused
CONST fixShopSounds = 8          'Set genItemLearnSFX..genCantSellSFX to defaults
CONST fixExtendedNPCs = 9        'Deleted or initialised garbage NPC data in IDs 36 to 99
CONST fixHeroPortrait = 10       'Initialize hero portrait data
CONST fixTextBoxPortrait = 11    'Initialize text box portrait data
CONST fixNPCLocationFormat = 12  'FIXME: not implemented ... can't remember....
CONST fixInitDamageDisplay = 13  'Initialize damage display time and distance
CONST fixDefaultLevelCap = 14    'Set level cap to 99
CONST fixHeroElementals = 15     'Set the hero elemental data from the old weak/strong/absorb bits
CONST fixOldElementalFailBit = 16'Turned on the 'Simulate old fail vs. element resist bit' bitset
CONST fixAttackElementFails = 17 'Initialized all 64 attack elemental fail conditions

'---Sizes (replaceable with variables when suitable)
CONST max_npc_defs = 500 'max number of NPC IDs definable in Custom
CONST maxMaxItems = 32000 'max number of items
CONST maxMaxHero = 59 'This is the max value possible for gen(genMaxHero) 'FIXME: not used everywhere
CONST inventoryMax = 599 'last inventory slot num (divisible by 3 when you count the zero)
CONST maplayerMax = 7 'The limit on the highest numbered map layer
CONST mapTilesMax = 100000 'Maximum map size, in tiles (note also a limit of 32768 tiles wide or high)
CONST dissolveTypeMax = 10 'Highest numbered frame dissolve effect
CONST maxElements = 8 'Maximum selectable number of elements
CONST numElements = 8 'Number of elements defined in this game (only a constant temporarily)
#IFDEF SCRIPTPROFILE
CONST scriptmemMax = 10000000 'in 4-byte ints
CONST scriptTableSize = 512  'hash table size, power of 2 please
CONST maxLoadedScripts = 32768
#ELSE
CONST scriptmemMax = 65536 'in 4-byte ints (256kb)
CONST scriptTableSize = 256  'hash table size, power of 2 please
CONST maxLoadedScripts = 360
#ENDIF

'--- Binary files in BINSIZE.BIN for getbinsize()
CONST binATTACK = 0
CONST binSTF = 1
CONST binSONGDATA = 2
CONST binSFXDATA = 3
CONST binMAP = 4
CONST binMENUS = 5
CONST binMENUITEM = 6
CONST binUICOLORS = 7
CONST binSAY = 8
CONST binN = 9
CONST binDT0 = 10

CONST sizebinsize = 10 ' *** Update this when adding binsize records ***

'--- Misc constants
Enum constDirection
	dirUp
	dirRight
	dirDown
	dirLeft
End Enum

'--- Constants for carray() 
CONST ccUp = 0
CONST ccDown = 1
CONST ccLeft = 2
CONST ccRight = 3
CONST ccUse = 4
CONST ccMenu = 5
CONST ccRun = 6

#include "uiconst.bi"
#include "scancodes.bi"

#ENDIF
