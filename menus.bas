'OHRRPGCE CUSTOM - Editor menu routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
'$DYNAMIC
DEFINT A-Z
'basic subs and functions
DECLARE FUNCTION str2lng& (stri$)
DECLARE FUNCTION str2int% (stri$)
DECLARE FUNCTION readshopname$ (shopnum%)
DECLARE SUB flusharray (array%(), size%, value%)
DECLARE FUNCTION filenum$ (n%)
DECLARE SUB writeconstant (filehandle%, num%, names$, unique$(), prefix$)
DECLARE SUB touchfile (f$)
DECLARE SUB standardmenu (menu$(), size%, vis%, pt%, top%, x%, y%, page%, edge%)
DECLARE FUNCTION readitemname$ (index%)
DECLARE FUNCTION readattackname$ (index%)
DECLARE SUB writeglobalstring (index%, s$, maxlen%)
DECLARE FUNCTION readglobalstring$ (index%, default$, maxlen%)
DECLARE SUB textfatalerror (e$)
DECLARE SUB fatalerror (e$)
DECLARE FUNCTION unlumpone% (lumpfile$, onelump$, asfile$)
DECLARE FUNCTION getmapname$ (m%)
DECLARE FUNCTION numbertail$ (s$)
DECLARE SUB cropafter (index%, limit%, flushafter%, lump$, bytes%, prompt%)
DECLARE FUNCTION isunique% (s$, u$(), r%)
DECLARE FUNCTION loadname$ (length%, offset%)
DECLARE FUNCTION exclude$ (s$, x$)
DECLARE FUNCTION exclusive$ (s$, x$)
DECLARE FUNCTION needaddset (pt%, check%, what$)
DECLARE SUB cycletile (cycle%(), tastuf%(), pt%(), skip%())
DECLARE SUB testanimpattern (tastuf%(), taset%)
DECLARE FUNCTION heroname$ (num%, cond%(), a%())
DECLARE FUNCTION onoroff$ (n%)
DECLARE FUNCTION lmnemonic$ (index%)
DECLARE FUNCTION rotascii$ (s$, o%)
DECLARE SUB editbitset (array%(), wof%, last%, names$())
DECLARE SUB formation ()
DECLARE SUB enemydata ()
DECLARE SUB herodata ()
DECLARE SUB attackdata ()
DECLARE SUB getnames (stat$(), max%)
DECLARE SUB statname ()
DECLARE SUB textage ()
DECLARE FUNCTION sublist% (num%, s$())
DECLARE SUB maptile (font%())
DECLARE FUNCTION intgrabber (n%, min%, max%, less%, more%)
DECLARE FUNCTION zintgrabber% (n%, min%, max%, less%, more%)
DECLARE SUB strgrabber (s$, maxl%)
DECLARE FUNCTION maplumpname$ (map, oldext$)
DECLARE SUB editmenus ()
DECLARE SUB writepassword (p$)
DECLARE FUNCTION readpassword$ ()
DECLARE SUB writescatter (s$, lhold%, start%)
DECLARE SUB readscatter (s$, lhold%, start%)
DECLARE SUB fixfilename (s$)
DECLARE FUNCTION filesize$ (file$)
DECLARE FUNCTION inputfilename$ (query$, ext$)
DECLARE FUNCTION getsongname$ (num%)
DECLARE FUNCTION getsfxname$ (num%)
DECLARE FUNCTION charpicker$ ()
DECLARE SUB generalscriptsmenu ()
DECLARE SUB generalsfxmenu ()
DECLARE FUNCTION scriptbrowse$ (trigger%, triggertype%, scrtype$)
DECLARE FUNCTION scrintgrabber (n%, BYVAL min%, BYVAL max%, BYVAL less%, BYVAL more%, scriptside%, triggertype%)

'$INCLUDE: 'compat.bi'
'$INCLUDE: 'allmodex.bi'
'$INCLUDE: 'common.bi'
'$INCLUDE: 'cglobals.bi'

'$INCLUDE: 'const.bi'
'$INCLUDE: 'scrconst.bi'

REM $STATIC
SUB editmenus

'DIM menu$(20), veh(39), min(39), max(39), offset(39), vehbit$(15), tiletype$(8)

CONST MenuDatSize = 187
DIM menu$(20),min(20),max(20), bitname$(-1 to 32), menuname$, vehname$

DIM menudat(MenuDatSize - 1), pt, csr, top

pt = 0: csr = 0: top = 0

bitname$(0) = "Background is Fuzzy"


' min(3) = 0: max(3) = 5: offset(3) = 8             'speed
' FOR i = 0 TO 3
'  min(5 + i) = 0: max(5 + i) = 8: offset(5 + i) = 17 + i
' NEXT i
' min(9) = -1: max(9) = 255: offset(9) = 11 'battles
' min(10) = -2: max(10) = general(43): offset(10) = 12 'use button
' min(11) = -2: max(11) = general(43): offset(11) = 13 'menu button
' min(12) = -999: max(12) = 999: offset(12) = 14 'tag
' min(13) = general(43) * -1: max(13) = general(39): offset(13) = 15'mount
' min(14) = general(43) * -1: max(14) = general(39): offset(14) = 16'dismount
' min(15) = 0: max(15) = 99: offset(15) = 21'dismount

GOSUB loaddat
GOSUB menu

setkeys
DO
 setwait timing(), 100
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 dummy = usemenu(csr, top, 0, 15, 22)
 SELECT CASE csr
  CASE 0
   IF keyval(57) > 1 OR keyval(28) > 1 THEN
    EXIT DO
   END IF
  CASE 1
   IF pt = general(genMaxMenu) AND keyval(77) > 1 THEN
    GOSUB savedat
    pt = bound(pt + 1, 0, 255)
    IF needaddset(pt, general(genMaxMenu), "menu") THEN
     FOR i = 0 TO MenuDatSize - 1
      menudat(i) = 0
     NEXT i
     menuname$ = ""
     GOSUB menu
    END IF
   END IF
   newptr = pt
   IF intgrabber(newptr, 0, general(genMaxMenu), 75, 77) THEN
    GOSUB savedat
    pt = newptr
    GOSUB loaddat
    GOSUB menu
   END IF
  CASE 2
   oldname$ = menuname$
   strgrabber menuname$, 15
   IF oldname$ <> menuname$ THEN GOSUB menu
'   CASE 3, 5 TO 15
'    IF intgrabber(veh(offset(csr)), min(csr), max(csr), 75, 77) THEN
'     GOSUB vehmenu
'    END IF
  CASE 4
   IF keyval(57) > 1 OR keyval(28) > 1 THEN
    editbitset menudat(), 13, 32, bitname$()
   END IF
 END SELECT
 standardmenu menu$(), 15, 15, csr, top, 0, 0, dpage, 0
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
' GOSUB saveveh
EXIT SUB

