'OHRRPGCE GAME - More various unsorted routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
'$DYNAMIC
DEFINT A-Z

#include "config.bi"
#include "allmodex.bi"
#include "common.bi"
#include "gglobals.bi"
#include "const.bi"
#include "scrconst.bi"
#include "uiconst.bi"
#include "loading.bi"
#include "hsinterpreter.bi"
#include "savegame.bi"

#include "game.bi"
#include "yetmore.bi"
#include "yetmore2.bi"
#include "moresubs.bi"
#include "menustuf.bi"
#include "bmod.bi"
#include "bmodsubs.bi"

'FIXME: this should not be called directly here. needs wrapping in allmodex.bi
'Mike: why? it's already wrapped in gfx_*.bas
#include "gfx.bi"

''''' Global variables

'Script commands in this file need to REDIM plotslices() and timers(), but FB
'doesn't let you REDIM a global array in a module other than where it is defined!

'Using a lower bound of 1 because 0 is considered an invalid handle
'The size of 64 is just so we won't have to reallocate for a little while
DIM plotslices(1 TO 64) AS Slice Ptr

DIM timers(15) as PlotTimer



REM $STATIC

SUB add_rem_swap_lock_hero (box AS TextBox)
'---ADD/REMOVE/SWAP/LOCK
'---ADD---
IF box.hero_addrem > 0 THEN
 i = first_free_slot_in_party()
 IF i > -1 THEN
  addhero box.hero_addrem, i
  vishero
 END IF
END IF '---end if > 0
'---REMOVE---
IF box.hero_addrem < 0 THEN
 IF herocount(40) > 1 THEN
  i = findhero(-box.hero_addrem, 0, 40, 1)
  IF i > -1 THEN hero(i) = 0
  IF herocount(3) = 0 THEN forceparty
 END IF
END IF '---end if < 0
vishero
'---SWAP-IN---
IF box.hero_swap > 0 THEN
 i = findhero(box.hero_swap, 40, 0, -1)
 IF i > -1 THEN
  FOR o = 0 TO 3
   IF hero(o) = 0 THEN
    doswap i, o
    EXIT FOR
   END IF
  NEXT o
 END IF
END IF '---end if > 0
'---SWAP-OUT---
IF box.hero_swap < 0 THEN
 i = findhero(-box.hero_swap, 0, 40, 1)
 IF i > -1 THEN
  FOR o = 40 TO 4 STEP -1
   IF hero(o) = 0 THEN
    doswap i, o
    IF herocount(3) = 0 THEN forceparty
    EXIT FOR
   END IF
  NEXT o
 END IF
END IF '---end if < 0
'---UNLOCK HERO---
IF box.hero_lock > 0 THEN
 temp = findhero(box.hero_lock, 0, 40, 1)
 IF temp > -1 THEN setbit hmask(), 0, temp, 0
END IF '---end if > 0
'---LOCK HERO---
IF box.hero_lock < 0 THEN
 temp = findhero(-box.hero_lock, 0, 40, 1)
 IF temp > -1 THEN setbit hmask(), 0, temp, 1
END IF '---end if > 0
END SUB

SUB doihavebits
dim her as herodef
FOR i = 0 TO small(gen(genMaxHero), 59)
 loadherodata @her, i
 herobits(i, 0) = her.have_tag    'have hero tag
 herobits(i, 1) = her.alive_tag   'is alive tag
 herobits(i, 2) = her.leader_tag  'is leader tag
 herobits(i, 3) = her.active_tag  'is in active party tag
NEXT i
DIM item_data(dimbinsize(binITM)) AS INTEGER
FOR i = 0 TO gen(genMaxItem)
 loaditemdata item_data(), i
 itembits(i, 0) = item_data(74)   'when have tag
 itembits(i, 1) = item_data(75)   'is in inventory
 itembits(i, 2) = item_data(76)   'is equiped tag
 itembits(i, 3) = item_data(77)   'is equiped by hero in active party
NEXT i
END SUB

SUB embedtext (text$, limit=0)
start = 1
DO WHILE start < LEN(text$)
 '--seek an embed spot
 embedbegin = INSTR(start, text$, "${")
 IF embedbegin = 0 THEN EXIT DO '--failed to find an embed spot
 embedend = INSTR(embedbegin + 4, text$, "}")
 IF embedend = 0 THEN EXIT DO '--embed spot has no end
 '--break apart the string
 before$ = MID$(text$, 1, large(embedbegin - 1, 0))
 after$ = MID$(text$, embedend + 1)
 '--extract the command and arg
 act$ = MID$(text$, embedbegin + 2, 1)
 arg$ = MID$(text$, embedbegin + 3, large(embedend - (embedbegin + 3), 0))
 '--convert the arg to a number
 arg = str2int(arg$)
 '--discourage bad arg values (not perfect)
 IF NOT (arg = 0 AND arg$ <> STRING$(LEN(arg$), "0")) THEN
  IF arg >= 0 THEN '--only permit postive args
   '--by default the embed is unchanged
   insert$ = "${" + act$ + arg$ + "}"
   '--evalued possible actions
   SELECT CASE UCASE$(act$)
    CASE "H": '--Hero name by ID
     '--defaults blank if not found
     insert$ = ""
     where = findhero(arg + 1, 0, 40, 1)
     IF where >= 0 THEN
      insert$ = names(where)
     END IF
    CASE "P": '--Hero name by Party position
     IF arg < 40 THEN
      '--defaults blank if not found
      insert$ = ""
      IF hero(arg) > 0 THEN
       insert$ = names(arg)
      END IF
     END IF
    CASE "C": '--Hero name by caterpillar position
     '--defaults blank if not found
     insert$ = ""
     where = partybyrank(arg)
     IF where >= 0 THEN
      insert$ = names(where)
     END IF
    CASE "V": '--global variable by ID
     '--defaults blank if out-of-range
     insert$ = ""
     IF arg >= 0 AND arg <= 4095 THEN
      insert$ = STR$(global(arg))
     END IF
    CASE "S": '--string variable by ID
     insert$ = ""
     IF bound_arg(arg, 0, UBOUND(plotstr), "string ID", "${S#} text box insert", NO) THEN
      insert$ = plotstr(arg).s
     END IF
   END SELECT
   text$ = before$ + insert$ + after$
   embedend = LEN(before$) + LEN(insert$) + 1
  END IF
 END IF
 '--skip past this embed
 start = embedend + 1
LOOP
'--enforce limit (if set)
IF limit > 0 THEN
 text$ = LEFT$(text$, limit)
END IF
END SUB

SUB scriptstat (id)
'contains an assortment of scripting commands that
'used to depend on access to the hero stat array stat(), but that is irrelevant now,
'because that is a global gam.hero().stat

SELECT CASE AS CONST id
 CASE 64'--get hero stat
  'FIXME: unfortunately this can also access hero level
  'which will suck when we want to add more stats
  slot = bound(retvals(0), 0, 40)
  i = bound(retvals(1), 0, 13)
  IF retvals(2) < 1 THEN
   IF i = 13 THEN
    'This is just backcompat for a very undocumented bugfeature
    scriptret = gam.hero(slot).wep_pic
   ELSEIF i = 12 THEN
    'This is backcompat for a somewhat documented feature
    scriptret = gam.hero(slot).lev
   ELSE
    scriptret = gam.hero(slot).stat.cur.sta(i)
   END IF
  ELSE
   IF i = 13 THEN
    'This is just backcompat for a very undocumented bugfeature
    scriptret = gam.hero(slot).wep_pal
   ELSEIF i = 12 THEN
    'This is backcompat for a barely documented feature
    scriptret = gam.hero(slot).lev_gain
   ELSE
    scriptret = gam.hero(slot).stat.max.sta(i)
   END IF
  END IF
 CASE 66'--add hero
  IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxHero) THEN
   slot = first_free_slot_in_party()
   IF slot >= 0 THEN
    'retvals(0) is the real hero id, addhero subtracts the 1 again
    addhero retvals(0) + 1, slot
    vishero
   END IF
   scriptret = slot
  END IF
 CASE 67'--delete hero
  IF herocount(40) > 1 THEN
   i = findhero(bound(retvals(0), 0, 59) + 1, 0, 40, 1)
   IF i > -1 THEN hero(i) = 0
   IF herocount(3) = 0 THEN forceparty
   vishero
  END IF
 CASE 68'--swap out hero
  i = findhero(retvals(0) + 1, 0, 40, 1)
  IF i > -1 THEN
   FOR o = 40 TO 4 STEP -1
    IF hero(o) = 0 THEN
     doswap i, o
     IF herocount(3) = 0 THEN forceparty
     vishero
     EXIT FOR
    END IF
   NEXT o
  END IF
 CASE 69'--swap in hero
  i = findhero(retvals(0) + 1, 40, 0, -1)
  IF i > -1 THEN
   FOR o = 0 TO 3
    IF hero(o) = 0 THEN
     doswap i, o
     vishero
     EXIT FOR
    END IF
   NEXT o
  END IF
 CASE 83'--set hero stat
  'FIXME: this command can also set hero level (without updating stats)
  ' which sucks for when we want to add more stats.
  slot = bound(retvals(0), 0, 40)
  i = bound(retvals(1), 0, 13)
  IF retvals(3) < 1 THEN
   IF i = 13 THEN
    'This is just backcompat for a very undocumented bugfeature
    gam.hero(slot).wep_pic = retvals(2)
   ELSEIF i = 12 THEN
    'This is backcompat for a mostly undocumented feature
    gam.hero(slot).lev = retvals(2)
   ELSE
    gam.hero(slot).stat.cur.sta(i) = retvals(2)
   END IF
  ELSE
   IF i = 13 THEN
    'This is backcompat for a very undocumented bugfeature
    gam.hero(slot).wep_pal = retvals(2)
   ELSEIF i = 12 THEN
    'This is backcompat for an undocumented feature
    gam.hero(slot).lev_gain = retvals(2)
   ELSE
    gam.hero(slot).stat.max.sta(i) = retvals(2)
   END IF
  END IF
 CASE 89'--swap by position
  doswap bound(retvals(0), 0, 40), bound(retvals(1), 0, 40)
  vishero
 CASE 110'--set hero picture
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   i = bound(retvals(0), 0, 40)
   retvals(2) = bound(retvals(2), 0, 1)
   IF retvals(2) = 0 THEN gam.hero(i).battle_pic = bound(retvals(1), 0, gen(genMaxHeroPic))
   IF retvals(2) = 1 THEN gam.hero(i).pic = bound(retvals(1), 0, gen(genMaxNPCPic))
   IF i < 4 THEN
    vishero
   END IF
  END IF
 CASE 111'--set hero palette
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   i = bound(retvals(0), 0, 40)
   j = bound(retvals(2), 0, 1)
   IF j < 1 THEN
    gam.hero(i).battle_pal = bound(retvals(1), -1, 32767)
   ELSE
    gam.hero(i).pal = bound(retvals(1), -1, 32767)
   END IF
   IF i < 4 THEN
    vishero
   END IF
  END IF
 CASE 112'--get hero picture
  IF retvals(1) < 1 THEN
   scriptret = gam.hero(bound(retvals(0), 0, 40)).battle_pic
  ELSE
   scriptret = gam.hero(bound(retvals(0), 0, 40)).pic
  END IF
 CASE 113'--get hero palette
  IF retvals(1) < 1 THEN
   scriptret = gam.hero(bound(retvals(0), 0, 40)).battle_pal
  ELSE
   scriptret = gam.hero(bound(retvals(0), 0, 40)).pal
  END IF
 CASE 150'--status screen
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   IF hero(retvals(0)) > 0 THEN
    status retvals(0)
   END IF
  END IF
 CASE 152'--spells menu
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   IF hero(retvals(0)) > 0 THEN
    spells_menu retvals(0)
   END IF
  END IF
 CASE 154'--equip menu
  'Can explicitly choose a hero to equip
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   IF hero(retvals(0)) > 0 THEN
    equip retvals(0)
   END IF
  END IF
  IF retvals(0) = -1 THEN
   'Or pass -1 to equip the first hero in the party
   FOR i = 0 TO 3
    IF hero(i) > 0 THEN
     equip i
     EXIT FOR
    END IF
   NEXT i
  END IF
 CASE 157'--order menu
  heroswap 0
 CASE 158'--team menu
  heroswap 1
 CASE 183'--set hero level (who, what, allow forgetting spells)
  IF retvals(0) >= 0 AND retvals(0) <= 40 AND retvals(1) >= 0 THEN  'we should make the regular level limit customisable anyway
   gam.hero(retvals(0)).lev_gain = retvals(1) - gam.hero(retvals(0)).lev
   gam.hero(retvals(0)).lev = retvals(1)
   exlev(retvals(0), 1) = exptolevel(retvals(1))
   exlev(retvals(0), 0) = 0  'XP attained towards the next level
   updatestatslevelup retvals(0), retvals(2) 'updates stats and spells
  END IF
 CASE 184'--give experience (who, how much)
  'who = -1 targets battle party
  IF retvals(0) <> -1 THEN
   IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
    giveheroexperience retvals(0), retvals(1)
    updatestatslevelup retvals(0), 0
   END IF
  ELSE
   'This sets the level gain and learnt spells and calls updatestatslevelup for every hero
   distribute_party_experience retvals(1)
  END IF
 CASE 185'--hero levelled (who)
  scriptret = gam.hero(bound(retvals(0), 0, 40)).lev_gain
 CASE 186'--spells learnt
  'NOTE: this is deprecated but will remain for backcompat. New games should use "spells learned" 
  found = 0
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   FOR i = retvals(0) * 96 TO retvals(0) * 96 + 95
    IF readbit(learnmask(), 0, i) THEN
     IF retvals(1) = found THEN
      scriptret = spell(retvals(0), (i \ 24) MOD 4, i MOD 24) - 1
      EXIT FOR
     END IF
     found = found + 1
    END IF
   NEXT
   IF retvals(1) = -1 THEN scriptret = found  'getcount
  END IF
 CASE 269'--totalexperience
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   scriptret = 0
   FOR i = 0 TO gam.hero(retvals(0)).lev - 1
    scriptret += exptolevel(i)
   NEXT
   scriptret += exlev(retvals(0), 0)
  END IF
 CASE 270'--experiencetolevel
  scriptret = 0
  FOR i = 0 TO retvals(0) - 1
   scriptret += exptolevel(i)
  NEXT
 CASE 271'--experiencetonextlevel
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   scriptret = exlev(retvals(0), 1) - exlev(retvals(0), 0)
  END IF
 CASE 272'--setexperience  (who, what, allowforget)
  IF retvals(0) >= 0 AND retvals(0) <= 40 AND retvals(1) >= 0 THEN
   setheroexperience retvals(0), retvals(1), retvals(2), exlev()
  END IF
 CASE 445'--update level up learning(who, allowforget)
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   learn_spells_for_current_level retvals(0), (retvals(1)<>0)
  END IF
 CASE 449'--reset hero picture
  i = retvals(0)
  j = retvals(1)
  IF valid_hero_party(i) THEN
   IF hero(i) > 0 THEN
    IF bound_arg(j, 0, 1, "in or out of battle") THEN
     DIM her as herodef
     loadherodata @her, hero(i) - 1
     IF j = 0 THEN gam.hero(i).battle_pic = her.sprite
     IF j = 1 THEN gam.hero(i).pic = her.walk_sprite
     IF i < 4 THEN vishero
    END IF
   END IF
  END IF
 CASE 450'--reset hero palette
  i = retvals(0)
  j = retvals(1)
  IF valid_hero_party(i) THEN
   IF hero(i) > 0 THEN
    IF bound_arg(j, 0, 1, "in or out of battle") THEN
     DIM her as herodef
     loadherodata @her, hero(i) - 1
     IF j = 0 THEN gam.hero(i).battle_pal = her.sprite_pal
     IF j = 1 THEN gam.hero(i).pal = her.walk_sprite_pal
     IF i < 4 THEN vishero
    END IF
   END IF
  END IF
 CASE 497'--set hero base elemental resist (hero, element, percent)
  IF really_valid_hero_party(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, gen(genNumElements) - 1, "element number") THEN
    gam.hero(retvals(0)).elementals(retvals(1)) = 0.01 * retvals(2)
   END IF
  END IF
 CASE 498'--hero base elemental resist as int (hero, element)
  IF really_valid_hero_party(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, gen(genNumElements) - 1, "element number") THEN
    scriptret = 100 * gam.hero(retvals(0)).elementals(retvals(1))  'rounds to nearest int
   END IF
  END IF
 CASE 499'--hero total elemental resist as int (hero, element)
  IF really_valid_hero_party(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, gen(genNumElements) - 1, "element number") THEN
    DIM elementals(gen(genNumElements) - 1) AS SINGLE
    calc_hero_elementals elementals(), retvals(0)
    scriptret = 100 * elementals(retvals(1))  'rounds to nearest int
   END IF
  END IF
END SELECT
END SUB

SUB forceparty ()
'---MAKE SURE YOU HAVE AN ACTIVE PARTY---
fpi = findhero(-1, 0, 40, 1)
IF fpi > -1 THEN
 FOR fpo = 0 TO 3
  IF hero(fpo) = 0 THEN
   doswap fpi, fpo
   EXIT FOR
  END IF
 NEXT fpo
END IF
END SUB

FUNCTION gethighbyte (n) as integer
RETURN n SHL 8
END FUNCTION

'Deprecated; Use get_valid_npc for all new NPC commands
FUNCTION getnpcref (seekid as integer, offset as integer) as integer
SELECT CASE seekid

 CASE -300 TO -1'--direct reference
  getnpcref = (seekid + 1) * -1
  EXIT FUNCTION

 CASE 0 TO UBOUND(npcs) 'ID
  found = 0
  FOR i = 0 TO 299
   IF npc(i).id - 1 = seekid THEN
    IF found = offset THEN
     getnpcref = i
     EXIT FUNCTION
    END IF
    found = found + 1
   END IF
  NEXT i

END SELECT

'--failure
getnpcref = -1
END FUNCTION

'Replacement for getnpcref.
'Given NPC ref or NPC ID, return npc() index, or throw a scripterr and return -1
'Note this is stricter than getnpcref: invalid npc refs are not alright!
'References to Hidden/Disabled NPCs are alright.
FUNCTION get_valid_npc (BYVAL seekid as integer, BYVAL errlvl as integer = 5) as integer
 IF seekid < 0 THEN
  DIM npcidx as integer = (seekid + 1) * -1
  IF npcidx > 299 ORELSE npc(npcidx).id = 0 THEN
   scripterr commandname(curcmd->value) & ": invalid npc reference " & seekid & " (maybe the NPC was deleted?)", errlvl
   RETURN -1
  END IF
  RETURN npcidx
 ELSE
  FOR i as integer = 0 TO 299
   IF npc(i).id - 1 = seekid THEN RETURN i
  NEXT
  scripterr commandname(curcmd->value) & ": invalid npc reference; no NPCs of ID " & seekid & " exist", errlvl
  RETURN -1
 END IF
END FUNCTION

SUB greyscalepal
FOR i = bound(retvals(0), 0, 255) TO bound(retvals(1), 0, 255)
 master(i).r = bound((master(i).r + master(i).g + master(i).b) / 3, 0, 255)
 master(i).g = master(i).r
 master(i).b = master(i).r
NEXT i
END SUB

FUNCTION herobyrank (slot as integer) as integer
IF slot >= 0 AND slot <= 3 THEN
 j = -1
 FOR i = 0 TO 3
  IF hero(i) > 0 THEN j = j + 1
  IF j = slot THEN
   RETURN hero(i) - 1
  END IF
 NEXT i
END IF
RETURN -1
END FUNCTION

SUB interpolatecat
'given the current positions of the caterpillar party, interpolate their inbetween frames
FOR o = 0 TO 10 STEP 5
 FOR i = o + 1 TO o + 4
  catx(i) = catx(i - 1) + ((catx(o + 5) - catx(o)) / 5)
  caty(i) = caty(i - 1) + ((caty(o + 5) - caty(o)) / 5)
  catd(i) = catd(o)
 NEXT i
NEXT o
END SUB

SUB npcplot
'This SUB will be called when a map is incompletely loaded (NPC instances before definitions
'or vice versa), and that's hard to avoid, because a script could load them with two separate loadmapstate
'calls. So we must tolerate invalid NPC IDs and anything else. So here we mark all NPCs as hidden which
'would otherwise cause problems

FOR i = 0 TO 299
 curnpc = ABS(npc(i).id) - 1

 IF curnpc > UBOUND(npcs) THEN
  'Invalid ID number; hide. Probably a partially loaded map.
  npc(i).id = -curnpc - 1
  CONTINUE FOR
 END IF

 IF npc(i).id < 0 THEN
  '--check reappearance tags for existing but hidden NPCs
  IF istag(npcs(curnpc).tag1, 1) AND istag(npcs(curnpc).tag2, 1) AND istag(1000 + npcs(curnpc).usetag, 0) = 0 THEN
   npc(i).id = ABS(npc(i).id)
  END IF
 END IF

 IF npc(i).id > 0 THEN
  '--check removal tags for existing visible NPCs
  IF istag(npcs(curnpc).tag1, 1) = 0 OR istag(npcs(curnpc).tag2, 1) = 0 OR istag(1000 + npcs(curnpc).usetag, 0) THEN
   npc(i).id = npc(i).id * -1
  END IF
  'IF readbit(tag(), 0, ABS(npcs(curnpc * 15 + 9))) <> SGN(SGN(npcs(curnpc * 15 + 9)) + 1) AND npcs(curnpc * 15 + 9) <> 0 THEN
  '  npcl(i + 600) = npcl(i + 600) * -1
  'END IF
  'IF readbit(tag(), 0, ABS(npcs(curnpc * 15 + 10))) <> SGN(SGN(npcs(curnpc * 15 + 10)) + 1) AND npcs(curnpc * 15 + 10) <> 0 THEN
  '  npcl(i + 600) = npcl(i + 600) * -1
  'END IF
  'IF npcs(curnpc * 15 + 11) > 0 THEN
  '  IF readbit(tag(), 0, 1000 + npcs(curnpc * 15 + 11)) = 1 THEN
  '    npcl(i + 600) = npcl(i + 600) * -1
  '  END IF
  'END IF
 END IF

NEXT i
END SUB

FUNCTION script_keyval (BYVAL key as integer) as integer
 'Wrapper around keyval for use by scripts: performs scancode mapping for back-compat

 DIM ret as integer = 0

 IF key >= 0 AND key <= 127 THEN
  ret = keyval(key)
 END IF

 IF readbit(gen(), genBits2, 8) = 0 THEN  'If improved scancodes not enabled
  'The new scancodes separate some keys which previously had the same scancode.
  'For backwards compatibility (whether or not you recompile your scripts with
  'a new copy of scancodes.hsi) we make the newly separated scancodes behave
  'as if they were indistinguishable.
  SELECT CASE key
   CASE scHome TO scDelete
    ret OR= keyval(key + scNumpad7 - scHome)
   CASE scNumpad7 TO scNumpad9, scNumpad4 TO scNumpad6, scNumpad1 TO scNumpadPeriod
    ret OR= keyval(key - scNumpad7 + scHome)
   CASE scSlash:       ret OR= keyval(scNumpadSlash)
   CASE scEnter:       ret OR= keyval(scNumpadEnter)
   CASE scNumlock:     ret OR= keyval(scPause)
   CASE scNumpadSlash: ret OR= keyval(scSlash)
   CASE scNumpadEnter: ret OR= keyval(scEnter)
   CASE scPause:       ret OR= keyval(scNumlock)
  END SELECT
 END IF

 RETURN ret
END FUNCTION

SUB onkeyscript (scriptnum)
doit = 0
FOR i = 0 TO 5
 IF carray(i) THEN doit = 1: EXIT FOR
NEXT i

IF doit = 0 THEN
 FOR i = 1 TO 127
  'We scan all keys, triggering a script even if its scancode is not one
  'accessible via script commands so that custom "press any key" scripts work.
  IF keyval(i) THEN doit = 1: EXIT FOR
 NEXT i
END IF

IF gam.mouse_enabled THEN
 IF mouse.clicks THEN doit = 1
END IF

IF nowscript >= 0 THEN
 IF scrat(nowscript).state = stwait AND scrat(nowscript).curvalue = 9 THEN
  '--never trigger a onkey script when the previous script
  '--has a "wait for key" command active
  doit = 0
 END IF
END IF

IF doit = 1 THEN
 rsr = runscript(scriptnum, nowscript + 1, -1, "on-key", plottrigger)
END IF

END SUB

FUNCTION partybyrank (slot as integer) as integer
result = -1
IF slot >= 0 AND slot <= 3 THEN
 j = -1
 FOR i = 0 TO 3
  IF hero(i) > 0 THEN j = j + 1
  IF j = slot THEN
   result = i
   EXIT FOR
  END IF
 NEXT i
END IF
partybyrank = result
END FUNCTION

FUNCTION playtime (d as integer, h as integer, m as integer) as string
s$ = ""

SELECT CASE d
 CASE 1
  s$ = s$ + STR$(d) + " " + readglobalstring$(154, "day", 10) + " "
 CASE IS > 1
  s$ = s$ + STR$(d) + " " + readglobalstring$(155, "days", 10) + " "
END SELECT

SELECT CASE h
 CASE 1
  s$ = s$ + STR$(h) + " " + readglobalstring$(156, "hour", 10) + " "
 CASE IS > 1
  s$ = s$ + STR$(h) + " " + readglobalstring$(157, "hours", 10) + " "
END SELECT

SELECT CASE m
 CASE 1
  s$ = s$ + STR$(m) + " " + readglobalstring$(158, "minute", 10) + " "
 CASE IS > 1
  s$ = s$ + STR$(m) + " " + readglobalstring$(159, "minutes", 10) + " "
END SELECT

playtime$ = s$

END FUNCTION

SUB playtimer
STATIC n AS DOUBLE

IF TIMER >= n + 1 OR n - TIMER > 3600 THEN
 n = INT(TIMER)
 gen(genSeconds) = gen(genSeconds) + 1
 WHILE gen(genSeconds) >= 60
  gen(genSeconds) = gen(genSeconds) - 60
  gen(genMinutes) = gen(genMinutes) + 1
 WEND
 WHILE gen(genMinutes) >= 60
  gen(genMinutes) = gen(genMinutes) - 60
  gen(genHours) = gen(genHours) + 1
 WEND
 WHILE gen(genHours) >= 24
  gen(genHours) = gen(genHours) - 24
  IF gen(genDays) < 32767 THEN gen(genDays) = gen(genDays) + 1
 WEND
END IF

END SUB

FUNCTION rankincaterpillar (heroid as integer) as integer
result = -1
o = 0
FOR i = 0 TO 3
 IF hero(i) > 0 THEN
  IF hero(i) - 1 = heroid THEN result = o
  o = o + 1
 END IF
NEXT i
rankincaterpillar = result
END FUNCTION

FUNCTION readfoemap (x as integer, y as integer, fh as integer) as integer
RETURN readbyte(fh, 12 + (y * mapsizetiles.x) + x) 
END FUNCTION

SUB scriptadvanced (id)

'contains advanced scripting stuff such as pixel-perfect movement

SELECT CASE AS CONST id

 CASE 135'--puthero
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   cropposition retvals(1), retvals(2), 20
   catx(retvals(0) * 5) = retvals(1)
   caty(retvals(0) * 5) = retvals(2)
  END IF
 CASE 136'--putnpc
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   cropposition retvals(1), retvals(2), 20
   npc(npcref).x = retvals(1)
   npc(npcref).y = retvals(2)
  END IF
 CASE 137'--putcamera
  gen(cameramode) = stopcam
  mapx = retvals(0)
  mapy = retvals(1)
  limitcamera mapx, mapy
 CASE 138'--heropixelx
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   scriptret = catx(retvals(0) * 5)
  END IF
 CASE 139'--heropixely
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   scriptret = caty(retvals(0) * 5)
  END IF
 CASE 140'--npcpixelx
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   scriptret = npc(npcref).x
  END IF
 CASE 141'--npcpixely
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   scriptret = npc(npcref).y
  END IF
 CASE 142'--camerapixelx
  scriptret = mapx
 CASE 143'--camerapixely
  scriptret = mapy
 CASE 147'--read general
  IF retvals(0) >= 0 AND retvals(0) <= UBOUND(gen) THEN
   scriptret = gen(retvals(0))
  END IF
 CASE 148'--write general
  IF retvals(0) >= 0 AND retvals(0) <= UBOUND(gen) THEN
   gen(retvals(0)) = retvals(1)
  END IF
 CASE 159'--init mouse
  IF havemouse() THEN scriptret = 1 ELSE scriptret = 0
  hidemousecursor
  mouse = readmouse  'Why do we do this?
  gam.mouse_enabled = YES
 CASE 160'--get mouse x
  scriptret = mouse.x
 CASE 161'--get mouse y
  scriptret = mouse.y
 CASE 162'--mouse button
  IF retvals(0) <= 2 THEN
   IF mouse.buttons AND (2 ^ retvals(0)) THEN scriptret = 1 ELSE scriptret = 0
  END IF
 CASE 163'--put mouse
  movemouse bound(retvals(0), 0, 319), bound(retvals(1), 0, 199)
  mouse = readmouse
 CASE 164'--mouse region(xmin, xmax, ymin, ymax)
  IF retvals(0) = -1 AND retvals(1) = -1 AND retvals(2) = -1 AND retvals(3) = -1 THEN
   mouserect -1, -1, -1, -1
  ELSE
   retvals(0) = bound(retvals(0), 0, 319)
   retvals(1) = bound(retvals(1), retvals(0), 319)
   retvals(2) = bound(retvals(2), 0, 199)
   retvals(3) = bound(retvals(3), retvals(2), 199)
   mouserect retvals(0), retvals(1), retvals(2), retvals(3)
  END IF
  mouse = readmouse
 CASE 178'--readgmap
  IF retvals(0) >= 0 AND retvals(0) <= 19 THEN
   scriptret = gmap(retvals(0))
  END IF
 CASE 179'--writegmap
  IF retvals(0) >= 0 AND retvals(0) <= 19 THEN
   gmap(retvals(0)) = retvals(1)
   IF retvals(0) = 5 THEN setoutside -1  'hint: always use the wrapper
   IF retvals(0) = 6 AND gmap(5) = 2 THEN setoutside retvals(1)
  END IF
 CASE 492'--mouse click
  IF retvals(0) <= 2 THEN
   IF mouse.clicks AND (2 ^ retvals(0)) THEN scriptret = 1 ELSE scriptret = 0
  END IF

END SELECT

END SUB

SUB scriptmisc (id)
'contains a whole mess of scripting commands that do not depend on
'any main-module level local variables or GOSUBs

SELECT CASE AS CONST id

 CASE 0'--noop
  scripterr "encountered clean noop", 1
 CASE 1'--Wait (cycles)
  IF retvals(0) > 0 THEN
   GOSUB setwaitstate
  END IF
 CASE 2'--wait for all
  GOSUB setwaitstate
 CASE 3'--wait for hero
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   GOSUB setwaitstate
  END IF
 CASE 4'--wait for NPC
  IF retvals(0) >= -300 AND retvals(0) <= UBOUND(npcs) THEN
   GOSUB setwaitstate
  END IF
 CASE 5'--suspend npcs
  setbit gen(), 44, suspendnpcs, 1
 CASE 6'--suspend player
  setbit gen(), 44, suspendplayer, 1
 CASE 7'--resume npcs
  setbit gen(), 44, suspendnpcs, 0
 CASE 8'--resume player
  setbit gen(), 44, suspendplayer, 0
 CASE 9'--wait for key
  GOSUB setwaitstate
 CASE 10'--walk hero
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   SELECT CASE retvals(1)
    CASE 0'--north
     catd(retvals(0) * 5) = 0
     ygo(retvals(0)) = retvals(2) * 20
    CASE 1'--east
     catd(retvals(0) * 5) = 1
     xgo(retvals(0)) = (retvals(2) * 20) * -1
    CASE 2'--south
     catd(retvals(0) * 5) = 2
     ygo(retvals(0)) = (retvals(2) * 20) * -1
    CASE 3'--west
     catd(retvals(0) * 5) = 3
     xgo(retvals(0)) = retvals(2) * 20
   END SELECT
  END IF
 CASE 12'--check tag
  scriptret = ABS(istag(retvals(0), 0))
 CASE 13'--set tag
  IF retvals(0) > 1 AND retvals(0) < 2000 THEN  'there are actually 2048 tags
   setbit tag(), 0, retvals(0), retvals(1)
   npcplot
  END IF
 CASE 17'--get item
  IF valid_item(retvals(0)) THEN
   IF retvals(1) >= 1 THEN
    getitem retvals(0) + 1, retvals(1)
    evalitemtag
   END IF
  END IF
 CASE 18'--delete item
  IF valid_item(retvals(0)) THEN
   IF retvals(1) >= 1 THEN
    delitem retvals(0) + 1, retvals(1)
    evalitemtag
   END IF
  END IF
 CASE 19'--leader
  FOR i = 0 TO 3
   IF hero(i) > 0 THEN scriptret = hero(i) - 1: EXIT FOR
  NEXT i
 CASE 20'--get money
  gold = gold + retvals(0)
 CASE 21'--lose money
  gold = gold - retvals(0)
  IF gold < 0 THEN gold = 0
 CASE 22'--pay money
  IF gold - retvals(0) >= 0 THEN
   gold = gold - retvals(0)
   scriptret = -1
  ELSE
   scriptret = 0
  END IF
 CASE 25'--set hero frame
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   wtog(retvals(0)) = bound(retvals(1), 0, 1) * 2
  END IF
 CASE 27'--suspend overlay
  setbit gen(), 44, suspendoverlay, 1
 CASE 28'--play song
  'loadsong game + "." + STR$(retvals(0))
  wrappedsong retvals(0)
 CASE 29'--stop song
  stopsong
 CASE 30'--keyval
  'This used to be keyispressed; which undocumentedly reported two bits
  'instead of true/false.
  IF retvals(0) >= 0 AND retvals(0) < 127 THEN
   'keyval() reports a 3rd bit, but didn't at the time that this command was (re-)documented
   scriptret = script_keyval(retvals(0)) AND 3
  ELSE
   scripterr "invalid scancode keyval(" & retvals(0) & ")", 4
  END IF
 CASE 31'--rank in caterpillar
  scriptret = rankincaterpillar(retvals(0))
 CASE 38'--camera follows hero
  gen(cameramode) = herocam
  gen(cameraArg) = bound(retvals(0), 0, 3) * 5
 CASE 40'--pan camera
  gen(cameramode) = pancam
  gen(cameraArg) = small(large(retvals(0), 0), 3)
  gen(cameraArg2) = large(retvals(1), 0) * (20 / large(retvals(2), 1))
  gen(cameraArg3) = large(retvals(2), 1)
 CASE 41'--focus camera
  gen(cameramode) = focuscam
  gen(cameraArg) = (retvals(0) * 20) - 150
  gen(cameraArg2) = (retvals(1) * 20) - 90
  gen(cameraArg3) = ABS(retvals(2))
  gen(cameraArg4) = ABS(retvals(2))
  limitcamera gen(cameraArg), gen(cameraArg2)
 CASE 42'--wait for camera
  GOSUB setwaitstate
 CASE 43'--hero x
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   scriptret = catx(retvals(0) * 5) \ 20
  END IF
 CASE 44'--hero y
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   scriptret = caty(retvals(0) * 5) \ 20
  END IF
 CASE 47'--suspend obstruction
  setbit gen(), 44, suspendobstruction, 1
 CASE 48'--resume obstruction
  setbit gen(), 44, suspendobstruction, 0
 CASE 49'--suspend hero walls
  setbit gen(), 44, suspendherowalls, 1
 CASE 50'--suspend NPC walls
  setbit gen(), 44, suspendnpcwalls, 1
 CASE 51'--resume hero walls
  setbit gen(), 44, suspendherowalls, 0
 CASE 53'--set hero direction
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   catd(retvals(0) * 5) = ABS(retvals(1)) MOD 4
  END IF
 CASE 57, 118'--suspend caterpillar
  setbit gen(), 44, suspendcatapillar, 1
 CASE 58, 119'--resume caterpillar
  setbit gen(), 44, suspendcatapillar, 0
  interpolatecat
 CASE 59'--wait for text box
  IF readbit(gen(), 44, suspendboxadvance) = 0 THEN
   GOSUB setwaitstate
  END IF
 CASE 60'--equip where
  scriptret = 0
  IF valid_item(retvals(1)) THEN
   IF valid_hero_party(retvals(0)) THEN
    loaditemdata buffer(), retvals(1)
    i = hero(retvals(0)) - 1
    IF i >= 0 THEN
     IF readbit(buffer(), 66, i) THEN
      scriptret = buffer(49)
     END IF
    END IF
   END IF
  END IF
 CASE 62, 168'--suspend random enemies
  setbit gen(), 44, suspendrandomenemies, 1
  '--resume random enemies is not here! it works different!
 CASE 65'--resume overlay
  setbit gen(), 44, suspendoverlay, 0
 CASE 70'--room in active party
  scriptret = 4 - herocount(3)
 CASE 71'--lock hero
  temp = findhero(retvals(0) + 1, 0, 40, 1)
  IF temp > -1 THEN setbit hmask(), 0, temp, 1
 CASE 72'--unlock hero
  temp = findhero(retvals(0) + 1, 0, 40, 1)
  IF temp > -1 THEN setbit hmask(), 0, temp, 0
 CASE 74'--set death script
  gen(genGameoverScript) = large(retvals(0), 0)
 CASE 75'--fade screen out
  FOR i = 0 TO 2
   retvals(i) = bound(iif(retvals(i), retvals(i) * 4 + 3, 0), 0, 255)
  NEXT
  fadeout retvals(0), retvals(1), retvals(2)
 CASE 76'--fade screen in
  fadein
 CASE 81'--set hero speed
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   herospeed(retvals(0)) = bound(retvals(1), 0, 20)
  END IF
 CASE 82'--inventory
  scriptret = countitem(retvals(0) + 1)
 CASE 84'--suspend box advance
  setbit gen(), 44, suspendboxadvance, 1
 CASE 85'--resume box advance
  setbit gen(), 44, suspendboxadvance, 0
 CASE 87'--set hero position
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
  cropposition retvals(1), retvals(2), 1
   FOR i = 0 TO 4
    catx(small(retvals(0) * 5 + i, 15)) = retvals(1) * 20
    caty(small(retvals(0) * 5 + i, 15)) = retvals(2) * 20
   NEXT i
  END IF
 CASE 90'--find hero
  scriptret = findhero(retvals(0) + 1, 0, 40, 1)
 CASE 91'--check equipment
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   scriptret = eqstuf(retvals(0), bound(retvals(1) - 1, 0, 4)) - 1
  ELSE
   scriptret = 0
  END IF
 CASE 92'--days of play
  scriptret = gen(genDays)
 CASE 93'--hours of play
  scriptret = gen(genHours)
 CASE 94'--minutes of play
  scriptret = gen(genMinutes)
 CASE 95'--resume NPC walls
  setbit gen(), 44, suspendnpcwalls, 0
 CASE 96'--set hero Z
  catz(bound(retvals(0), 0, 3) * 5) = retvals(1)
 CASE 102'--hero direction
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   scriptret = catd(retvals(0) * 5)
  END IF
 CASE 103'--reset palette
  loadpalette master(), gen(genMasterPal)
  LoadUIColors uilook(), gen(genMasterPal)
 CASE 104'--tweak palette
  tweakpalette
 CASE 105'--read color
  IF retvals(0) >= 0 AND retvals(0) < 256 THEN
   IF retvals(1) = 0 THEN scriptret = master(retvals(0)).r / 4
   IF retvals(1) = 1 THEN scriptret = master(retvals(0)).g / 4
   IF retvals(1) = 2 THEN scriptret = master(retvals(0)).b / 4
  END IF
 CASE 106'--write color
  IF retvals(0) >= 0 AND retvals(0) < 256 THEN
   temp = bound(retvals(2), 0, 63)
   IF retvals(1) = 0 THEN master(retvals(0)).r = iif(temp, temp * 4 + 3, 0)
   IF retvals(1) = 1 THEN master(retvals(0)).g = iif(temp, temp * 4 + 3, 0)
   IF retvals(1) = 2 THEN master(retvals(0)).b = iif(temp, temp * 4 + 3, 0)
  END IF
 CASE 107'--update palette
  setpal master()
 CASE 108'--seed random
  IF retvals(0) THEN
   RANDOMIZE retvals(0), 3
  ELSE
   RANDOMIZE TIMER, 3
  END IF
 CASE 109'--grey scale palette
  greyscalepal
 CASE 114'--read global
  IF retvals(0) >= 0 AND retvals(0) <= 4095 THEN
   scriptret = global(retvals(0))
  ELSE
   scripterr "readglobal: Cannot read global " & retvals(0) & ". Out of range", 5
  END IF
 CASE 115'--write global
  IF retvals(0) >= 0 AND retvals(0) <= 4095 THEN
   global(retvals(0)) = retvals(1)
  ELSE
   scripterr "writeglobal: Cannot write global " & retvals(0) & ". Out of range", 5
  END IF
 CASE 116'--hero is walking
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   IF xgo(retvals(0)) = 0 AND ygo(retvals(0)) = 0 THEN
    scriptret = 0
   ELSE
    scriptret = 1
   END IF
  END IF
 CASE 127'--teach spell
  scriptret = trylearn(bound(retvals(0), 0, 40), retvals(1), retvals(2))
 CASE 128'--forget spell
  scriptret = 0
  retvals(0) = bound(retvals(0), 0, 40)
  FOR i = 0 TO 3
   FOR j = 0 TO 23
    IF spell(retvals(0), i, j) = retvals(1) THEN
     spell(retvals(0), i, j) = 0
     scriptret = 1
    END IF
   NEXT j
  NEXT i
 CASE 129'--read spell
  IF retvals(0) >= 0 AND retvals(0) <= 40 AND retvals(1) >= 0 AND retvals(1) <= 3 AND retvals(2) >= 0 AND retvals(2) <= 23 THEN
   scriptret = spell(retvals(0), retvals(1), retvals(2))
  ELSE
   scriptret = 0
  END IF
 CASE 130'--write spell
  IF retvals(0) >= 0 AND retvals(0) <= 40 AND retvals(1) >= 0 AND retvals(1) <= 3 AND retvals(2) >= 0 AND retvals(2) <= 23 AND retvals(3) >= 0 THEN
   spell(retvals(0), retvals(1), retvals(2)) = retvals(3)
  END IF
 CASE 131'--knows spell
  scriptret = 0
  retvals(0) = bound(retvals(0), 0, 40)
  IF retvals(1) > 0 THEN
   FOR i = 0 TO 3
    FOR j = 0 TO 23
     IF spell(retvals(0), i, j) = retvals(1) THEN
      scriptret = 1
      EXIT FOR
     END IF
    NEXT j
   NEXT i
  END IF
 CASE 132'--can learn spell
  scriptret = 0
  DIM partyslot AS INTEGER
  DIM heroID as INTEGER
  partyslot = bound(retvals(0), 0, 40)
  heroID = hero(partyslot) - 1
  IF heroID = -1 THEN
   scripterr "can learn spell: fail on empty party slot " & partyslot, 4
  ELSE
   IF retvals(1) > 0 THEN
    DIM her as herodef
    loadherodata @her, heroID
    FOR i = 0 TO 3
     FOR j = 0 TO 23
      IF spell(partyslot, i, j) = 0 THEN
       IF her.spell_lists(i,j).attack = retvals(1) AND her.spell_lists(i,j).learned = retvals(2) THEN
        scriptret = 1
        EXIT FOR
       END IF
      END IF
     NEXT j
    NEXT i
   END IF
  END IF
 CASE 133'--hero by slot
  IF retvals(0) >= 0 AND retvals(0) <= 40 THEN
   scriptret = hero(retvals(0)) - 1
  ELSE
   scriptret = -1
  END IF
 CASE 134'--hero by rank
  scriptret = herobyrank(retvals(0))
 CASE 145'--pick hero
  scriptret = onwho(readglobalstring$(135, "Which Hero?", 20), 1)
 CASE 146'--rename hero by slot
  IF valid_hero_party(retvals(0)) THEN
   IF hero(retvals(0)) > 0 THEN
    renamehero retvals(0), YES
   END IF
  END IF
 CASE 171'--saveslotused
  IF retvals(0) >= 1 AND retvals(0) <= 32 THEN
   IF save_slot_used(retvals(0) - 1) THEN scriptret = 1 ELSE scriptret = 0
  END IF
 CASE 172'--importglobals
  IF retvals(0) >= 1 AND retvals(0) <= 32 THEN
   IF retvals(1) = -1 THEN 'importglobals(slot)
    retvals(1) = 0
    retvals(2) = 4095
   END IF
   IF retvals(1) >= 0 AND retvals(1) <= 4095 THEN
    IF retvals(2) = -1 THEN 'importglobals(slot,id)
     remval = global(retvals(1))
     loadglobalvars retvals(0) - 1, retvals(1), retvals(1)
     scriptret = global(retvals(1))
     global(retvals(1)) = remval
    ELSE                    'importglobals(slot,first,last)
     IF retvals(2) <= 4095 AND retvals(1) <= retvals(2) THEN
      loadglobalvars retvals(0) - 1, retvals(1), retvals(2)
     END IF
    END IF
   END IF
  END IF
 CASE 173'--exportglobals
  IF retvals(0) >= 1 AND retvals(0) <= 32 AND retvals(1) >= 0 AND retvals(2) <= 4095 AND retvals(1) <= retvals(2) THEN
   saveglobalvars retvals(0) - 1, retvals(1), retvals(2)
  END IF
 CASE 175'--deletesave
  IF retvals(0) >= 1 AND retvals(0) <= 32 THEN
   erase_save_slot retvals(0) - 1
  END IF
 CASE 176'--run script by id
  rsr = runscript(retvals(0), nowscript + 1, 0, "indirect", plottrigger) 'possible to get ahold of triggers
  IF rsr = 1 THEN
   '--fill heap with return values
   FOR i = 1 TO scrat(nowscript - 1).curargc - 1  'flexible argument number! (note that argc has been saved here by runscript)
    setScriptArg i - 1, retvals(i)
   NEXT i
   'NOTE: scriptret is not set here when this command is successful. The return value of the called script will be returned.
  ELSE
   scripterr "run script by id failed loading " & retvals(0), 6
   scriptret = -1
  END IF
 CASE 180'--mapwidth([map])
  'map width did not originally have an argument
  IF curcmd->argc = 0 ORELSE retvals(0) = -1 ORELSE retvals(0) = gam.map.id THEN
   scriptret = mapsizetiles.x
  ELSE
   IF bound_arg(retvals(0), 0, gen(genMaxMap), "map number", , , 5) THEN
    DIM as TilemapInfo mapsize
    GetTilemapInfo maplumpname(retvals(0), "t"), mapsize
    scriptret = mapsize.wide
   END IF
  END IF
 CASE 181'--mapheight([map])
  'map height did not originally have an argument
  IF curcmd->argc = 0 ORELSE retvals(0) = -1 ORELSE retvals(0) = gam.map.id THEN
   scriptret = mapsizetiles.y
  ELSE
   IF bound_arg(retvals(0), 0, gen(genMaxMap), "map number", , , 5) THEN
    DIM as TilemapInfo mapsize
    GetTilemapInfo maplumpname(retvals(0), "t"), mapsize
    scriptret = mapsize.high
   END IF
  END IF
 CASE 187'--getmusicvolume
  scriptret = get_music_volume * 255
 CASE 188'--setmusicvolume
  set_music_volume bound(retvals(0), 0, 255) / 255
 CASE 189, 307'--get formation song
  fh = FREEFILE
  IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxFormation) THEN
   OPEN tmpdir & "for.tmp" FOR BINARY AS #fh
   scriptret = readshort(fh, retvals(0) * 80 + 67)
   IF id = 307 THEN scriptret -= 1
   CLOSE #fh
  END IF
 CASE 190'--set formation song
  'set formation song never worked, so don't bother with backwards compatibility
  fh = FREEFILE
  IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxFormation) AND retvals(1) >= -2 AND retvals(1) <= gen(genMaxSong) THEN
   OPEN tmpdir & "for.tmp" FOR BINARY AS #fh
   WriteShort fh, retvals(0) * 80 + 67, retvals(1) + 1
   CLOSE #fh
  ELSE
   scriptret = -1
  END IF
 CASE 191'--hero frame
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   scriptret = wtog(retvals(0)) \ 2
  END IF
 CASE 195'--load sound (BACKWARDS COMPATABILITY HACK )
  'This opcode is not exposed in plotscr.hsd and should not be used in any new scripts
  IF retvals(0) >= 0 AND retvals(0) <= 7 THEN
   backcompat_sound_slot_mode = -1
   backcompat_sound_slots(retvals(0)) = retvals(1) + 1
  END IF
 CASE 196'--free sound (BACKWARDS COMPATABILITY HACK)
  'This opcode is not exposed in plotscr.hsd and should not be used in any new scripts
  IF retvals(0) >= 0 AND retvals(0) <= 7 THEN
   backcompat_sound_slots(retvals(0)) = 0
  END IF
 CASE 197'--play sound
  sfxid = backcompat_sound_id(retvals(0))
  IF sfxid >= 0 AND sfxid <= gen(genMaxSFX) THEN
   if retvals(2) then stopsfx sfxid
   playsfx sfxid, retvals(1)
   scriptret = -1
  END IF
 CASE 198'--pause sound
  IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxSFX) THEN
   pausesfx retvals(0)
   scriptret = -1
  END IF
 CASE 199'--stop sound
  IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxSFX) THEN
   stopsfx retvals(0)
   scriptret = -1
  END IF
 CASE 200'--system hour (time$ is always hh:mm:ss)
  scriptret = str2int(MID$(TIME$, 1, 2))
 CASE 201'--system minute
  scriptret = str2int(MID$(TIME$, 4, 2))
 CASE 202'--system second
  scriptret = str2int(MID$(TIME$, 7, 2))
 CASE 203'--current song
  scriptret = presentsong
 CASE 204'--get hero name(str,her)
  IF valid_plotstr(retvals(0)) AND valid_hero_party(retvals(1)) THEN
   plotstr(retvals(0)).s = names(retvals(1))
   scriptret = 1
  ELSE
   scriptret = 0
  END IF
 CASE 205'--set hero name
  IF valid_plotstr(retvals(0)) AND valid_hero_party(retvals(1)) THEN
   names(retvals(1)) = plotstr(retvals(0)).s
   scriptret = 1
  ELSE
   scriptret = 0
  END IF
 CASE 206'--get item name(str,itm)
  scriptret = 0
  IF valid_plotstr(retvals(0)) THEN
   IF valid_item(retvals(1)) THEN
    plotstr(retvals(0)).s = readitemname(retvals(1))
    scriptret = 1
   END IF
  END IF
 CASE 207'--get map name(str,map)
   IF valid_plotstr(retvals(0)) = NO OR retvals(1) < 0 OR retvals(1) > gen(genMaxMap) THEN
   scriptret = 0
  ELSE
   plotstr(retvals(0)).s = getmapname$(retvals(1))
   scriptret = 1
  END IF
 CASE 208'--get attack name(str,atk)
  'WARNING: backcompat only. new games should prefer read attack name
  IF valid_plotstr(retvals(0)) = NO OR retvals(1) < 0 OR retvals(1) > gen(genMaxAttack) THEN
   scriptret = 0
  ELSE
   plotstr(retvals(0)).s = readattackname$(retvals(1) + 1)
   scriptret = 1
  END IF
 CASE 209'--get global string(str,glo)
  'This command is basically unusable without a table of constants, it has almost certainly never been used.
  'Maybe someday it will be replaced - we can't add 'setglobalstring' unless the length is encoded in the offset constant.
  IF valid_plotstr(retvals(0)) = NO OR retvals(1) < 0 OR retvals(1) > 303 THEN
   scriptret = 0
  ELSE
   plotstr(retvals(0)).s = readglobalstring$(retvals(1), "", 255)
   scriptret = 1
  END IF
 CASE 211'--clear string
  IF valid_plotstr(retvals(0)) THEN plotstr(retvals(0)).s = ""
 CASE 212'--append ascii
  IF valid_plotstr(retvals(0)) THEN
   IF retvals(1) >= 0 AND retvals(1) <= 255 THEN
    plotstr(retvals(0)).s = plotstr(retvals(0)).s + CHR$(retvals(1))
    scriptret = LEN(plotstr(retvals(0)).s)
   END IF
  END IF
 CASE 213'--append number
  IF valid_plotstr(retvals(0)) THEN
   plotstr(retvals(0)).s = plotstr(retvals(0)).s & retvals(1)
   scriptret = LEN(plotstr(retvals(0)).s)
  END IF
 CASE 214'--copy string
  IF valid_plotstr(retvals(0)) AND valid_plotstr(retvals(1)) THEN
   plotstr(retvals(0)).s = plotstr(retvals(1)).s
  END IF
 CASE 215'--concatenate strings
  IF valid_plotstr(retvals(0)) AND valid_plotstr(retvals(1)) THEN
   plotstr(retvals(0)).s = plotstr(retvals(0)).s + plotstr(retvals(1)).s
   scriptret = LEN(plotstr(retvals(0)).s)
  END IF
 CASE 216'--string length
  IF valid_plotstr(retvals(0)) THEN
   scriptret = LEN(plotstr(retvals(0)).s)
  END IF
 CASE 217'--delete char
  IF valid_plotstr(retvals(0)) THEN
   IF retvals(1) >= 1 AND retvals(1) <= LEN(plotstr(retvals(0)).s) THEN
    temp2$ = LEFT$(plotstr(retvals(0)).s, retvals(1) - 1)
    temp3$ = MID$(plotstr(retvals(0)).s, retvals(1) + 1)
    plotstr(retvals(0)).s = temp2$ + temp3$
    temp3$ = ""
    temp2$ = ""
   END IF
  END IF
 CASE 218'--replace char
  IF valid_plotstr(retvals(0)) AND retvals(2) >= 0 AND retvals(2) <= 255 THEN
   IF retvals(1) >= 1 AND retvals(1) <= LEN(plotstr(retvals(0)).s) THEN
    MID$(plotstr(retvals(0)).s, retvals(1), 1) = CHR$(retvals(2))
   END IF
  END IF
 CASE 219'--ascii from string
  IF valid_plotstr(retvals(0)) AND retvals(1) >= 1 AND retvals(1) <= LEN(plotstr(retvals(0)).s) THEN
   scriptret = plotstr(retvals(0)).s[retvals(1)-1]'you can index strings a la C
  END IF
 CASE 220'--position string
  IF valid_plotstr(retvals(0)) THEN
   plotstr(retvals(0)).X = retvals(1)
   plotstr(retvals(0)).Y = retvals(2)
  END IF
 CASE 221'--set string bit
  IF valid_plotstr(retvals(0)) AND retvals(1) >= 0 AND retvals(1) <= 15 THEN
   if retvals(2) then
    plotstr(retvals(0)).bits = plotstr(retvals(0)).bits or 2 ^ retvals(1)
   else
    plotstr(retvals(0)).bits = plotstr(retvals(0)).bits and not 2 ^ retvals(1)
   end if
  END IF
 CASE 222'--get string bit
  IF valid_plotstr(retvals(0)) AND retvals(1) >= 0 AND retvals(1) <= 15 THEN
   'scriptret = readbit(plotstrBits(), retvals(0), retvals(1))
   scriptret = plotstr(retvals(0)).bits AND 2 ^ retvals(1)
   IF scriptret THEN scriptret = 1
  END IF
 CASE 223'--string color
  IF valid_plotstr(retvals(0)) THEN
   plotstr(retvals(0)).Col = bound(retvals(1), 0, 255)
   plotstr(retvals(0)).BGCol = bound(retvals(2), 0, 255)
  END IF
 CASE 224'--string X
  IF valid_plotstr(retvals(0)) THEN
   scriptret = plotstr(retvals(0)).X
  END IF
 CASE 225'--string Y
  IF valid_plotstr(retvals(0)) THEN
   scriptret = plotstr(retvals(0)).Y
  END IF
 CASE 226'--system day (date$ is always mm-dd-yyyy)
  scriptret = str2int(MID$(DATE$, 4, 2))
 CASE 227'--system month
  scriptret = str2int(MID$(DATE$, 1, 2))
 CASE 228'--system year
  scriptret = str2int(MID$(DATE$, 7, 4))
 CASE 229'--string compare
  IF valid_plotstr(retvals(0)) AND valid_plotstr(retvals(1)) THEN
   scriptret = (plotstr(retvals(0)).s = plotstr(retvals(1)).s)
  END IF
 CASE 230'--read enemy data
  'Boy, was this command a bad idea!
  '106 was the largest used offset until very recently, so we'll limit it there to
  'prevent further damage
  'Note: elemental/enemytype bits no longer exist (should still be able to read them
  'from old games, though)
  IF in_bound(retvals(0), 0, gen(genMaxEnemy)) AND in_bound(retvals(1), 0, 106) THEN
   scriptret = ReadShort(tmpdir & "dt1.tmp", retvals(0) * getbinsize(binDT1) + retvals(1) * 2 + 1)
  END IF
 CASE 231'--write enemy data
  'Boy, was this command a bad idea!
  '106 was the largest used offset until very recently, so we'll limit it there to
  'prevent further damage
  'Note: writing elemental/enemytype bits no longer works
  IF in_bound(retvals(0), 0, gen(genMaxEnemy)) AND in_bound(retvals(1), 0, 106) THEN
   WriteShort(tmpdir & "dt1.tmp", retvals(0) * getbinsize(binDT1) + retvals(1) * 2 + 1, retvals(2))
  END IF
 CASE 232'--trace
  IF valid_plotstr(retvals(0)) THEN
   debug "TRACE: " + plotstr(retvals(0)).s
  END IF
 CASE 233'--get song name
  IF valid_plotstr(retvals(0)) AND retvals(1) >= 0 THEN
   plotstr(retvals(0)).s = getsongname$(retvals(1))
  END IF
 CASE 235'--key is pressed
  SELECT CASE retvals(0)
  CASE 1 TO 127 'keyboard
   IF script_keyval(retvals(0)) THEN scriptret = 1 ELSE scriptret = 0
  CASE 128 TO 147 'joystick
   dim b as integer, xaxis as integer, yaxis as integer '0 >= x and y, >= 100
   IF readjoy(bound(retvals(1), 0, 7), b, xaxis, yaxis) THEN
    IF retvals(0) >= 128 AND retvals(0) <= 143 THEN
     scriptret = (b SHR (retvals(0) - 128)) AND 1
    ELSEIF retvals(0) = 144 THEN 'x left
     'debug STR$(xaxis)
     scriptret = abs(xaxis <= -50) 'true = -1...
    ELSEIF retvals(0) = 145 THEN 'x right
     scriptret = abs(xaxis >= 50)
    ELSEIF retvals(0) = 146 THEN 'y up
     scriptret = abs(yaxis <= -50)
    ELSEIF retvals(0) = 147 THEN 'y down
     scriptret = abs(yaxis >= 50)
    END IF
   ELSE
    scriptret = 0
   END IF
  CASE ELSE
   scriptret = 0
  END SELECT
 CASE 236'--sound is playing
  sfxid = backcompat_sound_id(retvals(0))
  IF sfxid >= 0 AND sfxid <= gen(genMaxSFX) THEN
   scriptret = sfxisplaying(sfxid)
  END IF
 CASE 237'--sound slots (BACKWARDS COMPATABILITY HACK)
  'This opcode is not exposed in plotscr.hsd and should not be used in any new scripts
  IF backcompat_sound_slot_mode THEN
    scriptret = 8
  END IF
 CASE 238'--search string
  IF valid_plotstr(retvals(0)) AND valid_plotstr(retvals(1)) THEN
    WITH plotstr(retvals(0))
     scriptret = instr(bound(retvals(2), 1, LEN(.s)), .s, plotstr(retvals(1)).s)
    END WITH
  ELSE
   scriptret = 0
  END IF
 CASE 239'--trim string
  IF valid_plotstr(retvals(0)) THEN
   IF retvals(1) = -1 THEN
    plotstr(retvals(0)).s = trim$(plotstr(retvals(0)).s)
   ELSE
    IF retvals(1) <= LEN(plotstr(retvals(0)).s) AND retvals(2) >= 1 THEN
     retvals(1) = large(retvals(1),1)
     'retvals(2) = bound(retvals(2),1,LEN(plotstr(retvals(0)).s))
     plotstr(retvals(0)).s = MID$(plotstr(retvals(0)).s,retvals(1),retvals(2))
    ELSE
     plotstr(retvals(0)).s = ""
    END IF
   END IF
  END IF
 CASE 240'-- string from textbox
  IF valid_plotstr(retvals(0)) THEN
   DIM box AS TextBox
   retvals(1) = bound(retvals(1),0,gen(genMaxTextbox))
   retvals(2) = bound(retvals(2),0,7)
   LoadTextBox box, retvals(1)
   plotstr(retvals(0)).s = box.text(retvals(2))
   IF NOT retvals(3) THEN embedtext plotstr(retvals(0)).s
   plotstr(retvals(0)).s = trim$(plotstr(retvals(0)).s)
  END IF
 CASE 241'-- expand string(id)
  IF valid_plotstr(retvals(0)) THEN
   embedtext plotstr(retvals(0)).s
  END IF
 CASE 242'-- joystick button
  retvals(0) = bound(retvals(0)-1,0,15)
  retvals(1) = bound(retvals(1),0,7)
  DIM b as integer
  IF readjoy(retvals(1),b,0,0) THEN
   scriptret = (b SHR retvals(0)) AND 1
  ELSE
   scriptret = 0
  END IF
 CASE 243'-- joystick axis
  retvals(0) = bound(retvals(0),0,1)
  retvals(2) = bound(retvals(2),0,7)
  DIM as integer xaxis, yaxis
  IF readjoy(retvals(2), 0, xaxis, yaxis) THEN
   IF retvals(0) = 0 THEN  'x axis
    'debug "x " & xaxis
    scriptret = int((xaxis / 100) * retvals(1)) 'normally, xaxis * 100
   ELSEIF retvals(0) = 1 THEN  'y axis
    'debug "y " & yaxis
    scriptret = int((yaxis / 100) * retvals(1)) 'normally, yaxis * 100
   END IF
  ELSE
   'debug "joystick failed"
   scriptret = 0
  END IF
 CASE 244'--wait for scancode
  GOSUB setwaitstate
 CASE 249'--party money
  scriptret = gold
 CASE 250'--set money
  IF retvals(0) >= 0 THEN gold = retvals(0)
 CASE 251'--set string from table
  IF bound_arg(retvals(0), 0, UBOUND(plotstr), "string ID", !"$# = \"...\"") THEN
   WITH *scrat(nowscript).scr
    DIM stringp AS INTEGER PTR = .ptr + .strtable + retvals(1)
    IF .strtable + retvals(1) >= .size ORELSE .strtable + (stringp[0] + 3) \ 4 >= .size THEN
     scripterr "script corrupt: illegal string offset", 6
    ELSE
     plotstr(retvals(0)).s = read32bitstring(stringp)
    END IF
   END WITH
  END IF
 CASE 252'--append string from table
  IF bound_arg(retvals(0), 0, UBOUND(plotstr), "string ID", !"$# + \"...\"") THEN
   WITH *scrat(nowscript).scr
    DIM stringp AS INTEGER PTR = .ptr + .strtable + retvals(1)
    IF .strtable + retvals(1) >= .size ORELSE .strtable + (stringp[0] + 3) \ 4 >= .size THEN
     scripterr "script corrupt: illegal string offset", 6
    ELSE
     plotstr(retvals(0)).s += read32bitstring(stringp)
    END IF
   END WITH
  END IF
 CASE 256'--suspend map music
  setbit gen(), 44, suspendambientmusic, 1
 CASE 257'--resume map music
  setbit gen(), 44, suspendambientmusic, 0
 CASE 260'--settimer(id, count, speed, trigger, string, flags)
  IF bound_arg(retvals(0), 0, UBOUND(timers), "timer ID") THEN
    WITH timers(retvals(0))
      IF retvals(1) > -1 THEN .count = retvals(1): .ticks = 0
      IF retvals(2) > -1 THEN
        .speed = retvals(2)
      ELSEIF retvals(2) = -1 AND .speed = 0 THEN
        .speed = 18
      END IF
      IF retvals(3) <> -1 THEN .trigger = retvals(3)
      IF retvals(4) <> -1 THEN
       IF valid_plotstr(retvals(4)) THEN .st = retvals(4) + 1
      END IF
      IF .st > 0 THEN plotstr(.st - 1).s = seconds2str(.count)
      IF retvals(5) <> -1 THEN .flags = retvals(5)
      IF .speed < -1 THEN .speed *= -1: .speed -= 1
    END WITH
  END IF
 CASE 261'--stoptimer
  IF bound_arg(retvals(0), 0, UBOUND(timers), "timer ID") THEN
   timers(retvals(0)).speed = 0
  END IF
 CASE 262'--readtimer
  IF bound_arg(retvals(0), 0, UBOUND(timers), "timer ID") THEN
   scriptret = timers(retvals(0)).count
  END IF
 CASE 263'--getcolor
  IF retvals(0) >= 0 AND retvals(0) < 256 THEN
   scriptret = master(retvals(0)).col
  END IF
 CASE 264'--setcolor
  IF retvals(0) >= 0 AND retvals(0) < 256 THEN
   retvals(1) = retvals(1) OR &HFF000000 'just in case, set the alpha
   master(retvals(0)).col = retvals(1)
  END IF
 CASE 265'--rgb
  scriptret = RGB(bound(retvals(0),0,255), bound(retvals(1),0,255), bound(retvals(2),0,255))
 CASE 266'--extractcolor
  dim c as rgbcolor
  c.col = retvals(0)
  SELECT CASE retvals(1)
   CASE 0
    scriptret = c.r
   CASE 1
    scriptret = c.g
   CASE 2
    scriptret = c.b
  END SELECT
 CASE 268'--loadpalette
  IF retvals(0) >= 0 AND retvals(0) <= gen(genMaxMasterPal) THEN
   loadpalette master(), retvals(0)
   LoadUIColors uilook(), retvals(0)
  END IF
 CASE 273'--milliseconds
  scriptret = fmod((TIMER * 1000) + 2147483648.0, 4294967296.0) - 2147483648.0
 CASE 308'--add enemy to formation (formation, enemy id, x, y, slot = -1)
  scriptret = -1
  IF valid_formation(retvals(0)) AND retvals(1) >= 0 AND retvals(1) <= gen(genMaxEnemy) THEN
   loadrecord buffer(), tmpdir & "for.tmp", 40, retvals(0)
   temp = -1
   FOR i = 0 TO 7
    IF buffer(i * 4) = 0 THEN temp = i: EXIT FOR
   NEXT
   IF retvals(4) >= 0 AND retvals(4) <= 7 THEN
    IF buffer(retvals(4) * 4) = 0 THEN temp = retvals(4)
   END IF
   IF temp >= 0 THEN
    szindex = ReadShort(tmpdir & "dt1.tmp", retvals(1) * getbinsize(binDT1) + 111) 'picture size
    IF szindex = 0 THEN size = 34
    IF szindex = 1 THEN size = 50
    IF szindex = 2 THEN size = 80
    buffer(temp * 4) = retvals(1) + 1
    buffer(temp * 4 + 1) = large( (small(retvals(2), 230) - size \ 2) , 0)  'approximately the 0 - 250 limit of the formation editor
    buffer(temp * 4 + 2) = large( (small(retvals(3), 199) - size) , 0)
   END IF
   storerecord buffer(), tmpdir & "for.tmp", 40, retvals(0)
   scriptret = temp
  END IF
 CASE 309'--find enemy in formation (formation, enemy id, number)
  IF valid_formation(retvals(0)) THEN
   loadrecord buffer(), tmpdir & "for.tmp", 40, retvals(0)
   temp = 0
   scriptret = -1
   FOR i = 0 TO 7
    IF buffer(i * 4) > 0 AND (retvals(1) = buffer(i * 4) - 1 OR retvals(1) = -1) THEN
     IF retvals(2) = temp THEN scriptret = i: EXIT FOR
     temp += 1
    END IF
   NEXT
   IF retvals(2) = -1 THEN scriptret = temp
  END IF
 CASE 310'--delete enemy from formation (formation, slot)
  IF valid_formation_slot(retvals(0), retvals(1)) THEN
   WriteShort tmpdir & "for.tmp", retvals(0) * 80 + retvals(1) * 8 + 1, 0
  END IF
 CASE 311'--formation slot enemy (formation, slot)
  scriptret = -1
  IF valid_formation_slot(retvals(0), retvals(1)) THEN
   scriptret = ReadShort(tmpdir & "for.tmp", retvals(0) * 80 + retvals(1) * 8 + 1) - 1
  END IF
 CASE 312, 313'--formation slot x (formation, slot), formation slot y (formation, slot)
  IF valid_formation_slot(retvals(0), retvals(1)) THEN
   temp = ReadShort(tmpdir & "for.tmp", retvals(0) * 80 + retvals(1) * 8 + 1) 'enemy id + 1
   scriptret = ReadShort(tmpdir & "for.tmp", retvals(0) * 80 + retvals(1) * 8 + (id - 311) * 2 + 1) 'x or y
   'now find the position of the bottom center of the enemy sprite
   IF temp THEN
    temp = ReadShort(tmpdir & "dt1.tmp", (temp - 1) * getbinsize(binDT1) + 111) 'picture size
    IF temp = 0 THEN size = 34
    IF temp = 1 THEN size = 50
    IF temp = 2 THEN size = 80
    IF id = 312 THEN scriptret += size \ 2 ELSE scriptret += size
   END IF
  END IF
 CASE 314'--set formation background (formation, background, animation frames, animation ticks)
  IF valid_formation(retvals(0)) AND retvals(1) >= 0 AND retvals(1) <= gen(genNumBackdrops) - 1 THEN 
   loadrecord buffer(), tmpdir & "for.tmp", 40, retvals(0)
   buffer(32) = retvals(1)
   buffer(34) = bound(retvals(2) - 1, 0, 49)
   buffer(35) = bound(retvals(3), 0, 1000)
   storerecord buffer(), tmpdir & "for.tmp", 40, retvals(0)
  END IF
 CASE 315'--get formation background (formation)
  IF valid_formation(retvals(0)) THEN
   scriptret = ReadShort(tmpdir & "for.tmp", retvals(0) * 80 + retvals(1) * 8 + 32 + 1)
  END IF
 CASE 316'--last formation
  scriptret = lastformation
 CASE 317'--random formation (formation set)
  IF retvals(0) >= 1 AND retvals(0) <= 255 THEN
   scriptret = random_formation(retvals(0) - 1)
  END IF
 CASE 318'--formation set frequency (formation set)
  IF retvals(0) >= 1 AND retvals(0) <= 255 THEN
   scriptret = ReadShort(game + ".efs", (retvals(0) - 1) * 50 + 1)
  END IF
 CASE 319'--formation probability (formation set, formation)
  IF retvals(0) >= 1 AND retvals(0) <= 255 THEN
   loadrecord buffer(), game + ".efs", 25, retvals(0) - 1
   temp = 0
   scriptret = 0
   FOR i = 1 TO 20
    IF buffer(i) = retvals(1) + 1 THEN scriptret += 1
    IF buffer(i) > 0 THEN temp += 1
   NEXT
   'probability in percentage points
   IF temp > 0 THEN scriptret = (scriptret * 100) / temp
  END IF
 CASE 321'--get hero speed (hero)
  IF retvals(0) >= 0 AND retvals(0) <= 3 THEN
   scriptret = herospeed(retvals(0))
  END IF
 CASE 322'--load hero sprite
  scriptret = load_sprite_plotslice(0, retvals(0), retvals(1))
 CASE 323'--free sprite
  IF valid_plotslice(retvals(0), 2) THEN
   IF plotslices(retvals(0))->SliceType = slSprite THEN
    DeleteSlice @plotslices(retvals(0))
   ELSE
    scripterr "free sprite: slice " & retvals(0) & " is a " & SliceTypeName(plotslices(retvals(0))), 5
   END IF
  END IF
 CASE 324 '--put slice  (previously place sprite)
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    .x = retvals(1)
    .y = retvals(2)
   END WITH
  END IF
 CASE 326 '--set sprite palette
  IF valid_plotslice(retvals(0)) THEN
   ChangeSpriteSlice plotslices(retvals(0)), , ,retvals(1)
  END IF
 CASE 327 '--replace hero sprite
  replace_sprite_plotslice retvals(0), 0, retvals(1), retvals(2)
 CASE 328 '--set sprite frame
  IF valid_plotslice(retvals(0)) THEN
   ChangeSpriteSlice plotslices(retvals(0)), , , , retvals(1)
  END IF
 CASE 329'--load walkabout sprite
  scriptret = load_sprite_plotslice(4, retvals(0), retvals(1))
 CASE 330 '--replace walkabout sprite
  replace_sprite_plotslice retvals(0), 4, retvals(1), retvals(2)
 CASE 331'--load weapon sprite
  scriptret = load_sprite_plotslice(5, retvals(0), retvals(1))
 CASE 332 '--replace weapon sprite
  replace_sprite_plotslice retvals(0), 5, retvals(1), retvals(2)
 CASE 333'--load small enemy sprite
  scriptret = load_sprite_plotslice(1, retvals(0), retvals(1))
 CASE 334 '--replace small enemy sprite
  replace_sprite_plotslice retvals(0), 1, retvals(1), retvals(2)
 CASE 335'--load medium enemy sprite
  scriptret = load_sprite_plotslice(2, retvals(0), retvals(1))
 CASE 336 '--replace medium enemy sprite
  replace_sprite_plotslice retvals(0), 2, retvals(1), retvals(2)
 CASE 337'--load large enemy sprite
  scriptret = load_sprite_plotslice(3, retvals(0), retvals(1))
 CASE 338 '--replace large enemy sprite
  replace_sprite_plotslice retvals(0), 3, retvals(1), retvals(2)
 CASE 339'--load attack sprite
  scriptret = load_sprite_plotslice(6, retvals(0), retvals(1))
 CASE 340 '--replace attack sprite
  replace_sprite_plotslice retvals(0), 6, retvals(1), retvals(2)
 CASE 341'--load border sprite
  scriptret = load_sprite_plotslice(7, retvals(0), retvals(1))
 CASE 342 '--replace border sprite
  replace_sprite_plotslice retvals(0), 7, retvals(1), retvals(2)
 CASE 343'--load portrait sprite
  scriptret = load_sprite_plotslice(8, retvals(0), retvals(1))
 CASE 344 '--replace portrait sprite
  replace_sprite_plotslice retvals(0), 8, retvals(1), retvals(2)
 CASE 345 '--clone sprite
  IF valid_plotsprite(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = NewSliceOfType(slSprite, SliceTable.scriptsprite)
   sl->Clone(plotslices(retvals(0)), sl)
   scriptret = create_plotslice_handle(sl)
  END IF
 CASE 346 '--get sprite frame
  IF valid_plotsprite(retvals(0)) THEN
   DIM dat AS SpriteSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->frame
  END IF
 CASE 347 '--sprite frame count
  IF valid_plotsprite(retvals(0)) THEN
   DIM dat AS SpriteSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   WITH *dat
    scriptret = sprite_sizes(.spritetype).frames
   END WITH
  END IF
 CASE 348 '--slice x
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->X
  END IF
 CASE 349 '--slice y
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->Y
  END IF
 CASE 350 '--set slice x
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->X = retvals(1)
  END IF
 CASE 351 '--set slice y
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->Y = retvals(1)
  END IF
 CASE 352 '--slice width
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->Width
  END IF
 CASE 353 '--slice height
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->Height
  END IF
 CASE 354 '--set horiz align
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->AlignHoriz = retvals(1)
  END IF
 CASE 355 '--set vert align
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->AlignVert = retvals(1)
  END IF
 CASE 356 '--set horiz anchor
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->AnchorHoriz = retvals(1)
  END IF
 CASE 357 '--set vert anchor
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->AnchorVert = retvals(1)
  END IF
 CASE 358 '--number from string
  IF valid_plotstr(retvals(0)) THEN
   scriptret = str2int(plotstr(retvals(0)).s, retvals(1))
  END IF
 CASE 359 '--slice is sprite
  IF valid_plotslice(retvals(0)) THEN
   scriptret = 0
   IF plotslices(retvals(0))->SliceType = slSprite THEN scriptret = 1
  END IF
 CASE 360 '--sprite layer
  scriptret = find_plotslice_handle(SliceTable.ScriptSprite)
 CASE 361 '--free slice
  IF valid_plotslice(retvals(0), 2) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))
   IF sl->SliceType = slRoot OR sl->SliceType = slSpecial THEN
    scripterr "free slice: cannot free " & SliceTypeName(sl) & " slice " & retvals(0), 5
   ELSE
    DeleteSlice @plotslices(retvals(0))
   END IF
  END IF
 CASE 362 '--first child
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))
   scriptret = find_plotslice_handle(sl->FirstChild)
  END IF
 CASE 363 '--next sibling
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))
   scriptret = find_plotslice_handle(sl->NextSibling)
  END IF
 CASE 364 '--create container
  DIM sl AS Slice Ptr
  sl = NewSliceOfType(slContainer, SliceTable.scriptsprite)
  sl->Width = retvals(0)
  sl->Height = retvals(1)
  scriptret = create_plotslice_handle(sl)
 CASE 365 '--set parent
  IF valid_plotslice(retvals(0)) AND valid_plotslice(retvals(1)) THEN
   SetSliceParent plotslices(retvals(0)), plotslices(retvals(1))
  END IF
 CASE 366 '--check parentage
  IF valid_plotslice(retvals(0)) AND valid_plotslice(retvals(1)) THEN
   IF verifySliceLineage(plotslices(retvals(0)), plotslices(retvals(1))) THEN
    scriptret = 1
   END IF
  END IF
 CASE 367 '--slice screen x
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))
   RefreshSliceScreenPos sl
   scriptret = sl->ScreenX + SliceXAnchor(sl)
  END IF
 CASE 368 '--slice screen y
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))
   RefreshSliceScreenPos sl
   scriptret = sl->ScreenY + SliceYAnchor(sl)
  END IF
 CASE 369 '--slice is container
  IF valid_plotslice(retvals(0)) THEN
   scriptret = 0
   IF plotslices(retvals(0))->SliceType = slContainer THEN scriptret = 1
  END IF
 CASE 370 '--create rect
  DIM sl AS Slice Ptr
  sl = NewSliceOfType(slRectangle, SliceTable.scriptsprite)
  sl->Width = retvals(0)
  sl->Height = retvals(1)
  IF bound_arg(retvals(2), -1, 14, "style") THEN
   ChangeRectangleSlice sl, retvals(2)
  END IF
  scriptret = create_plotslice_handle(sl)
 CASE 371 '--slice is rect
  IF valid_plotslice(retvals(0)) THEN
   scriptret = 0
   IF plotslices(retvals(0))->SliceType = slRectangle THEN scriptret = 1
  END IF
 CASE 372 '--set slice width
  IF valid_resizeable_slice(retvals(0)) THEN
   plotslices(retvals(0))->Width = retvals(1)
  END IF
 CASE 373 '--set slice height
  IF valid_resizeable_slice(retvals(0)) THEN
   plotslices(retvals(0))->Height = retvals(1)
  END IF
 CASE 374 '--get rect style
  IF valid_plotrect(retvals(0)) THEN
   DIM dat AS RectangleSliceData ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->style
  END IF
 CASE 375 '--set rect style
  IF bound_arg(retvals(1), -1, 14, "style") THEN
   change_rect_plotslice retvals(0), retvals(1)
  END IF
 CASE 376 '--get rect fgcol
  IF valid_plotrect(retvals(0)) THEN
   DIM dat AS RectangleSliceData ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->fgcol
  END IF
 CASE 377 '--set rect fgcol
  IF bound_arg(retvals(1), 0, 255, "fgcol") THEN
   change_rect_plotslice retvals(0), , ,retvals(1)
  END IF
 CASE 378 '--get rect bgcol
  IF valid_plotrect(retvals(0)) THEN
   DIM dat AS RectangleSliceData ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->bgcol
  END IF
 CASE 379 '--set rect bgcol
  IF bound_arg(retvals(1), 0, 255, "bgcol") THEN
   change_rect_plotslice retvals(0), ,retvals(1)
  END IF
 CASE 380 '--get rect border
  IF valid_plotrect(retvals(0)) THEN
   DIM dat AS RectangleSliceData ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->border
  END IF
 CASE 381 '--set rect border
  IF bound_arg(retvals(1), -2, 14, "border") THEN
   change_rect_plotslice retvals(0), , , ,retvals(1)
  END IF
 CASE 382 '--get rect trans
  IF valid_plotrect(retvals(0)) THEN
   DIM dat AS RectangleSliceData ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->translucent
  END IF
 CASE 383 '--set rect trans
  IF bound_arg(retvals(1), 0, 2, "transparency") THEN
   change_rect_plotslice retvals(0), , , , ,retvals(1)
  END IF
 CASE 384 '--slice collide point
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))
   RefreshSliceScreenPos sl
   scriptret = ABS(SliceCollidePoint(sl, retvals(1), retvals(2)))
  END IF
 CASE 385 '--slice collide
  IF valid_plotslice(retvals(0)) THEN
   IF valid_plotslice(retvals(1)) THEN
    RefreshSliceScreenPos plotslices(retvals(0))
    RefreshSliceScreenPos plotslices(retvals(1))
    scriptret = ABS(SliceCollide(plotslices(retvals(0)), plotslices(retvals(1))))
   END IF
  END IF
 CASE 386 '--slice contains
  IF valid_plotslice(retvals(0)) THEN
   IF valid_plotslice(retvals(1)) THEN
    scriptret = ABS(SliceContains(plotslices(retvals(0)), plotslices(retvals(1))))
   END IF
  END IF
 CASE 387 '--clamp slice
  IF valid_plotslice(retvals(0)) THEN
   IF valid_plotslice(retvals(1)) THEN
    SliceClamp plotslices(retvals(1)), plotslices(retvals(0))
   END IF
  END IF
 CASE 388 '--horiz flip sprite
  IF valid_plotsprite(retvals(0)) THEN
   ChangeSpriteSlice plotslices(retvals(0)), , , , , retvals(1)
  END IF
 CASE 389 '--vert flip sprite
  IF valid_plotsprite(retvals(0)) THEN
   ChangeSpriteSlice plotslices(retvals(0)), , , , , , retvals(1)
  END IF
 CASE 390 '--sprite is horiz flipped
  IF valid_plotsprite(retvals(0)) THEN
   DIM dat AS SpriteSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   IF dat->flipHoriz THEN scriptret = 1 ELSE scriptret = 0
  END IF
 CASE 391 '--sprite is vert flipped
  IF valid_plotsprite(retvals(0)) THEN
   DIM dat AS SpriteSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   IF dat->flipVert THEN scriptret = 1 ELSE scriptret = 0
  END IF
 CASE 392 '--set top padding
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->PaddingTop = retvals(1)
  END IF
 CASE 393 '--get top padding
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->PaddingTop
  END IF
 CASE 394 '--set left padding
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->PaddingLeft = retvals(1)
  END IF
 CASE 395 '--get left padding
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->PaddingLeft
  END IF
 CASE 396 '--set bottom padding
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->PaddingBottom = retvals(1)
  END IF
 CASE 397 '--get bottom padding
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->PaddingBottom
  END IF
 CASE 398 '--set right padding
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->PaddingRight = retvals(1)
  END IF
 CASE 399 '--get right padding
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->PaddingRight
  END IF
 CASE 400 '--fill parent
  IF valid_resizeable_slice(retvals(0), YES) THEN
   plotslices(retvals(0))->Fill = (retvals(1) <> 0)
  END IF
 CASE 401 '--is filling parent
  IF valid_plotslice(retvals(0)) THEN
   IF plotslices(retvals(0))->Fill THEN scriptret = 1 ELSE scriptret = 0
  END IF
 CASE 402 '--slice to front
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))->Parent
   SetSliceParent plotslices(retvals(0)), sl
  END IF
 CASE 403 '--slice to back
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr
   sl = plotslices(retvals(0))
   IF sl->Parent = 0 THEN
    scripterr "slice to back: invalid on root slice", 5
   ELSE
    InsertSliceBefore sl->Parent->FirstChild, sl
   END IF
  END IF
 CASE 404 '--last child
  IF valid_plotslice(retvals(0)) THEN
   scriptret = find_plotslice_handle(LastChild(plotslices(retvals(0))))
  END IF
 CASE 405 '--y sort children
  IF valid_plotslice(retvals(0)) THEN
   YSortChildSlices plotslices(retvals(0))
  END IF
 CASE 406 '--set sort order
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->Sorter = retvals(1)
  END IF
 CASE 407 '--sort children
  IF valid_plotslice(retvals(0)) THEN
   CustomSortChildSlices plotslices(retvals(0)), retvals(1)
  END IF
 CASE 408 '--previous sibling
  IF valid_plotslice(retvals(0)) THEN
   scriptret = find_plotslice_handle(plotslices(retvals(0))->PrevSibling)
  END IF 
 CASE 409 '--get sort order
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->Sorter
  END IF
 CASE 410 '--get slice extra (handle, extra)
  IF valid_plotslice(retvals(0)) THEN
   IF retvals(1) >= 0 AND retvals(1) <= 2 THEN
    scriptret = plotslices(retvals(0))->Extra(retvals(1))
   END IF
  END IF
 CASE 411 '--set slice extra (handle, extra, val)
  IF valid_plotslice(retvals(0)) THEN
   IF retvals(1) >= 0 AND retvals(1) <= 2 THEN
    plotslices(retvals(0))->Extra(retvals(1)) = retvals(2)
   END IF
  END IF
 CASE 412 '--get sprite type
  IF valid_plotslice(retvals(0)) THEN
   IF plotslices(retvals(0))->SliceType = slSprite THEN
    DIM dat AS SpriteSliceData Ptr = plotslices(retvals(0))->SliceData
    scriptret = dat->spritetype
   ELSE
    scriptret = -1
   END IF
  END IF
 CASE 413 '--get sprite set number
  IF valid_plotsprite(retvals(0)) THEN
   DIM dat AS SpriteSliceData Ptr = plotslices(retvals(0))->SliceData
   scriptret = dat->record
  END IF 
 CASE 414 '--get sprite palette
  IF valid_plotsprite(retvals(0)) THEN
   DIM dat AS SpriteSliceData Ptr = plotslices(retvals(0))->SliceData
   IF dat->paletted = NO THEN
    scripterr "get sprite palette: this sprite is unpaletted", 2
   ELSE
    scriptret = dat->pal
   END IF
  END IF 
 CASE 415 '--suspend timers
  FOR i = 0 TO ubound(timers)
   timers(i).pause = YES
  NEXT i
 CASE 416 '--resume timers
  FOR i = 0 TO ubound(timers)
   timers(i).pause = NO
  NEXT i
 CASE 325, 417 '--set sprite visible, set slice visible
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    .Visible = (retvals(1) <> 0)
   END WITH
  END IF
 CASE 418 '--get slice visible
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    scriptret = ABS(.Visible)
   END WITH
  END IF
 CASE 419 '--slice edge x
  IF valid_plotslice(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, 2, "edge") THEN
    DIM sl AS Slice Ptr
    sl = plotslices(retvals(0))
    scriptret = sl->X - SliceXAnchor(sl) + SliceEdgeX(sl, retvals(1))
   END IF
  END IF
 CASE 420 '--slice edge y
  IF valid_plotslice(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, 2, "edge") THEN
    DIM sl AS Slice Ptr
    sl = plotslices(retvals(0))
    scriptret = sl->Y - SliceYAnchor(sl) + SliceEdgeY(sl, retvals(1))
   END IF
  END IF
 CASE 421 '--create text
  DIM sl AS Slice Ptr
  sl = NewSliceOfType(slText, SliceTable.scriptsprite)
  scriptret = create_plotslice_handle(sl)
 CASE 422 '--set slice text
  IF valid_plottextslice(retvals(0)) THEN
   IF valid_plotstr(retvals(1)) THEN
    ChangeTextSlice plotslices(retvals(0)), plotstr(retvals(1)).s
   END IF
  END IF
 CASE 423 '--get text color
  IF valid_plottextslice(retvals(0)) THEN
   DIM dat AS TextSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->col
  END IF
 CASE 424 '--set text color
  IF valid_plottextslice(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, 255, "color") THEN
    ChangeTextSlice plotslices(retvals(0)), , retvals(1)
   END IF
  END IF
 CASE 425 '--get wrap
  IF valid_plottextslice(retvals(0)) THEN
   DIM dat AS TextSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = ABS(dat->wrap)
  END IF
 CASE 426 '--set wrap
  IF valid_plottextslice(retvals(0)) THEN
   ChangeTextSlice plotslices(retvals(0)), , , ,(retvals(1)<>0)
  END IF
 CASE 427 '--slice is text
  IF valid_plotslice(retvals(0)) THEN
   scriptret = 0
   IF plotslices(retvals(0))->SliceType = slText THEN scriptret = 1
  END IF
 CASE 428 '--get text bg
  IF valid_plottextslice(retvals(0)) THEN
   DIM dat AS TextSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->bgcol
  END IF
 CASE 429 '--set text bg
  IF valid_plottextslice(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, 255, "color") THEN
    ChangeTextSlice plotslices(retvals(0)), , , , , retvals(1)
   END IF
  END IF
 CASE 430 '--get outline
  IF valid_plottextslice(retvals(0)) THEN
   DIM dat AS TextSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = ABS(dat->outline)
  END IF
 CASE 431 '--set outline
  IF valid_plottextslice(retvals(0)) THEN
   ChangeTextSlice plotslices(retvals(0)), , ,(retvals(1)<>0)
  END IF
 CASE 433'--slice at pixel(parent, x, y, num, descend)
  IF valid_plotslice(retvals(0)) THEN
   RefreshSliceScreenPos plotslices(retvals(0))
   IF retvals(3) <= -1 THEN
    temp = -1
    FindSliceAtPoint(plotslices(retvals(0)), retvals(1), retvals(2), temp, retvals(4))
    scriptret = -temp - 1
   ELSE
    scriptret = find_plotslice_handle(FindSliceAtPoint(plotslices(retvals(0)), retvals(1), retvals(2), retvals(3), retvals(4)))
   END IF
  END IF
 CASE 434'--find colliding slice(parent, handle, num, descend)
  IF valid_plotslice(retvals(0)) AND valid_plotslice(retvals(1)) THEN
   RefreshSliceScreenPos plotslices(retvals(0))
   RefreshSliceScreenPos plotslices(retvals(1))
   IF retvals(2) <= -1 THEN
    temp = -1
    FindSliceCollision(plotslices(retvals(0)), plotslices(retvals(1)), temp, retvals(3))
    scriptret = -temp - 1
   ELSE
    scriptret = find_plotslice_handle(FindSliceCollision(plotslices(retvals(0)), plotslices(retvals(1)), retvals(2), retvals(3)))
   END IF
  END IF
 CASE 435'--parent slice
  IF valid_plotslice(retvals(0)) THEN
   scriptret = find_plotslice_handle(plotslices(retvals(0))->Parent)
  END IF
 CASE 436'--child count
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->NumChildren
  END IF
 CASE 437'--lookup slice
  IF retvals(1) = 0 THEN
   '--search the whole slice tree
   scriptret = find_plotslice_handle(LookupSlice(retvals(0)))
  ELSE
   '--search starting from a certain slice
   IF valid_plotslice(retvals(1)) THEN
    scriptret = find_plotslice_handle(LookupSlice(retvals(0), plotslices(retvals(1))))
   END IF
  END IF
 CASE 439'--slice is valid
  scriptret = 0
  IF retvals(0) >= LBOUND(plotslices) AND retvals(0) <= UBOUND(plotslices) THEN
   IF plotslices(retvals(0)) <> 0 THEN
    scriptret = 1
    IF ENABLE_SLICE_DEBUG THEN
     IF SliceDebugCheck(plotslices(retvals(0))) = NO THEN scriptret = 0
    END IF
   END IF
  END IF
 CASE 440'--item in slot
  IF valid_item_slot(retvals(0)) THEN
   IF inventory(retvals(0)).used = NO THEN
    scriptret = -1
   ELSE
    scriptret = inventory(retvals(0)).id
   END IF
  END IF
 CASE 441'--set item in slot
  IF valid_item_slot(retvals(0)) THEN
   IF retvals(1) = -1 THEN
    WITH inventory(retvals(0))
     .used = NO
     .id = 0
     .num = 0
    END WITH
   ELSEIF valid_item(retvals(1)) THEN
    WITH inventory(retvals(0))
     .id = retvals(1)
     IF .num < 1 THEN .num = 1
     .used = YES
    END WITH
   END IF
   update_inventory_caption retvals(0)
   evalitemtag
  END IF
 CASE 442'--item count in slot
  IF valid_item_slot(retvals(0)) THEN
   IF inventory(retvals(0)).used = NO THEN
    scriptret = 0
   ELSE
    scriptret = inventory(retvals(0)).num
   END IF
  END IF
 CASE 443'--set item count in slot
  IF valid_item_slot(retvals(0)) THEN
   IF retvals(1) = 0 THEN
    WITH inventory(retvals(0))
     .used = NO
     .id = 0
     .num = 0
    END WITH
   ELSEIF bound_arg(retvals(1), 1, 99, "count") THEN
    WITH inventory(retvals(0))
     IF .used = NO THEN
      scripterr "set item count in slot: can't set count for empty slot " & retvals(0), 4
     ELSE
      .num = retvals(1)
     END IF
    END WITH
   END IF
   update_inventory_caption retvals(0)
   evalitemtag
  END IF
 CASE 444 '--put sprite, place sprite
  IF valid_plotsprite(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    .X = retvals(1)
    .Y = retvals(2)
   END WITH
  END IF
 CASE 446 '--move slice below
  IF valid_plotslice(retvals(0)) ANDALSO valid_plotslice(retvals(1)) THEN
   IF retvals(0) = retvals(1) THEN
    scripterr "moveslicebelow: tried to move a slice below itself", 2
   ELSE
    InsertSliceBefore plotslices(retvals(1)), plotslices(retvals(0))
   END IF
  END IF
 CASE 447 '--move slice above
  IF valid_plotslice(retvals(0)) ANDALSO valid_plotslice(retvals(1)) THEN
   IF retvals(0) = retvals(1) THEN
    scripterr "movesliceabove: tried to move a slice above itself", 2
   ELSE
    DIM sl AS Slice Ptr = plotslices(retvals(1))
    IF sl->NextSibling THEN
     InsertSliceBefore sl->NextSibling, plotslices(retvals(0))
    ELSE
     IF sl->Parent = NULL THEN
      scripterr "movesliceabove: Root shouldn't have siblings", 5
     ELSE
      'sets as last child
      SetSliceParent plotslices(retvals(0)), sl->Parent
     END IF
    END IF
   END IF
  END IF
 CASE 448 '--slice child
  IF valid_plotslice(retvals(0)) THEN
   DIM sl AS Slice Ptr = plotslices(retvals(0))->FirstChild
   FOR i = 0 TO retvals(1)
    IF sl = NULL THEN EXIT FOR
    IF i = retvals(1) THEN scriptret = find_plotslice_handle(sl)
    sl = sl->NextSibling
   NEXT
  END IF
 CASE 451 '--set slice clipping
  IF valid_plotslice(retvals(0)) THEN
   plotslices(retvals(0))->Clip = (retvals(1) <> 0)
  END IF
 CASE 452 '--get slice clipping
  IF valid_plotslice(retvals(0)) THEN
   scriptret = ABS(plotslices(retvals(0))->Clip <> 0)
  END IF
 CASE 453 '--create grid
  DIM sl AS Slice Ptr
  sl = NewSliceOfType(slGrid, SliceTable.scriptsprite)
  scriptret = create_plotslice_handle(sl)
  sl->Width = retvals(0)
  sl->Height = retvals(1)
  ChangeGridSlice sl, retvals(2), retvals(3)
 CASE 454 '--slice is grid
  IF valid_plotslice(retvals(0)) THEN
   scriptret = 0
   IF plotslices(retvals(0))->SliceType = slGrid THEN scriptret = 1
  END IF
 CASE 455 '--set grid columns
  IF valid_plotgridslice(retvals(0)) THEN
   ChangeGridSlice plotslices(retvals(0)), , retvals(1)
  END IF
 CASE 456 '--get grid columns
  IF valid_plotgridslice(retvals(0)) THEN
   DIM dat AS GridSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->cols
  END IF
 CASE 457 '--set grid rows
  IF valid_plotgridslice(retvals(0)) THEN
   ChangeGridSlice plotslices(retvals(0)), retvals(1)
  END IF
 CASE 458 '--get grid rows
  IF valid_plotgridslice(retvals(0)) THEN
   DIM dat AS GridSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = dat->rows
  END IF
 CASE 459 '--show grid
  IF valid_plotgridslice(retvals(0)) THEN
   DIM dat AS GridSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   dat->show = (retvals(1) <> 0)
  END IF
 CASE 460 '--grid is shown
  IF valid_plotgridslice(retvals(0)) THEN
   DIM dat AS GridSliceData Ptr
   dat = plotslices(retvals(0))->SliceData
   scriptret = ABS(dat->show <> 0)
  END IF
 CASE 461 '--load slice collection
  DIM sl AS Slice Ptr
  IF isfile(workingdir & SLASH & "slicetree_0_" & retvals(0) & ".reld") THEN
   sl = NewSliceOfType(slContainer, SliceTable.scriptsprite)
   SliceLoadFromFile sl, workingdir & SLASH & "slicetree_0_" & retvals(0) & ".reld"
   scriptret = create_plotslice_handle(sl)
  ELSE
   scripterr commandname(curcmd->value) & ": invalid slice collection id " & retvals(0), 5
   scriptret = 0
  END IF
 CASE 462 '--set slice edge x
  IF valid_plotslice(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, 2, "edge") THEN
    DIM sl AS Slice Ptr
    sl = plotslices(retvals(0))
    sl->X = retvals(2) + SliceXAnchor(sl) - SliceEdgeX(sl, retvals(1))
   END IF
  END IF
 CASE 463 '--slice edge y
  IF valid_plotslice(retvals(0)) THEN
   IF bound_arg(retvals(1), 0, 2, "edge") THEN
    DIM sl AS Slice Ptr
    sl = plotslices(retvals(0))
    sl->Y = retvals(2) + SliceYAnchor(sl) - SliceEdgeY(sl, retvals(1))
   END IF
  END IF
 CASE 464 '--get slice lookup
  IF valid_plotslice(retvals(0)) THEN
   scriptret = plotslices(retvals(0))->Lookup
  END IF
 CASE 465 '--set slice lookup
  IF valid_plotslice(retvals(0)) THEN
   IF retvals(1) < 0 THEN
    scripterr commandname(curcmd->value) & ": negative lookup codes are reserved, they can't be set."
   ELSEIF plotslices(retvals(0))->Lookup < 0 THEN
    scripterr commandname(curcmd->value) & ": can't modify the lookup code of a special slice."
   ELSE
    plotslices(retvals(0))->Lookup = retvals(1)
   END IF
  END IF
 CASE 466 '--trace value internal (string, value, ...)
  DIM result AS string
  FOR i = 0 TO curcmd->argc - 1
   IF i MOD 2 = 0 THEN
    IF i <> 0 THEN result &= ", "
    WITH *scrat(nowscript).scr
     DIM stringp AS INTEGER PTR = .ptr + .strtable + retvals(i)
     IF .strtable + retvals(i) >= .size ORELSE .strtable + (stringp[0] + 3) \ 4 >= .size THEN
      scripterr "script corrupt: illegal string offset", 6
     ELSE
      result &= read32bitstring(stringp) & " = "
     END IF
    END WITH
   ELSE
    result &= retvals(i)
   END IF
  NEXT
  debug "TRACE: " & result
 CASE 467 '--map cure
  IF bound_arg(retvals(0), 1, gen(genMaxAttack)+1, "attack ID") THEN
   IF valid_hero_party(retvals(1)) THEN
    IF valid_hero_party(retvals(2), -1) THEN
     scriptret = ABS(outside_battle_cure(retvals(0) - 1, retvals(1), retvals(2), 0))
    END IF
   END IF
  END IF
 CASE 468 '--read attack name
  scriptret = 0
  IF valid_plotstr(retvals(0)) AND bound_arg(retvals(1), 1, gen(genMaxAttack)+1, "attack ID") THEN
   plotstr(retvals(0)).s = readattackname(retvals(1) - 1)
   scriptret = 1
  END IF
 CASE 469'--spells learned
  found = 0
  IF valid_hero_party(retvals(0)) THEN
   FOR i = retvals(0) * 96 TO retvals(0) * 96 + 95
    IF readbit(learnmask(), 0, i) THEN
     IF retvals(1) = found THEN
      scriptret = spell(retvals(0), (i \ 24) MOD 4, i MOD 24)
      EXIT FOR
     END IF
     found = found + 1
    END IF
   NEXT
   IF retvals(1) = -1 THEN scriptret = found  'getcount
  END IF
 CASE 470'--allocate timers
  IF bound_arg(retvals(0), 0, 100000, "number of timers", , , 5) THEN
   REDIM PRESERVE timers(large(0, retvals(0) - 1))
   IF retvals(0) = 0 THEN
    'Unfortunately, have to have at least one timer. Deactivate/blank it, in case the player
    'wants "allocate timers(0)" to kill all timers.
    REDIM timers(0)
   END IF
  END IF
/'  Disabled until an alternative ("new timer") is decided upon
 CASE 471'--unused timer
  scriptret = -1
  FOR i = 0 TO UBOUND(timers)
   IF timers(i).speed <= 0 THEN
    scriptret = i
    WITH timers(scriptret)
     .speed = 0
     .ticks = 0
     .count = 0
     .st = 0
     .trigger = 0
     .flags = 0
    END WITH
    EXIT FOR
   END IF
  NEXT
  IF scriptret = -1 THEN
   scriptret = UBOUND(timers) + 1
   IF scriptret < 100000 THEN
    REDIM PRESERVE timers(scriptret)
   END IF
  END IF
'/
 CASE 480'--read zone (id, x, y)
  IF valid_zone(retvals(0)) THEN
   IF valid_tile_pos(retvals(1), retvals(2)) THEN
    scriptret = IIF(CheckZoneAtTile(zmap, retvals(0), retvals(1), retvals(2)), 1, 0)
   END IF
  END IF
 CASE 481'--write zone (id, x, y, value)
  IF valid_zone(retvals(0)) THEN
   IF valid_tile_pos(retvals(1), retvals(2)) THEN
    IF retvals(3) THEN
     IF SetZoneTile(zmap, retvals(0), retvals(1), retvals(2)) = 0 THEN
      scriptret = 1
      'Is error level 2 the best for commands which fail? Do we need another?
      scripterr "writezone: the maximum number of zones, 15, already overlap at " & retvals(1) & "," & retvals(2) & "; attempt to add another failed", 2
     END IF
    ELSE
     UnsetZoneTile(zmap, retvals(0), retvals(1), retvals(2))
    END IF
   END IF
  END IF
 CASE 482'--zone at spot (x, y, count)
  IF valid_tile_pos(retvals(0), retvals(1)) THEN
   DIM zoneshere() as integer
   GetZonesAtTile(zmap, zoneshere(), retvals(0), retvals(1))
   IF retvals(2) = -1 THEN  'getcount
    scriptret = UBOUND(zoneshere)
   ELSEIF retvals(2) < -1 THEN
    scripterr "zone at spot: bad 'count' argument " & retvals(2), 5
   ELSE
    IF retvals(2) <= UBOUND(zoneshere) THEN scriptret = zoneshere(retvals(2))
   END IF
  END IF
 CASE 483'--zone number of tiles (id)
  IF valid_zone(retvals(0)) THEN
   scriptret = GetZoneInfo(zmap, retvals(0))->numtiles
  END IF
/' Unimplemented
 CASE 484'--draw with zone (id, layer)
  IF valid_zone(retvals(0)) THEN
  END IF
 CASE 485'--zone next tile x (id, x, y)
  IF valid_zone(retvals(0)) THEN
  END IF
 CASE 486'--zone next tile y (id, x, y)
  IF valid_zone(retvals(0)) THEN
  END IF
'/
 CASE 487'--get zone name (string, id)
  IF valid_plotstr(retvals(0)) AND valid_zone(retvals(1)) THEN
   plotstr(retvals(0)).s = GetZoneInfo(zmap, retvals(1))->name
  END IF
 CASE 488'--get zone extra (id, extra)
  IF valid_zone(retvals(0)) AND bound_arg(retvals(1), 0, 2, "extra data number", , , 5) THEN
   scriptret = GetZoneInfo(zmap, retvals(0))->extra(retvals(1))
  END IF
 CASE 489'--set zone extra (id, extra, value)
  IF valid_zone(retvals(0)) AND bound_arg(retvals(1), 0, 2, "extra data number", , , 5) THEN
   GetZoneInfo(zmap, retvals(0))->extra(retvals(1)) = retvals(2)
  END IF
 CASE 493'--load backdrop sprite (record)
  scriptret = load_sprite_plotslice(sprTypeMXS, retvals(0))
 CASE 494 '--replace backdrop sprite (handle, record)
  replace_sprite_plotslice retvals(0), sprTypeMXS, retvals(1)
 CASE 495 '--get sprite trans (handle)
  IF valid_plotsprite(retvals(0)) THEN
   DIM dat AS SpriteSliceData Ptr = plotslices(retvals(0))->SliceData
   scriptret = IIF(dat->trans, 1, 0)
  END IF 
 CASE 496 '--set sprite trans (handle, bool)
  IF valid_plotsprite(retvals(0)) THEN
   ChangeSpriteSlice plotslices(retvals(0)), , , , , , , retvals(1)
  END IF 
 CASE 500 '--set slice velocity x (handle, pixels per tick, ticks)
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    .Velocity.X = retvals(1)
    .VelTicks.X = retvals(2)
   END WITH
  END IF
 CASE 501 '--set slice velocity y (handle, pixels per tick)
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    .Velocity.Y = retvals(1)
    .VelTicks.Y = retvals(2)
   END WITH
  END IF
 CASE 502 '--get slice velocity x (handle)
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    scriptret = .Velocity.X
   END WITH
  END IF
 CASE 503 '--get slice velocity y (handle)
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    scriptret = .Velocity.Y
   END WITH
  END IF
 CASE 504 '--set slice velocity (handle, x pixels per tick, y pixels per tick, ticks)
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    .Velocity.X = retvals(1)
    .Velocity.Y = retvals(2)
    .VelTicks.X = retvals(3)
    .VelTicks.Y = retvals(3)
   END WITH
  END IF
 CASE 505 '--stop slice (handle)
  IF valid_plotslice(retvals(0)) THEN
   WITH *plotslices(retvals(0))
    .Velocity.X = 0
    .Velocity.Y = 0
    .VelTicks.X = 0
    .VelTicks.Y = 0
   END WITH
  END IF
  
END SELECT

EXIT SUB

setwaitstate:
scrat(nowscript).waitarg = retvals(0)
scrat(nowscript).state = stwait
RETRACE

END SUB

SUB scriptnpc (id)

'contains npc related scripting commands

SELECT CASE AS CONST id

 CASE 26'--set NPC frame
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN npc(npcref).frame = bound(retvals(1), 0, 1) * 2
 CASE 39'--camera follows NPC
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   gen(cameramode) = npccam
   gen(cameraArg) = npcref
  END IF
 CASE 45'--NPC x
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN scriptret = npc(npcref).x \ 20
 CASE 46'--NPC y
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN scriptret = npc(npcref).y \ 20
 CASE 52'--walk NPC
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   SELECT CASE retvals(1)
    CASE 0'--north
     npc(npcref).dir = 0
     npc(npcref).ygo = retvals(2) * 20
    CASE 1'--east
     npc(npcref).dir = 1
     npc(npcref).xgo = retvals(2) * -20
    CASE 2'--south
     npc(npcref).dir = 2
     npc(npcref).ygo = retvals(2) * -20
    CASE 3'--west
     npc(npcref).dir = 3
     npc(npcref).xgo = retvals(2) * 20
   END SELECT
  END IF
 CASE 54'--set NPC direction
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN npc(npcref).dir = ABS(retvals(1)) MOD 4
 CASE 88'--set NPC position
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   cropposition retvals(1), retvals(2), 1
   npc(npcref).x = retvals(1) * 20
   npc(npcref).y = retvals(2) * 20
  END IF
 CASE 101'--NPC direction
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN scriptret = npc(npcref).dir
 CASE 117, 177'--NPC is walking
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   IF npc(npcref).xgo = 0 AND npc(npcref).ygo = 0 THEN
    scriptret = 0
   ELSE
    scriptret = 1
   END IF
   IF id = 117 THEN scriptret = scriptret XOR 1 'Backcompat hack
  END IF
 CASE 120'--NPC reference
  scriptret = 0
  IF retvals(0) >= 0 AND retvals(0) <= UBOUND(npcs) THEN
   found = 0
   FOR i = 0 TO 299
    IF npc(i).id - 1 = retvals(0) THEN
     IF found = retvals(1) THEN
      scriptret = (i + 1) * -1
      EXIT FOR
     END IF
     found = found + 1
    END IF
   NEXT i
  END IF
 CASE 121'--NPC at spot
  scriptret = 0
  found = 0
  FOR i = 0 TO 299
   IF npc(i).id > 0 THEN
    IF npc(i).x \ 20 = retvals(0) THEN 
     IF npc(i).y \ 20 = retvals(1) THEN
      IF found = retvals(2) THEN
       scriptret = (i + 1) * -1
       EXIT FOR
      END IF
      found = found + 1
     END IF
    END IF
   END IF
  NEXT i
  IF retvals(2) = -1 THEN scriptret = found
 CASE 122'--get NPC ID
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   scriptret = ABS(npc(npcref).id) - 1
  ELSE
   scriptret = -1
  END IF
 CASE 123'--NPC copy count
  scriptret = 0
  IF retvals(0) >= 0 AND retvals(0) <= UBOUND(npcs) THEN
   FOR i = 0 TO 299
    IF npc(i).id - 1 = retvals(0) THEN
     scriptret = scriptret + 1
    END IF
   NEXT i
  END IF
 CASE 124'--change NPC ID
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 AND retvals(1) >= 0 AND retvals(1) <= UBOUND(npcs) THEN npc(npcref).id = retvals(1) + 1
 CASE 125'--create NPC
  scriptret = 0
  IF retvals(0) >= 0 AND retvals(0) <= UBOUND(npcs) THEN
   FOR i = 299 TO 0 STEP -1
    IF npc(i).id = 0 THEN EXIT FOR
   NEXT
   'for backwards compatibility with games that max out the number of NPCs, try to overwrite tag-disabled NPCs
   'FIXME: delete this bit once we raise the NPC limit
   IF i = -1 THEN
    FOR i = 299 TO 0 STEP -1
     IF npc(i).id <= 0 THEN EXIT FOR
    NEXT
    'I don't want to raise a scripterr here, again because it probably happens in routine in games like SoJ
    DIM msgtemp as string = "create NPC: trying to create NPC id " & retvals(0) & " at " & retvals(1)*20 & "," & retvals(2)*20
    IF i = -1 THEN 
     scripterr msgtemp & "; failed: too many NPCs exist", 4
    ELSE
     scripterr msgtemp & "; warning: had to overwrite tag-disabled NPC id " & ABS(npc(i).id)-1 & " at " & npc(i).x & "," & npc(i).y & ": too many NPCs exist", 4
    END IF
   END IF
   IF i > -1 THEN
    CleanNPCInst npc(i)
    npc(i).id = retvals(0) + 1
    cropposition retvals(1), retvals(2), 1
    npc(i).x = retvals(1) * 20
    npc(i).y = retvals(2) * 20
    npc(i).dir = ABS(retvals(3)) MOD 4
    scriptret = (i + 1) * -1
   END IF
  END IF
 CASE 126 '--destroy NPC
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN npc(npcref).id = 0
 CASE 165'--NPC at pixel
  scriptret = 0
  found = 0
  FOR i = 0 TO 299
   IF npc(i).id > 0 THEN 
    IF npc(i).x <= retvals(0) AND npc(i).x > (retvals(0) - 20) THEN 
     IF npc(i).y <= retvals(1) AND npc(i).y > (retvals(1) - 20) THEN
      IF found = retvals(2) THEN
       scriptret = (i + 1) * -1
       EXIT FOR
      END IF
      found = found + 1
     END IF
    END IF
   END IF
  NEXT i
  IF retvals(2) = -1 THEN scriptret = found
 CASE 182'--read NPC
  IF retvals(1) >= 0 AND retvals(1) <= 14 THEN
   IF retvals(0) >= 0 AND retvals(0) <= UBOUND(npcs) THEN
    scriptret = GetNPCD(npcs(retvals(0)), retvals(1))
   ELSE
    npcref = getnpcref(retvals(0), 0)
    IF npcref >= 0 THEN
     IF npc(npcref).id THEN scriptret = GetNPCD(npcs(ABS(npc(npcref).id) - 1), retvals(1))
    END IF
   END IF
  END IF
 CASE 192'--NPC frame
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN scriptret = npc(npcref).frame \ 2
 CASE 193'--NPC extra
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   IF retvals(1) >= 0 AND retvals(1) <= 2 THEN
    scriptret = npc(npcref).extra(retvals(1))
   END IF
  END IF
 CASE 194'--set NPC extra
  npcref = getnpcref(retvals(0), 0)
  IF npcref >= 0 THEN
   IF retvals(1) >= 0 AND retvals(1) <= 2 THEN
    npc(npcref).extra(retvals(1)) = retvals(2)
   END IF
  END IF
 CASE 472'--set NPC ignores walls (npc, value)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   npc(npcref).ignore_walls = (retvals(1) <> 0)
  END IF
 CASE 473'--get NPC ignores walls (npc)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   scriptret = iif(npc(npcref).ignore_walls, 1, 0)
  END IF
 CASE 474'--set NPC obstructs (npc, value)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   npc(npcref).not_obstruction = (retvals(1) = 0)
  END IF
 CASE 475'--get NPC obstructs (npc)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   scriptret = iif(npc(npcref).not_obstruction, 0, 1)
  END IF
 CASE 476'--set NPC usable (npc, value)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   npc(npcref).suspend_use = (retvals(1) = 0)
  END IF
 CASE 477'--get NPC usable (npc)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   scriptret = iif(npc(npcref).suspend_use, 0, 1)
  END IF
 CASE 478'--set NPC moves (npc, value)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   npc(npcref).suspend_ai = (retvals(1) = 0)
  END IF
 CASE 479'--get NPC moves (npc)
  npcref = get_valid_npc(retvals(0))
  IF npcref >= 0 THEN
   scriptret = iif(npc(npcref).suspend_ai, 0, 1)
  END IF

END SELECT

END SUB

SUB setdebugpan

gen(cameramode) = pancam
gen(cameraArg2) = 1
gen(cameraArg3) = 5

END SUB

SUB templockexplain
PRINT "Either " + exename + " is already running in the background, or it"
PRINT "terminated incorrectly last time it was run, and was unable to clean up"
PRINT "its temporary files. The operating system is denying access to the"
PRINT "files in " + workingdir
PRINT
PRINT "If this problem persists, manually delete playing.tmp"
PRINT
PRINT "Error code"; ERR
END SUB

SUB tweakpalette
FOR i = bound(retvals(3), 0, 255) TO bound(retvals(4), 0, 255)
 master(i).r = bound(master(i).r + retvals(0) * 4, 0, 255)
 master(i).g = bound(master(i).g + retvals(1) * 4, 0, 255)
 master(i).b = bound(master(i).b + retvals(2) * 4, 0, 255)
NEXT i
END SUB

FUNCTION vehiclestuff () as integer
STATIC aheadx, aheady

result = 0
IF vstate.mounting THEN '--scramble-----------------------
 '--part of the vehicle automount where heros scramble--
 IF npc(vstate.npc).xgo = 0 AND npc(vstate.npc).ygo = 0 THEN
  '--npc must stop before we mount
  vehscramble vstate.mounting, NO, npc(vstate.npc).x, npc(vstate.npc).y, result
 END IF
END IF'--scramble mount
IF vstate.rising THEN '--rise----------------------
 tmp = 0
 FOR i = 0 TO 3
  IF catz(i * 5) < vstate.dat.elevation THEN
   catz(i * 5) = catz(i * 5) + large(1, small(4, (vstate.dat.elevation - catz(i * 5) + 1) \ 2))
  ELSE
   tmp = tmp + 1
  END IF
 NEXT i
 IF tmp = 4 THEN
  vstate.rising = NO
 END IF
END IF
IF vstate.falling THEN '--fall-------------------
 tmp = 0
 FOR i = 0 TO 3
  IF catz(i * 5) > 0 THEN
   catz(i * 5) = catz(i * 5) - large(1, small(4, (vstate.dat.elevation - catz(i * 5) + 1) \ 2))
  ELSE
   tmp = tmp + 1
  END IF
 NEXT i
 IF tmp = 4 THEN
  FOR i = 0 TO 3
   catz(i * 5) = 0
  NEXT i
  vstate.falling = NO
  vstate.init_dismount = YES
 END IF
END IF
IF vstate.init_dismount THEN '--dismount---------------
 vstate.init_dismount = NO
 DIM disx AS INTEGER = catx(0) \ 20
 DIM disy AS INTEGER = caty(0) \ 20
 IF vstate.dat.dismount_ahead AND vstate.dat.pass_walls_while_dismounting THEN
  '--dismount-ahead is true, dismount-passwalls is true
  aheadxy disx, disy, catd(0), 1
  cropposition disx, disy, 1
 END IF
 IF vehpass(vstate.dat.dismount_to, readblock(pass, disx, disy), -1) THEN
  '--dismount point is landable
  FOR i = 0 TO 15
   catx(i) = catx(0)
   caty(i) = caty(0)
   catd(i) = catd(0)
   catz(i) = 0
  NEXT i
  IF vstate.dat.dismount_ahead = YES THEN
   vstate.ahead = YES
   aheadx = disx * 20
   aheady = disy * 20
  ELSE
   vstate.trigger_cleanup = YES
  END IF
 ELSE
  '--dismount point is unlandable
  IF vstate.dat.elevation > 0 THEN
   vstate.rising = YES '--riseagain
  END IF
 END IF
END IF
IF vstate.trigger_cleanup THEN '--clear
 IF vstate.dat.on_dismount < 0 THEN result = vstate.dat.on_dismount
 IF vstate.dat.on_dismount > 0 THEN result = 1 + vstate.dat.on_dismount
 IF vstate.dat.riding_tag > 1 THEN setbit tag(), 0, vstate.dat.riding_tag, 0
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
 herospeed(0) = vstate.old_speed
 IF herospeed(0) = 3 THEN herospeed(0) = 10
 npc(vstate.npc).xgo = 0
 npc(vstate.npc).ygo = 0
 '--clear vehicle
 reset_vehicle vstate
 FOR i = 0 TO 15   'Why is this duplicated from dismounting?
  catx(i) = catx(0)
  caty(i) = caty(0)
  catd(i) = catd(0)
  catz(i) = 0
 NEXT i
 gam.random_battle_countdown = range(100, 60)
END IF
IF vstate.ahead THEN '--ahead
 vehscramble vstate.ahead, YES, aheadx, aheady, result
END IF
IF vstate.active = YES AND vehicle_is_animating() = NO THEN
 IF txt.showing = NO AND readbit(gen(), 44, suspendplayer) = 0 THEN
  DIM button(1) AS INTEGER
  button(0) = vstate.dat.use_button
  button(1) = vstate.dat.menu_button
  FOR i = 0 TO 1
   IF carray(ccUse + i) > 1 AND xgo(0) = 0 AND ygo(0) = 0 THEN
    SELECT CASE button(i)
     CASE -2
      '-disabled
     CASE -1
      result = 1
     CASE 0
      '--dismount
      vehicle_graceful_dismount
     CASE IS > 0
      result = button(i) * -1
    END SELECT
   END IF
  NEXT i
 END IF
END IF'--normal

RETURN result

END FUNCTION

SUB vehicle_graceful_dismount ()
 xgo(0) = 0
 ygo(0) = 0
 IF vstate.dat.elevation > 0 THEN
  vstate.falling = YES
 ELSE
  vstate.init_dismount = YES
 END IF
END SUB

FUNCTION vehpass (n as integer, tile as integer, default as integer) as integer

'--true means passable
'--false means impassable

v = default

SELECT CASE n
 CASE 1
  v = (tile AND 16)
 CASE 2
  v = (tile AND 32)
 CASE 3
  v = ((tile AND 16) = 16) AND ((tile AND 32) = 32)
 CASE 4
  v = ((tile AND 16) = 16) OR ((tile AND 32) = 32)
 CASE 5
  v = NOT ((tile AND 16) = 16)
 CASE 6
  v = NOT ((tile AND 32) = 32)
 CASE 7
  v = NOT (((tile AND 16) = 16) OR ((tile AND 32) = 32))
 CASE 8
  v = -1
END SELECT

v = ABS(SGN(v)) * -1

vehpass = v

'tiles
'1   north
'2   east
'4   south
'8   west
'16  vehicle A
'32  vehicle B
'64  harm tile
'128 overhead

END FUNCTION

SUB vishero ()
FOR i = 0 TO UBOUND(herow)
 frame_unload @herow(i).sprite
 palette16_unload @herow(i).pal
NEXT
o = 0
FOR i = 0 TO 3
 IF hero(i) > 0 THEN
  herow(o).sprite = frame_load(4, gam.hero(i).pic)
  herow(o).pal = palette16_load(gam.hero(i).pal, 4, gam.hero(i).pic)
  o = o + 1
 END IF
NEXT i
evalherotag
END SUB

SUB wrapaheadxy (x, y, direction, distance, unitsize)
'alters X and Y ahead by distance in direction, wrapping if neccisary
'unitsize is 20 for pixels, 1 for tiles

aheadxy x, y, direction, distance

IF gmap(5) = 1 THEN
 wrapxy x, y, mapsizetiles.x * unitsize, mapsizetiles.y * unitsize
END IF

END SUB

SUB cropposition (BYREF x, BYREF y, unitsize)

IF gmap(5) = 1 THEN
 wrapxy x, y, mapsizetiles.x * unitsize, mapsizetiles.y * unitsize
ELSE
 x = bound(x, 0, (mapsizetiles.x - 1) * unitsize)
 y = bound(y, 0, (mapsizetiles.y - 1) * unitsize)
END IF

END SUB

FUNCTION wrappass (x as integer, y as integer, xgo as integer, ygo as integer, isveh as integer) as integer
' returns true if blocked by terrain
DIM pd(3)

wrappass = 0

tilex = x: tiley = y
p = readblock(pass, tilex, tiley)

FOR i = 0 TO 3
 tilex = x: tiley = y
 wrapaheadxy tilex, tiley, i, 1, 1
 IF tilex < 0 OR tilex >= pass.wide OR tiley < 0 OR tiley >= pass.high THEN
  pd(i) = 15
 ELSE
  pd(i) = readblock(pass, tilex, tiley)
 END IF
NEXT i

IF ygo > 0 AND movdivis(ygo) AND ((p AND 1) = 1 OR (pd(0) AND 4) = 4 OR (isveh ANDALSO vehpass(vstate.dat.blocked_by, pd(0), 0))) THEN ygo = 0: wrappass = 1
IF ygo < 0 AND movdivis(ygo) AND ((p AND 4) = 4 OR (pd(2) AND 1) = 1 OR (isveh ANDALSO vehpass(vstate.dat.blocked_by, pd(2), 0))) THEN ygo = 0: wrappass = 1
IF xgo > 0 AND movdivis(xgo) AND ((p AND 8) = 8 OR (pd(3) AND 2) = 2 OR (isveh ANDALSO vehpass(vstate.dat.blocked_by, pd(3), 0))) THEN xgo = 0: wrappass = 1
IF xgo < 0 AND movdivis(xgo) AND ((p AND 2) = 2 OR (pd(1) AND 8) = 8 OR (isveh ANDALSO vehpass(vstate.dat.blocked_by, pd(1), 0))) THEN xgo = 0: wrappass = 1

END FUNCTION

FUNCTION wrapzonetest (BYVAL zone as integer, BYVAL x as integer, BYVAL y as integer, BYVAL xgo as integer, BYVAL ygo as integer) as integer
 'x, y in pixels
 'Warning: always wraps! But that isn't a problem on non-wrapping maps.

 x -= xgo
 y -= ygo
 wrapxy (x, y, mapsizetiles.x * 20, mapsizetiles.y * 20)
 RETURN (CheckZoneAtTile(zmap, zone, x \ 20, y \ 20) = 0)
END FUNCTION

FUNCTION wrapcollision (xa as integer, ya as integer, xgoa as integer, ygoa as integer, xb as integer, yb as integer, xgob as integer, ygob as integer) as integer
 x1 = (xa - bound(xgoa, -20, 20)) \ 20
 x2 = (xb - bound(xgob, -20, 20)) \ 20
 y1 = (ya - bound(ygoa, -20, 20)) \ 20
 y2 = (yb - bound(ygob, -20, 20)) \ 20

 IF gmap(5) = 1 THEN
  wrapcollision = (x1 - x2) MOD mapsizetiles.x = 0 AND (y1 - y2) MOD mapsizetiles.y = 0
 ELSE
  wrapcollision = (x1 = x2) AND (y1 = y2)
 END IF

END FUNCTION

FUNCTION wraptouch (x1 as integer, y1 as integer, x2 as integer, y2 as integer, distance as integer) as integer
 'whether 2 walkabouts are within distance pixels horizontally + vertically
 wraptouch = 0
 IF gmap(5) = 1 THEN
  IF ABS((x1 - x2) MOD (mapsizetiles.x * 20 - distance)) <= distance AND ABS((y1 - y2) MOD (mapsizetiles.y * 20 - distance)) <= distance THEN wraptouch = 1
 ELSE
  IF ABS(x1 - x2) <= 20 AND ABS(y1 - y2) <= 20 THEN wraptouch = 1
 END IF
END FUNCTION

SUB wrappedsong (songnumber)

IF songnumber <> presentsong THEN
 playsongnum songnumber
 presentsong = songnumber
ELSE
 resumesong
END IF

END SUB

SUB stopsong
presentsong = -1
pausesong 'this is how you stop the music
END SUB

SUB wrapxy (x, y, wide, high)
'--wraps the given X and Y values within the bounds of width and height
x = ((x MOD wide) + wide) MOD wide  'negative modulo is the devil's creation and never helped me once
y = ((y MOD high) + high) MOD high
END SUB

FUNCTION backcompat_sound_id (id AS INTEGER) as integer
  IF backcompat_sound_slot_mode THEN
   'BACKWARDS COMPATABILITY HACK
   IF id >= 0 AND id <= 7 THEN
    RETURN backcompat_sound_slots(id) - 1
   END IF
  ELSE
   'Normal playsound mode
   RETURN id
  END IF
END FUNCTION

'======== FIXME: move this up as code gets cleaned up ===========
OPTION EXPLICIT

SUB vehscramble(BYREF mode_val AS INTEGER, BYVAL trigger_cleanup AS INTEGER, BYVAL targx AS INTEGER, BYVAL targy AS INTEGER, BYREF result AS INTEGER)
 DIM tmp AS INTEGER = 0
 DIM count AS INTEGER = herocount()
 DIM scramx AS INTEGER
 DIM scramy AS INTEGER
 FOR i AS INTEGER = 0 TO 3
  IF i >= count THEN
   tmp += 1
  ELSE
   scramx = catx(i * 5)
   scramy = caty(i * 5)
   IF ABS(scramx - targx) < large(herospeed(i), 4) THEN
    scramx = targx
    xgo(i) = 0
    ygo(i) = 0
   END IF
   IF ABS(scramy - targy) < large(herospeed(i), 4) THEN
    scramy = targy
    xgo(i) = 0
    ygo(i) = 0
   END IF
   IF ABS(targx - scramx) > 0 AND xgo(i) = 0 THEN
    xgo(i) = 20 * SGN(scramx - targx)
   END IF
   IF ABS(targy - scramy) > 0 AND ygo(i) = 0 THEN
    ygo(i) = 20 * SGN(scramy - targy)
   END IF
   IF gmap(5) = 1 THEN
    '--this is a wrapping map
    IF ABS(scramx - targx) > mapsizetiles.x * 20 / 2 THEN xgo(i) = xgo(i) * -1
    IF ABS(scramy - targy) > mapsizetiles.y * 20 / 2 THEN ygo(i) = ygo(i) * -1
   END IF
   IF scramx - targx = 0 AND scramy - targy = 0 THEN tmp = tmp + 1
   catx(i * 5) = scramx
   caty(i * 5) = scramy
  END IF
 NEXT i
 IF tmp = 4 THEN
  mode_val = NO
  IF vstate.dat.on_mount < 0 THEN result = vstate.dat.on_mount
  IF vstate.dat.on_mount > 0 THEN result = 1 + vstate.dat.on_mount
  herospeed(0) = vstate.dat.speed
  IF herospeed(0) = 3 THEN herospeed(0) = 10
  '--null out hero's movement
  FOR i AS INTEGER = 0 TO 3
   xgo(i) = 0
   ygo(i) = 0
  NEXT i
  IF trigger_cleanup THEN vstate.trigger_cleanup = YES '--clear
  IF vstate.dat.elevation > 0 THEN vstate.rising = YES
 END IF
END SUB

SUB loadsay (BYVAL box_id AS INTEGER)
DIM j AS INTEGER
DIM rsr AS INTEGER

DO '--This loop is where we find which box will be displayed right now
 gen(genTextboxBackdrop) = 0
 txt.choice_cursor = 0

 '--load data from the textbox lump
 LoadTextBox txt.box, box_id

 FOR j = 0 TO 7
  embedtext txt.box.text(j), 38
 NEXT j

 '-- evaluate "instead" conditionals
 IF istag(txt.box.instead_tag, 0) THEN
  '--do something else instead
  IF txt.box.instead < 0 THEN
   rsr = runscript(-txt.box.instead, nowscript + 1, -1, "instead", plottrigger)
   txt.sayer = -1
   EXIT SUB
  ELSE
   IF box_id <> txt.box.instead THEN
    box_id = txt.box.instead
    CONTINUE DO' Skip back to the top of the loop and get another box
   END IF
  END IF
 END IF

 EXIT DO'--We have the box we want to display, proceed
LOOP

'--Store box ID number for later reference
txt.id = box_id

'-- set tags indicating the text box has been seen.
IF istag(txt.box.settag_tag, 0) THEN
 IF ABS(txt.box.settag1) > 1 THEN setbit tag(), 0, ABS(txt.box.settag1), SGN(SGN(txt.box.settag1) + 1)
 IF ABS(txt.box.settag2) > 1 THEN setbit tag(), 0, ABS(txt.box.settag2), SGN(SGN(txt.box.settag2) + 1)
END IF

'--make a sound if the choicebox is enabled
IF txt.box.choice_enabled THEN MenuSound gen(genAcceptSFX)

'-- update backdrop if necessary
IF txt.box.backdrop > 0 THEN
 gen(genTextboxBackdrop) = txt.box.backdrop
 correctbackdrop
END IF

'-- change music if necessary
IF txt.box.music > 0 THEN
 txt.remember_music = presentsong
 wrappedsong txt.box.music - 1
END IF

'--play a sound effect
IF txt.box.sound_effect > 0 THEN
 playsfx txt.box.sound_effect - 1
END IF

'-- evaluate menu conditionals
IF istag(txt.box.menu_tag, 0) THEN
 add_menu txt.box.menu
END IF

'--Get the portrait
load_text_box_portrait txt.box, txt.portrait

txt.showing = YES
txt.fully_shown = NO
txt.show_lines = 0

'--Create a set of slices to display the text box
init_text_box_slices txt

END SUB

SUB load_text_box_portrait (BYREF box AS TextBox, BYREF gfx AS GraphicPair)
 'WARNING: There is another version of this in customsubs.bas
 'If you update this here, make sure to update that one too!
 DIM img_id AS INTEGER = -1
 DIM pal_id AS INTEGER = -1
 DIM hero_id AS INTEGER = -1
 DIM her AS HeroDef
 WITH gfx
  IF .sprite THEN frame_unload @.sprite
  IF .pal    THEN palette16_unload @.pal
  SELECT CASE box.portrait_type
   CASE 1' Fixed ID number
    img_id = box.portrait_id
    pal_id = box.portrait_pal
   CASE 2' Hero by caterpillar
    hero_id = herobyrank(box.portrait_id)
   CASE 3' Hero by party slot
    IF box.portrait_id >= 0 AND box.portrait_id <= UBOUND(hero) THEN
     hero_id = hero(box.portrait_id) - 1
    END IF
  END SELECT
  IF hero_id >= 0 THEN
   loadherodata @her, hero_id
   img_id = her.portrait
   pal_id = her.portrait_pal
  END IF
  IF img_id >= 0 THEN
   .sprite = frame_load(8, img_id)
   .pal    = palette16_load(pal_id, 8, img_id)
  END IF
 END WITH
END SUB

FUNCTION valid_spriteslice_dat(BYVAL sl AS Slice Ptr) AS INTEGER
 IF sl = 0 THEN scripterr "null slice ptr in valid_spriteslice_dat", 7 : RETURN NO
 DIM dat AS SpriteSliceData Ptr = sl->SliceData
 IF dat = 0 THEN
  scripterr SliceTypeName(sl) & " handle " & retvals(0) & " has null dat pointer", 7
  RETURN NO
 END IF
 RETURN YES
END FUNCTION

FUNCTION valid_plotslice(byval handle as integer, errlev as integer=5) as integer
 IF handle < LBOUND(plotslices) OR handle > UBOUND(plotslices) THEN
  scripterr commandname(curcmd->value) & ": invalid slice handle " & handle, errlev
  RETURN NO
 END IF
 IF plotslices(handle) = 0 THEN
  scripterr commandname(curcmd->value) & ": slice handle " & handle & " has already been deleted", errlev
  RETURN NO
 END IF
 IF ENABLE_SLICE_DEBUG THEN
  IF SliceDebugCheck(plotslices(handle)) = NO THEN
   scripterr commandname(curcmd->value) & ": slice " & handle & " " & plotslices(handle) & " is not in the slice debug table!", 7
   RETURN NO
  END IF
 END IF
 RETURN YES
END FUNCTION

FUNCTION valid_plotsprite(byval handle as integer) as integer
 IF valid_plotslice(handle) THEN
  IF plotslices(handle)->SliceType = slSprite THEN
   IF valid_spriteslice_dat(plotslices(handle)) THEN
    RETURN YES
   END IF
  ELSE
   scripterr commandname(curcmd->value) & ": slice handle " & handle & " is not a sprite", 5
  END IF
 END IF
 RETURN NO
END FUNCTION

FUNCTION valid_plotrect(byval handle as integer) as integer
 IF valid_plotslice(handle) THEN
  IF plotslices(handle)->SliceType = slRectangle THEN
   RETURN YES
  ELSE
   scripterr commandname(curcmd->value) & ": slice handle " & handle & " is not a rect", 5
  END IF
 END IF
 RETURN NO
END FUNCTION

FUNCTION valid_plottextslice(byval handle as integer) as integer
 IF valid_plotslice(handle) THEN
  IF plotslices(handle)->SliceType = slText THEN
   IF plotslices(handle)->SliceData = 0 THEN
    scripterr commandname(curcmd->value) & ": text slice handle " & handle & " has null data", 7
    RETURN NO
   END IF
   RETURN YES
  ELSE
   scripterr commandname(curcmd->value) & ": slice handle " & handle & " is not text", 5
  END IF
 END IF
 RETURN NO
END FUNCTION

FUNCTION valid_plotgridslice(byval handle as integer) as integer
 IF valid_plotslice(handle) THEN
  IF plotslices(handle)->SliceType = slGrid THEN
   RETURN YES
  ELSE
   scripterr commandname(curcmd->value) & ": slice handle " & handle & " is not a grid", 5
  END IF
 END IF
 RETURN NO
END FUNCTION

FUNCTION valid_resizeable_slice(byval handle as integer, byval ignore_fill as integer=NO) as integer
 IF valid_plotslice(handle) THEN
  DIM sl AS Slice Ptr
  sl = plotslices(handle)
  IF sl->SliceType = slRectangle OR sl->SliceType = slContainer OR sl->SliceType = slGrid THEN
   IF sl->Fill = NO OR ignore_fill THEN
    RETURN YES
   ELSE
    scripterr commandname(curcmd->value) & ": slice handle " & handle & " cannot be resized while filling parent", 5
   END IF
  ELSE
   IF sl->SliceType = slText THEN
    DIM dat AS TextSliceData ptr
    dat = sl->SliceData
    IF dat = 0 THEN scripterr "sanity check fail, text slice " & handle & " has null data", 7 : RETURN NO
    IF dat->wrap = YES THEN
     RETURN YES
    ELSE
     scripterr commandname(curcmd->value) & ": text slice handle " & handle & " cannot be resized unless wrap is enabled", 5
    END IF
   ELSE
    scripterr commandname(curcmd->value) & ": slice handle " & handle & " is not resizeable", 5
   END IF
  END IF
 END IF
 RETURN NO
END FUNCTION

FUNCTION create_plotslice_handle(byval sl as Slice Ptr) AS INTEGER
 IF sl = 0 THEN scripterr "create_plotslice_handle null ptr", 7 : RETURN 0
 IF sl->TableSlot <> 0 THEN
  'this should not happen! Call find_plotslice_handle instead.
  scripterr "Error: " & SliceTypeName(sl) & " " & sl & " references plotslices(" & sl->TableSlot & ") which has " & plotslices(sl->TableSlot), 7
  RETURN 0
 END IF
 DIM i as integer
 'First search for an empty slice handle slot (which sucks because it means they get re-used)
 FOR i = LBOUND(plotslices) to UBOUND(plotslices)
  IF plotslices(i) = 0 THEN
   'Store the slice pointer in the handle slot
   plotslices(i) = sl
   'Store the handle slot in the slice
   sl->TableSlot = i
   ' and return the handle number
   RETURN i
  END IF
 NEXT
 'If no room is available, make the array bigger.
 REDIM PRESERVE plotslices(LBOUND(plotslices) TO UBOUND(plotslices) + 32)
 'Store the slice pointer in the handle slot
 plotslices(i) = sl
 'Store the handle slot in the slice
 sl->TableSlot = i
 ' and return the handle number
 RETURN i
END FUNCTION

FUNCTION find_plotslice_handle(BYVAL sl AS Slice Ptr) AS INTEGER
 IF sl = 0 THEN RETURN 0 ' it would be silly to search for a null pointer
 IF sl->TableSlot THEN RETURN sl->TableSlot
 'slice not in table, so create a new handle for it
 RETURN create_plotslice_handle(sl)
END FUNCTION

'By default, no palette set
FUNCTION load_sprite_plotslice(BYVAL spritetype AS INTEGER, BYVAL record AS INTEGER, BYVAL pal AS INTEGER=-2) AS INTEGER
 WITH sprite_sizes(spritetype)
  IF bound_arg(record, 0, gen(.genmax) + .genmax_offset, "sprite record number") THEN
   DIM sl AS Slice Ptr
   sl = NewSliceOfType(slSprite, SliceTable.scriptsprite)
   ChangeSpriteSlice sl, spritetype, record, pal
   RETURN create_plotslice_handle(sl)
  END IF
 END WITH
 RETURN 0 'Failure, return zero handle
END FUNCTION

'By default, no palette change
SUB replace_sprite_plotslice(BYVAL handle AS INTEGER, BYVAL spritetype AS INTEGER, BYVAL record AS INTEGER, BYVAL pal AS INTEGER=-2)
 WITH sprite_sizes(spritetype)
  IF valid_plotsprite(handle) THEN
   IF bound_arg(record, 0, gen(.genmax) + .genmax_offset, "sprite record number") THEN
    ChangeSpriteSlice plotslices(handle), spritetype, record, pal
   END IF
  END IF
 END WITH
END SUB

SUB change_rect_plotslice(BYVAL handle AS INTEGER, BYVAL style AS INTEGER=-2, BYVAL bgcol AS INTEGER=-1, BYVAL fgcol AS INTEGER=-1, BYVAL border AS INTEGER=-3, BYVAL translucent AS RectTransTypes=transUndef)
 IF valid_plotslice(handle) THEN
  DIM sl AS Slice Ptr
  sl = plotslices(handle)
  IF sl->SliceType = slRectangle THEN
   ChangeRectangleSlice sl, style, bgcol, fgcol, border, translucent
  ELSE
   scripterr commandname(curcmd->value) & ": " & SliceTypeName(sl) & " is not a rect", 5
  END IF
 END IF
END SUB
