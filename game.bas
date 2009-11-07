'OHRRPGCE GAME - Main module
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
'!$DYNAMIC
'DEFINT A-Z

#include "udts.bi"
#include "game_udts.bi"
#include "slices.bi"
#include "compat.bi"
#include "allmodex.bi"
#include "common.bi"
#include "gglobals.bi"
#include "const.bi"
#include "scrconst.bi"
#include "uiconst.bi"
#include "loading.bi"
#include "slices.bi"
#include "yetmore.bi"
#include "yetmore2.bi"
#include "moresubs.bi"
#include "menustuf.bi"
#include "bmodsubs.bi"
#include "bmod.bi"
#include "game.bi"


'local subs and functions
DECLARE SUB LoadGen
DECLARE SUB reset_game_state ()
DECLARE SUB prepare_map (afterbat AS INTEGER=NO, afterload AS INTEGER=NO)
DECLARE SUB reset_map_state (map AS MapModeState)
DECLARE SUB opendoor (dforce AS INTEGER=0)
DECLARE SUB thrudoor (door_id AS INTEGER)
DECLARE SUB advance_text_box ()
DECLARE FUNCTION want_to_check_for_walls(BYVAL who AS INTEGER) AS INTEGER

REMEMBERSTATE

start_new_debug
debuginfo long_version & build_info

'DEBUG debug "randomize timer"
RANDOMIZE TIMER, 3 ' Mersenne Twister

processcommandline

'---get temp dir---
set_homedir
tmpdir = aquiretempdir$

'DEBUG debug "set mode-X"
setmodex

'DEBUG debug "init sound"
setupmusic
fmvol = getfmvol

'DEBUG debug "dim (almost) everything"

'$dynamic

'shared module variables
DIM SHARED needf
DIM SHARED harmtileflash = NO
DIM SHARED wantbox, wantdoor, wantbattle, wantteleport, wantusenpc, wantloadgame

'global variables
DIM gam AS GameState
DIM txt AS TextBoxState
DIM gen(360)
DIM tag(127)

DIM stat(40, 1, 16)
DIM hero(40), bmenu(40, 5), spell(40, 3, 23), lmp(40, 7), exlev(40, 1), names(40), herobits(59, 3), itembits(maxMaxItems, 3), nativehbits(40, 4)
DIM eqstuf(40, 4)
DIM catx(15), caty(15), catz(15), catd(15), xgo(3), ygo(3), herospeed(3), wtog(3), hmask(3)
DIM herow(3) as GraphicPair
DIM statnames() as string

DIM scroll(), pass()
DIM tilesets(2) as TilesetData ptr

DIM master(255) as RGBcolor
DIM uilook(uiColors)

DIM pal16(448)
DIM buffer(16384)

DIM inventory(inventoryMax) as InventSlot
DIM gold

DIM npcs(max_npc_defs) as NPCType
DIM npc(300) as NPCInst

DIM AS INTEGER mapx, mapy, vpage, dpage, fadestate, fmvol, speedcontrol, usepreunlump, lastsaveslot, abortg, resetg, foemaph, presentsong, framex, framey
DIM err_suppress_lvl
DIM AS STRING tmpdir, exename, game, sourcerpg, savefile, workingdir, homedir
DIM prefsdir as string

'Menu Data
DIM menu_set AS MenuSet
DIM menus(0) AS MenuDef 'This is an array because it holds a stack of heirarchial menus (resized as required)
DIM mstates(0) AS MenuState
DIM topmenu AS INTEGER = -1

DIM timers(15) as PlotTimer
DIM fatal
DIM lastformation

DIM vstate AS VehicleState

DIM csetup(12), carray(13)
DIM mouse(3)
DIM joy(14), gotj(2)

DIM backcompat_sound_slot_mode
DIM backcompat_sound_slots(7)

DIM nowscript, scriptret, scriptctr, numloadedscr, totalscrmem, scrwatch
DIM heap(2048), global(4095), retvals(32)
DIM scrat(128) as ScriptInst
DIM script(scriptTableSize - 1) as ScriptData Ptr
DIM plotstr(31) as Plotstring
DIM scrst as Stack
DIM curcmd as ScriptCommand ptr
DIM insideinterpreter

'incredibly frustratingly fbc doesn't export global array debugging symbols
DIM globalp as integer ptr
DIM heapp as integer ptr
DIM scratp as ScriptInst ptr
DIM scriptp as ScriptData ptr ptr 
DIM retvalsp as integer ptr
DIM plotslicesp as slice ptr ptr
globalp = @global(0)
heapp = @heap(0)
scratp = @scrat(0)
scriptp = @script(0)
retvalsp = @retvals(0)
plotslicesp = @plotslices(1)

'End global variables

'Module local variables
DIM font(1024)
DIM didgo(0 TO 3)

'DEBUG debug "Thestart"
DO 'This is a big loop that encloses the entire program (more than it should). The loop is only reached when resetting the game

'DEBUG debug "setup directories"

'---get work dir and exe name---
IF NOT isdir(tmpdir) THEN makedir tmpdir
workingdir = tmpdir + "playing.tmp"
exename = trimextension$(trimpath$(COMMAND$(0)))

'DEBUG debug "create playing.tmp"
'---If workingdir does not already exist, it must be created---
IF isdir(workingdir) THEN
 'DEBUG debug workingdir+" already exists"
 'DEBUG debug "erasing "+workingdir+"\"+ALLFILES
 cleanuptemp
ELSE
 makedir workingdir
END IF

'-- Init joysticks
FOR i = 0 TO 1
 gotj(i) = readjoy(joy(), i)
NEXT i

dpage = 1: vpage = 0
speedcontrol = 55
presentsong = -1
gen(genJoy) = 0'--leave joystick calibration enabled

load_default_master_palette master()
'get default ui colours
LoadUIColors uilook()

'DEBUG debug "load font"
getdefaultfont font()

setwindowtitle "O.H.R.RPG.C.E"

'DEBUG debug "apply font"
setfont font()

keyboardsetup

'DEBUG debug "set up default controls"
defaultc

'---IF A VALID RPG FILE WAS SPECIFIED ON THE COMMAND LINE, RUN IT, ELSE BROWSE---
'---ALSO CHECKS FOR GAME.EXE RENAMING
'DEBUG debug "enable autorunning"
autorungame = 0
usepreunlump = 0
FOR i = 1 TO commandlineargcount
 a$ = commandlinearg(i)

#IFNDEF __FB_LINUX__
 IF MID$(a$, 2, 1) <> ":" THEN a$ = curdir$ + SLASH + a$
#ELSE
 IF MID$(a$, 1, 1) <> "/" THEN a$ = curdir$ + SLASH + a$
#ENDIF
 IF LCASE$(RIGHT$(a$, 4)) = ".rpg" AND isfile(a$) THEN
  sourcerpg = a$
  autorungame = 1
  EXIT FOR
 ELSEIF isdir(a$) THEN 'perhaps it's an unlumped folder?
  'check for essentials
  IF isfile(a$ + SLASH + "archinym.lmp") THEN 'ok, accept it
   autorungame = 1
   usepreunlump = 1
   sourcerpg = a$
   workingdir = a$
  END IF
  EXIT FOR
 END IF
NEXT

IF autorungame = 0 THEN
 IF LCASE$(exename) <> "game" THEN
  IF isfile(exepath + SLASH + exename + ".rpg") THEN
   sourcerpg = exepath + SLASH + exename + ".rpg"
   autorungame = 1
  END IF
 END IF
END IF
IF autorungame = 0 THEN
 'DEBUG debug "browse for RPG"
 sourcerpg = browse$(7, "", "*.rpg", tmpdir, 1, "browse_rpg")
 IF sourcerpg = "" THEN exitprogram 0
 IF isdir(sourcerpg) THEN
  usepreunlump = 1
  workingdir = sourcerpg
 END IF
END IF

'-- set up prefs dir
#IFDEF __FB_LINUX__
'This is important on linux in case you are playing an rpg file installed in /usr/share/games
prefsdir = ENVIRON$("HOME") + SLASH + ".ohrrpgce" + SLASH + trimextension$(trimpath$(sourcerpg))
IF NOT isdir(prefsdir) THEN makedir prefsdir
#ELSE
'This is not used anywhere yet in the Windows version
prefsdir = ENVIRON$("APPDATA") + SLASH + "OHRRPGCE" + SLASH + trimextension$(trimpath$(sourcerpg))
#ENDIF

'-- change current directory, where g_debug will be put; mainly for drag-dropping onto Game in Windows which defaults to homedir
a$ = trimfilename(sourcerpg)
IF a$ <> "" ANDALSO fileiswriteable(a$ + SLASH + "writetest.tmp") THEN
 'first choice is game directory
 safekill a$ + SLASH + "writetest.tmp"
 CHDIR a$
ELSEIF fileiswriteable(exepath + SLASH + "writetest.tmp") THEN
 safekill exepath + SLASH + "writetest.tmp"
 CHDIR exepath
ELSE
 'should prefsdir be used instead?
 CHDIR homedir
END IF

'--set up savegame file
savefile = trimextension$(sourcerpg) + ".sav"
#IFDEF __FB_LINUX__
IF NOT fileisreadable(savefile) THEN
 savefile = prefsdir + SLASH + trimpath$(savefile)
END IF
#ENDIF

IF autorungame = 0 THEN
 edgeboxstyle 4, 3, 312, 14, 0, vpage
ELSE
 setpal master()
END IF

edgeprint "Loading...", xstring("Loading...", 160), 6, uilook(uiText), vpage
setvispage vpage 'refresh

'---GAME SELECTED, PREPARING TO PLAY---
IF usepreunlump = 0 THEN
 unlump sourcerpg, workingdir + SLASH
END IF

end_debug 'messages generated before this point, or previous game
start_new_debug
debuginfo long_version & build_info
debuginfo "Playing game " & trimpath(sourcerpg) & " (" & getdisplayname(" ") & ") " & DATE & " " & TIME

dim gmap(dimbinsize(binMAP)) 'this must be declared here, after the binsize file exists!

initgame '--set game

xbload game + ".fnt", font(), "font missing from " + game
LoadGEN
'--upgrade obsolete RPG files (if possible)
upgrade font()

if isfile(game + ".hsp") then unlump game + ".hsp", tmpdir

fadeout 0, 0, 0
needf = 1

rpgversion gen(genVersion)

setfont font()
setpicstuf buffer(), 50, -1
FOR i = 0 TO 254
 loadset game + ".efs", i, 0
 gam.foe_freq(i) = buffer(0)
NEXT i
getstatnames statnames()
j = 0

nowscript = -1
numloadedscr = 0
totalscrmem = 0
depth = 0
resetinterpreter
'the old stack used only inbattle
releasestack
setupstack

SetupGameSlices
'beginplay
DO' This loop encloses the playable game for a specific RPG file

loadpalette master(), gen(genMasterPal)
LoadUIColors uilook(), gen(genMasterPal)
init_default_text_colors

initgamedefaults
reset_game_state
fatal = 0
abortg = 0
resetg = NO
lastformation = -1
scrwatch = 0
err_suppress_lvl = 3
menu_set.menufile = workingdir & SLASH & "menus.bin"
menu_set.itemfile = workingdir & SLASH & "menuitem.bin"

makebackups 'make a few backup lumps

wantbox = 0
wantdoor = 0
wantbattle = 0
wantteleport = 0
wantusenpc = 0
wantloadgame = 0

txt.choice_cursor = 0
txt.showing = NO
txt.fully_shown = NO
txt.show_lines = 0
txt.sayer = -1
txt.id = -1

temp = -1
IF readbit(gen(), genBits, 11) = 0 THEN
 IF titlescr = 0 THEN EXIT DO'resetg
 IF readbit(gen(), genBits, 12) = 0 THEN temp = picksave(1)
ELSE
 readjoysettings
 IF readbit(gen(), genBits, 12) = 0 THEN
  IF gen(genTitleMus) > 0 THEN wrappedsong gen(genTitleMus) - 1
  temp = picksave(2)
 END IF
END IF
'DEBUG debug "picked save slot " & temp
stopsong
fadeout 0, 0, 0
IF temp = -2 THEN EXIT DO 'resetg
IF temp >= 0 THEN
 GOSUB doloadgame
 prepare_map NO, YES 'Special case if this is called right after GOSUB doloadgame
ELSE
 clearpage 0
 clearpage 1
 addhero 1, 0, stat()
 IF gen(genNewGameScript) > 0 THEN
  runscript(gen(genNewGameScript), nowscript + 1, -1, "newgame", plottrigger)
 END IF
 prepare_map
END IF

doihavebits
evalherotag stat()
needf = 1
force_npc_check = YES

'--Reset some stuff related to debug keys
showtags = 0
shownpcinfo = 0
gam.walk_through_walls = NO