menu:
menu$(0) = "Previous Menu"
menu$(1) = "Menu" + XSTR$(pt)
menu$(2) = "Name: " + vehname$

' IF veh(offset(3)) = 3 THEN tmp$ = " 10" ELSE tmp$ = XSTR$(veh(8))
' menu$(3) = "Speed:" + tmp$

' menu$(4) = "Vehicle Bitsets..." '9,10

' menu$(5) = "Override walls: "
' menu$(6) = "Blocked by: "
' menu$(7) = "Mount from: "
' menu$(8) = "Dismount to: "
' FOR i = 0 TO 3
'  menu$(5 + i) = menu$(5 + i) + tiletype$(bound(veh(offset(5 + i)), 0, 8))
' NEXT i

' SELECT CASE veh(offset(9))
'  CASE -1
'   tmp$ = "disabled"
'  CASE 0
'   tmp$ = "enabled"
'  CASE ELSE
'   tmp$ = "formation set" + XSTR$(veh(offset(9)))
' END SELECT
' menu$(9) = "Random Battles: " + tmp$ '11

' FOR i = 0 TO 1
'  SELECT CASE veh(offset(10 + i))
'   CASE -2
'    tmp$ = "disabled"
'   CASE -1
'    tmp$ = "menu"
'   CASE 0
'    tmp$ = "dismount"
'   CASE ELSE
'    tmp$ = "script " + scriptname$(ABS(veh(offset(10 + i))), "plotscr.lst")
'  END SELECT
'  IF i = 0 THEN menu$(10 + i) = "Use button: " + tmp$'12
'  IF i = 1 THEN menu$(10 + i) = "Menu button: " + tmp$'13
' NEXT i

' SELECT CASE ABS(veh(offset(12)))
'  CASE 0
'   tmp$ = " (DISABLED)"
'  CASE 1
'   tmp$ = " (RESERVED TAG)"
'  CASE ELSE
'   tmp$ = " (" + lmnemonic$(ABS(veh(offset(12)))) + ")"  '14
' END SELECT
' menu$(12) = "If riding Tag" + XSTR$(ABS(veh(offset(12)))) + "=" + onoroff$(veh(offset(12))) + tmp$

' SELECT CASE veh(offset(13))
'  CASE 0
'   tmp$ = "[script/textbox]"
'  CASE IS < 0
'   tmp$ = "run script " + scriptname$(ABS(veh(offset(13))), "plotscr.lst")
'  CASE IS > 0
'   tmp$ = "text box" + XSTR$(veh(offset(13)))
' END SELECT
' menu$(13) = "On Mount: " + tmp$

' SELECT CASE veh(offset(14))
'  CASE 0
'   tmp$ = "[script/textbox]"
'  CASE IS < 0
'   tmp$ = "run script " + scriptname$(ABS(veh(offset(14))), "plotscr.lst")
'  CASE IS > 0
'   tmp$ = "text box" + XSTR$(veh(offset(14)))
' END SELECT
' menu$(14) = "On Dismount: " + tmp$

' menu$(15) = "Elevation:" + XSTR$(veh(offset(15))) + " pixels"
RETRACE

loaddat:
setpicstuf menudat(), MenuDatSize*2, -1
loadset "menus.dat", pt, 0
menuname$ = STRING$(bound(menudat(0) AND 255, 0, 15), 0)
array2str menudat(), 1, menuname$
RETRACE

savedat:
' veh(0) = bound(LEN(vehname$), 0, 5)
' str2array vehname$, veh(), 1
' setpicstuf veh(), 80, -1
' storeset "menus.dat", pt, 0
RETRACE

END SUB

SUB vehicles

DIM menu$(20), veh(39), min(39), max(39), offset(39), vehbit$(15), tiletype$(8)

pt = 0: csr = 0: top = 0

vehbit$(0) = "Pass through walls"
vehbit$(1) = "Pass through NPCs"
vehbit$(2) = "Enable NPC activation"
vehbit$(3) = "Enable door use"
vehbit$(4) = "Do not hide leader"
vehbit$(5) = "Do not hide party"
vehbit$(6) = "Dismount one space ahead"
vehbit$(7) = "Pass walls while dismounting"
vehbit$(8) = "Disable flying shadow"

tiletype$(0) = "default"
tiletype$(1) = "A"
tiletype$(2) = "B"
tiletype$(3) = "A and B"
tiletype$(4) = "A or B"
tiletype$(5) = "not A"
tiletype$(6) = "not B"
tiletype$(7) = "neither A nor B"
tiletype$(8) = "everywhere"

min(3) = 0: max(3) = 5: offset(3) = 8             'speed
FOR i = 0 TO 3
 min(5 + i) = 0: max(5 + i) = 8: offset(5 + i) = 17 + i
NEXT i
min(9) = -1: max(9) = 255: offset(9) = 11 'battles
min(10) = -2: max(10) = general(43): offset(10) = 12 'use button
min(11) = -2: max(11) = general(43): offset(11) = 13 'menu button
min(12) = -999: max(12) = 999: offset(12) = 14 'tag
min(13) = general(43) * -1: max(13) = general(39): offset(13) = 15'mount
min(14) = general(43) * -1: max(14) = general(39): offset(14) = 16'dismount
min(15) = 0: max(15) = 99: offset(15) = 21'dismount

GOSUB loadveh
GOSUB vehmenu

setkeys
DO
 setwait timing(), 100
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 dummy = usemenu(csr, top, 0, 15, 22)
 SELECT CASE csr
  CASE 0
   IF keyval(57) > 1 OR keyval(28) > 1 THEN
    EXIT DO
   END IF
  CASE 1
   IF pt = general(55) AND keyval(77) > 1 THEN
    GOSUB saveveh
    pt = bound(pt + 1, 0, 32767)
    IF needaddset(pt, general(55), "vehicle") THEN
     FOR i = 0 TO 39
      veh(i) = 0
     NEXT i
     vehname$ = ""
     GOSUB vehmenu
    END IF
   END IF
   newptr = pt
   IF intgrabber(newptr, 0, general(55), 75, 77) THEN
    GOSUB saveveh
    pt = newptr
    GOSUB loadveh
    GOSUB vehmenu
   END IF
  CASE 2
   oldname$ = vehname$
   strgrabber vehname$, 15
   IF oldname$ <> vehname$ THEN GOSUB vehmenu
  CASE 3, 5 TO 9, 12, 15
   IF intgrabber(veh(offset(csr)), min(csr), max(csr), 75, 77) THEN
    GOSUB vehmenu
   END IF
  CASE 4
   IF keyval(57) > 1 OR keyval(28) > 1 THEN
    editbitset veh(), 9, 8, vehbit$()
   END IF
  CASE 10, 11
   IF keyval(57) > 1 OR keyval(28) > 1 THEN
    veh(offset(csr)) = large(0, veh(offset(csr)))
    dummy$ = scriptbrowse$(veh(offset(csr)), plottrigger, "vehicle plotscript")
    GOSUB vehmenu
   ELSEIF scrintgrabber(veh(offset(csr)), min(csr), max(csr), 75, 77, 1, plottrigger) THEN
    GOSUB vehmenu
   END IF
  CASE 13, 14
   IF keyval(57) > 1 OR keyval(28) > 1 THEN
    temptrig = large(0, -veh(offset(csr)))
    dummy$ = scriptbrowse$(temptrig, plottrigger, "vehicle plotscript")
    veh(offset(csr)) = -temptrig
    GOSUB vehmenu
   ELSEIF scrintgrabber(veh(offset(csr)), min(csr), max(csr), 75, 77, -1, plottrigger) THEN
    GOSUB vehmenu
   END IF
 END SELECT
 standardmenu menu$(), 15, 15, csr, top, 0, 0, dpage, 0
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
GOSUB saveveh
EXIT SUB

