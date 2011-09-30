'OHRRPGCE - Some Custom/Game common code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
' This file is for code that is shared between GAME and CUSTOM.
' Code that is not OHRRPGCE-specific that would be of general use
' to any FreeBasic program belongs in util.bas instead

#ifdef TRY_LANG_FB
 #define __langtok #lang
 __langtok "fb"
#else
 OPTION STATIC
 OPTION EXPLICIT
#endif

#include "config.bi"
#include "ver.txt"
#include "const.bi"
#include "allmodex.bi"
#include "os.bi"
#include "cutil.bi"
#include "string.bi"

#include "udts.bi"
#include "scrconst.bi"
#include "uiconst.bi"
#include "common.bi"
#include "slices.bi"

#include "music.bi"
#include "loading.bi"

'Subs and functions only used here
DECLARE SUB setup_sprite_sizes ()

#IFDEF IS_GAME
DECLARE FUNCTION istag (byval num as integer, byval zero as integer) as integer
DECLARE SUB scripterr (e as string, byval errorlevel as integer = 5)
DECLARE FUNCTION commandname (byval id as integer) as string
DECLARE SUB exitprogram (byval need_fade_out as integer = NO, byval errorout as integer = NO)
DECLARE SUB show_wrong_spawned_version_error
EXTERN insideinterpreter as integer
EXTERN curcmd as ScriptCommand ptr
EXTERN running_as_slave as integer
#ENDIF

#IFDEF IS_CUSTOM
DECLARE FUNCTION charpicker() as string
#ENDIF


''''' Global variables (anything else in common.bi missing here will be in game.bas or custom.bas)

'Allocate sprite size table
REDIM sprite_sizes(-1 TO 10) as SpriteSize
setup_sprite_sizes

'holds commandline args not recognised by the backends or anything else
REDIM cmdline_args(0) as string

'holds the directory to dump logfiles into
DIM log_dir as string

'It is very important for this to be populated _before_ any calls to CHDIR
DIM orig_dir as string

'Used on Mac to point to the app bundle Resources directory
DIM data_dir as string

'Used by intgrabber, reset by usemenu
DIM negative_zero as integer = NO

#IFDEF IS_CUSTOM
 'show/fatalerror option (Custom only): have we started editing?
 'If not, we should cleanup working.tmp instead of preserving it
 DIM cleanup_on_error as integer = YES
#ENDIF

''''' Module-local variables

'a primitive system for printing messages that scroll
TYPE ConsoleData
 as integer x = 0, y = 0, top = 0, h = 200, c = 0
END TYPE
DIM SHARED console as ConsoleData

'don't black out the screen to show upgrade messages if there aren't any
DIM SHARED upgrademessages as integer

'upgrading timing stuff
DIM SHARED time_rpg_upgrade as integer = NO  'Change to YES, or pass --time-upgrade
DIM SHARED last_upgrade_time as DOUBLE
DIM SHARED upgrade_overhead_time as DOUBLE
DIM SHARED upgrade_start_time as DOUBLE

'Upgrade all game data (required for writing), or only enough to allow reading?
#IFDEF IS_CUSTOM
DIM SHARED full_upgrade as integer = YES
#ELSE
DIM SHARED full_upgrade as integer = NO
#ENDIF

'don't delete the debug file at end of play
DIM SHARED importantdebug as integer = 0

'When restarting the log, the previous path if significant
DIM SHARED lastlogfile as string

'.stt lump read into memory
DIM SHARED global_strings_buffer as string


