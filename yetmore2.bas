'OHRRPGCE GAME - Even more various unsorted routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
'$DYNAMIC
DEFINT A-Z

#include "compat.bi"
#include "allmodex.bi"
#include "common.bi"
#include "gglobals.bi"
#include "const.bi"
#include "scrconst.bi"
#include "uiconst.bi"
#include "loading.bi"

#include "game.bi"
#include "yetmore.bi"
#include "yetmore2.bi"
#include "moresubs.bi"
#include "bmodsubs.bi"

REM $STATIC

SUB cathero
'NOTE: zsort contains positions in CATERPILLAR party
DIM zsort(3)

'--if riding a vehicle and not mounting and not hiding leader and not hiding party then exit
IF vstate.active = YES AND vstate.mounting = NO AND vstate.trigger_cleanup = NO AND vstate.ahead = NO AND vstate.dat.do_not_hide_leader = NO AND vstate.dat.do_not_hide_party = NO THEN EXIT SUB

IF readbit(gen(), 101, 1) = 1 AND (vstate.active = NO OR vstate.dat.do_not_hide_leader = NO) THEN
 '--caterpillar party (normal)
 '--this should Y-sort
 catlen = 0
 FOR i = 0 TO 3
  IF hero(i) > 0 THEN
   zsort(catlen) = catlen
   catlen += 1
  END IF
 NEXT
 FOR i = 0 TO catlen - 2
  FOR o = i + 1 TO catlen - 1
   IF caty(zsort(o) * 5) < caty(zsort(i) * 5) THEN
    SWAP zsort(i), zsort(o)
   END IF
  NEXT
 NEXT
 FOR i = 0 TO catlen - 1
  IF framewalkabout(catx(zsort(i) * 5), caty(zsort(i) * 5) + gmap(11), framex, framey, mapsizetiles.x * 20, mapsizetiles.y * 20, gmap(5)) THEN
   IF herow(zsort(i)).sprite = NULL THEN fatalerror "cathero: hero sprite " & zsort(i) & " missing!"
   frame_draw herow(zsort(i)).sprite + catd(zsort(i) * 5) * 2 + (wtog(zsort(i)) \ 2), herow(zsort(i)).pal, framex, framey - catz(zsort(i) * 5), 1, -1, dpage
  END IF
 NEXT i
ELSE
 '--non-caterpillar party, vehicle no-hide-leader (or backcompat pref)
 IF framewalkabout(catx(0), caty(0) + gmap(11), framex, framey, mapsizetiles.x * 20, mapsizetiles.y * 20, gmap(5)) THEN
  IF herow(0).sprite = NULL THEN fatalerror "cathero: hero sprite missing!"
  frame_draw herow(0).sprite + catd(0) * 2 + (wtog(0) \ 2), herow(0).pal, framex, framey - catz(0), 1, -1, dpage
 END IF
END IF
END SUB

FUNCTION cropmovement (x as integer, y as integer, xgo as integer, ygo as integer) as integer
 'crops movement at edge of map, or wraps
 'returns true if ran into wall at edge
 cropmovement = 0
 IF gmap(5) = 1 THEN
  '--wrap walking
  IF x < 0 THEN x = x + mapsizetiles.x * 20
  IF x >= mapsizetiles.x * 20 THEN x = x - mapsizetiles.x * 20
  IF y < 0 THEN y = y + mapsizetiles.y * 20
  IF y >= mapsizetiles.y * 20 THEN y = y - mapsizetiles.y * 20
 ELSE
  '--crop walking
  IF x < 0 THEN x = 0: xgo = 0: cropmovement = 1
  IF x > (mapsizetiles.x - 1) * 20 THEN x = (mapsizetiles.x - 1) * 20: xgo = 0: cropmovement = 1
  IF y < 0 THEN y = 0: ygo = 0: cropmovement = 1
  IF y > (mapsizetiles.y - 1) * 20 THEN y = (mapsizetiles.y - 1) * 20: ygo = 0: cropmovement = 1
 END IF
END FUNCTION

SUB defaultc
 DIM cconst(12) = {72,80,75,77,57,28,29,1,56,1,15,36,51}
 DIM joyconst(3) = {150,650,150,650}

 FOR i = 0 TO 12
  csetup(i) = cconst(i)
 NEXT i
 FOR i = 9 TO 12
  joy(i) = joyconst(i - 9)
 NEXT i
 EXIT SUB
END SUB