vehmenu:
menu$(0) = "Previous Menu"
menu$(1) = "Vehicle" + XSTR$(pt)
menu$(2) = "Name: " + vehname$

IF veh(offset(3)) = 3 THEN tmp$ = " 10" ELSE tmp$ = XSTR$(veh(8))
menu$(3) = "Speed:" + tmp$

menu$(4) = "Vehicle Bitsets..." '9,10

menu$(5) = "Override walls: "
menu$(6) = "Blocked by: "
menu$(7) = "Mount from: "
menu$(8) = "Dismount to: "
FOR i = 0 TO 3
 menu$(5 + i) = menu$(5 + i) + tiletype$(bound(veh(offset(5 + i)), 0, 8))
NEXT i

SELECT CASE veh(offset(9))
 CASE -1
  tmp$ = "disabled"
 CASE 0
  tmp$ = "enabled"
 CASE ELSE
  tmp$ = "formation set" + XSTR$(veh(offset(9)))
END SELECT
menu$(9) = "Random Battles: " + tmp$ '11

FOR i = 0 TO 1
 SELECT CASE veh(offset(10 + i))
  CASE -2
   tmp$ = "disabled"
  CASE -1
   tmp$ = "menu"
  CASE 0
   tmp$ = "dismount"
  CASE ELSE
   tmp$ = "script " + scriptname$(ABS(veh(offset(10 + i))), plottrigger)
 END SELECT
 IF i = 0 THEN menu$(10 + i) = "Use button: " + tmp$'12
 IF i = 1 THEN menu$(10 + i) = "Menu button: " + tmp$'13
NEXT i

SELECT CASE ABS(veh(offset(12)))
 CASE 0
  tmp$ = " (DISABLED)"
 CASE 1
  tmp$ = " (RESERVED TAG)"
 CASE ELSE
  tmp$ = " (" + lmnemonic$(ABS(veh(offset(12)))) + ")"  '14
END SELECT
menu$(12) = "If riding Tag" + XSTR$(ABS(veh(offset(12)))) + "=" + onoroff$(veh(offset(12))) + tmp$

SELECT CASE veh(offset(13))
 CASE 0
  tmp$ = "[script/textbox]"
 CASE IS < 0
  tmp$ = "run script " + scriptname$(ABS(veh(offset(13))), plottrigger)
 CASE IS > 0
  tmp$ = "text box" + XSTR$(veh(offset(13)))
END SELECT
menu$(13) = "On Mount: " + tmp$

SELECT CASE veh(offset(14))
 CASE 0
  tmp$ = "[script/textbox]"
 CASE IS < 0
  tmp$ = "run script " + scriptname$(ABS(veh(offset(14))), plottrigger)
 CASE IS > 0
  tmp$ = "text box" + XSTR$(veh(offset(14)))
END SELECT
menu$(14) = "On Dismount: " + tmp$

menu$(15) = "Elevation:" + XSTR$(veh(offset(15))) + " pixels"
RETRACE

loadveh:
setpicstuf veh(), 80, -1
loadset game$ + ".veh", pt, 0
vehname$ = STRING$(bound(veh(0) AND 255, 0, 15), 0)
array2str veh(), 1, vehname$
RETRACE

saveveh:
veh(0) = bound(LEN(vehname$), 0, 15)
str2array vehname$, veh(), 1
setpicstuf veh(), 80, -1
storeset game$ + ".veh", pt, 0
RETRACE

END SUB

SUB gendata ()
STATIC default$
CONST maxMenu = 32
DIM m$(maxMenu), max(maxMenu), bitname$(15)
DIM names$(32), stat$(11), menutop
getnames names$(), 32
stat$(0) = names$(0)
stat$(1) = names$(1)
stat$(2) = names$(2)
stat$(3) = names$(3)
stat$(4) = names$(5)
stat$(5) = names$(6)
stat$(6) = names$(29)
stat$(7) = names$(30)
stat$(8) = names$(8)
stat$(9) = names$(7)
stat$(10) = names$(31)
stat$(11) = names$(4)

IF general(genPoison) <= 0 THEN general(genPoison) = 161
IF general(genStun) <= 0 THEN general(genStun) = 159
IF general(genMute) <= 0 THEN general(genMute) = 163
last = maxMenu
m$(0) = "Return to Main Menu"
m$(1) = "Preference Bitsets..."
m$(8) = "Special Sound Effects..."
m$(9) = "Password For Editing..."
m$(10) = "Pick Title Screen..."
m$(11) = "Rename Game..."
m$(13) = "Special PlotScripts..."
m$(16) = "Import New Master Palette..."
max(1) = 1
max(2) = 320
max(3) = 200
max(4) = general(genMaxMap)
max(5) = general(genMaxSong)
max(6) = general(genMaxSong)
max(7) = general(genMaxSong)
max(9) = 0
max(12) = 32000
max(17) = 255 'poison
max(18) = 255 'stun
max(19) = 255 'mute
max(20) = 32767
FOR i = 21 to 22 'shut up
 max(i) = 9999 'HP + MP
NEXT
FOR i = 23 to 30
 max(i) = 999 'Regular stats
NEXT
max(31) = 100 'MP~
max(32) = 20  'Extra Hits

aboutline$ = ""
longname$ = ""
csr = 0

