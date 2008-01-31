'OHRRPGCE - File browser
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#include "const.bi"
#include "compat.bi"
#include "allmodex.bi"
#include "common.bi"

'Subs and functions only used locally
DECLARE SUB draw_browse_meter(br AS BrowseMenuState)
DECLARE SUB browse_add_files(wildcard$, attrib AS INTEGER, BYREF br AS BrowseMenuState, tree() AS BrowseMenuEntry)
DECLARE FUNCTION validmusicfile (file$, as integer = FORMAT_BAM AND FORMAT_MIDI)
DECLARE FUNCTION show_mp3_info() AS STRING

FUNCTION browse$ (special, default$, fmask$, tmp$, needf)
STATIC remember$
browse$ = ""

DIM br AS BrowseMenuState
br.limit = 255
br.tmp = tmp$
br.special = special

'special=0   no preview
'special=1   just BAM
'special=2   16 color BMP
'special=3   background
'special=4   master palette (*.mas, 8 bit *.bmp, 16x16 24 bit *.bmp) (fmask$ is ignored)
'special=5   any supported music (currently *.bam and *.mid, *.ogg, *.mp3 and mod format)  (fmask$ is ignored)
'special=6   any supported SFX (currently *.ogg, *.wav, *.mp3) (fmask$ is ignored)
'special=7   RPG files
mashead$ = CHR$(253) + CHR$(13) + CHR$(158) + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(6)
paledithead$ = CHR$(253) + CHR$(217) + CHR$(158) + CHR$(0) + CHR$(0) + CHR$(7) + CHR$(6)

DIM tree(br.limit) AS BrowseMenuEntry
DIM drive$(26), catfg(6), catbg(6), bmpd(4), f = -1

'tree().kind contains the type of each object in the menu
'0 = Drive (Windows only)
'1 = Parent Directory
'2 = Subdirectory
'3 = Selectable item
'4 = Root
'5 = Special (not used)
'6 = Unselectable item

showHidden = 0

'FIXME: do we need another uilook() constant for these "blue" directories instead of uilook(uiTextbox + 1)?
catfg(0) = uilook(uiMenuItem)   : catbg(0) = uilook(uiHighlight)    'selectable drives (none on unix systems)
catfg(1) = uilook(uiTextbox + 1): catbg(1) = uilook(uiDisabledItem) 'directories
catfg(2) = uilook(uiTextbox + 1): catbg(2) = uilook(uiBackground)   'subdirectories
catfg(3) = uilook(uiMenuItem)   : catbg(3) = uilook(uiBackground)   'files
catfg(4) = uilook(uiTextbox + 1): catbg(4) = uilook(uiDisabledItem) 'root of current drive
catfg(5) = uilook(uiTextBox + 3): catbg(5) = uilook(uiDisabledItem) 'special (never used???)
catfg(6) = uilook(uiDisabledItem): catbg(6) = uilook(uiBackground)  'disabled

IF needf = 1 THEN
 DIM temppal(255) as RGBcolor
 FOR i = 0 TO 255
  temppal(i).r = 0
  temppal(i).g = 0
  temppal(i).b = 0
 NEXT i
 setpal temppal()
END IF

drivetotal = drivelist(drive$())

IF remember$ = "" THEN remember$ = curdir$ + SLASH
IF default$ = "" THEN
 br.nowdir = remember$
ELSE
 br.nowdir = default$
END IF

If br.special = 7 THEN br.viewsize = 16 ELSE br.viewsize = 17

treeptr = 0
treetop = 0
br.treesize = 0

br.ranalready = 0
GOSUB context

changed = 1