SUB drawnpcs
 FOR i = 0 TO 299 '-- for each NPC instance
  IF npc(i).id > 0 THEN '-- if visible
   o = npc(i).id - 1
   z = 0
   drawnpcX = 0
   drawnpcY = 0
   IF framewalkabout(npc(i).x, npc(i).y + gmap(11), drawnpcX, drawnpcY, mapsizetiles.x * 20, mapsizetiles.y * 20, gmap(5)) THEN
    IF vstate.active AND vstate.npc = i THEN z = catz(0) '--special vehicle magic
    IF z AND vstate.dat.disable_flying_shadow = NO THEN '--shadow
     rectangle npc(i).x - mapx + 6, npc(i).y - mapy + gmap(11) + 13, 8, 5, uilook(uiShadow), dpage
     rectangle npc(i).x - mapx + 5, npc(i).y - mapy + gmap(11) + 14, 10, 3, uilook(uiShadow), dpage
    END IF
    frame_draw npcs(o).sprite + (2 * npc(i).dir) + npc(i).frame \ 2, npcs(o).pal, drawnpcX, drawnpcY - z, 1, -1, dpage
   END IF
  END IF
 NEXT i
END SUB

SUB forcedismount (catd())
IF vstate.active THEN
 '--clear vehicle on loading new map--
 IF vstate.dat.dismount_ahead = YES AND vstate.dat.pass_walls_while_dismounting = NO THEN
  '--dismount-ahead is true, dismount-passwalls is false
  SELECT CASE catd(0)
   CASE 0
    ygo(0) = 20
   CASE 1
    xgo(0) = -20
   CASE 2
    ygo(0) = -20
   CASE 3
    xgo(0) = 20
  END SELECT
 END IF
 IF vstate.dat.on_dismount > 0 THEN
  loadsay vstate.dat.on_dismount
 END IF
 IF vstate.dat.on_dismount < 0 THEN
  rsr = runscript(ABS(vstate.dat.on_dismount), nowscript + 1, -1, "dismount", plottrigger)
 END IF
 IF vstate.dat.riding_tag > 1 THEN setbit tag(), 0, vstate.dat.riding_tag, 0
 herospeed(0) = vstate.old_speed
 IF herospeed(0) = 3 THEN herospeed(0) = 10
 reset_vehicle vstate
 FOR i = 1 TO 15
  catx(i) = catx(0)
  caty(i) = caty(0)
 NEXT i
 gam.random_battle_countdown = range(100, 60)
END IF
END SUB

'called on each coordinate of a screen position to wrap it around the map so that's it's as close as possible to being on the screen
FUNCTION closestwrappedpos (coord as integer, screenlen as integer, maplen as integer) as integer
 'consider two possibilities: one negative but as large as possible; and the one after that
 DIM as integer lowposs, highposs
 lowposs = (coord MOD maplen) + 10 'center of tile
 IF lowposs >= 0 THEN lowposs -= maplen
 highposs = lowposs + maplen

 'now evaluate which of lowposs or highposs are in or closer to the interval [0, screenlen]
 IF highposs - screenlen < 0 - lowposs THEN RETURN highposs - 10
 RETURN lowposs - 10
END FUNCTION

FUNCTION framewalkabout (x as integer, y as integer, framex as integer, framey as integer, mapwide as integer, maphigh as integer, wrapmode as integer) as integer
'Given an X and a Y returns true if a walkabout at that spot might be on-screen.
'We always return true because with offset variable sized frames and slices
'attached to NPCs, it's practically impossible to tell.
'Also checks wraparound map, and sets framex and framey
'to the position on screen most likely to be the best place to 
'draw the walkabout (closest to the screen edge). (relative to the top-left
'corner of the screen, not the top left corner of the map)
'TODO: improve by taking into account frame offset once that's implemented.

 IF wrapmode = 1 THEN
  framex = closestwrappedpos(x - mapx, vpages(dpage)->w, mapwide)
  framey = closestwrappedpos(y - mapy, vpages(dpage)->h, maphigh)
 ELSE
  framex = x - mapx
  framey = y - mapy
 END IF
 RETURN YES
END FUNCTION

SUB initgamedefaults

lastsaveslot = 0

'--items
CleanInventory inventory()

'--money
gold = gen(genStartMoney)

'--hero's speed
FOR i = 0 TO 3
 herospeed(i) = 4
NEXT i

'--hero's position
FOR i = 0 TO 15
 catx(i) = gen(genStartX) * 20
 caty(i) = gen(genStartY) * 20
 catd(i) = 2