GOSUB loadpass
GOSUB genstr
setkeys
DO
 setwait timing(), 100
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN
  EXIT DO
 END IF
 dummy = usemenu(csr, menutop, 0, last, 22)
 IF (keyval(28) > 1 OR keyval(57) > 1) THEN
  IF csr = 0 THEN EXIT DO
  IF csr = 1 THEN
   bitname$(0) = "Pause on Battle Sub-menus"
   bitname$(1) = "Enable Caterpillar Party"
   bitname$(2) = "Don't Restore HP on Levelup"
   bitname$(3) = "Don't Restore MP on Levelup"
   bitname$(4) = "Inns Don't Revive Dead Heroes"
   bitname$(5) = "Hero Swapping Always Available"
   bitname$(6) = "Hide Ready-meter in Battle"
   bitname$(7) = "Hide Health-meter in Battle"
   bitname$(8) = "Disable Debugging Keys"
   bitname$(9) = "Simulate Old Levelup Bug"
   bitname$(10) = "Permit double-triggering of scripts"
   bitname$(11) = "Skip title screen"
   bitname$(12) = "Skip load screen"
   bitname$(13) = "Pause on All Battle Menus"
   bitname$(14) = "Disable Hero's Battle Cursor"
   editbitset general(), 101, 15, bitname$()
  END IF
  IF csr = 8 THEN generalsfxmenu
  IF csr = 10 THEN GOSUB ttlbrowse
  IF csr = 11 THEN GOSUB renrpg
  IF csr = 13 THEN generalscriptsmenu
  IF csr = 16 THEN GOSUB importmaspal
  IF csr = 9 THEN GOSUB inputpasw
 IF csr = 17 THEN
  d$ = charpicker$
  IF d$ <> "" THEN
  general(genPoison) = ASC(d$)
   GOSUB genstr
  END IF
 END IF
 IF csr = 18 THEN
  d$ = charpicker$
  IF d$ <> "" THEN
  general(genStun) = ASC(d$)
   GOSUB genstr
  END IF
 END IF
 IF csr = 19 THEN
  d$ = charpicker$
  IF d$ <> "" THEN
  general(genMute) = ASC(d$)
   GOSUB genstr
  END IF
 END IF

 END IF
 IF csr > 1 AND csr <= 4 THEN
  IF intgrabber(general(100 + csr), 0, max(csr), 75, 77) THEN GOSUB genstr
 END IF
 IF csr > 4 AND csr < 8 THEN
  IF zintgrabber(general(csr - 3), -1, max(csr), 75, 77) THEN GOSUB genstr
 END IF
 IF csr = 12 THEN
  IF intgrabber(general(96), 0, max(csr), 75, 77) THEN GOSUB genstr
 END IF
 IF csr = 14 THEN
  strgrabber longname$, 38
  GOSUB genstr
 END IF
 IF csr = 15 THEN
  strgrabber aboutline$, 38
  GOSUB genstr
 END IF
 IF csr = 17 THEN
  IF intgrabber(general(genPoison), 32, max(csr), 75, 77) THEN GOSUB genstr
 END IF
 IF csr = 18 THEN
  IF intgrabber(general(genStun), 32, max(csr), 75, 77) THEN GOSUB genstr
 END IF
 IF csr = 19 THEN
  IF intgrabber(general(genMute), 32, max(csr), 75, 77) THEN GOSUB genstr
 END IF
 IF csr = 20 THEN
  IF intgrabber(general(genDamageCap), 0, max(csr), 75, 77) THEN GOSUB genstr
 END IF
 IF csr >= 21 AND csr <= 32 THEN
  IF intgrabber(general(genStatCap + (csr - 21)), 0, max(csr), 75, 77) THEN GOSUB genstr
 END IF

 standardmenu m$(), last, 22, csr, menutop, 0, 0, dpage, 0

 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
GOSUB savepass
clearpage 0
clearpage 1
clearpage 2
clearpage 3
EXIT SUB

genstr:
'IF general(101) = 0 THEN m$(1) = "Active Menu Mode" ELSE m$(1) = "Wait Menu Mode"
m$(2) = "Starting X: " & general(102)
m$(3) = "Starting Y: " & general(103)
m$(4) = "Starting Map: " & general(104)
m$(5) = "Title Music: "
IF general(2) = 0 THEN m$(5) = m$(5) & "-none-" ELSE m$(5) = m$(5) & (general(2) - 1) & " " & getsongname$(general(2) - 1)
m$(6) = "Battle Victory Music: "
IF general(3) = 0 THEN m$(6) = m$(6) & "-none-" ELSE m$(6) = m$(6) & (general(3) - 1) & " " & getsongname$(general(3) - 1)
m$(7) = "Default Battle Music: "
IF general(4) = 0 THEN m$(7) = m$(7) & "-none-" ELSE m$(7) = m$(7) & (general(4) - 1) & " " & getsongname$(general(4) - 1)
m$(12) = "Starting Money: " & general(96)
m$(14) = "Long Name:" + longname$
m$(15) = "About Line:" + aboutline$
m$(17) = "Poison Indicator: " & general(61) & " " & CHR$(general(61))
m$(18) = "Stun Indicator: " & general(62) & " " & CHR$(general(62))
m$(19) = "Mute Indicator: " & general(genMute) & " " & CHR$(general(genMute))
m$(20) = "Damage Cap: "
if general(genDamageCap) = 0 THEN m$(20) = m$(20) + "None" ELSE m$(20) = m$(20) & general(genDamageCap)
FOR i = 0 to 11
 m$(21 + i) = stat$(i) + " Cap: "
 if general(genStatCap + i) = 0 THEN m$(21 + i) = m$(21 + i) + "None" ELSE m$(21 + i) = m$(21 + i) & general(genStatCap + i)
NEXT
RETRACE

ttlbrowse:
setdiskpages buffer(), 200, 0
GOSUB gshowpage
setkeys
DO
 setwait timing(), 100
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN RETRACE
 IF keyval(72) > 1 AND gcsr = 1 THEN gcsr = 0
 IF keyval(80) > 1 AND gcsr = 0 THEN gcsr = 1
 IF gcsr = 1 THEN
  IF intgrabber(general(1), 0, general(100) - 1, 75, 77) THEN GOSUB gshowpage
 END IF
 IF keyval(57) > 1 OR keyval(28) > 1 THEN
  IF gcsr = 0 THEN RETRACE
 END IF
 col = 7: IF gcsr = 0 THEN col = 14 + tog
 edgeprint "Go Back", 1, 1, col, dpage
 col = 7: IF gcsr = 1 THEN col = 14 + tog
 edgeprint CHR$(27) + "Browse" + CHR$(26), 1, 11, col, dpage
 SWAP vpage, dpage
 setvispage vpage
 copypage 2, dpage
 dowait
LOOP

gshowpage:
loadpage game$ + ".mxs", general(1), 2
RETRACE

loadpass:
IF general(5) >= 256 THEN
 '--new simple format
 pas$ = readpassword$
ELSE
 '--old scattertable format
 readscatter pas$, general(94), 200
 pas$ = rotascii(pas$, general(93) * -1)
END IF
IF isfile(workingdir$ + SLASH + "browse.txt") THEN
 setpicstuf buffer(), 40, -1
 loadset workingdir$ + SLASH + "browse.txt", 0, 0
 longname$ = STRING$(bound(buffer(0), 0, 38), " ")
 array2str buffer(), 2, longname$
 loadset workingdir$ + SLASH + "browse.txt", 1, 0
 aboutline$ = STRING$(bound(buffer(0), 0, 38), " ")
 array2str buffer(), 2, aboutline$
