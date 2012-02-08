'OHRRPGCE - Custom common code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
' This file is for general purpose code use by CUSTOM but not by GAME.

#include "config.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "const.bi"
#include "scrconst.bi"
#include "cglobals.bi"
#include "reload.bi"
#include "slices.bi"
#include "ver.txt"

#include "customsubs.bi"

OPTION EXPLICIT

'Subs and functions only used here
DECLARE SUB import_textboxes_warn (BYREF warn AS STRING, s AS STRING)
DECLARE SUB seekscript (BYREF temp AS INTEGER, BYVAL seekdir AS INTEGER, BYVAL triggertype AS INTEGER)
DECLARE SUB cond_editor (cond as Condition, byval default as integer = 0)

'Module-local variables
DIM SHARED comp_strings() as string
REDIM comp_strings(7) as string 
comp_strings(0) = ""
comp_strings(1) = "="
comp_strings(2) = "<>"
comp_strings(3) = "<"
comp_strings(4) = "<="
comp_strings(5) = ">"
comp_strings(6) = ">="
comp_strings(7) = "tag"   'debugging use only


FUNCTION safe_tag_name(BYVAL tagnum AS INTEGER) AS STRING 
 IF tagnum >= 1 AND tagnum <= gen(genMaxTagName) THEN
  RETURN load_tag_name(tagnum)
 ELSE
  RETURN ""
 END IF
END FUNCTION

'allowspecial indicates whether to allow picking 'special' tags: those automatically
'set, eg. based on inventory conditions
FUNCTION tag_grabber (BYREF n AS INTEGER, BYVAL min AS INTEGER=-999, BYVAL max AS INTEGER=999, BYVAL allowspecial as integer=YES) AS INTEGER
 IF intgrabber(n, min, max) THEN RETURN YES
 IF enter_or_space() THEN
  DIM browse_tag AS INTEGER
  browse_tag = tags_menu(n, YES, allowspecial)
  IF browse_tag >= 2 OR browse_tag <= -2 THEN
   n = browse_tag
   RETURN YES
  END IF
 END IF
 RETURN NO
END FUNCTION

SUB tag_autoset_warning(byval tag_id as integer)
 notification !"This tag is automatically set or unset on the following conditions:\n" + describe_tag_autoset_places(tag_id) + !"\nThis means that you should not attempt to set or unset the tag in any other way, because your changes will be erased -- unpredictably!"
END SUB

'If picktag is true, then can be used to pick a tag. In that case, allowspecial indicates whether to allow
'picking 'special' tags: those automatically set, eg. based on inventory conditions
FUNCTION tags_menu (byval starttag as integer=0, byval picktag as integer=NO, byval allowspecial as integer=YES) AS INTEGER
 DIM state AS MenuState
 DIM thisname as string
 DIM ret as integer = starttag
 IF gen(genMaxTagname) < 1 THEN gen(genMaxTagname) = 1
 DIM menu as BasicMenuItem vector
 v_new menu, gen(genMaxTagname) + 1
 IF picktag THEN
  menu[0].text = "Cancel"
 ELSE
  menu[0].text = "Previous Menu"
 END IF
 DIM i as integer
 FOR i = 2 TO gen(genMaxTagname) + 1
  'Load all tag names plus the first blank name
  menu[i - 1].text = "Tag " & i & ":" & load_tag_name(i)
  IF tag_is_autoset(i) THEN
   IF allowspecial = NO THEN
    menu[i - 1].disabled = YES
   ELSE
    'We don't have any UI colours that are subtle enough!
    'menu[i - 1].col = uilook(uiText)
   END IF
  END IF
 NEXT i

 DIM tagsign AS INTEGER
 tagsign = SGN(starttag)
 IF tagsign = 0 THEN tagsign = 1

 state.size = 23
 state.last = gen(genMaxTagname)

 state.pt = 0
 IF ABS(starttag) >= 2 THEN state.pt = small(ABS(starttag) - 1, gen(genMaxTagName))
 thisname = safe_tag_name(state.pt + 1)

 DIM int_browsing AS INTEGER = NO
 DIM uninterrupted_alt_press AS INTEGER = NO
 'Usually equal to state.pt + 1, but can reach 0
 DIM alt_pt AS INTEGER 

 DIM tog AS INTEGER = 0
 setkeys YES
 DO
  setwait 55
  setkeys YES
  tog = tog XOR 1
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "tagnames"
  IF usemenu(state) THEN
   thisname = safe_tag_name(state.pt + 1)
   alt_pt = state.pt + 1
  END IF
  IF keyval(scAlt) AND 4 THEN uninterrupted_alt_press = YES
  IF keyval(scAlt) = 0 AND uninterrupted_alt_press = YES THEN
   uninterrupted_alt_press = NO
   int_browsing XOR= YES
   alt_pt = state.pt + 1
  END IF
  IF int_browsing THEN
   IF intgrabber(alt_pt, 0, gen(genMaxTagName) + 1) THEN
    state.pt = large(0, alt_pt - 1)
    state.top = bound(state.top, state.pt - state.size, state.pt)
    thisname = safe_tag_name(state.pt + 1)
   END IF
  END IF
  IF state.pt = 0 AND enter_or_space() THEN EXIT DO
  IF state.pt > 0 AND state.pt + 1 <= gen(genMaxTagName) + 1 THEN
   IF keyval(scTab) > 1 ANDALSO tag_is_autoset(state.pt + 1) THEN
    tag_autoset_warning state.pt + 1
   END IF
   IF keyval(scEnter) > 1 THEN
    IF menu[state.pt].disabled THEN
     tag_autoset_warning state.pt + 1
    ELSEIF picktag THEN
     ret = (state.pt + 1) * tagsign
     EXIT DO
    END IF
   END IF
   IF int_browsing = NO ANDALSO strgrabber(thisname, 20) THEN
    uninterrupted_alt_press = NO
    save_tag_name thisname, state.pt + 1
    menu[state.pt].text = "Tag " & state.pt + 1 & ":" & thisname
    IF state.pt + 1 = gen(genMaxTagName) + 1 THEN
     IF gen(genMaxTagName) < 999 THEN
      gen(genMaxTagName) += 1
	  v_resize menu, gen(genMaxTagName) + 1
      menu[gen(genMaxTagName)].text = "Tag " & gen(genMaxTagName) + 1 & ":"
      state.last += 1
     END IF
    END IF
   END IF
  END IF

  clearpage dpage
  draw_fullscreen_scrollbar state, , dpage
  standardmenu menu, state, 0, 0, dpage
  DIM tmpstr AS STRING
  IF int_browsing THEN
   textcolor uilook(uiText), uilook(uiHighlight)
   tmpstr = "Tag " & alt_pt
  ELSE
   textcolor uilook(uiDisabledItem), 0
   tmpstr = "Alt:Tag #"
  END IF
  printstr tmpstr, 320 - LEN(tmpstr) * 8, 0, dpage

  IF tag_is_autoset(state.pt + 1) THEN
   textcolor uilook(uiDisabledItem), 0
   printstr "An auto-set tag. Press TAB for details", 0, 192, dpage
  END IF

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 v_free menu
 RETURN ret
END FUNCTION

'default: meaning of the null condition (true: ALWAYS, false: NEVER)
'alwaysedit: experimental parameter, changes behaviour of enter/space
'Return value is currently very unreliable.
FUNCTION cond_grabber (cond as Condition, byval default as integer = NO, byval alwaysedit as integer) as integer

 DIM intxt as string = getinputtext
 DIM entered_operator as integer = NO
 DIM temp as integer

 WITH cond

  'debug "cond_grabber: .type = " & comp_strings(.type) & " tag/var = " & .tag & " value = " & .value & " editst = " & .editstate & " lastchar = " & CHR(.lastinput) & "  default = " & default

  IF keyval(scDelete) > 1 THEN
   .type = 0
   RETURN YES
  END IF

  'Simplify
  IF .type = compTag AND .tag = 0 THEN .type = 0

  'enter_or_space
  IF .type = compTag AND alwaysedit = 0 THEN
   IF enter_or_space() THEN
    DIM browse_tag AS INTEGER
    browse_tag = tags_menu(.tag, YES, YES)
    IF browse_tag >= 2 OR browse_tag <= -2 THEN
     .tag = browse_tag
     RETURN YES
    ELSE
     'Return once enter/space processed
     RETURN NO
    END IF
   END IF
  ELSE
   'I tend to hit space while typing an expression...
   'IF enter_or_space() THEN 
   IF keyval(scEnter) > 1 THEN cond_editor(cond, default): RETURN YES
  END IF

  CONST compare_chars as string = "=<>!"
  'Use strings instead of integers for convenience -- have to decode to use
  STATIC statetable(3, 7) as string * 2 => { _
     /'Current comparison type:               '/ _
     /'None  =    <>   <    <=   >    >=  Tag '/ _
      {"=" ,"=" ,"=" ,"<=","=" ,">=","=" ,"=" },  /' = pressed  '/ _
      {"<" ,"<=","<" ,"<" ,"<" ,"<>","<" ,"<" },  /' < pressed  '/ _
      {">" ,">=",">" ,"<>",">" ,">" ,">" ,">" },  /' > pressed  '/ _
      {"<>","<>","=" ,">=",">" ,"<=","<" ,"<>"}   /' ! pressed  '/ _
  }

  'Listen for comparison operator input
  FOR i as integer = 1 TO LEN(intxt)
   DIM inchar as string = MID(intxt, i)
   DIM charnum as integer = INSTR(compare_chars, inchar)

   IF charnum THEN
    entered_operator = YES
    DIM newtype as integer = -1

    IF .type = compNone OR .type = compTag OR .editstate = 1 OR .editstate = 5 THEN
     'Ignore the current operator; we're pretending there is none
     newtype = str_array_findcasei(comp_strings(), inchar)

    ELSE
     'First check whether in the middle of typing a comparison operator.
     'This special check ensure that eg. typing >= causes the operator to
     'change to >= regardless of initial state
     IF .lastinput THEN
      'Only checking input strings of len 2
      newtype = str_array_findcasei(comp_strings(), CHR(.lastinput) + inchar)
     END IF

     IF newtype = -1 THEN
      DIM tempcomp as string = statetable(charnum - 1, .type)
      newtype = str_array_findcasei(comp_strings(), tempcomp)
     END IF
    END IF

    IF newtype > -1 THEN
     IF .type = compNone OR .type = compTag THEN
      .varnum = small(ABS(.tag), 4095)  'future proofing 'James says: why 4095? That is the script global limit not the tag limit
      .value = 0
      .editstate = 2
     END IF
     .type = newtype
    END IF
   END IF

   .lastinput = ASC(inchar)
  NEXT

  'Other input: a finite state machine
  IF .type = compNone THEN
   'No need to check for entered_operator: the type would have changed
   .tag = 0
   IF intgrabber(.tag, -999, 999) THEN
    .type = compTag
   END IF
  ELSEIF .type = compTag THEN
   'No need to check for entered_operator
   IF INSTR(intxt, "!") THEN
    .tag = -.tag
   ELSE
    intgrabber(.tag, -999, 999)
   END IF
  ELSE  'Globals
   'editstate is just a state id, defining the way the condition is edited and displayed
   '(below, asterixes indicate highlighting)
   '0: Global # .. #  (initial)
   '1: Global *#*
   '2: Global # *..*
   '3: Global # .. *#*
   '4: Global # *..* #
   '5: Global # *?* #
   '6: Global *#* .. #
   SELECT CASE .editstate
    CASE 0
     IF keyval(scTab) > 1 THEN
      .editstate = 3
     ELSEIF keyval(scBackspace) > 1 THEN
      'Backspace works from the right...
      intgrabber(.value, -2147483648, 2147483647)
      .editstate = 3
     ELSEIF entered_operator THEN
      .editstate = 4
     ELSE
      '...and numerals enter from the left
      temp = 0
      'Don't erase previous value when trying to inc/decrement it
      IF keyval(scLeft) > 0 OR keyval(scRight) > 0 THEN temp = .varnum
      IF intgrabber(temp, 0, maxScriptGlobals, , , YES) THEN
       .varnum = temp
       .editstate = 6
      END IF
     END IF
    CASE 1, 6
     IF .editstate = 6 AND keyval(scTab) > 1 THEN
      .editstate = 3
     ELSEIF entered_operator THEN
      IF .editstate = 1 THEN .editstate = 2 ELSE .editstate = 4
     ELSEIF keyval(scBackspace) > 1 AND .varnum = 0 THEN
      .editstate = 0
      .type = compNone
     ELSE
      intgrabber(.varnum, 0, maxScriptGlobals)
     END IF
    CASE 3
     IF keyval(scTab) > 1 THEN
      .editstate = 6
     ELSEIF entered_operator THEN
      .editstate = 4
     ELSEIF keyval(scBackspace) > 1 AND .value = 0 THEN
      .editstate = 2
     ELSE
      intgrabber(.value, -2147483648, 2147483647)
     END IF
    CASE 2, 4, 5  'Operator editing
     IF keyval(scTab) > 1 THEN
      .editstate = 3
     ELSEIF .editstate = 5 AND entered_operator THEN
      .editstate = 4
     ELSEIF keyval(scBackspace) > 1 THEN
      DIM newcomp as string = comp_strings(.type)
      IF .editstate = 5 THEN  'state 5 simulates LEN(newcomp) = 0
       .editstate = 1
      ELSEIF LEN(newcomp) = 1 THEN
       IF .editstate = 2 THEN
        .editstate = 1
       ELSEIF .editstate = 4 THEN
        .editstate = 5
       END IF
      ELSE 'LEN = 2
       .type = str_array_findcasei(comp_strings(), LEFT(newcomp, 1))
      END IF
     ELSE
      temp = 0
      'IF .editstate <> 2 THEN temp = .value
      'Don't erase previous value when trying to inc/decrement it
      IF keyval(scLeft) > 0 OR keyval(scRight) > 0 THEN temp = .value
      IF intgrabber(temp, -2147483648, 2147483647, , , YES) THEN
       .value = temp
       .editstate = 3
      END IF
     END IF
   END SELECT
  END IF

 END WITH
END FUNCTION

'default: meaning of the null condition (true: ALWAYS, false: NEVER)
SUB cond_editor (cond as Condition, byval default as integer = NO)
 DIM menu(10) as string
 menu(0) = "Cancel"
 menu(1) = "Always"
 menu(2) = "Never"
 menu(3) = "Tag # ON"
 menu(4) = "Tag # OFF"
 menu(5) = "Global # = #"
 menu(6) = "Global # <> #"
 menu(7) = "Global # < #"
 menu(8) = "Global # <= #"
 menu(9) = "Global # > #"
 menu(10) = "Global # >= #"

 DIM st as MenuState
 st.last = UBOUND(menu)
 st.size = 18
 DIM starttag as integer = 1

 IF cond.type = compTag AND cond.tag = 0 THEN cond.type = compNone
 IF cond.type = compNone THEN
  st.pt = iif(default, 1, 2)
 ELSEIF cond.type = compTag THEN
  starttag = ABS(cond.tag)
  IF cond.tag = 1 THEN
   st.pt = 2
  ELSEIF cond.tag = -1 THEN
   st.pt = 1
  ELSEIF cond.tag >= 2 THEN
   st.pt = 3
  ELSE
   st.pt = 4
  END IF
 ELSEIF cond.type >= compEq AND cond.type <= compGe THEN
  st.pt = cond.type - compEq + 5
 END IF

 DO
  setwait 55
  setkeys
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "cond_editor"
  IF enter_or_space() THEN
   SELECT CASE st.pt
    CASE 0:
     EXIT DO
    CASE 1:
     IF default THEN
      cond.type = compNone
     ELSE
      cond.type = compTag
      cond.tag = -1
     END IF
    CASE 2:
     IF default = 0 THEN
      cond.type = compNone
     ELSE
      cond.type = compTag
      cond.tag = 1
     END IF
    CASE 3:
     cond.type = compTag
     cond.tag = tags_menu(starttag, YES, YES)
    CASE 4:
     cond.type = compTag
     cond.tag = tags_menu(-1 * starttag, YES, YES)
    CASE ELSE:
     'TODO: global variable browser
     cond.type = (st.pt - 5) + compEq
     cond.editstate = 6  'start by entering global variable number
   END SELECT
   EXIT DO
  END IF
  usemenu st

  clearpage vpage
  standardmenu menu(), st, 0, 0, vpage
  setvispage vpage
  dowait
 LOOP
END SUB

'Returns a printable representation of a Condition with lots of ${K} colours
'default: the text displayed for a null Condition
'selected: whether this menu item is selected
'wide: max string length to return (not implemented yet)
FUNCTION condition_string (cond as Condition, byval selected as integer, default as string = "Always", byval wide as integer = 40) as string
 DIM ret as string = default
 DIM hilite as string = "${K" & uilook(uiHighlight2) & "}"

 IF selected = NO THEN cond.editstate = 0: cond.lastinput = 0

 IF cond.type = compNone THEN
 ELSEIF cond.type = compTag THEN
  IF cond.tag = 0 THEN
  ELSE
   ret = "Tag " & ABS(cond.tag) & iif_string(cond.tag >= 0, "=ON", "=OFF")
   IF cond.tag = 1 THEN
    ret += " [Never]"
   ELSEIF cond.tag = -1 THEN
    ret += " [Always]"
   ELSE
    ret += " (" & load_tag_name(ABS(cond.tag)) & ")"
   END IF
  END IF
 ELSEIF cond.type >= compEq AND cond.type <= compGe THEN
  SELECT CASE cond.editstate
   CASE 0
    ret = "Global #" & cond.varnum & " " & comp_strings(cond.type) & " " & cond.value
   CASE 1
    ret = "Global #" & hilite & cond.varnum
   CASE 2
    ret = "Global #" & cond.varnum & " " & hilite & comp_strings(cond.type)
   CASE 3
    ret = "Global #" & cond.varnum & " " & comp_strings(cond.type) & " " & hilite & cond.value
   CASE 4
    ret = "Global #" & cond.varnum & " " & hilite & comp_strings(cond.type) & "${K-1} " & cond.value
   CASE 5
    'FIXME: a tag for text background colour hasn't been implemented yet
    ret = "Global #" & cond.varnum & hilite & " ?${K-1} " & cond.value
   CASE 6
    ret = "Global #" & hilite & cond.varnum & "${K-1} " & comp_strings(cond.type) & " " & cond.value
  END SELECT
 ELSE
  ret = "[Corrupt condition data]"
 END IF
 RETURN ret
END FUNCTION

'Returns true if the string has changed
FUNCTION strgrabber (s AS STRING, BYVAL maxl AS INTEGER) AS INTEGER
 STATIC clip AS STRING
 DIM old AS STRING = s

 '--BACKSPACE support
 IF keyval(scBackspace) > 1 THEN s = LEFT(s, LEN(s) - 1)

 '--copy+paste support
 IF copy_keychord() THEN clip = s
 IF paste_keychord() THEN s = LEFT(clip, maxl)

 '--adding chars
 IF LEN(s) < maxl THEN
  IF keyval(scSpace) > 1 AND keyval(scCtrl) > 0 THEN
   '--charlist support
   s = s + charpicker()
  ELSE
   'Note: never returns newlines; and we don't check either
   s = LEFT(s + getinputtext, maxl)
  END IF
 END IF

 RETURN (s <> old)
END FUNCTION