NEXT i

END SUB

SUB innRestore ()

FOR i = 0 TO 3
 IF hero(i) > 0 THEN '--hero exists
  IF gam.hero(i).stat.cur.hp <= 0 AND readbit(gen(), 101, 4) THEN
   '--hero is dead and inn-revive is disabled
  ELSE
   '--normal revive
   gam.hero(i).stat.cur.hp = gam.hero(i).stat.max.hp
   gam.hero(i).stat.cur.mp = gam.hero(i).stat.max.mp
   resetlmp i, gam.hero(i).lev
  END IF
 END IF
NEXT i

END SUB

SUB setmapxy
SELECT CASE gen(cameramode)
 CASE herocam
  mapx = catx(gen(cameraArg)) - (vpages(dpage)->w \ 2 - 10)
  mapy = caty(gen(cameraArg)) - (vpages(dpage)->h \ 2 - 10)
 CASE npccam
  mapx = npc(gen(cameraArg)).x - (vpages(dpage)->w \ 2 - 10)
  mapy = npc(gen(cameraArg)).y - (vpages(dpage)->h \ 2 - 10)
 CASE pancam ' 1=dir, 2=ticks, 3=step
  IF gen(cameraArg2) > 0 THEN
   aheadxy mapx, mapy, gen(cameraArg), gen(cameraArg3)
   gen(cameraArg2) -= 1
  END IF
  IF gen(cameraArg2) <= 0 THEN gen(cameramode) = stopcam
 CASE focuscam ' 1=x, 2=y, 3=x step, 4=y step
  temp = gen(cameraArg) - mapx
  IF ABS(temp) <= gen(cameraArg3) THEN
   gen(cameraArg3) = 0
   mapx = gen(cameraArg)
  ELSE
   mapx += SGN(temp) * gen(cameraArg3)
  END IF
  temp = gen(cameraArg2) - mapy
  IF ABS(temp) <= gen(cameraArg4) THEN
   gen(cameraArg4) = 0
   mapy = gen(cameraArg2)
  ELSE
   mapy += SGN(temp) * gen(cameraArg4)
  END IF
  limitcamera mapx, mapy
  IF gen(cameraArg3) = 0 AND gen(cameraArg4) = 0 THEN gen(cameramode) = stopcam
END SELECT
limitcamera mapx, mapy
END SUB

SUB showplotstrings

FOR i = 0 TO 31
 '-- for each string
 IF plotstr(i).bits AND 1 THEN
  '-- only display visible strings
  IF plotstr(i).bits AND 2 THEN
    '-- flat text
    textcolor plotstr(i).Col, plotstr(i).BGCol
    printstr plotstr(i).s, plotstr(i).X, plotstr(i).Y, dpage
  ELSE
    '-- with outline
    edgeprint plotstr(i).s, plotstr(i).X, plotstr(i).Y, plotstr(i).Col, dpage
  END IF
 END IF
NEXT i

END SUB

FUNCTION strgrabber (s$, maxl) AS INTEGER
DIM old AS STRING
old = s$

'--BACKSPACE support
IF keyval(scBackspace) > 1 AND LEN(s$) > 0 THEN s$ = LEFT$(s$, LEN(s$) - 1)

'--SHIFT support
shift = 0
IF keyval(scRightShift) > 0 OR keyval(scLeftShift) > 0 THEN shift = 1

'--adding chars
IF LEN(s$) < maxl THEN

 '--SPACE support
 IF keyval(scSpace) > 1 THEN
   s$ = s$ + " "
 ELSE
  '--all other keys
  FOR i = 2 TO 53
   IF keyval(i) > 1 AND keyv(i, shift) > 0 THEN
    s$ = s$ + CHR$(keyv(i, shift))
    EXIT FOR
   END IF
  NEXT i
 END IF

END IF

'Return true of the string has changed
RETURN (s$ <> old)

END FUNCTION

SUB makebackups
 'what is this for? Since some lumps can be modified at run time, we need to keep a
 'backup copy, and then only edit the copy. The original is never used directly.
 'enemy data
 filecopy game + ".dt1", tmpdir & "dt1.tmp"
 'formation data
 filecopy game + ".for", tmpdir & "for.tmp"
 'if you add lump-modding commands, you better well add them here >:(
END SUB

SUB correctbackdrop