'DEBUG debug "pre-call movement"
GOSUB movement
setkeys
DO
 'DEBUG debug "top of master loop"
 setwait speedcontrol
 setkeys
 readmouse mouse()  'didn't bother to check havemouse()
 tog = tog XOR 1
 'DEBUG debug "increment play timers"
 playtimer
 'DEBUG debug "read controls"
 control
 'debug "menu key handling:"
 check_menu_tags
 FOR i = 0 TO topmenu
  IF mstates(i).need_update THEN
   mstates(i).need_update = NO
   init_menu_state mstates(i), menus(i)
  END IF
 NEXT i
 player_menu_keys stat(), catx(), caty(), tilesets()
 'debug "after menu key handling:"
 IF menus_allow_gameplay() THEN
 IF gmap(15) THEN onkeyscript gmap(15)
 'breakpoint : called after keypress script is run, but don't get called by wantimmediate
 IF scrwatch > 1 THEN breakpoint scrwatch, 4
 'DEBUG debug "enter script interpreter"
 GOSUB interpret
 'DEBUG debug "increment script timers"
 dotimer(0)
 'DEBUG debug "keyboard handling"
 IF carray(ccMenu) > 1 AND txt.showing = NO AND needf = 0 AND readbit(gen(), 44, suspendplayer) = 0 AND vstate.active = NO AND xgo(0) = 0 AND ygo(0) = 0 THEN
  IF allowed_to_open_main_menu() THEN
   add_menu 0
   menusound gen(genAcceptSFX)
  END IF
 END IF
 IF txt.showing = NO AND needf = 0 AND readbit(gen(), 44, suspendplayer) = 0 AND vehicle_is_animating() = NO AND menus_allow_player() THEN
  IF xgo(0) = 0 AND ygo(0) = 0 THEN
   DO
    IF carray(ccUp) > 0 THEN ygo(0) = 20: catd(0) = 0: EXIT DO
    IF carray(ccDown) > 0 THEN ygo(0) = -20: catd(0) = 2: EXIT DO
    IF carray(ccLeft) > 0 THEN xgo(0) = 20: catd(0) = 3: EXIT DO
    IF carray(ccRight) > 0 THEN xgo(0) = -20: catd(0) = 1: EXIT DO
    IF carray(ccUse) > 1 AND vstate.active = NO THEN
     txt.sayer = -1
     usething 0, catx(0), caty(0)
    END IF
    EXIT DO
   LOOP
  END IF
 END IF
 'debug "before advance_text_box:"
 IF carray(ccUse) > 1 AND txt.fully_shown = YES AND readbit(gen(), 44, suspendboxadvance) = 0 THEN
  advance_text_box
 END IF
 'debug "after advance_text_box:"
 IF vstate.active THEN
  'DEBUG debug "evaluate vehicles"
  tmp = vehiclestuff()
  SELECT CASE tmp
   CASE IS < 0
    runscript(ABS(tmp), nowscript + 1, -1, "vehicle", plottrigger)
   CASE 1
    add_menu 0
    menusound gen(genAcceptSFX)
   CASE IS > 1
    loadsay tmp - 1
  END SELECT
 END IF
 IF txt.fully_shown = YES AND txt.box.choice_enabled THEN
  IF carray(ccUp) > 1 AND txt.choice_cursor = 1 THEN txt.choice_cursor = 0: MenuSound gen(genCursorSFX)
  IF carray(ccDown) > 1 AND txt.choice_cursor = 0 THEN txt.choice_cursor = 1: MenuSound gen(genCursorSFX)
 END IF
 'DEBUG debug "hero movement"
 GOSUB movement
 'DEBUG debug "NPC movement"
 GOSUB movenpc
 IF readbit(gen(), 101, 8) = 0 THEN
  '--debugging keys
  'DEBUG debug "evaluate debugging keys"
  IF keyval(scF2) > 1 AND txt.showing = NO THEN
   savegame 32, stat()
  END IF
  IF keyval(scF3) > 1 AND txt.showing = NO THEN
   wantloadgame = 33
  END IF
  IF keyval(scF4) > 1 THEN showtags = showtags XOR 1: scrwatch = 0 
  IF keyval(scCtrl) = 0 AND keyval(scF5) > 1 THEN 'F5
   SELECT CASE gen(cameramode)
    CASE herocam
     IF gen(cameraArg) < 15 THEN
      gen(cameraArg) = gen(cameraArg) + 5
     ELSE
      gen(cameraArg) = 0
     END IF
    CASE ELSE
     gen(cameramode) = herocam
     gen(cameraArg) = 0
   END SELECT
  END IF
  IF keyval(scCtrl) > 0 AND keyval(scF5) > 1 THEN  'CTRL + F5
   catx(0) = (catx(0) \ 20) * 20
   caty(0) = (caty(0) \ 20) * 20
   xgo(0) = 0
   ygo(0) = 0
  END IF
  IF keyval(scF6) > 0 AND gen(cameramode) <> pancam THEN
   '--only permit movement when not already panning
   IF keyval(scUp) > 0 THEN
    gen(cameraArg) = 0 'north
    setdebugpan
   END IF
   IF keyval(scRight) > 0 THEN
    gen(cameraArg) = 1 'east
    setdebugpan
   END IF
   IF keyval(scDown) > 0 THEN
    gen(cameraArg) = 2 'south
    setdebugpan
   END IF
   IF keyval(scLeft) > 0 THEN
    gen(cameraArg) = 3 'west
    setdebugpan
   END IF
  END IF
  IF keyval(scF7) > 1 THEN 'Toggle level-up bug
   IF readbit(gen(), 101, 9) = 0 THEN
    setbit gen(), 101, 9, 1
   ELSE
    setbit gen(), 101, 9, 0
   END IF
  END IF
  IF keyval(scF10) > 1 THEN scrwatch = loopvar(scrwatch, 0, 2, 1): showtags = 0
  IF keyval(scCtrl) > 0 THEN ' holding CTRL
   IF keyval(scF1) > 1 AND txt.showing = NO THEN 
    IF teleporttool(tilesets()) THEN 'CTRL + F1
     prepare_map
    END IF
   END IF
   IF showtags = 0 THEN
    IF keyval(scNumpadPlus) > 1 OR keyval(scPlus) > 1 THEN speedcontrol = large(speedcontrol - 1, 10): scriptout$ = STR(speedcontrol) 'CTRL + +
    IF keyval(scNumpadMinus) > 1 OR keyval(scMinus) > 1 THEN speedcontrol = small(speedcontrol + 1, 160): scriptout$ = STR(speedcontrol)'CTRL + -
   END IF
   IF keyval(scF11) > 1 THEN shownpcinfo = shownpcinfo XOR 1  'CTRL + F11
  ELSE ' not holding CTRL
   IF keyval(scF1) > 1 AND txt.showing = NO THEN minimap catx(0), caty(0), tilesets()
   IF keyval(scF8) > 1 THEN patcharray gen(), "gen"
   IF keyval(scF9) > 1 THEN patcharray gmap(), "gmap"
   IF keyval(scF11) > 1 THEN gam.walk_through_walls = NOT gam.walk_through_walls
  END IF
 END IF
 IF wantloadgame > 0 THEN
  'DEBUG debug "loading game slot " & (wantloadgame - 1)
  temp = wantloadgame - 1
  wantloadgame = 0
  resetgame stat(), scriptout$
  initgamedefaults
  stopsong
  fadeout 0, 0, 0
  needf = 1
  force_npc_check = YES
  game.map.lastmap = -1
  GOSUB doloadgame
  prepare_map NO, YES
 END IF
 'DEBUG debug "random enemies"
 IF gam.random_battle_countdown = 0 AND readbit(gen(), 44, suspendrandomenemies) = 0 AND (vstate.active = NO OR vstate.dat.random_battles > -1) THEN
  temp = readfoemap(INT(catx(0) / 20), INT(caty(0) / 20), scroll(0), scroll(1), foemaph)
  IF vstate.active AND vstate.dat.random_battles > 0 THEN temp = vstate.dat.random_battles
  IF temp > 0 THEN
   batform = random_formation(temp - 1)
   IF batform >= 0 THEN
    IF gmap(13) <= 0 THEN
     '--normal battle
     fatal = 0
     gam.wonbattle = battle(batform, fatal, stat())
     dotimerafterbattle
     prepare_map YES
     needf = 2
    ELSE
     rsr = runscript(gmap(13), nowscript + 1, -1, "rand-battle", plottrigger)
     IF rsr = 1 THEN
      setScriptArg 0, batform
      setScriptArg 1, temp
     END IF
    END IF
   END IF
   gam.random_battle_countdown = range(100, 60)
  END IF
 END IF
 'DEBUG debug "check for death (fatal = " & fatal & ")"
 IF fatal = 1 THEN
  '--this is what happens when you die in battle
  txt.showing = NO
  txt.fully_shown = NO
  IF gen(genGameoverScript) > 0 THEN
   rsr = runscript(gen(genGameoverScript), nowscript + 1, -1, "death", plottrigger)
   IF rsr = 1 THEN
    fatal = 0
    needf = 2
   END IF
  ELSE
   fadeout 255, 0, 0
  END IF
 END IF
 END IF' end menus_allow_gameplay
 GOSUB displayall
 IF fatal = 1 OR abortg > 0 OR resetg THEN
  resetgame stat(), scriptout$
  IF resetg THEN EXIT DO
  'if skip loadmenu and title bits set, quit
  IF (readbit(gen(), genBits, 11)) AND (readbit(gen(), genBits, 12) OR abortg = 2 OR count_sav(savefile) = 0) THEN
   EXIT DO, DO ' To game select screen (quit the gameplay and RPG file loops, allowing the program loop to cycle)
  ELSE
   EXIT DO ' To title screen (quit the gameplay loop and allow the RPG file loop to cycle)
  END IF
 END IF
 'DEBUG debug "swap video pages"
 SWAP vpage, dpage
 setvispage vpage
 'DEBUG debug "fade in"
 'DEBUG debug "needf " & needf
 IF needf = 1 AND fatal = 0 THEN
  needf = 0
  fadein
  setkeys
 END IF
 IF needf > 1 THEN needf = needf - 1
 'DEBUG debug "tail of main loop"
 dowait
LOOP

LOOP ' This is the end of the DO that encloses a specific RPG file

'resetg final cleanup
cleanup_text_box
'checks for leaks and deallocates them
sprite_empty_cache()
palette16_empty_cache()
resetsfx()
IF autorungame THEN exitprogram (NOT abortg)
unloadmaptilesets tilesets()
refresh_map_slice_tilesets '--zeroes them out
resetinterpreter 'unload scripts
cleanuptemp
fadeout 0, 0, 0
stopsong
clearpage 0
clearpage 1
clearpage 2
clearpage 3
DestroyGameSlices
SliceDebugDump YES
RETRIEVESTATE
LOOP ' This is the end of the DO that encloses the entire program.

doloadgame:
loadgame temp, stat()
init_default_text_colors
IF gen(genLoadGameScript) > 0 THEN
 rsr = runscript(gen(genLoadGameScript), nowscript + 1, -1, "loadgame", plottrigger)
 IF rsr = 1 THEN
  '--pass save slot as argument
  IF temp = 32 THEN temp = -1 'quickload slot
  setScriptArg 0, temp
 END IF
END IF
gam.map.same = YES
RETRACE

displayall:
IF gen(genTextboxBackdrop) = 0 AND gen(genScrBackdrop) = 0 THEN
 '---NORMAL DISPLAY---
 'setanim tastuf(0) + tanim_state(0).cycle, tastuf(20) + tanim_state(1).cycle
 'cycletile tilesets(0)->anim(), tilesets(0)->tastuf()
 'DEBUG debug "drawmap"
 overlay = 1
 IF readbit(gen(), 44, suspendoverlay) THEN overlay = 0
 WITH *(SliceTable.MapRoot)
  .X = mapx * -1
  .Y = mapy * -1
 END WITH
 RefreshSliceScreenPos(SliceTable.MapRoot) '--FIXME: this can go away when it is no longer necessary to draw each map layer one-by-one
 ChangeMapSlice SliceTable.MapLayer(0), , , , , overlay
 DrawSlice SliceTable.MapLayer(0), dpage  'FIXME: Eventually we will just draw the slice root, but for transition we draw second-level slice trees individually
 IF readbit(gmap(), 19, 0) THEN DrawSlice SliceTable.MapLayer(1), dpage
 'DEBUG debug "draw npcs and heroes"
 IF gmap(16) = 1 THEN
  cathero
  drawnpcs
 ELSE
  drawnpcs
  cathero
 END IF
 'DEBUG debug "drawoverhead"
 IF readbit(gmap(), 19, 1) THEN DrawSlice SliceTable.MapLayer(2), dpage
 IF readbit(gen(), 44, suspendoverlay) = 0 THEN
  ChangeMapSlice SliceTable.MapLayer(0), , , , , 2
  DrawSlice SliceTable.MapLayer(0), dpage
 END IF
 DrawSlice SliceTable.scriptsprite, dpage 'FIXME: Eventually we will just draw the slice root, but for transition we draw second-level slice trees individually
 
 animatetilesets tilesets()
 IF harmtileflash = YES THEN
  rectangle 0, 0, 320, 200, gmap(10), dpage
  harmtileflash = NO
 END IF
ELSE '---END NORMAL DISPLAY---
 'DEBUG debug "backdrop display"
 copypage 3, dpage
END IF '---END BACKDROP DISPLAY---
'DEBUG debug "text box"
DrawSlice(SliceTable.TextBox, dpage) 'FIXME: Eventually we will just draw the slice root, but for transition we draw second-level slice trees individually
IF txt.showing = YES THEN drawsay
'DEBUG debug "map name"
IF gam.map.showname > 0 AND gmap(4) >= gam.map.showname THEN
 gam.map.showname -= 1
 edgeprint gam.map.name, xstring(gam.map.name, 160), 180, uilook(uiText), dpage
ELSE
 gam.map.showname = 0
END IF
FOR i = 0 TO topmenu
 draw_menu menus(i), mstates(i), dpage
NEXT i
edgeprint scriptout$, 0, 190, uilook(uiText), dpage
showplotstrings
IF shownpcinfo THEN npc_debug_display
IF showtags > 0 THEN tagdisplay
IF scrwatch THEN scriptwatcher scrwatch, -1
RETRACE

movement:
'note: xgo and ygo are offset of current position from destination, eg +ve xgo means go left 
FOR whoi = 0 TO 3
 thisherotilex = INT(catx(whoi * 5) / 20)
 thisherotiley = INT(caty(whoi * 5) / 20)
 '--if if aligned in at least one direction and passibility is enabled ... and some vehicle stuff ...
 IF want_to_check_for_walls(whoi) THEN
  IF readbit(gen(), 44, suspendherowalls) = 0 AND vehicle_is_animating() = NO THEN
   '--this only happens if herowalls is on
   '--wrapping passability
   wrappass thisherotilex, thisherotiley, xgo(whoi), ygo(whoi), vstate.active
  END IF
  IF readbit(gen(), 44, suspendobstruction) = 0 AND vehicle_is_animating() = NO THEN
   '--this only happens if obstruction is on
   FOR i = 0 TO 299
    IF npc(i).id > 0 THEN '---NPC EXISTS---
     IF npcs(npc(i).id - 1).activation < 2 THEN '---NPC IS AN OBSTRUCTION---
      IF wrapcollision (npc(i).x, npc(i).y, npc(i).xgo, npc(i).ygo, catx(whoi * 5), caty(whoi * 5), xgo(whoi), ygo(whoi)) THEN
       xgo(whoi) = 0: ygo(whoi) = 0
       id = (npc(i).id - 1)
       '--push the NPC
       pushtype = npcs(id).pushtype
       IF pushtype > 0 AND npc(i).xgo = 0 AND npc(i).ygo = 0 THEN
        IF catd(whoi) = 0 AND (pushtype = 1 OR pushtype = 2 OR pushtype = 4) THEN npc(i).ygo = 20
        IF catd(whoi) = 2 AND (pushtype = 1 OR pushtype = 2 OR pushtype = 6) THEN npc(i).ygo = -20
        IF catd(whoi) = 3 AND (pushtype = 1 OR pushtype = 3 OR pushtype = 7) THEN npc(i).xgo = 20
        IF catd(whoi) = 1 AND (pushtype = 1 OR pushtype = 3 OR pushtype = 5) THEN npc(i).xgo = -20
        IF readbit(gen(), genBits2, 0) = 0 THEN ' Only do this if the backcompat bitset is off
         FOR o = 0 TO 299 ' check to make sure no other NPCs are blocking this one
          IF npc(o).id <= 0 THEN CONTINUE FOR 'Ignore empty NPC slots and negative (tag-disabled) NPCs
          IF i = o THEN CONTINUE FOR
          IF wrapcollision (npc(i).x, npc(i).y, npc(i).xgo, npc(i).ygo, npc(o).x, npc(o).y, npc(o).xgo, npc(o).ygo) THEN
           npc(i).xgo = 0
           npc(i).ygo = 0
           EXIT FOR
          END IF
         NEXT o
        END IF
       END IF
       IF npcs(id).activation = 1 AND whoi = 0 THEN
        IF wraptouch(npc(i).x, npc(i).y, catx(0), caty(0), 20) THEN
         txt.sayer = i
         usething 1, npc(i).x, npc(i).y
        END IF
       END IF '---autoactivate
      END IF ' ---NPC IS IN THE WAY
     END IF ' ---NPC IS AN OBSTRUCTION
    END IF '---NPC EXISTS
   NEXT i
  END IF
 END IF'--this only gets run when starting a movement to a new tile
NEXT whoi
'--if the leader moved last time, and catapillar is enabled then make others trail
IF readbit(gen(), 44, suspendcatapillar) = 0 THEN
 IF xgo(0) OR ygo(0) THEN
  FOR i = 15 TO 1 STEP -1
   catx(i) = catx(i - 1)
   caty(i) = caty(i - 1)
   catd(i) = catd(i - 1)
  NEXT i
  FOR whoi = 0 TO 3
   wtog(whoi) = loopvar(wtog(whoi), 0, 3, 1)
  NEXT whoi
 END IF
ELSE
 FOR whoi = 0 TO 3
  IF xgo(whoi) OR ygo(whoi) THEN wtog(whoi) = loopvar(wtog(whoi), 0, 3, 1)
 NEXT whoi
