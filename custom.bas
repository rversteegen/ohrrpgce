'OHRRPGCE CUSTOM - Main module
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
DEFINT A-Z

#include "config.bi"
#include "ver.txt"
#include "udts.bi"
#include "const.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "customsubs.bi"
#include "flexmenu.bi"
#include "slices.bi"
#include "cglobals.bi"
#include "uiconst.bi"
#include "scrconst.bi"
#include "sliceedit.bi"
#include "reloadedit.bi"
#include "editedit.bi"
#include "os.bi"

'FIXME: add header files for these declarations
DECLARE SUB importbmp (f AS STRING, cap AS STRING, count AS INTEGER)
DECLARE SUB vehicles ()
DECLARE SUB scriptman ()
DECLARE SUB map_picker ()
DECLARE SUB sprite (xw, yw, sets, perset, soff, info() as string, zoom, fileset, fullset AS INTEGER=NO, cursor_start AS INTEGER=0, cursor_top AS INTEGER=0)
DECLARE SUB importsong ()
DECLARE SUB importsfx ()
DECLARE SUB gendata ()
DECLARE SUB itemdata ()
DECLARE SUB formation ()
DECLARE SUB enemydata ()
DECLARE SUB herodata ()
DECLARE SUB text_box_editor ()
DECLARE SUB maptile ()
DECLARE SUB importscripts (f as string)

'Local function declarations
DECLARE FUNCTION newRPGfile (templatefile as string, newrpg as string)
DECLARE FUNCTION makeworkingdir () as integer
DECLARE FUNCTION handle_dirty_workingdir () as integer
DECLARE SUB save_current_game()
DECLARE SUB dolumpfiles (filetolump as string)
DECLARE SUB move_unwriteable_rpg (filetolump as string)
DECLARE SUB shopdata ()
DECLARE SUB secret_menu ()
DECLARE SUB condition_test_menu ()
DECLARE SUB quad_transforms_menu ()
DECLARE SUB arbitrary_sprite_editor ()
DECLARE SUB setmainmenu (menu() as string, byref mainmax as integer, menukeys() as string)
DECLARE SUB setgraphicmenu (menu() as string, byref mainmax as integer, menukeys() as string)
DECLARE SUB distribute_game ()
DECLARE SUB distribute_game_as_zip ()
DECLARE FUNCTION confirmed_copy (srcfile as string, destfile as string) as integer
DECLARE FUNCTION get_windows_gameplayer() as string

'Global variables
REDIM gen(360)
REDIM buffer(16384)
REDIM master(255) as RGBcolor
REDIM uilook(uiColors)
DIM statnames() AS STRING
DIM vpage = 0, dpage = 1
DIM activepalette, fadestate
'FIXME: too many directory variables! Clean this nonsense up
DIM game as string
DIM sourcerpg as string
DIM exename as string
DIM tmpdir as string
DIM homedir as string
DIM workingdir as string
DIM app_dir as string
DIM slave_channel as IPCChannel = NULL_CHANNEL
DIM slave_process as ProcessHandle = 0

EXTERN running_as_slave AS INTEGER
DIM running_as_slave AS INTEGER = NO  'This is just for the benefit of gfx_sdl

'Local variables (declaring these up here is often necessary due to gosubs)
DIM joy(4)
DIM menu(22) AS STRING
DIM menukeys(22) AS STRING
DIM chooserpg_menu(2) AS STRING
DIM quit_menu(3) AS STRING
DIM quit_confirm(1) AS STRING
DIM hsfile AS STRING
DIM intext AS STRING
DIM passphrase AS STRING
DIM archinym AS STRING
DIM SHARED nocleanup AS INTEGER = NO

DIM walkabout_frame_captions(7) AS STRING = {"Up A","Up B","Right A","Right B","Down A","Down B","Left A","Left B"}
DIM hero_frame_captions(7) AS STRING = {"Standing","Stepping","Attack A","Attack B","Cast/Use","Hurt","Weak","Dead"}
DIM enemy_frame_captions(0) AS STRING = {"Enemy (facing right)"}
DIM weapon_frame_captions(1) AS STRING = {"Frame 1","Frame 2"}
DIM attack_frame_captions(2) AS STRING = {"First Frame","Middle Frame","Last Frame"}
DIM box_border_captions(15) AS STRING = {"Top Left Corner","Top Edge Left","Top Edge","Top Edge Right","Top Right Corner","Left Edge Top","Right Edge Top","Left Edge","Right Edge","Left Edge Bottom","Right Edge Bottom","Bottom Left Corner","Bottom Edge Left","Bottom Edge","Bottom Edge Right","Bottom Right Corner"}
DIM portrait_captions(0) AS STRING = {"Character Portrait"}

DIM lumpfile as string
DIM cmdline as string

'--Startup

'seed the random number generator
mersenne_twister TIMER

exename = trimextension(trimpath(COMMAND(0)))

'why do we use different temp dirs in game and custom?
set_homedir

app_dir = exepath  'Note that exepath is a FreeBasic builtin, and not derived from the above exename

#IFDEF __FB_DARWIN__
 'Bundled apps have starting current directory equal to the location of the bundle, but exepath points inside
 IF RIGHT(exepath, 19) = ".app/Contents/MacOS" THEN
  data_dir = parentdir(exepath, 1) + "Resources"
  app_dir = parentdir(exepath, 3)
 END IF
#ENDIF

'temporarily set current directory, will be changed to game directory later if writable
orig_dir = CURDIR()
IF diriswriteable(app_dir) THEN
 'When CUSTOM is installed read-write, work in CUSTOM's folder
 CHDIR app_dir
ELSE
 'If CUSTOM is installed read-only, use your home dir as the default
 CHDIR homedir
END IF

'Start debug file as soon as the directory is set
start_new_debug
debuginfo long_version & build_info 
debuginfo DATE & " " & TIME

#IFDEF __UNIX__
 tmpdir = homedir + SLASH + ".ohrrpgce" + SLASH
 IF NOT isdir(tmpdir) THEN makedir tmpdir
#ELSE
 'Custom on Windows works in the current dir
 tmpdir = CURDIR + SLASH
#ENDIF

processcommandline

load_default_master_palette master()
DefaultUIColors uilook()
DIM font(1023) as integer
getdefaultfont font()

setmodex
debuginfo musicbackendinfo  'Preliminary info before initialising backend
setwindowtitle "O.H.R.RPG.C.E"
setpal master()
setfont font()
textcolor uilook(uiText), 0

'Cleanups up working.tmp if existing; requires graphics up and running
workingdir = tmpdir & "working.tmp"
IF makeworkingdir() = NO THEN GOTO finis

FOR i = 1 TO UBOUND(cmdline_args)
 cmdline = cmdline_args(i)

 IF isfile(cmdline) = 0 AND isdir(cmdline) = 0 THEN
  centerbox 160, 40, 300, 50, 3, 0
  edgeprint "File not found/invalid option:", 15, 30, uilook(uiText), 0
  edgeprint RIGHT(cmdline,35), 15, 40, uilook(uiText), 0
  setvispage 0
  w = getkey
  CONTINUE FOR
 END IF
 IF LCASE(justextension(cmdline)) = "hs" AND isfile(cmdline) THEN
  hsfile = cmdline
  CONTINUE FOR
 END IF

 IF (LCASE(justextension(cmdline)) = "rpg" AND isfile(cmdline)) OR isdir(cmdline) THEN
  sourcerpg = cmdline
  game = trimextension(trimpath(sourcerpg))
 END IF
NEXT
IF game = "" THEN
 hsfile = ""
 GOSUB chooserpg
END IF

#IFDEF __FB_WIN32__
 IF MID(sourcerpg, 2, 1) <> ":" THEN sourcerpg = curdir + SLASH + sourcerpg
#ELSE
 IF MID(sourcerpg, 1, 1) <> SLASH THEN sourcerpg = curdir + SLASH + sourcerpg
#ENDIF
a$ = trimfilename(sourcerpg)