FUNCTION common_setoption(opt as string, arg as string) as integer
 IF opt = "time-upgrade" THEN
  time_rpg_upgrade = YES
  RETURN 1  'arg not used
 ELSEIF opt = "full-upgrade" THEN
  full_upgrade = YES
  RETURN 1  'arg not used
 ELSEIF opt = "recordinput" then
  DIM f as string = with_orig_path(arg)
  IF fileiswriteable(f) THEN
   start_recording_input f
   RETURN 2 'arg used
  ELSE
   DIM help as string = "input cannot be recorded to """ & f & """ because the file is not writeable." & LINE_END
   display_help_string help
   RETURN 1
  END IF
 ELSEIF opt = "replayinput" then
  DIM f as string = with_orig_path(arg)
  IF fileisreadable(f) THEN
   start_replaying_input f
   RETURN 2 'arg used
  ELSE
   DIM help as string = "input cannot be replayed from """ & f & """ because the file is not readable." & LINE_END
   display_help_string help
   RETURN 1
  END IF
 END IF
END FUNCTION

'fade in and out not actually used in custom
SUB fadein ()
fadestate = 1
fadetopal master()
END SUB

SUB fadeout (byval red as integer, byval green as integer, byval blue as integer)
fadestate = 0
fadeto red, green, blue
END SUB

FUNCTION filesize (file as string) as string
 'returns size of a file in formatted string
 DIM as integer size, spl
 DIM as string fsize, units
 IF isfile(file) THEN
  size = FILELEN(file)
  units = " B"
  spl = 0
  IF size > 1024 THEN spl = 1 : units = " KB"
  IF size > 1048576 THEN spl = 1 : size = size / 1024 : units = " MB"
  fsize = STR(size)
  IF spl <> 0 THEN
   size = size / 102.4
   fsize = STR(size \ 10)
   IF size < 1000 THEN fsize = fsize + "." + STR(size MOD 10)
  END IF
  RETURN fsize + units
 ELSE
  RETURN "N/A"
 END IF
END FUNCTION

FUNCTION soundfile (byval sfxnum as integer) as string
 DIM as string sfxbase

 sfxbase = workingdir & SLASH & "sfx" & sfxnum
 IF isfile(sfxbase & ".ogg") THEN
  RETURN sfxbase & ".ogg"
 ELSEIF isfile(sfxbase & ".mp3") THEN
  RETURN sfxbase & ".mp3"
 ELSEIF isfile(sfxbase & ".wav") THEN
  RETURN sfxbase & ".wav"
 ELSE
  RETURN ""
 END IF
END FUNCTION

SUB start_new_debug
 CONST buflen = 128 * 1024

 DIM as string logfile, oldfile
 #IFDEF IS_GAME
   logfile = log_dir & "g_debug.txt"
   oldfile = log_dir & "g_debug_archive.txt"
 #ELSE
   logfile = log_dir & "c_debug.txt"
   oldfile = log_dir & "c_debug_archive.txt"
 #ENDIF
 'If we just closed a debug file, don't archive it, or we'll never notice it
 IF lastlogfile = absolute_path(logfile) THEN EXIT SUB
 IF NOT isfile(logfile) THEN EXIT SUB

 DIM dlog as integer = FREEFILE
 OPEN logfile FOR BINARY as dlog
 DIM archive as integer = FREEFILE
 OPEN oldfile FOR BINARY as archive

 DIM as UBYTE PTR buf = ALLOCATE(buflen)

 DIM copyamount as integer = bound(buflen - LOF(dlog), 0, LOF(archive))

 IF copyamount THEN
  SEEK #archive, LOF(archive) - copyamount + 1
  'don't cut the file in the middle of a line
  DO
   GET #archive, , buf[0]
  LOOP UNTIL buf[0] = 10

  GET #archive, , buf[0], buflen, copyamount
 END IF

 CLOSE #archive
 safekill oldfile
 archive = FREEFILE
 OPEN oldfile FOR BINARY as archive
 PUT #archive, , *buf, copyamount

 IF LOF(dlog) > buflen THEN
  SEEK #dlog, LOF(dlog) - buflen + 1
  DO
   GET #dlog, , buf[0]
  LOOP UNTIL buf[0] = 10
 END IF
 
 GET #dlog, , buf[0], buflen, copyamount
 PUT #archive, , LINE_END " \....----~~~~````\" LINE_END
 PUT #archive, , *buf, copyamount
 CLOSE #dlog
 CLOSE #archive

 DEALLOCATE(buf)
 safekill logfile
END SUB

SUB end_debug
 DIM filename as string
 #IFDEF IS_GAME
   filename = "g_debug.txt"
 #ELSE
   filename = "c_debug.txt"
 #ENDIF
 IF NOT importantdebug THEN
   safekill log_dir & filename
 ELSE
   'Remember not to archive the log if we restart the log in the same directory
   lastlogfile = absolute_path(log_dir & filename)
 END IF
 importantdebug = 0
END SUB

SUB debug (s as string)
 importantdebug = -1
 debuginfo s
END SUB

SUB debugc CDECL (byval s as zstring ptr, byval errorlevel as integer)
 'Fine grained errorlevels unimplemented, but here's the current suggestion:
 ' 1 current debuginfo
 ' 2 current debug, mostly for debugging, including "trace"
 ' 3 recovered error, log and ask the user (when they quit?) to send the debug log
 ' 4 possibly recoverable error, ask the user whether they want to continue
 ' 5 fatal error, tell the user to report, and then quit
 ' 6 fatal error which prevents the display of a visible error message;
 '   attempt to print a stacktrace and quit

 IF errorlevel >= 2 THEN importantdebug = -1
 debuginfo *s
END SUB

SUB debuginfo (s as string)
 'use for throwaway messages like upgrading
 STATIC sizeerror as integer = 0
 DIM filename as string
 #IFDEF IS_GAME
   filename = "g_debug.txt"
 #ELSE
   filename = "c_debug.txt"
 #ENDIF
 DIM fh as integer = FREEFILE
 OPEN log_dir & filename FOR APPEND as #fh
 IF LOF(fh) > 2 * 1024 * 1024 THEN
  IF sizeerror = 0 THEN PRINT #fh, "too much debug() output, not printing any more messages"
  sizeerror = -1
  CLOSE #fh
  EXIT SUB
 END IF
 sizeerror = 0
 PRINT #fh, s
 CLOSE #fh
END SUB

'Draw a wrapped string in the middle of the page, in a box
SUB basic_textbox (msg as string, byval col as integer, byval page as integer)
 WITH *vpages(page)
  DIM captlines() as string
  split(wordwrap(msg, (.w - 20) \ 8), captlines())
  centerbox .w \ 2, .h \ 2, .w - 10, 26 + 10 * UBOUND(captlines), 3, page
  DIM y as integer = .h \ 2 - (UBOUND(captlines) + 1) * 5
  FOR i as integer = 0 TO UBOUND(captlines)
   edgeprint captlines(i), 10, y + i * 10, col, page, YES
  NEXT
 END WITH
END SUB

SUB notification (msg as string)
 basic_textbox msg, uilook(uiText), vpage
 setvispage vpage
 waitforanykey
END SUB

SUB visible_debug (msg as string)
 debuginfo msg
 notification msg + !"\nPress any key..."
' pop_warning msg
END SUB

FUNCTION getfixbit(byval bitnum as integer) as integer
 DIM f as string
 f = workingdir + SLASH + "fixbits.bin"
 IF NOT isfile(f) THEN RETURN 0
 DIM fh as integer = FREEFILE
 IF OPEN(f FOR BINARY ACCESS READ as fh) THEN debug "Could not read " & f : RETURN 0
 DIM ub as UBYTE
 GET #fh, (bitnum \ 8) + 1, ub
 CLOSE #fh
 RETURN BIT(ub, bitnum MOD 8)  'BIT is a standard macro
END FUNCTION

SUB setfixbit(byval bitnum as integer, byval bitval as integer)
 DIM f as string
 f = workingdir + SLASH + "fixbits.bin"
 DIM fh as integer = FREEFILE
 IF OPEN(f FOR BINARY as fh) THEN fatalerror "Impossible to upgrade game: Could not write " & f  'Really bad!
 extendfile fh, (bitnum \ 8) + 1  'Prevent writing garbage
 DIM ub as UBYTE
 GET #fh, (bitnum \ 8) + 1, ub
 IF bitval THEN ub = BITSET(ub, bitnum MOD 8) ELSE ub = BITRESET(ub, bitnum MOD 8)
 PUT #fh, (bitnum \ 8) + 1, ub
 CLOSE #fh
END SUB

'Note: Custom doesn't use this function
FUNCTION acquiretempdir () as string
 DIM tmp as string
 #IFDEF __FB_WIN32__
  'Windows only behavior
  tmp = environ("TEMP")
  IF NOT diriswriteable(tmp) THEN tmp = environ("TMP")
  IF NOT diriswriteable(tmp) THEN tmp = exepath
  IF NOT diriswriteable(tmp) THEN tmp = ""
  IF NOT diriswriteable(tmp) THEN fatalerror "Unable to find any writable temp dir"
  IF RIGHT(tmp, 1) <> SLASH THEN tmp = tmp & SLASH
  tmp = tmp & "ohrrpgce"
 #ELSE
  'Unix only behavior
  tmp = environ("HOME") + SLASH + ".ohrrpgce"
  IF NOT isdir(tmp) THEN makedir(tmp)
  tmp = tmp & SLASH
 #ENDIF
 DIM as string d = DATE, t = TIME
 tmp += MID(d,7,4) & MID(d,1,2) & MID(d,4,2) & MID(t,1,2) & MID(t,4,2) & MID(t,7,2) & "." & CINT(RND * 1000) & ".tmp" & SLASH
 RETURN tmp
END FUNCTION

'Backwards compatibility wrapper
SUB centerbox (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval c as integer, byval p as integer)
 IF c < 0 OR c > 15 THEN debug "Warning: invalid box style " & c & " in centerbox"
 center_edgeboxstyle x, y, w, h, c - 1, p
END SUB

SUB center_edgeboxstyle (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval boxstyle as integer, byval p as integer, byval fuzzy as integer=NO, byval supress_borders as integer=NO)
 edgeboxstyle x - w / 2, y - h / 2, w, h, boxstyle, p, fuzzy, supress_borders
END SUB

SUB edgeboxstyle (byref rect as RectType, byval boxstyle as integer, byval p as integer, byval fuzzy as integer=NO, byval supress_borders as integer=NO)
 edgeboxstyle rect.x, rect.y, rect.wide, rect.high, boxstyle, p, fuzzy, supress_borders
END SUB

SUB edgeboxstyle (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval boxstyle as integer, byval p as integer, byval fuzzy as integer=NO, byval supress_borders as integer=NO)
 IF boxstyle < 0 OR boxstyle > 14 THEN
  debug "edgeboxstyle: invalid boxstyle " & boxstyle
  EXIT SUB
 END IF
 DIM col as integer = uilook(uiTextBox + 2 * boxstyle)
 DIM bordercol as integer = uilook(uiTextBox + 2 * boxstyle + 1)
 DIM borders as integer = boxstyle
 DIM trans as RectTransTypes = transOpaque
 IF supress_borders THEN borders = -1
 IF fuzzy THEN trans = transFuzzy
 edgebox x, y, w, h, col, bordercol, p, trans, borders
END SUB

SUB edgebox (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval col as integer, byval bordercol as integer, byval p as integer, byval trans as RectTransTypes=transOpaque, byval border as integer=-1, byval fuzzfactor as integer=50)
 edgebox x, y, w, h, col, bordercol, vpages(p), trans, border, fuzzfactor
END SUB

SUB edgebox (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval col as integer, byval bordercol  as integer, byval fr as Frame Ptr, byval trans as RectTransTypes=transOpaque, byval border as integer=-1, byval fuzzfactor as integer=50)
'--border: -2 is none, -1 is simple line, 0+ is styled box edge
IF trans = transFuzzy THEN
 fuzzyrect fr, x, y, w, h, col, fuzzfactor
ELSEIF trans = transOpaque THEN
 rectangle fr, x, y, w, h, col
END IF
IF border = -1 THEN
 '--Simple line border
 drawbox fr, x, y, w, h, bordercol
ELSEIF border >= 0 AND border <= 14 THEN
 '--Normal Border
 IF trans <> transHollow THEN drawbox fr, x, y, w, h, bordercol
 DIM as integer i, borderindex
 DIM border_gfx as GraphicPair
 borderindex = uilook(uiTextBoxFrame + border) - 1
 IF borderindex >= 0 THEN
  load_sprite_and_pal border_gfx, 7, borderindex
 END IF
 WITH border_gfx
  IF .sprite THEN ' Only proceed if a sprite is actually selected
   'Draw edges
   'ensure we are clipping the correct page (there are many ways of doing this)
   setclip , , , , fr
   '--Top and bottom edges
   FOR i as integer = x + 8 TO x + w - 24 STEP 16
    setclip , , , y + h - 1
    frame_draw .sprite + 2, .pal, i, y - 8, 1, YES, fr
    setclip , y, , 
    frame_draw .sprite + 13, .pal, i, y + h - 8, 1, YES, fr
   NEXT i
   '--Left and right edges
   FOR i as integer = y + 8 TO y + h - 24 STEP 16
    setclip , , x + w - 1, 
    frame_draw .sprite + 7, .pal, x - 8, i, 1, YES, fr
    setclip x, , , 
    frame_draw .sprite + 8, .pal, x + w - 8, i, 1, YES, fr
   NEXT i
   'Draw end-pieces
   IF w > 26 THEN
    '--Top end pieces
    setclip , , , y + h - 1
    frame_draw .sprite + 3, .pal, x + w - 24, y - 8, 1, YES, fr
    frame_draw .sprite + 1, .pal, x + 8, y - 8, 1, YES, fr
    '--Bottom end pieces
    setclip , y, , 
    frame_draw .sprite + 14, .pal, x + w - 24, y + h - 8, 1, YES, fr
    frame_draw .sprite + 12, .pal, x + 8, y + h - 8, 1, YES, fr
   ELSEIF w > 16 THEN
    '--Not enough space for the end pieces, have to draw part of the edge after all
    '--Top and bottom edges
    setclip x + 8, , x + w - 9, y + h - 1
    frame_draw .sprite + 2, .pal, x + 8, y - 8, 1, YES, fr
    setclip x + 8, y, x + w - 9, 
    frame_draw .sprite + 13, .pal, x + 8, y + h - 8, 1, YES, fr
   END IF
   IF h > 26 THEN
    '--Left side end pieces
    setclip , , x + w - 1, 
    frame_draw .sprite + 9, .pal, x - 8, y + h - 24, 1, YES, fr
    frame_draw .sprite + 5, .pal, x - 8, y + 8, 1, YES, fr
    '--Right side end pieces
    setclip x, , , 
    frame_draw .sprite + 10, .pal, x + w - 8, y + h - 24, 1, YES, fr
    frame_draw .sprite + 6, .pal, x + w - 8, y + 8, 1, YES, fr
   ELSEIF h > 16 THEN
    '--Not enough space for the end pieces, have to draw part of the edge after all
    '--Left and right edges
    setclip , y + 8, x + w - 1, y + h - 9
    frame_draw .sprite + 7, .pal, x - 8, y + 8, 1, YES, fr
    setclip x, y + 8, , y + h - 9
    frame_draw .sprite + 8, .pal, x + w - 8, y + 8, 1, YES, fr
   END IF
   'Draw corners
   'If the box is really tiny, we need to only draw part of each corner
   setclip , , x + w - 1, y + h - 1
   frame_draw .sprite, .pal, x - 8, y - 8, 1, YES, fr
   setclip x, , , y + h - 1
   frame_draw .sprite + 4, .pal, x + w - 8, y - 8, 1, YES, fr
   setclip , y, x + w - 1,
   frame_draw .sprite + 11, .pal, x - 8, y + h - 8, 1, YES, fr
   setclip x, y, , 
   frame_draw .sprite + 15, .pal, x + w - 8, y + h - 8, 1, YES, fr
   setclip
  END IF
 END WITH
 unload_sprite_and_pal border_gfx
END IF
END SUB

SUB centerfuz (byval x as integer, byval y as integer, byval w as integer, byval h as integer, byval c as integer, byval p as integer)
 IF c < 0 OR c > 15 THEN debug "Warning: invalid box style " & c & " in centerbox"
 center_edgeboxstyle x, y, w, h, c - 1, p, YES
END SUB

FUNCTION read32bitstring (array() as integer, byval offset as integer) as string
DIM as string result = SPACE(array(offset))
memcpy(STRPTR(result), @array(offset + 1), array(offset))
return result
END FUNCTION

FUNCTION read32bitstring (stringptr as integer ptr) as string
DIM as string result = SPACE(stringptr[0])
memcpy(STRPTR(result), @stringptr[1], stringptr[0])
return result
END FUNCTION

FUNCTION readbadgenericname (byval index as integer, filename as string, byval recsize as integer, byval offset as integer, byval size as integer, byval skip as integer = 0) as string
 'recsize is in BYTES!
 'FIXME: there isn't any good reason to load the whole record
 '       just to get the string field
 IF index >= 0 THEN
  DIM buf(recsize \ 2 - 1) as integer
  IF loadrecord(buf(), filename, recsize \ 2, index) THEN
   RETURN readbadbinstring(buf(), offset, size, skip)
  END IF
 END IF
 RETURN ""  'failure
END FUNCTION

FUNCTION isbit (bb() as integer, byval w as integer, byval b as integer) as integer
 IF readbit (bb(), w, b) THEN
  RETURN -1
 ELSE
  RETURN 0
 END IF
END FUNCTION

FUNCTION scriptname (byval num as integer, byval trigger as integer = 0) as string
DIM a as string

#ifdef IS_GAME
 'remember script names; can be a large speed up in script debugger 
 STATIC cache(24) as IntStrPair
 a = search_string_cache(cache(), num, game)
 IF LEN(a) THEN RETURN a
#endif

DIM buf(19) as integer
IF num >= 16384 AND trigger > 0 THEN
 IF loadrecord (buf(), workingdir + SLASH + "lookup" + STR(trigger) + ".bin", 20, num - 16384, NO) THEN
  DIM sname as string = readbinstring(buf(), 1, 36)
  IF buf(0) THEN
   a = sname
  ELSE
   a = "[" & sname & "]"
  END IF
  GOTO theend
 END IF
END IF

IF num THEN
 a = "[id " & STR(num) & "]"
 DIM fh as integer = FREEFILE
 OPEN workingdir & SLASH & "plotscr.lst" FOR BINARY as #fh
 WHILE loadrecord (buf(), fh, 20)
  IF buf(0) = num THEN
   a = STRING(small(large(buf(1), 0), 38), " ")
   array2str buf(), 4, a
   EXIT WHILE
  END IF
 WEND
 CLOSE fh
ELSE
 a = "[none]"
END IF

theend:
#ifdef IS_GAME
 add_string_cache cache(), num, a
#endif
return a
END FUNCTION

Function seconds2str(byval sec as integer, f as string = "%m:%S") as string
  dim ret as string
  dim as integer s, m, h
  s = sec mod 60
  m = (sec \ 60) mod 60
  h = (sec \ 3600) mod 60

  dim as integer i
  FOR i as integer = 0 to len(f) - 1
    if f[i] = asc("%") then
      i+=1
      select case as const f[i]
        case asc("s")
          ret = ret & sec
        case asc("S")
          if s < 10 then ret = ret & "0"
          ret = ret & s
        case asc("m")
          ret = ret & (sec \ 60)
        case asc("M")
          if m < 10 then ret = ret & "0"
          ret = ret & m
        case asc("h")
          ret = ret & (sec \ 3600)
        case asc("H")
          if h < 10 then ret = ret & "0"
          ret = ret & h
        case asc("%")
          ret = ret & "%"
      end select
    else
      ret = ret & chr(f[i])
    end if
  next

  return ret
end function

FUNCTION getdefaultpal(byval fileset as integer, byval index as integer) as integer
 DIM v as SHORT
 DIM f as string = workingdir & SLASH & "defpal" & fileset & ".bin"
 IF isfile(f) THEN
  DIM fh as integer = FREEFILE
  OPEN f FOR BINARY as #fh
  GET #fh, 1 + index * 2, v
  CLOSE #fh
  RETURN v
 ELSE
  'currently extended NPCs palettes are initialised to -1, which means lots of debug spam in old games
  'debug "Default palette file " & f & " does not exist"
  RETURN -1
 END IF
END FUNCTION

FUNCTION abs_pal_num(byval num as integer, byval sprtype as integer, byval spr as integer) as integer
 IF num >= 0 THEN RETURN num
 IF num = -1 THEN RETURN getdefaultpal(sprtype, spr)
 debug "decode_default_pal: invalid palette " & num
 RETURN 0
END FUNCTION

SUB loaddefaultpals(byval fileset as integer, poffset() as integer, byval sets as integer)
 DIM v as SHORT
 DIM f as string = workingdir & SLASH & "defpal" & fileset & ".bin"
 IF isfile(f) THEN
  DIM fh as integer = FREEFILE
  OPEN f FOR BINARY as #fh
  FOR i as integer = 0 to sets
   GET #fh, 1 + i * 2, v
   poffset(i) = v
  NEXT i
  CLOSE #fh
 ELSE
  guessdefaultpals fileset, poffset(), sets
 END IF
END SUB

SUB savedefaultpals(byval fileset as integer, poffset() as integer, byval sets as integer)
 DIM v as SHORT
 DIM f as string = workingdir & SLASH & "defpal" & fileset & ".bin"
 DIM fh as integer = FREEFILE
 OPEN f FOR BINARY as #fh
 FOR i as integer = 0 to sets
  v = poffset(i)
  PUT #fh, 1 + i * 2, v
 NEXT i
 CLOSE #fh
END SUB

SUB guessdefaultpals(byval fileset as integer, poffset() as integer, byval sets as integer)
 DIM her as herodef
 DIM found as integer
 
 flusharray poffset(), sets, 0
 SELECT CASE fileset
 CASE 0 'Heroes
  FOR j as integer = 0 TO gen(genMaxHero)
   loadherodata @her, j
   IF her.sprite >= 0 AND her.sprite <= sets THEN poffset(her.sprite) = her.sprite_pal
  NEXT
 CASE 1 TO 3 'Enemies
  'Inefficient
  DIM enemy as EnemyDef
  FOR j as integer = 0 TO gen(genMaxEnemy)
   loadenemydata enemy, j
   IF enemy.size + 1 = fileset THEN
    IF enemy.pic >= 0 AND enemy.pic <= sets THEN poffset(enemy.pic) = enemy.pal
   END IF
  NEXT j
 CASE 4 'Walkabouts
  FOR j as integer = 0 TO gen(genMaxHero)
   loadherodata @her, j
   IF her.walk_sprite >= 0 AND her.walk_sprite <= sets THEN
	poffset(her.walk_sprite) = her.walk_sprite_pal
   END IF
  NEXT j
  REDIM npcbuf(0) as NPCType
  FOR mapi as integer = 0 TO gen(genMaxMap)
   LoadNPCD maplumpname(mapi, "n"), npcbuf()
   FOR j as integer = 0 to UBOUND(npcbuf)
	IF npcbuf(j).picture >= 0 AND npcbuf(j).picture <= sets THEN
	 poffset(npcbuf(j).picture) = npcbuf(j).palette
	END IF
   NEXT j
  NEXT mapi
 CASE 5 'Weapons
  REDIM buf(dimbinsize(binITM)) as integer
  FOR j as integer = 0 TO gen(genMaxItem)
   loaditemdata buf(), j
   IF buf(49) = 1 THEN
    IF buf(52) >= 0 AND buf(52) <= sets THEN poffset(buf(52)) = buf(53)
   END IF
  NEXT
 CASE 6 'Attacks
  REDIM buf(40 + dimbinsize(binATTACK)) as integer
  FOR j as integer = 0 TO gen(genMaxAttack)
   loadattackdata buf(), j
   IF buf(0) >= 0 AND buf(0) <= sets THEN poffset(buf(0)) = buf(1)
  NEXT
 CASE ELSE 'Portraits and later
  'Default palettes were implemented before portraits, so this can only be called
  'the first time you ever open the portrait editor in an old game -- no point
  'implementing this
 END SELECT
END SUB

FUNCTION defbinsize (byval id as integer) as integer
 'returns the default size in BYTES to use for getbinsize() when no BINSIZE data is available at all
 IF id = 0 THEN RETURN 0  'attack.bin
 IF id = 1 THEN RETURN 64 '.stf
 IF id = 2 THEN RETURN 0  'songdata.bin
 IF id = 3 THEN RETURN 0  'sfxdata.bin
 IF id = 4 THEN RETURN 40 '.map
 IF id = 5 THEN RETURN 0  'menus.bin
 IF id = 6 THEN RETURN 0  'menuitem.bin
 IF id = 7 THEN RETURN 0  'uicolors.bin
 IF id = 8 THEN RETURN 400  '.say
 IF id = 9 THEN RETURN 30   '.n##
 IF id = 10 THEN RETURN 636 '.dt0
 IF id = 11 THEN RETURN 320 '.dt1
 IF id = 12 THEN RETURN 200 '.itm
 RETURN 0
END FUNCTION

FUNCTION curbinsize (byval id as integer) as integer
 'returns the native size in BYTES of the records for the version you are running
 IF id = 0 THEN RETURN 546 'attack.bin
 IF id = 1 THEN RETURN 84  '.stf
 IF id = 2 THEN RETURN 32  'songdata.bin
 IF id = 3 THEN RETURN 34  'sfxdata.bin
 IF id = 4 THEN RETURN 64  '.map
 IF id = 5 THEN RETURN 52  'menus.bin
 IF id = 6 THEN RETURN 64  'menuitem.bin
 IF id = 7 THEN RETURN 126 'uicolors.bin
 IF id = 8 THEN RETURN 412 '.say
 IF id = 9 THEN RETURN 34  '.n##
 IF id = 10 THEN RETURN 858 '.dt0
 IF id = 11 THEN RETURN 734 '.dt1
 IF id = 12 THEN RETURN 420 '.itm
 RETURN 0
END FUNCTION

FUNCTION getbinsize (byval id as integer) as integer
'returns the current size in BYTES of the records in the specific binary file you are working with
IF isfile(workingdir + SLASH + "binsize.bin") THEN
 DIM as short recordsize
 DIM fh as integer = FREEFILE
 OPEN workingdir + SLASH + "binsize.bin" FOR BINARY as #fh
 IF LOF(fh) < 2 * id + 2 THEN
  getbinsize = defbinsize(id)
 ELSE
  GET #fh, 1 + id * 2, recordsize
  getbinsize = recordsize
 END IF
 CLOSE #fh
ELSE
 getbinsize = defbinsize(id)
END IF

END FUNCTION

'INTS, not bytes!
FUNCTION dimbinsize (byval id as integer) as integer
 'curbinsize is size supported by current version of engine
 'getbinsize is size of records in RPG file
 dimbinsize = large(curbinsize(id), getbinsize(id)) \ 2 - 1
END FUNCTION

SUB setbinsize (byval id as integer, byval size as integer)
 DIM fh as integer = FREEFILE
 OPEN workingdir & SLASH & "binsize.bin" FOR BINARY as #fh
 PUT #fh, 1 + id * 2, CAST(short, size)
 CLOSE #fh
END SUB

'Normally gamedir will be workingdir, and sourcefile will be sourcerpg
FUNCTION readarchinym (gamedir as string, sourcefile as string) as string
 DIM iname as string
 DIM fh as integer
 IF isfile(gamedir + SLASH + "archinym.lmp") THEN
  fh = FREEFILE
  OPEN gamedir + SLASH + "archinym.lmp" FOR INPUT as #fh
  LINE INPUT #fh, iname
  CLOSE #fh
  iname = LCASE(iname)
  'IF isfile(gamedir + SLASH + iname + ".gen") THEN
   RETURN iname
  'ELSE
  ' debug gamedir + SLASH + "archinym.lmp" + " invalid, ignored"
  'END IF
 ELSE
  debuginfo gamedir + SLASH + "archinym.lmp" + " unreadable"
 END IF

 ' for backwards compatibility with ancient games that lack archinym.lmp
 iname = LCASE(trimextension(trimpath(sourcefile)))
 'IF isfile(gamedir + SLASH + iname + ".gen") = 0 THEN
 ' fatalerror "archinym.lmp unusable, and internal name could not be determined"
 'ENDIF
 RETURN iname
END FUNCTION

FUNCTION maplumpname (byval map as integer, oldext as string) as string
 IF map < 100 THEN
  return game & "." & oldext & RIGHT("0" & map, 2)
 ELSE
  return workingdir & SLASH & map & "." & oldext
 END IF
END FUNCTION

SUB fatalerror (msg as string)
 showerror msg, YES
END SUB

'cleanup: (Custom only) whether to delete working.tmp
SUB showerror (msg as string, byval isfatal as integer = NO)
 STATIC entered as integer = 0  'don't allow reentry
 IF entered THEN EXIT SUB
 entered = 1
 debug "error: " + msg
 PRINT "error: " + msg

 DIM quitmsg as string
 quitmsg = !"\n\n"   '"${K" & uilook(uiMenuItem) & "}"
 quitmsg += "An error has occurred!"
 IF isfatal THEN
  quitmsg += " Press any key to quit."
 ELSE
  quitmsg += " Press ESC to cleanly quit, or any other key to ignore the error and try to continue."
 END IF
 #IFDEF IS_CUSTOM
  IF cleanup_on_error = NO THEN
   quitmsg += !"\nThe editing state of the game will be preserved"
   IF isfatal = NO THEN quitmsg += " if you quit immediately"
   quitmsg += "; run " + CUSTOMEXE + " again and you will be asked whether you want to recover it."
  END IF
 #ENDIF
 quitmsg += !"\nIf this error is unexpected, please send an e-mail to ohrrpgce-crash@HamsterRepublic.com"

 'Reset palette (in case the error happened in a fade-to-black or due to
 'corrupt/missing palette or UI colours)
 load_default_master_palette master()
 DefaultUIColors uilook()
 setpal master()
 clearpage 0
 basic_textbox msg + quitmsg, uilook(uiText), 0
 setvispage 0

 setwait 200  'Give user a chance to let go of keys
 dowait
 DIM w as integer = getkey
 IF isfatal ORELSE w = scEsc THEN
 #IFDEF IS_CUSTOM
  IF cleanup_on_error THEN
   touchfile workingdir & SLASH & "__danger.tmp"
   killdir workingdir
  END IF

  closemusic
  restoremode

  'no need for end_debug
  SYSTEM
 #ELSE
  exitprogram 0, 1
 #ENDIF
 END IF

 #IFDEF IS_CUSTOM
  'Continuing to edit
  setwait 200  'Give user a chance to let go of keys
  dowait
  clearpage 0
  basic_textbox "Warning! If you had unsaved changes to your game you should backup the old .RPG file " _
                "before attempting to save, because there is a chance that saving will produce a corrupt file.", _
                uilook(uiText), 0
  setvispage 0
  getkey
 #ENDIF

 'Restore game's master palette (minus fades or palette changes...
 'but that's the least of your worries at this point)
 loadpalette master(), gen(genMasterPal)
 LoadUIColors uilook(), gen(genMasterPal)
 setpal master()

 entered = 0
END SUB

'Returns left edge x coord of a string centred at given x
FUNCTION xstring (s as string, byval x as integer) as integer
 return small(large(x - LEN(s) * 4, 0), 319 - LEN(s) * 8)
END FUNCTION

FUNCTION defaultint (byval n as integer, default_caption as string="default") as string
 IF n = -1 THEN RETURN default_caption
 RETURN STR(n)
END FUNCTION

FUNCTION caption_or_int (byval n as integer, captions() as string) as string
 IF n >= LBOUND(captions) AND n <= UBOUND(captions) THEN RETURN captions(n)
 RETURN STR(n)
END FUNCTION

SUB poke8bit (array16() as integer, byval index as integer, byval val8 as integer)
 IF index \ 2 > UBOUND(array16) THEN
  debug "Dang rotten poke8bit(array(" & UBOUND(array16) & ")," & index & "," & val8 & ") out of range"
  EXIT SUB
 END IF
 IF val8 <> (val8 AND &hFF) THEN
   debug "Warning: " & val8 & " is not an 8-bit number. Discarding bits: " & (val8 XOR &hFF)
   val8 = val8 AND &hFF
 END IF
 DIM element as integer = array16(index \ 2)
 DIM lb as integer = element AND &hFF
 DIM hb as integer = (element AND &hFF00) SHR 8
 IF index AND 1 THEN
  hb = val8
 ELSE
  lb = val8
 END IF
 element = lb OR (hb SHL 8)
 array16(index \ 2) = element
END SUB

FUNCTION peek8bit (array16() as integer, byval index as integer) as integer
 IF index \ 2 > UBOUND(array16) THEN
  debug "Dang rotten peek8bit(array(" & UBOUND(array16) & ")," & index & ") out of range"
  RETURN 0
 END IF
 DIM element as integer = array16(index \ 2)
 IF index AND 1 THEN
  RETURN (element AND &hFF00) SHR 8
 ELSE
  RETURN element AND &hFF
 END IF
END FUNCTION

SUB loadpalette(pal() as RGBcolor, byval palnum as integer)
IF palnum < 0 THEN
 debug "loadpalette: invalid palnum " & palnum
 palnum = 0
END IF
IF NOT isfile(workingdir + SLASH + "palettes.bin") THEN
 '.MAS fallback, palnum ignored because it doesn't matter
 DIM oldpalbuf(767) as integer
 xbload game + ".mas", oldpalbuf(), "master palette missing from " + sourcerpg
 convertpalette oldpalbuf(), pal()
ELSE
 DIM as SHORT headsize, recsize
 DIM palbuf(767) as UBYTE

 DIM fh as integer = FREEFILE
 OPEN workingdir + SLASH + "palettes.bin" FOR BINARY as #fh
 GET #fh, , headsize
 GET #fh, , recsize
 GET #fh, recsize * palnum + headsize + 1, palbuf()
 CLOSE #fh
 FOR i as integer = 0 TO 255
  pal(i).r = palbuf(i * 3)
  pal(i).g = palbuf(i * 3 + 1)
  pal(i).b = palbuf(i * 3 + 2)
 NEXT
END IF
'Uncomment the line below if you want the palette in text format for updating load_default_master_palette
'dump_master_palette_as_hex pal()
END SUB

SUB savepalette(pal() as RGBcolor, byval palnum as integer)
 DIM as SHORT headsize = 4, recsize = 768  'Defaults

 DIM fh as integer = FREEFILE
 OPEN workingdir + SLASH + "palettes.bin" FOR BINARY as #fh
 IF LOF(fh) >= 4 THEN
  GET #fh, 1, headsize
  GET #fh, 3, recsize
 ELSE
  PUT #fh, 1, headsize
  PUT #fh, 3, recsize
 END IF

 DIM palbuf(recsize - 1) as UBYTE
 FOR i as integer = 0 TO 255
  palbuf(i * 3) = pal(i).r
  palbuf(i * 3 + 1) = pal(i).g
  palbuf(i * 3 + 2) = pal(i).b
 NEXT
 PUT #fh, recsize * palnum + headsize + 1, palbuf()
 CLOSE #fh
END SUB

SUB convertpalette(oldpal() as integer, newpal() as RGBcolor)
'takes a old QB style palette (as 768 ints), translates it to
'8 bits per component and writes it to the provided RGBcolor array
DIM r as integer
DIM g as integer
DIM b as integer

FOR i as integer = 0 TO 255
 r = oldpal(i * 3)
 g = oldpal(i * 3 + 1)
 b = oldpal(i * 3 + 2)
 'newpal(i).r = r shl 2 or r shr 4
 'newpal(i).g = g shl 2 or g shr 4
 'newpal(i).b = b shl 2 or b shr 4
 newpal(i).r = iif(r, r shl 2 + 3, 0)   'Mapping as Neo suggested
 newpal(i).g = iif(g, g shl 2 + 3, 0)
 newpal(i).b = iif(b, b shl 2 + 3, 0)
NEXT
END SUB

SUB unconvertpalette()
'Takes the default new format palette and saves it in the old QB style palette
'format. This is only here to help out old graphics tools
DIM newpal(255) as RGBcolor, oldpal(767) as integer
loadpalette newpal(), gen(genMasterPal)
FOR i as integer = 0 TO 255
 oldpal(i * 3) = newpal(i).r \ 4
 oldpal(i * 3 + 1) = newpal(i).g \ 4
 oldpal(i * 3 + 2) = newpal(i).b \ 4
NEXT
xbsave game + ".mas", oldpal(), 1536
END SUB

FUNCTION getmapname (byval m as integer) as string
 DIM nameread(39) as integer
 loadrecord nameread(), game + ".mn", 40, m
 DIM a as string = STRING(small((nameread(0) AND 255), 39), " ")
 array2str nameread(), 1, a
 RETURN a
END FUNCTION

FUNCTION createminimap (map() as TileMap, tilesets() as TilesetData ptr, byref zoom as integer = -1) as Frame PTR
 'if zoom is -1, calculate and store it

 IF zoom = -1 THEN
  'auto-detect best zoom
  zoom = bound(small(vpages(vpage)->w \ map(0).wide, vpages(vpage)->h \ map(0).high), 1, 20)
 END IF

 DIM mini as Frame Ptr
 mini = frame_new(zoom * map(0).wide, zoom * map(0).high)

 DIM as SINGLE fraction
 fraction = 20 / zoom

 DIM tx as integer
 DIM ty as integer
 DIM x as integer
 DIM y as integer
 DIM block as integer
 DIM pixel as integer
 
 FOR j as integer = 0 TO zoom * map(0).high - 1
  FOR i as integer = 0 TO zoom * map(0).wide - 1
   tx = i \ zoom
   ty = j \ zoom
   x = INT(((i MOD zoom) + RND) * fraction)
   y = INT(((j MOD zoom) + RND) * fraction)
   'layers but not overhead tiles
   pixel = 0
   FOR k as integer = UBOUND(map) TO 0 STEP -1
    block = readblock(map(k), tx, ty)
    IF block = 0 AND map(k).layernum > 0 THEN CONTINUE FOR

    WITH *tilesets(k)
     IF block > 207 THEN block = (block - 48 + .tastuf(20) + .anim(1).cycle) MOD 160
     IF block > 159 THEN block = (block + .tastuf(0) + .anim(0).cycle) MOD 160
     pixel = .spr->image[block * 400 + y * 20 + x]
     IF pixel <> 0 THEN EXIT FOR
    END WITH
   NEXT
   mini->image[i + j * mini->w] = pixel
  NEXT
 NEXT

 RETURN mini
END FUNCTION

FUNCTION createminimap (layer as TileMap, tileset as TilesetData ptr, byref zoom as integer = -1) as Frame PTR
 DIM layers(0) as TileMap
 DIM tilesets(0) as TilesetData ptr
 layers(0) = layer
 tilesets(0) = tileset
 RETURN createminimap(layers(), tilesets(), zoom)
END FUNCTION

FUNCTION readattackname (byval index as integer) as string
 RETURN readbadgenericname(index, game + ".dt6", 80, 24, 10, 1)
END FUNCTION

FUNCTION readattackcaption (byval index as integer) as string
 DIM buf(40 + dimbinsize(binATTACK)) as integer
 loadattackdata buf(), index
 RETURN readbinstring(buf(), 73, 38)
END FUNCTION

FUNCTION readenemyname (byval index as integer) as string
 RETURN readbadgenericname(index, game + ".dt1", getbinsize(binDT1), 0, 16, 0)
END FUNCTION

FUNCTION readitemname (byval index as integer) as string
 RETURN readbadgenericname(index, game + ".itm", getbinsize(binITM), 0, 8, 0)
END FUNCTION

FUNCTION readitemdescription (byval index as integer) as string
 RETURN readbadgenericname(index, game + ".itm", getbinsize(binITM), 9, 35, 0)
END FUNCTION

FUNCTION readshopname (byval shopnum as integer) as string
 RETURN readbadgenericname(shopnum, game + ".sho", 40, 0, 15, 0)
END FUNCTION

FUNCTION getsongname (byval num as integer, byval prefixnum as integer = 0) as string
 DIM songd(dimbinsize(binSONGDATA)) as integer
 DIM s as string
 IF num = -1 THEN RETURN "-none-"
 s = ""
 IF prefixnum THEN s = num & " "
 setpicstuf songd(), curbinsize(binSONGDATA), -1
 loadset workingdir + SLASH + "songdata.bin", num, 0
 s = s & readbinstring(songd(), 0, 30)
 RETURN s
END FUNCTION

FUNCTION getsfxname (byval num as integer) as string
 DIM sfxd(dimbinsize(binSFXDATA)) as integer
 setpicstuf sfxd(), curbinsize(binSFXDATA), -1
 loadset workingdir & SLASH & "sfxdata.bin", num, 0
 RETURN readbinstring (sfxd(), 0, 30)
END FUNCTION

'Modify an integer according to key input (less and more are scancodes for decrementing and incrementing)
'If returninput is true, returns whether the user tried to modify the int,
'otherwise returns true only if the int actually changed.
'If autoclamp is false, n is clamped within allowable range only if a key is pressed
FUNCTION intgrabber (byref n as integer, byval min as integer, byval max as integer, byval less as integer=scLeft, byval more as integer=scRight, byval returninput as integer=NO, byval use_clipboard as integer=YES, byval autoclamp as integer=YES) as integer
 DIM as LONGINT temp = n
 intgrabber = intgrabber(temp, cast(longint, min), cast(longint, max), less, more, returninput, use_clipboard, autoclamp)
 n = temp
END FUNCTION

'See above for documentation
FUNCTION intgrabber (byref n as LONGINT, byval min as LONGINT, byval max as LONGINT, byval less as integer=scLeft, byval more as integer=scRight, byval returninput as integer=NO, byval use_clipboard as integer=YES, byval autoclamp as integer=YES) as integer
 STATIC clip as LONGINT
 DIM old as LONGINT = n
 DIM typed as integer = NO

 IF more <> 0 AND keyval(more) > 1 THEN
  n = loopvar(n, min, max, 1)
  typed = YES
 ELSEIF less <> 0 AND keyval(less) > 1 THEN
  n = loopvar(n, min, max, -1)
  typed = YES
 ELSE
  DIM sign as integer = SGN(n)
  n = ABS(n)
  IF keyval(scBackspace) > 1 THEN n \= 10: typed = YES

  DIM intext as string = getinputtext
  FOR i as integer = 0 TO LEN(intext) - 1
   IF isdigit(intext[i]) THEN
    n = n * 10 + (intext[i] - ASC("0"))
    typed = YES
   END IF
  NEXT

  IF old = 0 ANDALSO n <> 0 ANDALSO negative_zero THEN sign = -1

  IF min < 0 AND max > 0 THEN
   IF keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1 THEN
    IF n = 0 THEN
     negative_zero = YES
    ELSE
     sign = sign * -1
     typed = YES
    END IF
   END IF
   IF (keyval(scPlus) > 1 OR keyval(scNumpadPlus) > 1) AND sign < 0 THEN
    sign = sign * -1
    typed = YES
   END IF
  END IF
  IF min < 0 AND (sign < 0 OR max = 0) THEN n = -n
  'CLIPBOARD
  IF use_clipboard THEN
   IF copy_keychord() THEN clip = n
   IF paste_keychord() THEN
    n = clip
    typed = YES
   END IF
  END IF
  n = bound(n, min, max)
 END IF

 IF typed = NO AND autoclamp = NO THEN n = old

 IF typed = YES THEN negative_zero = NO

 IF returninput THEN
  RETURN typed
 ELSE
  RETURN (old <> n)
 END IF
END FUNCTION

FUNCTION zintgrabber (byref n as integer, byval min as integer, byval max as integer, byval less as integer=75, byval more as integer=77) as integer
 '--adjust for entries that are offset by +1
 '--what a hack!
 '--all entries <= 0 are special options not meant to be enumerated
 '--supply the min & max as visible, not actual range for n
 '--eg a menu with 'A' = -2, 'B' = -1, 'C' = 0, 'item 0 - item 99' = 1 - 100 would have min = -3, max = 99
 DIM old as integer = n
 DIM temp as integer = n - 1
 '--must adjust to always be able to type in a number
 IF temp < 0 THEN
  FOR i as integer = 2 TO 11
   IF keyval(i) > 1 THEN temp = 0
  NEXT i
 END IF
 intgrabber temp, min, max, less, more
 n = temp + 1
 IF old = 1 AND keyval(scBackspace) > 1 THEN n = 0

 RETURN (old <> n)
END FUNCTION

FUNCTION xintgrabber (byref n as integer, byval pmin as integer, byval pmax as integer, byval nmin as integer=1, byval nmax as integer=1, byval less as integer=scLeft, byval more as integer=scRight) as integer
 '--quite a bit of documentation required:
 '--like zintgrabber, but for cases where positive values mean one thing, negatives
 '--another, and 0 means none.

 'Requirements:  nmax <= nmin <= 0 <= pmin <= pmax
 'Omit nmax and nmin for no negative range
 'nmin to nmax is the visible range of negative values
 'eg. nmin = -1 nmax = -100: negatives indicate a number between 1 and 100
 'pmin to pmax is positive range
 'eg. 2 - 50 means n==1 is '2', n==49 is '50', and 0 - 1 means n==1 is '0' and n==2 is '1'

 DIM old as integer = n

 'calculate the range of n
 DIM as integer valmin, valmax
 IF nmin <> 1 THEN
  valmin = -1 + (nmax - nmin)
 END IF
 valmax = 1 + (pmax - pmin)

 'calculate the visible value
 DIM as integer visval, oldvisval
 IF n > 0 THEN
  visval = n + pmin - 1
 ELSEIF n < 0 THEN
  visval = n + nmin + 1
 ELSE
  visval = 0
 END IF
 oldvisval = visval

 IF more <> 0 ANDALSO keyval(more) > 1 THEN
  'easy case
  n = loopvar(n, valmin, valmax, 1)
 ELSEIF less <> 0 ANDALSO keyval(less) > 1 THEN
  'easy case
  n = loopvar(n, valmin, valmax, -1)

/'--Why on earth do we want to support negation anyway?
 ELSEIF nmin < 0 AND pmax > 0 AND _
        (keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1 OR _
        ((keyval(scPlus) > 1 OR keyval(scNumpadPlus) > 1) AND s < 0)) THEN
  'nasty case: negate n based on *displayed* value
  visval = bound(-visval, nmax, pmax)
  n = ...
'/

 ELSE
  'horrible case: change n based on *displayed* value
  visval = ABS(visval)

  IF keyval(scBackspace) > 1 THEN
   visval \= 10

   'Special case for when backspace changes to None. Isolate this case to allow
   'some sanity in the rest of the logic
   IF (oldvisval = 0) OR (n > 0 AND visval < pmin) OR (n < 0 AND -visval > nmin) THEN
    n = 0
    RETURN YES
   END IF

  ELSE
   FOR i as integer = 1 TO 9
    IF keyval(i - 1 + sc1) > 1 THEN visval = visval * 10 + i
   NEXT i
   IF keyval(sc0) > 1 THEN visval *= 10
  END IF

  'convert absolute visval back to n
  'None can become positive, but positive remains positive and negative remains negative
  IF old = 0 THEN
   IF visval <> oldvisval THEN
    visval = bound(visval, pmin, pmax)
    n = visval - pmin + 1
   END IF
  ELSEIF old > 0 THEN
   visval = bound(visval, pmin, pmax)
   n = visval - pmin + 1
  ELSE
   visval = bound(-visval, nmax, nmin)
   n = visval - nmin - 1
  END IF
 END IF

 RETURN (old <> n)
END FUNCTION

FUNCTION stredit (s as string, byref insert as integer, byval maxl as integer, byval numlines as integer=1, byval wrapchars as integer=1) as integer
 'Return value is the line that the cursor is on, or 0 if numlines=1
 'insert is the position of the cursor (range 0..LEN(s)-1), and is modified byref. Set to -1 to move automatically to end of string
 stredit = 0
 
 STATIC clip as string

 '--copy+paste support
 IF copy_keychord() THEN clip = s
 IF paste_keychord() THEN s = LEFT(clip, maxl)

 '--insert cursor movement
 IF keyval(scCtrl) = 0 THEN 'not CTRL
  IF keyval(scLeft) > 1 THEN insert = large(0, insert - 1)
  IF keyval(scRight) > 1 THEN insert = small(LEN(s), insert + 1)
 ELSE 'CTRL
  IF keyval(scLeft) > 1 THEN 'move by word
   IF insert > 0 THEN 'searching from position -1 searches from the end
    insert = INSTRREV(s, ANY !" \n", insert - 1)  'different argument order: the FB devs, they are so funny
   END IF
  END IF
  IF keyval(scRight) > 1 THEN
   insert = INSTR(insert + 1, s, ANY !" \n")
   IF insert = 0 THEN insert = LEN(s)
  END IF
  IF keyval(scHome) > 1 THEN insert = 0
  IF keyval(scEnd) > 1 THEN insert = LEN(s)
 END IF

 '--up and down arrow keys
 IF numlines > 1 THEN
  DIM wrapped as string
  wrapped = wordwrap(s, large(1, wrapchars))
  DIM lines() as string
  split(wrapped, lines())
  DIM count as integer = 0
  DIM found_insert as integer = -1
  DIM line_chars as integer
  DIM move_lines as integer = 0
  FOR i as integer = 0 TO UBOUND(lines)
   IF count + LEN(lines(i)) >= insert THEN
    found_insert = i
    line_chars = insert - count
    EXIT FOR
   END IF
   count += LEN(lines(i)) + 1
  NEXT i
  IF found_insert >= 0 THEN
   '--set return value
   stredit = found_insert
   IF keyval(scUp) > 1 THEN move_lines = -1
   IF keyval(scDown) > 1 THEN move_lines = 1
   IF keyval(scPageUp) > 1 THEN move_lines = -(numlines - 2)
   IF keyval(scPageDown) > 1 THEN move_lines = numlines - 2
   IF move_lines THEN
    found_insert = bound(found_insert + move_lines, 0, UBOUND(lines))
    insert = 0
    FOR i as integer = 0 TO found_insert - 1
     insert += LEN(lines(i)) + 1
    NEXT i
    insert += small(line_chars, LEN(lines(large(found_insert, 0))))
    '--set return value
    stredit = found_insert
   END IF
   '--end of special handling for up and down motion
  END IF
  '--Home and end keys: go to previous/next newline,
  '--unless Ctrl is pressed, which is handled above
  IF keyval(scCtrl) = 0 THEN
   IF keyval(scHome) > 1 THEN
    IF insert > 0 THEN 'searching from position -1 searches from the end
     insert = INSTRREV(s, CHR(10), insert - 1)
    END IF
   END IF
   IF keyval(scEnd) > 1 THEN
    insert = INSTR(insert + 1, s, CHR(10))
    IF insert = 0 THEN insert = LEN(s) ELSE insert -= 1
   END IF
  END IF
  '--end of special keys that only work in multiline mode
 END IF

 IF insert < 0 THEN insert = LEN(s)
 insert = bound(insert, 0, LEN(s))

 DIM pre as string = LEFT(s, insert)
 DIM post as string = RIGHT(s, LEN(s) - insert)

 '--BACKSPACE support
 IF keyval(scBackspace) > 1 AND LEN(pre) > 0 THEN
  pre = LEFT(pre, LEN(pre) - 1)
  insert = large(0, insert - 1)
 END IF

 '--DEL support
 IF keyval(scDelete) > 1 AND LEN(post) > 0 THEN post = RIGHT(post, LEN(post) - 1)

 '--adding chars
 IF LEN(pre) + LEN(post) < maxl THEN
  DIM oldlen as integer = LEN(pre)
  IF keyval(scSpace) > 1 AND keyval(scCtrl) > 0 THEN
#IFDEF IS_CUSTOM
   '--charlist support
   pre = pre & charpicker()
#ENDIF
  ELSEIF keyval(scEnter) > 1 THEN
   IF numlines > 1 THEN
    pre = pre & CHR(10)
   END IF
  ELSE
   pre = LEFT(pre & getinputtext, maxl)
  END IF
  insert += (LEN(pre) - oldlen)
 END IF

 s = pre & post
 
END FUNCTION

SUB pop_warning(s as string)
 
 '--Construct the warning UI (This will be hella easier later when the Slice Editor can save/load)
 DIM root as Slice Ptr
 root = NewSliceOfType(slRoot)
 WITH *root
  .Y = 200
  .Fill = NO
 END WITH
 DIM outer_box as Slice Ptr
 outer_box = NewSliceOfType(slContainer, root)
 WITH *outer_box
  .paddingTop = 20
  .paddingBottom = 20
  .paddingLeft = 20
  .paddingRight = 20
  .Fill = Yes
 END WITH
 DIM inner_box as Slice Ptr
 inner_box = NewSliceOfType(slRectangle, outer_box)
 WITH *inner_box
  .paddingTop = 8
  .paddingBottom = 8
  .paddingLeft = 8
  .paddingRight = 8
  .Fill = YES
  ChangeRectangleSlice inner_box, 2
 END WITH
 DIM text_area as Slice Ptr
 text_area = NewSliceOfType(slText, inner_box)
 WITH *text_area
  .Fill = YES
  ChangeTextSlice text_area, s, , , YES
 END WITH
 DIM animate as Slice Ptr
 animate = root

 '--Preserve whatever screen was already showing as a background
 DIM holdscreen as integer
 holdscreen = allocatepage
 copypage vpage, holdscreen
 copypage vpage, dpage

 DIM dat as TextSliceData Ptr
 dat = text_area->SliceData
 dat->line_limit = 15

 DIM deadkeys as integer = 25
 DIM cursor_line as integer = 0
 DIM scrollbar_state as MenuState
 scrollbar_state.size = 16

 '--Now loop displaying text
 setkeys
 DO
  setwait 17
  setkeys
  
  IF deadkeys = 0 THEN 
   IF keyval(scESC) > 1 OR enter_or_space() THEN EXIT DO
   IF keyval(scUp) > 1 THEN dat->first_line -= 1
   IF keyval(scDown) > 1 THEN dat->first_line += 1
   dat->first_line = bound(dat->first_line, 0, large(0, dat->line_count - dat->line_limit))
  END IF
  deadkeys = large(deadkeys -1, 0)

  'Animate the arrival of the pop-up
  animate->Y = large(animate->Y - 20, 0)

  DrawSlice root, dpage
  
  WITH scrollbar_state
   .top = dat->first_line
   .last = dat->line_count - 1
  END WITH
  draw_fullscreen_scrollbar scrollbar_state, , dpage

  SWAP vpage, dpage
  setvispage vpage
  copypage holdscreen, dpage
  dowait
 LOOP

 '--Animate the removal of the help screen
 DO
  setkeys
  setwait 17
  animate->Y = animate->Y + 20
  IF animate->Y > 200 THEN EXIT DO
  DrawSlice root, dpage
  SWAP vpage, dpage
  setvispage vpage
  copypage holdscreen, dpage
  dowait
 LOOP
  
 freepage holdscreen
 DeleteSlice @root
END SUB

FUNCTION prompt_for_string (byref s as string, caption as string, byval limit as integer=NO) as integer
 '--Construct the prompt UI. FIXME: redo this when the Slice Editor can save/load)
 DIM root as Slice Ptr
 root = NewSliceOfType(slRoot)
 root->Fill = YES
 DIM outer_box as Slice Ptr
 outer_box = NewSliceOfType(slRectangle, root)
 WITH *outer_box
  .AnchorHoriz = 1
  .AnchorVert = 1
  .AlignHoriz = 1
  .AlignVert = 1
  .paddingTop = 16
  .paddingBottom = 16
  .paddingLeft = 16
  .paddingRight = 16
  .Width = 300
  .Height = 64
 END WITH
 ChangeRectangleSlice outer_box, 1
 DIM caption_area as Slice Ptr
 caption_area = NewSliceOfType(slText, outer_box)
 ChangeTextSlice caption_area, caption, uilook(uiText)
 DIM inner_box as Slice Ptr
 inner_box = NewSliceOfType(slContainer, outer_box)
 WITH *inner_box
  .paddingTop = 16
  .Fill = YES
 END WITH
 DIM text_border_box As Slice Ptr
 text_border_box = NewSliceOfType(slRectangle, inner_box)
 WITH *text_border_box
  .paddingTop = 2
  .paddingBottom = 2
  .paddingLeft = 2
  .paddingRight = 2
  .Fill = YES
 END WITH
 ChangeRectangleSlice text_border_box, , uilook(uiOutline), uilook(uiText)
 DIM text_area as Slice Ptr
 text_area = NewSliceOfType(slText, text_border_box)
 WITH *text_area
  .Fill = YES
 END WITH
 ChangeTextSlice text_area, s, uilook(uiMenuItem), , , uilook(uiOutline) 

 '--Preserve whatever screen was already showing as a background
 DIM holdscreen as integer
 holdscreen = allocatepage
 copypage vpage, holdscreen

 DIM dat as TextSliceData Ptr
 dat = text_area->SliceData

 IF limit = NO THEN limit = 40

 '--Now loop while editing string
 setkeys
 DO
  setwait 40
  setkeys
  
  IF keyval(scESC) > 1 THEN
   prompt_for_string = NO
   EXIT DO
  END IF
  IF keyval(scEnter) > 1 THEN
   prompt_for_string = YES
   s = dat->s
   EXIT DO
  END IF
  strgrabber dat->s, limit

  copypage holdscreen, dpage
  DrawSlice root, dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 
 setkeys
 freepage holdscreen
 DeleteSlice @root
END FUNCTION

SUB show_help(helpkey as string)
 DIM help_str as string
 help_str = load_help_file(helpkey)
 
 '--Construct the help UI (This will be hella easier later when the Slice Editor can save/load)
 DIM help_root as Slice Ptr
 help_root = NewSliceOfType(slRoot)
 WITH *help_root
  .Y = 200
  .Fill = NO
 END WITH
 DIM help_outer_box as Slice Ptr
 help_outer_box = NewSliceOfType(slContainer, help_root)
 WITH *help_outer_box
  .paddingTop = 4
  .paddingBottom = 4
  .paddingLeft = 4
  .paddingRight = 4
  .Fill = Yes
 END WITH
 DIM help_box as Slice Ptr
 help_box = NewSliceOfType(slRectangle, help_outer_box)
 WITH *help_box
  .paddingTop = 8
  .paddingBottom = 8
  .paddingLeft = 8
  .paddingRight = 8
  .Fill = YES
  ChangeRectangleSlice help_box, 1
 END WITH
 DIM help_text as Slice Ptr
 help_text = NewSliceOfType(slText, help_box)
 WITH *help_text
  .Fill = YES
  ChangeTextSlice help_text, help_str, , , YES
 END WITH
 DIM animate as Slice Ptr
 animate = help_root

 '--Preserve whatever screen was already showing as a background
 DIM holdscreen as integer
 holdscreen = allocatepage
 copypage vpage, holdscreen
 copypage vpage, dpage

 DIM dat as TextSliceData Ptr
 dat = help_text->SliceData
 dat->line_limit = 18
 dat->insert = 0

 DIM editing as integer = NO
 DIM deadkeys as integer = 25
 DIM cursor_line as integer = 0
 DIM scrollbar_state as MenuState
 scrollbar_state.size = 17

 DIM searchstring as string

 '--Now loop displaying help
 setkeyrepeat  'reset repeat rate
 setkeys
 DO
  IF editing THEN
   setwait 30
  ELSE
   setwait 17
  END IF
  setkeys
  
  IF editing THEN  
   cursor_line = stredit(dat->s, dat->insert, 32767, dat->line_limit, help_text->Width \ 8)
   'The limit of 32767 chars is totally arbitrary and maybe not a good limit
  END IF

  IF deadkeys = 0 THEN 
   IF keyval(scESC) > 1 THEN
    '--If there are any changes to the help screen, offer to save them
    IF help_str = dat->s THEN
     EXIT DO
    ELSE
     'Prevent attempt to quit the program, stop and wait for response first
     DIM quitting as integer = keyval(-1)
     clearkey(-1)
     DIM choice as integer = twochoice("Save changes to help for """ & helpkey & """?", "Yes", "No", 0, -1)
     IF keyval(-1) THEN choice = 1  'Second attempt to quit: discard
     IF choice <> -1 THEN
      IF quitting THEN setquitflag
      IF choice = 0 THEN save_help_file helpkey, dat->s
      EXIT DO
     END IF
    END IF
   END IF

   IF editing THEN
    'Enabled while editing only, because when not, 1) scrolling to show the match
    'and 2) highlighting the match aren't easy. Delayed until TextSlice cleanup.
    IF keyval(scCTRL) > 0 AND keyval(scS) > 1 THEN
     IF prompt_for_string(searchstring, "Search") THEN
      DIM idx as integer = INSTR(dat->insert + 2, LCASE(dat->s), LCASE(searchstring))
      IF idx = 0 THEN  'wrap
       idx = INSTR(dat->s, searchstring)
      END IF
      IF idx THEN dat->insert = idx - 1
     END IF
    END IF
   END IF

   IF keyval(scE) > 1 THEN
    IF fileiswriteable(get_help_dir() & SLASH & helpkey & ".txt") THEN
     editing = YES
     dat->show_insert = YES
     ChangeRectangleSlice help_box, , uilook(uiBackground), , 0
    ELSE
     pop_warning "Your """ & get_help_dir() & """ folder is not writable. Try making a copy of it at """ & homedir & SLASH & "ohrhelp"""
    END IF
   END IF
   IF keyval(scF1) and helpkey <> "helphelp" THEN
    show_help "helphelp"
   END IF
   IF editing THEN
    dat->first_line = small(dat->first_line, cursor_line - 1)
    dat->first_line = large(dat->first_line, cursor_line - (dat->line_limit - 2))
   ELSE
    '--not editing, just browsing
    IF keyval(scUp) > 1 THEN dat->first_line -= 1
    IF keyval(scDown) > 1 THEN dat->first_line += 1
    IF keyval(scPageUp) > 1 THEN dat->first_line -= dat->line_limit - 1
    IF keyval(scPageDown) > 1 THEN dat->first_line += dat->line_limit - 1
    IF keyval(scHome) > 1 THEN dat->first_line = 0
    IF keyval(scEnd) > 1 THEN dat->first_line = dat->line_count
   END IF
   dat->first_line = bound(dat->first_line, 0, large(0, dat->line_count - dat->line_limit))
  END IF
  deadkeys = large(deadkeys -1, 0)

  'Animate the arrival of the help screen
  animate->Y = large(animate->Y - 20, 0)

  copypage holdscreen, vpage

  DrawSlice help_root, vpage
  
  WITH scrollbar_state
   .top = dat->first_line
   .last = dat->line_count - 1
  END WITH
  draw_fullscreen_scrollbar scrollbar_state, , vpage

  setvispage vpage
  dowait
 LOOP

 '--Animate the removal of the help screen
 DO
  setkeys
  setwait 17
  animate->Y = animate->Y + 20
  IF animate->Y > 200 THEN EXIT DO
  copypage holdscreen, vpage
  DrawSlice help_root, vpage
  setvispage vpage
  dowait
 LOOP
  
 freepage holdscreen
 DeleteSlice @help_root