END IF
FOR whoi = 0 TO 3
 didgo(whoi) = 0
 IF xgo(whoi) OR ygo(whoi) THEN
  '--this actualy updates the heros coordinates
  IF xgo(whoi) > 0 THEN xgo(whoi) = xgo(whoi) - herospeed(whoi): catx(whoi * 5) = catx(whoi * 5) - herospeed(whoi): didgo(whoi) = 1
  IF xgo(whoi) < 0 THEN xgo(whoi) = xgo(whoi) + herospeed(whoi): catx(whoi * 5) = catx(whoi * 5) + herospeed(whoi): didgo(whoi) = 1
  IF ygo(whoi) > 0 THEN ygo(whoi) = ygo(whoi) - herospeed(whoi): caty(whoi * 5) = caty(whoi * 5) - herospeed(whoi): didgo(whoi) = 1
  IF ygo(whoi) < 0 THEN ygo(whoi) = ygo(whoi) + herospeed(whoi): caty(whoi * 5) = caty(whoi * 5) + herospeed(whoi): didgo(whoi) = 1
 END IF

 o = whoi
 '--if catapillar is not suspended, only the leader's motion matters
 IF readbit(gen(), 44, suspendcatapillar) = 0 THEN o = 0

 '--leader always checks harm tiles, allies only if caterpillar is enabled
 IF whoi = 0 OR readbit(gen(), 101, 1) = 1 THEN
  '--Stuff that should only happen when you finish moving
  IF didgo(o) = 1 AND xgo(o) = 0 AND ygo(o) = 0 THEN
   '---check for harm tile
   p = readpassblock(catx(whoi * 5) \ 20, caty(whoi * 5) \ 20)
   IF (p AND 64) THEN
    o = -1
    FOR i = 0 TO whoi
     o = o + 1
     WHILE hero(o) = 0 AND o < 4: o = o + 1: WEND
    NEXT i
    IF o < 4 THEN
     stat(o, 0, statHP) = large(stat(o, 0, statHP) - gmap(9), 0)
     IF gmap(10) THEN
      harmtileflash = YES
     END IF
    END IF
    '--check for death
    fatal = checkfordeath(stat())
   END IF
  END IF
 END IF
 cropmovement catx(whoi * 5), caty(whoi * 5), xgo(whoi), ygo(whoi)
NEXT whoi
'--only the leader may activate NPCs
IF (xgo(0) MOD 20 = 0) AND (ygo(0) MOD 20 = 0) AND (didgo(0) = 1 OR force_npc_check = YES) THEN
 '--finished a step
 force_npc_check = NO
 IF readbit(gen(), 44, suspendobstruction) = 0 THEN
  '--this only happens if obstruction is on
  FOR i = 0 TO 299
   IF npc(i).id > 0 THEN '---NPC EXISTS---
    IF vstate.active = NO OR (vstate.dat.enable_npc_activation = YES AND vstate.npc <> i) THEN
     IF npcs(npc(i).id - 1).activation = 2 THEN '---NPC IS PASSABLE---
      IF npc(i).x = catx(0) AND npc(i).y = caty(0) THEN '---YOU ARE ON NPC---
       txt.sayer = i
       usething 1, npc(i).x, npc(i).y
      END IF'---YOU ARE ON NPC---
     END IF ' ---NPC IS PASSABLE---
    END IF '--vehicle okay
   END IF '---NPC EXISTS
  NEXT i
 END IF
 IF didgo(0) = 1 THEN 'only check doors if the hero really moved, not just if force_npc_check = YES
  opendoor
 END IF
 IF needf = 0 THEN
  temp = readfoemap(catx(0) \ 20, caty(0) \ 20, scroll(0), scroll(1), foemaph)
  IF vstate.active = YES AND vstate.dat.random_battles > 0 THEN temp = vstate.dat.random_battles
  IF temp > 0 THEN gam.random_battle_countdown = large(gam.random_battle_countdown - gam.foe_freq(temp - 1), 0)
 END IF
 IF gmap(14) > 0 THEN
  rsr = runscript(gmap(14), nowscript + 1, -1, "eachstep", plottrigger)
  IF rsr = 1 THEN
   setScriptArg 0, catx(0) \ 20
   setScriptArg 1, caty(0) \ 20
   setScriptArg 2, catd(0)
  END IF
 END IF
END IF
setmapxy
RETRACE

movenpc:
FOR o = 0 TO 299
 IF npc(o).id > 0 THEN
  id = (npc(o).id - 1)
  '--if this is the active vehicle
  IF vstate.active = YES AND vstate.npc = o THEN
   '-- if we are not scrambling clearing or aheading
   IF vstate.mounting = NO AND vstate.trigger_cleanup = NO AND vstate.ahead = NO THEN
    '--match vehicle to main hero
    npc(o).x = catx(0)
    npc(o).y = caty(0)
    npc(o).dir = catd(0)
    npc(o).frame = wtog(0)
   END IF
  ELSE
   movetype = npcs(id).movetype
   speedset = npcs(id).speed
   IF movetype > 0 AND (speedset > 0 OR movetype = 8) AND txt.sayer <> o AND readbit(gen(), 44, suspendnpcs) = 0 THEN
    IF npc(o).xgo = 0 AND npc(o).ygo = 0 THEN
     'RANDOM WANDER---
     IF movetype = 1 THEN
      rand = 25
      IF wraptouch(npc(o).x, npc(o).y, catx(0), caty(0), 20) THEN rand = 5
      IF INT(RND * 100) < rand THEN
       temp = INT(RND * 4)
       npc(o).dir = temp
       IF temp = 0 THEN npc(o).ygo = 20
       IF temp = 2 THEN npc(o).ygo = -20
       IF temp = 3 THEN npc(o).xgo = 20
       IF temp = 1 THEN npc(o).xgo = -20
      END IF
     END IF '---RANDOM WANDER
     'ASSORTED PACING---
     IF movetype > 1 AND movetype < 6 THEN
      IF npc(o).dir = 0 THEN npc(o).ygo = 20
      IF npc(o).dir = 2 THEN npc(o).ygo = -20
      IF npc(o).dir = 3 THEN npc(o).xgo = 20
      IF npc(o).dir = 1 THEN npc(o).xgo = -20
     END IF '---ASSORTED PACING
     'CHASE/FLEE---
     IF movetype > 5 AND movetype < 8 THEN
      rand = 100
      IF INT(RND * 100) < rand THEN
       IF INT(RND * 100) < 50 THEN
        IF caty(0) < npc(o).y THEN temp = 0
        IF caty(0) > npc(o).y THEN temp = 2
        IF gmap(5) = 1 AND caty(0) - scroll(1) * 10 > npc(o).y THEN temp = 0
        IF gmap(5) = 1 AND caty(0) + scroll(1) * 10 < npc(o).y THEN temp = 2
        IF caty(0) = npc(o).y THEN temp = INT(RND * 4)
       ELSE
        IF catx(0) < npc(o).x THEN temp = 3
        IF catx(0) > npc(o).x THEN temp = 1
        IF gmap(5) = 1 AND catx(0) - scroll(0) * 10 > npc(o).x THEN temp = 3
        IF gmap(5) = 1 AND catx(0) + scroll(0) * 10 < npc(o).x THEN temp = 1
        IF catx(0) = npc(o).x THEN temp = INT(RND * 4)
       END IF
       IF movetype = 7 THEN temp = loopvar(temp, 0, 3, 2)
       npc(o).dir = temp
       IF temp = 0 THEN npc(o).ygo = 20
       IF temp = 2 THEN npc(o).ygo = -20
       IF temp = 3 THEN npc(o).xgo = 20
       IF temp = 1 THEN npc(o).xgo = -20
      END IF
     END IF '---CHASE/FLEE
     'WALK IN PLACE---
     IF movetype = 8 THEN
      npc(o).frame = loopvar(npc(o).frame, 0, 3, 1)
     END IF '---WALK IN PLACE
    END IF
   END IF
  END IF
  IF npc(o).xgo <> 0 OR npc(o).ygo <> 0 THEN GOSUB movenpcgo
 END IF
NEXT o
RETRACE

movenpcgo:
npc(o).frame = loopvar(npc(o).frame, 0, 3, 1)
IF movdivis(npc(o).xgo) OR movdivis(npc(o).ygo) THEN
 IF readbit(gen(), 44, suspendnpcwalls) = 0 THEN
  '--this only happens if NPC walls on
  IF wrappass(npc(o).x \ 20, npc(o).y \ 20, npc(o).xgo, npc(o).ygo, 0) THEN
   npc(o).xgo = 0
   npc(o).ygo = 0
   GOSUB hitwall
   GOTO nogo
  END IF
 END IF
 IF readbit(gen(), 44, suspendobstruction) = 0 THEN
  '--this only happens if obstruction is on
  FOR i = 0 TO 299
   IF npc(i).id > 0 AND o <> i THEN
    IF wrapcollision (npc(i).x, npc(i).y, npc(i).xgo, npc(i).ygo, npc(o).x, npc(o).y, npc(o).xgo, npc(o).ygo) THEN
     npc(o).xgo = 0
     npc(o).ygo = 0
     GOSUB hitwall
     GOTO nogo
    END IF
   END IF
  NEXT i
  '---CHECK THAT NPC IS OBSTRUCTABLE-----
  IF npc(o).id > 0 THEN
   IF npcs(npc(o).id - 1).activation < 2 THEN
    IF wrapcollision (npc(o).x, npc(o).y, npc(o).xgo, npc(o).ygo, catx(0), caty(0), xgo(0), ygo(0)) THEN
     npc(o).xgo = 0
     npc(o).ygo = 0
     '--a 0-3 tick delay before pacing enemies bounce off hero
     IF npc(o).frame = 3 THEN
      GOSUB hitwall
      GOTO nogo
     END IF
    END IF
   END IF
  END IF
 END IF
END IF
IF npcs(id).speed THEN
 '--change x,y and decrement wantgo by speed
 IF npc(o).xgo > 0 THEN npc(o).xgo = npc(o).xgo - npcs(id).speed: npc(o).x = npc(o).x - npcs(id).speed
 IF npc(o).xgo < 0 THEN npc(o).xgo = npc(o).xgo + npcs(id).speed: npc(o).x = npc(o).x + npcs(id).speed
 IF npc(o).ygo > 0 THEN npc(o).ygo = npc(o).ygo - npcs(id).speed: npc(o).y = npc(o).y - npcs(id).speed
 IF npc(o).ygo < 0 THEN npc(o).ygo = npc(o).ygo + npcs(id).speed: npc(o).y = npc(o).y + npcs(id).speed
ELSE
 '--no speed, kill wantgo
 npc(o).xgo = 0
 npc(o).ygo = 0
END IF
IF cropmovement(npc(o).x, npc(o).y, npc(o).xgo, npc(o).ygo) THEN GOSUB hitwall
nogo:
IF npcs(id).activation = 1 AND txt.showing = NO THEN
 IF wraptouch(npc(o).x, npc(o).y, catx(0), caty(0), 20) THEN
  txt.sayer = o
  usething 1, npc(o).x, npc(o).y
 END IF
END IF
RETRACE

hitwall:
IF npcs(id).movetype = 2 THEN npc(o).dir = loopvar(npc(o).dir, 0, 3, 2)
IF npcs(id).movetype = 3 THEN npc(o).dir = loopvar(npc(o).dir, 0, 3, 1)
IF npcs(id).movetype = 4 THEN npc(o).dir = loopvar(npc(o).dir, 0, 3, -1)
IF npcs(id).movetype = 5 THEN npc(o).dir = INT(RND * 4)
RETRACE

interpret:
IF nowscript >= 0 THEN
WITH scrat(nowscript)
 SELECT CASE .state
  CASE IS < stnone
   scripterr "illegally suspended script", 6
   .state = ABS(.state)
  CASE stnone
   scripterr "script " & nowscript & " became stateless", 6
  CASE stwait
   '--evaluate wait conditions
   SELECT CASE .curvalue
    CASE 15, 35, 61'--use door, use NPC, teleport to map
     .state = streturn
    CASE 16'--fight formation
     scriptret = gam.wonbattle
     .state = streturn
    CASE 1'--wait number of ticks
     .waitarg -= 1
     IF .waitarg < 1 THEN
      .state = streturn
     END IF
    CASE 2'--wait for all
     n = 0
     FOR i = 0 TO 3
      IF xgo(i) <> 0 OR ygo(i) <> 0 THEN n = 1
     NEXT i
     IF readbit(gen(), 44, suspendnpcs) = 1 THEN
      FOR i = 0 TO 299
       IF npc(i).xgo <> 0 OR npc(i).ygo <> 0 THEN n = 1
       EXIT FOR
      NEXT i
     END IF
     IF gen(cameramode) = pancam OR gen(cameramode) = focuscam THEN n = 1
     IF n = 0 THEN
      .state = streturn
     END IF
    CASE 3'--wait for hero
     IF .waitarg < 0 OR .waitarg > 3 THEN
      scripterr "waiting for nonexistant hero " & .waitarg, 6  'should be bound by waitforhero
      .state = streturn
     ELSE
      IF xgo(.waitarg) = 0 AND ygo(.waitarg) = 0 THEN
       .state = streturn
      END IF
     END IF
    CASE 4'--wait for NPC
     npcref = getnpcref(.waitarg, 0)
     IF npcref >= 0 THEN
      IF npc(npcref).xgo = 0 AND npc(npcref).ygo = 0 THEN
       .state = streturn
      END IF
     ELSE
      '--no reference found, why wait for a non-existant npc?
      .state = streturn
     END IF
    CASE 9'--wait for key
     IF .waitarg >= 0 AND .waitarg <= 5 THEN
      IF carray(.waitarg) > 1 THEN
       .state = streturn
      END IF
     ELSE
      FOR i = 0 TO 5
       IF carray(i) > 1 THEN
        scriptret = csetup(i)
        .state = streturn
       END IF
      NEXT i
      FOR i = 1 TO 127
       IF keyval(i) > 1 THEN
        scriptret = i
        .state = streturn
       END IF
      NEXT i
     END IF
    CASE 244'--wait for scancode
     IF keyval(.waitarg) > 1 THEN
      .state = streturn
     END IF
    CASE 42'--wait for camera
     IF gen(cameramode) <> pancam AND gen(cameramode) <> focuscam THEN .state = streturn
    CASE 59'--wait for text box
     IF txt.showing = NO OR readbit(gen(), 44, suspendboxadvance) = 1 THEN
      .state = streturn
     END IF
    CASE 73, 234, 438'--game over, quit from loadmenu, reset game
    CASE ELSE
     scripterr "illegal wait substate " & .curvalue, 6
     .state = streturn
   END SELECT
   IF .state = streturn THEN
    '--this allows us to resume the script without losing a game cycle
    wantimmediate = -1
   END IF
  CASE ELSE
   '--interpret script
   reloadscript scrat(nowscript)
   insideinterpreter = YES
#IFDEF SCRIPTPROFILE
   scrat(nowscript).scr->entered += 1
   TIMER_START(scrat(nowscript).scr->totaltime)
#ENDIF
   GOSUB interpretloop
   '--WARNING: WITH pointer probably corrupted
#IFDEF SCRIPTPROFILE
   IF nowscript >= 0 THEN TIMER_STOP(scrat(nowscript).scr->totaltime)
#ENDIF
   insideinterpreter = NO
 END SELECT
 IF wantimmediate = -2 THEN
'  IF nowscript < 0 THEN
'   debug "wantimmediate ended on nowscript = -1"
'  ELSE
'   debug "wantimmediate would have skipped wait on command " & scrat(nowscript).curvalue & " in " & scriptname$(scrat(nowscript).id) & ", state = " & scrat(nowscript).state
'   debug "needf = " & needf
'  END IF
  wantimmediate = 0 'change to -1 to reenable bug
 END IF
 IF wantimmediate = -1 THEN
  '--wow! I hope this doesnt screw things up!
  wantimmediate = 0
  GOTO interpret
 END IF
END WITH
END IF
'--do spawned text boxes, battles, etc.
IF wantbox > 0 THEN
 loadsay wantbox
 wantbox = 0
END IF
IF wantdoor > 0 THEN
 opendoor wantdoor
 wantdoor = 0
 IF needf = 0 THEN
  temp = readfoemap(INT(catx(0) / 20), INT(caty(0) / 20), scroll(0), scroll(1), foemaph)
  IF vstate.active = YES AND vstate.dat.random_battles > 0 THEN temp = vstate.dat.random_battles
  IF temp > 0 THEN gam.random_battle_countdown = large(gam.random_battle_countdown - gam.foe_freq(temp - 1), 0)
 END IF
 setmapxy