setkeys
DO
 setwait 80
 setkeys
 tog = tog XOR 1
 IF keyval(1) > 1 THEN EXIT DO
 IF usemenu(treeptr, treetop, 0, br.treesize, br.viewsize) OR changed THEN
  alert$ = ""
  changed = 0
  GOSUB hover
 END IF
 IF enter_or_space() THEN
  alert$ = ""
  changed = 1
  IF br.special = 1 OR br.special = 5 THEN pausesong
  SELECT CASE tree(treeptr).kind
   CASE 0
    'this could take a while...
    rectangle 5, 32 + br.viewsize * 9, 310, 12, uilook(uiTextbox + 0), vpage
    edgeprint "Reading...", 8, 34 + br.viewsize * 9, uilook(uiText), vpage
    setvispage vpage
    IF hasmedia(tree(treeptr).filename) THEN
     br.nowdir = tree(treeptr).filename
     GOSUB context
    ELSE
     alert$ = "No media"
     changed = 0
    END IF
   CASE 1, 4
    br.nowdir = ""
    FOR i = drivetotal TO treeptr
     br.nowdir = br.nowdir + tree(i).filename
    NEXT i
    GOSUB context
   CASE 2
    br.nowdir = br.nowdir + tree(treeptr).filename + SLASH
    GOSUB context
   CASE 3
    browse$ = br.nowdir + tree(treeptr).filename
    EXIT DO
  END SELECT
 END IF
 IF keyval(29) THEN
  'Ctrl + H for hidden
  IF keyval(35) > 1 THEN
   showHidden = showHidden XOR attribHidden
   GOSUB context
  END IF
 ELSE
  'find by letter
  FOR i = 2 TO 53
   IF keyval(i) > 1 AND keyv(i, 0) > 0 THEN
    FOR j = 1 TO br.treesize
     mappedj = (j + treeptr) MOD (br.treesize + 1)
     tempstr$ = LCASE$(tree(mappedj).caption)
     IF (tree(mappedj).kind = 1 OR tree(mappedj).kind = 2 OR tree(mappedj).kind = 3) AND tempstr$[0] = keyv(i, 0) THEN treeptr = mappedj: EXIT FOR
    NEXT
    EXIT FOR
   END IF
  NEXT i
 END IF
 edgeboxstyle 4, 3, 312, 14, 0, dpage
 edgeprint br.nowdir, 8, 6, uilook(uiText), dpage
 edgeboxstyle 4, 31 + br.viewsize * 9, 312, 14, 0, dpage
 edgeprint alert$, 8, 34 + br.viewsize * 9, uilook(uiText), dpage
 IF br.special = 7 THEN
  rectangle 0, 190, 320, 10, uilook(uiDisabledItem), dpage
  edgeprint version$, 8, 190, uilook(uiMenuItem), dpage
  textcolor uilook(uiText), 0
 END IF
 textcolor uilook(uiText), 0
 printstr ">", 0, 20 + (treeptr - treetop) * 9, dpage
 FOR i = treetop TO small(treetop + br.viewsize, br.treesize)
  textcolor catfg(tree(i).kind), catbg(tree(i).kind)
  a$ = tree(i).caption
  IF LEN(a$) < 38 AND catbg(tree(i).kind) > 0 THEN a$ = a$ + STRING$(38 - LEN(a$), " ")
  printstr a$, 10, 20 + (i - treetop) * 9, dpage
 NEXT i
 SWAP vpage, dpage
 setvispage vpage
 clearpage dpage
 IF needf = 1 THEN fadein: setkeys
 IF needf THEN needf = needf - 1
 dowait
LOOP
IF default$ = "" THEN
 remember$ = br.nowdir
ELSE
 default$ = br.nowdir
END IF
pausesong:if f >= 0 then sound_stop(f, -1): UnloadSound(f)
EXIT FUNCTION