end_debug
IF a$ <> "" ANDALSO diriswriteable(a$) THEN
 CHDIR a$
END IF
'otherwise, keep current directory as it was, net effect: it is the same as in Game

start_new_debug
debuginfo long_version & build_info
debuginfo "Runtime info: " & gfxbackendinfo & "  " & musicbackendinfo & "  " & systeminfo

'For getdisplayname
copylump sourcerpg, "archinym.lmp", workingdir, -1

debuginfo "Editing game " & sourcerpg & " (" & getdisplayname(" ") & ") " & DATE & " " & TIME
setwindowtitle "O.H.R.RPG.C.E - " + trimpath(sourcerpg)

'--set game according to the archinym
copylump sourcerpg, "archinym.lmp", workingdir, -1
archinym = readarchinym(workingdir, sourcerpg)
game = workingdir + SLASH + archinym

copylump sourcerpg, archinym + ".gen", workingdir
xbload game + ".gen", gen(), "general data is missing: RPG file appears to be corrupt"

IF gen(genVersion) > CURRENT_RPG_VERSION THEN
 debug "genVersion = " & gen(genVersion)
 future_rpg_warning
END IF

GOSUB checkpass

clearpage vpage
textcolor uilook(uiText), 0
printstr "UNLUMPING DATA: please wait.", 0, 0, vpage
setvispage vpage

touchfile workingdir + SLASH + "__danger.tmp"
IF isdir(sourcerpg) THEN
 'work on an unlumped RPG file. Don't take hidden files
 copyfiles sourcerpg, workingdir
ELSE
 unlump sourcerpg, workingdir + SLASH
END IF
safekill workingdir + SLASH + "__danger.tmp"

'Perform additional checks for future rpg files or corruption
rpg_sanity_checks

'upgrade obsolete RPG files
upgrade

'Load the game's palette, uicolors, font
activepalette = gen(genMasterPal)
loadpalette master(), activepalette
setpal master()
LoadUIColors uilook(), activepalette
xbload game + ".fnt", font(), "Font not loaded"
setfont font()

IF hsfile <> "" THEN GOTO hsimport

loadglobalstrings
getstatnames statnames()

setupmusic

'From here on, preserve working.tmp if something goes wrong
cleanup_on_error = NO

menumode = 0
pt = 0
mainmax = 0
quitnow = 0

setkeys
setmainmenu menu(), mainmax, menukeys()
DO:
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(scEsc) > 1 THEN
  SELECT CASE menumode
   CASE 0'--in main menu
    GOSUB relump
    IF quitnow > 1 THEN GOTO finis
   CASE 1'--graphics
    pt = 0
    menumode = 0
    setmainmenu menu(), mainmax, menukeys()
  END SELECT
 END IF
 IF keyval(scF1) > 1 THEN
  SELECT CASE menumode
   CASE 0'--normal mode
    show_help "main"
   CASE 1'--normal mode
    show_help "gfxmain"
  END SELECT
 END IF
 intext = LCASE(getinputtext)
 passphrase = RIGHT(passphrase + intext, 4)
 IF passphrase = "spam" THEN passphrase = "" : secret_menu
 FOR i = 1 TO mainmax
  DIM temp as integer = (pt + i) MOD (mainmax + 1)
  IF INSTR(menukeys(temp), intext) THEN pt = temp : EXIT FOR
 NEXT
 usemenu pt, 0, 0, mainmax, 24
 IF enter_or_space() THEN
  SELECT CASE menumode
   CASE 0'--normal mode
    IF pt = 0 THEN
     pt = 0
     menumode = 1
     setgraphicmenu menu(), mainmax, menukeys()
    END IF
    IF pt = 1 THEN map_picker
    IF pt = 2 THEN edit_global_text_strings
    IF pt = 3 THEN herodata
    IF pt = 4 THEN enemydata
    IF pt = 5 THEN attackdata
    IF pt = 6 THEN itemdata
    IF pt = 7 THEN shopdata
    IF pt = 8 THEN formation
    IF pt = 9 THEN text_box_editor
    if pt = 10 THEN menu_editor
    IF pt = 11 THEN vehicles
    IF pt = 12 THEN tagnames
    IF pt = 13 THEN importsong
    IF pt = 14 THEN importsfx
    IF pt = 15 THEN fontedit
    IF pt = 16 THEN gendata
    IF pt = 17 THEN scriptman
    IF pt = 18 THEN slice_editor
    IF pt = 19 THEN spawn_game_menu
    IF pt = 20 THEN distribute_game
    IF pt = 21 THEN
     GOSUB relump
     IF quitnow > 1 THEN GOTO finis
    END IF
   CASE 1'--graphics mode
    IF pt = 0 THEN
     pt = 0
     menumode = 0
     setmainmenu menu(), mainmax, menukeys()
    END IF
    IF pt = 1 THEN maptile
    IF pt = 2 THEN sprite 20, 20, gen(genMaxNPCPic),    8, 5, walkabout_frame_captions(),  4, 4
    IF pt = 3 THEN sprite 32, 40, gen(genMaxHeroPic),   8, 16, hero_frame_captions(), 4, 0
    IF pt = 4 THEN sprite 34, 34, gen(genMaxEnemy1Pic), 1, 2, enemy_frame_captions(), 4, 1
    IF pt = 5 THEN sprite 50, 50, gen(genMaxEnemy2Pic), 1, 4, enemy_frame_captions(), 2, 2
    IF pt = 6 THEN sprite 80, 80, gen(genMaxEnemy3Pic), 1, 10, enemy_frame_captions(), 2, 3
    IF pt = 7 THEN sprite 50, 50, gen(genMaxAttackPic), 3, 12, attack_frame_captions(), 2, 6
    IF pt = 8 THEN sprite 24, 24, gen(genMaxWeaponPic), 2, 2, weapon_frame_captions(), 4, 5
    IF pt = 9 THEN
     sprite 16, 16, gen(genMaxBoxBorder), 16, 7, box_border_captions(), 4, 7
    END IF
    IF pt = 10 THEN sprite 50, 50, gen(genMaxPortrait), 1, 4, portrait_captions(), 2, 8
    IF pt = 11 THEN importbmp ".mxs", "screen", gen(genNumBackdrops)
    IF pt = 12 THEN
     gen(genMaxTile) = gen(genMaxTile) + 1
     importbmp ".til", "tileset", gen(genMaxTile)
     gen(genMaxTile) = gen(genMaxTile) - 1
     tileset_empty_cache
    END IF
    IF pt = 13 THEN ui_color_editor(activepalette)
  END SELECT
  '--always resave the .GEN lump after any menu
  xbsave game + ".gen", gen(), 1000
 END IF

 clearpage dpage
 standardmenu menu(), mainmax, 22, pt, 0, 0, 0, dpage, 0

 textcolor uilook(uiSelectedDisabled), 0
 printstr version_code, 0, 176, dpage
 printstr version_build, 0, 184, dpage
 textcolor uilook(uiText), 0
 printstr "Press F1 for help on any menu!", 0, 192, dpage

 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP

chooserpg:
last = 2: csr = 1: top = 0
chooserpg_menu(0) = "CREATE NEW GAME"
chooserpg_menu(1) = "LOAD EXISTING GAME"
chooserpg_menu(2) = "EXIT PROGRAM"

setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(scEsc) > 1 THEN GOTO finis
 usemenu csr, top, 0, last, 20
 IF enter_or_space() THEN
  IF csr = 0 THEN
   game = inputfilename("Filename of New Game?", ".rpg", CURDIR, "input_file_new_game", , NO)
   IF game <> "" THEN
     IF NOT newRPGfile(finddatafile("ohrrpgce.new"), game + ".rpg") THEN GOTO finis
     sourcerpg = game + ".rpg"
     game = trimpath(game)
     EXIT DO
   END IF
  ELSEIF csr = 1 THEN
   sourcerpg = browse(7, "", "*.rpg", tmpdir, 0, "browse_rpg")
   game = trimextension(trimpath(sourcerpg))
   IF game <> "" THEN EXIT DO
  ELSEIF csr = 2 THEN
   GOTO finis
  END IF
 END IF

 clearpage dpage
 standardmenu chooserpg_menu(), last, 22, csr, top, 0, 0, dpage, 0

 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP
RETRACE


relump:
xbsave game + ".gen", gen(), 1000
quit_menu(0) = "Continue editing"
quit_menu(1) = "Save changes and continue editing"
quit_menu(2) = "Save changes and quit"
quit_menu(3) = "Discard changes and quit"
clearkey(-1) 'stop firing esc's, if the user hit esc+pgup+pgdown
quitnow = sublist(quit_menu(), "quit_and_save")
IF keyval(-1) THEN '2nd quit request? Right away!
 a$ = trimextension(sourcerpg)
 i = 0
 DO
  lumpfile = a$ & ".rpg_" & i & ".bak"
  i += 1
 LOOP WHILE isfile(lumpfile)
 clearpage 0
 printstr "Saving as " + lumpfile, 0, 0, 0
 printstr "LUMPING DATA: please wait...", 0, 10, 0
 setvispage 0
 dolumpfiles lumpfile
 quitnow = 4 'no special meaning
 RETRACE
END IF
IF (quitnow = 2 OR quitnow = 3) AND slave_channel <> NULL_CHANNEL THEN
 IF yesno("You are still running a copy of this game. Quitting will force " & GAMEEXE & " to quit as well. Really quit?") = NO THEN quitnow = 0
END IF
IF quitnow = 1 OR quitnow = 2 THEN
 save_current_game
END IF
IF quitnow = 3 THEN
 quit_confirm(0) = "I changed my mind! Don't quit!"
 quit_confirm(1) = "I am sure I don't want to save."
 IF sublist(quit_confirm()) <= 0 THEN quitnow = 0
END IF
setkeys
RETRACE

checkpass:
'--Is a password set?
IF checkpassword("") THEN RETRACE

'--Input password
pas$ = ""
passcomment$ = ""
'Uncomment to display the/a password
'passcomment$ = getpassword
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(scEnter) > 1 THEN
  IF checkpassword(pas$) THEN
   RETRACE
  ELSE
   GOTO finis
  END IF
 END IF
 strgrabber pas$, 17
 clearpage dpage
 textcolor uilook(uiText), 0
 printstr "This game requires a password to edit", 0, 0, dpage
 printstr " Type it in and press ENTER", 0, 9, dpage
 textcolor uilook(uiSelectedItem + tog), 1
 printstr STRING(LEN(pas$), "*"), 0, 20, dpage
 printstr passcomment$, 0, 40, dpage
 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP

hsimport:
debuginfo "Importing scripts from " & hsfile
xbload game + ".gen", gen(), "general data is missing, RPG file corruption is likely"
upgrade 'needed because it has not already happened because we are doing command-line import
importscripts with_orig_path(hsfile)
xbsave game + ".gen", gen(), 1000
save_current_game
GOSUB cleanupfiles
end_debug
restoremode
SYSTEM

finis:
IF slave_channel <> NULL_CHANNEL THEN
 channel_write_line(slave_channel, "Q ")
 #IFDEF __FB_WIN32__
  'On windows, can't delete workingdir until Game has closed the music. Not too serious though
  basic_textbox "Waiting for " & GAMEEXE & " to clean up...", uilook(uiText), vpage
  setvispage vpage
  IF channel_wait_for_msg(slave_channel, "Q", "", 2000) = 0 THEN
   basic_textbox "Waiting for " & GAMEEXE & " to clean up... giving up.", uilook(uiText), vpage
   setvispage vpage
   sleep 700
  END IF
 #ENDIF
 channel_close(slave_channel)
END IF
IF slave_process <> 0 THEN cleanup_process @slave_process
closemusic
'catch sprite leaks
sprite_empty_cache
palette16_empty_cache
GOSUB cleanupfiles
IF keyval(-1) = 0 THEN
 clearpage vpage
 pop_warning "Don't forget to keep backup copies of your work! You never know when an unknown bug or a hard-drive crash or a little brother might delete your files!"
END IF
end_debug
restoremode
END

cleanupfiles:
IF nocleanup = 0 THEN killdir workingdir
safekill "temp.lst"
RETRACE

'---GENERIC LOOP HEAD---
'setkeys
'DO
'setwait timing(), 100
'setkeys
'tog = tog XOR 1
'IF keyval(scESC) > 1 THEN EXIT DO
'IF keyval(scF1) > 1 THEN show_help "helpkey"

'---GENERIC LOOP TAIL---
'SWAP vpage, dpage
'setvispage vpage
'copypage 3, dpage
'dowait
'LOOP

'---For documentation of general data see http://rpg.hamsterrepublic.com/ohrrpgce/GEN

REM $STATIC

SUB shopdata
DIM a(20), b(curbinsize(binSTF) \ 2 - 1), menu(24) AS STRING, smenu(24) AS STRING, max(24), min(24), sbit(-1 TO 10) AS STRING, stf(16) AS STRING, tradestf(3) AS STRING
DIM her AS HeroDef' Used to get hero name for default stuff name
DIM item_tmp(dimbinsize(binITM)) ' This is only used for loading the default buy/sell price for items
DIM sn AS STRING = "", trit AS STRING = ""


maxcount = 32: pt = 0
havestuf = 0
sbit(0) = "Buy"
sbit(1) = "Sell"
sbit(2) = "Hire"
sbit(3) = "Inn"
sbit(4) = "Equip"
sbit(5) = "Save"
sbit(6) = "Map"
sbit(7) = "Team"
smenu(0) = "Previous Menu"
max(3) = 1
min(5) = -1
max(5) = 99
FOR i = 6 TO 9
 min(i) = -999: max(i) = 999
NEXT i
min(10) = -32767
max(10) = 32767
FOR i = 11 TO 17 STEP 2
 max(i) = gen(genMaxItem)
 min(i) = -1
 max(i + 1) = 99
 min(i + 1) = 1
NEXT

min(20) = -32767
max(20) = 32767
max(21) = gen(genMaxItem)
min(21) = -1
max(22) = 99
min(22) = 1
stf(0) = "Item"
stf(1) = "Hero"
stf(2) = "Script"
stf(3) = "Normal"
stf(4) = "Aquire Inventory"
stf(5) = "Increment Inventory"
stf(6) = "Refuse to Buy"
stf(7) = "In Stock: Infinite"
stf(8) = "In Stock: None"

GOSUB lshopset
GOSUB menugen
li = 6
csr = 0
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(scEsc) > 1 THEN EXIT DO
 IF keyval(scF1) > 1 THEN show_help "shop_main"
 IF keyval(scCtrl) > 0 AND keyval(scBackspace) > 0 THEN cropafter pt, gen(genMaxShop), 0, game + ".sho", 40: GOSUB menugen
 usemenu csr, 0, 0, li, 24
 IF csr = 1 THEN
  '--only allow adding shops up to 99
  'FIXME: This is because of the limitation on remembering shop stock in the SAV format
  '       when the SAV format has changed, this limit can easily be lifted.
  newpt = pt
  IF intgrabber_with_addset(newpt, 0, gen(genMaxShop), 99, "Shop") THEN
   GOSUB sshopset
   pt = newpt
   IF pt > gen(genMaxShop) THEN
    gen(genMaxShop) = pt
    '--Create a new shop record
    flusharray a(), 19, 0
    setpicstuf a(), 40, -1
    storeset game + ".sho", pt, 0
    '--create a new shop stuff record
    flusharray b(), dimbinsize(binSTF), 0
    setpicstuf b(), getbinsize(binSTF), -1
    b(19) = -1 ' When adding new stuff, default in-stock to infinite
    storeset game + ".stf", pt * 50 + 0, 0
   END IF
   GOSUB lshopset
  END IF
 END IF
 IF csr = 2 THEN
  strgrabber sn, 15
  GOSUB menuup
 END IF
 IF enter_or_space() THEN
  IF csr = 0 THEN EXIT DO
  IF csr = 3 AND havestuf THEN
   GOSUB shopstuf
   GOSUB save_stf
  END IF
  IF csr = 4 THEN editbitset a(), 17, 7, sbit(): GOSUB menuup
  IF csr = 6 THEN
   menu(6) = "Inn Script: " & scriptbrowse_string(a(19), plottrigger, "Inn Plotscript")
  END IF
 END IF
 IF csr = 5 THEN
  IF intgrabber(a(18), 0, 32767) THEN GOSUB menuup
 END IF
 IF csr = 6 THEN
  IF scrintgrabber(a(19), 0, 0, scLeft, scRight, 1, plottrigger) THEN GOSUB menuup
 END IF
 clearpage dpage
 FOR i = 0 TO li
  c = uilook(uiMenuItem): IF i = csr THEN c = uilook(uiSelectedItem + tog)
  IF i = 3 AND havestuf = 0 THEN
   c = uilook(uiDisabledItem): IF i = csr THEN c = uilook(uiSelectedDisabled + tog)
  END IF
  textcolor c, 0
  printstr menu(i), 0, i * 8, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP
GOSUB sshopset
EXIT SUB

menugen:
menu(0) = "Return to Main Menu"
menu(3) = "Edit Available Stuff..."
menu(4) = "Select Shop Menu Items..."
GOSUB menuup
RETRACE

lshopset:
setpicstuf a(), 40, -1
loadset game + ".sho", pt, 0
sn = ""
FOR i = 1 TO small(a(0), 15)
 sn = sn + CHR(a(i))
NEXT i
GOSUB menuup
RETRACE

sshopset:
a(16) = small(a(16), 49)
a(0) = LEN(sn)
FOR i = 1 TO small(a(0), 15)
 a(i) = ASC(MID(sn, i, 1))
NEXT i
setpicstuf a(), 40, -1
storeset game + ".sho", pt, 0
RETRACE

menuup:
menu(1) = CHR(27) & " Shop " & pt & " of " & gen(genMaxShop) & CHR(26)
menu(2) = "Name: " & sn
menu(5) = "Inn Price: " & a(18)
IF readbit(a(), 17, 3) = 0 THEN menu(5) = "Inn Price: N/A"
menu(6) = "Inn Script: " & scriptname(a(19), plottrigger)
IF readbit(a(), 17, 0) OR readbit(a(), 17, 1) OR readbit(a(), 17, 2) THEN havestuf = 1 ELSE havestuf = 0
RETRACE

shopstuf:
thing = 0
defaultthing$ = ""
thing$ = ""
tcsr = 0
last = 2
GOSUB load_stf
GOSUB othertype
GOSUB itstrsh
GOSUB stufmenu
setkeys
DO
 setwait 55
 setkeys
 tog = tog XOR 1
 IF keyval(scEsc) > 1 THEN RETRACE
 IF keyval(scF1) > 1 THEN show_help "shop_stuff"
 IF tcsr = 0 THEN IF enter_or_space() THEN RETRACE
 usemenu tcsr, 0, 0, last, 24
 IF tcsr = 1 THEN
  newthing = thing
  IF intgrabber_with_addset(newthing, 0, a(16), 49, "Shop Thing") THEN
   GOSUB save_stf
   thing = newthing
   IF thing > a(16) THEN
    a(16) = thing
    flusharray b(), dimbinsize(binSTF), 0
    setpicstuf b(), getbinsize(binSTF), -1
    b(19) = -1 ' When adding new stuff, default in-stock to infinite
    storeset game + ".stf", pt * 50 + thing, 0
   END IF
   GOSUB load_stf
   GOSUB itstrsh
  END IF
 END IF
 IF tcsr = 2 THEN strgrabber thing$, 16
 IF tcsr > 2 THEN
  IF b(17) = 1 THEN
   '--using a hero
   min(19) = -1
   max(19) = 99
  ELSE
   '--not a hero
   min(19) = 0: max(19) = 3
  END IF
  SELECT CASE tcsr
   CASE 6 TO 9 '--tags
    tag_grabber b(17 + tcsr - 3)
   CASE 11 '--must trade in item 1 type
    IF zintgrabber(b(25), min(tcsr), max(tcsr)) THEN GOSUB itstrsh
   CASE 13, 15, 17 '--must trade in item 2+ types
    IF zintgrabber(b(18 + tcsr), min(tcsr), max(tcsr)) THEN GOSUB itstrsh
   CASE 12, 14, 16, 18 '--trade in item amounts
    b(18 + tcsr) = b(18 + tcsr) + 1
    intgrabber(b(18 + tcsr), min(tcsr), max(tcsr))
    b(18 + tcsr) = b(18 + tcsr) - 1
   CASE 19, 20 '--sell type, price
    intgrabber(b(7 + tcsr), min(tcsr), max(tcsr))
    IF (b(26) < 0 OR b(26) > 3) AND b(17) <> 1 THEN b(26) = 0
   CASE 21 '--trade in for
    IF zintgrabber(b(7 + tcsr), min(tcsr), max(tcsr)) THEN GOSUB itstrsh
   CASE 22 '--trade in for amount
    b(7 + tcsr) = b(7 + tcsr) + 1
    intgrabber(b(7 + tcsr), min(tcsr), max(tcsr))
    b(7 + tcsr) = b(7 + tcsr) - 1
   CASE ELSE
    IF intgrabber(b(17 + tcsr - 3), min(tcsr), max(tcsr)) THEN
     IF tcsr = 3 OR tcsr = 4 THEN
      GOSUB othertype
      '--Re-load default names and default prices
      SELECT CASE b(17)
       CASE 0' This is an item
        thing$ = load_item_name(b(18),1,1)
        loaditemdata item_tmp(), b(18)
        b(24) = item_tmp(46) ' default buy price
        b(27) = item_tmp(46) \ 2 ' default sell price
       CASE 1
        loadherodata @her, b(18)
        thing$ = her.name
        b(24) = 0 ' default buy price
        b(27) = 0 ' default sell price
       CASE ELSE
        thing$ = "Unsupported"
      END SELECT
     END IF
    END IF
  END SELECT
 END IF
 GOSUB othertype
 GOSUB stufmenu

 clearpage dpage
 standardmenu smenu(), last, 22, tcsr, 0, 0, 0, dpage, 0

 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP

othertype:
SELECT CASE b(17)
 CASE 0 ' Is an item
  last = 22
  max(4) = gen(genMaxItem): IF b(18) > max(4) THEN b(18) = 0
  max(19) = 3 ' Item sell-type
 CASE 1 ' Is a hero
  last = 19
  max(4) = gen(genMaxHero): IF b(18) > gen(genMaxHero) THEN b(18) = 0
  max(19) = gen(genMaxLevel) ' Hero experience level
 CASE 2 ' Is ... something else?
  last = 18
  max(4) = 999
END SELECT
RETRACE

stufmenu:
smenu(1) = CHR(27) & "Shop Thing " & thing & " of " & a(16) & CHR(26)
smenu(2) = "Name: " & thing$
smenu(3) = "Type: " & b(17) & "-" & stf(bound(b(17), 0, 2))
smenu(4) = "Number: " & b(18) & " " & defaultthing$
IF b(19) > 0 THEN
 smenu(5) = "In Stock: " & b(19)
ELSE
 smenu(5) = stf(8 + bound(b(19), -1, 0))