END IF
IF wantbattle > 0 THEN
 fatal = 0
 gam.wonbattle = battle(wantbattle - 1, fatal, stat())
 wantbattle = 0
 prepare_map YES
 gam.random_battle_countdown = range(100, 60)
 needf = 3
 setkeys
END IF
IF wantteleport > 0 THEN
 wantteleport = 0
 prepare_map
 gam.random_battle_countdown = range(100, 60)
END IF
IF wantusenpc > 0 THEN
 txt.sayer = wantusenpc - 1
 wantusenpc = 0
 usething 2, 0, 0
END IF
RETRACE

interpretloop:
DIM tmpstate, tmpcase  'tmpstart, tmpend, tmpstep, tmpnow, tmpvar
WITH scrat(nowscript)
DO
 SELECT CASE .state
  CASE stnext'---check if all args are done
   IF scrwatch AND breakstnext THEN breakpoint scrwatch, 1
   IF .curargn >= curcmd->argc THEN
    '--pop return values of each arg
    '--evaluate function, math, script, whatever
    '--scriptret would be set here, pushed at return
    SELECT CASE curcmd->kind
     CASE tystop
      scripterr "stnext encountered noop " & curcmd->value & " at " & .ptr & " in " & nowscript, 5
      killallscripts
      EXIT DO
     CASE tymath, tyfunct
      '--complete math and functions, nice and easy.
      FOR i = curcmd->argc - 1 TO 0 STEP -1
       pops(scrst, retvals(i))
      NEXT i
      .state = streturn
      IF curcmd->kind = tymath THEN
       scriptmath
       '.state = streturn
      ELSE
       GOSUB sfunctions
       '--WARNING: WITH pointer probably corrupted
       '--nowscript might be changed
       '--unless you have switched to wait mode, return
       'IF scrat(nowscript).state = stnext THEN scrat(nowscript).state = streturn'---return
       GOTO interpretloop 'new WITH pointer
      END IF
     CASE tyflow
      '--finish flow control? tricky!
      SELECT CASE curcmd->value
       CASE flowwhile'--repeat or terminate while
        SELECT CASE .curargn
         CASE 2
          '--if a while statement finishes normally (argn is 2) then it repeats.
          scrst.pos -= 2
          .curargn = 0
         CASE ELSE
          scripterr "while fell out of bounds, landed on " & .curargn, 6
          killallscripts
          EXIT DO
        END SELECT
       CASE flowfor'--repeat or terminate for
        SELECT CASE .curargn
         CASE 5
          '--normal for termination means repeat
          scrst.pos -= 1
          tmpvar = reads(scrst, -3)
          writescriptvar tmpvar, readscriptvar(tmpvar) + reads(scrst, 0)
          .curargn = 4
         CASE ELSE
          scripterr "for fell out of bounds, landed on " & .curargn, 6
          killallscripts
          EXIT DO
        END SELECT
       CASE flowreturn
        pops(scrst, .ret)
        .state = streturn'---return
       CASE flowbreak
        pops(scrst, temp)
        unwindtodo(scrat(nowscript), temp)
        '--for and while need to be broken
        IF curcmd->kind = tyflow AND (curcmd->value = flowfor OR curcmd->value = flowwhile) THEN
         GOSUB dumpandreturn
         '--WARNING: WITH pointer probably corrupted
        END IF
       CASE flowcontinue
        pops(scrst, temp)
        unwindtodo(scrat(nowscript), temp)
        IF curcmd->kind = tyflow AND curcmd->value = flowswitch THEN
         '--set state to 2
         scrst.pos -= 2
         pushs(scrst, 2)
         pushs(scrst, 0) '-- dummy value
        ELSEIF NOT (curcmd->kind = tyflow AND (curcmd->value = flowfor OR curcmd->value = flowwhile)) THEN
         '--if this do isn't a for's or while's, then just repeat it, discarding the returned value
         scrst.pos -= 1
         .curargn -= 1
        END IF
       CASE flowexit
        unwindtodo(scrat(nowscript), 9999)
       CASE flowexitreturn
        pops(scrst, .ret)
        unwindtodo(scrat(nowscript), 9999)
       CASE flowswitch
        scrst.pos -= 3
        scriptret = 0
        .state = streturn
       CASE ELSE
        '--do, then, etc... terminate normally
        GOSUB dumpandreturn
        '--WARNING: WITH pointer probably corrupted
      END SELECT
      '.state = streturn'---return
     CASE tyscript
      rsr = runscript(curcmd->value, nowscript + 1, 0, "indirect", 0)
      IF rsr = 1 THEN
       '--fill heap with return values
       FOR i = .curargc - 1 TO 0 STEP -1   '--be VERY careful... runscript set curargc, WITH points to nowscript-1
        pops(scrst, temp)
        setScriptArg i, temp
       NEXT i
      END IF
      IF rsr = 0 THEN
       .state = streturn'---return
      END IF
      GOTO interpretloop 'new WITH pointer
     CASE ELSE
      scripterr "illegal kind " & curcmd->kind & " " & curcmd->value & " in stnext", 5
      killallscripts
      EXIT DO
    END SELECT
   ELSE
    IF .curargn = 0 THEN
     '--always need to execute the first argument
     .state = stdoarg
    ELSE 
     '--flow control and logical math are special, for all else, do next arg
     SELECT CASE curcmd->kind
      CASE tyflow
       SELECT CASE curcmd->value
        CASE flowif'--we got an if!
         SELECT CASE .curargn
          CASE 0
           .state = stdoarg'---call conditional
          CASE 1
           IF reads(scrst, 0) THEN
            'scrst.pos -= 1
            .state = stdoarg'---call then block
           ELSE
            .curargn = 2
            '--if-else needs one extra thing on the stack to account for the then that didnt get used.
            pushs(scrst, 0)
            .state = stdoarg'---call else block
           END IF
          CASE 2
           '--finished then but not at end of argument list: skip else
           GOSUB dumpandreturn
           '--WARNING: WITH pointer probably corrupted
          CASE ELSE
           scripterr "if statement overstepped bounds", 6
         END SELECT
        CASE flowwhile'--we got a while!
         SELECT CASE .curargn
          CASE 0
           .state = stdoarg'---call condition
          CASE 1
           IF reads(scrst, 0) THEN
            .state = stdoarg'---call do block
            '--don't pop: number of words on stack should equal argn (for simplicity when unwinding stack)
           ELSE
            '--break while
            scrst.pos -= 1
            scriptret = 0
            .state = streturn'---return
           END IF
          CASE ELSE
          scripterr "while statement has jumped the curb", 6
         END SELECT
        CASE flowfor'--we got a for!
         SELECT CASE .curargn
          '--argn 0 is var
          '--argn 1 is start
          '--argn 2 is end
          '--argn 3 is step
          '--argn 4 is do block
          '--argn 5 is repeat (normal termination)
          CASE 0, 1, 3
           '--get var, start, and later step
           .state = stdoarg
          CASE 2
           '--set variable to start val before getting end
           writescriptvar reads(scrst, -1), reads(scrst, 0)
           '---now get end value
           .state = stdoarg
          CASE 4
           IF scrwatch AND breakloopbrch THEN breakpoint scrwatch, 5
           tmpstep = reads(scrst, 0)
           tmpend = reads(scrst, -1)
           tmpstart = reads(scrst, -2)
           tmpvar = reads(scrst, -3)
           tmpnow = readscriptvar(tmpvar)
           IF (tmpnow > tmpend AND tmpstep > 0) OR (tmpnow < tmpend AND tmpstep < 0) THEN
            '--breakout
            scrst.pos -= 4
            scriptret = 0
            .state = streturn'---return
           ELSE
            .state = stdoarg'---execute the do block
           END IF
          CASE ELSE
           scripterr "for statement is being difficult", 6
         END SELECT
        CASE flowswitch
         IF .curargn = 0 THEN
          '--get expression to match
          .state = stdoarg
         ELSEIF .curargn = 1 THEN
          '--set up state - push a 0: not fallen in
          '--assume first statement is a case, run it
          pushs(scrst, 0)
          .state = stdoarg
         ELSE
          pops(scrst, tmpcase)
          pops(scrst, tmpstate)
          doseek = 0 ' whether or not to search argument list for something to execute
          IF tmpstate = 0 THEN
           '--not fallen in, check tmpvar
           IF tmpcase = reads(scrst, 0) THEN 
            tmpstate = 1
           END IF
           doseek = 1 '--search for a case or do
          ELSEIF tmpstate = 1 THEN
           '--after successfully running a do block, pop off matching value and exit
           scrst.pos -= 1
           scriptret = 0
           .state = streturn'---return
          ELSEIF tmpstate = 2 THEN
           '--continue encountered, fall back in
           tmpstate = 1
           doseek = 1 '--search for a do
          END IF

          WHILE doseek
           tmpkind = .scrdata[curcmd->args(.curargn)]

           IF (tmpstate = 1 AND tmpkind = tyflow) OR (tmpstate = 0 AND (tmpkind <> tyflow OR .curargn = curcmd->argc - 1)) THEN
            '--fall into a do, execute a case, or run default (last arg)
            .state = stdoarg
            pushs(scrst, tmpstate)
            EXIT WHILE
           END IF
           IF .curargn >= curcmd->argc THEN
            scrst.pos -= 1
            scriptret = 0
            .state = streturn'---return
            EXIT WHILE
           END IF
           .curargn += 1
          WEND
         END IF
        CASE ELSE
         .state = stdoarg'---call argument
       END SELECT
      CASE tymath
       SELECT CASE curcmd->value
        CASE 20'--logand
         IF reads(scrst, 0) THEN
          .state = stdoarg'---call 2nd argument
         ELSE
          '--shortcut evaluate to false
          scriptret = 0
          '--pop all args
          scrst.pos -= .curargn
          .state = streturn'---return
         END IF
        CASE 21'--logor
         IF reads(scrst, 0) THEN
          '--shortcut evaluate to true
          scriptret = 1
          '--pop all args
          scrst.pos -= .curargn
          .state = streturn'---return
         ELSE
          .state = stdoarg'---call 2nd argument
         END IF
        CASE ELSE
         .state = stdoarg'---call argument
       END SELECT
      CASE ELSE
       .state = stdoarg'---call argument
     END SELECT
    END IF
   END IF
  CASE streturn'---return
   '--sets stdone if done with entire script, stnext otherwise
   subreturn scrat(nowscript)
  CASE stdoarg'---do argument
   '--evaluate an arg, either directly or by changing state. stnext will be next
   subdoarg scrat(nowscript)
  CASE stread'---read statement
   '--FIRST STATE
   '--just load the first command
   subread scrat(nowscript)
  CASE stwait'---begin waiting for something
   .curkind = curcmd->kind
   .curvalue = curcmd->value
   .curargc = curcmd->argc
   EXIT DO
  CASE stdone'---script terminates
   '--if resuming a supended script, restore its state (normally stwait)
   '--if returning a value to a calling script, set streturn
   '--if no scripts left, break the loop
   SELECT CASE functiondone
    CASE 1
     EXIT DO
    CASE 2
     IF scrat(nowscript).state <> stwait THEN
'      debug "WANTIMMEDIATE BUG"
'      debug scriptname$(scrat(nowscript + 1).id) & " terminated, setting wantimmediate on " & scriptname$(scrat(nowscript).id)
      wantimmediate = -2
     ELSE
      wantimmediate = -1
     END IF
   END SELECT
   IF scrwatch AND breakstnext THEN breakpoint scrwatch, 2
   GOTO interpretloop 'new WITH pointer
  CASE sterror'---some error has occurred, crash and burn
   '--note that there's no thought out plan for handling errors
   killallscripts
   EXIT DO
 END SELECT
LOOP
END WITH
RETRACE

dumpandreturn:
scrst.pos -= scrat(nowscript).curargn
scriptret = 0
scrat(nowscript).state = streturn'---return
RETRACE