END SUB

FUNCTION multiline_string_editor(s as string, helpkey as string="") as string
 'probably contains more code duplication than is apropriate when comared to the help_editor
 
 '--Construct the UI (loading a slice collection might be better here? but not from the RPG file!)
 DIM root as Slice Ptr
 root = NewSliceOfType(slRoot)
 WITH *root
  .Y = 200
  .Fill = NO
 END WITH
 DIM outer_box as Slice Ptr
 outer_box = NewSliceOfType(slContainer, root)
 WITH *outer_box
  .paddingTop = 4
  .paddingBottom = 4
  .paddingLeft = 4
  .paddingRight = 4
  .Fill = Yes
 END WITH
 DIM box as Slice Ptr
 box = NewSliceOfType(slRectangle, outer_box)
 WITH *box
  .paddingTop = 8
  .paddingBottom = 8
  .paddingLeft = 8
  .paddingRight = 8
  .Fill = YES
  ChangeRectangleSlice box, , uilook(uiBackground), , 0
 END WITH
 DIM text as Slice Ptr
 text = NewSliceOfType(slText, box)
 WITH *text
  .Fill = YES
  ChangeTextSlice text, s, , , YES
 END WITH
 DIM animate as Slice Ptr
 animate = root

 '--Preserve whatever screen was already showing as a background
 DIM holdscreen as integer
 holdscreen = allocatepage
 copypage vpage, holdscreen
 copypage vpage, dpage

 DIM dat as TextSliceData Ptr
 dat = text->SliceData
 dat->line_limit = 18
 dat->insert = 0
 dat->show_insert = YES

 DIM deadkeys as integer = 25
 DIM cursor_line as integer = 0
 DIM scrollbar_state as MenuState
 scrollbar_state.size = 17

 '--Now loop displaying help
 setkeyrepeat  'reset repeat rate
 setkeys
 DO
  setwait 30
  setkeys
  
  cursor_line = stredit(dat->s, dat->insert, 32767, dat->line_limit, text->Width \ 8)
  'The limit of 32767 chars is totally arbitrary and maybe not a good limit

  IF keyval(scESC) > 1 THEN
   '--If there are any changes to the help screen, offer to save them
   IF s = dat->s THEN
    EXIT DO
   ELSE
    DIM choice as integer = twochoice("Keep changes to this text?", "Yes", "No", 0, -1)
    IF choice = 1 THEN dat->s = s '--don't use changes!
    IF choice >= 0 THEN EXIT DO
   END IF
  END IF
  IF deadkeys = 0 THEN 
   IF keyval(scF1) AND helpkey <> "" THEN show_help helpkey
   dat->first_line = small(dat->first_line, cursor_line - 1)
   dat->first_line = large(dat->first_line, cursor_line - (dat->line_limit - 2))
   dat->first_line = bound(dat->first_line, 0, large(0, dat->line_count - dat->line_limit))
  END IF
  deadkeys = large(deadkeys -1, 0)

  'Animate the arrival of the help screen
  animate->Y = large(animate->Y - 20, 0)

  copypage holdscreen, vpage

  DrawSlice root, vpage
  
  WITH scrollbar_state
   .top = dat->first_line
   .last = dat->line_count - 1
  END WITH
  draw_fullscreen_scrollbar scrollbar_state, , vpage

  setvispage vpage
  dowait
 LOOP

 '--Animate the removal of the multiline text editor
 DO
  setkeys
  setwait 17
  animate->Y = animate->Y + 20
  IF animate->Y > 200 THEN EXIT DO
  copypage holdscreen, vpage
  DrawSlice root, vpage
  setvispage vpage
  dowait
 LOOP

 DIM result as string
 result = dat->s
 
 freepage holdscreen
 DeleteSlice @root
 
 RETURN result