IF gen(genTextboxBackdrop) THEN
 '--restore text box backdrop
 loadmxs game + ".mxs", gen(genTextboxBackdrop) - 1, vpages(3)
 EXIT SUB
END IF

IF gen(genScrBackdrop) THEN
 '--restore script backdrop
 loadmxs game + ".mxs", gen(genScrBackdrop) - 1, vpages(3)
 EXIT SUB
END IF

'loadmxs game + ".til", gmap(0), vpages(3)

END SUB

SUB cleanuptemp
 findfiles workingdir + SLASH + ALLFILES, 0, tmpdir + "filelist.tmp"
 fh = FREEFILE
  OPEN tmpdir + "filelist.tmp" FOR INPUT AS #fh
  DO UNTIL EOF(fh)
   LINE INPUT #fh, filename$
   IF usepreunlump = 0 THEN
    'normally delete everything
    KILL workingdir + SLASH + filename$
   ELSE
    'but for preunlumped games only delete specific files
    ext$ = justextension$(filename$)
    IF ext$ = "tmp" OR ext$ = "bmd" THEN
     KILL workingdir + SLASH + filename$
    END IF
   END IF
  LOOP
  CLOSE #fh

  KILL tmpdir + "filelist.tmp"

  findfiles tmpdir + ALLFILES, 0, tmpdir + "filelist.tmp"
  fh = FREEFILE
  OPEN tmpdir + "filelist.tmp" FOR INPUT AS #fh
  DO UNTIL EOF(fh)
   LINE INPUT #fh, filename$
   IF filename$ = "filelist.tmp" THEN CONTINUE DO ' skip this, deal with it later
   IF NOT isdir(tmpdir & filename$) THEN
    KILL tmpdir & filename$
   END IF
  LOOP
  CLOSE #fh

  KILL tmpdir + "filelist.tmp"
END SUB

FUNCTION checkfordeath () as integer
checkfordeath = 0' --default alive

o = 0
FOR i = 0 TO 3 '--for each slot
 IF hero(i) > 0 THEN '--if hero exists
  o = o + 1
  IF gam.hero(i).stat.cur.hp <= 0 AND gam.hero(i).stat.max.hp > 0 THEN o = o - 1
 END IF
NEXT i
IF o = 0 THEN checkfordeath = 1

END FUNCTION

SUB aheadxy (x, y, direction, distance)
'--alters the input X and Y, moving them "ahead" by distance in direction

IF direction = 0 THEN y = y - distance
IF direction = 1 THEN x = x + distance
IF direction = 2 THEN y = y + distance
IF direction = 3 THEN x = x - distance

END SUB

SUB exitprogram (needfade)

'DEBUG debug "Exiting Program"
'DEBUG debug "fade screen"
IF needfade THEN fadeout 0, 0, 0

'DEBUG debug "Cleanup Routine"
'--open files
'DEBUG debug "Close foemap handle"
CLOSE #foemaph

'--script stack
'DEBUG debug "Release script stack"
releasestack
destroystack(scrst)

'--reset audio
closemusic
'DEBUG debug "Restore original FM volume"

'--working files
'DEBUG debug "Kill working files"
cleanuptemp
RMDIR tmpdir + "playing.tmp"
RMDIR tmpdir
'DEBUG debug "Remove working directory"
IF usepreunlump = 0 THEN RMDIR workingdir

'DEBUG debug "Restore Old Graphics Mode"
restoremode
'DEBUG debug "Terminate NOW (boom!)"
end_debug
END

END SUB

SUB keyboardsetup
'There is a different implementation of this in customsubs for CUSTOM
DIM keyconst(103) as string = {"1","2","3","4","5","6","7","8","9","0","-","=","","","q","w","e","r","t","y","u","i","o","p","[","]","","","a","s","d","f","g","h","j","k","l",";","'","`","","\","z","x","c","v","b","n","m",",",".","/", _
"!","@","#","$","%","^","&","*","(",")","_","+","","","Q","W","E","R","T","Y","U","I","O","P","{","}","","","A","S","D","F","G","H","J","K","L",":"," ","~","","|","Z","X","C","V","B","N","M","<",">","?"}

FOR o = 0 TO 1
 FOR i = 2 TO 53
  temp$ = keyconst$((i - 2) + o * 52)
  IF temp$ <> "" THEN keyv(i, o) = ASC(temp$) ELSE keyv(i, o) = 0
 NEXT i
NEXT o
keyv(40, 1) = 34

END SUB