'---DO THE ACTUAL EFFECTS OF MATH AND FUNCTIONS----
sfunctions:
DIM menuslot AS INTEGER = 0
DIM mislot AS INTEGER = 0
scriptret = 0
WITH scrat(nowscript)
  'the only commands that belong at the top level are the ones that need
  'access to main-module top-level global variables or GOSUBs
  SELECT CASE AS CONST curcmd->value
   CASE 11'--Show Text Box (box)
    wantbox = retvals(0)
   CASE 15'--use door
    wantdoor = retvals(0) + 1
    .waitarg = 0
    .state = stwait
   CASE 16'--fight formation
    IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxFormation) THEN
     wantbattle = retvals(0) + 1
     .waitarg = 0
     .state = stwait
    ELSE
     scriptret = -1
    END IF
   CASE 23'--unequip
    IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
     i = retvals(0)
     unequip i, bound(retvals(1) - 1, 0, 4), stat(i, 0, 16), stat(), 1
    END IF
    evalitemtag
   CASE 24'--force equip
    IF bound_hero_party(retvals(0), "force equip") THEN
     i = retvals(0)
     IF bound_item(retvals(2), "force equip") THEN
      unequip i, bound(retvals(1) - 1, 0, 4), stat(i, 0, 16), stat(), 0
      doequip retvals(2) + 1, i, bound(retvals(1) - 1, 0, 4), stat(i, 0, 16), stat()
     END IF
    END IF
    evalitemtag
   CASE 32'--show backdrop
    gen(genScrBackdrop) = bound(retvals(0) + 1, 0, gen(genMaxBackdrop))
    correctbackdrop
   CASE 33'--show map
    gen(genScrBackdrop) = 0
    correctbackdrop
   CASE 34'--dismount vehicle
    forcedismount catd()
   CASE 35'--use NPC
    npcref = getnpcref(retvals(0), 0)
    IF npcref >= 0 THEN
     wantusenpc = npcref + 1
     .waitarg = 0
     .state = stwait
    END IF
   CASE 37'--use shop
    IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxShop) THEN
     shop retvals(0), needf, stat(), tilesets()
     reloadnpc stat()
    END IF
   CASE 55'--get default weapon
    IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
     scriptret = stat(retvals(0), 0, 16) - 1
    ELSE
     scriptret = 0
    END IF
   CASE 56'--set default weapon
    IF bound_hero_party(retvals(0), "set default weapon") THEN
     IF bound_item(retvals(1), "set default weapon") THEN
      '--identify new default weapon
      newdfw = retvals(1) + 1
      '--remember old default weapon
      olddfw = stat(retvals(0), 0, 16)
      '--remeber currently equipped weapon
      cureqw = eqstuf(retvals(0), 0)
      '--change default
      stat(retvals(0), 0, 16) = newdfw
      '--blank weapon
      unequip retvals(0), 0, olddfw, stat(), 0
      IF cureqw <> olddfw THEN
       '--if previously using a weapon, re-equip old weapon
       doequip cureqw, retvals(0), 0, newdfw, stat()
      ELSE
       '--otherwize equip new default weapon
       doequip newdfw, retvals(0), 0, newdfw, stat()
      END IF
     END IF
    END IF
   CASE 61'--teleport to map
    IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxMap) THEN
     gam.map.id = retvals(0)
     FOR i = 0 TO 3
      catx(i) = retvals(1) * 20
      caty(i) = retvals(2) * 20
     NEXT i
     wantteleport = 1
     .waitarg = 0
     .state = stwait
    END IF
   CASE 63, 169'--resume random enemies
    setbit gen(), 44, suspendrandomenemies, 0
    gam.random_battle_countdown = range(100, 60)
   CASE 73'--game over
    abortg = 1
    .state = stwait
   CASE 77'--show value
    scriptout$ = STR$(retvals(0))
   CASE 78'--alter NPC
    IF retvals(1) >= 0 AND retvals(1) <= 14 THEN
     IF retvals(0) < 0 AND retvals(0) >= -300 THEN retvals(0) = ABS(npc(ABS(retvals(0) + 1)).id) - 1
     IF retvals(0) >= 0 AND retvals(0) <= max_npc_defs THEN
      writesafe = 1
      IF retvals(1) = 0 THEN
       IF retvals(2) < 0 OR retvals(2) > gen(genMaxNPCPic) THEN
        writesafe = 0
       ELSE
        if npcs(retvals(0)).sprite then sprite_unload(@npcs(retvals(0)).sprite)
        npcs(retvals(0)).sprite = sprite_load(4, retvals(2))
       END IF
      END IF
      IF retvals(1) = 1 THEN
       if npcs(retvals(0)).pal then palette16_unload(@npcs(retvals(0)).pal)
       npcs(retvals(0)).pal = palette16_load(retvals(2), 4, npcs(retvals(0)).picture)
      END IF
      IF writesafe THEN SetNPCD(npcs(retvals(0)), retvals(1), retvals(2))
     END IF
    END IF
   CASE 79'--show no value
    scriptout$ = ""
   CASE 80'--current map
    scriptret = gam.map.id
   CASE 86'--advance text box
    advance_text_box
   CASE 97'--read map block
    IF curcmd->argc = 2 THEN retvals(2) = 0
    scriptret = readmapblock(bound(retvals(0), 0, scroll(0)-1), bound(retvals(1), 0, scroll(1)-1), bound(retvals(2), 0, 2))
   CASE 98'--write map block
    IF curcmd->argc = 3 THEN retvals(3) = 0
    setmapblock bound(retvals(0), 0, scroll(0)-1), bound(retvals(1), 0, scroll(1)-1), bound(retvals(3),0,2), bound(retvals(2), 0, 255)
   CASE 99'--read pass block
    scriptret = readpassblock(bound(retvals(0), 0, pass(0)-1), bound(retvals(1), 0, pass(1)-1))
   CASE 100'--write pass block
    setpassblock bound(retvals(0), 0, pass(0)-1), bound(retvals(1), 0, pass(1)-1), bound(retvals(2), 0, 255)
   CASE 144'--load tileset
    'version that doesn't modify gmap
    IF retvals(0) <= gen(genMaxTile) THEN
     IF retvals(1) < 0 OR curcmd->argc <= 1 THEN
      '0 or 1 args given
      IF retvals(0) < 0 THEN
       'reload all defaults
       loadmaptilesets tilesets(), gmap(), NO
      ELSE
       'change default
       IF gmap(22) = 0 THEN loadtilesetdata tilesets(), 0, retvals(0)
       IF gmap(23) = 0 THEN loadtilesetdata tilesets(), 1, retvals(0)
       IF gmap(24) = 0 THEN loadtilesetdata tilesets(), 2, retvals(0)
      END IF
     ELSEIF retvals(1) >= 0 AND retvals(1) <= 2 AND retvals(0) >= 0 THEN
      'load tileset for an individual layer. 
      loadtilesetdata tilesets(), retvals(1), retvals(0)
     END IF
     '--important to refresh map slices regardless of how the tileset was changed
     refresh_map_slice_tilesets
    END IF
   CASE 305'--change tileset
    'this version of load tileset modifies gmap() for persistent (given map state saving) effects
    IF retvals(0) <= gen(genMaxTile) THEN
     IF retvals(1) < 0 THEN
      IF retvals(0) < 0 THEN
       'reload all defaults
      ELSE
       'change default
       gmap(0) = retvals(0)
      END IF
     ELSEIF retvals(1) >= 0 AND retvals(1) <= 2 THEN
      'load tileset for an individual layer
      gmap(22 + retvals(1)) = large(0, retvals(0) + 1)
     END IF
     loadmaptilesets tilesets(), gmap(), NO
     refresh_map_slice_tilesets
    END IF
   CASE 151'--show mini map
    minimap catx(0), caty(0), tilesets()
   CASE 153'--items menu
    wantbox = items_menu(stat())
   CASE 155, 170'--save menu
    'ID 155 is a backcompat hack
    scriptret = picksave(0) + 1
    IF scriptret > 0 AND (retvals(0) OR curcmd->value = 155) THEN
     savegame scriptret - 1, stat()
    END IF
   CASE 166'--save in slot
    IF retvals(0) >= 1 AND retvals(0) <= 32 THEN
     savegame retvals(0) - 1, stat()
    END IF
   CASE 167'--last save slot
    scriptret = lastsaveslot
   CASE 174'--load from slot
    IF retvals(0) >= 1 AND retvals(0) <= 32 THEN
     IF checksaveslot(retvals(0) - 1) = 3 THEN
      wantloadgame = retvals(0)
      .state = stwait
     END IF
    END IF
   CASE 210'--show string
    IF retvals(0) >= 0 AND retvals(0) <= 31 THEN
     scriptout$ = plotstr(retvals(0)).s
    END IF
   CASE 234'--load menu
    scriptret = picksave(1) + 1
    IF retvals(0) THEN
     IF scriptret = -1 THEN
      abortg = 2  'don't go straight back to loadmenu!
      .state = stwait
      fadeout 0, 0, 0
     ELSEIF scriptret > 0 THEN
      wantloadgame = scriptret
      .state = stwait
     END IF
    END IF
   CASE 245'--save map state
    IF retvals(1) > -1 AND retvals(1) <= 31 THEN
     savemapstate retvals(1), retvals(0), "state"
    ELSEIF retvals(1) = 255 THEN
     savemapstate gam.map.id, retvals(0), "map"
    END IF
   CASE 246'--load map state
    IF retvals(1) > -1 AND retvals(1) <= 31 THEN
     loadmapstate retvals(1), retvals(0), "state", -1
    ELSEIF retvals(1) = 255 THEN
     loadmapstate gam.map.id, retvals(0), "map"
    END IF
   CASE 247'--reset map state
    loadmaplumps gam.map.id, retvals(0)
   CASE 248'--delete map state
    deletemapstate gam.map.id, retvals(0), "map"
   CASE 253'--settileanimationoffset
    IF curcmd->argc < 3 THEN retvals(2) = 0
    IF (retvals(0) = 0 OR retvals(0) = 1) AND retvals(2) >= 0 AND retvals(2) <= 2 THEN
     tilesets(retvals(2))->anim(retvals(0)).cycle = retvals(1) MOD 160
    END IF
   CASE 254'--gettileanimationoffset
    IF curcmd->argc < 2 THEN retvals(1) = 0
    IF (retvals(0) = 0 OR retvals(0) = 1) AND retvals(1) >= 0 AND retvals(1) <= 2 THEN
     scriptret = tilesets(retvals(1))->anim(retvals(0)).cycle
    END IF
   CASE 255'--animationstarttile
    IF curcmd->argc < 2 THEN retvals(1) = 0
    IF retvals(0) < 160 THEN
     scriptret = retvals(0)
    ELSEIF retvals(0) < 256 AND retvals(1) >= 0 AND retvals(1) <= 2 THEN
     scriptret = tilesets(retvals(1))->tastuf(((retvals(0) - 160) \ 48) * 20) + (retvals(0) - 160) MOD 48
    END IF
   CASE 258'--checkherowall
    IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
     tempxgo = 0
     tempygo = 0
     IF retvals(1) = 0 THEN tempygo = 20
     IF retvals(1) = 1 THEN tempxgo = -20
     IF retvals(1) = 2 THEN tempygo = -20
     IF retvals(1) = 3 THEN tempxgo = 20
     scriptret = wrappass(catx(retvals(0) * 5) \ 20, catx(retvals(0) * 5) \ 20, tempxgo, tempygo, 0)
    END IF
   CASE 259'--checkNPCwall
    npcref = getnpcref(retvals(0), 0)
    IF npcref >= 0 THEN
     'Only check walls for NPC who actually exists
     tempxgo = 0
     tempygo = 0
     IF retvals(1) = 0 THEN tempygo = 20
     IF retvals(1) = 1 THEN tempxgo = -20
     IF retvals(1) = 2 THEN tempygo = -20
     IF retvals(1) = 3 THEN tempxgo = 20
     scriptret = wrappass(npc(npcref).x \ 20, npc(npcref).y \ 20, tempxgo, tempygo, 0)
    END IF
   CASE 267'--main menu
    add_menu 0
   CASE 274'--open menu
    IF bound_arg(retvals(0), 0, gen(genMaxMenu), "open menu", "menu ID") THEN
     scriptret = add_menu(retvals(0), (retvals(1) <> 0))
    END IF
   CASE 275'--read menu int
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "read menu int") THEN
     scriptret = read_menu_int(menus(menuslot), retvals(1))
    END IF
   CASE 276'--write menu int
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "write menu int") THEN
     write_menu_int(menus(menuslot), retvals(1), retvals(2))
    END IF
   CASE 277'--read menu item int
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "read menu item int") THEN
     WITH menus(menuslot)
      IF .items(mislot).exists THEN scriptret = read_menu_item_int(.items(mislot), retvals(1))
     END WITH
    END IF
   CASE 278'--write menu item int
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "write menu item int") THEN
     WITH menus(menuslot)
      IF .items(mislot).exists THEN write_menu_item_int(.items(mislot), retvals(1), retvals(2))
     END WITH
    END IF
   CASE 279'--create menu
    scriptret = add_menu(-1)
    menus(topmenu).allow_gameplay = YES
   CASE 280'--close menu
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "close menu") THEN
     remove_menu menuslot
    END IF
   CASE 281'--top menu
    IF topmenu >= 0 THEN
     scriptret = menus(topmenu).handle
    END IF
   CASE 282'--bring menu forward
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "bring menu forward") THEN
     bring_menu_forward menuslot
    END IF
   CASE 283'--add menu item
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "add menu item") THEN
     i = append_menu_item(menus(menuslot), "")
     IF i >= 0 THEN
      scriptret = assign_menu_item_handle(menus(menuslot).items(i))
      mstates(menuslot).need_update = YES
     ELSE
      scripterr "add menu item: failed. menu " & menuslot & " is full", 3
     END IF
    END IF
   CASE 284'--delete menu item
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "delete menu item") THEN
     WITH menus(menuslot)
      ClearMenuItem .items(mislot)
      SortMenuItems .items()
     END WITH
     mstates(menuslot).need_update = YES
    END IF
   CASE 285'--get menu item caption
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "get menu item caption") THEN
     IF bound_plotstr(retvals(1), "get menu item caption") THEN
      plotstr(retvals(1)).s = get_menu_item_caption(menus(menuslot).items(mislot), menus(menuslot))
     END IF
    END IF
   CASE 286'--set menu item caption
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "set menu item caption") THEN
     IF bound_plotstr(retvals(1), "set menu item caption") THEN
      menus(menuslot).items(mislot).caption = plotstr(retvals(1)).s
     END IF
    END IF
   CASE 287'--get level mp
    IF bound_hero_party(retvals(0), "get level mp") THEN
     IF bound_arg(retvals(1), 0, 7, "get level mp", "mp level") THEN
      scriptret = lmp(retvals(0), retvals(1))
     END IF
    END IF
   CASE 288'--set level mp
    IF bound_hero_party(retvals(0), "set level mp") THEN
     IF bound_arg(retvals(1), 0, 7, "set level mp", "mp level") THEN
      lmp(retvals(0), retvals(1)) = retvals(2)
     END IF
    END IF
   CASE 289'--bottom menu
    IF topmenu >= 0 THEN
     scriptret = menus(0).handle
    END IF
   CASE 290'--previous menu
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "previous menu") THEN
     menuslot = menuslot - 1
     IF menuslot >= 0 THEN
      scriptret = menus(menuslot).handle
     END IF
    END IF
   CASE 291'--next menu
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "next menu") THEN
     menuslot = menuslot + 1
     IF menuslot <= topmenu THEN
      scriptret = menus(menuslot).handle
     END IF
    END IF
   CASE 292'--menu item by slot
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "menu item by slot") THEN
     scriptret = menu_item_handle_by_slot(menuslot, retvals(1), retvals(2)<>0)
    END IF
   CASE 293'--previous menu item
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "previous menu item") THEN
     scriptret = menu_item_handle_by_slot(menuslot, mislot - 1, retvals(1)<>0)
    END IF
   CASE 294'--next menu item
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "next menu item") THEN
     scriptret = menu_item_handle_by_slot(menuslot, mislot - 1, retvals(1)<>0)
    END IF
   CASE 295'--selected menu item
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "selected menu item") THEN
     scriptret = menu_item_handle_by_slot(menuslot, mstates(menuslot).pt)
    END IF
   CASE 296'--select menu item
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "select menu item") THEN
     mstates(menuslot).pt = menu_item_handle_by_slot(menuslot, mislot)
     mstates(menuslot).need_update = YES
    END IF
   CASE 297'--parent menu
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "parent menu") THEN
     scriptret = menus(menuslot).handle
    END IF
   CASE 298'--get menu ID
    menuslot = find_menu_handle(retvals(0))
    IF bound_menuslot(menuslot, "get menu ID") THEN
     scriptret = menus(menuslot).record
    END IF
   CASE 299'--swap menu items
    DIM AS INTEGER menuslot2, mislot2
    mislot = find_menu_item_handle(retvals(0), menuslot)
    mislot2 = find_menu_item_handle(retvals(1), menuslot2)
    IF bound_menuslot_and_mislot(menuslot, mislot, "swap menu items") THEN
     IF bound_menuslot_and_mislot(menuslot2, mislot2, "swap menu items") THEN
      SWAP menus(menuslot).items(mislot), menus(menuslot2).items(mislot2)
      mstates(menuslot).need_update = YES
      mstates(menuslot2).need_update = YES
     END IF
    END IF
   CASE 300'--find menu item caption
    IF bound_plotstr(retvals(1), "find menu item caption") THEN
     menuslot = find_menu_handle(retvals(0))
     DIM start_slot AS INTEGER
     IF retvals(3) = 0 THEN
      start_slot = 0
     ELSE
      start_slot = find_menu_item_handle_in_menuslot(retvals(3), menuslot) + 1
     END IF
     IF bound_menuslot_and_mislot(menuslot, start_slot, "find menu item caption") THEN
      mislot = find_menu_item_slot_by_string(menuslot, plotstr(retvals(1)).s, start_slot, (retvals(2) <> 0))
      IF mislot >= 0 THEN scriptret = menus(menuslot).items(mislot).handle
     END IF
    END IF
   CASE 301'--find menu ID
    IF bound_arg(retvals(0), 0, gen(genMaxMenu), "find menu ID", "menu ID") THEN
     menuslot = find_menu_id(retvals(0))
     IF menuslot >= 0 THEN
      scriptret = menus(menuslot).handle
     END IF
    END IF
   CASE 302'--menu is open
    menuslot = find_menu_handle(retvals(0))
    IF menuslot = -1 THEN
     scriptret = 0
    ELSE
     scriptret = 1
    END IF
   CASE 303'--menu item slot
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "menu item slot") THEN
     scriptret = mislot
    END IF
   CASE 304'--outside battle cure
    IF bound_arg(retvals(0), 0, gen(genMaxAttack), "outside battle cure", "attack ID") THEN
     IF bound_hero_party(retvals(1), "outside battle cure") THEN
      IF bound_hero_party(retvals(2), "outside battle cure", -1) THEN
       scriptret = ABS(outside_battle_cure(retvals(0), retvals(1), retvals(2), stat(), 0))
      END IF
     END IF
    END IF
   CASE 306'--layer tileset
    IF retvals(0) >= 0 AND retvals(0) <= 2 THEN
     scriptret = tilesets(retvals(0))->num
    END IF
   CASE 320'--current text box
    scriptret = -1
    IF txt.showing = YES THEN scriptret = txt.id
   CASE 432 '--use menu item
    mislot = find_menu_item_handle(retvals(0), menuslot)
    IF bound_menuslot_and_mislot(menuslot, mislot, "use menu item") THEN
     WITH menus(menuslot)
      IF .items(mislot).exists THEN activate_menu_item(.items(mislot), NO)
     END WITH
    END IF
   CASE 438 '--reset game
    resetg = YES
    .state = stwait
   CASE ELSE '--try all the scripts implemented in subs
    scriptnpc curcmd->value
    scriptmisc curcmd->value
    scriptadvanced curcmd->value
    scriptstat curcmd->value, stat()
    '---------
  END SELECT