END IF
RETRACE

savepass:

newpas$ = pas$
writepassword newpas$

'--also write old scattertable format, for backwards
'-- compatability with older versions of game.exe
general(93) = INT(RND * 250) + 1
oldpas$ = rotascii(pas$, general(93))
writescatter oldpas$, general(94), 200

'--write long name and about line
setpicstuf buffer(), 40, -1
buffer(0) = bound(LEN(longname$), 0, 38)
str2array longname$, buffer(), 2
storeset workingdir$ + SLASH + "browse.txt", 0, 0
buffer(0) = bound(LEN(aboutline$), 0, 38)
str2array aboutline$, buffer(), 2
storeset workingdir$ + SLASH + "browse.txt", 1, 0
RETRACE

renrpg:
oldgame$ = RIGHT$(game$, LEN(game$) - 12)
newgame$ = oldgame$
setkeys
DO
 setwait timing(), 100
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN RETRACE
 strgrabber newgame$, 8
 fixfilename newgame$
 IF keyval(28) > 1 THEN
  IF oldgame$ <> newgame$ AND newgame$ <> "" THEN
   IF NOT isfile(newgame$ + ".rpg") THEN
    textcolor 10, 0
    printstr "Finding files...", 0, 30, vpage
    findfiles workingdir$ + SLASH + oldgame$ + ".*", 0, "temp.lst", buffer()
    fh = FREEFILE
    OPEN "temp.lst" FOR APPEND AS #fh
    PRINT #fh, "-END OF LIST-"
    CLOSE #fh
    fh = FREEFILE
    OPEN "temp.lst" FOR INPUT AS #fh
    textcolor 10, 0
    printstr "Renaming Lumps...", 0, 40, vpage
    textcolor 15, 2
    DO
     LINE INPUT #fh, temp$
     IF temp$ = "-END OF LIST-" THEN EXIT DO
     printstr " " + RIGHT$(temp$, LEN(temp$) - LEN(oldgame$)) + " ", 0, 50, vpage
     copyfile workingdir$ + SLASH + temp$, workingdir$ + SLASH + newgame$ + RIGHT$(temp$, LEN(temp$) - LEN(oldgame$)), buffer()
     KILL workingdir$ + SLASH + temp$
    LOOP
    CLOSE #fh
    safekill "temp.lst"
    '--update archinym information lump
    fh = FREEFILE
    IF isfile(workingdir$ + SLASH + "archinym.lmp") THEN
     OPEN workingdir$ + SLASH + "archinym.lmp" FOR INPUT AS #fh
     LINE INPUT #fh, oldversion$
     LINE INPUT #fh, oldversion$
     CLOSE #fh
    END IF
    OPEN workingdir$ + SLASH + "archinym.lmp" FOR OUTPUT AS #fh
    PRINT #fh, newgame$
    PRINT #fh, oldversion$
    CLOSE #fh
    game$ = workingdir$ + SLASH + newgame$
   ELSE '---IN CASE FILE EXISTS
    edgeprint newgame$ + " Already Exists. Cannot Rename.", 0, 30, 15, vpage
    w = getkey
   END IF '---END IF OKAY TO COPY
  END IF '---END IF VALID NEW ENTRY
  RETRACE
 END IF
 textcolor 7, 0
 printstr "Current Name: " + oldgame$, 0, 0, dpage
 printstr "Type New Name and press ENTER", 0, 10, dpage
 textcolor 14 + tog, 2
 printstr newgame$, 0, 20, dpage
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP

inputpasw:
setkeys
DO
 setwait timing(), 100
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 OR keyval(28) > 1 THEN EXIT DO
 strgrabber pas$, 17
 textcolor 7, 0
 printstr "You can require a password for this", 0, 0, dpage
 printstr "game to be opened in " + CUSTOMEXE, 0, 8, dpage
 printstr "This does not encrypt your file, and", 0, 16, dpage
 printstr "should only be considered weak security", 0, 24, dpage
 printstr "PASSWORD", 30, 64, dpage
 IF LEN(pas$) THEN
  textcolor 14 + tog, 1
  printstr pas$, 30, 74, dpage
 ELSE
  printstr "(NONE SET)", 30, 74, dpage
 END IF
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
RETRACE

importmaspal:

clearpage vpage
textcolor 15, 0
printstr "WARNING: Importing a new master palette", 0, 0, vpage
printstr "will change ALL of your graphics!", 48, 8, vpage
w = getkey

f$ = browse$(4, default$, "*.mas", "")
IF f$ <> "" THEN
 '--copy the new palette in
 copyfile f$, game$ + ".mas", buffer()
 '--patch the header in case it is a corrupt PalEdit header.
 masfh = FREEFILE
 OPEN game$ + ".mas" FOR BINARY AS #masfh
 a$ = CHR$(13)
 PUT #masfh, 2, a$
 a$ = CHR$(0)
 PUT #masfh, 6, a$
 CLOSE #masfh
 '--load the new palette!
 xbload game$ + ".mas", master(), "MAS load error"
 setpal master()
END IF

RETRACE

END SUB

SUB generalscriptsmenu ()
DIM menu$(3), scrname$(3)
DIM scriptgenoff(3) = {0, 41, 42, 57}
menu$(0) = "Previous Menu"
menu$(1) = "new-game plotscript"
menu$(2) = "game-over plotscript"
menu$(3) = "load-game plotscript"
scrname$(0) = ""
FOR i = 1 TO 3
 scrname$(i) = ": " + scriptname$(general(scriptgenoff(i)), plottrigger)
NEXT

pt = 0
menusize = 3
setkeys
DO
 tog = tog XOR 1
 setwait timing(), 100
 setkeys
 IF keyval(1) > 1 THEN EXIT DO
 dummy = usemenu(pt, 0, 0, menusize, 24)
 IF pt = 0 THEN
  IF keyval(57) > 1 OR keyval(28) > 1 THEN EXIT DO
 ELSE
  IF keyval(57) > 1 OR keyval(28) > 1 THEN
   scrname$(pt) = ": " + scriptbrowse$(general(scriptgenoff(pt)), plottrigger, menu$(pt))
  ELSEIF scrintgrabber(general(scriptgenoff(pt)), 0, 0, 75, 77, 1, plottrigger) THEN
   scrname$(pt) = ": " + scriptname$(general(scriptgenoff(pt)), plottrigger)
  END IF
 END IF
 FOR i = 0 TO menusize
  IF pt = i THEN textcolor 14 + tog, 0 ELSE textcolor 7, 0
  printstr menu$(i) + scrname$(i), 0, i * 8, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
END SUB