SUB verquit
 'copypage dpage, vpage
 DIM page AS INTEGER
 page = compatpage

 quitprompt$ = readglobalstring$(55, "Quit Playing?", 20)
 quityes$ = readglobalstring$(57, "Yes", 10)
 quitno$ = readglobalstring$(58, "No", 10)
 direction = 2
 ptr2 = 0
 setkeys
 DO
  setwait speedcontrol
  setkeys
  tog = tog XOR 1
  playtimer
  control
  wtog(0) = loopvar(wtog(0), 0, 3, 1)
  IF carray(ccMenu) > 1 THEN abortg = 0: setkeys: flusharray carray(),7,0: EXIT DO
  IF (carray(ccUse) > 1 AND ABS(ptr2) > 20) OR ABS(ptr2) > 50 THEN
   IF ptr2 < 0 THEN abortg = 1: fadeout 0, 0, 0
   setkeys
   flusharray carray(), 7, 0
   freepage page
   EXIT SUB
  END IF
  IF carray(ccLeft) > 0 THEN ptr2 = ptr2 - 5: direction = 3
  IF carray(ccRight) > 0 THEN ptr2 = ptr2 + 5: direction = 1
  centerbox 160, 95, 200, 42, 15, page
  frame_draw herow(0).sprite + direction * 2 + (wtog(0) \ 2), herow(0).pal, 150 + ptr2, 90, 1, -1, page
  edgeprint quitprompt$, xstring(quitprompt$, 160), 80, uilook(uiText), page
  col = uilook(uiMenuItem): IF ptr2 < -20 THEN col = uilook(uiSelectedItem + tog) '10 + tog * 5
  edgeprint quityes$, 70, 96, col, page
  col = uilook(uiMenuItem): IF ptr2 > 20 THEN col = uilook(uiSelectedItem + tog) '10 + tog * 5
  edgeprint quitno$, 256 - LEN(quitno$) * 8, 96, col, page
  setvispage vpage
  dowait
 LOOP
END SUB

FUNCTION titlescr () as integer
titlescr = -1 ' default return true for success
loadmxs game + ".mxs", gen(genTitle), vpages(3)
needf = 2
IF gen(genTitleMus) > 0 THEN wrappedsong gen(genTitleMus) - 1
setkeys
DO
 setwait speedcontrol
 setkeys
 control
 IF carray(ccMenu) > 1 THEN
  titlescr = 0 ' return false for cancel
  EXIT DO
 END IF
 IF carray(ccUse) > 1 OR carray(ccMenu) > 1 THEN EXIT DO
 FOR i = 2 TO 88
  IF i <> scNumlock AND i <> scCapslock AND keyval(i) > 1 THEN  'DELETEME: a workaround for bug 619
   EXIT DO
  END IF
 NEXT i
 FOR i = 0 TO 1
  gotj(i) = readjoy(joy(), i)
  IF gotj(i) THEN
   IF joy(2) = 0 OR joy(3) = 0 THEN
    joy(2) = -1: joy(3) = -1
    readjoysettings
    joy(2) = -1: joy(3) = -1
    EXIT DO
   ELSE
    gotj(i) = 0
   END IF
  END IF
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 copypage 3, dpage
 IF needf = 1 THEN
  needf = 0
  fadein
 END IF
 IF needf > 1 THEN needf = needf - 1
 dowait
LOOP
END FUNCTION

SUB reloadnpc ()
vishero
FOR i = 0 TO max_npc_defs
 with npcs(i)
  if .sprite then frame_unload(@.sprite)
  if .pal then palette16_unload(@.pal)
  .sprite = frame_load(4, .picture)
  .pal = palette16_load(.palette, 4, .picture)
 end with
NEXT i
END SUB

FUNCTION mapstatetemp(mapnum as integer, prefix as string) as string
 RETURN tmpdir & prefix & mapnum
END FUNCTION

SUB savemapstate_gmap(mapnum, prefix$)
 fh = FREEFILE
 OPEN mapstatetemp$(mapnum, prefix$) + "_map.tmp" FOR BINARY AS #fh
 PUT #fh, , gmap()
 CLOSE #fh
END SUB

SUB savemapstate_npcl(mapnum, prefix$)
 fh = FREEFILE
 OPEN mapstatetemp$(mapnum, prefix$) + "_l.tmp" FOR BINARY AS #fh
 PUT #fh, , npc()
 CLOSE #fh
END SUB