hover:
SELECT CASE br.special
 CASE 1
  pausesong
  IF tree(treeptr).kind = 3 OR tree(treeptr).kind = 6 THEN
   IF validmusicfile(br.nowdir + tree(treeptr).filename, FORMAT_BAM) THEN
    loadsong br.nowdir + tree(treeptr).filename
   ELSE
    alert$ = tree(treeptr).filename + " is not a valid BAM file"
   END IF
  END IF
 CASE 2, 3
  IF bmpinfo(br.nowdir + tree(treeptr).filename, bmpd()) THEN
   alert$ = bmpd(1) & "*" & bmpd(2) & " pixels, " & bmpd(0) & "-bit color"
  END IF
 CASE 4
  IF tree(treeptr).kind = 3 OR tree(treeptr).kind = 6 THEN
   masfh = FREEFILE
   OPEN br.nowdir + tree(treeptr).filename FOR BINARY AS #masfh
   IF LCASE$(justextension$(tree(treeptr).filename)) = "mas" THEN
    a$ = "       "
    GET #masfh, 1, a$
    CLOSE #masfh
    SELECT CASE a$
     CASE mashead$
      alert$ = "MAS format"
     CASE paledithead$
      alert$ = "MAS format (PalEdit)"
     CASE ELSE
     alert$ = "Not a valid MAS file"
    END SELECT
   ELSE
    '.bmp file
    IF bmpinfo(br.nowdir + tree(treeptr).filename, bmpd()) THEN
     IF bmpd(0) = 24 THEN
      alert$ = bmpd(1) & "*" & bmpd(2) & " pixels, " & bmpd(0) & "-bit color"
     ELSE
      alert$ = bmpd(0) & "-bit color BMP"
     END IF
    END IF
   END IF
  END IF
 CASE 5
  pausesong
  alert$ = tree(treeptr).about
  IF validmusicfile(br.nowdir + tree(treeptr).filename, PREVIEWABLE_MUSIC_FORMAT) THEN
   loadsong br.nowdir + tree(treeptr).filename
  ELSEIF getmusictype(br.nowdir + tree(treeptr).filename) = FORMAT_MP3 THEN
   alert$ = show_mp3_info()
  END IF
 CASE 6
  alert$ = tree(treeptr).about
  IF f > -1 THEN
   sound_stop(f,-1)
   UnloadSound(f)
   f = -1
  END IF
  IF validmusicfile(br.nowdir + tree(treeptr).filename, PREVIEWABLE_FX_FORMAT) THEN
   f = LoadSound(br.nowdir + tree(treeptr).filename)
   sound_play(f, 0, -1)
  ELSEIF getmusictype(br.nowdir + tree(treeptr).filename) = FORMAT_MP3 THEN
   alert$ = show_mp3_info()
  END IF
 CASE 7
  alert$ = tree(treeptr).about
END SELECT
IF tree(treeptr).kind = 0 THEN alert$ = "Drive"
IF tree(treeptr).kind = 1 THEN alert$ = "Directory"
IF tree(treeptr).kind = 2 THEN alert$ = "Subdirectory"
IF tree(treeptr).kind = 4 THEN alert$ = "Root"
RETRACE

context:
'erase old list
FOR i = 0 TO br.limit
 tree(i).filename = ""
 tree(i).caption = ""
 tree(i).about = ""
 tree(i).kind = 0
NEXT i
'for progress meter
IF br.ranalready THEN rectangle 5, 32 + br.viewsize * 9, 310, 12, uilook(uiTextbox + 0), vpage
br.meter = 0
br.treesize = 0
IF br.nowdir = "" THEN
ELSE
 draw_browse_meter br
 a$ = br.nowdir
 '--Drive list
#IFNDEF __FB_LINUX__
  FOR i = 0 TO drivetotal - 1
   tree(br.treesize).filename = drive$(i)
   tree(br.treesize).kind = 0
   IF isremovable(drive$(i)) THEN
    tree(br.treesize).caption = drive$(i) + " (removable)"
   ELSE
    IF hasmedia(drive$(i)) THEN
     tree(br.treesize).caption = drive$(i) + " <" + drivelabel$(drive$(i)) + ">"
    ELSE
     tree(br.treesize).caption = drive$(i) + " (not ready)"
    END IF
    draw_browse_meter br
   END IF
   br.treesize += 1
  NEXT i
  'could add My Documents to drives list here