END FUNCTION

FUNCTION multichoice(capt as string, choices() as string, byval defaultval as integer=0, byval escval as integer=-1, helpkey as string="") as integer
 DIM state as MenuState
 DIM menu as MenuDef
 ClearMenuData menu
 DIM result as integer
 DIM captlines() as string
 DIM wide as integer

 split(wordwrap(capt, 37), captlines())
 FOR i as integer = 0 TO UBOUND(captlines)
  wide = large(wide, LEN(captlines(i)))
 NEXT

 FOR i as integer = 0 TO UBOUND(choices)
  append_menu_item menu, choices(i)
 NEXT

 state.active = YES
 menu.maxrows = 10
 init_menu_state state, menu
 state.pt = defaultval
 menu.offset.Y = -20 + 5 * UBOUND(captlines)
 menu.anchor.Y = -1

 'Keep whatever was on the screen already as a background (NOTE: this doesn't always work (not necessarily vpage))
 DIM holdscreen as integer
 holdscreen = allocatepage
 copypage vpage, holdscreen

 setkeys
 DO
  setwait 55
  setkeys

  IF keyval(scEsc) > 1 THEN
   result = escval
   state.active = NO
  END IF

  IF keyval(scF1) > 1 ANDALSO LEN(helpkey) > 0 THEN
   show_help helpkey
  END IF

  IF enter_or_space() THEN
   result = state.pt
   state.active = NO
  END IF

  IF state.active = NO THEN EXIT DO
  
  usemenu state

  copypage holdscreen, vpage
  centerbox 160, 70, 16 + wide * 8, 16 + 10 * UBOUND(captlines), 2, vpage
  FOR i as integer = 0 TO UBOUND(captlines)
   edgeprint captlines(i), xstring(captlines(i), 160), 65 - 5 * UBOUND(captlines) + i * 10, uilook(uiMenuItem), vpage
  NEXT
  draw_menu menu, state, vpage
  IF LEN(helpkey) > 0 THEN
   edgeprint "F1 Help", 0, 190, uilook(uiMenuItem), vpage
  END IF
  setvispage vpage
  dowait
 LOOP
 setkeys
 freepage holdscreen
 ClearMenuData menu

 RETURN result
END FUNCTION

FUNCTION twochoice(capt as string, strA as string="Yes", strB as string="No", byval defaultval as integer=0, byval escval as integer=-1, helpkey as string="") as integer
 DIM choices(1) as string = {strA, strB}
 RETURN multichoice(capt, choices(), defaultval, escval, helpkey)
END FUNCTION

'Asks a yes-or-no pop-up question.
'(Not to be confused with yesorno(), which returns a yes/no string)
FUNCTION yesno(capt as string, byval defaultval as integer=YES, byval escval as integer=NO) as integer
 IF defaultval THEN defaultval = 0 ELSE defaultval = 1
 IF escval THEN escval = 0 ELSE escval = 1
 DIM result as integer
 result = twochoice(capt, "Yes", "No", defaultval, escval)
 IF result = 0 THEN RETURN YES
 IF result = 1 THEN RETURN NO
END FUNCTION

SUB playsongnum (byval songnum as integer)
  DIM songbase as string, songfile as string

  songbase = workingdir & SLASH & "song" & songnum
  songfile = ""
  
  IF isfile(songbase & ".mp3") THEN
    songfile = songbase & ".mp3"
  ELSEIF isfile(songbase & ".ogg") THEN
    songfile = songbase & ".ogg"
  ELSEIF isfile(songbase & ".mod") THEN
    songfile = songbase & ".mod"
  ELSEIF isfile(songbase & ".xm") THEN
    songfile = songbase & ".xm"
  ELSEIF isfile(songbase & ".s3m") THEN
    songfile = songbase & ".s3m"
  ELSEIF isfile(songbase & ".it") THEN
    songfile = songbase & ".it"
  ELSEIF isfile(songbase & ".mid") THEN
    songfile = songbase & ".mid"
  ELSEIF isfile(songbase & ".bam") THEN
    songfile = songbase & ".bam"
  ELSEIF isfile(game & "." & songnum) THEN
    songfile = game & "." & songnum ' old-style BAM naming scheme
  END IF

  if songfile = "" then exit sub
  loadsong songfile
END SUB

FUNCTION spawn_and_wait (app as string, args as string) as string
 'Run a commandline program in a terminal emulator and wait for it to finish. 
 'On Windows the program is run asynchronously and users are offered the option to kill it.
 'On other platforms the program just freezes.
 'You can of course also kill the program on all platforms with Ctrl+C
 'Returns an error message, or "" if no apparent failure

 'It may be better to pass arguments in an array (the Unix way), so that
 'we can do all the necessary quoting required for Windows here.

#IFDEF __FB_DARWIN__

 basic_textbox "Please wait, running " & trimpath(app), uilook(uiText), vpage
 setvispage vpage

 'Wow that's a crazy amount of indirection!
 'Running Terminal.app is the only way to get a terminal, but 'open' is for opening a file with an application only,
 'so we use an AppleScript script embedded in Terminal_wrapper.sh to run HSpeak

 DIM term_wrap as string = find_helper_app("Terminal_wrapper.sh")
 IF term_wrap = "" THEN RETURN missing_helper_message("Terminal_wrapper.sh")

 DIM fh as integer
 DIM dummyscript as string = tmpdir + "dummyscript" & RND * 10000 & ".sh"
 fh = FREEFILE
 OPEN dummyscript FOR OUTPUT as #fh
 PRINT #fh, "#!/bin/sh"
 PRINT #fh, "cd " & curdir()
 PRINT #fh, "clear"
 PRINT #fh, app + " " + args
 CLOSE #fh
 SHELL "chmod +x " + dummyscript
 SHELL term_wrap + " " + dummyscript
 safekill dummyscript
 RETURN ""

#ENDIF

#IFDEF __FB_WIN32__

 DIM handle as ProcessHandle
 handle = open_console_process(app, args)
 IF handle = 0 THEN
  RETURN "Could not run " & app
 END IF

 DIM dots as integer = 0
 DIM exitcode as integer
 setkeys
 DO
  setwait 400
  setkeys
  IF process_running(handle, @exitcode) = NO THEN
   cleanup_process @handle
   IF exitcode THEN
    'Error, or the user might have killed the program some other way
    RETURN trimpath(app) + " reported failure."
   END IF
   RETURN ""
  END IF
  IF keyval(scEsc) > 1 THEN
   kill_process handle
   cleanup_process @handle
   setkeys
   RETURN "User cancelled."
  END IF

  dots = (dots + 1) MOD 5
  centerbox 160, 100, 300, 36, 3, vpage
  edgeprint "Please wait, running " & trimpath(app) & STRING(dots, "."), 15, 90, uilook(uiText), vpage
  edgeprint "Press ESC to cancel", 15, 100, uilook(uiMenuItem), vpage
  setvispage vpage

  dowait
 LOOP