SUB savemapstate_npcd(mapnum, prefix$)
 fh = FREEFILE
 OPEN mapstatetemp$(mapnum, prefix$) + "_n.tmp" FOR BINARY AS #fh
 'PUT #fh, , npcs()
 dim i as integer
 for i = lbound(npcs) to ubound(npcs)
  with npcs(i)
   put #fh, ,.picture
   put #fh, ,.palette
   put #fh, ,.movetype
   put #fh, ,.speed
   put #fh, ,.textbox
   put #fh, ,.facetype
   put #fh, ,.item
   put #fh, ,.pushtype
   put #fh, ,.activation
   put #fh, ,.tag1
   put #fh, ,.tag2
   put #fh, ,.usetag
   put #fh, ,.script
   put #fh, ,.scriptarg
   put #fh, ,.vehicle
  end with
 next
 CLOSE #fh
END SUB

SUB savemapstate_tilemap(mapnum, prefix$)
 savetilemaps maptiles(), mapstatetemp$(mapnum, prefix$) + "_t.tmp"
END SUB

SUB savemapstate_passmap(mapnum, prefix$)
 savetilemap pass, mapstatetemp$(mapnum, prefix$) + "_p.tmp"
END SUB

SUB savemapstate (mapnum, savemask = 255, prefix$)
fh = FREEFILE
IF savemask AND 1 THEN
 savemapstate_gmap mapnum, prefix$
END IF
IF savemask AND 2 THEN
 savemapstate_npcl mapnum, prefix$
END IF
IF savemask AND 4 THEN
 savemapstate_npcd mapnum, prefix$
END IF
IF savemask AND 8 THEN
 savemapstate_tilemap mapnum, prefix$
END IF
IF savemask AND 16 THEN
 savemapstate_passmap mapnum, prefix$
END IF
END SUB

SUB loadmapstate_gmap (mapnum, prefix$, dontfallback = 0)
 fh = FREEFILE
 filebase$ = mapstatetemp$(mapnum, prefix$)
 IF NOT isfile(filebase$ + "_map.tmp") THEN
  IF dontfallback = 0 THEN loadmap_gmap mapnum
  EXIT SUB
 END IF
 OPEN filebase$ + "_map.tmp" FOR BINARY AS #fh
 GET #fh, , gmap()
 CLOSE #fh
 IF gmap(31) = 0 THEN gmap(31) = 2

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

SUB loadmapstate_npcl (mapnum, prefix$, dontfallback = 0)
 fh = FREEFILE
 filebase$ = mapstatetemp$(mapnum, prefix$)
 IF NOT isfile(filebase$ + "_l.tmp") THEN
  IF dontfallback = 0 THEN loadmap_npcl mapnum
  EXIT SUB
 END IF
 OPEN filebase$ + "_l.tmp" FOR BINARY AS #fh
 GET #fh, , npc()
 CLOSE #fh

 'Evaluate whether NPCs should appear or disappear based on tags
 npcplot
END SUB

SUB loadmapstate_npcd (mapnum, prefix$, dontfallback = 0)
 fh = FREEFILE
 filebase$ = mapstatetemp$(mapnum, prefix$)
 IF NOT isfile(filebase$ + "_n.tmp") THEN
  IF dontfallback = 0 THEN loadmap_npcd mapnum
  EXIT SUB
 END IF
 OPEN filebase$ + "_n.tmp" FOR BINARY AS #fh
 for i = lbound(npcs) to ubound(npcs)
  with npcs(i)
   get #fh, ,.picture
   get #fh, ,.palette
   get #fh, ,.movetype
   get #fh, ,.speed
   get #fh, ,.textbox
   get #fh, ,.facetype
   get #fh, ,.item
   get #fh, ,.pushtype
   get #fh, ,.activation
   get #fh, ,.tag1
   get #fh, ,.tag2
   get #fh, ,.usetag
   get #fh, ,.script
   get #fh, ,.scriptarg
   get #fh, ,.vehicle
  end with
 next
 CLOSE #fh

 'Evaluate whether NPCs should appear or disappear based on tags
 npcplot
 'load NPC graphics
 reloadnpc
END SUB