FUNCTION charpicker() AS STRING
 STATIC pt AS INTEGER

 DIM i AS INTEGER
 DIM f(255) AS INTEGER
 DIM last AS INTEGER = -1
 DIM linesize AS INTEGER
 DIM offset AS XYPair

 FOR i = 32 TO 255
  last = last + 1
  f(last) = i
 NEXT i

 linesize = 16
 offset.x = 160 - (linesize * 9) \ 2
 offset.y = 100 - ((last \ linesize) * 9) \ 2

 DIM tog AS INTEGER = 0
 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
  IF keyval(scESC) > 1 THEN RETURN ""
  IF keyval(scF1) > 1 THEN show_help "charpicker"

  IF keyval(scUp) > 1 THEN pt = large(pt - linesize, 0)
  IF keyval(scDown) > 1 THEN pt = small(pt + linesize, last)
  IF keyval(scLeft) > 1 THEN pt = large(pt - 1, 0)
  IF keyval(scRight) > 1 THEN pt = small(pt + 1, last)

  IF enter_or_space() THEN RETURN CHR(f(pt))

  clearpage dpage
  FOR i = 0 TO last
   textcolor uilook(uiMenuItem), uilook(uiDisabledItem)
                                            IF (i MOD linesize) = (pt MOD linesize) OR (i \ linesize) = (pt \ linesize) THEN textcolor uilook(uiMenuItem), uilook(uiHighlight)
   IF pt = i THEN textcolor uilook(uiSelectedItem + tog), 0
   printstr CHR(f(i)), offset.x + (i MOD linesize) * 9, offset.y + (i \ linesize) * 9, dpage
  NEXT i

  textcolor uilook(uiMenuItem), 0
  printstr "ASCII " & f(pt), 78, 190, dpage
  FOR i = 2 TO 53
   IF f(pt) = ASC(key2text(2, i)) THEN printstr "ALT+" + UCASE(key2text(0, i)), 178, 190, dpage
   IF f(pt) = ASC(key2text(3, i)) THEN printstr "ALT+SHIFT+" + UCASE(key2text(0, i)), 178, 190, dpage
  NEXT i
  IF f(pt) = 32 THEN printstr "SPACE", 178, 190, dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END FUNCTION

'Edit a floating point value and its string representation simultaneously (repr
'effectively stores the editing state). Initialise repr with format_percent(float)
'Returns true if float or repr changed
'decimalplaces actually limits the number of sig. fig.s too, except in front of the decimal point.
'Note: min and max are not in percent: max=1 is 100%
FUNCTION percent_grabber(byref float as double, repr as string, byval min as double, byval max as double, byval decimalplaces as integer = 4) as integer
 STATIC clip as double
 DIM oldfloat as double = float
 DIM oldrepr as string = repr

 'Remove negative (because we trim leading 0's later) and percentage signs
 repr = LEFT(repr, LEN(repr) - 1)
 DIM sign as integer = 1
 IF LEFT(repr, 1) = "-" THEN sign = -1: repr = MID(repr, 2)

 '--Textual editing. The following is very similar to strgrabber
 IF copy_keychord() THEN clip = float
 IF paste_keychord() THEN float = clip
 IF keyval(scBackspace) > 1 AND LEN(repr) > 0 THEN repr = LEFT(repr, LEN(repr) - 1)
 repr += exclusive(getinputtext, "0123456789.")

 'Exclude all but last period
 DIM period as integer = INSTRREV(repr, ".")
 DO
  DIM period2 as integer = INSTR(repr, ".")
  IF period = period2 THEN EXIT DO
  repr = MID(repr, 1, period2 - 1) + MID(repr, period2 + 1)
  period -= 1
 LOOP

 'Enforce sig. fig.s/decimal places limit
 IF period THEN repr = LEFT(repr, large(period, decimalplaces + 1))

 'Trim leading 0's
 repr = LTRIM(repr, "0")
 IF LEN(repr) = 0 ORELSE repr[0] = ASC(".") THEN repr = "0" + repr

 IF sign = -1 THEN repr = "-" + repr

 '--Numerical editing.
 float = VAL(repr) / 100
 IF float = 0.0 ANDALSO sign = -1 THEN repr = MID(repr, 2)  'Convert -0 to 0
 DIM increment as double = 0.01
 period = INSTR(repr, ".")
 IF period THEN
  increment *= 0.1 ^ (LEN(repr) - period)
 END IF

 DIM changed as integer = NO  'Whether to replace repr
 IF keyval(scLeft) > 1 THEN
  float -= increment
  changed = YES
 END IF
 IF keyval(scRight) > 1 THEN
  float += increment
  changed = YES
 END IF
 IF (keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1) AND min < 0.0 THEN
  float = -float
  changed = YES
 END IF
 IF (keyval(scPlus) > 1 OR keyval(scNumpadPlus) > 1) AND max > 0.0 THEN
  float = ABS(float)
  changed = YES
 END IF

 'Cleanup
 DIM temp as double = float
 float = bound(float, min, max) 
 IF changed OR float <> temp THEN
  repr = format_percent(float, decimalplaces)
 ELSE
  repr += "%"
 END IF
 RETURN (oldfloat <> float) ORELSE (oldrepr <> repr)
END FUNCTION

FUNCTION percent_grabber(byref float as single, repr as string, byval min as double, byval max as double, byval decimalplaces as integer = 4) as integer
 DIM temp as double = float
 DIM ret as integer = percent_grabber(temp, repr, min, max, decimalplaces)
 float = temp
 RETURN ret
END FUNCTION

'Return initial representation string for percent_cond_grabber
FUNCTION format_percent_cond(byref cond as AttackElementCondition, default as string, byval decimalplaces as integer = 4) as string
 IF cond.type = compNone THEN
  RETURN default
 ELSE
  RETURN " " + comp_strings(cond.type) + " " + format_percent(cond.value, decimalplaces)
 END IF
END FUNCTION

'This will probably only be used for editing AttackElementConditions, but it more general than that
FUNCTION percent_cond_grabber(byref cond as AttackElementCondition, repr as string, default as string, byval min as double, byval max as double, byval decimalplaces as integer = 4) as integer
 WITH cond
  DIM intxt as string = getinputtext
  DIM newtype as integer = .type

  IF keyval(scDelete) > 1 THEN newtype = compNone

  'Listen for comparison operator input
  FOR i as integer = 1 TO LEN(intxt)
   DIM inchar as string = MID(intxt, i)
   IF inchar = "<" THEN newtype = compLt
   IF inchar = ">" THEN newtype = compGt
  NEXT

  IF newtype <> .type THEN
   IF .type = compNone THEN .value = 0
   .type = newtype
   repr = format_percent_cond(cond, default, decimalplaces)
   RETURN YES
  ELSEIF .type = compNone THEN
   DIM temp as string = "0%"
   .value = 0
   'typing 0 doesn't change the value or repr, workaround
   IF percent_grabber(.value, temp, min, max, decimalplaces) OR INSTR(intxt, "0") > 0 THEN
    repr = " < " + temp
    .type = compLt
    RETURN YES
   END IF
   RETURN NO
  ELSE
   'Trim comparison operator
   repr = MID(repr, 4)
   IF keyval(scBackspace) > 1 ANDALSO repr = "0%" THEN
    repr = default
    .type = compNone
    RETURN YES
   ELSE
    DIM ret as integer = percent_grabber(.value, repr, min, max, decimalplaces)
    'Add back operator
    repr = " " + comp_strings(.type) + " " + repr
    RETURN ret
   END IF
  END IF

 END WITH
END FUNCTION

SUB percent_cond_editor (cond as AttackElementCondition, byval min as double, byval max as double, byval decimalplaces as integer = 4, do_what as string = "...", percent_of_what as string = "")
 DIM cond_types(2) as integer = {compNone, compLt, compGt}
 DIM type_num as integer
 FOR i as integer = 0 TO 2
  IF cond.type = cond_types(i) THEN type_num = i
 NEXT

 DIM menu(2) as string
 menu(0) = "Previous Menu"
 DIM st as MenuState
 st.size = 18
 st.pt = 1

 DIM repr as string = format_percent(cond.value, decimalplaces)

 DO
  setwait 55
  setkeys YES
  IF keyval(scEsc) > 1 OR enter_or_space() THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "percent_cond_editor"
  SELECT CASE st.pt
   CASE 1: IF intgrabber(type_num, 0, 2) THEN cond.type = cond_types(type_num)
   CASE 2: percent_grabber(cond.value, repr, min, max, decimalplaces)
  END SELECT

  'Update
  IF cond.type = compNone THEN menu(1) = "Condition: Never"
  IF cond.type = compGt THEN menu(1) = "Condition: " + do_what + " when more than..."
  IF cond.type = compLt THEN menu(1) = "Condition: " + do_what + " when less than..."
  menu(2) = "Threshold: " + repr + percent_of_what
  st.last = IIF(cond.type = compNone, 1, 2)

  usemenu st

  clearpage vpage
  standardmenu menu(), st, 0, 0, vpage
  setvispage vpage
  dowait
 LOOP
END SUB

SUB ui_color_editor(palnum AS INTEGER)
 DIM i AS INTEGER
 DIM index AS INTEGER
 DIM default_colors(uiColors) AS INTEGER

 DIM sample_menu AS MenuDef
 ClearMenuData sample_menu
 WITH sample_menu
  .anchor.x = 1
  .anchor.y = -1
  .offset.x = 156
  .offset.y = -96
 END WITH
 append_menu_item sample_menu, "Sample"
 append_menu_item sample_menu, "Example"
 append_menu_item sample_menu, "Disabled"
 sample_menu.last->disabled = YES
 
 DIM sample_state AS MenuState
 sample_state.active = YES
 init_menu_state sample_state, sample_menu

 GuessDefaultUIColors default_colors()

 LoadUIColors uilook(), palnum

 DIM color_menu(uiColors + 1) AS STRING
 make_ui_color_editor_menu color_menu(), uilook()

 DIM state AS MenuState
 state.size = 22
 state.last = UBOUND(color_menu)

 DIM tog AS INTEGER = 0
 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "ui_color_editor"
  usemenu state

  index = state.pt - 1

  IF enter_or_space() THEN
   IF state.pt = 0 THEN
    EXIT DO
   ELSEIF index < uiTextBoxFrame THEN
    'Color browser
    uilook(index) = color_browser_256(uilook(index))
    make_ui_color_editor_menu color_menu(), uilook() 
   END IF
  END IF

  SELECT CASE index
   CASE 0 TO 47
    IF intgrabber(uilook(index), 0, 255) THEN
     make_ui_color_editor_menu color_menu(), uilook()
    END IF
   CASE 48 TO 62
    IF zintgrabber(uilook(index), -1, gen(genMaxBoxBorder)) THEN
     make_ui_color_editor_menu color_menu(), uilook()
    END IF
  END SELECT

  IF index >= 0 THEN
   IF keyval(scCtrl) > 0 AND keyval(scD) > 1 THEN ' Ctrl+D
    uilook(index) = default_colors(index)
    make_ui_color_editor_menu color_menu(), uilook()
   END IF
  END IF

  '--update sample according to what you have highlighted
  sample_menu.boxstyle = 0
  sample_state.pt = 0
  SELECT CASE index
   CASE 5,6 ' selected disabled
    sample_state.pt = 2
   CASE 18 TO 47
    sample_menu.boxstyle = (state.pt - 19) \ 2
   CASE 48 TO 62
    sample_menu.boxstyle = index - 48
  END SELECT

  '--draw screen
  clearpage dpage
  draw_menu sample_menu, sample_state, dpage
  standardmenu color_menu(), state, 10, 0, dpage
  FOR i = state.top TO state.top + state.size
   IF i > 0  AND i <= 48 THEN
    rectangle 0, 8 * (i - state.top), 8, 8, uilook(i - 1), dpage
   END IF
  NEXT i
  edgeprint "Ctrl+D to revert to default", 100, 190, uilook(uiText), dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 SaveUIColors uilook(), palnum
 ClearMenuData sample_menu
END SUB

SUB make_ui_color_editor_menu(m() AS STRING, colors() AS INTEGER)
 DIM cap(17) AS STRING = {"Background", "Menu item", "Disabled item", _
     "Selected item (A)", "Selected item (B)", "Selected disabled item (A)", _
      "Selected disabled item (B)", "Hilight (A)", "Hilight (B)", "Time bar", _
      "Time bar (full)", "Health bar", "Health bar (flash)", "Default Text", _
      "Text outline", "Spell description", "Total money", "Vehicle shadow"}
 DIM i AS INTEGER
 m(0) = "Previous Menu"
 FOR i = 0 TO 17
  m(1 + i) = cap(i) & ": " & colors(i)
 NEXT i
 FOR i = 0 TO 14
  m(19 + i*2) = "Box style " & i & " color:  " & colors(18 + i*2)
  m(19 + i*2 + 1) = "Box style " & i & " border: " & colors(18 + i*2 + 1)
  m(49 + i) = "Box style " & i & " border image: " & zero_default(colors(48 + i), "none", -1)
 NEXT i
END SUB

FUNCTION pick_ogg_quality(BYREF quality AS INTEGER) AS INTEGER
 STATIC q as integer = 4
 DIM i as integer
 DIM descrip as string
 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN RETURN -1   'cancel
  IF keyval(scF1) > 1 THEN show_help "pick_ogg_quality"
  IF enter_or_space() THEN EXIT DO
  intgrabber (q, -1, 10)
  clearpage dpage
  centerbox 160, 105, 300, 54, 4, dpage
  edgeprint "Pick Ogg quality level (" & q & ")", 64, 86, uilook(uiText), dpage
  FOR i = 0 TO q + 1
   rectangle 30 + 21 * i, 100, 20, 16, uilook(uiText), dpage
  NEXT i
  SELECT CASE q
   CASE -1: descrip = "scratchy, smallest"
   CASE 0: descrip = "not too bad, very small"
   CASE 1: descrip = "pretty good, quite small"
   CASE 2: descrip = "good, pretty small"
   CASE 3: descrip = "very good, smallish"
   CASE 4: descrip = "great, medium sized"
   CASE 5: descrip = "amazing, biggish"
   CASE 6: descrip = "better than you need, big"
   CASE 7: descrip = "much better than you need, too big"
   CASE 8: descrip = "excessive, wasteful"
   CASE 9: descrip = "very excessive, very wasteful"
   CASE 10: descrip = "flagrantly excessive and wasteful"
  END SELECT
  edgeprint descrip, xstring(descrip, 160), 118, uilook(uiText), dpage
  swap vpage, dpage
  setvispage vpage
  dowait
 LOOP
 quality = q
 RETURN 0
END FUNCTION

FUNCTION needaddset (BYREF pt AS INTEGER, BYREF check AS INTEGER, what AS STRING) AS INTEGER
 IF pt <= check THEN RETURN NO
 IF yesno("Add new " & what & "?") THEN
  check += 1
  RETURN YES
 ELSE
  pt -= 1
 END IF
 RETURN NO
END FUNCTION

'This is intgrabber, and if the 'more' key is pressed when pt=max, asks whether to
'add a new set. DOES NOT INCREMENT max. Check whether pt > max to see whether this
'needs to be handled.
'maxmax is max value of max, of course
FUNCTION intgrabber_with_addset(BYREF pt AS INTEGER, BYVAL min AS INTEGER, BYVAL max AS INTEGER, BYVAL maxmax AS INTEGER=32767, what AS STRING, BYVAL less AS INTEGER=scLeft, BYVAL more AS INTEGER=scRight) AS INTEGER
 IF keyval(more) > 1 AND pt = max AND max < maxmax THEN
  IF yesno("Add new " & what & "?") THEN
   pt += 1
   RETURN YES
  END IF
  RETURN NO
 ELSE
  RETURN intgrabber(pt, min, max, less, more, NO, NO)
 END IF
END FUNCTION

FUNCTION editnpc_zone_caption(byval zoneid as integer, byval default as integer, zmap as ZoneMap) as string
 DIM caption as string
 IF zoneid = 0 THEN
  caption = " Map default:"
  zoneid = default
 ELSEIF zoneid = -1 THEN
  'We use -1 instead of 0 for None simply so that the default value
  '(including in existing games) is 'default'
  zoneid = 0
 END IF
 IF zoneid = 0 THEN
  caption += " None"
 ELSE
  caption += " " & zoneid & " " & GetZoneInfo(zmap, zoneid)->name
 END IF
 RETURN caption
END FUNCTION

FUNCTION explain_two_tag_condition(prefix as string, truetext as string, falsetext as string, byval zerovalue as integer, byval tag1 as integer, byval tag2 as integer) as string
  DIM ret as string
  ret = "Appears if"
  DIM true_count as integer
  DIM false_count as integer
  IF tag1 = 0 THEN tag1 = IIF(zerovalue, -1, 1)
  IF tag2 = 0 THEN tag2 = IIF(zerovalue, -1, 1)
  IF tag1 = 1 THEN
   false_count += 1
  ELSEIF tag1 = -1 THEN
   true_count += 1
  ELSE
   ret &= " tag " & ABS(tag1) & " = " & onoroff(tag1)
  END IF
  IF tag2 = 1 THEN
   false_count += 1
  ELSEIF tag2 = -1 THEN
   true_count += 1
  ELSE
   IF true_count = 0 AND false_count = 0 THEN ret &= " and"
   ret &= " tag " & ABS(tag2) & " = " & onoroff(tag2)
  END IF
  
  IF true_count = 2 THEN ret = truetext
  IF false_count > 0 THEN ret = falsetext
  RETURN ret
END FUNCTION