#ENDIF

 'Generic UNIX: xterm is everywhere, isn't it?

 'os_* process handling functions only currently implemented on Windows
 SHELL "xterm -bg black -fg gray90 -e """ & app & " " & args & """"
 RETURN ""

END FUNCTION

FUNCTION find_madplay () as string
 STATIC cached as integer = 0
 STATIC cached_app as string
 IF cached THEN RETURN cached_app
 cached_app = find_helper_app("madplay")
 cached = -1
 RETURN cached_app
END FUNCTION

FUNCTION find_oggenc () as string
 STATIC cached as integer = 0
 STATIC cached_app as string
 IF cached THEN RETURN cached_app
 cached_app = find_helper_app("oggenc")
 IF cached_app = "" THEN cached_app = find_helper_app("oggenc2")
 cached = -1
 RETURN cached_app
END FUNCTION

FUNCTION find_helper_app (appname as string) as string
'Returns an empty string if the app is not found, or the full path if it is found

'Look in the same folder as CUSTOM/GAME
IF isfile(exepath & SLASH & appname & DOTEXE) THEN RETURN exepath & SLASH & appname & DOTEXE

#IFDEF __FB_DARWIN__
IF isfile(exepath & "/support/" & appname) THEN RETURN exepath & "/support/" & appname
#ENDIF
#IFDEF __UNIX__
'--Find helper app on Unix
DIM as integer fh
DIM as string tempfile
DIM as string s
tempfile = tmpdir & "find_helper_app." & INT(RND * 10000) & ".tmp"
'Use the standard util "which" to search the path
SHELL "which " & appname & " > " & tempfile
IF NOT isfile(tempfile) THEN debug "find_helper_app(" & appname & ") failed" : RETURN ""
fh = FREEFILE
OPEN tempfile FOR INPUT as #fh
LINE INPUT #fh, s
CLOSE #fh
KILL tempfile
s = TRIM(s)
RETURN s
#ELSE
'Then look in the support subdirectory
IF isfile(exepath & "\support\" & appname & ".exe") THEN RETURN exepath & "\support\" & appname & ".exe"
RETURN ""
#ENDIF
END FUNCTION

'Not used
FUNCTION can_convert_mp3 () as integer
 IF find_madplay() = "" THEN RETURN 0
 RETURN can_convert_wav()
END FUNCTION

'Not used
FUNCTION can_convert_wav () as integer
 IF find_oggenc() = "" THEN RETURN 0
 RETURN -1 
END FUNCTION

'There is way too much stuff in this function, would probably be cleaner to remove it
FUNCTION missing_helper_message (appname as string) as string
 DIM ret as string
 DIM mult as integer = INSTR(appname, " ")

 ret = appname + DOTEXE + iif_string(mult, " are both missing (only one required).", " is missing.")

 #IFDEF __FB_WIN32__
  IF appname = "hspeak" THEN
   'support/hspeak.exe WILL work, but that's not where we package it
   ret += " Check that it is in the same folder as custom.exe."
  ELSE
   ret += " Check that it is in the support folder."
  END IF
 #ELSEIF DEFINED(__FB_DARWIN__)
  ret += " This ought to be included inside OHRRPGCE-Custom! Please report this."
 #ELSE
  ret += " You must install it on your system."
 #ENDIF

 'Linux nightly builds are full distributions, while on Windows they are missing much.
 #IF DEFINED(__FB_WIN32__)
  IF version_branch = "wip" THEN
   ret += CHR(10) + "You are using a nightly build. Did you unzip the nightly on top of a full install of a stable release, as you are meant to?"
   IF INSTR(appname, "oggenc") OR INSTR(appname, "madplay") THEN
    ret += " Alternatively, download oggenc+madplay.zip from the nightly ""alternative backends"" folder."
   END IF
  END IF
 #ENDIF
 RETURN ret
END FUNCTION

'Returns error message, or "" on success
FUNCTION mp3_to_ogg (in_file as string, out_file as string, byval quality as integer = 4) as string
 DIM as string tempwav
 DIM as string ret
 tempwav = tmpdir & "temp." & INT(RND * 100000) & ".wav"
 ret = mp3_to_wav(in_file, tempwav)
 IF LEN(ret) THEN RETURN ret
 ret = wav_to_ogg(tempwav, out_file, quality)
 safekill tempwav
 RETURN ret
END FUNCTION

'Returns error message, or "" on success
FUNCTION mp3_to_wav (in_file as string, out_file as string) as string
 DIM as string app, args, ret
 IF NOT isfile(in_file) THEN RETURN "mp3 to wav conversion: " & in_file & " does not exist"
 app = find_madplay()
 IF app = "" THEN RETURN "Can not read MP3 files: " + missing_helper_message("madplay" + DOTEXE)

 args = " -o wave:""" & out_file & """ """ & in_file & """"
 ret = spawn_and_wait(app, args)
 IF LEN(ret) THEN
  safekill out_file
  RETURN ret
 END IF

 IF NOT isfile(out_file) THEN RETURN "Could not find " + out_file + ": " + app + " must have failed"
 RETURN ""
END FUNCTION

'Returns error message, or "" on success
FUNCTION wav_to_ogg (in_file as string, out_file as string, byval quality as integer = 4) as string
 DIM as string app, args, ret
 IF NOT isfile(in_file) THEN RETURN "wav to ogg conversion: " & in_file & " does not exist"
 app = find_oggenc()
 IF app = "" THEN RETURN "Can not convert to OGG: " + missing_helper_message("oggenc" DOTEXE " and oggenc2" DOTEXE)

 args = " -q " & quality & " -o """ & out_file & """ """ & in_file & """"
 ret = spawn_and_wait(app, args)
 IF LEN(ret) THEN
  safekill out_file
  RETURN "wav to ogg conversion failed."
 END IF

 IF NOT isfile(out_file) THEN RETURN "Could not find " + out_file + ": " + app + " must have failed"
 RETURN ""
END FUNCTION

SUB upgrade_message (s as string)
 IF NOT upgrademessages THEN
  upgrademessages = -1
  reset_console 20, vpages(vpage)->h - 20
  show_message("Auto-Updating obsolete RPG file")
 END IF
 DIM temptime as DOUBLE
 IF time_rpg_upgrade THEN
  temptime = TIMER
  upgrade_overhead_time -= temptime
  IF last_upgrade_time <> 0.0 THEN
   debuginfo "...done in " & FORMAT((temptime - last_upgrade_time) * 1000, ".#") & "ms"
  END IF
 END IF
 debuginfo "rpgfix:" & s
 show_message(s)
 IF time_rpg_upgrade THEN
  temptime = TIMER
  last_upgrade_time = temptime
  upgrade_overhead_time += temptime
 END IF
END SUB

'admittedly, these 'console' functions suck
SUB reset_console (byval top as integer = 0, byval h as integer = 200, byval c as integer = -1)
 IF c = -1 THEN c = uilook(uiBackground)
 WITH console
  .top = top
  .h = h
  .x = 0
  .y = top
  .c = c
  DIM tempfr as Frame ptr
  tempfr = frame_new_view(vpages(vpage), 0, .top, vpages(vpage)->w, .h)
  frame_clear tempfr, c
  frame_unload @tempfr
 END WITH
END SUB

SUB show_message (s as string)
 WITH console
  IF .x > 0 THEN .x = 0 : .y += 8
  append_message s
 END WITH
END SUB

SUB append_message (s as string)
 DIM as integer display = YES
 IF RIGHT(TRIM(s), 1) = "," THEN display = NO
 WITH console
  IF .x > 0 AND LEN(s) * 8 + .x > vpages(vpage)->w THEN .x = 0 : .y += 8: display = YES
  IF .y >= .top + .h - 8 THEN
   'scroll page up 2 lines
   DIM as Frame ptr tempfr, copied
   tempfr = frame_new_view(vpages(vpage), 0, .top + 16, vpages(vpage)->w, .h - 16)
   copied = frame_duplicate(tempfr)
   frame_clear tempfr, .c
   frame_draw copied, , 0, .top, , NO, vpage
   .y -= 16
   frame_unload @copied
   frame_unload @tempfr
  END IF
  printstr s, .x, .y, vpage
  .x += LEN(s) * 8
  IF display THEN setvispage vpage
 END WITH
END SUB

SUB animatetilesets (tilesets() as TilesetData ptr)
 FOR i as integer = 0 TO UBOUND(tilesets)
  'Animate each tileset...
  FOR j as integer = 0 TO i - 1
   '--unless of course we already animated it for this frame
   '  because the same tileset can be used on more than one layer...
   IF tilesets(i) = tilesets(j) THEN CONTINUE FOR, FOR
  NEXT
  cycletile tilesets(i)->anim(), tilesets(i)->tastuf()
 NEXT
END SUB

SUB cycletile (tanim_state() as TileAnimState, tastuf() as integer)
 DIM notstuck as integer
 FOR i as integer = 0 TO 1
#IFDEF IS_GAME
  IF istag(tastuf(1 + 20 * i), 0) THEN CONTINUE FOR
#ENDIF
  WITH tanim_state(i)
   .skip = large(.skip - 1, 0)
   IF .skip = 0 THEN
    notstuck = 10
    DO
     SELECT CASE tastuf(2 + 20 * i + .pt)
      CASE 0
       IF .pt <> 0 THEN .cycle = 0  'this is done for the tile animation plotscript commands
       .pt = 0
      CASE 1
       .cycle = .cycle - tastuf(11 + 20 * i + .pt) * 16
       .pt = loopvar(.pt, 0, 8, 1)
      CASE 2
       .cycle = .cycle + tastuf(11 + 20 * i + .pt) * 16
       .pt = loopvar(.pt, 0, 8, 1)
      CASE 3
       .cycle = .cycle + tastuf(11 + 20 * i + .pt)
       .pt = loopvar(.pt, 0, 8, 1)
      CASE 4
       .cycle = .cycle - tastuf(11 + 20 * i + .pt)
       .pt = loopvar(.pt, 0, 8, 1)
      CASE 5
       .skip = tastuf(11 + 20 * i + .pt)
       .pt = loopvar(.pt, 0, 8, 1)
#IFDEF IS_GAME
      CASE 6
       IF istag(tastuf(11 + 20 * i + .pt), 0) THEN
        .pt = loopvar(.pt, 0, 8, 1)
       ELSE
        .pt = 0
        .cycle = 0
       END IF
#ENDIF
      CASE ELSE
       .pt = loopvar(.pt, 0, 8, 1)
     END SELECT
     notstuck = large(notstuck - 1, 0)
    LOOP WHILE notstuck AND .skip = 0
   END IF
  END WITH
 NEXT i
END SUB

FUNCTION finddatafile(filename as string) as string
'Current dir
IF isfile(filename) THEN RETURN filename
'platform-specific relative data files path (Mac OS X bundles)
IF isfile(data_dir & SLASH & filename) THEN RETURN data_dir & SLASH & filename
'same folder as executable
IF isfile(exepath & SLASH & filename) THEN RETURN exepath & SLASH & filename
#IFDEF __UNIX__
'~/.ohrrpgce/
IF isfile(tmpdir & SLASH & filename) THEN RETURN tmpdir & SLASH & filename
#IFDEF DATAFILES
IF isfile(DATAFILES & SLASH & filename) THEN RETURN DATAFILES & SLASH & filename
#ENDIF
#ENDIF
RETURN ""
END FUNCTION

FUNCTION finddatadir(dirname as string) as string
'Current dir
IF isdir(dirname) THEN RETURN dirname
'platform-specific relative data files path (Mac OS X bundles)
IF isdir(data_dir & SLASH & dirname) THEN RETURN data_dir & SLASH & dirname
'same folder as executable
IF isdir(exepath & SLASH & dirname) THEN RETURN exepath & SLASH & dirname
#IFDEF __UNIX__
'~/.ohrrpgce/
IF isdir(tmpdir & SLASH & dirname) THEN RETURN tmpdir & SLASH & dirname
#IFDEF DATAFILES
IF isdir(DATAFILES & SLASH & dirname) THEN RETURN DATAFILES & SLASH & dirname
#ENDIF
#ENDIF
RETURN ""
END FUNCTION

SUB updaterecordlength (lumpf as string, byval bindex as integer, byval headersize as integer = 0, byval repeating as integer = NO)
'If the length of records in this lump has changed (increased) according to binsize.bin, stretch it, padding records with zeroes.
'Note: does not create a lump if it doesn't exist.
'Pass 'repeating' as true when more than one lump with this bindex exists.
''headersize' is the number of bytes before the first record.

IF getbinsize(bindex) < curbinsize(bindex) THEN

 DIM oldsize as integer = getbinsize(bindex)
 DIM newsize as integer = curbinsize(bindex)

 upgrade_message trimpath(lumpf) & " record size = " & newsize

 'Only bother to do this for records of nonzero size (this implies the file doesn't exist, right?)
 IF oldsize > 0 ANDALSO isfile(lumpf) THEN

  DIM tempf as string = lumpf & ".resize.tmp"

  'This tends to break (it's a C/unix system call), hence all the paranoia
  IF rename(lumpf, tempf) THEN
   DIM err_string as string = *get_sys_err_string()  'errno would get overwritten while building the error message
   fatalerror "Impossible to upgrade game: Could not rename " & lumpf & " to " & tempf & " (exists=" & isfile(tempf) & ") Reason: " & err_string
  END IF

  DIM inputf as integer = FREEFILE
  OPEN tempf FOR BINARY as inputf
  DIM outputf as integer = FREEFILE
  OPEN lumpf FOR BINARY as outputf

  DIM records as integer = (LOF(inputf) - headersize) \ oldsize

  IF headersize > 0 THEN
   DIM headerbuf(headersize - 1) as BYTE
   GET #inputf, , headerbuf()
   PUT #outputf, , headerbuf()
  END IF

  DIM buf(newsize \ 2 - 1) as integer
  FOR i as integer = 0 TO records - 1
   loadrecord buf(), inputf, oldsize \ 2
   storerecord buf(), outputf, newsize \ 2
  NEXT

  CLOSE inputf
  CLOSE outputf
  KILL tempf
 END IF

 'If we are repeating, we need to keep the old binsize intact
 IF repeating = NO THEN setbinsize bindex, newsize

END IF
END SUB

'Clamp a value to within a range with warning
SUB clamp_value (byref value as integer, byval min as integer, byval max as integer, argname as string)
 DIM oldval as integer = value
 IF value < min THEN value = min
 IF value > max THEN value = max
 IF value <> oldval THEN debug "Clamped invalid " + argname + " value " & oldval & " to " & value
END SUB

FUNCTION passwordhash (p as string) as ushort
 'Just a simple stupid 9-bit hash.
 'The idea is just to make the password unretrieveable, without using a cryptographic hash.
 IF p = "" THEN RETURN 0
 DIM hash as ushort
 FOR i as integer = 0 TO LEN(p) - 1
  hash = hash * 3 + p[i] * 31
 NEXT
 RETURN (hash AND 511) OR 512  'Never return 0
END FUNCTION

'If someone forgets their password, call this function to generate a new one
FUNCTION generatepassword(byval hash as integer) as string
 IF hash = 0 THEN RETURN ""
 IF hash - 512 < 0 OR hash - 512 > 511 THEN RETURN "<invalid password hash " & hash & ">"
 DO
  DIM p as string = ""
  FOR i as integer = 0 TO 3
   p += CHR(ASC("a") + RND * 25)
  NEXT
  IF passwordhash(p) = hash THEN RETURN p
 LOOP
END FUNCTION

SUB writepassword (pass as string)
 gen(genPassVersion) = 257
 gen(genPW4Hash) = passwordhash(pass)

 '--Provide limited back-compat for PW3 (not possible to open a passworded
 '--file with an older version of Custom even if you know the password)
 DIM dummypw as string
 IF pass = "" THEN
  '--Write empty 3rd-style password
  dummypw = STRING(17, 0)
 ELSE
  '--Write unguessable garbage 3rd-style password
  FOR i as integer = 1 TO 17
   dummypw += CHR(CINT(RND * 254))
  NEXT i
 END IF
 gen(genPW3Rot) = 0
 str2array dummypw, gen(), 14
END SUB

'Read old-old-old password (very similar to PW3)
FUNCTION read_PW1_password () as string
 DIM rpas as string
 FOR i as integer = 1 TO gen(genPW1Length)
  IF gen(4 + i) >= 0 AND gen(4 + i) <= 255 THEN rpas = rpas + CHR(loopvar(gen(4 + i), 0, 255, gen(genPW1Offset) * -1))
 NEXT i
 RETURN rpas
END FUNCTION

'Read old-old scattertable password format
FUNCTION read_PW2_password () as string
 DIM stray(10) as integer
 DIM pass as string = STRING(20, "!")

 FOR i as integer = 0 TO gen(genPW2Length)
  setbit stray(), 0, i, readbit(gen(), 200 - 1, gen(200 + i))
 NEXT i

 array2str stray(), 0, pass
 pass = LEFT(pass, INT((gen(genPW2Length) + 1) / 8))

 RETURN rotascii(pass, gen(genPW2Offset) * -1)
END FUNCTION

FUNCTION read_PW3_password () as string
 '--read a 17-byte string from GEN at word offset 7
 '--(Note that array2str uses the byte offset not the word offset)
 DIM pass as string
 pass = STRING(17, 0)
 array2str gen(), 14, pass

 '--reverse ascii rotation / weak obfuscation
 pass = rotascii(pass, gen(genPW3Rot) * -1)

 '-- discard ascii chars lower than 32
 DIM pass2 as string = ""
 FOR i as integer = 1 TO 17
  DIM c as string = MID(pass, i, 1)
  IF ASC(c) >= 32 THEN pass2 += c
 NEXT i

 RETURN pass2
END FUNCTION

'Return true if it passes.
'Supports all password formats, because this is called before upgrade
FUNCTION checkpassword (pass as string) as integer
 IF gen(genPassVersion) > 257 THEN
  'Please let this never happen
  RETURN NO
 ELSEIF gen(genPassVersion) = 257 THEN
  RETURN (passwordhash(pass) = gen(genPW4Hash))
 ELSEIF gen(genPassVersion) = 256 THEN
  '--new format password
  RETURN (pass = read_PW3_password)
 ELSEIF gen(genVersion) >= 3 THEN
  '--old scattertable format
  RETURN (pass = read_PW2_password)
 ELSE
  '--ancient format
  RETURN (pass = read_PW1_password)
 END IF
END FUNCTION

'Used for forgotten password retrieval. Move along.
FUNCTION getpassword () as string
 IF gen(genPassVersion) = 257 THEN
  RETURN "Random password: " & generatepassword(gen(genPW4Hash))
 ELSEIF gen(genPassVersion) = 256 THEN
  RETURN read_PW3_password
 ELSEIF gen(genVersion) >= 3 THEN
  RETURN read_PW2_password
 ELSE
  RETURN read_PW1_password
 END IF 
END FUNCTION

SUB upgrade ()
DIM pal16(8) as integer
DIM o as integer
DIM p as integer
DIM y as integer
DIM temp as integer
DIM fh as integer

upgrademessages = 0
last_upgrade_time = 0.0
upgrade_start_time = TIMER
upgrade_overhead_time = 0.0

'Custom and Game should both have provided a writeable workingdir. Double check.
'(This is partially in vain, as we could crash if any of the lumps are unwriteable)
IF NOT diriswriteable(workingdir) THEN fatalerror "Upgrade failure: " + workingdir + " not writeable"

IF full_upgrade THEN
 debuginfo "Full game data upgrade..."
ELSE
 debuginfo "Partial game data upgrade..."
END IF

IF getfixbit(fixNumElements) = 0 THEN
 setfixbit(fixNumElements, 1)
 'This has to be set before we start loading and saving things
 gen(genNumElements) = 16
END IF

IF gen(genNumElements) < 1 THEN
 upgrade_message "genNumElements was " & gen(genNumElements) & ", fixing"
 gen(genNumElements) = 1
END IF

IF gen(genVersion) = 0 THEN
 upgrade_message "Ancient Pre-1999 format (1)"
 gen(genVersion) = 1
 upgrade_message "Flushing New Text Data..."
 DIM box as TextBox
 FOR o as integer = 0 TO 999
  LoadTextBox box, o
  'Zero out the data members that contained random garbage before 1999
  WITH box
   .money_tag      = 0
   .money          = 0
   .door_tag       = 0
   .door           = 0
   .item_tag       = 0
   .item           = 0
   .choice_enabled = NO
   .no_box         = NO
   .opaque         = NO
   .restore_music  = NO
   .choice(0)      = ""
   .choice_tag(0)  = 0
   .choice(1)      = ""
   .choice_tag(1)  = 0
   .menu_tag       = 0
   .vertical_offset = 0
   .shrink         = 0
   .textcolor      = 0
   .boxstyle       = 0
   .backdrop       = 0
   .music          = 0
   .menu           = 0
  END WITH
  SaveTextBox box, o
 NEXT o
END IF
IF gen(genVersion) = 1 THEN
 upgrade_message "June 18 1999 format (2)"
 gen(genVersion) = 2
 upgrade_message "Updating Door Format..."
 FOR o as integer = 0 TO 19
  IF isfile(game + ".dor") THEN xbload game + ".dor", buffer(), "No doors"
  FOR i as integer = 0 TO 299
   buffer(i) = buffer(o * 300 + i)
  NEXT i
  setpicstuf buffer(), 600, -1
  storeset game + ".dox", o, 0
 NEXT o
 upgrade_message "Enforcing default font"
 DIM font(1023) as integer
 getdefaultfont font()
 xbsave game + ".fnt", font(), 2048
 upgrade_message "rpgfix:Making AniMaptiles Backward Compatible"
 FOR i as integer = 0 TO 39
  buffer(i) = 0
 NEXT i
 FOR i as integer = 0 TO 1
  o = i * 20
  buffer(0 + o) = 112
  buffer(1 + o) = 0
  '--wait 3--
  buffer(2 + o + 0) = 5
  buffer(11 + o + 0) = 3
  '--right 1--
  buffer(2 + o + 1) = 3
  buffer(11 + o + 1) = 1
  '--wait 3--
  buffer(2 + o + 2) = 5
  buffer(11 + o + 2) = 3
  '--left 1--
  buffer(2 + o + 3) = 4
  buffer(11 + o + 3) = 1
 NEXT i
 FOR i as integer = 0 TO 14
  savetanim i, buffer()
 NEXT i
 DIM tx as integer, ty as integer
 DIM tmap as TileMap
 FOR i as integer = 0 TO gen(genMaxMap)
  upgrade_message " map " & i
  loadtilemap tmap, maplumpname(i, "t")
  FOR tx = 0 TO tmap.wide - 1
   FOR ty = 0 TO tmap.high - 1
    IF readblock(tmap, tx, ty) = 158 THEN writeblock tmap, tx, ty, 206
   NEXT ty
  NEXT tx
  savetilemap tmap, maplumpname(i, "t")
 NEXT i
 unloadtilemap tmap
END IF
'---VERSION 3---
IF gen(genVersion) = 2 THEN
 upgrade_message "July 8 1999 format (3)"
 gen(genVersion) = 3
 writepassword read_PW1_password
 'No need to remove the old password: we just overwrote it with
 'a back-compat PW3 blank/garbage password

 upgrade_message "Put record count defaults in GEN..."
 gen(genMaxHeroPic)   = 40
 gen(genMaxEnemy1Pic) = 149
 gen(genMaxEnemy2Pic) = 79
 gen(genMaxEnemy3Pic) = 29
 gen(genMaxNPCPic)    = 119
 gen(genMaxWeaponPic) = 149
 gen(genMaxAttackPic) = 99
 gen(genMaxTile)      = 14
 gen(genMaxAttack)    = 200
 gen(genMaxHero)      = 59
 gen(genMaxEnemy)     = 500
 gen(genMaxFormation) = 1000
 gen(genMaxPal)       = 99
 gen(genMaxTextbox)   = 999
END IF
'--VERSION 4--
IF gen(genVersion) = 3 THEN
 upgrade_message "Sept 15 2000 format (4)"
 gen(genVersion) = 4
 upgrade_message "Clearing New Attack Bitsets..."
 setpicstuf buffer(), 80, -1
 FOR o as integer = 0 TO gen(genMaxAttack)
  loadoldattackdata buffer(), o
  buffer(18) = 0
  IF readbit(buffer(), 20, 60) THEN buffer(18) = 1
  setbit buffer(), 20, 2, 0
  FOR i as integer = 21 TO 58
   setbit buffer(), 20, i, 0
  NEXT i
  FOR i as integer = 60 TO 63
   setbit buffer(), 20, i, 0
  NEXT i
  saveoldattackdata buffer(), o
 NEXT o
 setbit gen(), genBits, 6, 0 'no hide readymeter
 setbit gen(), genBits, 7, 0 'no hide health meter
END IF
'--VERSION 5--
IF gen(genVersion) = 4 THEN
 upgrade_message "March 31 2001 format (5)"
 gen(genVersion) = 5
 upgrade_message "Upgrading 16-color Palette Format..."
 setpicstuf pal16(), 16, -1
 xbload game + ".pal", buffer(), "16-color palettes missing from " + sourcerpg
 KILL game + ".pal"
 '--find last used palette
 DIM last as integer = 99
 DIM foundpal as integer = 0
 FOR j as integer = 99 TO 0 STEP -1
  FOR i as integer = 0 TO 7
   IF buffer(j * 8 + i) <> 0 THEN
    last = j
    foundpal = 1
    EXIT FOR
   END IF
  NEXT i
  IF foundpal THEN EXIT FOR
 NEXT j
 upgrade_message "Last used palette is " & last
 '--write header
 pal16(0) = 4444
 pal16(1) = last
 FOR i as integer = 2 TO 7
  pal16(i) = 0
 NEXT i
 storeset game + ".pal", 0, 0
 '--convert palettes
 FOR j as integer = 0 TO last
  FOR i as integer = 0 TO 7
   pal16(i) = buffer(j * 8 + i)
  NEXT i
  storeset game + ".pal", 1 + j, 0
 NEXT j
 'esperable (2003) introduced the bug where harm tiles no longer damage the
 'whole active party if the caterpillar is disabled. Fixed for alectormancy.
 'The best we can do is not emulating the bug for versions before March 2001 :(
 setbit gen(), genBits2, 12, 1  'Harm tiles harm non-caterpillar heroes
END IF
'--VERSION 6--
IF gen(genVersion) = 5 THEN
 upgrade_message "Serendipity format (6)"
 'Shop stuff and song name formats changed, MIDI music added
 'Sub version info also added
 'Clear battle formation animation data
 FOR i as integer = 0 TO gen(genMaxFormation)
  setpicstuf buffer(), 80, -1
  loadset game + ".for", i, 0
  buffer(34) = 0
  buffer(35) = 0
  storeset game + ".for", i, 0
 NEXT i
 gen(genVersion) = 6
END IF
'--VERSION 7 and up!
' It is a good idea to increment this number each time a major feature
' has been added, if opening a new game in an old editor would cause data-loss
' Don't be afraid to increment this. Backcompat warnings are a good thing!
IF gen(genVersion) < CURRENT_RPG_VERSION THEN
 upgrade_message "Bumping RPG format version number from " & gen(genVersion) & " to " & CURRENT_RPG_VERSION
 gen(genVersion) = CURRENT_RPG_VERSION '--update me in const.bi
END IF

IF NOT isfile(workingdir + SLASH + "archinym.lmp") THEN
 upgrade_message "generate default archinym.lmp"
 '--create archinym information lump
 fh = FREEFILE
 OPEN workingdir + SLASH + "archinym.lmp" FOR OUTPUT as #fh
 PRINT #fh, RIGHT(game, LEN(game) - LEN(workingdir + SLASH))
 PRINT #fh, version + "(previous)"
 CLOSE #fh
END IF

'This is corruption recovery, not upgrade, but Custom has always done this
IF NOT isfile(game + ".fnt") THEN
 debug game + ".fnt missing (which should never happen)"
 DIM font(1023) as integer
 getdefaultfont font()
 xbsave game + ".fnt", font(), 2048
END IF

IF NOT isfile(game + ".veh") THEN
 upgrade_message "add vehicle data"
 '--make sure vehicle lump is present
 DIM templatefile as string = finddatafile("ohrrpgce.new")
 IF templatefile <> "" THEN
  unlumpfile(templatefile, "ohrrpgce.veh", tmpdir)
  'Recall it's best to avoid moving files across filesystems
  copyfile tmpdir & SLASH & "ohrrpgce.veh", game & ".veh"
  safekill tmpdir & SLASH & "ohrrpgce.veh"
  gen(genMaxVehicle) = 2
 END IF
END IF

'--make sure binsize.bin is full. why are we doing this? Otherwise as lumps are upgraded
'--and binsize.bin is extended, records in binsize which are meant to default
'--because they don't exist would become undefined instead
FOR i as integer = 0 TO sizebinsize
 setbinsize i, getbinsize(i)
NEXT

IF NOT isfile(workingdir + SLASH + "attack.bin") THEN
 upgrade_message "Init extended attack data..."
 setbinsize binATTACK, curbinsize(binATTACK)
 flusharray buffer(), dimbinsize(binAttack), 0
 FOR i as integer = 0 TO gen(genMaxAttack)
  savenewattackdata buffer(), i
 NEXT i

 '--and while we are at it, clear the old death-string from enemies
 upgrade_message "Re-init recycled enemy data..."
 FOR i as integer = 0 TO gen(genMaxEnemy)
  loadenemydata buffer(), i
  FOR j as integer = 17 TO 52
   buffer(j) = 0
  NEXT j
  saveenemydata buffer(), i
 NEXT i
END IF

IF NOT isfile(workingdir + SLASH + "songdata.bin") THEN
 upgrade_message "Upgrading Song Name format..."
 DIM song(99) as string
 fh = FREEFILE
 OPEN game + ".sng" FOR BINARY as #fh
 temp = LOF(fh)
 CLOSE #fh
 IF temp > 0 THEN
  fh = FREEFILE
  OPEN game + ".sng" FOR INPUT as #fh
  FOR i as integer = 0 TO 99
   INPUT #fh, song(i)
  NEXT i
  CLOSE #fh
 END IF

 FOR i as integer = 99 TO 1 STEP -1
  '-- check for midis as well 'cause some people might use a WIP custom or whatnot
  IF song(i) <> "" OR isfile(game + "." + STR(i)) OR isfile(workingdir + SLASH + "song" + STR(i) + ".mid") THEN
   gen(genMaxSong) = i
   EXIT FOR
  END IF
 NEXT

 setbinsize binSONGDATA, curbinsize(binSONGDATA)
 flusharray buffer(), dimbinsize(binSONGDATA), 0
 setpicstuf buffer(), curbinsize(binSONGDATA), -1
 FOR i as integer = 0 TO gen(genMaxSong)
  writebinstring song(i), buffer(), 0, 30
  storeset workingdir + SLASH + "songdata.bin", i, 0
 NEXT
 ERASE song
END IF

'Safety-check for negative gen(genMasterPal) because of one known game that somehow had -2
gen(genMasterPal) = large(0, gen(genMasterPal))

IF NOT isfile(workingdir + SLASH + "palettes.bin") THEN
 upgrade_message "Upgrading Master Palette format..."
 IF NOT isfile(game + ".mas") THEN
  debug "Warning: " & game & ".mas does not exist (which should never happen)"
  load_default_master_palette master()
 ELSE
  loadpalette master(), 0  'Loads from .mas
 END IF
 savepalette master(), 0  'Saves to palettes.bin
END IF
'This is not necessary in the slightest, but we copy the default master palette
'back to the .MAS lump, to give old graphics utilities some chance of working
unconvertpalette()

IF gen(genHeroWeakHP) = 0 THEN
 gen(genHeroWeakHP) = 20
END IF

IF gen(genEnemyWeakHP) = 0 THEN
 gen(genEnemyWeakHP) = 20
END IF

'--If no stf lump exists, create an empty one.
IF NOT isfile(game + ".stf") THEN touchfile game + ".stf"

'--check variable record size lumps and reoutput them if records have been extended
'--all of the files below should exist, be non zero length and have non zero record size by this point
updaterecordlength workingdir + SLASH + "attack.bin", binATTACK
updaterecordlength game + ".stf", binSTF
updaterecordlength workingdir + SLASH + "songdata.bin", binSONGDATA
updaterecordlength workingdir + SLASH + "sfxdata.bin", binSFXDATA
updaterecordlength game + ".map", binMAP
updaterecordlength workingdir + SLASH + "menus.bin", binMENUS
updaterecordlength workingdir + SLASH + "menuitem.bin", binMENUITEM
IF NOT isfile(workingdir + SLASH + "menuitem.bin") THEN
 upgrade_message "Creating default menu file..."
 DIM menu_set as MenuSet
 menu_set.menufile = workingdir + SLASH + "menus.bin"
 menu_set.itemfile = workingdir + SLASH + "menuitem.bin"
 DIM menu as MenuDef
 create_default_menu menu
 SaveMenuData menu_set, menu, 0
 ClearMenuData menu
END IF
updaterecordlength game & ".say", binSAY
updaterecordlength game & ".dt0", binDT0
updaterecordlength game & ".dt1", binDT1
updaterecordlength game & ".itm", binITM
'Don't update .N binsize until all records have been stretched
FOR i as integer = 0 TO gen(genMaxMap)
 updaterecordlength maplumpname(i, "n"), binN, 7, YES
NEXT
setbinsize binN, curbinsize(binN)

'If you want to add more colours to uicolors.bin, you'll want to record what the old
'record length was (one record per palette), then updaterecordlength, then fill in
'the new colours, which start zeroed out.
'However, if uicolors.bin is completely empty/missing, then just let the block below
'initialise the lump.
updaterecordlength workingdir + SLASH + "uicolors.bin", binUICOLORS

'--give each palette a default ui color set
DIM uirecords as integer = FILELEN(workingdir + SLASH + "uicolors.bin") \ getbinsize(binUICOLORS)
IF uirecords < gen(genMaxMasterPal) + 1 THEN
 upgrade_message "Adding default UI colors..."
 DIM defaultcols(uiColors) as integer
 OldDefaultUIColors defaultcols()
 FOR i as integer = uirecords TO gen(genMaxMasterPal)
  SaveUIColors defaultcols(), i
 NEXT
END IF

IF gen(genPassVersion) = 256 THEN
 '--Update PW3 to PW4
 upgrade_message "Updating PW3 password storage format"
 writepassword read_PW3_password
ELSEIF gen(genPassVersion) < 256 THEN
 '--At this point we know the password format is PW2 (not PW1), scattertable
 upgrade_message "Updating PW2 password storage format"
 writepassword read_PW2_password

 '--Zero out PW2 scatter table
 FOR i as integer = 199 TO 359
  gen(i) = 0
 NEXT
END IF

'Zero out new attack item cost (ammunition) data
IF getfixbit(fixAttackitems) = 0 THEN
  upgrade_message "Zero new ammunition data..."
  setfixbit(fixAttackitems, 1)
  fh = freefile
  OPEN workingdir + SLASH + "attack.bin" FOR BINARY as #FH
  REDIM dat(curbinsize(binATTACK)/2 - 1) as SHORT
  p = 1
  FOR i as integer = 0 to gen(genMaxAttack)

    GET #fh,p,dat()
    FOR y = 53 TO 59
      dat(y) = 0
    NEXT

    PUT #fh,p,dat()
    p+=curbinsize(binATTACK)
  NEXT
  CLOSE #fh
END IF

IF getfixbit(fixWeapPoints) = 0 THEN
 upgrade_message "Reset hero hand points..."
 DO
  setfixbit(fixWeapPoints, 1)
  fh = freefile
  OPEN game + ".dt0" FOR BINARY as #fh
  REDIM dat(dimbinsize(binDT0)) as SHORT
  FOR i as integer = 0 to gen(genMaxHero)
   GET #fh,,dat()
   IF dat(297) <> 0 OR dat(298) <> 0 OR dat(299) <> 0 OR dat(300) <> 0 THEN
    close #fh
    EXIT DO 'they already use hand points, abort!
   END IF
  NEXT
  
  p = 1
  DIM recsize as integer = getbinsize(binDT0)
  FOR i as integer = 0 to gen(genMaxHero)
   GET #fh, p, dat()
   dat(297) = 24
   dat(299) = -20
   PUT #fh, p, dat()
   p += recsize
  NEXT
  close #fh
  EXIT DO
 LOOP
END IF

'Upgrade attack data
DIM fix_stun as integer = (getfixbit(fixStunCancelTarg) = 0)
DIM fix_dam_mp as integer = (getfixbit(fixRemoveDamageMP) = 0) AND full_upgrade
DIM fix_elem_fails as integer = (getfixbit(fixAttackElementFails) = 0) AND full_upgrade
IF fix_stun OR fix_dam_mp OR fix_elem_fails THEN
 IF fix_stun THEN
  upgrade_message "Target disabling old stun attacks..."
  setfixbit(fixStunCancelTarg, 1)
 END IF
 IF fix_dam_mp THEN
  upgrade_message "Remove obsolete 'Damage MP' bit..."
  setfixbit(fixRemoveDamageMP, 1)
 END IF
 IF fix_elem_fails THEN
  upgrade_message "Initialised attack elemental failure conditions..."
  setfixbit(fixAttackElementFails, 1)
 END IF
 REDIM dat(40 + dimbinsize(binATTACK)) as integer
 DIM cond as AttackElementCondition
 FOR i as integer = 0 to gen(genMaxAttack)
  DIM saveattack as integer = NO
  loadattackdata dat(), i

  IF fix_stun AND dat(18) = 14 THEN '--Target stat is stun register
   IF readbit(dat(), 20, 0) THEN GOTO skipfix '--cure instead of harm
   IF dat(5) = 5 OR dat(5) = 6 THEN '--set to percentage
    IF dat(11) >= 0 THEN GOTO skipfix '-- set to >= 100%
   END IF
   'Turn on the disable target attack bit
   setbit dat(), 65, 12, YES
   saveattack = YES
  END IF
  skipfix:

  IF fix_dam_mp THEN
   IF readbit(dat(), 20, 60) THEN '--Damage MP
    setbit dat(), 20, 60, NO
    saveattack = YES
    IF dat(18) = statHP THEN dat(18) = statMP
   END IF
  END IF

  IF fix_elem_fails THEN
   FOR j as integer = 0 TO 63
    loadoldattackelementalfail cond, dat(), j
    SerAttackElementCond cond, dat(), 121 + j * 3
   NEXT
   saveattack = YES
  END IF

  IF saveattack THEN saveattackdata dat(), i
 NEXT
END IF

IF getfixbit(fixDefaultDissolve) = 0 THEN
 upgrade_message "Initializing default enemy fade..."
 setfixbit(fixDefaultDissolve, 1)
 gen(genEnemyDissolve) = 0
END IF

IF getfixbit(fixDefaultDissolveEnemy) = 0 THEN
 upgrade_message "Initializing default enemy fade (per enemy)..."
 setfixbit(fixDefaultDissolveEnemy, 1)
 DIM enemy as EnemyDef
 FOR i as integer = 0 to gen(genMaxEnemy)
  loadenemydata enemy, i
  enemy.dissolve = 0
  enemy.dissolve_length = 0
  saveenemydata enemy, i
 NEXT
END IF

IF getfixbit(fixPushNPCBugCompat) = 0 THEN
 upgrade_message "Enabling 'Simulate pushable NPC bug' bitset..."
 setfixbit(fixPushNPCBugCompat, 1)
 setbit gen(), genBits2, 0, 1 ' For backcompat
END IF

IF getfixbit(fixDefaultMaxItem) = 0 THEN
 upgrade_message "Store max item number in GEN..."
 setfixbit(fixDefaultMaxItem, 1)
 gen(genMaxItem) = 254
END IF

IF getfixbit(fixBlankDoorLinks) = 0 THEN
 upgrade_message "Disable redundant blank door links..."
 setfixbit(fixBlankDoorLinks, 1)
 DIM doorlink_temp(199) as DoorLink
 DIM found_first as integer
 FOR i as integer = 0 TO gen(genMaxMap)
  deserDoorLinks maplumpname(i, "d"), doorlink_temp()
  found_first = NO
  FOR j as integer = 0 TO UBOUND(doorlink_temp)
   WITH doorlink_temp(j)
    IF .source = 0 AND .tag1 = 0 AND .tag2 = 0 THEN
     IF found_first = NO THEN
      'Ignore the first "always" link for door 0
      found_first = YES
     ELSE
      IF .dest = 0 AND .dest_map = 0 THEN
       .source = -1 ' Mark redundant all-zero links as unused
      END IF
     END IF
    END IF
   END WITH
  NEXT j
  serDoorLinks maplumpname(i, "d"), doorlink_temp()
 NEXT i
END IF

IF getfixbit(fixShopSounds) = 0 THEN
 upgrade_message "Set default soundeffects..."
 setfixbit(fixShopSounds, 1)
 gen(genItemLearnSFX) = gen(genAcceptSFX)
 gen(genCantLearnSFX) = gen(genCancelSFX)
 gen(genBuySFX) = gen(genAcceptSFX)
 gen(genHireSFX) = gen(genAcceptSFX)
 gen(genSellSFX) = gen(genAcceptSFX)
 gen(genCantBuySFX) = gen(genCancelSFX)
 gen(genCantSellSFX) = gen(genCancelSFX)
END IF

IF getfixbit(fixExtendedNPCs) = 0 THEN
 upgrade_message "Initialize extended NPC data..."
 setfixbit(fixExtendedNPCs, 1)
 REDIM npctemp(0) as NPCType 
 FOR i as integer = 0 TO gen(genMaxMap)
  ' These are the garbage data left over from somewhere in the late 90's when
  ' James decided to make the .N lumps big enough to hold 100 NPC definitions
  ' even though there was only enough memory available for 36 NPC sprites at a time
  LoadNPCD maplumpname(i, "n"), npctemp()
  REDIM PRESERVE npctemp(35)
  SaveNPCD maplumpname(i, "n"), npctemp()
 NEXT i
END IF

IF getfixbit(fixHeroPortrait) = 0 OR getfixbit(fixHeroElementals) = 0 THEN
 DIM as integer do_portraits = (getfixbit(fixHeroPortrait) = 0)
 DIM as integer do_elements = (getfixbit(fixHeroElementals) = 0)
 setfixbit(fixHeroPortrait, 1)
 setfixbit(fixHeroElementals, 1)

 DIM as string msgtemp = "Initialize hero "
 IF do_portraits THEN msgtemp += "portraits"
 IF do_portraits AND do_elements THEN msgtemp += " and "
 IF do_elements THEN msgtemp += "elemental resists"
 upgrade_message msgtemp

 DIM her as HeroDef
 FOR i as integer = 0 TO gen(genMaxHero)
  loadherodata @her, i

  WITH her
   IF do_portraits THEN
    .portrait = -1 'Disable
    .portrait_pal = -1 'Default
   END IF

   IF do_elements THEN
    '.elementals() not initialised, load from old bits
    FOR i as integer = 0 TO small(7, gen(genNumElements) - 1)
     .elementals(i) = backcompat_element_dmg(xreadbit(.bits(), i), xreadbit(.bits(), 8 + i), xreadbit(.bits(), 16 + i))
    NEXT
    'gen(genNumElements) will be more than 8 even in old games after enemytypes are converted to elements
    FOR i as integer = 8 TO gen(genNumElements) - 1
     .elementals(i) = 1
    NEXT
   END IF
  END WITH

  saveherodata @her, i
 NEXT i
END IF

'This fixbit was introduced at the same time as textbox portraits,
'so if it's not on, then the game doesn't use portraits, so it doesn't
'need to be fixed for Game.
IF full_upgrade AND getfixbit(fixTextBoxPortrait) = 0 THEN
 upgrade_message "Initialize text box portrait data..."
 setfixbit(fixTextBoxPortrait, 1)
 'DIM box as TextBox
 DIM boxbuf(dimbinsize(binSAY)) as integer
 DIM recsize as integer = getbinsize(binSAY) \ 2
 fh = FREEFILE
 OPEN game & ".say" FOR BINARY ACCESS READ WRITE as #fh
 FOR i as integer = 0 TO gen(genMaxTextBox)
  'This was stupefying slow, by far the slowest of all upgrades
  'LoadTextBox box, i
  'box.portrait_pal = -1 'Default palette
  'SaveTextBox box, i
  loadrecord boxbuf(), fh, recsize, i
  boxbuf(202) = -1 'Default palette
  storerecord boxbuf(), fh, recsize, i
 NEXT i
 CLOSE #fh
END IF

IF getfixbit(fixInitDamageDisplay) = 0 THEN
 upgrade_message "Initialize damage display time/distance data..."
 setfixbit(fixInitDamageDisplay, 1)
 gen(genDamageDisplayTicks) = 7
 gen(genDamageDisplayRise) = 14
END IF

IF getfixbit(fixDefaultLevelCap) = 0 THEN
 upgrade_message "Set level cap to 99..."
 setfixbit(fixDefaultLevelCap, 1)
 gen(genLevelCap) = 99
END IF

IF getfixbit(fixDefaultMaxLevel) = 0 THEN
 upgrade_message "Set max level to 99..."
 setfixbit(fixDefaultMaxLevel, 1)
 gen(genMaxLevel) = 99
END IF

IF getfixbit(fixOldElementalFailBit) = 0 THEN
 upgrade_message "Enabling 'Simulate old fail vs. element resist bit' bitset"
 setfixbit(fixOldElementalFailBit, 1)
 setbit gen(), genBits2, 9, 1
END IF

IF full_upgrade ANDALSO getfixbit(fixEnemyElementals) = 0 THEN
 upgrade_message "Initialising enemy elemental resists..."
 setfixbit(fixEnemyElementals, 1)
 REDIM dat(dimbinsize(binDT1)) as integer
 FOR i as integer = 0 TO gen(genMaxEnemy)
  loadenemydata dat(), i
  FOR j as integer = 0 TO 63
   SerSingle(dat(), 239 + j*2, loadoldenemyresist(dat(), j))
  NEXT
  saveenemydata dat(), i
 NEXT
END IF

IF full_upgrade ANDALSO getfixbit(fixItemElementals) = 0 THEN
 upgrade_message "Initialising equipment elemental resists..."
 setfixbit(fixItemElementals, 1)
 REDIM dat(dimbinsize(binITM)) as integer
 FOR i as integer = 0 TO gen(genMaxItem)
  loaditemdata dat(), i
  FOR j as integer = 0 TO 63
   SerSingle(dat(), 82 + j*2, LoadOldItemElemental(dat(), j))
  NEXT
  saveitemdata dat(), i
 NEXT
END IF

'Update record-count for all fixed-length lumps.
IF time_rpg_upgrade THEN upgrade_message "Updating record counts"
FOR i as integer = 0 TO 8
 fix_sprite_record_count i
NEXT i
fix_record_count gen(genMaxTile),     320 * 200, game & ".til", "Tilesets"
fix_record_count gen(genNumBackdrops), 320 * 200, game & ".mxs", "Backdrops", , -1
'FIXME: .dt0 lump is always padded up to 60 records
'fix_record_count gen(genMaxHero),     getbinsize(binDT0), game & ".dt0", "Heroes"
'FIXME: Attack data is split over two lumps. Must handle mismatch
fix_record_count gen(genMaxEnemy),     getbinsize(binDT1), game & ".dt1", "Enemies"
fix_record_count gen(genMaxFormation), 80, game & ".for", "Battle Formations"
fix_record_count gen(genMaxPal),       16, game & ".pal", "16-color Palettes", 16
fix_record_count gen(genMaxTextbox),   getbinsize(binSAY), game & ".say", "Text Boxes"
fix_record_count gen(genMaxVehicle),   80, game & ".veh", "Vehicles"
fix_record_count gen(genMaxTagname),   42, game & ".tmn", "Tag names", -84 'Note: no records for tags 0 and 1, so we handle that with a negative header size.
'FIXME: What is wrong with my menu record sizes?
'fix_record_count gen(genMaxMenu),      getbinsize(binMENUS), workingdir & SLASH & "menus.bin", "Menus"
'fix_record_count gen(genMaxMenuItem),  getbinsize(binMENUITEM), workingdir & SLASH & "menus.bin", "Menu Items"
fix_record_count gen(genMaxItem), getbinsize(binITM), game & ".itm", "Items"
'Warning: don't deduce number of map from length of .MAP or .MN: may be appended with garbage

IF time_rpg_upgrade THEN
 upgrade_message "Upgrades complete."
 debuginfo "Total upgrade time = " & FORMAT(TIMER - upgrade_start_time, ".###") & "s, time wasted on messages = " & FORMAT(upgrade_overhead_time, ".###") & "s"
END IF

IF gen(genErrorLevel) = 0 THEN
 #IFDEF IS_CUSTOM
  IF twochoice("Set script error reporting level to new default, showing all warnings and error messages?", "Yes (Best)", "No (Safest)", 1, 1, "script_error_new_default") = 0 THEN
   gen(genErrorLevel) = 2
  ELSE
   gen(genErrorLevel) = 5
  END IF
 #ELSE
  gen(genErrorLevel) = 5
 #ENDIF
END IF

'Save changes to GEN lump (important when exiting to the title screen and loading a SAV)
xbsave game + ".gen", gen(), 1000

'wow! this is quite a big and ugly routine!
END SUB

SUB fix_record_count(byref last_rec_index as integer, byref record_byte_size as integer, lumpname as string, info as string, byval skip_header_bytes as integer=0, byval count_offset as integer=0)
 DIM rec_count as integer = last_rec_index + 1 + count_offset
 IF NOT isfile(lumpname) THEN
  'debug "fix_record_count: " & info & " lump " & trimpath(lumpname) & " does not exist." 
  EXIT SUB
 END IF
 DIM fh as integer
 fh = FREEFILE
 OPEN lumpname FOR BINARY ACCESS READ as #fh
 DIM total_bytes as integer = LOF(fh) - skip_header_bytes
 CLOSE #fh
 IF total_bytes MOD record_byte_size <> 0 THEN
  DIM diffsize as integer
  diffsize = total_bytes - record_byte_size * rec_count
  DIM mismatch as string
  IF diffsize < 0 THEN
   mismatch = "file short by " & diffsize & " bytes"
  ELSE
   mismatch = "file long by " & diffsize & " bytes"
  END IF
  debug "fix_record_count mismatch for " & info & " lump, " & total_bytes & " is not evenly divisible by " & record_byte_size & " (" & mismatch & ")"
  '--expand the lump to have a valid total size
  fh = FREEFILE
  OPEN lumpname FOR BINARY as #fh
  DO WHILE total_bytes MOD record_byte_size <> 0
   total_bytes += 1
   PUT #fh, skip_header_bytes + total_bytes, CHR(0)
  LOOP
  CLOSE #fh
  debug "Expanded " & info & " lump to " & total_bytes & " bytes"
 END IF
 DIM records as integer = total_bytes / record_byte_size
 IF records <> rec_count THEN
  upgrade_message "Adjusting record count for " & info & " lump, " & rec_count & " -> " & records & " (" & records - rec_count & ")"
  last_rec_index = records - 1 - count_offset
 END IF
END SUB

SUB fix_sprite_record_count(byval pt_num as integer)
 WITH sprite_sizes(pt_num)
  DIM bytes as integer = .size.x * .size.y * .frames / 2 '--we divide by 2 because there are 2 pixels per byte
  DIM lump as string = game & ".pt" & pt_num
  fix_record_count gen(.genmax), bytes, lump, .name & " sprites"
 END WITH
END SUB

SUB future_rpg_warning ()
 'This sub displays forward-compat warnings when a new RPG file is loaded in
 'an old copy of game, or an old version of custom (ypsiliform or newer)

#IFDEF IS_GAME
 IF running_as_slave THEN
  'No version differences allowable!
  show_wrong_spawned_version_error
 END IF
#ENDIF

 'future_rpg_warning can get called multiple times per game
 STATIC warned_sourcerpg as string
 IF sourcerpg = warned_sourcerpg THEN EXIT SUB
 warned_sourcerpg = sourcerpg

 debug "Unsupported RPG file!"

 DIM hilite as string = "${K" & uilook(uiText) & "}"
 DIM msg as string = hilite + "Unsupported RPG File ${K-1}"
 msg += !"\n\nThis game has features that are not supported in this version of the OHRRPGCE. Download the latest version at http://HamsterRepublic.com\n"
 msg += "Press any key to continue, but "
 #IFDEF IS_GAME
  msg += "be aware that some things might not work right..."
 #ELSE
  msg += hilite + "DO NOT SAVE the game${K-1}, as this will lead to almost certain data corruption!!"
 #ENDIF
 clearpage 0
 basic_textbox msg, uilook(uiMenuItem), 0
 setvispage 0
 fadein
 waitforanykey
 #IFDEF IS_GAME
'  fadeout 0, 0, 0
 #ENDIF
END SUB

'Check for corruption and unsupported RPG features (maybe someone forgot to update CURRENT_RPG_VERSION)
SUB rpg_sanity_checks

 'Check binsize.bin is not from future
 DIM flen as integer = filelen(workingdir + SLASH + "binsize.bin")
 IF flen > 2 * (sizebinsize + 1) THEN
  debug "binsize.bin length " & flen
  future_rpg_warning
 ELSE
  FOR bindex as integer = 0 TO sizebinsize
   IF curbinsize(bindex) MOD 2 <> 0 THEN
    'curbinsize is INSANE, scream bloody murder to prevent data corruption!
    fatalerror "Oh noes! curbinsize(" & bindex & ")=" & curbinsize(bindex) & " Please complain to the devs, who may have just done something stupid!"
   END IF
   DIM binsize as integer = getbinsize(bindex)
   IF binsize > curbinsize(bindex) THEN
    debug "getbinsize(" & bindex & ") = " & binsize & ", but curbinsize = " & curbinsize(bindex)
    future_rpg_warning
   END IF
  NEXT
 END IF

 'Check fixbits.bin is not from future
 DIM maxbits as integer = filelen(workingdir + SLASH + "fixbits.bin") * 8
 FOR i as integer = sizefixbits + 1 TO maxbits - 1
  IF getfixbit(i) THEN
   debug "Unknown fixbit " & i & " set"
   future_rpg_warning
  END IF
 NEXT

 FOR i as integer = 0 TO gen(genMaxMap)
  'Game actually runs just fine when anything except the foemap is missing; Custom
  'has some (crappy) map lump fix code in the map editor
  IF NOT isfile(maplumpname(i, "t")) THEN showerror "map" + filenum(i) + " tilemap is missing!"
  IF NOT isfile(maplumpname(i, "p")) THEN showerror "map" + filenum(i) + " passmap is missing!"
  IF NOT isfile(maplumpname(i, "e")) THEN showerror "map" + filenum(i) + " foemap is missing!"
  IF NOT isfile(maplumpname(i, "l")) THEN showerror "map" + filenum(i) + " NPClocations are missing!"
  IF NOT isfile(maplumpname(i, "n")) THEN showerror "map" + filenum(i) + " NPCdefinitions are missing!"
  IF NOT isfile(maplumpname(i, "d")) THEN showerror "map" + filenum(i) + " doorlinks are missing!"
 NEXT

 'Should this be in upgrade? I can't make up my mind!
 IF gen(genNumElements) > 64 THEN
  future_rpg_warning
  'We would definitely crash if we didn't cap this
  gen(genNumElements) = 64
 END IF
END SUB

SUB loadglobalstrings
'we load the whole lump into memory because readglobalstring can be called
'hunderds of times a second. It's stored in a raw format; good enough.
DIM fh as integer = FREEFILE
OPEN game + ".stt" FOR BINARY as #fh
IF LOF(fh) > 0 THEN
 global_strings_buffer = STRING(LOF(fh), 0)
 GET #fh, 1, global_strings_buffer
END IF
CLOSE #fh
END SUB

FUNCTION readglobalstring (byval index as integer, default as string, byval maxlen as integer=10) as string
IF index * 11 + 2 > LEN(global_strings_buffer) THEN
 RETURN default
ELSE
 DIM namelen as UBYTE = global_strings_buffer[index * 11]
 IF maxlen < namelen THEN namelen = maxlen
 RETURN MID(global_strings_buffer, index * 11 + 2, namelen)
END IF
END FUNCTION

SUB create_default_menu(menu as MenuDef)
 ClearMenuData menu
 FOR i as integer = 0 TO 3  ' item, spell, status, equip
  append_menu_item(menu, "", 1, i)
 NEXT i
 append_menu_item(menu, "", 1, 6)  ' Order/Status menu
 FOR i as integer = 7 TO 8  ' map, save
  append_menu_item(menu, "", 1, i)
  menu.last->hide_if_disabled = YES
 NEXT
 FOR i as integer = 10 TO 11  ' quit, volume
  append_menu_item(menu, "", 1, i)
 NEXT
 menu.translucent = YES
 menu.min_chars = 14
END SUB

FUNCTION bound_arg(byval n as integer, byval min as integer, byval max as integer, argname as ZSTRING PTR, context as ZSTRING PTR=nulzstr, byval fromscript as integer=YES, byval errlvl as integer = 4) as integer
 'This function takes zstring ptr arguments because passing strings is actually really expensive
 '(it performs an allocation, copy, delete), and would be easily noticeable by scripts.
 IF n < min OR n > max THEN
#IFDEF IS_GAME
  IF fromscript THEN
   IF *context = "" ANDALSO curcmd->kind = tyfunct THEN
    scripterr commandname(curcmd->value) + ": invalid " & *argname & " " & n, errlvl
   ELSE
    scripterr *context & ": invalid " & *argname & " " & n, errlvl
   END IF
   RETURN NO
  END IF
#ENDIF
  debug *context & ": invalid " & *argname & " " & n
  RETURN NO
 END IF
 RETURN YES
END FUNCTION

SUB reporterr(msg as string, byval errlvl as integer = 5)
 'this is a placeholder for some more detailed replacement of debug, so scripterrs can be thrown from slices.bas
#IFDEF IS_GAME
 IF insideinterpreter THEN
  DIM msg2 as string = msg  'Don't modify passed-in strings
  IF curcmd->kind = tyfunct THEN msg2 = commandname(curcmd->value) + ": " + msg2
  scripterr msg2, errlvl
 ELSE
  debug msg
 END IF
#ELSE
 debug msg
#ENDIF
END SUB

FUNCTION tag_set_caption(byval n as integer, prefix as string="Set Tag") as string
 RETURN tag_condition_caption(n, prefix, "N/A", "Unchangeable", "Unchangeable")
END FUNCTION

FUNCTION tag_condition_caption(byval n as integer, prefix as string="Tag", zerocap as string="", onecap as string="", negonecap as string="") as string
 DIM s as string
 DIM cap as string
 s = prefix
 IF LEN(s) > 0 THEN s = s & " "
 s = s & ABS(n) & "=" & onoroff(n)
 cap = load_tag_name(n)
 IF n = 0 AND LEN(zerocap) > 0 THEN cap = zerocap
 IF n = 1 AND LEN(onecap) > 0 THEN cap = onecap
 IF n = -1 AND LEN(negonecap) > 0 THEN cap = negonecap
 cap = TRIM(cap)
 IF LEN(cap) > 0 THEN s = s & " (" & cap & ")"
 RETURN s
END FUNCTION

FUNCTION onoroff (byval n as integer) as string
 IF n >= 0 THEN RETURN "ON"
 RETURN "OFF"
END FUNCTION

'Returns a YES/NO string. Not to be confused with yesno() (in this file)
'which asks an interactive yes/no question
FUNCTION yesorno (byval n as integer, yes_cap as string="YES", no_cap as string="NO") as string
 IF n THEN RETURN yes_cap
 RETURN no_cap
END FUNCTION

'This is mostly equivalent to '(float * 100) & "%"', however it doesn't show
'exponentials, and it rounds to some number of significant places
FUNCTION format_percent(byval float as double, byval sigfigs as integer = 5) as string
 DIM deciplaces as integer = sigfigs - (INT(LOG(ABS(float * 100)) / LOG(10)) + 1)
 IF deciplaces > sigfigs THEN deciplaces = sigfigs
 DIM repr as string = FORMAT(float * 100, "0." & STRING(deciplaces, "#"))
 'Unlike STR, FORMAT will add a trailing point
 IF repr[LEN(repr) - 1] = ASC(".") THEN repr = LEFT(repr, LEN(repr) - 1)
 RETURN repr + "%"
END FUNCTION

FUNCTION load_tag_name (byval index as integer) as string
 IF index = 0 THEN RETURN ""
 IF index = 1 THEN RETURN "Never"
 IF index = -1 THEN RETURN "Always"
 RETURN readbadgenericname(ABS(index), game + ".tmn", 42, 0, 20)
END FUNCTION

SUB save_tag_name (tagname as string, byval index as integer)
 DIM buf(20) as integer
 setpicstuf buf(), 42, -1
 writebadbinstring tagname, buf(), 0, 20
 storeset game + ".tmn", index, 0
END SUB

SUB dump_master_palette_as_hex (master_palette() as RGBColor)
 DIM hexstring as string = " DIM colorcodes(255) as integer = {"
 FOR i as integer = 0 to 255
  hexstring = hexstring & "&h" & hex(master_palette(i).col, 6)
  IF i <> 255 THEN hexstring = hexstring & ","
  IF LEN(hexstring) > 88 THEN
   hexstring = hexstring & "_"
   debug hexstring
   hexstring = "        "
  END IF
 NEXT i
 hexstring = hexstring & "}"
 debug hexstring
END SUB

SUB load_default_master_palette (master_palette() as RGBColor)
 'To regenerate this if the default master palette changes, use dump_master_palette_as_hex
 DIM colorcodes(255) as integer = {&h000000,&h232222,&h312F2B,&h3F3B34,&h4C483C,&h5D5747,_
        &h716A54,&h857C61,&h9A8F6D,&hAFA277,&hC4B581,&hD8C68B,&hEAD694,&hFDBC3B,&hFC9D47,_
        &hFA7D53,&h0D0F0D,&h121111,&h2A2426,&h41323B,&h583D51,&h6F456D,&h81577B,&h916684,_
        &hA2778D,&hB28997,&hC39CA3,&hD3B0B0,&hE3C9C4,&hEEDCD6,&hF4E7E4,&hFAF3F3,&h1F221E,_
        &h0C0E1C,&h1C203E,&h2A305E,&h39407D,&h495198,&h5962B1,&h6975C4,&h8084D0,&h9793DD,_
        &hAEA2EA,&hC1B8F1,&hD3CEF7,&hE2DFFC,&hECEBFF,&hF6F6FF,&h2F342E,&h15091C,&h2B1239,_
        &h411B56,&h562473,&h6C2D90,&h8236AC,&h9740C9,&hAD49E6,&hC154FF,&hCB68FF,&hD57CFF,_
        &hDF90FF,&hE9A4FF,&hF2B8FF,&hFCCCFF,&h40463E,&h060E27,&h0E2059,&h153289,&h1B45AE,_
        &h1E5DC0,&h2179D3,&h2294DD,&h24B0E6,&h25CEF0,&h27EEF9,&h3DFFFA,&h75FFFB,&hA3FFFC,_
        &hC4FFFD,&hE4FFFE,&h4F595A,&h170000,&h340000,&h500000,&h6B0000,&h870000,&hA30000,_
        &hBF0000,&hDC2D2D,&hFA5F5F,&hFF7F7F,&hFF9D9D,&hFFB9B9,&hFFD0D0,&hFFE1E1,&hFFF1F1,_
        &h5F6B75,&h140F00,&h2D2200,&h463400,&h5E4600,&h765800,&h8E6B00,&hA67D00,&hBF8F00,_
        &hD7A100,&hEFB300,&hFFC70D,&hFFDD30,&hFFEF4D,&hFFFC62,&hFFFFB4,&h707D8F,&h140614,_
        &h2E0F2E,&h471747,&h5F1F5F,&h782878,&h913091,&hAB3CA2,&hC74AB0,&hE358BE,&hFF67CC,_
        &hFF8AD8,&hFFACE3,&hFFC7EC,&hFFDBF3,&hFFEFF9,&h898CA0,&h1B0904,&h3D150A,&h5A2419,_
        &h76352C,&h91463F,&hAC5752,&hBF6666,&hD17579,&hE4848C,&hF693A0,&hFFA8B5,&hFFC2CB,_
        &hFFD7DD,&hFFE7EA,&hFFF6F7,&hA19CB0,&h080B0E,&h121921,&h1B2733,&h363B45,&h4D484B,_
        &h61504B,&h75584B,&h89614B,&h9E694B,&hB1774F,&hC38C56,&hD3A560,&hDFC171,&hE8D67D,_
        &hF1EA89,&hBAABC1,&h091207,&h162911,&h20411C,&h285B2A,&h45692A,&h647729,&h7B8639,_
        &h90964E,&hA2A860,&hAFBE6C,&hBDD379,&hC9E784,&hD3F88E,&hDFFFA7,&hF1FFD8,&hCCBDD0,_
        &h0F0F0F,&h232221,&h363331,&h494D3C,&h436443,&h4F7A54,&h5A8F67,&h64A57D,&h6DBA96,_
        &h76CFB1,&h7DE5D0,&h84F9F1,&hA4FFFB,&hC4FFFC,&hE5FFFE,&hDAD0DD,&h161010,&h322524,_
        &h4D3836,&h6A4C44,&h836052,&h9A7360,&hAF846C,&hC29478,&hD4A484,&hE1B494,&hEDC2A2,_
        &hF6D2B6,&hF9E2CF,&hFBECE1,&hFDF7F2,&hE6E0E8,&h0B230B,&h0E300E,&h123D12,&h154C15,_
        &h196119,&h1E771E,&h228B22,&h379F37,&h3CB23A,&h44C53D,&h65D95D,&h6BEB61,&h98FA90,_
        &hCCFFCA,&hE5FFE9,&hEFEBF0,&h180B09,&h371916,&h52281E,&h6B3824,&h84492A,&h9E5A30,_
        &hB56E24,&hCD8316,&hDF9814,&hE6AD33,&hECC253,&hF3D773,&hF7E69A,&hFAEFBE,&hFCF7E2,_
        &hFFFFFF,&h000000,&h001D48,&h002C6F,&h003B95,&h004BBC,&h005AE2,&h076DFF,&h258BFF,_
        &h43A9FF,&h61C7FF,&h85D6FF,&hA8E2FF,&hC5EBFF,&hDAF2FF,&hEEF9FF}
 FOR i as integer = 0 TO 255
  master_palette(i).col = colorcodes(i)
 NEXT i
END SUB

FUNCTION enter_or_space () as integer
 RETURN keyval(scEnter) > 1 OR keyval(scSpace) > 1
END FUNCTION

FUNCTION copy_keychord () as integer
 RETURN (keyval(scCtrl) > 0 AND keyval(scInsert) > 1) OR (keyval(scShift) > 0 AND keyval(scDelete) > 0) OR (keyval(scCtrl) > 0 AND keyval(scC) > 1)
END FUNCTION

FUNCTION paste_keychord () as integer
 RETURN (keyval(scShift) > 0 AND keyval(scInsert) > 1) OR (keyval(scCtrl) > 0 AND keyval(scV) > 1)
END FUNCTION

SUB write_npc_int (npcdata as NPCType, byval intoffset as integer, byval n as integer)
 '--intoffset is the integer offset, same as appears in the .N lump documentation
 WITH npcdata
  SELECT CASE intoffset
   CASE 0: .picture = n
   CASE 1: .palette = n
   CASE 2: .movetype = n
   CASE 3: .speed = n
   CASE 4: .textbox = n
   CASE 5: .facetype = n
   CASE 6: .item = n
   CASE 7: .pushtype = n
   CASE 8: .activation = n
   CASE 9: .tag1 = n
   CASE 10: .tag2 = n
   CASE 11: .usetag = n
   CASE 12: .script = n
   CASE 13: .scriptarg = n
   CASE 14: .vehicle = n
   CASE 15: .defaultzone = n
   CASE 16: .defaultwallzone = n
   CASE ELSE
    debug "write_npc_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
END SUB

FUNCTION read_npc_int (npcdata as NPCType, byval intoffset as integer) as integer
 '--intoffset is the integer offset, same as appears in the .N lump documentation
 WITH npcdata
  SELECT CASE intoffset
   CASE 0: RETURN .picture
   CASE 1: RETURN .palette
   CASE 2: RETURN .movetype
   CASE 3: RETURN .speed
   CASE 4: RETURN .textbox
   CASE 5: RETURN .facetype
   CASE 6: RETURN .item
   CASE 7: RETURN .pushtype
   CASE 8: RETURN .activation
   CASE 9: RETURN .tag1
   CASE 10: RETURN .tag2
   CASE 11: RETURN .usetag
   CASE 12: RETURN .script
   CASE 13: RETURN .scriptarg
   CASE 14: RETURN .vehicle
   CASE 15: RETURN .defaultzone
   CASE 16: RETURN .defaultwallzone
   CASE ELSE
    debug "read_npc_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
 RETURN 0
END FUNCTION

SUB lockstep_tile_animation (tilesets() as TilesetData ptr, byval layer as integer)
 'Called after changing a layer's tileset to make sure its tile animation is in phase with other layers of the same tileset
 FOR i as integer = 0 TO UBOUND(tilesets)
  IF i <> layer ANDALSO tilesets(i) ANDALSO tilesets(i)->num = tilesets(layer)->num THEN
   tilesets(layer)->anim(0) = tilesets(i)->anim(0)
   tilesets(layer)->anim(1) = tilesets(i)->anim(1)
   EXIT SUB
  END IF
 NEXT
END SUB

SUB unloadtilesetdata (byref tileset as TilesetData ptr)
 IF tileset <> NULL THEN
  'debug "unloading tileset " & tileset->num
  frame_unload @tileset->spr
  DELETE tileset
  tileset = NULL
 END IF
END SUB

SUB maptilesetsprint (tilesets() as TilesetData ptr)
 FOR i as integer = 0 TO UBOUND(tilesets)
  IF tilesets(i) = NULL THEN
   debug i & ": NULL"
  ELSE 
   debug i & ": " & tilesets(i)->num
  END IF
 NEXT
END SUB

SUB loadtilesetdata (tilesets() as TilesetData ptr, byval layer as integer, byval tilesetnum as integer, byval lockstep as integer = YES)
'the tileset may already be loaded
'note that tile animation data is NOT reset if the old tileset was the same	

 IF tilesets(layer) = NULL ORELSE tilesets(layer)->num <> tilesetnum THEN
  unloadtilesetdata tilesets(layer)
  tilesets(layer) = NEW TilesetData

  WITH *tilesets(layer)
   .num = tilesetnum
   'debug "loading tileset " & tilesetnum

   .spr = tileset_load(tilesetnum)
   loadtanim tilesetnum, .tastuf()
  END WITH
 END IF
 FOR i as integer = 0 TO 1
  WITH tilesets(layer)->anim(i)
   .cycle = 0
   .pt = 0
   .skip = 0
  END WITH
 NEXT
 IF lockstep THEN lockstep_tile_animation tilesets(), layer
END SUB

FUNCTION layer_tileset_index(byval layer as integer) as integer
'return the gmap() index containing a layer's tileset
 IF layer <= 2 THEN RETURN 22 + layer ELSE RETURN 23 + layer
END FUNCTION

SUB loadmaptilesets (tilesets() as TilesetData ptr, gmap() as integer, byval resetanimations as integer = YES)
'tilesets() may contain already loaded tilesets. In this case, we can reuse them
 DIM as integer i, j
 DIM tileset as integer

 FOR i as integer = 0 TO UBOUND(tilesets)
  tileset = gmap(layer_tileset_index(i))
  IF tileset <> 0 THEN
   tileset = tileset - 1
  ELSE
   tileset = gmap(0)
  END IF

  loadtilesetdata tilesets(), i, tileset
  IF resetanimations THEN
   FOR j as integer = 0 TO 1
    WITH tilesets(i)->anim(j)
     .cycle = 0
     .pt = 0
     .skip = 0
    END WITH
   NEXT
  END IF
 NEXT
END SUB

SUB reloadtileanimations (tilesets() as TilesetData ptr, gmap() as integer)
 DIM tileset as integer

 FOR i as integer = 0 TO UBOUND(tilesets)
  tileset = gmap(layer_tileset_index(i))
  IF tileset <> 0 THEN
   tileset = tileset - 1
  ELSE
   tileset = gmap(0)
  END IF

  loadtanim tileset, tilesets(i)->tastuf()
  FOR j as integer = 0 TO 1
   WITH tilesets(i)->anim(j)
    .cycle = 0
    .pt = 0
    .skip = 0
   END WITH
  NEXT
 NEXT
END SUB

SUB unloadmaptilesets (tilesets() as TilesetData ptr)
 FOR i as integer = 0 TO UBOUND(tilesets)
  unloadtilesetdata tilesets(i)
 NEXT
END SUB

FUNCTION xreadbit (bitarray() as integer, byval bitoffset as integer, byval intoffset as integer=0) as integer
 'This is a wrapper for readbit that returns YES/NO and accepts a default arg of zero for the integer offset
 RETURN readbit(bitarray(), intoffset, bitoffset) <> 0 
END FUNCTION

FUNCTION getheroname (byval hero_id as integer) as string
 DIM her as HeroDef
 IF hero_id >= 0 THEN
  loadherodata @her, hero_id
  RETURN her.name
 END IF
 RETURN ""
END FUNCTION

FUNCTION get_text_box_height(byref box as TextBox) as integer
 IF box.shrink >= 0 THEN RETURN 88 - box.shrink * 4
 FOR i as integer = UBOUND(box.text) TO 0 STEP -1
  IF LEN(TRIM(box.text(i))) > 0 THEN
   DIM vsize as integer = 20 + i * 10
   IF vsize < 32 AND vsize > 24 THEN RETURN 32
   IF vsize <= 24 THEN RETURN 16
   RETURN vsize
  END IF
 NEXT i
 RETURN 88
END FUNCTION

FUNCTION last_inv_slot() as integer
 '--If genMaxInventory is 0, return the default inventory size
 IF gen(genMaxInventory) = 0 THEN RETURN inventoryMax
 '--Otherwise round genMaxInventory up to the nearest
 '-- multiple of three (counting the zero-slot) and return it.
 RETURN ((gen(genMaxInventory) + 3) \ 3) * 3 - 1
END FUNCTION

SUB setup_sprite_sizes ()
 'Populates the global sprite_sizes
 WITH sprite_sizes(0)
  .name = "Hero"
  .size.x = 32
  .size.y = 40
  .frames = 8
  .genmax = genMaxHeroPic
 END WITH
 WITH sprite_sizes(1)
  .name = "Small Enemy"
  .size.x = 34
  .size.y = 34
  .frames = 1
  .genmax = genMaxEnemy1Pic
 END WITH
 WITH sprite_sizes(2)
  .name = "Medium Enemy"
  .size.x = 50
  .size.y = 50
  .frames = 1
  .genmax = genMaxEnemy2Pic
 END WITH
 WITH sprite_sizes(3)
  .name = "Large Enemy"
  .size.x = 80
  .size.y = 80
  .frames = 1
  .genmax = genMaxEnemy3Pic
 END WITH
 WITH sprite_sizes(4)
  .name = "Walkabout"
  .size.x = 20
  .size.y = 20
  .frames = 8
  .genmax = genMaxNPCPic
 END WITH
 WITH sprite_sizes(5)
  .name = "Weapon"
  .size.x = 24
  .size.y = 24
  .frames = 2
  .genmax = genMaxWeaponPic
 END WITH
 WITH sprite_sizes(6)
  .name = "Attack"
  .size.x = 50
  .size.y = 50
  .frames = 3
  .genmax = genMaxAttackPic
 END WITH
 WITH sprite_sizes(7)
  .name = "Box Border"
  .size.x = 16
  .size.y = 16
  .frames = 16
  .genmax = genMaxBoxBorder
 END WITH
 WITH sprite_sizes(8)
  .name = "Portrait"
  .size.x = 50
  .size.y = 50
  .frames = 1
  .genmax = genMaxPortrait
 END WITH
 WITH sprite_sizes(sprTypeMXS)  '9
  .name = "Backdrop"
  .size.x = 320
  .size.y = 200
  .frames = 1
  .genmax = genNumBackdrops
  .genmax_offset = -1
 END WITH
 WITH sprite_sizes(sprTypeFrame)   '10
  .name = "Pixel array"
  .frames = 1
 END WITH
 
 WITH sprite_sizes(-1) '--Only use for temporary use in the secret desting/debugging menu
  .name = "Experimental"
  .frames = 1
  .genmax = -1 'this should throw an error rather than corrupting gen(0)
 END WITH
END SUB

SUB load_sprite_and_pal (byref img as GraphicPair, byval spritetype as integer, byval index as integer, byval palnum as integer=-1)
 unload_sprite_and_pal img
 IF spritetype = sprTypeMXS THEN
  img.sprite = loadmxs(game + ".mxs", index)
 ELSEIF spritetype >= 0 AND spritetype <= 8 THEN
  img.sprite = frame_load(spritetype, index)
  img.pal    = palette16_load(palnum, spritetype, index)
 ELSE
  debug "load_sprite_and_pal: bad spritetype " & spritetype & " (index " & index & " pal " & palnum & ")"
 END IF
END SUB

SUB unload_sprite_and_pal (byref img as GraphicPair)
 frame_unload @img.sprite
 palette16_unload @img.pal
END SUB

FUNCTION decode_backslash_codes(s as string) as string
 DIM result as string = ""
 DIM i as integer = 1
 DIM ch as string
 DIM mode as integer = 0
 DIM nstr as string
 DIM num as integer
 DO
  ch = MID(s, i, 1)
  SELECT CASE mode
   CASE 0'--normal
    IF ch = "\" THEN
      mode = 1
      nstr = ""
    ELSE
      result &= ch
    END IF
   CASE 1'--parsing backslash
    SELECT CASE ch
     CASE "\" '--an escaped backslash
      result &= "\"
      mode = 0
     CASE "n" '-- a newline
      result &= CHR(10)
      mode = 0
     CASE "r" '-- a carriage return
      result &= CHR(13)
      mode = 0
     CASE "t" '-- a tab
      result &= CHR(9)
      mode = 0
     CASE "0", "1", "2"
      nstr &= ch
      mode = 2
     CASE ELSE '--not a valid backslash code, resume without discarding the backslash
      result &= "\" & ch
      mode = 0
    END SELECT
   CASE 2'--parsing ascii code number
    SELECT CASE ch
     CASE "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
      nstr &= ch
     CASE ELSE 'busted backslash code, print warning
      debug "Bogus backslash ascii code in string """ & s & """"
      mode = 0
    END SELECT
    IF LEN(nstr) >= 3 THEN
     num = str2int(nstr)
     IF num > 255 THEN
      debug "Bogus backslash ascii code in string """ & s & """"
     ELSE
      result &= CHR(num)
     END IF
     mode = 0
    END IF
  END SELECT
  i += 1
 LOOP UNTIL i > LEN(s)
 IF mode <> 0 THEN
  debug "decode_backslash_codes: exited while parsing a backslash code (mode=" & mode & ")"
 END IF
 RETURN result
END FUNCTION

FUNCTION escape_nonprintable_ascii(s as string) as string
 DIM result as string = ""
 DIM nstr as string
 DIM ch as string
 FOR i as integer = 1 TO LEN(s)
  ch = MID(s, i, 1)
  SELECT CASE ASC(ch)
   CASE 32 TO 91, 93 TO 126
    result &= ch
   CASE 92 '--Backslash
    result &= "\\"
   CASE 10
    result &= "\n"
   CASE 13
    result &= "\r"
   CASE 9
    result &= "\t"
   CASE ELSE
    nstr = STR(ASC(ch))
    WHILE LEN(nstr) < 3
     nstr = "0" & nstr
    WEND
    result &= "\" & nstr
  END SELECT
 NEXT i
 RETURN result
END FUNCTION

FUNCTION fixfilename (s as string) as string
 'Makes sure that a string cannot contain any chars unsafe for filenames (overly strict)
 DIM result as string = ""
 DIM ch as string
 DIM ascii as integer
 FOR i as integer = 1 TO LEN(s)
  ch = MID(s, i, 1)
  ascii = ASC(ch)
  SELECT CASE ascii
   CASE 32, 46, 48 TO 57, 65 TO 90, 97 TO 122, 95, 126, 45  '[ 0-9A-Za-z_~-]
    result = result & ch
  END SELECT
 NEXT i
 RETURN result
END FUNCTION

FUNCTION inputfilename (query as string, ext as string, directory as string, helpkey as string, default as string="", byval allow_overwrite as integer=YES) as string
 DIM filename as string = default
 DIM tog as integer
 IF directory = "" THEN directory = CURDIR
 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
  IF keyval(scEsc) > 1 THEN RETURN ""
  IF keyval(scF1) > 1 THEN show_help helpkey
  strgrabber filename, 40
  filename = fixfilename(filename)
  IF keyval(scEnter) > 1 THEN
   filename = TRIM(filename)
   IF filename <> "" THEN
    IF isfile(directory + SLASH + filename + ext) THEN
     If allow_overwrite THEN
      IF yesno("File already exists, overwrite?") THEN RETURN directory + SLASH + filename
     ELSE
      notification filename & ext & " already exists"
     END IF
    ELSE
     RETURN directory + SLASH + filename
    END IF
   END IF
  END IF
  clearpage dpage
  textcolor uilook(uiText), 0
  printstr query, 160 - LEN(query) * 4, 20, dpage
  printstr "Output directory: ", 160 - 18 * 4, 35, dpage
  printstr directory, xstring(directory, 160), 45, dpage
  textcolor uilook(uiSelectedItem + tog), 1
  printstr filename, 160 - LEN(filename & ext) * 4 , 60, dpage
  textcolor uilook(uiText), uilook(uiHighlight)
  printstr ext, 160 + (LEN(filename) - LEN(ext)) * 4 , 60, dpage
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END FUNCTION

FUNCTION getdisplayname (default as string) as string
 '--Get game's display name
 DIM f as string
 f = workingdir & SLASH & "browse.txt"
 IF isfile(f) THEN
  setpicstuf buffer(), 40, -1
  loadset f, 0, 0
  DIM s as string
  s = STRING(bound(buffer(0), 0, 38), " ")
  array2str buffer(), 2, s
  IF LEN(s) > 0 THEN
   RETURN s
  END IF
 END IF
 RETURN default
END FUNCTION

SUB getstatnames(statnames() as string)
 REDIM statnames(11)
 statnames(0) = readglobalstring(0, "HP")
 statnames(1) = readglobalstring(1, "MP")
 statnames(2) = readglobalstring(2, "Atk")
 statnames(3) = readglobalstring(3, "Aim")
 statnames(4) = readglobalstring(5, "Def")
 statnames(5) = readglobalstring(6, "Dog")
 statnames(6) = readglobalstring(29, "Mag")
 statnames(7) = readglobalstring(30, "Wil")
 statnames(8) = readglobalstring(8, "Speed")
 statnames(9) = readglobalstring(7, "Counter")
 statnames(10) = readglobalstring(31, "Focus")
 statnames(11) = readglobalstring(4, "HitX")
END SUB

SUB getelementnames(elmtnames() as string)
 REDIM elmtnames(gen(genNumElements) - 1)
 FOR i as integer = 0 TO gen(genNumElements) - 1
  DIM default as string
  default = "Element" & i+1
  IF i < 8 THEN
   'Original indices changed so maxlen could be expanded
   default = readglobalstring(17 + i, default, 10)
  ELSEIF i < 16 THEN
   'Next 8 elements map to old enemytypes
   default = LEFT(readglobalstring(1 + i, "EnemyType" & i, 10) + "-killer", 14)
  END IF
  elmtnames(i) = readglobalstring(174 + i*2, default, 14)
 NEXT i
END SUB

'See WriteByteStr for the straight-to-file version
SUB writebinstring (savestr as string, array() as integer, byval offset as integer, byval maxlen as integer)
 DIM s as string

 '--pad savestr to (at least) the right length
 s = savestr + STRING(maxlen - LEN(s), CHR(0))

 '--odd lengths would result in (harmless) garbage
 IF maxlen AND 1 THEN s += CHR(0): maxlen += 1

 '--write length (current not max)
 array(offset) = small(LEN(savestr), maxlen)

 FOR i as integer = 1 TO maxlen \ 2
  array(offset + i) = s[2 * i - 2] OR (s[2 * i - 1] SHL 8)
 NEXT
END SUB

SUB writebinstring (savestr as string, array() as short, byval offset as integer, byval maxlen as integer)
 DIM s as string

 '--pad savestr to (at least) the right length
 s = savestr + STRING(maxlen - LEN(s), CHR(0))

 '--odd lengths would result in (harmless) garbage
 IF maxlen AND 1 THEN s += CHR(0): maxlen += 1

 '--write length (current not max)
 array(offset) = small(LEN(savestr), maxlen)

 memcpy(@array(offset + 1), @s[0], maxlen)
END SUB

'See WriteVStr for the straight-to-file version
SUB writebadbinstring (savestr as string, array() as integer, byval offset as integer, byval maxlen as integer, byval skipword as integer=0)
 '--write current length
 array(offset) = small(LEN(savestr), maxlen)


 FOR i as integer = 1 TO small(LEN(savestr), maxlen)
  array(offset + skipword + i) = savestr[i - 1]
 NEXT i

 FOR i as integer = LEN(savestr) + 1 TO maxlen
  array(offset + skipword + i) = 0
 NEXT i

END SUB

'See ReadByteStr for the straight-from-file version
FUNCTION readbinstring (array() as integer, byval offset as integer, byval maxlen as integer) as string

 DIM result as string = ""
 DIM stringlen as integer = bound(array(offset), 0, maxlen)
 DIM i as integer
 DIM n as integer

 i = 1
 DO WHILE LEN(result) < stringlen
  '--get an int
  n = array(offset + i)
  i = i + 1

  '--append the lowbyte as a char
  result = result & CHR(n AND &HFF)

  '--if we still care about the highbyte, append it as a char too
  IF LEN(result) < stringlen THEN
   result = result & CHR((n SHR 8) AND &HFF)
  END IF

 LOOP

 RETURN result
END FUNCTION

'See ReadByteStr for the straight-from-file version
FUNCTION readbinstring (array() as short, byval offset as integer, byval maxlen as integer) as string
 DIM stringlen as integer = bound(array(offset), 0, maxlen)
 DIM result as string = STRING(stringlen, 0)
 memcpy(@result[0], @array(offset + 1), stringlen)
 RETURN result
END FUNCTION

'See ReadVStr for the straight-from-file version
FUNCTION readbadbinstring (array() as integer, byval offset as integer, byval maxlen as integer, byval skipword as integer=0) as string
 DIM result as string = ""
 DIM stringlen as integer = bound(array(offset), 0, maxlen)
 DIM n as integer

 FOR i as integer = 1 TO stringlen
  '--read and int
  n = array(offset + skipword + i)
  '--if the int is a char use it.
  IF n >= 0 AND n <= 255 THEN
   '--use it
   result = result & CHR(n)
  END IF
 NEXT i

 RETURN result
END FUNCTION

SUB set_homedir()
#IFDEF __UNIX__
 homedir = ENVIRON("HOME")
#ELSE
 homedir = ENVIRON("USERPROFILE") & SLASH & "My Documents" 'Is My Documents called something else for non-English versions of Windows?
 IF NOT isdir(homedir) THEN
  'Windows Vista uses "Documents" instead of "My Documents"
  homedir = ENVIRON("USERPROFILE") & SLASH & "Documents"
 END IF
#ENDIF
END SUB

PRIVATE FUNCTION help_dir_helper(dirname as string, fname as string) as integer
 IF LEN(fname) THEN RETURN isfile(dirname + SLASH + fname) ELSE RETURN isdir(dirname)
END FUNCTION

FUNCTION get_help_dir(helpfile as string="") as string
 'what happened to prefsdir? [James: prefsdir only exists for game not custom right now]
 IF help_dir_helper(homedir & SLASH & "ohrhelp", helpfile) THEN RETURN homedir & SLASH & "ohrhelp"
 IF help_dir_helper(exepath & SLASH & "ohrhelp", helpfile) THEN RETURN exepath & SLASH & "ohrhelp"
 'platform-specific relative data files path (Mac OS X bundles)
 IF help_dir_helper(data_dir & SLASH & "ohrhelp", helpfile) THEN RETURN data_dir & SLASH & "ohrhelp"
 #IFDEF __UNIX__
 #IFDEF DATAFILES
  IF help_dir_helper(DATAFILES & SLASH & "ohrhelp", helpfile) THEN RETURN DATAFILES & SLASH & "ohrhelp"
 #ENDIF
 #ENDIF
 '-- if all else fails, use exepath even if invalid
 RETURN exepath & SLASH & "ohrhelp"
END FUNCTION

FUNCTION load_help_file(helpkey as string) as string
 DIM help_dir as string
 help_dir = get_help_dir(helpkey & ".txt")
 IF isdir(help_dir) THEN
  DIM helpfile as string
  helpfile = help_dir & SLASH & helpkey & ".txt"
  IF isfile(helpfile) THEN
   DIM fh as integer = FREEFILE
   OPEN helpfile FOR INPUT ACCESS READ as #fh
   DIM helptext as string = ""
   DIM s as string
   DO WHILE NOT EOF(fh)
    LINE INPUT #fh, s
    helptext = helptext & s & CHR(10)
   LOOP
   CLOSE #fh
   RETURN helptext
  END IF
 END IF
 RETURN "No help found for """ & helpkey & """"
END FUNCTION

SUB save_help_file(helpkey as string, text as string)
 DIM help_dir as string
 help_dir = get_help_dir()
 IF NOT isdir(help_dir) THEN
  IF makedir(help_dir) THEN
   visible_debug """" & help_dir & """ does not exist and could not be created."
   EXIT SUB
  END IF
 END IF
 DIM helpfile as string
 helpfile = help_dir & SLASH & helpkey & ".txt"
 DIM fh as integer = FREEFILE
 IF OPEN(helpfile FOR OUTPUT ACCESS READ WRITE as #fh) = 0 THEN
  DIM trimmed_text as string
  trimmed_text = RTRIM(text, ANY " " & CHR(13) & CHR(10))
  PRINT #fh, trimmed_text
  CLOSE #fh
 ELSE
  visible_debug "help file """ & helpfile & """ is not writeable."
 END IF
END SUB

FUNCTION filenum (byval n as integer) as string
 IF n < 100 THEN
  RETURN RIGHT("00" + STR(n), 2)
 ELSE
  RETURN STR(n)
 END IF
END FUNCTION

'OK, NOW it supports negative n too
FUNCTION xy_from_int(byval n as integer, byval wide as integer, byval high as integer) as XYPair
 DIM pair as XYPair
 n = POSMOD(n, wide * high)  'Mathematical modulo wide*high
 pair.x = n MOD wide
 pair.y = n \ wide
 RETURN pair
END FUNCTION

FUNCTION int_from_xy(pair as XYPair, byval wide as integer, byval high as integer) as integer
 RETURN bound(pair.y * wide + pair.x, 0, wide * high - 1)
END FUNCTION

FUNCTION color_browser_256(byval start_color as integer=0) as integer
 DIM tog as integer = 0
 DIM spot as XYPair
 DIM cursor as XYPair
 cursor = xy_from_int(start_color, 16, 16)
 setkeys
 DO
  setwait 55
  setkeys
  tog = (tog + 1) MOD 256
  IF keyval(scESC) > 1 THEN RETURN start_color
  IF keyval(scF1) > 1 THEN show_help "color_browser"

  IF enter_or_space() THEN RETURN int_from_xy(cursor, 16, 16)

  IF keyval(scUp) > 1 THEN cursor.y = loopvar(cursor.y, 0, 15, -1)
  IF keyval(scDown) > 1 THEN cursor.y = loopvar(cursor.y, 0, 15, 1)
  IF keyval(scLeft) > 1 THEN cursor.x = loopvar(cursor.x, 0, 15, -1)
  IF keyval(scRight) > 1 THEN cursor.x = loopvar(cursor.x, 0, 15, 1)

  clearpage dpage
  FOR i as integer = 0 TO 255
   spot = xy_from_int(i, 16, 16)
   IF spot.x = cursor.x AND spot.y = cursor.y THEN
    edgebox 64 + spot.x * 12 , 0 + spot.y * 12 , 12, 12, i, tog, dpage
   ELSE
    rectangle 64 + spot.x * 12 , 0 + spot.y * 12 , 12, 12, i, dpage
   END IF
  NEXT i

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END FUNCTION

FUNCTION exptolevel (byval level as integer) as integer
' HINT: Customisation goes here :)

 IF level = 0 THEN RETURN 0
 DIM exper as integer = 30
 FOR o as integer = 2 TO level
  exper = exper * 1.2 + 5
  'FIXME: arbitrary experience cap should be removable
  IF exper > 1000000 THEN exper = 1000000
 NEXT
 RETURN exper
END FUNCTION

FUNCTION total_exp_to_level (byval level as integer) as integer
 DIM total as integer = 0
 FOR i as integer = 1 TO level
  total += exptolevel(i)
 NEXT
 RETURN total
END FUNCTION

FUNCTION current_max_level() as integer
 RETURN small(gen(genLevelCap), gen(genMaxLevel))
END FUNCTION

FUNCTION atlevel (byval lev as integer, byval a0 as integer, byval aMax as integer) as integer
 'Stat at a given level, according to an arbitrary curve between two points.
  IF lev < 0 THEN RETURN 0
  RETURN (.8 + lev / 50) * lev * ((aMax - a0) / 275.222) + a0 + .1
END FUNCTION

FUNCTION atlevel_quadratic (byval lev as double, byval a0 as double, byval aMax as double, byval midpercent as double) as double
  'Stat at a given level, according to an arbitrary curve between two points.
  'CHECKME: Is it actually alright to return a double?
  IF lev < 0 THEN RETURN 0
  IF gen(genMaxLevel) <= 0 THEN RETURN aMax
  DIM as DOUBLE a, b  'quadratic coefficients (c=0 fixed)
  b = 4 * midpercent - 1
  a = 1 - b
  DIM as DOUBLE x = lev / gen(genMaxLevel)
  RETURN (a * x^2 + b * x) * (aMax - a0) + a0 + .1
END FUNCTION