SUB loadmapstate_tilemap (mapnum, prefix$, dontfallback = 0)
 filebase$ = mapstatetemp$(mapnum, prefix$)
 IF NOT isfile(filebase$ + "_t.tmp") THEN
  IF dontfallback = 0 THEN loadmap_tilemap mapnum
 ELSE
  DIM AS SHORT mapsize(1), propersize(1)
  fh = FREEFILE
  OPEN maplumpname$(mapnum, "t") FOR BINARY AS #fh
  GET #fh, 8, propersize()
  CLOSE #fh
  OPEN filebase$ + "_t.tmp" FOR BINARY AS #fh
  GET #fh, 8, mapsize()
  CLOSE #fh
  IF mapsize(0) = propersize(0) AND mapsize(1) = propersize(1) THEN
   loadtilemaps maptiles(), filebase$ + "_t.tmp"
   mapsizetiles.x = maptiles(0).wide
   mapsizetiles.y = maptiles(0).high
   refresh_map_slice

   '--as soon as we know the dimensions of the map, enforce hero position boundaries
   cropposition catx(0), caty(0), 20

  ELSE
   IF dontfallback = 0 THEN loadmap_tilemap mapnum
  END IF
 END IF
END SUB

SUB loadmapstate_passmap (mapnum, prefix$, dontfallback = 0)
 filebase$ = mapstatetemp$(mapnum, prefix$)
 IF NOT isfile(filebase$ + "_p.tmp") THEN
  IF dontfallback = 0 THEN loadmap_passmap mapnum
 ELSE
  DIM AS SHORT mapsize(1), propersize(1)
  fh = FREEFILE
  OPEN maplumpname$(mapnum, "p") FOR BINARY AS #fh
  GET #fh, 8, propersize()
  CLOSE #fh
  OPEN filebase$ + "_p.tmp" FOR BINARY AS #fh
  GET #fh, 8, mapsize()
  CLOSE #fh
  IF mapsize(0) = propersize(0) AND mapsize(1) = propersize(1) THEN
   loadtilemap pass, filebase$ + "_p.tmp"
  ELSE
   IF dontfallback = 0 THEN loadmap_passmap mapnum
  END IF
 END IF
END SUB

SUB loadmapstate (mapnum, loadmask, prefix$, dontfallback = 0)
IF loadmask AND 1 THEN
 loadmapstate_gmap mapnum, prefix$, dontfallback
END IF
IF loadmask AND 2 THEN
 loadmapstate_npcl mapnum, prefix$, dontfallback
END IF
IF loadmask AND 4 THEN
 loadmapstate_npcd mapnum, prefix$, dontfallback
END IF
IF loadmask AND 8 THEN
 loadmapstate_tilemap mapnum, prefix$, dontfallback
END IF
IF loadmask AND 16 THEN
 loadmapstate_passmap mapnum, prefix$, dontfallback
END IF
END SUB

SUB deletemapstate (mapnum, killmask, prefix$)
filebase$ = mapstatetemp(mapnum, "map")
IF killmask AND 1 THEN safekill filebase$ + "_map.tmp"
IF killmask AND 2 THEN safekill filebase$ + "_l.tmp"
IF killmask AND 4 THEN safekill filebase$ + "_n.tmp"
IF killmask AND 8 THEN safekill filebase$ + "_t.tmp"
IF killmask AND 16 THEN safekill filebase$ + "_p.tmp"
END SUB

SUB deletetemps
'deletes game-state temporary files when exiting back to the titlescreen

 findfiles tmpdir + ALLFILES, 0, tmpdir + "filelist.tmp"
 fh = FREEFILE
 OPEN tmpdir + "filelist.tmp" FOR INPUT AS #fh
 DO UNTIL EOF(fh)
  LINE INPUT #fh, filename$
  filename$ = LCASE$(filename$)
  IF RIGHT$(filename$,4) = ".tmp" AND (LEFT$(filename$,3) = "map" OR LEFT$(filename$,5) = "state") THEN
   KILL tmpdir + filename$
  END IF
 LOOP
 CLOSE #fh

 KILL tmpdir + "filelist.tmp"
END SUB

'--A similar function exists in customsubs.bas for custom. it differs only in error-reporting
FUNCTION decodetrigger (trigger as integer, trigtype as integer) as integer
 DIM buf(19)
 'debug "decoding " + STR$(trigger) + " type " + STR$(trigtype)
 decodetrigger = trigger  'default
 IF trigger >= 16384 THEN
  fname$ = workingdir + SLASH + "lookup" + STR$(trigtype) + ".bin"
  IF loadrecord (buf(), fname$, 20, trigger - 16384) THEN
   decodetrigger = buf(0)
   IF buf(0) = 0 THEN
    scripterr "Script " + readbinstring(buf(), 1, 36) + " is used but has not been imported", 6
   END IF
  END IF
 END IF