SUB generalsfxmenu ()
  CONST num as integer = 3
  DIM as string menu(num), snd(num), disp(num)
  DIM as integer sfxgenoff(1 to num) = {genAcceptSFX, genCancelSFX, genCursorSFX}, menutop

  disp(0) = "Previous Menu" 'don't need menu(0)
  menu(1) = "Accept Sound: "
  menu(2) = "Cancel Sound: "
  menu(3) = "Cursor Sound: "

  FOR i = 1 to num
    IF general(sfxgenoff(i)) > 0 THEN
      disp(i) = menu(i) & general(sfxgenoff(i)) & " - " & getsongname(general(sfxgenoff(i)))
    ELSE
      disp(i) = menu(i) & "None"
    END IF
  NEXT
  pt = 0
  menusize = num
  setkeys
  DO
    tog = tog XOR 1
    setwait timing(), 100
    setkeys
    accept = keyval(57) > 1 OR keyval(28) > 1
    cancel = keyval(1) > 1

    IF cancel THEN EXIT DO
    usemenu pt, 0, 0, menusize, 24

    SELECT CASE AS CONST pt
    CASE 0
      IF accept THEN EXIT DO
    CASE 1 TO num
      IF intgrabber(general(sfxgenoff(pt)), 0, general(genMaxSFX)+1, 75, 77) THEN
        IF general(sfxgenoff(pt)) > 0 THEN
          disp(pt) = menu(pt) & (general(sfxgenoff(pt))-1) & " " & getsfxname(general(sfxgenoff(pt))-1)
        ELSE
          disp(pt) = menu(pt) & "None"
        END IF
      END IF
    END SELECT

    standardmenu disp(), num, 22, pt, menutop, 0, 0, dpage, 0

    'printstr str(general(genMaxSFX)), 0, 100, dpage

    SWAP vpage, dpage
    setvispage vpage
    clearpage dpage
    dowait
  LOOP
END SUB

SUB importsong ()
STATIC default$
setupmusic
setfmvol getfmvol
clearpage 0
clearpage 1
clearpage 2
clearpage 3
DIM menu$(10), submenu$(2)
menu$(0) = "Previous Menu"
menu$(3) = "Import Song..."
menu$(4) = "Export Song..."
menu$(5) = "Delete Song"

csr = 1
snum = 0
sname$ = ""
songfile$ = ""
bamfile$ = ""
optionsbottom = 0
GOSUB getsonginfo

setkeys
DO
 setwait timing(), 100
 setkeys
 IF keyval(1) > 1 THEN EXIT DO

 dummy = usemenu(csr, 0, 0, optionsbottom, 22)

 IF csr = 2 AND songfile$ <> "" THEN
  strgrabber sname$, 30
  menu$(2) = "Name: " + sname$
 ELSE
  '-- check for switching song
  newsong = snum
  IF intgrabber(newsong, 0, general(genMaxSong), 51, 52) THEN
   GOSUB ssongdata
   snum = newsong
   GOSUB getsonginfo
  END IF
  IF keyval(75) > 1 AND snum > 0 THEN
   GOSUB ssongdata
   snum = snum - 1
   GOSUB getsonginfo
  END IF
  IF keyval(77) > 1 AND snum < 32767 THEN
   GOSUB ssongdata
   snum = snum + 1
   IF needaddset(snum, general(genMaxSong), "song") THEN sname$ = ""
   GOSUB getsonginfo
  END IF
 END IF
 IF (keyval(28) > 1 OR keyval(57) > 1) THEN
  IF csr = 0 THEN EXIT DO
  IF csr = 3 THEN GOSUB importsongfile
  IF csr = 4 AND songfile$ <> "" THEN GOSUB exportsong
  IF csr = 5 AND songfile$ <> "" THEN  'delete song
   safekill songfile$
   safekill bamfile$
   GOSUB getsonginfo
  END IF
  IF csr = 6 THEN  'delete BAM fallback
   safekill bamfile$
   GOSUB getsonginfo
   csr = 0
  END IF
 END IF

 standardmenu menu$(), 10, 22, csr, 0, 0, 0, dpage, 0

 SWAP vpage, dpage
 setvispage vpage
 copypage 2, dpage
 dowait
LOOP
GOSUB ssongdata
clearpage 0
clearpage 1
clearpage 2
clearpage 3
stopsong
closemusic

EXIT SUB

getsonginfo:
stopsong

'-- first job: find the song's name
temp$ = workingdir$ + SLASH + "song" + STR$(snum)
songfile$ = ""
songtype$ = "NO FILE"
'-- BAM special case and least desirable, so check first and override
IF snum > 99 THEN
 IF isfile(temp$ + ".bam") THEN ext$ = ".bam" : songfile$ = temp$ + ext$ : songtype$ = "Bob's Adlib Music (BAM)"
ELSE
 IF isfile(game$ + "." + STR$(snum)) THEN ext$ = ".bam" : songfile$ = game$ + "." + STR$(snum) : songtype$ = "Bob's Adlib Music (BAM)"
END IF
bamfile$ = songfile$
IF isfile(temp$ + ".mid") THEN
  ext$ = ".mid"
  songfile$ = temp$ + ext$
  songtype$ = "MIDI Music (MID)"
ELSEIF isfile(temp$ + ".ogg") THEN
 ext$ = ".ogg"
 songfile$ = temp$ + ext$
 songtype$ = "OGG Vorbis (OGG)"
ELSEIF isfile(temp$ + ".mp3") THEN
 ext$ = ".mp3"
 songfile$ = temp$ + ext$
 songtype$ = "MPEG Layer III (MP3)"
ELSEIF isfile(temp$ + ".s3m") THEN
 ext$ = ".s3m"
 songfile$ = temp$ + ext$
 songtype$ = "S3 Module (S3M)" 'fixme
ELSEIF isfile(temp$ + ".it") THEN
 ext$ = ".it"
 songfile$ = temp$ + ext$
 songtype$ = "Impulse Tracker (IT)"
ELSEIF isfile(temp$ + ".xm") THEN
 ext$ = ".xm"
 songfile$ = temp$ + ext$
 songtype$ = "Extended Module (XM)"
ELSEIF isfile(temp$ + ".mod") THEN
 ext$ = ".mod"
 songfile$ = temp$ + ext$
 songtype$ = "Module (MOD)"
END IF
'--add more formats here

sname$ = getsongname$(snum)

IF songfile$ <> "" THEN '--song exists
 loadsong songfile$
ELSE
 sname$ = ""
END IF

menu$(1) = "<- Song " + STR$(snum) + " of " + STR$(general(genMaxSong)) + " ->"
IF songfile$ <> "" THEN menu$(2) = "Name: " + sname$ ELSE menu$(2) = "-Unused-"
menu$(7) = ""
menu$(8) = "Type: " + songtype$
menu$(9) = "Filesize: " + filesize$(songfile$)
IF bamfile$ <> songfile$ AND bamfile$ <> "" THEN
 menu$(10) = "BAM fallback exists. Filesize: " + filesize$(bamfile$)
 menu$(6) = "Delete BAM fallback"
 optionsbottom = 6
ELSE
 menu$(10) = ""
 menu$(6) = ""
 optionsbottom = 5