END IF
smenu(6) = tag_condition_caption(b(20), "Buy Require Tag", "No Tag Check")
smenu(7) = tag_condition_caption(b(21), "Sell Require Tag", "No Tag Check")
smenu(8) = tag_condition_caption(b(22), "Buy Set Tag", "No Tag Set", "Unalterable", "Unalterable")
smenu(9) = tag_condition_caption(b(23), "Sell Set Tag", "No Tag Set", "Unalterable", "Unalterable")
smenu(10) = "Cost: " & b(24) & " " & readglobalstring(32, "Money")
smenu(11) = "Must Trade in " & (b(30) + 1) & " of: " & tradestf(0)
smenu(12) = " (Change Amount)"
smenu(13) = "Must Trade in " & (b(32) + 1) & " of: " & tradestf(1)
smenu(14) = " (Change Amount)"
smenu(15) = "Must Trade in " & (b(34) + 1) & " of: " & tradestf(2)
smenu(16) = " (Change Amount)"
smenu(17) = "Must Trade in " & (b(36) + 1) & " of: " & tradestf(3)
smenu(18) = " (Change Amount)"
IF b(17) = 0 THEN
 smenu(19) = "Sell type: " & stf(bound(b(26), 0, 3) + 3)
 smenu(20) = "Sell for: " & b(27) & " " & readglobalstring(32, "Money")
 smenu(21) = "  and " & (b(29) + 1) & " of: " & trit$
 smenu(22) = " (Change Amount)"
ELSE
 smenu(19) = "Experience Level: "
 IF b(26) = -1 THEN
  smenu(19) = smenu(19) & "default"
 ELSE
  smenu(19) = smenu(19) & b(26)
 END IF
END IF
'--mutate menu for item/hero
RETRACE

load_stf:
flusharray b(), dimbinsize(binSTF), 0
setpicstuf b(), getbinsize(binSTF), -1
loadset game + ".stf", pt * 50 + thing, 0
thing$ = readbadbinstring(b(), 0, 16, 0)
'---check for invalid data
IF b(17) < 0 OR b(17) > 2 THEN b(17) = 0
IF b(19) < -1 THEN b(19) = 0
IF (b(26) < 0 OR b(26) > 3) AND b(17) <> 1 THEN b(26) = 0
'--WIP Serendipity custom builds didn't flush shop records when upgrading properly
FOR i = 32 TO 41
 b(i) = large(b(i), 0)
NEXT
RETRACE

save_stf:
b(0) = LEN(thing$)
FOR i = 1 TO small(b(0), 16)
 b(i) = ASC(MID$(thing$, i, 1))
NEXT i
setpicstuf b(), getbinsize(binSTF), -1
storeset game + ".stf", pt * 50 + thing, 0
RETRACE

itstrsh:
tradestf(0) = load_item_name(b(25),0,0)
tradestf(1) = load_item_name(b(31),0,0)
tradestf(2) = load_item_name(b(33),0,0)
tradestf(3) = load_item_name(b(35),0,0)
trit$ = load_item_name(b(28),0,0)
RETRACE

END SUB

FUNCTION newRPGfile (templatefile as string, newrpg as string)
 newRPGfile = 0 ' default return value 0 means failure
 IF newrpg = "" THEN EXIT FUNCTION
 textcolor uilook(uiSelectedDisabled), 0
 printstr "Please Wait...", 0, 40, vpage
 printstr "Creating RPG File", 0, 50, vpage
 setvispage vpage
 IF NOT isfile(templatefile) THEN
  printstr "Error: ohrrpgce.new not found", 0, 60, vpage
  printstr "Press Enter to quit", 0, 70, vpage
 setvispage vpage
  w = getkey
  EXIT FUNCTION
 END IF
 writeablecopyfile templatefile, newrpg
 printstr "Unlumping", 0, 60, vpage
 setvispage vpage 'refresh
 unlump newrpg, workingdir + SLASH
 '--create archinym information lump
 fh = FREEFILE
 OPEN workingdir + SLASH + "archinym.lmp" FOR OUTPUT AS #fh
 PRINT #fh, "ohrrpgce"
 PRINT #fh, version
 CLOSE #fh
 printstr "Finalumping", 0, 80, vpage
 setvispage vpage 'refresh
 '--re-lump files as NEW rpg file
 dolumpfiles newrpg
 newRPGfile = -1 'return true for success
END FUNCTION

'=======================================================================
'FIXME: move this up as code gets cleaned up!  (Hah!)
OPTION EXPLICIT

'Try to delete everything in workingdir
FUNCTION empty_workingdir () as integer
 DIM filelist() as string
 findfiles workingdir, ALLFILES, fileTypeFile, NO, filelist()
 FOR i as integer = 0 TO UBOUND(filelist)
  DIM fname as string = workingdir + SLASH + filelist(i)
  safekill fname
  IF isfile(fname) THEN
   notification "Could not clean up " & workingdir & !"\nYou may have to manually delete its contents."
   RETURN NO
  END IF
 NEXT
 RETURN YES
END FUNCTION

'Returns true on success, false if want to GOTO finis
FUNCTION makeworkingdir () as integer
 IF NOT isdir(workingdir) THEN
  makedir workingdir
  RETURN YES
 ELSE
  'Does this look like a game, or should we just delete it?
  DIM filelist() as string
  findfiles workingdir, ALLFILES, fileTypeFile, NO, filelist()
  IF UBOUND(filelist) <= 5 THEN
   'Just some stray files that refused to delete last time
   RETURN empty_workingdir
  END IF

  'Recover from an old crash
  RETURN handle_dirty_workingdir
 END IF
END FUNCTION

'Returns true on success, false if want to GOTO finis
FUNCTION handle_dirty_workingdir () as integer
 DIM cleanup_menu(2) AS STRING
 cleanup_menu(0) = "DO NOTHING"
 cleanup_menu(1) = "RECOVER IT"
 cleanup_menu(2) = "ERASE IT"
 DIM clean_choice as integer
 DIM tog as integer

 DIM index as integer = 0
 DIM destfile as string
 DO
  destfile = "recovered" & index & ".bak"
  IF NOT isfile(destfile) THEN EXIT DO
  index += 1
 LOOP

 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
  usemenu clean_choice, 0, 0, 2, 2
  IF enter_or_space() THEN
   IF clean_choice = 1 THEN
	IF isfile(workingdir + SLASH + "__danger.tmp") THEN
	 textcolor uilook(uiSelectedItem), uilook(uiHighlight) 'FIXME: new uilook for warning text colors?
	 printstr "Data is corrupt, not safe to relump", 0, 100, vpage
	 setvispage vpage 'refresh
	 waitforanykey
	ELSE '---END UNSAFE
	 printstr "Saving as " + destfile, 0, 180, vpage
	 printstr "LUMPING DATA: please wait...", 0, 190, vpage
	 setvispage vpage 'refresh
	 '--re-lump recovered files as BAK file
	 dolumpfiles destfile
	 clearpage vpage
	 basic_textbox "The recovered data has been saved. If " + CUSTOMEXE + " crashed last time you " _
				   "ran it and you lost work, you may be able to recover it. Make a backup " _
				   "copy of your RPG and then rename " + destfile + !" to gamename.rpg\n" _
				   "If you have questions, ask ohrrpgce-crash@HamsterRepublic.com", _
				   uilook(uiText), vpage
	 setvispage vpage
	 waitforanykey
     empty_workingdir
	 RETURN YES  'continue
	END IF '---END RELUMP
   END IF
   IF clean_choice = 2 THEN empty_workingdir : RETURN YES  'continue
   IF clean_choice = 0 THEN nocleanup = 1: RETURN NO  'quit
  END IF

  basic_textbox !"A game was found unlumped.\n" _
				 "This may mean that " + CUSTOMEXE + " crashed last time you used it, or it may mean " _
				 "that another copy of " + CUSTOMEXE + " is already running in the background.", _
				 uilook(uiText), dpage
  standardmenu cleanup_menu(), 2, 2, clean_choice, 0, 16, 150, dpage, 0

  SWAP vpage, dpage
  setvispage vpage
  clearpage dpage
  dowait
 LOOP
END FUNCTION