#ENDIF
 '--Current drive
 tree(br.treesize).filename = MID$(a$, 1, INSTR(a$, SLASH))
#IFNDEF __FB_LINUX__
 IF hasmedia(tree(br.treesize).filename) = 0 THEN
  'Somebody pulled out the disk
  changed = 0
  alert$ = "Disk not readable"
  br.treesize -= 1
  treeptr = 0
  treetop = 0
  br.nowdir = ""
  RETRACE
 END IF
#ENDIF
 a$ = MID$(a$, INSTR$(a$, SLASH) + 1)
 tree(br.treesize).kind = 4
 tmpname$ = drivelabel$(tree(br.treesize).filename)
 IF LEN(tmpname$) THEN tree(br.treesize).caption = tree(br.treesize).filename + " <" + tmpname$ + ">"
 '--Directories
 b$ = ""
 DO UNTIL a$ = "" OR br.treesize >= br.limit
  b$ = b$ + LEFT$(a$, 1)
  a$ = RIGHT$(a$, LEN(a$) - 1)
  IF RIGHT$(b$, 1) = SLASH THEN
#IFNDEF __FB_LINUX__
   'Special handling of My Documents in Windows
   IF b$ = "My Documents\" OR b$ = "MYDOCU~1\" THEN
    FOR i = br.treesize to drivetotal STEP -1
     b$ = tree(i).filename + b$
    NEXT i
    br.treesize = drivetotal - 1
    tree(br.treesize + 1).caption = "My Documents\"
   END IF
#ENDIF
   br.treesize = br.treesize + 1
   tree(br.treesize).filename = b$
   tree(br.treesize).kind = 1
   b$ = ""
   draw_browse_meter br
  END IF
 LOOP
 '---FIND ALL SUB-DIRECTORIES IN THE CURRENT DIRECTORY---
 findfiles br.nowdir + ALLFILES, 16, br.tmp + "hrbrowse.tmp"
 fh = FREEFILE
 OPEN br.tmp + "hrbrowse.tmp" FOR INPUT AS #fh
 DO UNTIL EOF(fh) OR br.treesize >= br.limit
  br.treesize = br.treesize + 1
  tree(br.treesize).kind = 2
  LINE INPUT #fh, tree(br.treesize).filename
  IF tree(br.treesize).filename = "." OR tree(br.treesize).filename = ".." OR RIGHT$(tree(br.treesize).filename, 4) = ".tmp" THEN br.treesize = br.treesize - 1
  IF br.special = 7 THEN ' Special handling in RPG mode
   IF justextension$(tree(br.treesize).filename) = "rpgdir" THEN br.treesize = br.treesize - 1
  END IF
  draw_browse_meter br
 LOOP
 CLOSE #fh
 safekill br.tmp + "hrbrowse.tmp"
 '---FIND ALL FILES IN FILEMASK---
 attrib = attribAlmostAll OR showHidden
 IF br.special = 4 THEN
  browse_add_files "*.mas", attrib, br, tree()
  browse_add_files "*.bmp", attrib, br, tree()
 ELSEIF br.special = 5 THEN' background music
  '--disregard fmask$. one call per extension
  browse_add_files "*.bam", attrib, br, tree()
  browse_add_files "*.mid", attrib, br, tree()
  browse_add_files "*.xm", attrib, br, tree()
  browse_add_files "*.it", attrib, br, tree()
  browse_add_files "*.mod", attrib, br, tree()
  browse_add_files "*.s3m", attrib, br, tree()
  browse_add_files "*.ogg", attrib, br, tree()
  browse_add_files "*.mp3", attrib, br, tree()
 ELSEIF br.special = 6 THEN ' sound effects
  '--disregard fmask$. one call per extension
  browse_add_files "*.wav", attrib, br, tree()
  browse_add_files "*.ogg", attrib, br, tree()
  browse_add_files "*.mp3", attrib, br, tree()
 ELSEIF br.special = 7 THEN
  'Call once for RPG files once for rpgdirs
  browse_add_files fmask$, attrib, br, tree()
  browse_add_files "*.rpgdir", 16, br, tree()
 ELSE
  browse_add_files fmask$, attrib, br, tree()
 END IF