END IF
'-- add author, length, etc, info here
RETRACE

importsongfile:
stopsong
'sourcesong$ = browse$(1, default$, "*.bam", "")
sourcesong$ = browse$(5, default$, "", "")
IF sourcesong$ = "" THEN
 GOSUB getsonginfo 'to play the song again
 RETRACE
END IF
'--remove song file (except BAM, we can leave those as fallback for QB version)
IF songfile$ <> bamfile$ THEN safekill songfile$

IF sourcesong$ <> "" THEN
 IF LCASE$(RIGHT$(sourcesong$, 4)) = ".bam" AND snum <= 99 THEN
  songfile$ = game$ + "." + STR$(snum)
 ELSE
  songfile$ = workingdir$ + SLASH + "song" + STR$(snum) + "." + justextension$(sourcesong$)
 END IF
 copyfile sourcesong$, songfile$, buffer()
 a$ = trimextension$(trimpath$(sourcesong$))
 sname$ = a$
 GOSUB ssongdata
END IF
GOSUB getsonginfo
RETRACE

exportsong:
query$ = "Name of file to export to?"
IF bamfile$ <> songfile$ AND bamfile$ <> "" THEN
 submenu$(0) = "Export " + ext$ + " file"
 submenu$(1) = "Export .bam fallback file"
 submenu$(2) = "Cancel"
 choice = sublist(2, submenu$())
 IF choice = 1 THEN ext$ = ".bam" : songfile$ = bamfile$
 IF choice = 2 THEN RETRACE
END IF
outfile$ = inputfilename$(query$, ext$)
IF outfile$ = "" THEN RETRACE
copyfile songfile$, outfile$ + ext$, buffer()
RETRACE

ssongdata:
flusharray buffer(), curbinsize(2) / 2, 0
setpicstuf buffer(), curbinsize(2), -1
writebinstring sname$, buffer(), 0, 30
storeset workingdir$ + SLASH + "songdata.bin", snum, 0
RETRACE

END SUB


SUB importsfx ()
STATIC default$
setupsound
clearpage 0
clearpage 1
clearpage 2
clearpage 3
DIM menu$(11), submenu$(2), optionsbottom
optionsbottom = 7
menu$(0) = "Previous Menu"
menu$(3) = "Import Wave..."
menu$(4) = "Export Wave..."
menu$(5) = "Delete Wave"
menu$(6) = "Play Wave"
menu$(7) = "Streaming"

csr = 1
snum = 0
sname$ = ""
sfxfile$ = ""
GOSUB getsfxinfo

setkeys
DO
 setwait timing(), 100
 setkeys
 IF keyval(1) > 1 THEN EXIT DO

 dummy = usemenu(csr, 0, 0, optionsbottom, 22)

 IF csr = 2 AND sfxfile$ <> "" THEN
  strgrabber sname$, 30
  menu$(2) = "Name: " + sname$
 ELSE
  '-- check for switching sfx
  newsfx = snum
  IF intgrabber(newsfx, 0, general(genMaxSFX), 51, 52) THEN
   GOSUB ssfxdata
   snum = newsfx
   GOSUB getsfxinfo
  END IF
  IF keyval(75) > 1 AND snum > 0 THEN
   GOSUB ssfxdata
   snum = snum - 1
   GOSUB getsfxinfo
  END IF
  IF keyval(77) > 1 AND snum < 32767 THEN
   GOSUB ssfxdata
   snum = snum + 1
   IF needaddset(snum, general(genMaxSFX), "sfx") THEN sname$ = ""
   GOSUB getsfxinfo
  END IF
 END IF
 IF (keyval(28) > 1 OR keyval(57) > 1) THEN
  SELECT CASE csr
  CASE 0
    EXIT DO
  CASE 3
    GOSUB importsfxfile
  CASE 4
    IF sfxfile$ <> "" THEN GOSUB exportsfx
  CASE 5
    IF sfxfile$ <> "" THEN  'delete sfx
      safekill sfxfile$
      GOSUB getsfxinfo
    END IF
  CASE 6
    IF sfxfile$ <> "" THEN 'play sfx
      playsfx snum, 0
    END IF
  CASE 7

  END SELECT


 END IF

 standardmenu menu$(), 10, 22, csr, 0, 0, 0, dpage, 0

 SWAP vpage, dpage
 setvispage vpage
 copypage 2, dpage
 dowait
LOOP
GOSUB ssfxdata
clearpage 0
clearpage 1
clearpage 2
clearpage 3
closesound

EXIT SUB

getsfxinfo:
'-- first job: find the sfx's name
temp$ = workingdir$ + SLASH + "sfx" + STR$(snum)
sfxfile$ = ""
sfxtype$ = "NO FILE"

IF isfile(temp$ + ".wav") THEN
 ext$ = ".wav"
 sfxfile$ = temp$ + ext$
 sfxtype$ = "Waveform (WAV)"
ELSEIF isfile(temp$ + ".ogg") THEN
 ext$ = ".ogg"
 sfxfile$ = temp$ + ext$
 sfxtype$ = "OGG Vorbis (OGG)"
ELSEIF isfile(temp$ + ".mp3") THEN
 ext$ = ".mp3"
 sfxfile$ = temp$ + ext$
 sfxtype$ = "MPEG Layer III (MP3)"
ELSEIF isfile(temp$ + ".s3m") THEN 'N/A for sound effects
 ext$ = ".s3m"
 sfxfile$ = temp$ + ext$
 sfxtype$ = "A MOD Format (S3M)" 'fixme
ELSEIF isfile(temp$ + ".it") THEN
 ext$ = ".it"
 sfxfile$ = temp$ + ext$
 sfxtype$ = "Impulse Tracker (IT)"
ELSEIF isfile(temp$ + ".xm") THEN
 ext$ = ".xm"
 sfxfile$ = temp$ + ext$
 sfxtype$ = "A MOD format (XM)"
ELSEIF isfile(temp$ + ".mod") THEN
 ext$ = ".mod"
 sfxfile$ = temp$ + ext$
 sfxtype$ = "Module (MOD)"
END IF

'--add more formats here

if sfxfile$ <> "" then
 'playsfx snum, 0
 setpicstuf buffer(), curbinsize(3), -1
 loadset workingdir$ + SLASH + "sfxdata.bin", snum, 0
 sname$ = readbinstring(buffer(), 0, 30)
ELSE '--sfx doesn't exist
 sname$ = ""
END IF

menu$(1) = "<- SFX " + STR$(snum) + " of " + STR$(general(genMaxSFX)) + " ->"
IF sfxfile$ <> "" THEN menu$(2) = "Name: " + sname$ ELSE menu$(2) = "-Unused-"
menu$(8) = ""
menu$(9) = "Type: " + sfxtype$
menu$(10) = "Filesize: " + filesize$(sfxfile$)

'-- add author, length, etc, info here
RETRACE