END FUNCTION

SUB debug_npcs ()
 debug "NPC types:"
 FOR i AS INTEGER = 0 TO max_npc_defs
  debug " ID " & i & ": pic=" & npcs(i).picture & " pal=" & npcs(i).palette
 NEXT
 debug "NPC instances:"
 FOR i AS INTEGER = 0 TO 299
  WITH npc(i)
   IF .id <> 0 THEN
    DIM AS INTEGER drawX, drawY
    IF framewalkabout(npc(i).x, npc(i).y + gmap(11), drawX, drawY, mapsizetiles.x * 20, mapsizetiles.y * 20, gmap(5)) THEN
     debug " " & i & ": ID=" & SGN(.id) * (ABS(.id) - 1) & " x=" & .x & " y=" & .y & " screenx=" & drawX & " screeny=" & drawY
    ELSE
     debug " " & i & ": ID=" & SGN(.id) * (ABS(.id) - 1) & " x=" & .x & " y=" & .y
    END IF
   END IF
  END WITH
 NEXT
END SUB

SUB npc_debug_display ()
 DIM temp AS STRING
 STATIC tog
 tog = tog XOR 1
 FOR i AS INTEGER = 0 TO 299
  WITH npc(i)
   IF .id <> 0 THEN
    DIM AS INTEGER drawX, drawY
    IF framewalkabout(npc(i).x, npc(i).y + gmap(11), drawX, drawY, mapsizetiles.x * 20, mapsizetiles.y * 20, gmap(5)) THEN
     textcolor uilook(uiText), 0
     'the numbers can overlap quite badly, try to squeeze them in
     temp = STR$(SGN(.id) * (ABS(.id) - 1))
     printstr MID$(temp, 1, 1), drawX, drawY + 4, dpage
     printstr MID$(temp, 2, 1), drawX + 7, drawY + 4, dpage
     printstr MID$(temp, 3, 1), drawX + 14, drawY + 4, dpage
     textcolor uilook(uiDescription), 0
     temp = STR$(i + 1)
     printstr MID$(temp, 1, 1), drawX, drawY + 12, dpage
     printstr MID$(temp, 2, 1), drawX + 7, drawY + 12, dpage
     printstr MID$(temp, 3, 1), drawX + 14, drawY + 12, dpage
    END IF
   END IF
  END WITH
 NEXT
END SUB

'======== FIXME: move this up as code gets cleaned up ===========
OPTION EXPLICIT

SUB limitcamera (BYREF x AS INTEGER, BYREF y AS INTEGER)
 IF gmap(5) = 0 THEN
  'when cropping the camera to the map, stop camera movements that attempt to go over the edge
  DIM oldmapx AS INTEGER = x
  DIM oldmapy AS INTEGER = y
  x = bound(x, 0, mapsizetiles.x * 20 - 320)
  y = bound(y, 0, mapsizetiles.y * 20 - 200)
  IF oldmapx <> x THEN
   IF gen(cameramode) = pancam THEN gen(cameramode) = stopcam
   IF gen(cameramode) = focuscam THEN gen(cameraArg3) = 0
  END IF
  IF oldmapy <> y THEN
   IF gen(cameramode) = pancam THEN gen(cameramode) = stopcam
   IF gen(cameramode) = focuscam THEN gen(cameraArg4) = 0
  END IF
 END IF
 IF gmap(5) = 1 THEN
  'Wrap the camera according to the center, not the top-left
  x += 160
  y += 100
  wrapxy x, y, mapsizetiles.x * 20, mapsizetiles.y * 20
  x -= 160
  y -= 100
 END IF
END SUB

FUNCTION game_setoption(opt as string, arg as string) as integer
 IF opt = "errlvl" THEN
  IF is_int(arg) THEN
   err_suppress_lvl = str2int(arg, 4)
   RETURN 2
  ELSE
   RETURN 1
  END IF
 END IF
 RETURN 0
END FUNCTION

'return a video page which is a view on vpage that is 320x200 (or smaller) and centred
FUNCTION compatpage() as integer
 DIM fakepage AS INTEGER
 DIM centreview AS Frame ptr
 centreview = frame_new_view(vpages(vpage), (vpages(vpage)->w - 320) / 2, (vpages(vpage)->h - 200) / 2, 320, 200)
 fakepage = registerpage(centreview)
 frame_unload @centreview
 RETURN fakepage
END FUNCTION