SUB edit_npc (npcdata AS NPCType, gmap() AS integer, zmap AS ZoneMap)
 DIM i AS INTEGER

 DIM itemname AS STRING
 DIM boxpreview AS STRING
 DIM scrname AS STRING
 DIM vehiclename AS STRING
 DIM caption AS STRING

 DIM walk AS INTEGER = 0
 DIM tog AS INTEGER = 0

 DIM unpc(16) AS INTEGER, lnpc(16) AS INTEGER
 DIM menucaption(16) AS STRING

 DIM state AS MenuState
 state.size = 24
 state.first = -1
 state.last = UBOUND(menucaption)
 state.top = -1
 state.pt = -1

 'lower and upper data limits
 unpc(0) = gen(genMaxNPCPic)
 unpc(1) = 32767
 unpc(2) = 8
 unpc(3) = 5
 unpc(4) = gen(genMaxTextbox)       'max text boxes
 unpc(5) = 2
 unpc(6) = gen(genMaxItem) + 1
 unpc(7) = 7
 unpc(8) = 2
 unpc(9) = 999
 unpc(10) = 999
 unpc(11) = 1
 unpc(12) = gen(genMaxRegularScript)'max scripts
 unpc(13) = 32767
 unpc(14) = gen(genMaxVehicle) + 1  'max vehicles
 unpc(15) = 9999  'zones
 unpc(16) = 9999  'zones

 FOR i = 0 TO UBOUND(lnpc)
  lnpc(i) = 0
 NEXT i
 lnpc(1) = -1
 lnpc(9) = -999
 lnpc(10) = -999
 lnpc(13) = -32767
 lnpc(15) = -1
 lnpc(16) = -1

 menucaption(0) = "Picture"
 menucaption(1) = "Palette"
 menucaption(2) = "Move Type"
 menucaption(3) = "Move Speed"
 menucaption(4) = "Display Text"
 menucaption(5) = "When Activated"
 menucaption(6) = "Give Item:"
 menucaption(7) = "Pushability"
 menucaption(8) = "Activation: "
 menucaption(9) = "Appear if Tag "
 menucaption(10) = "Appear if Tag "
 menucaption(11) = "Usable"
 menucaption(12) = "Run Script: "
 menucaption(13) = "Script Argument"
 menucaption(14) = "Vehicle: "
 menucaption(15) = "Movement Zone:"
 menucaption(16) = "Avoidance Zone:"
 DIM movetype(8) AS STRING
 movetype(0) = "Stand Still"
 movetype(1) = "Wander"
 movetype(2) = "Pace"
 movetype(3) = "Right Turns"
 movetype(4) = "Left Turns"
 movetype(5) = "Random Turns"
 movetype(6) = "Chase You"
 movetype(7) = "Avoid You"
 movetype(8) = "Walk In Place"
 DIM pushtype(7) AS STRING
 pushtype(0) = "Off"
 pushtype(1) = "Full"
 pushtype(2) = "Vertical"
 pushtype(3) = "Horizontal"
 pushtype(4) = "Up only"
 pushtype(5) = "Right Only"
 pushtype(6) = "Down Only"
 pushtype(7) = "Left Only"
 DIM usetype(2) AS STRING
 usetype(0) = "Use"
 usetype(1) = "Touch"
 usetype(2) = "Step On"
 DIM facetype(2) AS STRING
 facetype(0) = "Change Direction"
 facetype(1) = "Face Player"
 facetype(2) = "Do Not Face Player"

 npcdata.sprite = frame_load(4, npcdata.picture)
 npcdata.pal = palette16_load(npcdata.palette, 4, npcdata.picture)

 itemname = load_item_name(npcdata.item, 0, 0)
 boxpreview = textbox_preview_line(npcdata.textbox)
 scrname = scriptname$(npcdata.script, plottrigger)
 vehiclename = load_vehicle_name(npcdata.vehicle - 1)

 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
  IF npcdata.movetype > 0 THEN walk = walk + 1: IF walk > 3 THEN walk = 0
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "edit_npc"
  usemenu state
  SELECT CASE state.pt
   CASE 0'--picture
    IF intgrabber(npcdata.picture, lnpc(state.pt), unpc(state.pt)) THEN
     frame_unload @npcdata.sprite
     palette16_unload @npcdata.pal
     npcdata.sprite = frame_load(4, npcdata.picture)
     npcdata.pal = palette16_load(npcdata.palette, 4, npcdata.picture)
    END IF
   CASE 1'--palette
    IF intgrabber(npcdata.palette, lnpc(state.pt), unpc(state.pt)) THEN
     palette16_unload @npcdata.pal
     npcdata.pal = palette16_load(npcdata.palette, 4, npcdata.picture)
    END IF
    IF enter_or_space() THEN
     npcdata.palette = pal16browse(npcdata.palette, 4, npcdata.picture)
     palette16_unload @npcdata.pal
     npcdata.pal = palette16_load(npcdata.palette, 4, npcdata.picture)
    END IF
   CASE 2
    intgrabber(npcdata.movetype, lnpc(state.pt), unpc(state.pt))
   CASE 3
    'yuck.
    IF npcdata.speed = 10 THEN npcdata.speed = 3
    intgrabber(npcdata.speed, lnpc(state.pt), unpc(state.pt))
    IF npcdata.speed = 3 THEN npcdata.speed = 10
   CASE 4
    IF intgrabber(npcdata.textbox, lnpc(state.pt), unpc(state.pt)) THEN
     boxpreview = textbox_preview_line(npcdata.textbox)
    END IF
   CASE 5
    intgrabber(npcdata.facetype, lnpc(state.pt), unpc(state.pt))
   CASE 6
    IF intgrabber(npcdata.item, lnpc(state.pt), unpc(state.pt)) THEN
     itemname = load_item_name(npcdata.item, 0, 0)
    END IF
   CASE 7
    intgrabber(npcdata.pushtype, lnpc(state.pt), unpc(state.pt))
   CASE 8
    intgrabber(npcdata.activation, lnpc(state.pt), unpc(state.pt))
   CASE 9'--tag conditionals
    tag_grabber npcdata.tag1
   CASE 10'--tag conditionals
    tag_grabber npcdata.tag2
   CASE 11'--one-time-use tag
    IF keyval(scLeft) > 1 OR keyval(scRight) > 1 OR enter_or_space() THEN
     onetimetog npcdata.usetag
    END IF
   CASE 12'--script
    IF enter_or_space() THEN
     scrname = scriptbrowse_string(npcdata.script, plottrigger, "NPC use plotscript")
    ELSEIF scrintgrabber(npcdata.script, 0, 0, scLeft, scRight, 1, plottrigger) THEN
     scrname = scriptname$(npcdata.script, plottrigger)
    END IF
   CASE 13
    intgrabber(npcdata.scriptarg, lnpc(state.pt), unpc(state.pt))
   CASE 14
    IF intgrabber(npcdata.vehicle, lnpc(state.pt), unpc(state.pt)) THEN
     vehiclename = load_vehicle_name(npcdata.vehicle - 1)
    END IF
   CASE 15
    intgrabber(npcdata.defaultzone, lnpc(state.pt), unpc(state.pt))
   CASE 16
    intgrabber(npcdata.defaultwallzone, lnpc(state.pt), unpc(state.pt))
   CASE -1' previous menu
    IF enter_or_space() THEN EXIT DO
  END SELECT
  '--Draw screen
  clearpage dpage
  textcolor uilook(uiMenuItem), 0
  IF state.pt = -1 THEN textcolor uilook(uiSelectedItem + tog), 0
  printstr "Previous Menu", 0, 0, dpage
  FOR i = 0 TO UBOUND(menucaption)
   textcolor uilook(uiMenuItem), 0
   IF state.pt = i THEN textcolor uilook(uiSelectedItem + tog), 0
   caption = " " & read_npc_int(npcdata, i)
   SELECT CASE i
    CASE 1
     caption = " " & defaultint$(npcdata.palette)
    CASE 2
     caption = " = " & safe_caption(movetype(), npcdata.movetype, "movetype")
    CASE 3
     caption = " " & npcdata.speed
    CASE 4
     caption = " " & zero_default(npcdata.textbox, "[None]")
    CASE 5
     caption = " " & safe_caption(facetype(), npcdata.facetype, "facetype")
    CASE 6
     caption = " " & itemname
    CASE 7
     caption = " " & safe_caption(pushtype(), npcdata.pushtype, "pushtype")
    CASE 8
     caption = safe_caption(usetype(), npcdata.activation, "usetype")
    CASE 9
	 caption = tag_condition_caption(npcdata.tag1, "", "Always")
    CASE 10
	 caption = tag_condition_caption(npcdata.tag2, "", "Always")
    CASE 11
     IF npcdata.usetag THEN caption = " Only Once (tag " & (1000 + npcdata.usetag) & ")" ELSE caption = " Repeatedly"
    CASE 12 'script
     caption = scrname
    CASE 13 'script arg
     IF npcdata.script = 0 THEN caption = " N/A"
    CASE 14 'vehicle
     IF npcdata.vehicle <= 0 THEN
      caption = "No"
     ELSE
      caption = vehiclename
     END IF
    CASE 15 'default movement zone
     caption = editnpc_zone_caption(npcdata.defaultzone, gmap(32), zmap)
    CASE 16 'default avoidance zone
     caption = editnpc_zone_caption(npcdata.defaultwallzone, gmap(33), zmap)
   END SELECT
   printstr menucaption(i) + caption, 0, 8 + (8 * i), dpage
  NEXT i
  edgebox 9, 149, 22, 22, uilook(uiDisabledItem), uilook(uiText), dpage
  frame_draw npcdata.sprite + 4 + (walk \ 2), npcdata.pal, 10, 150, 1, YES, dpage
  textcolor uilook(uiSelectedItem2), uiLook(uiHighlight)
  printstr boxpreview, 0, 177, dpage
  textcolor uilook(uiSelectedItem2), 0
  printstr explain_two_tag_condition("Appears if", "Appears all the time", "Never appears!", YES, npcdata.tag1, npcdata.tag2), 0, 190, dpage
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 frame_unload @npcdata.sprite
 palette16_unload @npcdata.pal
END SUB

FUNCTION load_vehicle_name(vehID AS INTEGER) AS STRING
 IF vehID < 0 OR vehID > gen(genMaxVehicle) THEN RETURN ""
 DIM vehicle AS VehicleData
 LoadVehicle game + ".veh", vehicle, vehID
 RETURN vehicle.name
END FUNCTION

FUNCTION load_item_name (it AS INTEGER, hidden AS INTEGER, offbyone AS INTEGER) AS STRING
 'it - the item number
 'hidden - whether to *not* prefix the item number
 'offbyone - whether it is the item number (1), or the itemnumber + 1 (0)
 IF it <= 0 AND offbyone = NO THEN RETURN "NONE"
 DIM itn AS INTEGER
 IF offbyone THEN itn = it ELSE itn = it - 1
 DIM result AS STRING = readitemname(itn)
 IF hidden = 0 THEN result = itn & " " & result
 RETURN result
END FUNCTION

FUNCTION textbox_preview_line(boxnum AS INTEGER) AS STRING
 IF boxnum <= 0 OR boxnum > gen(genMaxTextBox) THEN RETURN ""
 DIM box AS TextBox
 LoadTextBox box, boxnum
 RETURN textbox_preview_line(box)
END FUNCTION

FUNCTION textbox_preview_line(box AS TextBox) AS STRING
 DIM s AS STRING
 DIM i AS INTEGER
 FOR i = 0 TO 7
  s= TRIM(box.text(i))
  IF LEN(s) > 0 THEN RETURN s 
 NEXT i
 RETURN "" 
END FUNCTION

SUB onetimetog(BYREF tagnum AS INTEGER)
 IF tagnum > 0 THEN
  setbit gen(), genOneTimeNPCBits, tagnum - 1, 0
  tagnum = 0
  EXIT SUB
 END IF
 DIM i AS INTEGER = 0
 DO
  gen(genOneTimeNPC) = loopvar(gen(genOneTimeNPC), 0, 999, 1)
  i = i + 1: IF i > 1000 THEN EXIT SUB 'Revisit this later
 LOOP UNTIL readbit(gen(), genOneTimeNPCBits, gen(genOneTimeNPC)) = 0
 tagnum = gen(genOneTimeNPC) + 1
 setbit gen(), genOneTimeNPCBits, gen(genOneTimeNPC), 1
END SUB

FUNCTION pal16browse (BYVAL curpal AS INTEGER, BYVAL picset AS INTEGER, BYVAL picnum AS INTEGER) AS INTEGER

 DIM buf(7) AS INTEGER
 DIM sprite(9) AS Frame PTR
 DIM pal16(9) AS Palette16 PTR

 DIM AS INTEGER i, o, j, k
 DIM c AS INTEGER

 DIM state AS MenuState
 state.need_update = YES
 state.top = curpal - 1
 state.first = -1
 state.size = 9

 '--get last pal
 loadrecord buf(), game + ".pal", 8, 0
 state.last = buf(1) + 1
 FOR i = state.last TO 0 STEP -1
  state.last = i
  loadrecord buf(), game + ".pal", 8, 1 + i
  FOR j = 0 TO 7
   IF buf(j) <> 0 THEN EXIT FOR, FOR
  NEXT j
 NEXT i

 state.pt = bound(curpal, 0, state.last)
 state.top = bound(state.top, state.first, large(state.last - state.size, state.first))

 'reset repeat rate, needed because called from sprite editor (argh), the caller resets its own repeatrate
 setkeys
 DO
  setwait 55
  setkeys
  state.tog = state.tog XOR 1
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "pal16browse"
  IF usemenu(state) THEN state.need_update = YES
  DIM temppt AS INTEGER = large(state.pt, 0)
  IF intgrabber(temppt, 0, state.last, , , YES) THEN
   state.pt = temppt
   state.top = bound(state.top, state.pt - state.size, state.pt)
   state.need_update = YES
  END IF
  IF enter_or_space() THEN
   IF state.pt >= 0 THEN curpal = state.pt
   EXIT DO
  END IF

  IF state.need_update THEN
   state.need_update = NO
   FOR i = 0 TO 9
    frame_unload @sprite(i)
    palette16_unload @pal16(i)
    sprite(i) = frame_load(picset, picnum)
    IF state.top + i <= gen(genMaxPal) THEN pal16(i) = palette16_load(state.top + i, picset, picnum)
   NEXT i
  END IF

  '--Draw screen
  clearpage dpage
  FOR i = 0 TO 9
   textcolor uilook(uiMenuItem), 0
   IF state.top + i = state.pt THEN textcolor uilook(uiSelectedItem + state.tog), 0
   SELECT CASE state.top + i
    CASE IS >= 0
     o = LEN(" " & (state.top + i)) * 8
     IF state.top + i = state.pt THEN
      edgebox o - 1, 1 + i * 20, 114, 18, uilook(uiBackground), uilook(uiMenuitem), dpage
     END IF
     FOR j = 0 TO 15
      IF pal16(i) THEN
       c = pal16(i)->col(j)
       rectangle o + j * 7, 2 + i * 20, 5, 16, c, dpage
      END IF
     NEXT j
     IF state.top + i <> state.pt THEN
      IF pal16(i) THEN
       WITH sprite_sizes(picset)
        FOR k = 0 TO .frames - 1
         frame_draw sprite(i) + k, pal16(i), o + 140 + (k * .size.x), i * 20 - (.size.y \ 2 - 10), 1, YES, dpage
        NEXT k
       END WITH
      END IF
     END IF
     printstr "" & (state.top + i), 4, 5 + i * 20, dpage
    CASE ELSE
     printstr "Cancel", 4, 5 + i * 20, dpage
   END SELECT
  NEXT i
  IF state.pt >= 0 THEN '--write current pic on top
   i = state.pt - state.top
   o = LEN(" " & state.pt) * 8
   IF pal16(i) THEN
    WITH sprite_sizes(picset)
     FOR k = 0 TO .frames - 1
      frame_draw sprite(i) + k, pal16(i), o + 130 + (k * .size.x), i * 20 - (.size.y \ 2 - 10), 1, YES, dpage
     NEXT k
    END WITH
   END IF
  END IF
 
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 FOR i = 0 TO 9
  frame_unload @sprite(i)
  palette16_unload @pal16(i)
 NEXT
 RETURN curpal
END FUNCTION

FUNCTION step_estimate(freq AS INTEGER, low AS INTEGER, high AS INTEGER, infix AS STRING="-", suffix AS STRING= "", zero AS STRING="never") AS STRING
 IF freq = 0 THEN RETURN zero
 DIM low_est  AS INTEGER = INT(low / freq)
 DIM high_est AS INTEGER = INT(high / freq)
 RETURN low_est & infix & high_est & suffix
END FUNCTION

FUNCTION speed_estimate(speed AS INTEGER, suffix AS STRING=" seconds", zero AS STRING="infinity") AS STRING
 IF speed = 0 THEN RETURN zero
 DIM ticks AS INTEGER = INT(1000 / speed)
 DIM result AS STRING
 result = STR(INT(ticks * 10 \ 18) / 10)
 'Special case for dumb floating point math freak-outs
 WHILE INSTR(result, ".") AND RIGHT(result, 2) = "99"
  result = LEFT(result, LEN(result) - 1)
 WEND
 RETURN result & suffix
END FUNCTION

FUNCTION seconds_estimate(ticks AS INTEGER) AS STRING
 IF ticks = 0 THEN RETURN "0.0"
 DIM sec AS DOUBLE
 sec = ticks * (1 / 18.2)
 DIM s AS STRING = STR(sec)
 DIM dot AS INTEGER = INSTR(s, ".")
 DIM prefix AS STRING = LEFT(s, dot - 1)
 DIM suffix AS STRING = MID(s, dot + 1, 2)
 WHILE LEN(suffix) > 1 ANDALSO RIGHT(suffix, 1) = "0"
  suffix = LEFT(suffix, LEN(suffix) - 1)
 WEND
 RETURN prefix & "." & suffix
END FUNCTION

SUB load_text_box_portrait (BYREF box AS TextBox, BYREF gfx AS GraphicPair)
 'WARNING: There is another version of this in yetmore.bas
 'If you update this here, make sure to update that one too!
 DIM img_id AS INTEGER = -1
 DIM pal_id AS INTEGER = -1
 DIM her AS HeroDef
 WITH gfx
  IF .sprite THEN frame_unload @.sprite
  IF .pal    THEN palette16_unload @.pal
  SELECT CASE box.portrait_type
   CASE 1' Fixed ID number
    img_id = box.portrait_id
    pal_id = box.portrait_pal
   CASE 2' Hero by caterpillar
    'In custom, no party exists, so preview using the first hero
    loadherodata @her, 0
    img_id = her.portrait
    pal_id = her.portrait_pal
   CASE 3' Hero by party slot
    'In custom, no party exists, so preview using the first hero
    loadherodata @her, 0
    img_id = her.portrait
    pal_id = her.portrait_pal
  END SELECT
  IF img_id >= 0 THEN
   .sprite = frame_load(8, img_id)
   .pal    = palette16_load(pal_id, 8, img_id)
  END IF
 END WITH
END SUB

FUNCTION askwhatmetadata (metadata() AS INTEGER, metadatalabels() AS STRING) AS INTEGER
 DIM tog AS INTEGER
 
 DIM state AS MenuState
 state.size = UBOUND(metadata) + 1
 state.first = -1
 state.last = UBOUND(metadata)
 state.top = -1
 state.pt = -1
 
 setkeys
 DO
  setwait 55
  setkeys
  usemenu state
  tog = tog XOR 1
  IF keyval(scESC) > 1 THEN RETURN NO
  IF keyval(scF1) > 1 THEN show_help "textbox_export_askwhatmetadata"
  
  IF enter_or_space() THEN
   IF state.pt = -1 THEN RETURN YES
   IF metadata(state.pt) = NO THEN metadata(state.pt) = YES ELSE metadata(state.pt) = NO
  END IF
  
  clearpage dpage
  textcolor uilook(uiText), 0
  printstr "Choose what metadata to include:", 4, 4, dpage
  
  IF state.pt <> -1 THEN textcolor uilook(uiText), 0 ELSE textcolor uilook(uiSelectedItem + tog), 1
  printstr "Done", 4, 4 + 9, dpage
  FOR i AS INTEGER = 0 TO UBOUND(metadatalabels)
   IF state.pt = i THEN
    IF metadata(i) = YES THEN textcolor uilook(uiSelectedItem + tog), 1 ELSE textcolor uilook(uiSelectedDisabled), 1
   ELSE
    IF metadata(i) = YES THEN textcolor uilook(uiText), 0 ELSE textcolor uilook(uiDisabledItem), 0
   END IF
   printstr metadatalabels(i), 4, 4 + 18 + i * 9, dpage
  NEXT
  
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END FUNCTION