END IF

'--set display
FOR i = 0 TO br.treesize
 IF LEN(tree(i).caption) = 0 THEN
  tree(i).caption = tree(i).filename
 END IF
NEXT

sortstart = br.treesize
FOR k = 0 TO br.treesize
 WITH tree(k)
  IF .kind = 2 OR .kind = 3 OR .kind = 6 THEN sortstart = k: EXIT FOR
 END WITH
NEXT

'--alphabetize
FOR i = sortstart TO br.treesize - 1
 FOR j = br.treesize TO i + 1 STEP -1
  FOR k = 0 TO small(LEN(tree(i).caption), LEN(tree(j).caption))
   chara = ASC(LCASE$(CHR$(tree(i).caption[k])))
   charb = ASC(LCASE$(CHR$(tree(j).caption[k])))
   IF chara < charb THEN
    EXIT FOR
   ELSEIF chara > charb THEN
    SWAP tree(i), tree(j)
    EXIT FOR
   END IF
  NEXT
 NEXT
NEXT

'--sort by type
FOR o = br.treesize TO sortstart + 1 STEP -1
 FOR i = sortstart + 1 TO o
  IF tree(i).kind < tree(i - 1).kind THEN
   SWAP tree(i), tree(i - 1)
  END IF
 NEXT
NEXT

'--set cursor
treeptr = 0
treetop = 0
FOR i = drivetotal TO br.treesize
 IF tree(i).kind = 1 OR tree(i).kind = 4 THEN treeptr = i
NEXT i
FOR i = br.treesize TO 1 STEP -1
 IF tree(i).kind = 3 THEN treeptr = i
NEXT i
treetop = bound(treetop, treeptr - (br.viewsize + 2), treeptr)

'--don't display progress bar overtop of previous menu
br.ranalready = 1

RETRACE

END FUNCTION

SUB browse_add_files(wildcard$, attrib AS INTEGER, BYREF br AS BrowseMenuState, tree() AS BrowseMenuEntry)
DIM bmpd(4) AS INTEGER
DIM f AS STRING
mashead$ = CHR$(253) + CHR$(13) + CHR$(158) + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(6)
paledithead$ = CHR$(253) + CHR$(217) + CHR$(158) + CHR$(0) + CHR$(0) + CHR$(7) + CHR$(6)

DIM filelist$
filelist$ = br.tmp + "hrbrowse.tmp"
findfiles br.nowdir + anycase$(wildcard$), attrib, filelist$