END WITH
RETRACE

'======== FIXME: move this up as code gets cleaned up ===========
OPTION EXPLICIT

FUNCTION valid_item_slot(item_slot AS INTEGER, cmd AS STRING) AS INTEGER
 RETURN bound_arg(item_slot, 0, gen(genMaxInventory), cmd, "item slot")
END FUNCTION

FUNCTION bound_item(itemID AS INTEGER, cmd AS STRING) AS INTEGER
 RETURN bound_arg(itemID, 0, gen(genMaxItem), cmd, "item ID")
END FUNCTION

FUNCTION bound_hero_party(who AS INTEGER, cmd AS STRING, minimum AS INTEGER=0) AS INTEGER
 RETURN bound_arg(who, minimum, 40, cmd, "hero party slot")
END FUNCTION

FUNCTION bound_menuslot(menuslot AS INTEGER, cmd AS STRING) AS INTEGER
 RETURN bound_arg(menuslot, 0, topmenu, cmd, "menu handle")
END FUNCTION

FUNCTION bound_menuslot_and_mislot(menuslot AS INTEGER, mislot AS INTEGER, cmd AS STRING) AS INTEGER
 IF bound_menuslot(menuslot, cmd) THEN
  RETURN bound_arg(mislot, 0, UBOUND(menus(menuslot).items), cmd, "menu item handle")
 END IF
 RETURN NO
END FUNCTION

FUNCTION bound_plotstr(n AS INTEGER, cmd AS STRING) AS INTEGER
 RETURN bound_arg(n, 0, UBOUND(plotstr), cmd, "string ID")
END FUNCTION

FUNCTION bound_formation(form AS INTEGER, cmd AS STRING) AS INTEGER
 RETURN bound_arg(form, 0, gen(genMaxFormation), cmd, "formation ID")
END FUNCTION

FUNCTION bound_formation_slot(form AS INTEGER, slot AS INTEGER, cmd AS STRING) AS INTEGER
 IF bound_arg(form, 0, gen(genMaxFormation), cmd, "formation ID") THEN
  RETURN bound_arg(slot, 0, 7, cmd, "formation slot")
 END IF
 RETURN NO
END FUNCTION

SUB loadmap_gmap(mapnum)
 loadrecord gmap(), game + ".map", getbinsize(binMAP) / 2, mapnum

 loadmaptilesets tilesets(), gmap()
 refresh_map_slice_tilesets
 
 correctbackdrop
 SELECT CASE gmap(5) '--outer edge wrapping
  CASE 0, 1'--crop edges or wrap
   setoutside -1
  CASE 2
   setoutside gmap(6)
 END SELECT
END SUB

SUB loadmap_npcl(mapnum)
 LoadNPCL maplumpname$(mapnum, "l"), npc()

 'Evaluate whether NPCs should appear or disappear based on tags
 npcplot
END SUB

SUB loadmap_npcd(mapnum)
 LoadNPCD maplumpname$(mapnum, "n"), npcs()

 'Evaluate whether NPCs should appear or disappear based on tags
 npcplot
 'load NPC graphics
 reloadnpc stat()
END SUB

SUB loadmap_tilemap(mapnum)
 LoadTileData maplumpname$(mapnum, "t"), scroll(), 3
 refresh_map_slice 
 
 '--as soon as we know the dimensions of the map, enforce hero position boundaries
 cropposition catx(0), caty(0), 20
END SUB

SUB loadmap_passmap(mapnum)
 LoadTileData maplumpname$(mapnum, "p"), pass(), 1
END SUB

SUB loadmaplumps (mapnum, loadmask)
 'loads some, but not all the lumps needed for each map
 IF loadmask AND 1 THEN
  loadmap_gmap mapnum
 END IF
 IF loadmask AND 2 THEN
  loadmap_npcl mapnum
 END IF
 IF loadmask AND 4 THEN
  loadmap_npcd mapnum
 END IF
 IF loadmask AND 8 THEN
  loadmap_tilemap mapnum
 END IF
 IF loadmask AND 16 THEN
  loadmap_passmap mapnum
 END IF
END SUB

Sub MenuSound(byval s as integer)
  if s then stopsfx s-1:playsfx s-1, 0
End Sub

SUB LoadGen
  dim as integer genlen, ff
  dim as short s

  if not isfile(game + ".gen") then fatalerror("general data missing from " & game): exit sub

  genlen = 0
  ff = freefile

  OPEN game + ".gen" FOR BINARY AS #ff
  SEEK #ff, 8

  DO UNTIL EOF(ff) OR genlen > UBOUND(gen)
    get #ff, , s
    gen(genlen) = s
    genlen += 1
  LOOP
  genlen -= 1
END SUB

SUB dotimer(byval l as integer)
  dim i as integer
  dim rsr as integer
  for i = 0 to 15
    with timers(i)
      if .pause then continue for
      if .speed > 0 then
        if ((l = 1) AND (.flags AND 2 = 0)) OR ((l = 2) AND (.flags AND 4 = 0)) then continue for 'not supposed to run here
        'debug "updating timer #" & i

        if .st > 0 then
          if plotstr(.st - 1).s = "" then plotstr(.st - 1).s = seconds2str(.count)
        end if

        .ticks += 1
        if .ticks >= .speed then
          .count -= 1
          .ticks = 0
          if .st > 0 and .count >= 0 then plotstr(.st - 1).s = seconds2str(.count)
          if .count < 0 then
            .speed *= -1
            .speed -= 1
            'do something
            if l = 0 then 'on the field
              if .trigger = -2 then 'game over
                fatal = 1
                abortg = 1

                exit sub
              end if

              if .trigger = -1 then 'undefined, shouldn't happen
              end if

              if .trigger > -1 then 'plotscript
                rsr = runscript(.trigger, nowscript + 1, -1, "timer", 0)
                IF rsr = 1 THEN
                  setScriptArg 0, i
                END IF
              end if
            end if
          end if
        end if
      end if
    end with
  next
end sub

function dotimerbattle() as integer
  dotimer 1  'no sense duplicating code

  dim i as integer
  for i = 0 to 15
    with timers(i)
      if .speed < 0 then 'normally, not valid. but, if a timer expired in battle, this will be -ve, -1
        if .flags AND 1 then return -1
      end if
    end with
  next
  return 0
end function

function dotimermenu() as integer
  dotimer 2  'no sense duplicating code

  dim i as integer
  for i = 0 to 15
    with timers(i)
      if .speed < 0 then 'normally, not valid. but, if a timer expired in the menu, this will be -ve, -1
        if .flags AND 1 then return -1
      end if
    end with
  next
  return 0
end function

Sub dotimerafterbattle()
  dim i as integer
  for i = 0 to 15
    with timers(i)
      if .speed < 0 then 'normally, not valid. but, if a timer expired in battle, this will be -ve, -1
        .speed *= -1
        .speed -= 1

        .count = 0
        .ticks = .speed
      end if
    end with
  next

end sub

FUNCTION count_sav(filename AS STRING) AS INTEGER
 DIM i AS INTEGER
 DIM n AS INTEGER
 DIM savver AS INTEGER
 n = 0
 setpicstuf buffer(), 30000, -1
 FOR i = 0 TO 3
  loadset filename, i * 2, 0
  savver = buffer(0)
  IF savver = 3 THEN n += 1
 NEXT i
 RETURN n
END FUNCTION

FUNCTION add_menu (record AS INTEGER, allow_duplicate AS INTEGER=NO) AS INTEGER
 IF record > = 0 AND allow_duplicate = NO THEN
  'If adding a non-blank menu, first check if the requested menu is already open
  DIM menuslot AS INTEGER
  menuslot = find_menu_id(record)
  IF menuslot >= 0 THEN
   'the requested menu is already open, just bring it to the top
   bring_menu_forward menuslot
   RETURN menus(topmenu).handle
  END IF
 END IF
 'Load the menu into a new menu slot
 topmenu = topmenu + 1
 IF topmenu > UBOUND(menus) THEN
  REDIM PRESERVE menus(topmenu) AS MenuDef
  REDIM PRESERVE mstates(topmenu) AS MenuState
 END IF
 mstates(topmenu).top = 0
 mstates(topmenu).pt = 0
 IF record = -1 THEN
  ClearMenuData menus(topmenu)
 ELSE
  LoadMenuData menu_set, menus(topmenu), record
 END IF
 init_menu_state mstates(topmenu), menus(topmenu)
 mstates(topmenu).active = YES
 check_menu_tags
 RETURN assign_menu_handles(menus(topmenu))
END FUNCTION

SUB remove_menu (slot AS INTEGER)
 IF slot < 0 OR slot > UBOUND(menus) THEN scripterr "remove_menu: invalid slot " & slot, 3 : EXIT SUB
 bring_menu_forward slot
 IF txt.fully_shown = YES AND menus(topmenu).advance_textbox = YES THEN
  'Advance an open text box.
  'Because this could open other menus, take care to remember this menu's handle
  DIM remember_handle AS INTEGER = menus(topmenu).handle
  advance_text_box
  slot = find_menu_handle(remember_handle)
  bring_menu_forward slot
 END IF
 ClearMenuData menus(topmenu)
 topmenu = topmenu - 1
 IF topmenu >=0 THEN
  REDIM PRESERVE menus(topmenu) AS MenuDef
  REDIM PRESERVE mstates(topmenu) AS MenuState
  mstates(topmenu).active = YES
 END IF
END SUB

SUB bring_menu_forward (slot AS INTEGER)
 DIM i AS INTEGER
 IF slot < 0 OR slot > UBOUND(menus) THEN scripterr "bring_menu_forward: invalid slot " & slot, 3 : EXIT SUB
 FOR i = slot TO topmenu - 1
  SWAP menus(i), menus(i + 1)
  SWAP mstates(i), mstates(i + 1)
 NEXT i
END SUB

FUNCTION menus_allow_gameplay () AS INTEGER
 IF topmenu < 0 THEN RETURN YES
 RETURN menus(topmenu).allow_gameplay
END FUNCTION

FUNCTION menus_allow_player () AS INTEGER
 IF topmenu < 0 THEN RETURN YES
 RETURN menus(topmenu).suspend_player = NO
END FUNCTION

SUB player_menu_keys (stat(), catx(), caty(), tilesets() AS TilesetData ptr)
 DIM i AS INTEGER
 DIM activated AS INTEGER
 DIM menu_handle AS INTEGER
 IF topmenu >= 0 THEN
  IF menus(topmenu).no_controls = YES THEN EXIT SUB
  menu_handle = menus(topmenu).handle 'store handle for later use
  IF game_usemenu(mstates(topmenu)) THEN
   menusound gen(genCursorSFX)
  END IF
  IF carray(ccMenu) > 1 AND menus(topmenu).no_close = NO THEN
   carray(ccMenu) = 0
   setkeys ' Forget keypress that closed the menu
   remove_menu topmenu
   menusound gen(genCancelSFX)
   fatal = checkfordeath(stat())
   'update any change tags
   evalherotag stat()
   evalitemtag
   npcplot
   EXIT SUB
  END IF
  activated = NO
  DIM mi AS MenuDefItem '--use a copy of the menu item here because activate_menu_item() can deallocate it
  mi = menus(topmenu).items(mstates(topmenu).pt)
  IF mi.disabled THEN EXIT SUB
  IF carray(ccUse) > 1 THEN
   activated = activate_menu_item(menus(topmenu).items(mstates(topmenu).pt))
  END IF
  IF mi.t = 1 AND mi.sub_t = 11 THEN '--volume
   IF carray(ccLeft) > 1 THEN fmvol = large(fmvol - 1, 0): setfmvol fmvol
   IF carray(ccRight) > 1 THEN fmvol = small(fmvol + 1, 15): setfmvol fmvol
  END IF
  IF activated THEN
   IF mi.settag > 1 THEN setbit tag(), 0, mi.settag, YES
   IF mi.settag < -1 THEN setbit tag(), 0, ABS(mi.settag), NO
   IF mi.togtag > 1 THEN setbit tag(), 0, mi.togtag, (readbit(tag(), 0, mi.togtag) XOR 1)
   IF mi.close_if_selected THEN
    remove_menu find_menu_handle(menu_handle)
    carray(ccUse) = 0
    setkeys '--Discard the  keypress that triggered the menu item that closed the menu
   END IF
  END IF
 END IF
END SUB

FUNCTION activate_menu_item(mi AS MenuDefItem, newcall AS INTEGER=YES) AS INTEGER
 DIM open_other_menu AS INTEGER = -1
 DIM menu_text_box AS INTEGER = 0
 DIM updatetags AS INTEGER = NO
 DIM slot AS INTEGER
 DIM activated AS INTEGER = YES
 menu_text_box = 0
 DO 'This DO exists to allow EXIT DO
  WITH mi
   SELECT CASE .t
    CASE 0 ' Label
     SELECT CASE .sub_t
      CASE 0 'Selectable
      CASE 1 'Unselectable
       activated = NO
     END SELECT
    CASE 1 ' Special
     SELECT CASE .sub_t
      CASE 0 ' item
       menu_text_box = items_menu(stat())
       IF menu_text_box > 0 THEN
        remove_menu topmenu
        EXIT DO
       END IF
      CASE 1 ' spell
       slot = onwho(readglobalstring$(106, "Whose Spells?", 20), 0)
       IF slot >= 0 THEN spells_menu slot : updatetags = YES
      CASE 2 ' status
       slot = onwho(readglobalstring$(104, "Whose Status?", 20), 0)
       IF slot >= 0 THEN status slot, stat() : updatetags = YES
      CASE 3 ' equip
       slot = onwho(readglobalstring$(108, "Equip Whom?", 20), 0)
       IF slot >= 0 THEN equip slot, stat() : updatetags = YES
      CASE 4 ' order
       heroswap 0, stat() : updatetags = YES
      CASE 5 ' team
       heroswap 1, stat() : updatetags = YES
      CASE 6 ' order/team
       heroswap readbit(gen(), 101, 5), stat() : updatetags = YES
      CASE 7,12 ' map
       minimap catx(0), caty(0), tilesets()
      CASE 8,13 ' save
       slot = picksave(0)
       IF slot >= 0 THEN savegame slot, stat()
      CASE 9 ' load
       slot = picksave(1)
       IF slot >= 0 THEN
        wantloadgame = slot + 1
        FOR i AS INTEGER = topmenu TO 0 STEP -1
         remove_menu i
        NEXT i
        EXIT DO
       END IF
      CASE 10 ' quit
       menusound gen(genAcceptSFX)
       verquit
      CASE 11 ' volume
       activated = NO
     END SELECT
    CASE 2 ' Menu
     mstates(topmenu).active = NO
     open_other_menu = .sub_t
    CASE 3 ' Text box
     menu_text_box = .sub_t
    CASE 4 ' Run Script
     DIM rsr AS INTEGER
     rsr = runscript(.sub_t, nowscript + 1, newcall, "menuitem", plottrigger)
     IF rsr = 1 THEN
      IF menus(topmenu).allow_gameplay THEN
       'Normally, pass a menu item handle
       setScriptArg 0, .handle
      ELSE
       'but if this menu suspends gameplay, then a handle will always be invalid
       'by the time the script runs, so pass the extra values instead.
       setScriptArg 0, .extra(0)
       setScriptArg 1, .extra(1)
       setScriptArg 2, .extra(2)
      END IF
     END IF
    END SELECT
   END WITH
  EXIT DO
 LOOP
 IF updatetags THEN
  evalherotag stat()
  evalitemtag
  npcplot
 END IF
 IF open_other_menu >= 0 THEN
  add_menu open_other_menu
 END IF
 IF menu_text_box > 0 THEN
  '--player has triggered a text box from the menu--
  loadsay menu_text_box
  menu_text_box = 0
 END IF
 RETURN activated
END FUNCTION