importsfxfile:

sourcesfx$ = browse$(6, "", "", "")
IF sourcesfx$ = "" THEN
 RETRACE
END IF

safekill sfxfile$

IF sourcesfx$ <> "" THEN
 sfxfile$ = workingdir$ + SLASH + "sfx" + STR$(snum) + "." + justextension$(sourcesfx$)
 copyfile sourcesfx$, sfxfile$, buffer()
 a$ = trimextension$(trimpath$(sourcesfx$))
 sname$ = a$
 GOSUB ssfxdata
 freesfx snum
END IF
GOSUB getsfxinfo
RETRACE

exportsfx:
query$ = "Name of file to export to?"
outfile$ = inputfilename$(query$, ext$)
IF outfile$ = "" THEN RETRACE
copyfile sfxfile$, outfile$ + ext$, buffer()
RETRACE

ssfxdata:
stopsfx snum
flusharray buffer(), curbinsize(3) / 2, 0
setpicstuf buffer(), curbinsize(3), -1
writebinstring sname$, buffer(), 0, 30
storeset workingdir$ + SLASH + "sfxdata.bin", snum, 0
RETRACE

END SUB

FUNCTION scriptbrowse$ (trigger, triggertype, scrtype$)
DIM localbuf(20)
REDIM scriptnames$(0), scriptids(0)
numberedlast = 0

temp$ = scriptname(trigger, triggertype)
IF temp$ <> "[none]" AND LEFT$(temp$, 1) = "[" THEN firstscript = 2 ELSE firstscript = 1

IF triggertype = 1 THEN
 'plotscripts
 fh = FREEFILE
 OPEN workingdir$ + SLASH + "plotscr.lst" FOR BINARY AS #fh
 'numberedlast = firstscript + LOF(fh) \ 40 - 1
 numberedlast = firstscript + general(40) - 1

 REDIM scriptnames$(numberedlast), scriptids(numberedlast)

 i = firstscript
 FOR j = firstscript TO numberedlast
  loadrecord localbuf(), fh, 40
  IF localbuf(0) < 16384 THEN
   scriptids(i) = localbuf(0)
   scriptnames$(i) = STR$(localbuf(0)) + " " + readbinstring(localbuf(), 1, 36)
   i += 1
  END IF
 NEXT
 numberedlast = i - 1

 CLOSE #fh
END IF

fh = FREEFILE
OPEN workingdir$ + SLASH + "lookup" + STR$(triggertype) + ".bin" FOR BINARY AS #fh
scriptmax = numberedlast + LOF(fh) \ 40

IF scriptmax < firstscript THEN
 scriptbrowse$ = "[no scripts]"
 EXIT FUNCTION
END IF

' 0 to firstscript - 1 are special options (none, current script)
' firstscript to numberedlast are oldstyle numbered scripts
' numberedlast + 1 to scriptmax are newstyle trigger scripts
REDIM PRESERVE scriptnames$(scriptmax), scriptids(scriptmax)
scriptnames$(0) = "[none]"
scriptids(0) = 0
IF firstscript = 2 THEN
 scriptnames$(1) = temp$
 scriptids(1) = trigger
END IF

FOR i = numberedlast + 1 TO scriptmax
 loadrecord localbuf(), fh, 40
 scriptids(i) = 16384 + i - (numberedlast + 1)
 scriptnames$(i) = readbinstring(localbuf(), 1, 36)
NEXT

CLOSE #fh

'insertion sort numbered scripts by id
FOR i = firstscript + 1 TO numberedlast
 FOR j = i - 1 TO firstscript STEP -1
  IF scriptids(j + 1) < scriptids(j) THEN
   SWAP scriptids(j + 1), scriptids(j)
   SWAP scriptnames$(j + 1), scriptnames$(j)
  ELSE
   EXIT FOR
  END IF
 NEXT
NEXT

'sort trigger scripts by name
FOR i = numberedlast + 1 TO scriptmax - 1
 FOR j = scriptmax TO i + 1 STEP -1
  FOR k = 0 TO small(LEN(scriptnames$(i)), LEN(scriptnames$(j)))
   chara = ASC(LCASE$(CHR$(scriptnames$(i)[k])))
   charb = ASC(LCASE$(CHR$(scriptnames$(j)[k])))
   IF chara < charb THEN
    EXIT FOR
   ELSEIF chara > charb THEN
    SWAP scriptids(i), scriptids(j)
    SWAP scriptnames$(i), scriptnames$(j)
    EXIT FOR
   END IF
  NEXT
 NEXT i
NEXT o

pt = 0
IF firstscript = 2 THEN
 pt = 1
ELSE
 FOR i = 1 TO scriptmax
  IF trigger = scriptids(i) THEN pt = i: EXIT FOR
 NEXT
END IF
top = large(0, small(pt - 10, scriptmax - 21))
id = scriptids(pt)
iddisplay = 0
clearpage 0
clearpage 1
setkeys
DO
 setwait timing(), 90
 setkeys
 IF keyval(1) > 1 THEN
  scriptbrowse$ = temp$
  EXIT FUNCTION
 END IF
 IF keyval(57) > 1 OR keyval(28) > 1 THEN EXIT DO
 IF scriptids(pt) < 16384 THEN
  IF intgrabber(id, 0, 16383, 75, 77) THEN
   iddisplay = -1
   FOR i = 0 TO numberedlast
    IF id = scriptids(i) THEN pt = i
   NEXT
  END IF
 END IF
 IF usemenu(pt, top, 0, scriptmax, 21) THEN
  IF scriptids(pt) < 16384 THEN id = scriptids(pt) ELSE id = 0: iddisplay = 0
 END IF
 FOR i = 2 TO 53
  IF keyval(i) > 1 AND keyv(i, 0) > 0 THEN
   j = pt + 1
   FOR ctr = numberedlast + 1 TO scriptmax
    IF j > scriptmax THEN j = numberedlast + 1
    tempstr$ = LCASE$(scriptnames$(j))
    IF tempstr$[0] = keyv(i, 0) THEN pt = j: EXIT FOR
    j += 1
   NEXT
   EXIT FOR
  END IF
 NEXT i

 textcolor 7, 0
 printstr "Pick a " + scrtype$, 0, 0, dpage
 standardmenu scriptnames$(), scriptmax, 21, pt, top, 8, 10, dpage, 0
 IF iddisplay THEN
  textcolor 7, 1
  printstr STR$(id), 8, 190, dpage
 END IF

 SWAP dpage, vpage
 setvispage vpage
 clearpage dpage
 dowait
LOOP
clearpage 0
clearpage 1

IF scriptids(pt) < 16384 THEN
 scriptbrowse$ = MID$(scriptnames$(pt), INSTR(scriptnames$(pt), " ") + 1)
ELSE
 scriptbrowse$ = scriptnames$(pt)
END IF
trigger = scriptids(pt)

END FUNCTION