SUB dolumpfiles (filetolump as string)
 '--build the list of files to lump. We don't need hidden files
 DIM filelist() AS STRING
 findfiles workingdir, ALLFILES, fileTypeFile, NO, filelist()
 fixlumporder filelist()
 IF isdir(filetolump) THEN
  '---copy changed files back to source rpgdir---
  IF NOT fileiswriteable(filetolump & SLASH & "archinym.lmp") THEN
   move_unwriteable_rpg filetolump
   makedir filetolump
  END IF
  FOR i AS INTEGER = 0 TO UBOUND(filelist)
   safekill filetolump + SLASH + filelist(i)
   copyfile workingdir + SLASH + filelist(i), filetolump + SLASH + filelist(i)
   'FIXME: move file instead? (warning: can't move from different mounted filesystem)
  NEXT
 ELSE
  '---relump data into lumpfile package---
  IF NOT fileiswriteable(filetolump) THEN
   move_unwriteable_rpg filetolump
  END IF
  lumpfiles filelist(), filetolump, workingdir + SLASH
 END IF
END SUB

SUB move_unwriteable_rpg (filetolump as string)
 clearpage vpage
 DIM newfile as string = homedir & SLASH & trimpath(filetolump)
 basic_textbox filetolump + " is not writeable. Saving to " + newfile + !"\n[Press Any Key]", uilook(uiText), vpage
 setvispage vpage
 getkey
 filetolump = newfile
END SUB

SUB secret_menu ()
 DIM menu(...) as string = {"Reload Editor", "Editor Editor", "Conditions and More Tests", "Transformed Quads", "Sprite editor with arbitrary sizes"}
 DIM st as MenuState
 st.size = 24
 st.last = UBOUND(menu)

 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF enter_or_space() THEN
   IF st.pt = 0 THEN reload_editor
   IF st.pt = 1 THEN editor_editor
   IF st.pt = 2 THEN condition_test_menu
   IF st.pt = 3 THEN quad_transforms_menu
   IF st.pt = 4 THEN arbitrary_sprite_editor
  END IF
  usemenu st
  clearpage vpage
  standardmenu menu(), st, 0, 0, vpage
  setvispage vpage
  dowait
 LOOP
 setkeys
END SUB

SUB arbitrary_sprite_editor ()
 DIM tempsets AS INTEGER = 0
 DIM tempcaptions(15) AS STRING
 FOR i AS INTEGER = 0 to UBOUND(tempcaptions)
  tempcaptions(i) = "frame" & i
 NEXT i
 DIM size AS XYPair
 size.x = 20
 size.y = 20
 DIM framecount AS INTEGER = 8
 DIM crappy_screenpage_lines AS INTEGER
 DIM zoom AS INTEGER = 2

 DIM menu(...) as string = {"Width=", "Height=", "Framecount=", "Zoom=", "Sets=", "Start Editing..."}
 DIM st as MenuState
 st.size = 24
 st.last = UBOUND(menu)
 st.need_update = YES

 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO
  SELECT CASE st.pt
   CASE 0: IF intgrabber(size.x, 0, 160) THEN st.need_update = YES
   CASE 1: IF intgrabber(size.y, 0, 160) THEN st.need_update = YES
   CASE 2: IF intgrabber(framecount, 0, 16) THEN st.need_update = YES
   CASE 3: IF intgrabber(zoom, 0, 4) THEN st.need_update = YES
   CASE 4: IF intgrabber(tempsets, 0, 32000) THEN st.need_update = YES
  END SELECT
  IF enter_or_space() THEN
   IF st.pt = 5 THEN
    crappy_screenpage_lines = ceiling(size.x * size.y * framecount / 2 / 320)
    sprite size.x, size.y, tempsets, framecount, crappy_screenpage_lines, tempcaptions(), zoom, -1
    IF isfile(game & ".pt-1") THEN
     debug "Leaving behind """ & game & ".pt-1"""
    END IF
   END IF
  END IF
  usemenu st
  IF st.need_update THEN
   menu(0) = "Width: " & size.x
   menu(1) = "Height:" & size.y
   menu(2) = "Framecount: " & framecount
   menu(3) = "Zoom: " & zoom
   menu(4) = "Sets: " & tempsets
   st.need_update = NO
  END IF
  clearpage vpage
  standardmenu menu(), st, 0, 0, vpage
  setvispage vpage
  dowait
 LOOP
 setkeys

END SUB

'This menu is for testing experimental Condition UI stuff
SUB condition_test_menu ()
 DIM as Condition cond1, cond2, cond3, cond4
 DIM as AttackElementCondition atkcond
 DIM float as double
 DIM float_repr as string = "0%"
 DIM atkcond_repr as string = ": Never"
 DIM menu(8) as string
 DIM st as MenuState
 st.last = UBOUND(menu)
 st.size = 22
 DIM tmp as integer

 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "condition_test"
  tmp = 0
  IF st.pt = 0 THEN
   IF enter_or_space() THEN EXIT DO
  ELSEIF st.pt = 2 THEN
   tmp = cond_grabber(cond1, YES , NO)
  ELSEIF st.pt = 3 THEN
   tmp = cond_grabber(cond2, NO, NO)
  ELSEIF st.pt = 5 THEN
   tmp = cond_grabber(cond3, YES, YES)
  ELSEIF st.pt = 6 THEN
   tmp = cond_grabber(cond4, NO, YES)
  ELSEIF st.pt = 7 THEN
   tmp = percent_cond_grabber(atkcond, atkcond_repr, ": Never", -9.99, 9.99, 5)
  ELSEIF st.pt = 8 THEN
   tmp = percent_grabber(float, float_repr, -9.99, 9.99, 5)
  END IF
  usemenu st

  clearpage vpage
  menu(0) = "Previous menu"
  menu(1) = "Enter goes to tag browser for tag conds:"
  menu(2) = " If " & condition_string(cond1, (st.pt = 2), "Always", 45)
  menu(3) = " If " & condition_string(cond2, (st.pt = 3), "Never", 45)
  menu(4) = "Enter always goes to cond editor:"
  menu(5) = " If " & condition_string(cond3, (st.pt = 5), "Always", 45)
  menu(6) = " If " & condition_string(cond4, (st.pt = 6), "Never", 45)
  menu(7) = "Fail vs damage from <fire>" & atkcond_repr
  menu(8) = "percent_grabber : " & float_repr
  standardmenu menu(), st, 0, 0, vpage
  printstr STR(tmp), 0, 190, vpage
  setvispage vpage
  dowait
 LOOP
 setkeys
END SUB

SUB setmainmenu (menu() as string, byref mainmax as integer, menukeys() as string)
 mainmax = 21
 menu(0) = "Edit Graphics"
 menu(1) = "Edit Map Data"
 menu(2) = "Edit Global Text Strings"
 menu(3) = "Edit Hero Stats"
 menu(4) = "Edit Enemy Stats"
 menu(5) = "Edit Attacks"
 menu(6) = "Edit Items"
 menu(7) = "Edit Shops"
 menu(8) = "Edit Battle Formations"
 menu(9) = "Edit Text Boxes"
 menu(10) = "Edit Menus"
 menu(11) = "Edit Vehicles"
 menu(12) = "Edit Tag Names"
 menu(13) = "Import Music"
 menu(14) = "Import Sound Effects"
 menu(15) = "Edit Font"
 menu(16) = "Edit General Game Data"
 menu(17) = "Script Management"
 menu(18) = "Edit Slice Collections"
 menu(19) = "Test Game"
 menu(20) = "Distribute Game"
 menu(21) = "Quit Editing"
 get_menu_hotkeys menu(), mainmax, menukeys(), "Edit"
END SUB

SUB setgraphicmenu (menu() as string, byref mainmax as integer, menukeys() as string)
 mainmax = 13
 menu(0) = "Back to the main menu"
 menu(1) = "Edit Maptiles"
 menu(2) = "Draw Walkabout Graphics"
 menu(3) = "Draw Hero Graphics"
 menu(4) = "Draw Small Enemy Graphics  34x34"
 menu(5) = "Draw Medium Enemy Graphics 50x50"
 menu(6) = "Draw Big Enemy Graphics    80x80"
 menu(7) = "Draw Attacks"
 menu(8) = "Draw Weapons"
 menu(9) = "Draw Box Edges"
 menu(10) = "Draw Portrait Graphics"
 menu(11) = "Import/Export Screens"
 menu(12) = "Import/Export Full Maptile Sets"
 menu(13) = "Change User-Interface Colors"
 get_menu_hotkeys menu(), mainmax, menukeys()