SUB check_menu_tags ()
 DIM i AS INTEGER
 DIM j AS INTEGER
 DIM old AS INTEGER
 DIM changed AS INTEGER
 DIM remember AS INTEGER
 FOR j = 0 TO topmenu
  WITH menus(j)
   changed = NO
   FOR i = 0 TO UBOUND(.items)
    WITH .items(i)
     old = .disabled
     .disabled = NO
     IF NOT (istag(.tag1, YES) AND istag(.tag2, YES)) THEN .disabled = YES
     IF .t = 0 AND .sub_t = 1 THEN .disabled = YES
     IF .t = 1 AND .sub_t = 7 AND gmap(2) = 0 THEN .disabled = YES 'Minimap disabled on this map
     IF .t = 1 AND .sub_t = 8 AND gmap(3) = 0 THEN .disabled = YES 'Save anywhere disabled on this map
     IF old <> .disabled THEN changed = YES
    END WITH
   NEXT i
   IF changed = YES THEN
    remember = .items(mstates(j).pt).sortorder
    SortMenuItems .items()
    FOR i = 0 TO UBOUND(.items)
     WITH .items(i)
      IF .exists = NO THEN EXIT FOR
      IF .disabled AND .hide_if_disabled THEN EXIT FOR
      IF remember = .sortorder THEN
        mstates(j).pt = i
        EXIT FOR
      END IF
     END WITH
    NEXT i
    mstates(j).need_update = YES
   END IF
  END WITH
 NEXT j
END SUB

FUNCTION game_usemenu (state AS MenuState) as integer
 DIM oldptr AS INTEGER
 DIM oldtop AS INTEGER

 WITH state
  oldptr = .pt
  oldtop = .top

  IF carray(ccUp) > 1 THEN .pt = loopvar(.pt, .first, .last, -1) 'UP
  IF carray(ccDown) > 1 THEN .pt = loopvar(.pt, .first, .last, 1)  'DOWN
  IF keyval(scPageup) > 1 THEN .pt = large(.pt - .size, .first)     'PGUP
  IF keyval(scPagedown) > 1 THEN .pt = small(.pt + .size, .last)      'PGDN
  IF keyval(scHome) > 1 THEN .pt = .first                         'HOME
  IF keyval(scEnd) > 1 THEN .pt = .last                          'END
  .top = bound(.top, .pt - .size, .pt)

  IF oldptr <> .pt OR oldtop <> .top THEN RETURN YES
  RETURN NO
 END WITH
END FUNCTION

FUNCTION find_menu_id (id AS INTEGER) AS INTEGER
 DIM i AS INTEGER
 FOR i = topmenu TO 0 STEP -1
  IF menus(i).record = id THEN
   RETURN i 'return slot
  END IF
 NEXT i
 RETURN -1 ' Not found
END FUNCTION

FUNCTION find_menu_handle (handle) AS INTEGER
 DIM i AS INTEGER
 FOR i = 0 TO topmenu
  IF menus(i).handle = handle THEN RETURN i 'return slot
 NEXT i
 RETURN -1 ' Not found
END FUNCTION

FUNCTION find_menu_item_handle_in_menuslot (handle AS INTEGER, menuslot AS INTEGER) AS INTEGER
 DIM mislot AS INTEGER
 WITH menus(menuslot)
  FOR mislot = 0 TO UBOUND(.items)
   WITH .items(mislot)
    IF .exists AND .handle = handle THEN
     RETURN mislot
    END IF
   END WITH
  NEXT mislot
 END WITH
 RETURN -1 ' Not found
END FUNCTION

FUNCTION find_menu_item_handle (handle AS INTEGER, BYREF found_in_menuslot) AS INTEGER
 DIM menuslot AS INTEGER
 DIM mislot AS INTEGER
 DIM found AS INTEGER
 FOR menuslot = 0 TO topmenu
  found = find_menu_item_handle_in_menuslot(handle, menuslot)
  IF found >= 0 THEN
   found_in_menuslot = menuslot
   RETURN found
  END IF
 NEXT menuslot
 found_in_menuslot = -1
 RETURN -1 ' Not found
END FUNCTION

FUNCTION assign_menu_item_handle (BYREF mi AS MenuDefItem) AS INTEGER
 STATIC new_handle = 0
 IF mi.exists THEN
  new_handle = new_handle + 1
  mi.handle = new_handle
  RETURN new_handle
 END IF
 RETURN 0
END FUNCTION

FUNCTION assign_menu_handles (BYREF menu AS MenuDef) AS INTEGER
 DIM i AS INTEGER
 STATIC new_handle = 0
 new_handle = new_handle + 1
 menus(topmenu).handle = new_handle
 FOR i = 0 TO UBOUND(menu.items)
  assign_menu_item_handle menu.items(i)
 NEXT i
 RETURN new_handle
END FUNCTION

FUNCTION menu_item_handle_by_slot(menuslot AS INTEGER, mislot AS INTEGER, visible_only AS INTEGER=YES) AS INTEGER
 IF menuslot >= 0 AND menuslot <= topmenu THEN
  WITH menus(menuslot)
   IF mislot >= 0 AND mislot <= UBOUND(.items) THEN
    WITH .items(mislot)
     IF .exists = NO THEN RETURN 0
     IF visible_only AND .disabled AND .hide_if_disabled THEN RETURN 0
     RETURN .handle
    END WITH
   END IF
  END WITH
 END IF
 RETURN 0
END FUNCTION

FUNCTION find_menu_item_slot_by_string(menuslot AS INTEGER, s AS STRING, mislot AS INTEGER=0, visible_only AS INTEGER=YES) AS INTEGER
 DIM i AS INTEGER
 DIM cap AS STRING
 WITH menus(menuslot)
  FOR i = mislot TO UBOUND(.items)
   WITH .items(i)
    IF .exists = NO THEN CONTINUE FOR
    IF visible_only AND .disabled AND .hide_if_disabled THEN CONTINUE FOR
    cap = get_menu_item_caption(menus(menuslot).items(i), menus(menuslot))
    IF cap = s THEN
     RETURN i
    END IF
   END WITH
  NEXT i
 END WITH
 RETURN -1 ' not found
END FUNCTION

FUNCTION allowed_to_open_main_menu () AS INTEGER
 DIM i AS INTEGER
 IF find_menu_id(0) >= 0 THEN RETURN NO 'Already open
 FOR i = topmenu TO 0 STEP -1
  IF menus(i).prevent_main_menu = YES THEN RETURN NO
 NEXT i
 RETURN YES
END FUNCTION

FUNCTION random_formation (BYVAL set AS INTEGER) AS INTEGER
 DIM formset(24)
 DIM AS INTEGER i, num
 STATIC foenext AS INTEGER = 0
 loadrecord formset(), game + ".efs", 25, set
 FOR i = 1 TO 20
  IF formset(i) THEN num += 1
 NEXT
 IF num = 0 THEN RETURN -1

 'surprisingly, this is actually slightly effective at reducing the rate of the
 'same slot being picked consecutively, so I'll leave it be for now
 FOR i = 0 TO INT(RND * range(19, 27))
  DO 
   foenext = loopvar(foenext, 0, 19, 1)
  LOOP WHILE formset(1 + foenext) = 0
 NEXT
 RETURN formset(1 + foenext) - 1
END FUNCTION

SUB prepare_map (afterbat AS INTEGER=NO, afterload AS INTEGER=NO)
 'DEBUG debug "in preparemap"
 DIM i AS INTEGER
 'save data from old map
 IF gam.map.lastmap > -1 THEN
  IF gmap(17) = 1 THEN
   savemapstate_npcd gam.map.lastmap, "map"
   savemapstate_npcl gam.map.lastmap, "map"
  END IF
  IF gmap(18) = 1 THEN
   savemapstate_tilemap gam.map.lastmap, "map"
   savemapstate_passmap gam.map.lastmap, "map"
  END IF
 END IF
 gam.map.lastmap = gam.map.id

 'load gmap
 loadmapstate_gmap gam.map.id, "map"

 'Play map music
 IF readbit(gen(), genSuspendBits, suspendambientmusic) = 0 THEN
  IF gmap(1) > 0 THEN
   wrappedsong gmap(1) - 1
  ELSEIF gmap(1) = 0 THEN
   stopsong
  ELSEIF gmap(1) = -1 AND afterbat = YES THEN
   IF gam.remembermusic > -1 THEN wrappedsong gam.remembermusic ELSE stopsong
  END IF
 END IF

 gam.map.name = getmapname$(gam.map.id)

 IF gmap(18) < 2 THEN
  loadmapstate_tilemap gam.map.id, "map"
  loadmapstate_passmap gam.map.id, "map"
 ELSE
  loadmap_tilemap gam.map.id
  loadmap_passmap gam.map.id
 END IF

 IF afterbat = NO THEN
  gam.map.showname = gmap(4)
  IF gmap(17) < 2 THEN
   loadmapstate_npcd gam.map.id, "map"
   loadmapstate_npcl gam.map.id, "map"
  ELSE
   loadmap_npcd gam.map.id
   loadmap_npcl gam.map.id
  END IF
 END IF
 setmapdata scroll(), pass(), 0, 0

 IF isfile(maplumpname$(gam.map.id, "e")) THEN
  CLOSE #foemaph
  foemaph = FREEFILE
  OPEN maplumpname$(gam.map.id, "e") FOR BINARY AS #foemaph
 ELSE
  fatalerror "Oh no! Map " & gam.map.id & " foemap is missing"
 END IF
 loaddoor gam.map.id

 IF afterbat = NO AND gam.map.same = NO THEN
  forcedismount catd()
 END IF
 IF afterbat = NO AND afterload = NO THEN
  FOR i = 0 TO 15
   catx(i) = catx(0)
   caty(i) = caty(0)
   catd(i) = catd(0)
   catz(i) = 0
  NEXT i
 END IF
 IF afterload = YES THEN
  interpolatecat
  xgo(0) = 0
  ygo(0) = 0
  herospeed(0) = 4
 END IF
 IF vstate.active = YES AND gam.map.same = YES THEN
  FOR i = 0 TO 3
   catz(i) = vstate.dat.elevation
  NEXT i
  herospeed(0) = vstate.dat.speed
  IF herospeed(0) = 3 THEN herospeed(0) = 10
 END IF
 txt.sayer = -1

 'Why are these here? Seems like superstition
 evalherotag stat()
 evalitemtag
 DIM rsr AS INTEGER
 IF afterbat = NO THEN
  IF gmap(7) > 0 THEN
   rsr = runscript(gmap(7), nowscript + 1, -1, "map", plottrigger)
   IF rsr = 1 THEN
    setScriptArg 0, gmap(8)
   END IF
  END IF
 ELSE
  IF gmap(12) > 0 THEN
   rsr = runscript(gmap(12), nowscript + 1, -1, "afterbattle", plottrigger)
   IF rsr = 1 THEN
    '--afterbattle script gets one arg telling if you won or ran
    setScriptArg 0, gam.wonbattle
   END IF
  END IF
 END IF
 gam.map.same = NO
 'DEBUG debug "end of preparemap"
END SUB

SUB reset_game_state ()
 reset_map_state(gam.map)
 gam.wonbattle = NO
 gam.remembermusic = -1
 gam.random_battle_countdown = range(100, 60)
END SUB

SUB reset_map_state (map AS MapModeState)
 map.id = gen(genStartMap)
 map.lastmap = -1
 map.same = NO
 map.showname = 0
 map.name = ""
END SUB

SUB opendoor (dforce AS INTEGER=0)
 'dforce is the ID number +1 of the door to force, or 0 if we are going to search for a mathcing door
 DIM door_id AS INTEGER
 IF vstate.active = YES AND vstate.dat.enable_door_use = NO AND dforce = 0 THEN EXIT SUB 'Doors are disabled by a vehicle
 IF dforce THEN
  door_id = dforce - 1
  IF readbit(gam.map.door(door_id).bits(),0,0) = 0 THEN EXIT SUB 'Door is disabled
  thrudoor door_id
  EXIT SUB
 END IF
 FOR door_id = 0 TO 99
  IF readbit(gam.map.door(door_id).bits(),0,0) THEN 'Door is enabled
   IF gam.map.door(door_id).x = catx(0) \ 20 AND gam.map.door(door_id).y = (caty(0) \ 20) + 1 THEN
    thrudoor door_id
    EXIT SUB
   END IF
  END IF
 NEXT door_id
 'No doors found
END SUB

SUB thrudoor (door_id AS INTEGER)
 'FIXME: needf is accessed here. It is module shared, should probably become a member of gam
 DIM oldmap AS INTEGER
 DIM i AS INTEGER
 DIM destdoor AS INTEGER
 gam.map.same = NO
 oldmap = gam.map.id
 deserdoorlinks(maplumpname(gam.map.id,"d"), gam.map.doorlinks())

 FOR i = 0 TO 199
  WITH gam.map.doorlinks(i)
   IF door_id = .source THEN
    IF istag(.tag1, -1) AND istag(.tag2, -1) THEN 'Check tags to make sure this door is okay
     gam.map.id = .dest_map
     destdoor = .dest
     deserdoors game + ".dox", gam.map.door(), gam.map.id
     catx(0) = gam.map.door(destdoor).x * 20
     caty(0) = (gam.map.door(destdoor).y - 1) * 20
     fadeout 0, 0, 0
     needf = 2
     IF oldmap = gam.map.id THEN gam.map.same = YES
     prepare_map
     gam.random_battle_countdown = range(100, 60)
     EXIT FOR
    END IF
   END IF
  END WITH
 NEXT i
END SUB

SUB advance_text_box ()
 IF txt.box.backdrop > 0 THEN
  '--backdrop needs resetting
  gen(genTextboxBackdrop) = 0
  correctbackdrop
 END IF
 '---IF MADE A CHOICE---
 IF txt.box.choice_enabled THEN
  MenuSound gen(genAcceptSFX)
  IF ABS(txt.box.choice_tag(txt.choice_cursor)) > 1 THEN
   setbit tag(), 0, ABS(txt.box.choice_tag(txt.choice_cursor)), SGN(SGN(txt.box.choice_tag(txt.choice_cursor)) + 1)
  END IF
 END IF
 '---RESET MUSIC----
 IF txt.box.restore_music THEN
  IF gmap(1) > 0 THEN
   wrappedsong gmap(1) - 1
  ELSEIF gmap(1) = 0 THEN
   stopsong
  ELSE
   IF txt.remember_music > -1 THEN
    wrappedsong txt.remember_music
   ELSE
    stopsong
   END IF
  END IF
 END IF
 '---STOP SOUND EFFECT----
 IF txt.box.sound_effect > 0 AND txt.box.stop_sound_after THEN
  stopsfx txt.box.sound_effect - 1
 END IF
 '---GAIN/LOSE CASH-----
 IF istag(txt.box.money_tag, 0) THEN
  gold = gold + txt.box.money
  IF gold > 2000000000 THEN gold = 2000000000
  IF gold < 0 THEN gold = 0
 END IF
 '---SPAWN BATTLE--------
 IF istag(txt.box.battle_tag, 0) THEN
  fatal = 0
  gam.wonbattle = battle(txt.box.battle, fatal, stat())
  prepare_map YES
  gam.random_battle_countdown = range(100, 60)
  needf = 1
 END IF
 '---GAIN/LOSE ITEM--------
 IF istag(txt.box.item_tag, 0) THEN
  IF txt.box.item > 0 THEN getitem txt.box.item, 1
  IF txt.box.item < 0 THEN delitem -txt.box.item, 1
 END IF
 '---SHOP/INN/SAVE/ETC------------
 IF istag(txt.box.shop_tag, 0) THEN
  IF txt.box.shop > 0 THEN
   shop txt.box.shop - 1, needf, stat(), tilesets()
   reloadnpc stat()
  END IF
  DIM inn AS INTEGER = 0
  IF txt.box.shop < 0 THEN
   DIM holdscreen = allocatepage
   '--Preserve background for display beneath the top-level shop menu
   copypage vpage, holdscreen
   IF useinn(inn, -txt.box.shop, needf, stat(), holdscreen) THEN
    fadeout 0, 0, 80
    needf = 1
   END IF
   freepage holdscreen
  END IF
  IF txt.box.shop <= 0 AND inn = 0 THEN
   innRestore stat()
  END IF
 END IF
 '---ADD/REMOVE/SWAP/LOCK HERO-----------------
 IF istag(txt.box.hero_tag, 0) THEN add_rem_swap_lock_hero txt.box, stat()
 '---FORCE DOOR------
 IF istag(txt.box.door_tag, 0) THEN
  opendoor txt.box.door + 1
  IF needf = 0 THEN
   DIM temp AS INTEGER
   temp = readfoemap(INT(catx(0) / 20), INT(caty(0) / 20), scroll(0), scroll(1), foemaph)
   IF vstate.active = YES AND vstate.dat.random_battles > 0 THEN temp = vstate.dat.random_battles
   IF temp > 0 THEN gam.random_battle_countdown = large(gam.random_battle_countdown - gam.foe_freq(temp - 1), 0)
  END IF
  setmapxy
 END IF
 '---JUMP TO NEXT TEXT BOX--------
 IF istag(txt.box.after_tag, 0) THEN
  IF txt.box.after < 0 THEN
   runscript(-txt.box.after, nowscript + 1, -1, "textbox", plottrigger)
  ELSE
   loadsay txt.box.after
   EXIT SUB
  END IF
 END IF
 evalitemtag
 '---DONE EVALUATING CONDITIONALS--------
 vishero stat()
 npcplot
 IF txt.sayer >= 0 AND txt.old_dir <> -1 THEN
  IF npc(txt.sayer).id > 0 THEN
   IF npcs(npc(txt.sayer).id - 1).facetype = 1 THEN
    npc(txt.sayer).dir = txt.old_dir
   END IF
  END IF
 END IF
 IF txt.box.backdrop > 0 THEN
  gen(genTextboxBackdrop) = 0
  correctbackdrop
 END IF
 WITH txt.portrait
  IF .sprite THEN sprite_unload @.sprite
  IF .pal    THEN palette16_unload @.pal
 END WITH
 txt.showing = NO
 txt.fully_shown = NO
 txt.sayer = -1
 txt.id = -1
 IF txt.sl THEN DeleteSlice @(txt.sl)
 ClearTextBox txt.box
 setkeys
 flusharray carray(), 7, 0