fh = FREEFILE
OPEN filelist$ FOR INPUT AS #fh
DO UNTIL EOF(fh) OR br.treesize >= br.limit
 br.treesize = br.treesize + 1
 tree(br.treesize).kind = 3
 LINE INPUT #fh, tree(br.treesize).filename
 f = br.nowdir & tree(br.treesize).filename
 '---music files
 IF br.special = 1 OR br.special = 5 THEN
  IF validmusicfile(f, VALID_MUSIC_FORMAT) = 0 THEN
   tree(br.treesize).kind = 6
   tree(br.treesize).about = "Not a valid music file"
  END IF
 END IF
 IF br.special = 6 THEN
  IF validmusicfile(f, VALID_FX_FORMAT) = 0 THEN
   tree(br.treesize).kind = 6
   tree(br.treesize).about = "Not a valid sound effect file"
  END IF
 END IF
 '---4-bit BMP browsing
 IF br.special = 2 THEN
  IF bmpinfo(f, bmpd()) THEN
   IF bmpd(0) <> 4 OR bmpd(1) > 320 OR bmpd(2) > 200 THEN
    tree(br.treesize).kind = 6
   END IF
  ELSE
   br.treesize = br.treesize - 1
  END IF
 END IF
 '---320x200x24/8bit BMP files
 IF br.special = 3 THEN
  IF bmpinfo(f, bmpd()) THEN
   IF (bmpd(0) <> 24 AND bmpd(0) <> 8) OR bmpd(1) <> 320 OR bmpd(2) <> 200 THEN
    tree(br.treesize).kind = 6
   END IF
  ELSE
   br.treesize = br.treesize - 1
  END IF
 END IF
 '--master palettes  (why isn't this up there?)
 IF br.special = 4 THEN
  IF LCASE$(justextension$(tree(br.treesize).filename)) = "mas" THEN
   masfh = FREEFILE
   OPEN f FOR BINARY AS #masfh
   a$ = "       "
   GET #masfh, 1, a$
   CLOSE #masfh
   IF a$ <> mashead$ AND a$ <> paledithead$ THEN
    tree(br.treesize).kind = 6
   END IF
  ELSE
   IF bmpinfo(f, bmpd()) THEN
    IF (bmpd(0) = 8 OR bmpd(0) = 24 AND (bmpd(1) = 16 AND bmpd(2) = 16)) = 0 THEN tree(br.treesize).kind = 6
   ELSE
    br.treesize = br.treesize - 1
   END IF
  END IF
 END IF
 '--RPG files
 IF br.special = 7 THEN
  copylump f, "browse.txt", br.tmp, -1
  IF isfile(br.tmp + "browse.txt") THEN
   setpicstuf buffer(), 40, -1
   loadset br.tmp + "browse.txt", 0, 0
   tree(br.treesize).caption = STRING$(bound(buffer(0), 0, 38), " ")
   array2str buffer(), 2, tree(br.treesize).caption
   loadset br.tmp + "browse.txt", 1, 0
   tree(br.treesize).about = STRING$(bound(buffer(0), 0, 38), " ")
   array2str buffer(), 2, tree(br.treesize).about
   safekill br.tmp + "browse.txt"
   IF LEN(tree(br.treesize).caption) = 0 THEN tree(br.treesize).caption = tree(br.treesize).filename
  ELSE
   tree(br.treesize).about = ""
   tree(br.treesize).caption = tree(br.treesize).filename
  END IF
 END IF
 draw_browse_meter br
LOOP
CLOSE #fh
safekill filelist$

END SUB

SUB draw_browse_meter(br AS BrowseMenuState)
WITH br
 IF .ranalready THEN
  .meter = small(.meter + 1, 308)
  rectangle 5 + .meter, 33 + .viewsize * 9, 2, 5, uilook(uiTextbox + 1), vpage
  setvispage vpage 'refresh
 END IF
END WITH
END SUB

FUNCTION validmusicfile (file$, types = FORMAT_BAM AND FORMAT_MIDI)
'-- actually, doesn't need to be a music file, but only multi-filetype imported data right now
	DIM ext$, a$, realhd$, musfh, v, chk
	ext$ = lcase(justextension(file$))
	chk = getmusictype(file$)

	if (chk AND types) = 0 then return 0

	SELECT CASE chk
	CASE FORMAT_BAM
		a$ = "    "
		realhd$ = "CBMF"
		v = 1
	CASE FORMAT_MIDI
		a$ = "    "
		realhd$ = "MThd"
		v = 1
	CASE FORMAT_XM
		a$ =      "                 "
		realhd$ = "Extended Module: "
		v = 1
	CASE FORMAT_MP3
		return can_convert_mp3()
	END SELECT

	if v then
		musfh = FREEFILE
		OPEN file$ FOR BINARY AS #musfh
		GET #musfh, 1, a$
		CLOSE #musfh
		IF a$ <> realhd$ THEN return 0
	end if

	return 1
END FUNCTION

FUNCTION show_mp3_info() AS STRING
 IF can_convert_mp3() THEN
  RETURN "Cannot preview MP3, try importing"
 ELSE
  RETURN "madplay & oggenc required. See README"
 END IF
END FUNCTION