END SUB

CONST distmenuEXIT as integer = 1
CONST distmenuZIP as integer = 2

SUB distribute_game ()
 save_current_game
 
 DIM zip_ok as integer = YES
 
 DIM menu as SimpleMenuItem vector
 v_new menu, 0
 append_simplemenu_item menu, "Previous Menu...", , , distmenuEXIT
 append_simplemenu_item menu, " Game file: " & trimpath(sourcerpg), YES, uilook(uiDisabledItem)

 DIM relump as string
 IF LCASE(justextension(sourcerpg)) = "rpgdir" THEN
  relump = find_helper_app("relump")
  IF relump = "" THEN
   append_simplemenu_item menu, " ERROR: Can't find relump" & DOTEXE & " utility", YES, uilook(uiDisabledItem)
   zip_ok = NO
  END IF
 END IF
 
 IF zip_ok THEN
  IF find_helper_app("zip") <> "" THEN
   append_simplemenu_item menu, "Export .ZIP", , , distmenuZIP
  ELSE
   append_simplemenu_item menu, "Can't Export .ZIP (zip" & DOTEXE & " not found)", YES
  END IF
 END IF

 DIM st AS MenuState
 init_menu_state st, cast(BasicMenuItem vector, menu)

 DO
  setwait 55
  setkeys

  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "distribute_game"
  IF enter_or_space() THEN
   SELECT CASE menu[st.pt].dat
    CASE distmenuEXIT: EXIT DO
    CASE distmenuZIP:
     distribute_game_as_zip
   END SELECT
  END IF

  usemenu st, cast(BasicMenuItem vector, menu)
  
  IF st.need_update THEN
  END IF

  clearpage dpage
  standardmenu cast(BasicMenuItem vector, menu), st, 0, 0, dpage
  
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 setkeys
 v_free menu
END SUB