END SUB

SUB init_default_text_colors()
 textcolor uilook(uiText), 0
 FOR i AS INTEGER = 0 TO 31
  plotstr(i).Col = uilook(uiText)
 NEXT i
END SUB

SUB init_text_box_slices(txt AS TextBoxState)
 IF txt.sl THEN
  '--free any already-loaded textbox
  DeleteSlice @(txt.sl)
 END IF
 txt.sl = NewSliceOfType(slContainer, SliceTable.TextBox)
 txt.sl->Fill = Yes

 '--Create a new slice for the text box
 DIM text_box AS Slice Ptr

 '--set up box style
 IF txt.box.no_box THEN
  text_box = NewSliceOfType(slContainer, txt.sl)
 ELSE
  text_box = NewSliceOfType(slRectangle, txt.sl)
  ChangeRectangleSlice text_box, txt.box.boxstyle, , , , iif(txt.box.opaque, transOpaque, transFuzzy)
 END IF
 
 '--position and size the text box
 WITH *text_box 
  .X = 4
  .Y = 4 + txt.box.vertical_offset * 4
  .Width = 312
  .Height = get_text_box_height(txt.box)
 END WITH

 '--A frame that handles the padding around the text
 DIM text_frame AS Slice Ptr
 text_frame = NewSliceOfType(slContainer, text_box)
  '--set up padding
 WITH *text_frame
  .Fill = YES
  .PaddingLeft = 4
  .PaddingRight = 4
  .PaddingTop = 3
  .PaddingBottom = 3
 END WITH

 '--Set up the actual text
 DIM col AS INTEGER
 col = uilook(uiText)
 IF txt.box.textcolor > 0 THEN col = txt.box.textcolor

 DIM s AS STRING = ""
 FOR i AS INTEGER = 0 TO 7
  s &= txt.box.text(i) & CHR(10)
 NEXT i
  
 DIM text_sl AS Slice Ptr
 text_sl = NewSliceOfType(slText, text_frame, SL_TEXTBOX_TEXT)
 text_sl->Fill = YES
 ChangeTextSlice text_sl, s, col, YES, NO

 '--start the displayed lines as all hidden. They will be revealed in drawsay
 DIM dat AS TextSliceData Ptr
 dat = text_sl->SliceData
 IF dat THEN
  dat->line_limit = -1
 END IF
 
 '--figure out which portrait to load
 DIM img_id AS INTEGER = -1
 DIM pal_id AS INTEGER = -1
 DIM hero_id AS INTEGER = -1
 DIM her AS HeroDef
 SELECT CASE txt.box.portrait_type
  CASE 1' Fixed ID number
   img_id = txt.box.portrait_id
   pal_id = txt.box.portrait_pal
  CASE 2' Hero by caterpillar
   hero_id = herobyrank(txt.box.portrait_id)
  CASE 3' Hero by party slot
   IF txt.box.portrait_id >= 0 AND txt.box.portrait_id <= UBOUND(hero) THEN
    hero_id = hero(txt.box.portrait_id) - 1
   END IF
 END SELECT
 IF hero_id >= 0 THEN
  loadherodata @her, hero_id
  img_id = her.portrait
  pal_id = her.portrait_pal
 END IF

 IF img_id >= 0 THEN
  '--First set up the box that holds the portrait
  DIM img_box AS Slice Ptr
  IF txt.box.portrait_box THEN
   img_box = NewSliceOfType(slRectangle, text_box)
   ChangeRectangleSlice img_box, txt.box.boxstyle, , , , transFuzzy
  ELSE
   img_box = NewSliceOfType(slContainer, text_box)
  END IF
  img_box->Width = 50
  img_box->Height = 50
  img_box->X = txt.box.portrait_pos.x
  img_box->Y = txt.box.portrait_pos.y
  '--Then load the portrait
  DIM img_sl AS Slice Ptr
  img_sl = NewSliceOfType(slSprite, img_box, SL_TEXTBOX_PORTRAIT)
  ChangeSpriteSlice img_sl, 8, img_id, pal_id
 END IF
 
 '--set up the choice-box (if any)
 IF txt.box.choice_enabled THEN
  'tempy = 100 + (txt.box.vertical_offset * 4) - (txt.box.shrink * 4)
  'IF tempy > 160 THEN tempy = 20
  'centerbox 160, tempy + 12, 10 + large(LEN(txt.box.choice(0)) * 8, LEN(txt.box.choice(1)) * 8), 24, txt.box.boxstyle + 1, dpage
  DIM choice_box AS Slice Ptr
  choice_box = NewSliceOfType(slRectangle, txt.sl)
  WITH *choice_box
   '--center the box
   .AnchorHoriz = 1
   .AlignHoriz = 1
   .AnchorVert = 1
   .AlignVert = 1
   '--set box size
   .Width = 10 + large(LEN(txt.box.choice(0)) * 8, LEN(txt.box.choice(1)) * 8)
   .Height = 24
   '--FIXME: This hackyness just reproduces the old method of positioning the choicebox.
   '--FIXME: eventually the game author should have control over this.
   .Y = (txt.box.vertical_offset * 4) - (txt.box.shrink * 4)
   IF .Y > 60 THEN .Y = -80
   .Y += 12
  END WITH
  ChangeRectangleSlice choice_box, txt.box.boxstyle
  DIM choice_sl(1) AS Slice Ptr
  FOR i AS INTEGER = 0 TO 1
   choice_sl(i) = NewSliceOfType(slText, choice_box)
   ChangeTextSlice choice_sl(i), txt.box.choice(i), uilook(uiMenuItem), YES
   WITH *(choice_sl(i))
    .AnchorHoriz = 1
    .AlignHoriz = 1
    .Y = 2 + i * 10
   END WITH
  NEXT i
  choice_sl(0)->Lookup = SL_TEXTBOX_CHOICE0
  choice_sl(1)->Lookup = SL_TEXTBOX_CHOICE1
 END IF
 
END SUB

SUB cleanup_text_box ()
 ClearTextBox txt.box
 WITH txt
  .id = -1
  .showing = NO
  .fully_shown = NO
  .choice_cursor = 0
  .remember_music = NO
  .show_lines = 0
  .sayer = -1
  .old_dir = 0
 END WITH
 WITH txt.portrait
  IF .sprite THEN sprite_unload @.sprite
  IF .pal    THEN palette16_unload @.pal
 END WITH
 IF txt.sl THEN DeleteSlice @(txt.sl)
END SUB

SUB refresh_map_slice()
 '--Store info about the map in the map slices
 WITH *(SliceTable.MapRoot)
  .Width = scroll(0) * 20
  .Height = scroll(1) * 20
 END WITH
 FOR i AS INTEGER = 0 TO 2
  '--reset each layer (the tileset ptr is set in refresh_map_slice_tilesets)
  ChangeMapSlice SliceTable.MapLayer(i), scroll(0), scroll(1), i, (i > 0), 0
  WITH *(SliceTable.MapLayer(i))
   .Fill = YES
  END WITH
 NEXT i
END SUB

SUB refresh_map_slice_tilesets()
 FOR i AS INTEGER = 0 TO 2
  '--reset map layer tileset ptrs
  ChangeMapSliceTileset SliceTable.MapLayer(i), tilesets(i)
 NEXT i
END SUB

FUNCTION vehicle_is_animating() AS INTEGER
 WITH vstate
  RETURN .mounting ORELSE .rising ORELSE .falling ORELSE .init_dismount ORELSE .ahead ORELSE .trigger_cleanup
 END WITH
END FUNCTION

SUB reset_vehicle(v AS VehicleState)
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
  debug "active=" & .active & " npc=" & .npc & " mounting=" & .mounting & " rising=" & .rising & " falling=" & .falling & " dismount=" & .init_dismount & " cleanup=" & .trigger_cleanup & " ahead=" & .ahead
 END WITH
END SUB

SUB usething(BYVAL auto AS INTEGER, BYVAL ux AS INTEGER, BYVAL uy AS INTEGER)
 'auto = 0: normal use, txt.sayer = -1
 'auto = 1: touch and step-on, txt.sayer set to +NPC reference
 'auto = 2: scripted, txt.sayer set to +NPC reference
 IF auto = 0 THEN
  ux = catx(0)
  uy = caty(0)
  wrapaheadxy ux, uy, catd(0), 20, 20
 END IF
 DIM nx AS INTEGER
 DIM ny AS INTEGER
 DIM nd AS INTEGER
 IF txt.sayer < 0 THEN
  IF auto <> 2 THEN 'find the NPC to trigger the hard way
   txt.sayer = -1
   DIM j AS INTEGER = -1
   DO
    j += 1
    IF j > 299 THEN EXIT SUB
    IF npc(j).id > 0 AND (j <> vstate.npc OR vstate.active = NO) THEN
     '--Step-on NPCs cannot be used
     IF auto = 0 AND npcs(npc(j).id - 1).activation = 2 THEN CONTINUE DO
     nx = npc(j).x
     ny = npc(j).y
     nd = npc(j).dir
     IF (nx = ux AND ny = uy) THEN 'not moving NPCs
      EXIT DO
     ELSEIF nx MOD 20 <> 0 XOR ny mod 20 <> 0 THEN 'they're moving (i.e. misaligned)
      '--first check the tile the NPC is stepping into
      nx -= npc(j).xgo
      ny -= npc(j).ygo
      cropposition nx, ny, 20
      '--uncommenting the line below provides a helpful rectangle that shows the activation tile of an NPC
      'rectangle nx - mapx, ny - mapy, 20,20, 1, vpage : setvispage vpage
      IF (nx = ux AND ny = uy) THEN 'check for activation
       EXIT DO
      END IF
      '--also check the tile the NPC is leaving
      nx = nx + SGN(npc(j).xgo) * 20
      ny = ny + SGN(npc(j).ygo) * 20
      '--uncommenting the line below provides a helpful rectangle that shows the activation tile of an NPC
      'rectangle nx - mapx, ny - mapy, 20,20, 4, vpage : setvispage vpage
      IF (nx = ux AND ny = uy) THEN 'check for activation
       '--if activating an NPC that has just walked past us, cause it to back up
       npc(j).xgo = SGN(npc(j).xgo * -1) * (20 - ABS(npc(j).xgo))
       npc(j).ygo = SGN(npc(j).ygo * -1) * (20 - ABS(npc(j).ygo))
       EXIT DO
      END IF
     END IF
    END IF
   LOOP
   txt.sayer = j
  END IF
 END IF
 '--if we have gotten this far, we must have a valid txt.sayer
 IF txt.sayer >= 0 THEN
  '---Item from NPC---
  DIM getit AS INTEGER = npcs(npc(txt.sayer).id - 1).item
  IF getit THEN getitem getit, 1
  '---DIRECTION CHANGING-----------------------
  txt.old_dir = -1
  IF auto <> 2 AND npcs(npc(txt.sayer).id - 1).facetype < 2 THEN
   txt.old_dir = npc(txt.sayer).dir
   npc(txt.sayer).dir = catd(0)
   npc(txt.sayer).dir = loopvar(npc(txt.sayer).dir, 0, 3, 2)
  END IF
  IF npcs(npc(txt.sayer).id - 1).usetag > 0 THEN
   '--One-time-use tag
   setbit tag(), 0, 1000 + npcs(npc(txt.sayer).id - 1).usetag, 1
  END IF
  IF npcs(npc(txt.sayer).id - 1).script > 0 THEN
   '--summon a script directly from an NPC
   DIM rsr AS INTEGER = runscript(npcs(npc(txt.sayer).id - 1).script, nowscript + 1, -1, "NPC", plottrigger)
   IF rsr = 1 THEN
    setScriptArg 0, npcs(npc(txt.sayer).id - 1).scriptarg
    setScriptArg 1, (txt.sayer + 1) * -1 'reference
   END IF
  END IF
  DIM vehuse AS INTEGER = npcs(npc(txt.sayer).id - 1).vehicle
  IF vehuse THEN '---activate a vehicle---
   reset_vehicle vstate
   LoadVehicle game & ".veh", vstate.dat, vehuse - 1
   '--check mounting permissions first
   IF vehpass(vstate.dat.mount_from, readpassblock(catx(0) \ 20, caty(0) \ 20), -1) THEN
    vstate.active = YES
    vstate.npc = txt.sayer
    vstate.old_speed = herospeed(0)
    herospeed(0) = 10
    vstate.mounting = YES '--trigger mounting sequence
    IF vstate.dat.riding_tag > 1 THEN setbit tag(), 0, vstate.dat.riding_tag, 1
   END IF
  END IF
  SELECT CASE npcs(npc(txt.sayer).id - 1).textbox
   CASE 0
    txt.sayer = -1
   CASE IS > 0
    loadsay npcs(npc(txt.sayer).id - 1).textbox
  END SELECT
  evalherotag stat()
  evalitemtag
  IF txt.id = -1 THEN
   npcplot
  END IF
 END IF
END SUB

FUNCTION want_to_check_for_walls(BYVAL who AS INTEGER) AS INTEGER
 IF movdivis(xgo(who)) = 0 AND movdivis(ygo(who)) = 0 THEN RETURN NO
 IF gam.walk_through_walls = YES THEN RETURN NO
 IF vstate.dat.pass_walls = YES THEN RETURN NO
 IF vstate.active THEN
  DIM thisherotilex AS INTEGER = INT(catx(who * 5) / 20)
  DIM thisherotiley AS INTEGER = INT(caty(who * 5) / 20)
  IF vehpass(vstate.dat.override_walls, readmapblock(thisherotilex, thisherotiley, 0), 0) <> 0 THEN RETURN NO
 END IF
 RETURN YES
END FUNCTION