FUNCTION export_textboxes (filename AS STRING, metadata() AS INTEGER) AS INTEGER
 DIM fh AS INTEGER = FREEFILE
 IF OPEN(filename FOR OUTPUT AS #fh) THEN debug "export_textboxes: Failed to open " & filename : RETURN NO
 DIM box AS TextBox
 DIM blank AS INTEGER
 DIM AS INTEGER i, j, k
 FOR i = 0 TO gen(genMaxTextBox)
  LoadTextBox box, i
  '--Write the header guide
  PRINT #fh, "======================================"
  '--Write the box number and metadata
  PRINT #fh, "Box " & i
    
  IF metadata(1) THEN '--box conditionals
   IF box.instead_tag <> 0 THEN
    PRINT #fh, "Instead Tag: " & box.instead_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.instead_tag, , "Never")) & ")"
    PRINT #fh, "Instead Box: " & box.instead;
    IF box.instead < 0 THEN
     PRINT #fh, " (Plotscript " & scriptname$(box.instead * -1, plottrigger) & ")"
    ELSE
     PRINT #fh, " (Textbox)"
    END IF
   END IF
   IF box.after_tag <> 0 THEN
    PRINT #fh, "Next Tag: " & box.after_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.after_tag, , "Never")) & ")"
    PRINT #fh, "Next Box: " & box.after;
    IF box.after < 0 THEN
     PRINT #fh, " (Plotscript " & scriptname$(box.after * -1, plottrigger) & ")"
    ELSE
     PRINT #fh, " (Textbox)"
    END IF
   END IF
   
   IF box.settag_tag <> 0 THEN
    PRINT #fh, "Set Tag: " & box.settag_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.settag_tag, , "Never")) & ")"
    IF box.settag1 <> 0 THEN PRINT #fh, "Set Tag 1: " & box.settag1 & " (" & escape_nonprintable_ascii(tag_set_caption(box.settag1)) & ")"
    IF box.settag2 <> 0 THEN PRINT #fh, "Set Tag 2: " & box.settag2 & " (" & escape_nonprintable_ascii(tag_set_caption(box.settag2)) & ")"
   END IF
   IF box.battle_tag <> 0 THEN
    PRINT #fh, "Battle Tag: " & box.battle_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.battle_tag, , "Never")) & ")"
    PRINT #fh, "Battle: " & box.battle
   END IF
   IF box.shop_tag <> 0 THEN
    PRINT #fh, "Shop Tag: " & box.shop_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.shop_tag, , "Never")) & ")"
    PRINT #fh, "Shop: " & box.shop;
    IF box.shop = 0 THEN PRINT #fh, " (Restore HP/MP)"
    IF box.shop < 0 THEN PRINT #fh, " (Inn for $" & (box.shop * -1) & ")"
    IF box.shop > 0 THEN PRINT #fh, " (" & escape_nonprintable_ascii(readshopname$(box.shop - 1)) & ")"
   END IF
   IF box.hero_tag <> 0 THEN
    PRINT #fh, "Hero Tag: " & box.hero_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.hero_tag, , "Never")) & ")"
    
    IF box.hero_addrem <> 0 THEN
     PRINT #fh, "Hero Add: " & box.hero_addrem;
     IF box.hero_addrem < 0 THEN
      PRINT #fh, " (Remove " & escape_nonprintable_ascii(getheroname((box.hero_addrem * -1) - 1)) & ")"
     ELSE
      PRINT #fh, " (Add " & escape_nonprintable_ascii(getheroname(box.hero_addrem - 1)) & ")"
     END IF
    END IF
    
    IF box.hero_swap <> 0 THEN
     PRINT #fh, "Hero Swap: " & box.hero_swap;
     IF box.hero_swap < 0 THEN
      PRINT #fh, " (Swap Out " & escape_nonprintable_ascii(getheroname((box.hero_swap * -1) - 1)) & ")"
     ELSE
      PRINT #fh, " (Swap In " & escape_nonprintable_ascii(getheroname(box.hero_swap - 1)) & ")"
     END IF
    END IF
    
    IF box.hero_lock <> 0 THEN
     PRINT #fh, "Hero Lock: " & box.hero_lock;
     IF box.hero_lock < 0 THEN
      PRINT #fh, " (Lock " & escape_nonprintable_ascii(getheroname((box.hero_lock * -1) - 1)) & ")"
     ELSE
      PRINT #fh, " (Unlock " & escape_nonprintable_ascii(getheroname(box.hero_lock - 1)) & ")"
     END IF
    END IF
    
   END IF
   
   IF box.money_tag <> 0 THEN
    PRINT #fh, "Money Tag: " & box.money_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.money_tag, , "Never")) & ")"
    PRINT #fh, "Money: " & box.money
   END IF
   
   IF box.door_tag <> 0 THEN
    PRINT #fh, "Door Tag: " & box.door_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.door_tag, , "Never")) & ")"
    PRINT #fh, "Door: " & box.door
   END IF
   
   IF box.item_tag <> 0 THEN
    PRINT #fh, "Item Tag: " & box.item_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.item_tag, , "Never")) & ")"
    PRINT #fh, "Item: " & box.item;
    IF box.item < 0 THEN
     PRINT #fh, " (Remove " & escape_nonprintable_ascii(readitemname$((box.item * -1) - 1)) & ")"
    ELSE
     PRINT #fh, " (Add " & escape_nonprintable_ascii(readitemname$(box.item - 1)) & ")"
    END IF
   END IF
  END IF
  
  IF box.menu_tag <> 0 THEN
    PRINT #fh, "Menu Tag: " & box.menu_tag & " (" & escape_nonprintable_ascii(tag_condition_caption(box.menu_tag, , "Never")) & ")"
    PRINT #fh, "Menu: " & box.menu
   END IF
   
  IF metadata(2) THEN '--choices
   IF box.choice_enabled THEN
    PRINT #fh, "Choice Enabled: YES"
    PRINT #fh, "Choice 1: " & escape_nonprintable_ascii(box.choice(0))
    PRINT #fh, "Choice 1 " & escape_nonprintable_ascii(tag_set_caption(box.choice_tag(0)))
    PRINT #fh, "Choice 2: " & escape_nonprintable_ascii(box.choice(1))
    PRINT #fh, "Choice 2 " & escape_nonprintable_ascii(tag_set_caption(box.choice_tag(1)))
    
   END IF
  END IF
  
  IF metadata(3) THEN '--box appearance
   IF box.shrink = -1 THEN
    PRINT #fh, "Size: auto"
   ELSE
    PRINT #fh, "Size: " & (21 - box.shrink)
   END IF
   PRINT #fh, "Position: " & box.vertical_offset
   PRINT #fh, "Text Color: " & box.textcolor '--AARGH.
   PRINT #fh, "Border Color: " & box.boxstyle '--AARGH AGAIN.
   PRINT #fh, "Backdrop: " & box.backdrop
   IF box.music > 0 THEN
    PRINT #fh, "Music: " & box.music & " (" & escape_nonprintable_ascii(getsongname(box.music - 1)) & ")"
   ELSE
    PRINT #fh, "Music: " & box.music & " (None)"
   END IF
   PRINT #fh, "Restore Music: " & yesorno(box.restore_music)
   IF box.sound_effect > 0 THEN
    PRINT #fh, "Sound Effect: " & box.sound_effect & " (" & escape_nonprintable_ascii(getsfxname(box.sound_effect - 1)) & ")"
   ELSE
    PRINT #fh, "Sound Effect: " & box.sound_effect & " (None)"
   END IF
   PRINT #fh, "Stop Sound After Box: " & yesorno(box.stop_sound_after)
   PRINT #fh, "Show Box: " & yesorno(NOT box.no_box) '--argh, double negatives
   PRINT #fh, "Translucent: " & yesorno(NOT box.opaque) '--  "       "      "
   
   IF box.portrait_box <> NO OR box.portrait_type <> 0 THEN
    PRINT #fh, "Portrait Box: " & yesorno(box.portrait_box)
   END IF
   IF box.portrait_type <> 0 THEN
    PRINT #fh, "Portrait Type: " & box.portrait_type
    PRINT #fh, "Portrait ID: " & box.portrait_id
    IF box.portrait_pal <> -1 THEN PRINT #fh, "Portrait Palette: " & box.portrait_pal
    PRINT #fh, "Portrait X: " & box.portrait_pos.X
    PRINT #fh, "Portrait Y: " & box.portrait_pos.Y
   END IF
  END IF
  
  
  
  IF metadata(0) THEN '--box text
   '--Write the separator
   PRINT #fh, "--------------------------------------"
   blank = 0
   FOR j = 0 TO 7
    IF box.text(j) = "" THEN
     blank += 1
    ELSE
     FOR k = 1 TO blank
      PRINT #fh, ""
     NEXT k
     blank = 0
     PRINT #fh, escape_nonprintable_ascii(box.text(j))
    END IF
   NEXT j
  END IF
 NEXT i
 CLOSE #fh
 RETURN YES
END FUNCTION

SUB import_textboxes_warn (BYREF warn AS STRING, s AS STRING)
 debug "import_textboxes: " & s
 IF warn <> "" THEN warn = warn & " "
 warn = warn & s
END SUB

FUNCTION import_textboxes (filename AS STRING, BYREF warn AS STRING) AS INTEGER
 DIM fh AS INTEGER = FREEFILE
 IF OPEN(filename FOR INPUT AS #fh) THEN
  import_textboxes_warn warn, "Failed to open """ & filename & """."
  RETURN NO
 END IF
 DIM warn_length AS INTEGER = 0
 DIM warn_skip AS INTEGER = 0
 DIM warn_append AS INTEGER = 0
 DIM box AS TextBox
 DIM index AS INTEGER = 0
 DIM getindex AS INTEGER = 0 
 DIM mode AS INTEGER = 0
 DIM s AS STRING
 DIM firstline AS INTEGER = YES
 DIM line_number AS INTEGER = 0
 DIM boxlines AS INTEGER = 0
 DIM i AS INTEGER
 DO WHILE NOT EOF(fh)
  line_number += 1
  LINE INPUT #1, s
  s = decode_backslash_codes(s)
  IF firstline THEN
   IF RTRIM(s) <> STRING(38, "=") THEN
    import_textboxes_warn warn, filename & " is not a valid text box file. Expected header row, found """ & s & """."
    CLOSE #fh
    RETURN NO
   END IF
   firstline = NO
   CONTINUE DO
  END IF
  SELECT CASE mode
   CASE 0 '--Seek box number
    IF LEFT(s, 4) = "Box " THEN
     getindex = VALINT(MID(s, 5))
     IF getindex > index THEN
      warn_skip += 1
      debug "import_textboxes: line " & line_number & ": box ID " & index & " is not in the txt file"
     END IF
     IF getindex < index THEN
      debug "import_textboxes: line " & line_number & ": box ID numbers out-of-order. Expected " & index & ", but found " & getindex
     END IF
     index = getindex
     LoadTextBox box, index
     boxlines = 0
     mode = 1
    ELSE
     import_textboxes_warn warn, "line " & line_number & ": expected Box # but found """ & s & """."
     CLOSE #fh
     RETURN NO
    END IF
   CASE 1 '--Seek divider
    IF RTRIM(s) = STRING(38, "-") THEN
     mode = 2
    ELSEIF RTRIM(s) = STRING(38, "=") THEN '--no text
     IF index > gen(genMaxTextbox) THEN
      warn_append += index - gen(genMaxTextbox)
      gen(genMaxTextbox) = index
     END IF
     SaveTextBox box, index
     index += 1
     mode = 0
     boxlines = 0
    ELSE
     IF INSTR(s, ":") THEN '--metadata, probably
      dim t as string, v as string
      t = LCASE(LEFT(s, instr(s, ":") - 1))
      v = TRIM(MID(s, instr(s, ":") + 1))
      SELECT CASE t
       CASE "size"
        IF LCASE(v) = "auto" THEN
         box.shrink = -1
        ELSEIF VALINT(v) > 21 THEN
         debug "Box size too large, capping"
         box.shrink = 0
        ELSE
         box.shrink = 21 - VALINT(v)
        END IF
       CASE "portrait box"
        box.portrait_box = str2bool(v, NO)
       CASE "portrait type"
        box.portrait_type = VALINT(v)
       CASE "portrait id"
        box.portrait_id = VALINT(v)
       CASE "portrait x"
        box.portrait_pos.x = VALINT(v)
       CASE "portrait y"
        box.portrait_pos.y = VALINT(v)
       CASE "portrait palette"
        box.portrait_pal = VALINT(v)
       CASE "instead tag"
        box.instead_tag = VALINT(v)
       CASE "instead box"
        box.instead = VALINT(v)
       CASE "set tag"
        box.settag_tag = VALINT(v)
       CASE "set tag 1"
        box.settag1 = VALINT(v)
       CASE "set tag 2"
        box.settag2 = VALINT(v)
       CASE "battle tag"
        box.battle_tag = VALINT(v)
       CASE "battle"
        box.battle = VALINT(v)
       CASE "shop tag"
        box.shop_tag = VALINT(v)
       CASE "shop"
        box.shop = VALINT(v)
       CASE "item tag"
        box.item_tag = VALINT(v)
       CASE "item"
        box.item = VALINT(v)
       CASE "money tag"
        box.money_tag = VALINT(v)
       CASE "money"
        box.money = VALINT(v)
       CASE "door tag"
        box.door_tag = VALINT(v)
       CASE "door"
        box.door = VALINT(v)
       CASE "hero tag"
        box.hero_tag = VALINT(v)
       CASE "hero add"
        box.hero_addrem = VALINT(v)
       CASE "hero swap"
        box.hero_swap = VALINT(v)
       CASE "hero lock"
        box.hero_lock = VALINT(v)
       CASE "menu tag"
        box.menu_tag = VALINT(v)
       CASE "menu"
        box.menu = VALINT(v)
       CASE "next tag"
        box.after_tag = VALINT(v)
       CASE "next box"
        box.after = VALINT(v)
       CASE "choice enabled"
        box.choice_enabled = str2bool(v)
       CASE "choice 1"
        box.choice(0) = TRIM(v)
       CASE "choice 2"
        box.choice(1) = TRIM(v)
       CASE "choice 1 tag"
        box.choice_tag(0) = VALINT(v)
       CASE "choice 2 tag"
        box.choice_tag(1) = VALINT(v)
       CASE "position"
        box.vertical_offset = VALINT(v)
       CASE "text color"
        box.textcolor = VALINT(v)
       CASE "border color"
        box.boxstyle = VALINT(v)
       CASE "backdrop"
        box.backdrop = VALINT(v)
       CASE "music"
        box.music = VALINT(v)
       CASE "restore music"
        box.restore_music = str2bool(v)
       CASE "sound effect"
        box.sound_effect = VALINT(v)
       CASE "stop sound after box"
        box.stop_sound_after = str2bool(v)
       CASE "show box"
        box.no_box = str2bool(v,,YES)
       CASE "translucent"
        box.opaque = str2bool(v,,YES)
        
       CASE ELSE
        import_textboxes_warn warn, "line " & line_number & ": expected divider line but found """ & s & """."
        CLOSE #fh
        RETURN NO
      END SELECT
     END IF
    END IF
   CASE 2 '--Text lines
    IF RTRIM(s) = STRING(38, "=") THEN
     FOR i = boxlines TO 7
      box.text(i) = ""
     NEXT i
     IF index > gen(genMaxTextbox) THEN
      warn_append += index - gen(genMaxTextbox)
      gen(genMaxTextbox) = index
     END IF
     SaveTextBox box, index
     index += 1
     boxlines = 0
     mode = 0
    ELSE
     IF boxlines >= 8 THEN
      import_textboxes_warn warn, "line " & line_number & ": too many lines in box " & index & ". Overflowed with """ & s & """."
      CLOSE #fh
      RETURN NO
     END IF
     IF LEN(s) > 38 THEN '--this should be down here
      warn_length += 1
      debug "import_textboxes: line " & line_number & ": line too long (" & LEN(s) & ")"
      s = LEFT(s, 38)
     END IF
     box.text(boxlines) = s
     boxlines += 1
    END IF
  END SELECT
 LOOP
 IF mode = 2 THEN'--Save the last box
  FOR i = boxlines TO 7
   box.text(i) = ""
  NEXT i
  IF index > gen(genMaxTextbox) THEN
   warn_append += index - gen(genMaxTextbox)
   gen(genMaxTextbox) = index
  END IF
  SaveTextBox box, index
 ELSEIF mode = 0 THEN '--this... is not good
  import_textboxes_warn warn, "line " & line_number & ": txt file ended unexpectedly."
  CLOSE #fh
  RETURN NO
 END IF
 IF warn_length > 0 THEN import_textboxes_warn warn, warn_length & " lines were too long."
 IF warn_skip > 0   THEN import_textboxes_warn warn, warn_skip & " box ID numbers were not in the txt file."
 IF warn_append > 0 THEN import_textboxes_warn warn, warn_append & " new boxes were appended."
 CLOSE #fh
 RETURN YES
END FUNCTION

FUNCTION str2bool(q AS STRING, default AS INTEGER = NO, invert AS INTEGER = NO) AS INTEGER
 IF LCASE(LEFT(TRIM(q), 3)) = "yes" THEN
  IF invert THEN RETURN NO ELSE RETURN YES
 END IF
 IF LCASE(LEFT(TRIM(q), 2)) = "no" THEN
  IF invert THEN RETURN YES ELSE RETURN NO
 END IF
 RETURN default
END FUNCTION

SUB xy_position_on_slice (sl AS Slice Ptr, BYREF x AS INTEGER, BYREF y AS INTEGER, caption AS STRING, helpkey AS STRING)
 DIM col AS INTEGER
 DIM tog AS INTEGER
 DIM root AS Slice Ptr
 
 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1

  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help helpkey
  IF enter_or_space() THEN EXIT DO
  IF keyval(scLeft) > 0  THEN x -= 1
  IF keyval(scRight) > 0 THEN x += 1
  IF keyval(scUp) > 0    THEN y -= 1
  IF keyval(scDown) > 0  THEN y += 1

  clearpage dpage
  DrawSlice sl, dpage
  col = uilook(uiBackground)
  IF tog = 0 THEN col = uilook(uiSelectedItem)
  rectangle sl->ScreenX + x - 2, sl->ScreenY + y, 2, 2, col, dpage
  rectangle sl->ScreenX + x + 2, sl->ScreenY + y, 2, 2, col, dpage
  rectangle sl->ScreenX + x, sl->ScreenY + y - 2, 2, 2, col, dpage
  rectangle sl->ScreenX + x, sl->ScreenY + y + 2, 2, 2, col, dpage

  edgeprint caption, xstring(caption, 160), 0, uilook(uiText), dpage
  edgeprint "Position point and press Enter or SPACE", 0, 190, uilook(uiText), dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END SUB

SUB xy_position_on_sprite (spr AS GraphicPair, BYREF x AS INTEGER, BYREF y AS INTEGER, BYVAL frame AS INTEGER, BYVAL wide AS INTEGER, byval high AS INTEGER, caption AS STRING, helpkey AS STRING)
 DIM col AS INTEGER
 DIM tog AS INTEGER
 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1

  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help helpkey
  IF enter_or_space() THEN EXIT DO
  IF keyval(scLeft) > 0  THEN x -= 1
  IF keyval(scRight) > 0 THEN x += 1
  IF keyval(scUp) > 0    THEN y -= 1
  IF keyval(scDown) > 0  THEN y += 1

  clearpage dpage
  drawbox 160 - wide, 100 - high, wide * 2, high * 2, uilook(uiSelectedDisabled), 1, dpage
  frame_draw spr.sprite + frame, spr.pal, 160 - wide, 100 - high, 2,, dpage
  col = uilook(uiBackground)
  IF tog = 0 THEN col = uilook(uiSelectedItem)
  rectangle 160 - wide + x * 2 - 2, 100 - high + y * 2, 2, 2, col, dpage
  rectangle 160 - wide + x * 2 + 2, 100 - high + y * 2, 2, 2, col, dpage
  rectangle 160 - wide + x * 2, 100 - high + y * 2 - 2, 2, 2, col, dpage
  rectangle 160 - wide + x * 2, 100 - high + y * 2 + 2, 2, 2, col, dpage

  edgeprint caption, xstring(caption, 160), 0, uilook(uiText), dpage
  edgeprint "Position point and press Enter or SPACE", 0, 190, uilook(uiText), dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END SUB

SUB edit_menu_bits (menu AS MenuDef)
 DIM bitname(8) AS STRING
 DIM bits(0) AS INTEGER
 
 bitname(0) = "Translucent box"
 bitname(1) = "Never show scrollbar"
 bitname(2) = "Allow gameplay & scripts"
 bitname(3) = "Suspend player even if gameplay allowed"
 bitname(4) = "No box"
 bitname(5) = "Disable cancel button"
 bitname(6) = "No player control of menu"
 bitname(7) = "Prevent main menu activation"
 bitname(8) = "Advance text box when menu closes"

 MenuBitsToArray menu, bits()
 editbitset bits(), 0, UBOUND(bitname), bitname(), "menu_editor_bitsets"
 MenuBitsFromArray menu, bits()  
END SUB

SUB edit_menu_item_bits (mi AS MenuDefItem)
 DIM bitname(2) AS STRING
 DIM bits(0) AS INTEGER
 
 bitname(0) = "Hide if disabled"
 bitname(1) = "Close menu if selected"
 bitname(2) = "Don't run on-close script"

 MenuItemBitsToArray mi, bits()
 editbitset bits(), 0, UBOUND(bitname), bitname(), "menu_editor_item_bitsets"
 MenuItemBitsFromArray mi, bits()  
END SUB

SUB reposition_menu (menu AS MenuDef, mstate AS MenuState)
 DIM shift AS INTEGER

 setkeys
 DO
  setwait 55
  setkeys
 
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "reposition_menu"
  
  shift = ABS(keyval(scLeftShift) > 0 OR keyval(scRightShift) > 0)
  WITH menu.offset
   IF keyval(scUp) > 1 THEN .y -= 1 + 9 * shift
   IF keyval(scDown) > 1 THEN .y += 1 + 9 * shift
   IF keyval(scLeft) > 1 THEN .x -= 1 + 9 * shift
   IF keyval(scRight) > 1 THEN .x += 1 + 9 * shift
  END WITH
 
  clearpage dpage
  draw_menu menu, mstate, dpage
  edgeprint "Offset=" & menu.offset.x & "," & menu.offset.y, 0, 0, uilook(uiDisabledItem), dpage
  edgeprint "Arrows to re-position, ESC to exit", 0, 191, uilook(uiDisabledItem), dpage
  
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END SUB

SUB reposition_anchor (menu AS MenuDef, mstate AS MenuState)
 DIM tog AS INTEGER = 0
 DIM x AS INTEGER
 DIM y AS INTEGER
 setkeys
 DO
  setwait 55
  setkeys
  tog = tog XOR 1
 
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "reposition_anchor"
  
  WITH menu.anchor
   IF keyval(scUp) > 1 THEN .y = bound(.y - 1, -1, 1)
   IF keyval(scDown) > 1 THEN .y = bound(.y + 1, -1, 1)
   IF keyval(scLeft) > 1 THEN .x = bound(.x - 1, -1, 1)
   IF keyval(scRight) > 1 THEN .x = bound(.x + 1, -1, 1)
  END WITH
 
  clearpage dpage
  draw_menu menu, mstate, dpage
  WITH menu
   x = .rect.x - 2 + anchor_point(.anchor.x, .rect.wide)
   y = .rect.y - 2 + anchor_point(.anchor.y, .rect.high)
   rectangle x, y, 5, 5, 2 + tog, dpage 
  END WITH
  edgeprint "Arrows to re-position, ESC to exit", 0, 191, uilook(uiDisabledItem), dpage
  
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END SUB

FUNCTION base_tag_caption(byval n as integer, prefix as string, suffix as string, zerocap as string, onecap as string, negonecap as string, byval allowspecial as integer) as string
 DIM s as string
 DIM cap as string
 s = prefix
 IF LEN(s) > 0 THEN s &= " "
 s &= ABS(n) & suffix
 cap = load_tag_name(n)
 IF n = 0 AND LEN(zerocap) > 0 THEN cap = zerocap
 IF n = 1 AND LEN(onecap) > 0 THEN cap = onecap
 IF n = -1 AND LEN(negonecap) > 0 THEN cap = negonecap
 cap = TRIM(cap)
 IF allowspecial <> YES ANDALSO tag_is_autoset(n) THEN s &= " [AUTOSET]"
 IF LEN(cap) > 0 THEN s &= " (" & cap & ")"
 RETURN s
END FUNCTION

FUNCTION tag_toggle_caption(byval n as integer, prefix as string="Toggle tag", byval allowspecial as integer=NO) as string
 RETURN base_tag_caption(n, prefix, "", "N/A", "Unchangeable", "Unchangeable", allowspecial)
END FUNCTION

FUNCTION tag_set_caption(byval n as integer, prefix as string="Set Tag", byval allowspecial as integer=NO) as string
 RETURN base_tag_caption(n, prefix, "=" & onoroff(n), "No tag set", "Unchangeable", "Unchangeable", allowspecial)
END FUNCTION

FUNCTION tag_condition_caption(byval n as integer, prefix as string="Tag", zerocap as string, onecap as string="Never", negonecap as string="Always") as string
 RETURN base_tag_caption(n, prefix, "=" & onoroff(n), zerocap, onecap, negonecap, YES)
END FUNCTION

'Edit array of bits. The bits don't have to be consecutive, but they do have to be in ascending order.
'The bits corresponding to any blank entries in names() are skipped over.
SUB editbitset (array() AS INTEGER, BYVAL wof AS INTEGER, BYVAL last AS INTEGER, names() AS STRING, helpkey AS STRING="editbitset")

 '---DIM AND INIT---
 DIM state AS MenuState
 WITH state
  .pt = -1
  .top = -1
  .first = -1
  .last = last
  .size = 24
 END WITH

 DIM menu(-1 to last) AS STRING
 DIM bits(-1 to last) AS INTEGER

 menu(-1) = "Previous Menu"

 DIM nextbit AS INTEGER = 0
 FOR i AS INTEGER = 0 to last
  IF names(i) <> "" THEN
   menu(nextbit) = names(i)
   bits(nextbit) = i
   nextbit += 1
  END IF
 NEXT
 state.last = nextbit - 1

 DIM col AS INTEGER

 '---MAIN LOOP---
 setkeys
 DO
  setwait 55
  setkeys
  state.tog = state.tog XOR 1
  IF keyval(scEsc) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help helpkey
  usemenu state
  IF state.pt >= 0 THEN
   IF keyval(scLeft) > 1 OR keyval(scComma) > 1 THEN setbit array(), wof, bits(state.pt), 0
   IF keyval(scRight) > 1 OR keyval(scPeriod) > 1 THEN setbit array(), wof, bits(state.pt), 1
   IF enter_or_space() THEN setbit array(), wof, bits(state.pt), readbit(array(), wof, bits(state.pt)) XOR 1
  ELSE
   IF enter_or_space() THEN EXIT DO
  END IF
  clearpage dpage
  draw_fullscreen_scrollbar state, , dpage
  FOR i AS INTEGER = state.top TO small(state.top + state.size, state.last)
   IF i >= 0 THEN
    col = IIF(readbit(array(), wof, bits(i)), uilook(uiMenuItem), uilook(uiDisabledItem))
    IF state.pt = i THEN col = IIF(readbit(array(), wof, bits(i)), uilook(uiSelectedItem + state.tog), uilook(uiSelectedDisabled + state.tog))
   ELSE
    col = uilook(uiMenuItem)
    IF state.pt = i THEN col = uilook(uiSelectedItem + state.tog)
   END IF
   textcolor col, 0
   DIM drawstr as string = " " & menu(i)
   IF state.pt = i THEN drawstr = RIGHT(drawstr, 40)
   printstr drawstr, 0, (i - state.top) * 8, dpage
  NEXT i
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END SUB

SUB scriptbrowse (BYREF trigger AS INTEGER, BYVAL triggertype AS INTEGER, scrtype AS STRING)
 'For when you don't care about the return value of scriptbrowse_string()
 DIM s AS STRING
 s = scriptbrowse_string(trigger, triggertype, scrtype)
END SUB

FUNCTION scriptbrowse_string (BYREF trigger AS INTEGER, BYVAL triggertype AS INTEGER, scrtype AS STRING) AS STRING
 DIM localbuf(20)
 REDIM scriptnames(0) AS STRING, scriptids(0)
 DIM numberedlast AS INTEGER = 0
 DIM firstscript AS INTEGER = 0
 DIM scriptmax AS INTEGER = 0
 
 DIM chara AS INTEGER
 DIM charb AS INTEGER
 
 DIM fh AS INTEGER
 DIM i AS INTEGER
 DIM j AS INTEGER

 DIM tempstr AS STRING
 tempstr = scriptname(trigger, triggertype)
 IF tempstr <> "[none]" AND LEFT$(tempstr, 1) = "[" THEN firstscript = 2 ELSE firstscript = 1

 IF triggertype = 1 THEN
  'plotscripts
  fh = FREEFILE
  OPEN workingdir + SLASH + "plotscr.lst" FOR BINARY AS #fh
  'numberedlast = firstscript + LOF(fh) \ 40 - 1
  numberedlast = firstscript + gen(genNumPlotscripts) - 1

  REDIM scriptnames(numberedlast) AS STRING, scriptids(numberedlast)

  i = firstscript
  FOR j AS INTEGER = firstscript TO numberedlast
   loadrecord localbuf(), fh, 20
   IF localbuf(0) < 16384 THEN
    scriptids(i) = localbuf(0)
    scriptnames(i) = STR$(localbuf(0)) + " " + readbinstring(localbuf(), 1, 36)
    i += 1
   END IF
  NEXT
  numberedlast = i - 1

  CLOSE #fh
 END IF

 fh = FREEFILE
 OPEN workingdir + SLASH + "lookup" + STR$(triggertype) + ".bin" FOR BINARY AS #fh
 scriptmax = numberedlast + LOF(fh) \ 40

 IF scriptmax < firstscript THEN
  RETURN "[no scripts]"
 END IF

 ' 0 to firstscript - 1 are special options (none, current script)
 ' firstscript to numberedlast are oldstyle numbered scripts
 ' numberedlast + 1 to scriptmax are newstyle trigger scripts
 REDIM PRESERVE scriptnames(scriptmax), scriptids(scriptmax)
 scriptnames(0) = "[none]"
 scriptids(0) = 0
 IF firstscript = 2 THEN
  scriptnames(1) = tempstr
  scriptids(1) = trigger
 END IF

 i = numberedlast + 1
 FOR j AS INTEGER = numberedlast + 1 TO scriptmax
  loadrecord localbuf(), fh, 20
  IF localbuf(0) <> 0 THEN
   scriptids(i) = 16384 + j - (numberedlast + 1)
   scriptnames(i) = readbinstring(localbuf(), 1, 36)
   i += 1
  END IF
 NEXT
 scriptmax = i - 1

 CLOSE #fh

 'insertion sort numbered scripts by id
 FOR i = firstscript + 1 TO numberedlast
  FOR j AS INTEGER = i - 1 TO firstscript STEP -1
   IF scriptids(j + 1) < scriptids(j) THEN
    SWAP scriptids(j + 1), scriptids(j)
    SWAP scriptnames(j + 1), scriptnames(j)
   ELSE
    EXIT FOR
   END IF
  NEXT
 NEXT

 'sort trigger scripts by name
 FOR i = numberedlast + 1 TO scriptmax - 1
  FOR j AS INTEGER = scriptmax TO i + 1 STEP -1
   FOR k AS INTEGER = 0 TO small(LEN(scriptnames(i)), LEN(scriptnames(j)))
    chara = ASC(LCASE$(CHR$(scriptnames(i)[k])))
    charb = ASC(LCASE$(CHR$(scriptnames(j)[k])))
    IF chara < charb THEN
     EXIT FOR
    ELSEIF chara > charb THEN
     SWAP scriptids(i), scriptids(j)
     SWAP scriptnames(i), scriptnames(j)
     EXIT FOR
     END IF
   NEXT
  NEXT
 NEXT

 DIM state AS MenuState
 WITH state
  .pt = 0
  .last = scriptmax
  .size = 22
 END WITH

 IF firstscript = 2 THEN
  state.pt = 1
 ELSE
  FOR i = 1 TO scriptmax
   IF trigger = scriptids(i) THEN state.pt = i: EXIT FOR
  NEXT
 END IF
 state.top = large(0, small(state.pt - 10, scriptmax - 21))
 DIM id AS INTEGER = scriptids(state.pt)
 DIM iddisplay AS INTEGER = 0
 setkeys YES
 DO
  setwait 55
  setkeys YES
  IF keyval(scESC) > 1 THEN
   RETURN tempstr
  END IF
  IF keyval(scF1) > 1 THEN show_help "scriptbrowse"
  IF enter_or_space() THEN EXIT DO
  IF scriptids(state.pt) < 16384 THEN
   IF intgrabber(id, 0, 16383) THEN
    iddisplay = -1
    FOR i = 0 TO numberedlast
     IF id = scriptids(i) THEN state.pt = i
    NEXT
   END IF
  END IF
  IF usemenu(state) THEN
   IF scriptids(state.pt) < 16384 THEN
    id = scriptids(state.pt)
   ELSE
    id = 0
    iddisplay = 0
   END IF
  END IF
  DIM intext as string = LEFT(getinputtext, 1)
  IF LEN(intext) > 0 THEN
   DIM AS INTEGER j = state.pt + 1
   FOR ctr AS INTEGER = numberedlast + 1 TO scriptmax
    IF j > scriptmax THEN j = numberedlast + 1
    tempstr$ = LCASE(LEFT(scriptnames(j), 1))
    IF tempstr$ = intext THEN state.pt = j: EXIT FOR
    j += 1
   NEXT
  END IF

  clearpage dpage
  draw_fullscreen_scrollbar state, , dpage
  textcolor uilook(uiText), 0
  printstr "Pick a " + scrtype$, 0, 0, dpage
  standardmenu scriptnames(), state, 8, 10, dpage
  IF iddisplay THEN
   textcolor uilook(uiMenuItem), uilook(uiHighlight)
   printstr STR$(id), 8, 190, dpage
  END IF

  SWAP dpage, vpage
  setvispage vpage
  dowait
 LOOP

 trigger = scriptids(state.pt)
 IF scriptids(state.pt) < 16384 THEN
  RETURN MID(scriptnames(state.pt), INSTR(scriptnames(state.pt), " ") + 1)
 ELSE
  RETURN scriptnames(state.pt)
 END IF

END FUNCTION

FUNCTION scrintgrabber (BYREF n AS INTEGER, BYVAL min AS INTEGER, BYVAL max AS INTEGER, BYVAL less AS INTEGER=75, BYVAL more AS INTEGER=77, BYVAL scriptside AS INTEGER, BYVAL triggertype AS INTEGER) AS INTEGER
 'script side is 1 or -1: on which side of zero are the scripts
 'min or max on side of scripts is ignored

 DIM temp AS INTEGER = n
 IF scriptside < 0 THEN
  temp = -n
  SWAP less, more
  min = -min
  max = -max
  SWAP min, max
 END IF

 DIM seekdir AS INTEGER = 0
 IF keyval(more) > 1 THEN
  seekdir = 1
 ELSEIF keyval(less) > 1 THEN
  seekdir = -1
 END IF

 DIM scriptscroll AS INTEGER = NO
 IF seekdir <> 0 THEN
  scriptscroll = NO
  IF temp = min AND seekdir = -1 THEN
   temp = -1
   scriptscroll = YES
  ELSEIF (temp = 0 AND seekdir = 1) OR temp > 0 THEN
   scriptscroll = YES
  END IF
  IF scriptscroll THEN
   'scroll through scripts
   seekscript temp, seekdir, triggertype
   IF temp = -1 THEN temp = min
  ELSE
   'regular scroll
   temp += seekdir
  END IF
 ELSE
  IF (temp > 0 AND temp < 16384) OR (temp = 0 AND scriptside = 1) THEN
   'if a number is entered, don't seek to the next script, allow "[id]" to display instead
   IF intgrabber(temp, 0, 16383, 0, 0) THEN
    'if temp starts off greater than gen(genMaxRegularScript) then don't disturb it
    temp = small(temp, gen(genMaxRegularScript))
   END IF
  ELSEIF temp < 0 OR (temp = 0 AND scriptside = -1) THEN
   intgrabber(temp, min, 0, 0, 0)
  END IF
 END IF

 IF keyval(scDelete) > 1 THEN temp = 0
 IF keyval(scMinus) > 1 OR keyval(scNumpadMinus) > 1 THEN temp = bound(-temp, min, gen(genMaxRegularScript))

 temp = temp * SGN(scriptside)
 scrintgrabber = (temp <> n) ' Returns true if BYREF n has changed
 n = temp
END FUNCTION

SUB seekscript (BYREF temp AS INTEGER, BYVAL seekdir AS INTEGER, BYVAL triggertype AS INTEGER)
 'temp = -1 means scroll to last script
 'returns 0 when scrolled past first script, -1 when went past last

 DIM buf(19), plotids(gen(genMaxRegularScript))
 DIM recordsloaded AS INTEGER = 0
 DIM screxists AS INTEGER = 0

 DIM fh AS INTEGER = FREEFILE
 OPEN workingdir & SLASH & "lookup" & triggertype & ".bin" FOR BINARY AS #fh
 DIM triggernum AS INTEGER = LOF(fh) \ 40
 IF temp = -1 THEN temp = triggernum + 16384

 DO
  temp += seekdir
  IF temp > gen(genMaxRegularScript) AND temp < 16384 THEN
   IF seekdir > 0 THEN
    temp = 16384
   ELSEIF triggertype = plottrigger THEN
    temp = gen(genMaxRegularScript)
   ELSE
    temp = 0
   END IF
  END IF
  IF temp <= 0 THEN EXIT DO
  IF temp >= triggernum + 16384 THEN
   temp = -1
   EXIT DO
  END IF
  'check script exists, else keep looking
  IF temp < 16384 AND triggertype = plottrigger THEN
   IF plotids(temp) THEN
    screxists = -1
   ELSE
    WHILE recordsloaded < gen(genNumPlotscripts)
     loadrecord buf(), workingdir + SLASH + "plotscr.lst", 20, recordsloaded
     recordsloaded += 1
     IF buf(0) = temp THEN screxists = -1: EXIT WHILE
     IF buf(0) <= gen(genMaxRegularScript) THEN plotids(buf(0)) = -1
    WEND
   END IF
  END IF
  IF temp >= 16384 THEN
   loadrecord buf(), fh, 20, temp - 16384
   IF buf(0) THEN screxists = -1
  END IF
  IF screxists THEN EXIT DO
 LOOP

 CLOSE fh
END SUB

'--For each script trigger datum in the game, call visitor (whether or not there
'--is a script set there; however fields which specify either a script or
'--something else, eg. either a script or a textbox, may be skipped)
SUB visit_scripts(byval visitor as FnScriptVisitor)
 DIM AS INTEGER i, j, idtmp, resave

 '--global scripts
 visitor(gen(genNewGameScript), "new game", "")
 visitor(gen(genLoadGameScript), "load game", "")
 visitor(gen(genGameoverScript), "game over", "")

 '--Text box scripts
 DIM box AS TextBox
 FOR i AS INTEGER = 0 TO gen(genMaxTextbox)
  LoadTextBox box, i
  resave = NO
  IF box.instead < 0 THEN
   idtmp = -box.instead
   resave OR= visitor(idtmp, "box " & i & " (instead)", textbox_preview_line(box))
   box.instead = -idtmp
  END IF
  IF box.after < 0 THEN
   idtmp = -box.after
   resave OR= visitor(idtmp, "box " & i & " (after)", textbox_preview_line(box))
   box.after = -idtmp
  END IF
  IF resave THEN
   SaveTextBox box, i
  END IF
 NEXT i
 
 '--Map scripts and NPC scripts
 DIM gmaptmp(dimbinsize(binMAP))
 REDIM npctmp(0) AS NPCType
 FOR i = 0 TO gen(genMaxMap)
  resave = NO
  loadrecord gmaptmp(), game & ".map", getbinsize(binMAP) \ 2, i
  resave OR= visitor(gmaptmp(7), "map " & i & " autorun", "")
  resave OR= visitor(gmaptmp(12), "map " & i & " after-battle", "")
  resave OR= visitor(gmaptmp(13), "map " & i & " instead-of-battle", "")
  resave OR= visitor(gmaptmp(14), "map " & i & " each-step", "")
  resave OR= visitor(gmaptmp(15), "map " & i & " on-keypress", "")
  IF resave THEN
   storerecord gmaptmp(), game & ".map", getbinsize(binMAP) \ 2, i
  END IF
  'loop through NPC's
  LoadNPCD maplumpname(i, "n"), npctmp()
  resave = NO
  FOR j = 0 TO UBOUND(npctmp)
   resave OR= visitor(npctmp(j).script, "map " & i & " NPC " & j, "")
  NEXT j
  IF resave THEN
   SaveNPCD maplumpname(i, "n"), npctmp()
  END IF
 NEXT i
 
 '--vehicle scripts
 DIM vehicle AS VehicleData
 FOR i = 0 TO gen(genMaxVehicle)
  resave = NO
  LoadVehicle game & ".veh", vehicle, i
  IF vehicle.use_button > 0 THEN
   resave OR= visitor(vehicle.use_button, "use button veh " & i, """" & vehicle.name & """")
  END IF
  IF vehicle.menu_button > 0 THEN
   resave OR= visitor(vehicle.menu_button, "menu button veh " & i, """" & vehicle.name & """")
  END IF
  IF vehicle.on_mount < 0 THEN
   idtmp = -(vehicle.on_mount)
   resave OR= visitor(idtmp, "mount vehicle " & i, """" & vehicle.name & """")
   vehicle.on_mount = -idtmp
  END IF
  IF vehicle.on_dismount < 0 THEN
   idtmp = -(vehicle.on_dismount)
   resave OR= visitor(idtmp, "dismount vehicle " & i,  """" & vehicle.name & """")
   vehicle.on_dismount = -idtmp
  END IF
  IF resave THEN
   SaveVehicle game & ".veh", vehicle, i
  END IF
 NEXT i
 
 '--shop scripts
 DIM shoptmp(19)
 DIM shopname AS STRING
 FOR i = 0 TO gen(genMaxShop)
  loadrecord shoptmp(), game & ".sho", 20, i
  shopname = readbadbinstring(shoptmp(), 0, 15)
  IF visitor(shoptmp(19), "show inn " & i, """" & shopname & """") THEN
   storerecord shoptmp(), game & ".sho", 20, i
  END IF
 NEXT i
 
 '--menu scripts
 DIM menu_set AS MenuSet
 menu_set.menufile = workingdir + SLASH + "menus.bin"
 menu_set.itemfile = workingdir + SLASH + "menuitem.bin"
 DIM menutmp AS MenuDef
 FOR i = 0 TO gen(genMaxMenu)
  resave = NO
  LoadMenuData menu_set, menutmp, i
  FOR j = 0 TO menutmp.numitems - 1
   WITH *menutmp.items[j]
    IF .t = 4 THEN
     resave OR= visitor(.sub_t, "menu " & i & " item " & j, """" & .caption & """")
    END IF
   END WITH
  NEXT j
  resave OR= visitor(menutmp.on_close, "menu " & i & " on-close", """" & menutmp.name & """")
  IF resave THEN
   SaveMenuData menu_set, menutmp, i
  END IF
  ClearMenuData menutmp
 NEXT i

END SUB

'For script_usage_list and script_usage_visitor
DIM SHARED plotscript_order() AS INTEGER
DIM SHARED script_usage_menu() AS IntStrPair

PRIVATE FUNCTION script_usage_visitor(byref trig as integer, description as string, caption as string) as integer
 IF trig = 0 THEN RETURN NO
 '--See script_usage_list about rank calculation
 DIM rank AS INTEGER = trig
 IF trig >= 16384 THEN rank = 100000 + plotscript_order(trig - 16384)
 intstr_array_append script_usage_menu(), rank, "  " & description & " " & caption
 RETURN NO  'trig not modified
END FUNCTION

SUB script_usage_list ()
 DIM buf(20) AS INTEGER
 DIM id AS INTEGER
 DIM s AS STRING
 DIM fh AS INTEGER
 DIM i AS INTEGER
 'DIM t AS DOUBLE = TIMER

 'Build script_usage_menu, which is an list of menu items, initially out of order.
 'The integer in each pair is used to sort the menu items into the right order:
 'items for old-style scripts have rank = id
 'all plotscripts are ordered by name and given rank = 100000 + alphabetic rank
 'Start by adding all the script names to script_usage_menu (so that they'll
 'appear first when we do a stable sort), then add script instances.

 REDIM script_usage_menu(0)
 script_usage_menu(0).i = -1
 script_usage_menu(0).s = "back to previous menu..."

 'Loop through old-style non-autonumbered scripts
 fh = FREEFILE
 OPEN workingdir & SLASH & "plotscr.lst" FOR BINARY AS #fh
 FOR i AS INTEGER = 0 TO gen(genNumPlotscripts) - 1
  loadrecord buf(), fh, 20, i
  id = buf(0)
  IF id <= 16383 THEN
   s = id & ":" & readbinstring(buf(), 1, 38)
   intstr_array_append script_usage_menu(), id, s
  END IF
 NEXT i
 CLOSE #fh

 'Loop through new-style plotscripts

 'First, a detour: determine the alphabetic rank of each plotscript
 fh = FREEFILE
 OPEN workingdir & SLASH & "lookup1.bin" FOR BINARY AS #fh
 REDIM plotscripts(0) AS STRING
 WHILE loadrecord(buf(), fh, 20)
  s = readbinstring(buf(), 1, 38)
  str_array_append plotscripts(), s
 WEND

 'Have to skip if no plotscripts
 IF UBOUND(plotscripts) > 0 THEN
  'We must skip plotscripts(0)
  REDIM plotscript_order(UBOUND(plotscripts) - 1)
  qsort_strings_indices plotscript_order(), @plotscripts(1), UBOUND(plotscripts), sizeof(string)
  invert_permutation plotscript_order()

  'OK, now that we can calculate ranks, we can add new-style scripts
  SEEK #fh, 1
  i = 0
  WHILE loadrecord(buf(), fh, 20)
   id = buf(0)
   IF id <> 0 THEN
    s = readbinstring(buf(), 1, 38)
    intstr_array_append script_usage_menu(), 100000 + plotscript_order(i), s
   END IF
   i += 1
  WEND 
 END IF
 CLOSE #fh

 'add script instances to script_usage_menu
 visit_scripts @script_usage_visitor

 'sort, and build menu() (for standardmenu)
 DIM indices(UBOUND(script_usage_menu)) AS INTEGER
 REDIM menu(UBOUND(script_usage_menu)) AS STRING
 sort_integers_indices indices(), @script_usage_menu(0).i, UBOUND(script_usage_menu) + 1, sizeof(IntStrPair)

 DIM currentscript AS INTEGER = -1
 DIM j AS INTEGER = 0
 FOR i AS INTEGER = 0 TO UBOUND(script_usage_menu)
  WITH script_usage_menu(indices(i))
   IF MID(.s, 1, 1) = " " THEN
    'script trigger
    'Do not add triggers which are missing their scripts; those go in the other menu
    IF .i <> currentscript THEN CONTINUE FOR
   END IF
   menu(j) = .s
   j += 1
   currentscript = .i
  END WITH
 NEXT
 REDIM PRESERVE menu(j - 1)

 'Free memory
 REDIM plotscript_order(0)
 REDIM script_usage_menu(0)

 'debug "script usage in " & ((TIMER - t) * 1000) & "ms"

 DIM state AS MenuState
 state.size = 24
 state.last = UBOUND(menu)
 
 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "script_usage_list"
  IF enter_or_space() THEN
   IF state.pt = 0 THEN EXIT DO
  END IF
  usemenu state

  clearpage dpage
  draw_fullscreen_scrollbar state, , dpage 
  standardmenu menu(), state, 0, 0, dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP 
END SUB

'--A similar function exists in yetmore2.bas for game. it differs only in error-reporting
FUNCTION decodetrigger (trigger as integer, trigtype as integer) as integer
 DIM buf(19) AS INTEGER
 DIM fname AS STRING
 IF trigger >= 16384 THEN
  fname = workingdir & SLASH & "lookup" & trigtype & ".bin"
  IF loadrecord (buf(), fname$, 20, trigger - 16384) THEN
   RETURN buf(0)
  ELSE
   debug "decodetrigger: record " & (trigger - 16384) & " could not be loaded"
  END IF
 ELSE
  '--this is an old-style script
  RETURN trigger
 END IF
END FUNCTION

'--This could be used in more places; makes sense to load plotscr.lst into a global
DIM SHARED script_ids_list() AS INTEGER

SUB load_script_ids_list()
 REDIM script_ids_list(large(0, gen(genNumPlotscripts) - 1))
 DIM buf(19) AS INTEGER
 DIM fh AS INTEGER
 fh = FREEFILE
 OPEN workingdir & SLASH & "plotscr.lst" FOR BINARY AS #fh
 FOR i AS INTEGER = 0 TO gen(genNumPlotscripts) - 1
  loadrecord buf(), fh, 20, i
  script_ids_list(i) = buf(0)
 NEXT i
 CLOSE #fh
END SUB

'--For script_broken_trigger_list and check_broken_script_trigger
DIM SHARED missing_script_trigger_list() AS STRING

PRIVATE FUNCTION check_broken_script_trigger(byref trig as integer, description as string, caption as string) as integer
 IF trig <= 0 THEN RETURN NO ' No script trigger
 '--decode script trigger
 DIM id AS INTEGER
 id = decodetrigger(trig, plottrigger)
 '--Check for missing new-style script
 IF id = 0 THEN
  str_array_append missing_script_trigger_list(), description & " " & scriptname(trig, plottrigger) & " missing. " & caption 
 ELSEIF id < 16384 THEN
  '--now check for missing old-style scripts
  IF int_array_find(script_ids_list(), id) <> -1 THEN RETURN NO 'Found okay

  str_array_append missing_script_trigger_list(), description & " ID " & id & " missing. " & caption
 END IF
 RETURN NO
END FUNCTION

SUB script_broken_trigger_list()
 'Cache plotscr.lst
 load_script_ids_list

 REDIM missing_script_trigger_list(0) AS STRING
 missing_script_trigger_list(0) = "back to previous menu..."

 visit_scripts @check_broken_script_trigger

 IF UBOUND(missing_script_trigger_list) = 0 THEN
  str_array_append missing_script_trigger_list(), "No broken triggers found!"
 END IF

 DIM state AS MenuState
 state.size = 24
 state.last = UBOUND(missing_script_trigger_list)

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "script_broken_trigger_list"
  IF enter_or_space() THEN
   IF state.pt = 0 THEN EXIT DO
  END IF
  usemenu state

  clearpage dpage
  draw_fullscreen_scrollbar state, , dpage 
  standardmenu missing_script_trigger_list(), state, 0, 0, dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP 
 'Free memory
 REDIM missing_script_trigger_list(0)
END SUB

FUNCTION autofix_old_script_visitor(byref id as integer, description as string, caption as string) as integer
 '--returns true if a fix has occured
 IF id = 0 THEN RETURN NO ' not a trigger
 IF id >= 16384 THEN RETURN NO 'New-style script
 IF int_array_find(script_ids_list(), id) <> -1 THEN RETURN NO 'Found okay

 DIM buf(19) AS INTEGER
 DIM fh AS INTEGER
  
 DIM found_name AS STRING = ""
 
 fh = FREEFILE
 OPEN tmpdir & "plotscr.lst.tmp" FOR BINARY ACCESS READ AS #fh
 FOR i AS INTEGER = 0 TO (LOF(fh) \ 40) - 1
  loadrecord buf(), fh, 20, i
  IF buf(0) = id THEN '--Yay! found it in the old file!
   found_name = readbinstring(buf(), 1, 38)
   EXIT FOR
  END IF
 NEXT i
 CLOSE #fh
 
 IF found_name = "" THEN RETURN NO '--broken but unfixable (no old name)

 fh = FREEFILE
 OPEN workingdir & SLASH & "lookup1.bin" FOR BINARY AS #fh
 FOR i AS INTEGER = 0 TO (LOF(fh) \ 40) - 1
  loadrecord buf(), fh, 20, i
  IF found_name = readbinstring(buf(), 1, 38) THEN '--Yay! found it in the new file!
   id = 16384 + i
   CLOSE #fh
   RETURN YES '--fixed it, report a change!
  END IF
 NEXT i
 CLOSE #fh 

 RETURN NO '--broken but unfixable (no matching new name)
 
END FUNCTION

SUB autofix_broken_old_scripts()
 '--sanity test
 IF NOT isfile(tmpdir & "plotscr.lst.tmp") THEN
  debug "can't autofix broken old scripts, can't find: " & tmpdir & "plotscr.lst.tmp"
  EXIT SUB
 END IF

 'Cache plotscr.lst
 load_script_ids_list()

 visit_scripts @autofix_old_script_visitor
END SUB

FUNCTION sublist (s() AS STRING, helpkey AS STRING="", BYVAL x AS INTEGER=0, BYVAL y AS INTEGER=0, BYVAL page AS INTEGER=-1) AS INTEGER
 DIM state AS MenuState
 state.pt = 0
 state.last = UBOUND(s)
 state.size = 22

 DIM holdscreen AS INTEGER
 holdscreen = allocatepage
 IF page > -1 THEN
  copypage page, holdscreen
 ELSE
  clearpage holdscreen
 END IF

 setkeys
 DO
  setwait 55
  setkeys
  usemenu state
  IF keyval(scESC) > 1 THEN
   sublist = -1
   EXIT DO
  END IF
  IF keyval(scF1) > 1 AND helpkey <> "" THEN show_help helpkey
  IF enter_or_space() THEN
   sublist = state.pt
   EXIT DO
  END IF
  copypage holdscreen, vpage
  standardmenu s(), state, x, y, vpage
  setvispage vpage
  dowait
 LOOP
END FUNCTION

'The maximum - 1 number of global text strings that can appear in the global
'text strings menu (the actual number varies)
CONST GTSnumitems = 209

TYPE GlobalTextStringsMenu
 index(-1 TO GTSnumitems) AS INTEGER
 description(-1 TO GTSnumitems) AS STRING
 shaded(-1 TO GTSnumitems) AS INTEGER
 text(-1 TO GTSnumitems) AS STRING
 maxlen(GTSnumitems) AS INTEGER
 help(GTSnumitems) AS STRING
 curitem AS INTEGER
END TYPE

PRIVATE SUB GTS_add_to_menu (menu as GlobalTextStringsMenu, description as string, BYVAL index as integer, default as string, BYVAL maxlen as integer, helpfile as string = "")
 WITH menu
  IF .curitem > GTSnumitems THEN fatalerror "GlobalTextStringsMenu.curitem too large"
  .index(.curitem) = index
  .description(.curitem) = description
  .text(.curitem) = readglobalstring(index, default, maxlen)
  .maxlen(.curitem) = maxlen
  IF LEN(helpfile) THEN .help(.curitem) = "globalstring_" + helpfile
  .curitem += 1
 END WITH
END SUB

PRIVATE SUB GTS_menu_header (menu as GlobalTextStringsMenu, description as string)
 WITH menu
  'IF .curitem > -1 THEN .curitem += 1
  IF .curitem > GTSnumitems THEN fatalerror "GlobalTextStringsMenu.curitem too large"
  .shaded(.curitem) = YES
  .description(.curitem) = description
  .curitem += 1
 END WITH
END SUB

SUB edit_global_text_strings()
 DIM search AS STRING = ""
 DIM state AS MenuState
 DIM menu as GlobalTextStringsMenu
 DIM rect AS RectType
 rect.wide = 320
 rect.high = 192

 '--load current names

 'getelementnames handles the double-defaulting of element names
 DIM elementnames() AS STRING
 getelementnames elementnames()

 FOR i AS INTEGER = -1 TO UBOUND(menu.index)
  'initialize unused menu items to -1 because if you leave them at 0
  'they collide with HP
  menu.index(i) = -1
 NEXT i

 menu.description(-1) = "Back to Previous Menu"

 GTS_menu_header menu, "Stats:"
 GTS_add_to_menu menu, "Health Points",              0, "HP", 10
 GTS_add_to_menu menu, "Spell Points",               1, "MP", 10
 GTS_add_to_menu menu, "Attack Power",               2, "Attack", 10
 GTS_add_to_menu menu, "Accuracy",                   3, "Accuracy", 10
 GTS_add_to_menu menu, "Extra Hits",                 4, "Hits", 10
 GTS_add_to_menu menu, "Blocking Power",             5, "Blocking", 10
 GTS_add_to_menu menu, "Dodge Rate",                 6, "Dodge", 10
 GTS_add_to_menu menu, "Counter Rate",               7, "Counter", 10
 GTS_add_to_menu menu, "Speed",                      8, "Speed", 10
 GTS_add_to_menu menu, "Spell Skill",                29, "SpellSkill", 10
 GTS_add_to_menu menu, "Spell Block",                30, "SpellBlock", 10
 GTS_add_to_menu menu, "Spell cost %",               31, "SpellCost%", 10

 GTS_menu_header menu, "Elements:"
 FOR i AS INTEGER = 0 TO gen(genNumElements) - 1
  GTS_add_to_menu menu, "Elemental " & i,            174 + i*2, elementnames(i), 14
 NEXT i

 GTS_menu_header menu, "Equip slots:"
 GTS_add_to_menu menu, "Weapon",                     38, "Weapon", 10
 FOR i AS INTEGER = 1 TO 4
  GTS_add_to_menu menu, "Armor " & i,                24 + i, "Armor " & i, 10
 NEXT i

 GTS_menu_header menu, "Special Menu Item Default Captions:"
 GTS_add_to_menu menu, "Items",                      60, "Items", 10
 GTS_add_to_menu menu, "Spells",                     61, "Spells", 10
 GTS_add_to_menu menu, "Status",                     62, "Status", 10
 GTS_add_to_menu menu, "Equip",                      63, "Equip", 10
 GTS_add_to_menu menu, "Order",                      64, "Order", 10
 GTS_add_to_menu menu, "Team",                       65, "Team", 10
 GTS_add_to_menu menu, "Save",                       66, "Save", 10
 GTS_add_to_menu menu, "Quit",                       67, "Quit", 10
 GTS_add_to_menu menu, "Minimap",                    68, "Map", 10
 GTS_add_to_menu menu, "Volume",                     69, "Volume", 10

 GTS_menu_header menu, "Item Menu:"
 GTS_add_to_menu menu, "Exit Item Menu",             35, "DONE", 10
 GTS_add_to_menu menu, "Sort Item Menu",             36, "AUTOSORT", 10
 GTS_add_to_menu menu, "Drop Item",                  37, "TRASH", 10
 GTS_add_to_menu menu, "Drop Prompt",                41, "Discard", 10
 GTS_add_to_menu menu, "Negative Drop Prefix",       42, "Cannot", 10

 GTS_menu_header menu, "Status Main Screen:"
 GTS_add_to_menu menu, "Level",                      43, "Level", 10
 GTS_add_to_menu menu, "Experience",                 33, "Experience", 10
 GTS_add_to_menu menu, "(exp) for next (level)",     47, "for next", 10
 GTS_add_to_menu menu, "Money",                      32, "Money", 10
 GTS_add_to_menu menu, "Level MP",                   160, "Level MP", 20

 GTS_menu_header menu, "Status Second Screen:"
 GTS_add_to_menu menu, "Elemental Effects Title",    302, "Elemental Effects:", 30
 GTS_add_to_menu menu, "No Elemental Effects",       130, "No Elemental Effects", 30
 GTS_add_to_menu menu, "Takes > 100% element dmg",   162, "Weak to $E", 25,   "elemental_resist"
 GTS_add_to_menu menu, "Takes 0 to 100% element dmg",165, "Strong to $E", 25, "elemental_resist"
 GTS_add_to_menu menu, "Takes 0% element dmg",       168, "Immune to $E", 25, "elemental_resist"
 GTS_add_to_menu menu, "Takes < 0% element dmg",     171, "Absorb $E", 25,   "elemental_resist"

 GTS_menu_header menu, "Equip Menu:"
 GTS_add_to_menu menu, "Equip Nothing (unequip)",    110, "Nothing", 10
 GTS_add_to_menu menu, "Unequip All",                39, "-REMOVE-", 8
 GTS_add_to_menu menu, "Exit Equip",                 40, "-EXIT-", 8

 GTS_menu_header menu, "Spells Menu:"
 GTS_add_to_menu menu, "(hero) has no spells",       133, "has no spells", 20
 GTS_add_to_menu menu, "Exit Spell List Menu",       46, "Exit", 10
 GTS_add_to_menu menu, "Cancel Spell Menu",          51, "(CANCEL)", 10

 GTS_menu_header menu, "Team/Order Menu:"
 GTS_add_to_menu menu, "Remove Hero from Team",      48, "REMOVE", 10

 GTS_menu_header menu, "Save/Load Menus:"
 GTS_add_to_menu menu, "New Game",                   52, "NEW GAME", 10
 GTS_add_to_menu menu, "Exit Game",                  53, "EXIT", 10
 GTS_add_to_menu menu, "Cancel Save",                59, "CANCEL", 10
 GTS_add_to_menu menu, "Replace Save Prompt",        102, "Replace Old Data?", 20
 GTS_add_to_menu menu, "Overwrite Save Yes",         44, "Yes", 10
 GTS_add_to_menu menu, "Overwrite Save No",          45, "No", 10
 GTS_add_to_menu menu, "day",                        154, "day", 10
 GTS_add_to_menu menu, "days",                       155, "days", 10
 GTS_add_to_menu menu, "hour",                       156, "hour", 10
 GTS_add_to_menu menu, "hours",                      157, "hours", 10
 GTS_add_to_menu menu, "minute",                     158, "minute", 10
 GTS_add_to_menu menu, "minutes",                    159, "minutes", 10

 GTS_menu_header menu, "Quit Playing Prompt:"
 GTS_add_to_menu menu, "Prompt",                     55, "Quit Playing?", 20
 GTS_add_to_menu menu, "Yes",                        57, "Yes", 10
 GTS_add_to_menu menu, "No",                         58, "No", 10

 GTS_menu_header menu, "Shop Menu:"
 GTS_add_to_menu menu, "Buy",                        70, "Buy", 10
 GTS_add_to_menu menu, "Sell",                       71, "Sell", 10
 GTS_add_to_menu menu, "Inn",                        72, "Inn", 10
 GTS_add_to_menu menu, "Hire",                       73, "Hire", 10
 GTS_add_to_menu menu, "Exit",                       74, "Exit", 10

 GTS_menu_header menu, "Buy/Hire Menu:"
 GTS_add_to_menu menu, "Buy trade prefix",           85, "Trade for", 20
 GTS_add_to_menu menu, "($) and a (item)",           81, "and a", 10
 GTS_add_to_menu menu, "($) and (number) (item)",    153, "and", 10
 GTS_add_to_menu menu, "Hire price prefix",          87, "Joins for", 20
 GTS_add_to_menu menu, "(#) in stock",               97, "in stock", 20
 GTS_add_to_menu menu, "Equipability prefix",        99, "Equip:", 10
 GTS_add_to_menu menu, "Cannot buy prefix",          89, "Cannot Afford", 20
 GTS_add_to_menu menu, "Cannot hire prefix",         91, "Cannot Hire", 20
 GTS_add_to_menu menu, "Party full warning",         100, "No Room In Party", 20
 GTS_add_to_menu menu, "Buy alert",                  93, "Purchased", 20
 GTS_add_to_menu menu, "Hire alert (suffix)",        95, "Joined!", 20

 GTS_menu_header menu, "Sell Menu:"
 GTS_add_to_menu menu, "Unsellable item warning",    75, "CANNOT SELL", 20
 GTS_add_to_menu menu, "Sell value prefix",          77, "Worth", 20
 GTS_add_to_menu menu, "Sell trade prefix",          79, "Trade for", 20
 GTS_add_to_menu menu, "Worthless item warning",     82, "Worth Nothing", 20
 GTS_add_to_menu menu, "Sell alert",                 84, "Sold", 10

 GTS_menu_header menu, "Inns:"
 GTS_add_to_menu menu, "THE INN COSTS (# gold)",     143, "THE INN COSTS", 20
 GTS_add_to_menu menu, "You have (# gold)",          145, "You have", 20
 GTS_add_to_menu menu, "Pay at Inn",                 49, "Pay", 10
 GTS_add_to_menu menu, "Cancel Inn",                 50, "Cancel", 10

 GTS_menu_header menu, "Battles:"
 GTS_add_to_menu menu, "Battle Item Menu",           34, "Item", 10
 GTS_add_to_menu menu, "Stole (itemname)",           117, "Stole", 30
 GTS_add_to_menu menu, "Nothing to Steal",           111, "Has Nothing", 30
 GTS_add_to_menu menu, "Steal Failure",              114, "Cannot Steal", 30
 GTS_add_to_menu menu, "When an Attack Misses",      120, "miss", 20
 GTS_add_to_menu menu, "When a Spell Fails",         122, "fail", 20
 GTS_add_to_menu menu, "CANNOT RUN!",                147, "CANNOT RUN!", 20
 GTS_add_to_menu menu, "Pause",                      54, "PAUSE", 10
 GTS_add_to_menu menu, "Gained (experience)",        126, "Gained", 10
 GTS_add_to_menu menu, "Level up for (hero)",        149, "Level up for", 20
 GTS_add_to_menu menu, "(#) levels for (hero)",      151, "levels for", 20
 GTS_add_to_menu menu, "(hero) learned (spell)",     124, "learned", 10
 GTS_add_to_menu menu, "Found a (item)",             139, "Found a", 20
 GTS_add_to_menu menu, "Found (number) (items)",     141, "Found", 20
 GTS_add_to_menu menu, "Found (gold)",               125, "Found", 10

 GTS_menu_header menu, "Misc:"
 GTS_add_to_menu menu, "Status Prompt",              104, "Who's Status?", 20
 GTS_add_to_menu menu, "Spells Prompt",              106, "Who's Spells?", 20
 GTS_add_to_menu menu, "Equip Prompt",               108, "Equip Who?", 20
 GTS_add_to_menu menu, "Plotscript: pick hero",      135, "Which Hero?", 20
 GTS_add_to_menu menu, "Hero name prompt",           137, "Name the Hero", 20

 '**** next unused index is 305

 'NOTE: if you add global strings here, be sure to update the limit-checking on
 'the implementation of the "get global string" plotscripting command

 state.top = -1
 state.pt = -1
 state.first = -1
 state.last = menu.curitem - 1
 state.size = 21
 setkeys YES
 DO
  setwait 55
  setkeys YES
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN
   IF state.pt >= 0 ANDALSO LEN(menu.help(state.pt)) THEN
    show_help menu.help(state.pt)
   ELSE
    show_help "edit_global_strings"
   END IF
  END IF
  IF keyval(scCTRL) > 0 AND keyval(scS) > 1 THEN
   IF prompt_for_string(search, "Search (descriptions & values)") THEN
    FOR i AS INTEGER = 0 TO state.last
     DIM idx AS INTEGER = (state.pt + 1 + i) MOD (state.last + 1)
     IF INSTR(LCASE(menu.text(idx)), LCASE(search)) OR INSTR(LCASE(menu.description(idx)), LCASE(search)) THEN
      state.pt = idx
      clamp_menu_state state
      EXIT FOR
     END IF
    NEXT i
   END IF
  END IF
  usemenu state
  IF state.pt = -1 THEN
   IF enter_or_space() THEN EXIT DO
  ELSEIF menu.index(state.pt) <> -1 THEN
   strgrabber menu.text(state.pt), menu.maxlen(state.pt)
  END IF
 
  clearpage dpage
  standardmenu menu.description(), state, menu.shaded(), 0, 0, dpage
  standardmenu menu.text(), state, 232, 0, dpage, , , , YES  'highlight=YES
  draw_scrollbar state, rect, , dpage
  edgeprint "CTRL+S Search", 0, 191, uilook(uiDisabledItem), dpage
  IF state.pt >= 0 ANDALSO LEN(menu.help(state.pt)) THEN
   edgeprint "Press F1 for help about this string", 0, 181, uilook(uiDisabledItem), dpage
  END IF
  IF menu.index(state.pt) >= 0 THEN
   edgeboxstyle 160 - (menu.maxlen(state.pt) * 4), 191, 8 * menu.maxlen(state.pt) + 4, 8, 0, dpage, transOpaque, YES
   edgeprint menu.text(state.pt), 162 - (menu.maxlen(state.pt) * 4), 191, uilook(uiText), dpage
  END IF
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 'Note: it is safe to write the strings to file out of order as long as we write
 'all of them. Any gaps in the file will be filled with garbage: do not leave
 'unused global string indices, or you won't be able to use them later!
 FOR i AS INTEGER = 0 TO GTSnumitems
  writeglobalstring menu.index(i), menu.text(i), menu.maxlen(i)
 NEXT i
 'Write defaults for all elements that don't appear in the menu
 FOR i AS INTEGER = gen(genNumElements) TO 63
  writeglobalstring 174 + i*2, "Element" & i+1, 14
 NEXT i

 getstatnames statnames()
END SUB

SUB writeglobalstring (index AS INTEGER, s AS STRING, maxlen AS INTEGER)
 IF index < 0 THEN EXIT SUB
 DIM fh AS INTEGER = FREEFILE
 OPEN game & ".stt" FOR BINARY AS #fh
 DIM ch AS STRING
 ch = CHR(small(LEN(s), small(maxlen, 255)))
 PUT #fh, 1 + index * 11, ch
 ch = LEFT(s, small(maxlen, 255))
 PUT #fh, 2 + index * 11, ch
 CLOSE #fh
 loadglobalstrings
END SUB

FUNCTION safe_caption(caption_array() AS STRING, BYVAL index AS INTEGER, description AS STRING) AS STRING
 IF index >= LBOUND(caption_array) AND index <= UBOUND(caption_array) THEN
  RETURN caption_array(index)
 ELSE
  RETURN "Invalid " & description & " " & index
 END IF
END FUNCTION

SUB update_attack_editor_for_chain (BYVAL mode AS INTEGER, BYREF caption1 AS STRING, BYREF max1 AS INTEGER, BYREF min1 AS INTEGER, BYREF menutype1 AS INTEGER, BYREF caption2 AS STRING, BYREF max2 AS INTEGER, BYREF min2 AS INTEGER, BYREF menutype2 AS INTEGER)
 SELECT CASE mode
  CASE 0 '--no special condition
   caption1 = ""
   max1 = 32000
   min1 = -32000
   menutype1 = 18'skipper
   caption2 = ""
   max2 = 32000
   min2 = -32000
   menutype2 = 18'skipper
  CASE 1 '--tagcheck
   caption1 = "  if Tag:"
   max1 = 1000
   min1 = -1000
   menutype1 = 2
   caption2 = "  and Tag:"
   max2 = 1000
   min2 = -1000
   menutype2 = 2
  CASE 2 TO 5
   caption1 = "  if attacker"
   max1 = 15
   min1 = 0
   menutype1 = 16 'stat
   SELECT CASE mode
    CASE 2
     caption2 = "  is >"
     max2 = 32000
     min2 = -32000
     menutype2 = 0
    CASE 3
     caption2 = "  is <"
     max2 = 32000
     min2 = -32000
     menutype2 = 0
    CASE 4
     caption2 = "  is >"
     max2 = 100
     min2 = 0
     menutype2 = 17 'int%
    CASE 5
     caption2 = "  is <"
     max2 = 100
     min2 = 0
     menutype2 = 17 'int%
   END SELECT
 END SELECT
END SUB

FUNCTION attack_chain_browser (BYVAL start_attack AS INTEGER) AS INTEGER
 DIM state AS AttackChainBrowserState
 DIM selected AS INTEGER = start_attack
 
 state.before.size = 2
 state.after.size = 2
 
 DO
  '--Init

  FOR i AS INTEGER = 0 TO UBOUND(state.chainto)
   state.chainto(i) = 0
  NEXT i

  FOR i AS INTEGER = 0 TO UBOUND(state.chainfrom)
   state.chainfrom(i) = 0
  NEXT i
  
  state.root = NewSliceOfType(slRoot)

  state.lbox = NewSliceOfType(slContainer, state.root)
  state.lbox->Width = 80

  state.rbox = NewSliceOfType(slContainer, state.root)
  state.rbox->Width = 80
  state.rbox->AlignHoriz = 2
  state.rbox->AnchorHoriz = 2

  init_attack_chain_screen selected, state
 
  state.column = 1
  state.refresh = YES
  state.focused = state.current

  state.before.pt = 0
  state.before.top = 0
  state.after.pt = 0
  state.after.top = 0
 
  setkeys
  DO
   setwait 55
   setkeys

   IF keyval(scESC) > 1 THEN
    state.done = YES
    EXIT DO
   END IF
   IF keyval(scF1) > 1 THEN show_help "attack_chain_browse"

   IF enter_or_space() THEN
    IF state.focused <> 0 THEN
     IF state.column = 1 THEN state.done = YES
     selected = state.focused->extra(0)
     EXIT DO
    END IF
   END IF

   IF keyval(scLeft) > 1 THEN state.column = loopvar(state.column, 0, 2, -1) : state.refresh = YES
   IF keyval(scRight) > 1 THEN state.column = loopvar(state.column, 0, 2, 1) : state.refresh = YES
   SELECT CASE state.column
    CASE 0: IF usemenu(state.before) THEN state.refresh = YES
    CASE 1: 
    CASE 2: IF usemenu(state.after) THEN state.refresh = YES
   END SELECT
   
   IF state.refresh THEN
    state.refresh = NO
    attack_preview_slice_defocus state.focused
    SELECT CASE state.column
     CASE 0: state.focused = state.chainfrom(state.before.pt)
     CASE 1: state.focused = state.current
     CASE 2: state.focused = state.chainto(state.after.pt)
    END SELECT
    attack_preview_slice_focus state.focused
    state.lbox->Y = state.before.top * -56
   END IF
 
   clearpage dpage
   DrawSlice state.root, dpage
 
   SWAP vpage, dpage
   setvispage vpage
   dowait
  LOOP
  
  DeleteSlice @(state.root)
  IF state.done THEN EXIT DO
 LOOP
 
 RETURN selected
END FUNCTION

FUNCTION find_free_attack_preview_slot(slots() AS Slice Ptr) AS INTEGER
 FOR i AS INTEGER = 0 TO UBOUND(slots)
  IF slots(i) = 0 THEN RETURN i
 NEXT i
 'Oops! Can't hold any more 'FIXME: if/when FreeBasic supports resizeable arrays in types, use them here
 RETURN -1
END FUNCTION

SUB init_attack_chain_screen(BYVAL attack_id AS INTEGER, state AS AttackChainBrowserState)
 DIM atk AS AttackData
 loadattackdata atk, attack_id
 
 state.current = create_attack_preview_slice("", attack_id, state.root)
 state.current->AnchorHoriz = 1
 state.current->AlignHoriz = 1
 state.current->Y = 6
 
 DIM slot AS INTEGER
 IF atk.instead.atk_id > 0 THEN
  slot = find_free_attack_preview_slot(state.chainto())
  IF slot >= 0 THEN
   state.chainto(slot) = create_attack_preview_slice("Instead", atk.instead.atk_id - 1, state.rbox)
  END IF
 END IF
 IF atk.chain.atk_id > 0 THEN
  slot = find_free_attack_preview_slot(state.chainto())
  IF slot >= 0 THEN
   state.chainto(slot) = create_attack_preview_slice("Regular", atk.chain.atk_id - 1, state.rbox)
  END IF
 END IF
 IF atk.elsechain.atk_id > 0 THEN
  slot = find_free_attack_preview_slot(state.chainto())
  IF slot >= 0 THEN
   state.chainto(slot) = create_attack_preview_slice("Else", atk.elsechain.atk_id - 1, state.rbox)
  END IF
 END IF
 
 position_chain_preview_boxes(state.chainto(), state.after)

 '--now search for attacks that chain to this one
 FOR i AS INTEGER = 0 TO gen(genMaxAttack)
  loadattackdata atk, i
  IF atk.chain.atk_id - 1 = attack_id THEN
   slot = find_free_attack_preview_slot(state.chainfrom())
   IF slot = -1 THEN EXIT FOR 'give up when out of space
   state.chainfrom(slot) = create_attack_preview_slice("Regular", i, state.lbox)
  END IF
  IF atk.elsechain.atk_id - 1 = attack_id THEN
   slot = find_free_attack_preview_slot(state.chainfrom())
   IF slot = -1 THEN EXIT FOR 'give up when out of space
   state.chainfrom(slot) = create_attack_preview_slice("Else", i, state.lbox)
  END IF
  IF atk.instead.atk_id - 1 = attack_id THEN
   slot = find_free_attack_preview_slot(state.chainfrom())
   IF slot = -1 THEN EXIT FOR 'give up when out of space
   state.chainfrom(slot) = create_attack_preview_slice("Instead", i, state.lbox)
  END IF
 NEXT i

 position_chain_preview_boxes(state.chainfrom(), state.before)

END SUB

SUB position_chain_preview_boxes(sl_list() AS Slice ptr, st AS MenuState)
 st.last = -1
 DIM y AS INTEGER = 6
 FOR i AS INTEGER = 0 TO UBOUND(sl_list)
  IF sl_list(i) <> 0 THEN
   WITH *(sl_list(i))
    .Y = y
    y += .Height + 6
   END WITH
   st.last += 1
  END IF
 NEXT i
 IF st.last = -1 THEN st.last = 0
END SUB

FUNCTION create_attack_preview_slice(caption AS STRING, BYVAL attack_id AS INTEGER, BYVAL parent AS Slice Ptr) AS Slice Ptr
 DIM atk AS AttackData
 loadattackdata atk, attack_id
 
 DIM box AS Slice Ptr = NewSliceOfType(slRectangle, parent)
 box->Width = 80
 box->Height = 50
 ChangeRectangleSlice box, 0
 ChangeRectangleSlice box, , , , -1

 DIM spr AS Slice Ptr = NewSliceOfType(slSprite, box)
 ChangeSpriteSlice spr, 6, atk.picture, atk.pal, 2
 spr->AnchorHoriz = 1
 spr->AlignHoriz = 1
 spr->AnchorVert = 2
 spr->AlignVert = 2

 DIM numsl AS Slice Ptr = NewSliceOfType(slText, box)
 ChangeTextSlice numsl, STR(attack_id), , YES
 numsl->AnchorHoriz = 1
 numsl->AlignHoriz = 1
 
 DIM namesl AS Slice Ptr = NewSliceOfType(slText, box)
 ChangeTextSlice namesl, atk.name, , YES
 namesl->AnchorHoriz = 1
 namesl->AlignHoriz = 1
 namesl->Y = 10

 DIM capsl AS Slice Ptr = NewSliceOfType(slText, box)
 ChangeTextSlice capsl, caption, , -1
 capsl->AnchorHoriz = 1
 capsl->AlignHoriz = 1
 capsl->AnchorVert = 2
 capsl->AlignVert = 2

 '--Save attack_id in the extra data
 box->extra(0) = attack_id
 RETURN box
END FUNCTION

SUB attack_preview_slice_focus(BYVAL sl AS Slice Ptr)
 IF sl = 0 THEN EXIT SUB
 ChangeRectangleSlice sl, , , , 0
 DIM ch AS Slice Ptr = sl->FirstChild
 WHILE ch
  IF ch->SliceType= slText THEN
   ChangeTextSlice ch, , uilook(uiSelectedItem)
  END IF
  ch = ch->NextSibling
 WEND
END SUB

SUB attack_preview_slice_defocus(BYVAL sl AS Slice Ptr)
 IF sl = 0 THEN EXIT SUB
 ChangeRectangleSlice sl, , , , -1
 DIM ch AS Slice Ptr = sl->FirstChild
 WHILE ch
  IF ch->SliceType = slText THEN
   ChangeTextSlice ch, , uilook(uiText)
  END IF
  ch = ch->NextSibling
 WEND
END SUB

SUB fontedit (font() as integer)
 DIM f(255) AS INTEGER
 DIM copybuf(4) AS INTEGER
 DIM menu(3) AS STRING

 menu(0) = "Previous Menu"
 menu(1) = "Edit Font..."
 menu(2) = "Import Font..."
 menu(3) = "Export Font..."

 DIM i AS INTEGER

 DIM last AS INTEGER = -1
 FOR i = 32 TO 255
  last += 1
  f(last) = i
 NEXT i

 DIM mode AS INTEGER = -1

 'This state is used for the menu, not the charpicker
 DIM state AS MenuState
 WITH state
  .pt = 0
  .top = 0
  .last = UBOUND(menu)
  .size = 22
 END WITH

 DIM linesize AS INTEGER = 14
 DIM pt AS INTEGER = -1 * linesize

 DIM x AS INTEGER
 DIM y AS INTEGER
 
 DIM xoff AS INTEGER
 DIM yoff AS INTEGER
 
 DIM c AS INTEGER

 setkeys
 DO
  setwait 55
  setkeys
  state.tog = state.tog XOR 1
  IF keyval(scF1) > 1 THEN show_help "fontedit"
  SELECT CASE mode
   CASE -1
    IF keyval(scEsc) > 1 THEN EXIT DO
    usemenu state
    IF enter_or_space() THEN
     IF state.pt = 0 THEN EXIT DO
     IF state.pt = 1 THEN mode = 0
     IF state.pt = 2 THEN
      fontedit_import_font font()
      state.pt = 1
      mode = 0
     END IF
     IF state.pt = 3 THEN fontedit_export_font font()
    END IF
   CASE 0
    IF keyval(scEsc) > 1 THEN mode = -1
    IF keyval(scUp) > 1 THEN pt = large(pt - linesize, -1 * linesize)
    IF keyval(scDown) > 1 THEN pt = small(pt + linesize, last)
    IF keyval(scLeft) > 1 THEN pt = large(pt - 1, 0)
    IF keyval(scRight) > 1 THEN pt = small(pt + 1, last)
    IF enter_or_space() THEN
     IF pt < 0 THEN
      mode = -1
     ELSE
      mode = 1
      x = 0
      y = 0
     END IF
    END IF
   CASE 1
    IF keyval(scEsc) > 1 OR keyval(scEnter) > 1 THEN mode = 0
    IF keyval(scUp) > 1 THEN y = loopvar(y, 0, 7, -1)
    IF keyval(scDown) > 1 THEN y = loopvar(y, 0, 7, 1)
    IF keyval(scLeft) > 1 THEN x = loopvar(x, 0, 7, -1)
    IF keyval(scRight) > 1 THEN x = loopvar(x, 0, 7, 1)
    IF keyval(scSpace) > 1 THEN
     setbit font(), 0, (f(pt) * 8 + x) * 8 + y, (readbit(font(), 0, (f(pt) * 8 + x) * 8 + y) XOR 1)
     setfont font()
     xbsave game + ".fnt", font(), 2048
    END IF
  END SELECT
  IF mode >= 0 THEN
   '--copy and paste support
   IF copy_keychord() THEN
    FOR i = 0 TO 63
     setbit copybuf(), 0, i, readbit(font(), 0, f(pt) * 64 + i)
    NEXT i
   END IF
   IF paste_keychord() THEN
    FOR i = 0 TO 63
     setbit font(), 0, f(pt) * 64 + i, readbit(copybuf(), 0, i)
    NEXT i
    setfont font()
    xbsave game + ".fnt", font(), 2048
   END IF
  END IF

  '--Draw screen
  clearpage dpage

  IF mode = -1 THEN
   standardmenu menu(), state, 0, 0, dpage
  END IF

  IF mode >= 0 THEN
   xoff = 8
   yoff = 8
   FOR i = 0 TO last
    textcolor uilook(uiMenuItem), uilook(uiDisabledItem)
    IF pt >= 0 THEN
     IF mode = 0 THEN
      IF (i MOD linesize) = (pt MOD linesize) OR (i \ linesize) = (pt \ linesize) THEN textcolor uilook(uiMenuItem), uilook(uiHighlight)
     END IF
     IF pt = i THEN textcolor uilook(uiSelectedItem + state.tog), 0
    END IF
    printstr CHR(f(i)), xoff + (i MOD linesize) * 9, yoff + (i \ linesize) * 9, dpage
   NEXT i
   textcolor uilook(uiMenuItem), 0
   IF pt < 0 THEN textcolor uilook(uiSelectedItem + state.tog), 0
   printstr menu(0), 8, 0, dpage

   IF pt >= 0 THEN
    xoff = 150
    yoff = 4
    rectangle xoff, yoff, 160, 160, uilook(uiDisabledItem), dpage
    FOR i = 0 TO 7
     FOR j AS INTEGER = 0 TO 7
      IF readbit(font(), 0, (f(pt) * 8 + i) * 8 + j) THEN
       rectangle xoff + i * 20, yoff + j * 20, 20, 20, uilook(uiMenuItem), dpage
      END IF
     NEXT j
    NEXT i
    IF mode = 1 THEN
     IF readbit(font(), 0, (f(pt) * 8 + x) * 8 + y) THEN
      c = uilook(uiSelectedItem2)
     ELSE
      c = uilook(uiSelectedDisabled)
     END IF
     rectangle xoff + x * 20, yoff + y * 20, 20, 20, c, dpage
    END IF
    textcolor uilook(uiText), 0
    DIM tmp as string = "CHAR " & f(pt)
    IF f(pt) >= &hA1 THEN tmp &= "/U+00" & HEX(f(pt))
    printstr tmp, 12, 190, dpage
    IF f(pt) < 32 THEN
     printstr "RESERVED", 160, 190, dpage
    ELSE
     FOR i = 2 TO 53
      IF f(pt) = ASC(key2text(2, i)) THEN printstr "ALT+" + UCASE(key2text(0, i)), 160, 190, dpage
      IF f(pt) = ASC(key2text(3, i)) THEN printstr "ALT+SHIFT+" + UCASE(key2text(0, i)), 160, 190, dpage
     NEXT i
     IF f(pt) = 32 THEN printstr "SPACE", 160, 190, dpage
    END IF
   END IF
  END IF

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
EXIT SUB

END SUB

SUB fontedit_export_font(font() AS INTEGER)

 DIM newfont AS STRING = "newfont"
 newfont = inputfilename("Input a filename to save to", ".ohf", "", "input_file_export_font") 

 IF newfont <> "" THEN
  xbsave game & ".fnt", font(), 2048
  copyfile game & ".fnt", newfont & ".ohf"
 END IF

END SUB

SUB fontedit_import_font(font() AS INTEGER)

 STATIC default AS STRING
 DIM newfont AS STRING = browse(0, default, "*.ohf", "", , "browse_font")
 
 IF newfont <> "" THEN
  writeablecopyfile newfont, game & ".fnt"

  DIM i AS INTEGER
  DIM font_tmp(1023) AS INTEGER

  '--character 0 (actually font(0)) contains metadata (marks as ASCII or Latin-1)
  '--character 1 to 31 are internal icons and should never be overwritten
  FOR i = 1 * 4 TO 32 * 4 - 1
   font_tmp(i) = font(i)
  NEXT i

  '--Reload the font
  xbload game + ".fnt", font(), "Can't load font"
  setfont font()

  '--write back the old 1-31 characters
  FOR i = 1 * 4 TO 32 * 4 - 1
   font(i) = font_tmp(i)
  NEXT i
  
 END IF
END SUB

SUB cropafter (BYVAL index AS INTEGER, BYREF limit AS INTEGER, BYVAL flushafter AS INTEGER, lump AS STRING, BYVAL bytes AS INTEGER, BYVAL prompt AS INTEGER=YES)
 'flushafter -1 = flush records
 'flushafter 0 = trim file
 DIM i as integer

 IF prompt THEN
  DIM menu(1) as string
  menu(0) = "No do not delete anything"
  menu(1) = "Yes, delete all records after this one"
  IF sublist(menu(), "cropafter") < 1 THEN
   setkeys
   EXIT SUB
  ELSE
   setkeys
  END IF
 END IF

 DIM buf(bytes \ 2 - 1) AS INTEGER
 FOR i = 0 TO index
  loadrecord buf(), lump, bytes \ 2, i
  storerecord buf(), tmpdir & "_cropped.tmp", bytes \ 2, i
 NEXT i
 IF flushafter THEN
  'FIXME: this flushafter hack only exists for the .DT0 lump,
  ' out of fear that some code with read hero data past the end of the file.
  ' after cleanup of all hero code has confurmed this fear is unfounded, we can
  ' eliminate this hack entirely
  flusharray buf()
  FOR i = index + 1 TO limit
   storerecord buf(), tmpdir & "_cropped.tmp", bytes \ 2, i
  NEXT i
 END IF
 limit = index

 copyfile tmpdir & "_cropped.tmp", lump
 safekill tmpdir & "_cropped.tmp"
END SUB

FUNCTION numbertail (s AS STRING) AS STRING
 DIM n AS INTEGER

 IF s = "" THEN RETURN "BLANK"

 FOR i AS INTEGER = 1 TO LEN(s)
  IF is_int(MID(s, i)) THEN
   n = str2int(MID(s, i)) + 1
   RETURN LEFT(s, i - 1) & n
  END IF
 NEXT
 RETURN s + "2"  
END FUNCTION

'Get a list of the first letters (lowercase) of every word in menu(), except
'those words listed in excludewords. excludewords should be a space-separated
'list (case matters).
'menukeys() should be staticaly sized.
SUB get_menu_hotkeys (menu() as string, byval menumax as integer, menukeys() as string, excludewords as string = "")
 'Easy exercise for the reader: Write this in three lines of Python
 DIM excludes() as string
 IF excludewords = "" THEN
  REDIM excludes(-1 TO -1)
 ELSE
  split excludewords, excludes(), " "
 END IF
 FOR i as integer = 0 TO menumax
  menukeys(i) = ""
  DIM firstletter as integer = YES
  FOR j as integer = 1 TO LEN(menu(i))
   DIM isalp as integer = isalpha(menu(i)[j - 1])
   IF firstletter ANDALSO isalp THEN
    DIM excluded as integer = NO
    FOR k as integer = 0 TO UBOUND(excludes)
     IF MID(menu(i), j, LEN(excludes(k))) = excludes(k) THEN excluded = YES : EXIT FOR
    NEXT
    IF excluded = NO THEN
     menukeys(i) += LCASE(MID(menu(i), j, 1))
    END IF
   END IF
   firstletter = (isalp = 0)
  NEXT
  'debug "hotkeys from '" & menu(i) & "' -> '" & menukeys(i) & "'"
 NEXT
END SUB

SUB experience_chart ()

 'DIM exp_first_level AS INTEGER = 30
 'DIM exp_multiplier AS SINGLE = 1.2
 'DIM exp_adder AS INTEGER = 5
 'DIM exp_uppercap AS INTEGER = 1000000

 DIM mode AS INTEGER = 0
 STATIC hero_count AS INTEGER = 4
 STATIC enemy_id AS INTEGER = 0
 DIM enemy AS EnemyDef

 STATIC form_id AS INTEGER = 0
 DIM formdata(40) AS INTEGER

 DIM startfrom AS INTEGER = 3
 DIM menu(startfrom + gen(genMaxLevel)) AS STRING
 menu(0) = "Previous menu..."
 DIM state AS MenuState
 WITH state
  .size = 24
  .last = UBOUND(menu)
  .need_update = YES
 END WITH

 setkeys
 DO
  setwait 55
  setkeys

  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "experience_chart"
  usemenu state
  IF enter_or_space() THEN
   IF state.pt = 0 THEN EXIT DO
  END IF
  IF state.pt = 1 THEN
   IF intgrabber(mode, 0, 2) THEN state.need_update = YES
  END IF
  IF state.pt = 2 THEN
   IF mode = 1 THEN
    IF intgrabber(enemy_id, 0, gen(genMaxEnemy)) THEN state.need_update = YES
   ELSEIF mode = 2 THEN
    IF intgrabber(form_id, 0, gen(genMaxFormation)) THEN state.need_update = YES
   END IF
  END IF
  IF state.pt = 3 THEN
   IF intgrabber(hero_count, 1, 4) THEN state.need_update = YES
  END IF

  IF state.need_update THEN
   DIM test_exp AS INTEGER = 0
   DIM test_name AS STRING
   IF mode = 0 THEN
    menu(1) = "Preview mode: Total Exp."
    menu(2) = "Compared to N/A"
   ELSEIF mode = 1 THEN
    loadenemydata enemy, enemy_id
    menu(1) = "Preview mode: Enemy"
    menu(2) = "Compared to enemy: " & enemy_id & " " & enemy.name & " (" & enemy.reward.exper & " exp)"
    test_exp = enemy.reward.exper
    test_name = enemy.name
   ELSEIF mode = 2 THEN
    setpicstuf formdata(), 80, -1
    loadset game & ".for", form_id, 0
    test_exp = 0
    FOR i AS INTEGER = 0 TO 8
     IF formdata(i * 4) > 0 THEN
      loadenemydata enemy, formdata(i * 4) - 1
      test_exp += enemy.reward.exper
     END IF
    NEXT i
    menu(1) = "Compare mode: Formation"
    menu(2) = "Compared to formation: " & form_id & " (" & test_exp & " exp)"
    test_name = "Formation" & form_id
   END IF
   menu(3) = "Distributed to a party of: " & hero_count & " heroes"
   DIM suffix AS STRING
   DIM killcount AS STRING
   FOR lev AS INTEGER = 1 TO gen(genMaxLevel)
    IF mode = 0 THEN
     suffix = "total " & total_exp_to_level(lev)
    ELSE
     IF test_exp > 0 THEN
      killcount = STR(ceiling(exptolevel(lev) / test_exp * hero_count))
     ELSE
      killcount = "infinite"
     END IF
     suffix = "= " & test_name & "*" & killcount
    END IF
    menu(startfrom + lev) = "Level " & lev & " +" & exptolevel(lev) & " " & suffix
   NEXT lev
   state.need_update = NO
  END IF

  clearpage vpage
  draw_fullscreen_scrollbar state, , vpage
  standardmenu menu(), state, 0, 0, vpage, , , 312  'wide=312
  setvispage vpage
  dowait
 LOOP 
END SUB

SUB stat_growth_chart ()
 'midpoint should stored in gen()
 DIM midpoint AS DOUBLE = 0.3219  'default to current
 DIM midpoint_repr AS STRING = format_percent(midpoint, 4)

 DIM menu(2) AS STRING
 menu(0) = "Previous menu..."
 DIM state AS MenuState
 WITH state
  .size = 24
  .last = UBOUND(menu)
  .need_update = YES
 END WITH

 DIM preview_lev AS INTEGER = gen(genMaxLevel) \ 2

 'Position and size of the graph
 DIM rect AS RectType
 rect.x = 150
 rect.y = 40
 rect.wide = 150
 rect.high = 140
 DIM origin_y = rect.y + rect.high

 setkeys YES
 DO
  setwait 55
  setkeys YES

  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "stat_growth"
  usemenu state
  IF enter_or_space() THEN
   IF state.pt = 0 THEN EXIT DO
  END IF
  IF state.pt = 1 THEN
   state.need_update = percent_grabber(midpoint, midpoint_repr, -0.1, 1.2, 4)
  ELSEIF state.pt = 2 THEN
   state.need_update = intgrabber(preview_lev, 0, gen(genMaxLevel))
  END IF

  IF state.need_update THEN
   menu(1) = "Fix value at level " & (gen(genMaxLevel) / 2) & " : " & midpoint_repr
   menu(2) = "Preview: at level " & preview_lev & " = " & format_percent(atlevel_quadratic(preview_lev, 0, 1000000, midpoint) / 1000000, 4)  ' of Level" & gen(genMaxLevel) & " value"
   state.need_update = NO
  END IF

  'Draw screen
  clearpage vpage
  standardmenu menu(), state, 0, 0, vpage

  'Draw a 150x150 graph
  'axes
  drawline rect.x, origin_y, rect.x, rect.y, uilook(uiDisabledItem), vpage
  drawline rect.x, origin_y, rect.x + rect.wide, origin_y, uilook(uiDisabledItem), vpage
  'line (drawn so that if genMaxLevel is small, you get a lot of steps, and never sloped line segments)
  DIM lasty AS DOUBLE
  FOR x AS INTEGER = 0 TO rect.wide - 1
   DIM lev AS INTEGER = INT((gen(genMaxLevel) + 1) * x / rect.wide)  'floor
   DIM y AS DOUBLE = atlevel_quadratic(lev, 0, rect.high * 100, midpoint) / 100
   IF x = 0 THEN lasty = y
   drawline x + rect.x, origin_y - y, x + rect.x, origin_y - lasty, uilook(uiHighlight), vpage
   lasty = y
  NEXT

  'Draw crosshair
  DIM crosshair_lev AS DOUBLE
  IF state.pt = 2 THEN crosshair_lev = preview_lev ELSE crosshair_lev = gen(genMaxLevel) / 2
  DIM AS DOUBLE crosshairx, crosshairy  'in pixels
  crosshairx = rect.wide * crosshair_lev / gen(genMaxLevel)
  crosshairy = atlevel_quadratic(crosshair_lev, 0, rect.high * 100, midpoint) / 100
  drawline rect.x + crosshairx - 3, origin_y - crosshairy, rect.x + crosshairx + 3, origin_y - crosshairy, uilook(uiHighlight2), vpage
  drawline rect.x + crosshairx, origin_y - crosshairy - 3, rect.x + crosshairx, origin_y - crosshairy + 3, uilook(uiHighlight2), vpage

  setvispage vpage
  dowait
 LOOP 
END SUB

FUNCTION pick_channel_name() as string
 #ifdef __FB_WIN32__
  return "\\.\pipe\ohrrpgce_lump_updates_testing_" + trimpath(sourcerpg)
 #else
  return tmpdir + ".lump_updates.txt"
 #endif
END FUNCTION

SUB spawn_game
 IF slave_process <> 0 THEN
  'First clean up after the last time we ran Game
  cleanup_process @slave_process
 END IF

 DIM fh as integer = FREEFILE
 DIM channel_name as string
 channel_name = pick_channel_name()
 IF channel_open_server(slave_channel, channel_name) = NO THEN
  notification "Couldn't open channel"
  EXIT SUB
 END IF
 debuginfo "Successfully opened IPC channel " + channel_name

 DIM gameexename as string = GAMEEXE
 DIM executable as string
 executable = exepath & SLASH & GAMEEXE

#ifdef __FB_DARWIN__
 executable = app_dir + "/OHRRPGCE-Game.app/Contents/MacOS/ohrrpgce-game"
 IF isfile(executable) = NO THEN
  executable = exepath & SLASH & GAMEEXE
 ELSE
  gameexename = "OHRRPGCE-Game"
 END IF
#endif
 IF isfile(executable) = NO THEN
  notification "Couldn't find " & gameexename
  EXIT SUB
 END IF
 slave_process = open_process(executable, "-slave " & channel_name)
 IF slave_process = 0 THEN
  notification "Couldn't run " & gameexename
  EXIT SUB
 END IF
 'We currently do nothing at all with slave_process except cleanup (nothing is implemented
 'on Unix). Instead we test Game is still running with slave_channel <> NULL_CHANNEL

 'Need Game to connect before we can safely write to the pipe; wait up to 3000ms
 IF channel_wait_for_client_connection(slave_channel, 3000) = 0 THEN
  notification "Couldn't connect to " & gameexename
  channel_close slave_channel
  cleanup_process @slave_process
  EXIT SUB
 END IF

 'Write version info
 DIM tmp as string
 'msgtype magickey,proto_ver,program_ver,version_string
 tmp = "V OHRRPGCE," & CURRENT_TESTING_IPC_VERSION & "," & version_revision & "," & version
 IF channel_write_line(slave_channel, tmp) = 0 THEN
  'good idea to test writing is working at least once
  notification "Channel write failure; aborting"
  channel_close slave_channel
  cleanup_process @slave_process
  EXIT SUB
 END IF
 tmp = "G " & sourcerpg
 channel_write_line(slave_channel, tmp)
 tmp = "W " & workingdir
 channel_write_line(slave_channel, tmp)

 IF slave_channel <> NULL_CHANNEL THEN
  'If we got this far, start sending lump updates and locking files before writing
  set_OPEN_hook @inworkingdir, YES, @slave_channel
 END IF
END SUB

SUB spawn_game_menu
 'Prod the channel to see whether it's still up (send ping)
 channel_write_line(slave_channel, "P ")

 IF slave_channel <> NULL_CHANNEL THEN
  notification "Game is already running! Running multiple test copies of a game is not yet supported."
 ELSE
  spawn_game
  notification !"You're running your game in live preview mode. Please press F1 now to read the help file for this if you haven't already.\n\nPress any key"
  IF keyval(scF1) > 1 THEN show_help "test_game"
 END IF
END SUB

FUNCTION wget_download (url as string, destdir as string, forcefilename as string="") as integer
 'Returns True on success, false on failure.
 '
 'Downloads a url to a file. uses wget's -N option to only re-download
 ' an existing file if the remote file is newer.
 '
 'If you specify forcefilename, the -N option will do nothing,
 ' and the file will be re-downloaded even if it has not changed
 ' since the last time it was downloaded.

 '--Find the wget to to do the downloading
 DIM wget as string = find_helper_app("wget")
 IF wget = "" THEN visible_debug "ERROR: Can't find wget download tool": RETURN NO

 '--prepare the command line
 DIM args as string
 IF forcefilename = "" THEN
  args = "-N -P """ & destdir & """"
 ELSE
  args = "-O """ & destdir & SLASH & forcefilename & """"
 END IF
 args &= " """ & url & """"
 
 '--Do the download
 DIM spawn_ret as string
 spawn_ret = spawn_and_wait(wget, args)
 
 '--Check to see if the download worked
 IF LEN(spawn_ret) > 0 THEN visible_debug "ERROR: wget download failed: " & spawn_ret : RETURN NO
 
 RETURN YES
END FUNCTION

FUNCTION can_run_windows_exes () as integer
#IFDEF __FB_WIN32__
 '--Of course we can always run exe files on Windows
 RETURN YES
#ENDIF
'--Unixen and Macs can only run exe files with wine
IF find_helper_app("wine") = "" THEN RETURN NO
IF NOT isdir(environ("HOME") & "/.wine/dosdevices/c:") THEN RETURN NO
RETURN YES
END FUNCTION