SUB distribute_game_as_zip ()

 DIM spawn_ret as string

 DIM zip as string = find_helper_app("zip")
 IF zip = "" THEN
  visible_debug "Can't create zip files: " & missing_helper_message("zip" + DOTEXE)
  RETURN
 END IF

 DIM ziptmp as string = trimfilename(sourcerpg) & SLASH & "zip.tmp"
 IF isdir(ziptmp) THEN
  IF yesno("Warning: zip.tmp already exists. Delete it?") = NO THEN RETURN
  killdir ziptmp
 END IF

 DIM extension as string = LCASE(justextension(sourcerpg))

 DIM need_relump as integer = NO
 DIM relump as string
 IF extension = "rpgdir" THEN
  need_relump = YES
  relump = find_helper_app("relump")
  IF relump = "" THEN
   visible_debug "Can't find relump" & DOTEXE & " utility."
   RETURN
  END IF
 END IF

 DIM use_gameplayer as integer = YES
 DIM gameplayer as string
 gameplayer = get_windows_gameplayer()
 IF gameplayer = "" THEN
  IF yesno("game.exe is not available, continue anyway?") = NO THEN RETURN
  use_gameplayer = NO
 END IF

 DIM destzip as string = trimextension(sourcerpg) & ".zip"
 DIM shortzip as string = trimpath(destzip)
 IF isfile(destzip) THEN
  IF yesno(shortzip & " already exists. Overwrite it?") = NO THEN RETURN
  safekill destzip
 END IF

 makedir ziptmp
 IF NOT isdir(ziptmp) THEN
  visible_debug "ERROR: unable to create temporary folder"
  RETURN
 END IF

 DO 'Single-pass loop for operations after ziptmp exists
  
  DIM basename as string = trimextension(trimpath(sourcerpg))
  
  IF need_relump THEN
   spawn_ret = spawn_and_wait(relump, """" & sourcerpg & """ """ & ziptmp & SLASH & basename & ".rpg""")
   IF LEN(spawn_ret) ORELSE NOT isfile(ziptmp & SLASH & basename & ".rpg") THEN
    visible_debug "ERROR: failed relumping " & sourcerpg & " " & spawn_ret 
    EXIT DO
   END IF
  ELSE
   IF confirmed_copy(sourcerpg, ziptmp & SLASH & basename & ".rpg") = NO THEN EXIT DO
  END IF

  IF use_gameplayer THEN
   IF confirmed_copy(gameplayer, ziptmp & SLASH & basename & ".exe") = NO THEN EXIT DO
   DIM gamedir AS string = trimfilename(gameplayer)
   DIM otherf(3) as string = {"gfx_directx.dll", "SDL.dll", "SDL_mixer.dll", "LICENSE-binary.txt"}
   FOR i as integer = 0 TO UBOUND(otherf)
    IF confirmed_copy(gamedir & SLASH & otherf(i), ziptmp & SLASH & otherf(i)) = NO THEN EXIT DO
   NEXT i
  END IF
 
  DIM args as string = "-r -j """ & destzip & """ """ & ziptmp & """"
  spawn_ret = spawn_and_wait(zip, args)
  IF LEN(spawn_ret) ORELSE NOT isfile(destzip) THEN
   safekill destzip
   visible_debug "Zip file creation failed." & spawn_ret
   RETURN
  END IF
  
  visible_debug "Successfully created " & shortzip

  EXIT DO 'single pass, never really loops.
 LOOP
 'Cleanup ziptmp
 killdir ziptmp
 
END SUB

FUNCTION get_windows_gameplayer() as string
 'On Windows, Return the full path to game.exe
 'On other platforms, download game.exe, unzip it, and return the full path
 'Returns "" for failure.

#IFDEF __FB_WIN32__

 '--If this is Windows, we already have the correct version of game.exe
 IF isfile(exepath & SLASH & "game.exe") THEN
  RETURN exepath & SLASH & "game.exe"
 ELSE
  visible_debug "ERROR: game.exe wasn't found in the same folder as custom.exe. (This shouldn't happen!)" : RETURN ""
 END IF

#ENDIF
 '--For Non-Windows platforms, we need to download game.exe
 '(NOTE: This all should work fine on Windows too, but it is best to use the installed game.exe)

 '--Find the folder that we are going to download game.exe into
 DIM support as string = find_support_dir()
 IF support = "" THEN visible_debug "ERROR: Unable to find support directory": RETURN ""
 DIM dldir as string = support & SLASH & "gameplayer"
 IF NOT isdir(dldir) THEN makedir dldir
 IF NOT isdir(dldir) THEN visible_debug "ERROR: Unable to create support/gameplayer directory": RETURN ""
  
 '--Decide which url to download
 DIM url as string
 IF version_branch = "wip" THEN
  '--If running a nightly wip, download the latest nightly wip
  url = "http://hamsterrepublic.com/ohrrpgce/nightly/ohrrpgce-wip-default.zip"
 ELSE
  '--If running any stable release, download the latest stable release.
  url = "http://hamsterrepublic.com/dl/ohrrpgce-minimal.zip"
 END IF

 '--Ask the user for permission the first time we download (subsequent updates don't ask)
 DIM destzip as string = dldir & SLASH & "ohrrpgce-windows.zip"
 IF NOT isfile(destzip) THEN
  IF yesno("Is it okay to download the Windows version of OHRRPGCE game.exe from HamsterRepublic.com now?") = NO THEN RETURN ""
 END IF

 '--Actually download the dang file
 wget_download url, destzip
 
 '--Find the unzip tool
 DIM unzip as string = find_helper_app("unzip")
 IF unzip = "" THEN visible_debug "ERROR: Couldn't find unzip tool": RETURN ""
 
 '--Unzip the desired files
 DIM args as string = "-o """ & destzip & """ game.exe gfx_directx.dll SDL.dll SDL_mixer.dll LICENSE-binary.txt -d """ & dldir & """"
 DIM spawn_ret as string = spawn_and_wait(unzip, args)
 IF LEN(spawn_ret) > 0 THEN visible_debug "ERROR: unzip failed: " & spawn_ret : RETURN ""
 
 IF NOT isfile(dldir & SLASH & "game.exe")           THEN visible_debug "ERROR: Failed to unzip game.exe" : RETURN ""
 IF NOT isfile(dldir & SLASH & "gfx_directx.dll")    THEN visible_debug "ERROR: Failed to unzip gfx_directx.dll" : RETURN ""
 IF NOT isfile(dldir & SLASH & "SDL.dll")            THEN visible_debug "ERROR: Failed to unzip SDL.dll" : RETURN ""
 IF NOT isfile(dldir & SLASH & "SDL_mixer.dll")      THEN visible_debug "ERROR: Failed to unzip SDL_mixer.dll" : RETURN ""
 IF NOT isfile(dldir & SLASH & "LICENSE-binary.txt") THEN visible_debug "ERROR: Failed to unzip LICENSE-binary.txt" : RETURN ""
 
 RETURN dldir & SLASH & "game.exe"
END FUNCTION

FUNCTION confirmed_copy (srcfile as string, destfile as string) as integer
 'Copy a file, heck to make sure it really was copied, and show an error message if not.
 ' Returns true if the copy was okay, false if it failed
 copyfile srcfile, destfile
 IF NOT isfile(destfile) THEN
  visible_debug "ERROR: failed copying " & destfile
  RETURN NO
 END IF
 RETURN YES
END FUNCTION

SUB save_current_game ()
 clearpage 0
 setvispage 0
 textcolor uilook(uiText), 0
 printstr "LUMPING DATA: please wait.", 0, 0, 0
 setvispage 0 'refresh
 '--verify various stuff
 rpg_sanity_checks
 '--lump data to SAVE rpg file
 dolumpfiles sourcerpg
END SUB

#IFDEF USE_RASTERIZER

#include "matrixMath.bi"
#include "gfx_newRenderPlan.bi"
#include "gfx.bi"

declare sub surface_export_bmp24 (f as string, byval surf as Surface Ptr)

SUB quad_transforms_menu ()
 DIM menu(...) as string = {"Arrows: scale X and Y", "<, >: change angle", "[, ]: change sprite"}
 DIM st as MenuState
 st.last = 2
 st.size = 22
 st.need_update = YES
 
 DIM spritemode AS INTEGER = -1

 DIM testframe as Frame ptr
 DIM vertices(3) as Float3

 DIM angle as single
 DIM scale as Float2 = (2.0, 2.0)
 DIM position as Float2 = (150, 50)

 'This is used to copy data from vpages(vpage) to vpage32 
 DIM vpage8 as Surface ptr
 gfx_surfaceCreate(320, 200, SF_8bit, SU_Source, @vpage8)

 'This is the actual render Surface
 DIM vpage32 as Surface ptr
 gfx_surfaceCreate(320, 200, SF_32bit, SU_RenderTarget, @vpage32)

 DIM as double drawtime, pagecopytime

 DIM spriteSurface as Surface ptr

 DIM masterPalette as BackendPalette ptr
 gfx_paletteCreate(@masterPalette)
 memcpy(@masterPalette->col(0), @master(0), 256 * 4)
 'Set each colour in the master palette to opaque.
 FOR i as integer = 0 TO 255
  masterPalette->col(i).a = 255
 NEXT

 DO
  setwait 55
  
  if st.need_update then
   if spritemode < -1 then spritemode = 8
   if spritemode > 8 then spritemode = -1

   frame_unload @testframe

   select case spritemode
    case 0 to 8
     DIM tempsprite as GraphicPair
     load_sprite_and_pal tempsprite, spritemode, 0, -1
     with tempsprite
      testframe = frame_new(.sprite->w, .sprite->h, , YES)
      frame_draw .sprite, .pal, 0, 0, , , testframe
     end with
     unload_sprite_and_pal tempsprite
    case else
     testframe = frame_new(16, 16)
     FOR i as integer = 0 TO 255
      putpixel testframe, (i MOD 16), (i \ 16), i
     NEXT
   end select

   gfx_surfaceDestroy( spriteSurface )
   gfx_surfaceCreate( testframe->w, testframe->h, SF_8bit, SU_Source, @spriteSurface )
   memcpy(spriteSurface->pPaletteData, testframe->image, testframe->w * testframe->h - 1)
   gfx_surfaceUpdate( spriteSurface )

   DIM testframesize as Rect
   WITH testframesize
    .top = 0
    .left = 0
    .right = spriteSurface->width - 1
    .bottom = spriteSurface->height - 1
   END WITH
   vec3GenerateCorners @vertices(0), 4, testframesize
   
   st.need_update = NO
  end if
  
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scLeft)  THEN scale.x -= 0.1
  IF keyval(scRight) THEN scale.x += 0.1
  IF keyval(scUp)    THEN scale.y -= 0.1
  IF keyval(scDown)  THEN scale.y += 0.1
  IF keyval(scLeftCaret)  THEN angle -= 0.1
  IF keyval(scRightCaret) THEN angle += 0.1
  IF keyval(scLeftBracket) > 1 THEN spritemode -= 1: st.need_update = YES
  IF keyval(scRightBracket) > 1 THEN spritemode += 1: st.need_update = YES

  clearpage vpage
  standardmenu menu(), st, 0, 0, vpage
  frame_draw testframe, , 20, 50, 2, , vpages(vpage)  'drawn at 2x scale

  'Can only display the previous frame's time to draw, since we don't currently
  'have any functions to print text to surfaces
  printstr "Drawn in " & FIX(drawtime * 1000000) & " usec, pagecopytime = " & FIX(pagecopytime * 1000000) & " usec", 0, 190, vpage
  debug "Drawn in " & FIX(drawtime * 1000000) & " usec, pagecopytime = " & FIX(pagecopytime * 1000000) & " usec"

  'Copy from vpage (8 bit Frame) to a source Surface, and then from there to the render target surface
  memcpy(vpage8->pPaletteData, vpages(vpage)->image, 320 * 200)
  gfx_surfaceUpdate( vpage8 )
  pagecopytime = TIMER
  gfx_surfaceCopy( NULL, vpage8, masterPalette, NO, NULL, vpage32)
  pagecopytime = TIMER - pagecopytime

  DIM starttime as DOUBLE = TIMER

  DIM matrix as Float3x3
  matrixLocalTransform @matrix, angle, scale, position
  DIM trans_vertices(3) as Float3
  vec3Transform @trans_vertices(0), 4, @vertices(0), 4, matrix

  'may have to reorient the tex coordinates
  DIM pt_vertices(3) as VertexPT
  pt_vertices(0).tex.u = 0
  pt_vertices(0).tex.v = 0
  pt_vertices(1).tex.u = 1
  pt_vertices(1).tex.v = 0
  pt_vertices(2).tex.u = 1
  pt_vertices(2).tex.v = 1
  pt_vertices(3).tex.u = 0
  pt_vertices(3).tex.v = 1
  FOR i as integer = 0 TO 3
   pt_vertices(i).pos.x = trans_vertices(i).x
   pt_vertices(i).pos.y = trans_vertices(i).y
  NEXT

  gfx_renderQuadTexture( @pt_vertices(0), spriteSurface, masterPalette, YES, NULL, vpage32 )
  drawtime = TIMER - starttime

  gfx_present( vpage32, NULL )

  'surface_export_bmp24 ("out.bmp", vpage32)
  dowait
 LOOP
 setkeys
 frame_unload @testframe
 gfx_surfaceDestroy(vpage32)
 gfx_surfaceDestroy(vpage8)
 gfx_surfaceDestroy(spriteSurface)
 gfx_paletteDestroy(masterPalette)
END SUB

#ELSE

SUB quad_transforms_menu ()
 notification "Compile with 'scons raster=1' to enable."
END SUB

#ENDIF
