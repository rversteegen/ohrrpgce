'OHRRPGCE CUSTOM - Tag and Condition editors and grabbers
'(C) Copyright 1997-2018 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability

#include "config.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "const.bi"
#include "uiconst.bi"
'#include "scrconst.bi"
#include "customsubs.bi"
#include "custom.bi"
#include "tagedit.bi"
'#include "thingbrowser.bi"

'Subs and functions only used here
DECLARE SUB cond_editor (cond as Condition, default as bool = NO, outer_state as MenuState)
DECLARE FUNCTION describe_tag_autoset_places(byval tag_id as integer) as string


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


'==========================================================================================
'                            Captions for tag-editing menu items
'==========================================================================================

'Returns  "prefix ABS(n) suffix [AUTOSET] (<tagname or zero/one/negonecap>)"
'where everything except the ABS(n) is optional.
PRIVATE FUNCTION base_tag_caption(byval n as integer, prefix as string, suffix as string, zerocap as string, onecap as string, negonecap as string, byval allowspecial as bool) as string
 DIM ret as string
 ret = prefix
 IF LEN(ret) > 0 THEN ret &= " "
 ret &= ABS(n) & suffix
 IF allowspecial <> YES ANDALSO tag_is_autoset(n) THEN ret &= " [AUTOSET]"

 'Append " ($cap)"
 DIM cap as string
 cap = load_tag_name(n)
 IF n = 0 AND LEN(zerocap) > 0 THEN cap = zerocap
 IF n = 1 AND LEN(onecap) > 0 THEN cap = onecap
 IF n = -1 AND LEN(negonecap) > 0 THEN cap = negonecap
 cap = TRIM(cap)
 IF LEN(cap) > 0 THEN ret &= " (" & cap & ")"

 RETURN ret
END FUNCTION

FUNCTION tag_toggle_caption(byval n as integer, prefix as string="Toggle tag", byval allowspecial as bool=NO) as string
 RETURN base_tag_caption(n, prefix, "", "N/A", "Unchangeable", "Unchangeable", allowspecial)
END FUNCTION

FUNCTION tag_choice_caption(byval n as integer, prefix as string="", byval allowspecial as bool=NO) as string
 RETURN base_tag_caption(n, prefix, "", "None", "Unchangeable", "Unchangeable", allowspecial)
END FUNCTION

FUNCTION tag_set_caption(byval n as integer, prefix as string="Set Tag", byval allowspecial as bool=NO) as string
 RETURN base_tag_caption(n, prefix, "=" & onoroff(n), "No tag set", "Unchangeable", "Unchangeable", allowspecial)
END FUNCTION

' Note that this similar to textbox_condition[_short]_caption and describe_tag_condition. Sorry!
FUNCTION tag_condition_caption(byval n as integer, prefix as string="Tag", zerocap as string, onecap as string="Never", negonecap as string="Always") as string
 RETURN base_tag_caption(n, prefix, "=" & onoroff(n), zerocap, onecap, negonecap, YES)
END FUNCTION

'Describe a condition which checks two tags (both conditions need to pass)
'zerovalue: meaning of 0. true is always, false is never
FUNCTION describe_two_tag_condition(prefix as string, truetext as string, falsetext as string, byval zerovalue as bool, byval tag1 as integer, byval tag2 as integer) as string
  DIM ret as string = prefix
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


'==========================================================================================
'                                       tag_grabber
'==========================================================================================

'Return YES if the tag has changed
'allowspecial:  Whether to allow picking autoset tags (eg hero is alive)
'               If you want to change this, use tag_set_grabber instead if possible.
'always_choice: 'Always' is an option
'allowneg:      Allow set tag=OFF.
'               If you want to change this, use tag_id_grabber instead if possible.
FUNCTION tag_grabber (byref n as integer, state as MenuState, allowspecial as bool=YES, always_choice as bool=NO, allowneg as bool=YES) as bool
 DIM min as integer = 0
 IF allowneg THEN min = -max_tag()
 IF intgrabber(n, min, max_tag()) THEN RETURN YES
 IF enter_space_click(state) THEN
  DIM browse_tag as integer
  browse_tag = tags_menu(n, YES, allowspecial, allowneg, always_choice)
  IF browse_tag <> n THEN
   n = browse_tag
   RETURN YES
  END IF
 END IF
 RETURN NO
END FUNCTION

'A tag_grabber wrapper for set tag ON/OFF actions.
'Return YES if the tag has changed
FUNCTION tag_set_grabber (byref n as integer, state as MenuState) as bool
 RETURN tag_grabber(n, state, NO)
END FUNCTION

'A tag_grabber wrapper for tag ids.
'Return YES if the tag has changed
FUNCTION tag_id_grabber (byref n as integer, state as MenuState) as bool
 RETURN tag_grabber(n, state, NO, , NO)  'allowneg=NO
END FUNCTION


'==========================================================================================
'                                       Tag Editor
'==========================================================================================

/'
FUNCTION safe_tag_name(byval tagnum as integer) as string 
 IF tagnum >= 1 AND tagnum <= gen(genMaxTagName) THEN
  RETURN load_tag_name(tagnum)
 ELSE
  RETURN ""
 END IF
END FUNCTION
'/

'Returns one line per place where this tag is autoset. Empty if none.
FUNCTION describe_tag_autoset_places(byval tag_id as integer) as string
 DIM ret as string
 tag_id = ABS(tag_id)

 IF tag_id <= 1 THEN RETURN ""
 
 DIM kind_name as string

 FOR i as integer = 0 TO small(gen(genMaxHero), UBOUND(herotags)) '--for each available hero
  WITH herotags(i)
   IF tag_id = .have_tag THEN ret += "Hero " & i & !" in party tag\n"
   IF tag_id = .alive_tag THEN ret += "Hero " & i & !" is alive tag\n"
   IF tag_id = .leader_tag THEN ret += "Hero " & i & !" is leader tag\n"
   IF tag_id = .active_tag THEN ret += "Hero " & i & !" in active party tag\n"
   FOR j as integer = 0 TO v_len(.checks) - 1
    WITH .checks[j]
     SELECT CASE .kind
      CASE TagRangeCheckKind.level
       kind_name = "level"
      CASE ELSE
       kind_name = "???(" & .kind & ")"
     END SELECT
     IF tag_id = .tag THEN ret += "Hero " & i & " " & kind_name & " check " & j & !"\n"
    END WITH
   NEXT j
  END WITH
 NEXT i

 FOR i as integer = 0 TO maxMaxItems
  WITH itemtags(i)
   IF tag_id = .have_tag THEN ret += "Item " & i & !" have tag\n"
   IF tag_id = .in_inventory_tag THEN ret += "Item " & i & !" in inventory tag\n"
   IF tag_id = .is_equipped_tag THEN ret += "Item " & i & !" is equipped tag\n"
   IF tag_id = .is_actively_equipped_tag THEN ret += "Item " & i & !" equipped by active hero tag\n"
  END WITH
 NEXT i

 IF tag_id <= UBOUND(chainedtags) THEN
  WITH chainedtags(tag_id)
   IF .typ <> chainedtagUnused THEN
    DIM temp as string
    'Set default in case all Conditions are unused
    IF .typ = chainedtagAND THEN temp = "ON" ELSE temp = "OFF"
    DIM firstcond as bool = YES
    FOR idx as integer = 0 TO UBOUND(.conds)
     'WITH .conds(idx)
      IF .conds(idx).comp <> compNone THEN
       IF firstcond = NO THEN
        IF .typ = chainedtagAND THEN temp += " AND " ELSE temp += " OR "
       END IF
       firstcond = NO
       temp += condition_string(.conds(idx), NO)
      END IF
     'END WITH
    NEXT
    ret += "When " & temp & !"\n"
   END IF
  END WITH
 END IF

 RETURN ret
END FUNCTION

PRIVATE SUB tag_autoset_warning(byval tag_id as integer)
 notification !"This tag is automatically set or unset on the following conditions:\n" + describe_tag_autoset_places(tag_id) + !"\nThis means that you should not attempt to set or unset the tag in any other way, because your changes will be erased -- unpredictably!"
END SUB


TYPE ChainedTagMenu EXTENDS ModularMenu
 DIM id as integer

 DECLARE SUB update ()
 DECLARE FUNCTION each_tick () as bool
END TYPE

SUB ChainedTagMenu.update()
 STATIC as zstring ptr chaintypes = {@"None", @"AND", @"OR"}
 WITH chainedtags(id)
  REDIM menu(1)
  menu(0) = "Previous Menu"
  IF .typ = chainedtagNone THEN
   menu(1) = 
  REDIM PRESERVE menu(5)
  state.last = UBOUND(menu)
  IF 
  menu(1) = ""
  FOR mi as integer = 2 TO 2 + 3
   menu(mi) = " If " & condition_string(cond1, (state.pt = mi), "Always", 60)
  NEXT
 END WITH
END SUB

FUNCTION ChainedTagMenu.each_tick () as bool
 WITH chainedtags(id)

 DIM changed as bool
 SELECT CASE state.pt
  CASE 0
   IF enter_space_click(state) THEN RETURN YES
  CASE 1
   
  CASE 2 TO 5
   tmp = cond_grabber(.conds(state.pt - 2), YES, YES, state)
  END SELECT
 state.need_update OR= changed

 END WITH
END FUNCTION

SUB chained_tag_editor(tag_id as integer)
 DIM menu as ChainedTagMenu
 menu.floating = YES
 menu.tag = tag_id
 menu.title = "Editing a chained tag"
 menu.helpkey = "chained_tag_edit"
 menu.run()
END SUB

'If picktag is true, then can be used to pick a tag. In that case, allowspecial indicates whether to allow
'picking 'special' tags: those automatically set, eg. based on inventory conditions
'If showsign is true, picking a tag condition (tag=ON/OFF), and the ON/OFF condition can be selected.
'Returns a signed tag number (+ve, tag ON, -ve tag OFF).
FUNCTION tags_menu (byval starttag as integer=0, byval picktag as bool=NO, byval allowspecial as bool=YES, byval showsign as bool=NO, byval always_choice as bool=NO) as integer
 STATIC searchstring as string
 
 'If this method for guessing checktag mode ever fails, we can change it to be an argument
 DIM checktag as bool = picktag ANDALSO allowspecial

 DIM thisname as string
 DIM ret as integer = starttag
 IF gen(genMaxTagname) < 1 THEN gen(genMaxTagname) = 1
 
 DIM tagid as integer vector
 DIM menu as BasicMenuItem vector

 DIM menu_size as integer = gen(genMaxTagname) + 1
 IF picktag THEN menu_size += 1
 IF always_choice THEN menu_size += 1

 v_new menu, menu_size
 v_new tagid, menu_size

 IF picktag THEN
  menu[0].text = "Cancel"
 ELSE
  menu[0].text = "Previous Menu"
 END IF
 tagid[0] = -1

 DIM menu_i as integer = 1
 
 IF picktag THEN
  'When picktag is true, it should be possible to clear the tag selection
  tagid[menu_i] = 0
  IF checktag THEN
   menu[menu_i].text = "No Tag Check"
  ELSE
   menu[menu_i].text = "No Tag Set"
  END IF
  menu_i += 1
 END IF

 IF always_choice THEN
  tagid[menu_i] = 1 'Magic value to indicate we want the "Always" tag
  menu[menu_i].text = "ALWAYS"
  menu_i += 1
 END IF

 FOR i as integer = 2 TO gen(genMaxTagname) + 1
  'Load all tag names plus the first blank name
  menu[menu_i].text = "Tag " & i & ":" & load_tag_name(i)
  tagid[menu_i] = i
  IF tag_is_autoset(i) THEN
   IF allowspecial = NO AND i <> ABS(starttag) THEN
    menu[menu_i].disabled = YES
   END IF
  END IF
  menu_i += 1
 NEXT i

 DIM tagsign as integer
 tagsign = SGN(starttag)
 IF tagsign = 0 THEN tagsign = 1

 DIM menuopts as MenuOptions
 menuopts.fullscreen_scrollbar = YES

 DIM state as MenuState
 state.autosize = YES
 state.autosize_ignore_lines = 1
 IF showsign THEN
  state.autosize_ignore_lines = 2
 END IF
 state.last = v_len(menu) - 1
 init_menu_state state, menu

 state.pt = 0
 'If ABS(starttag) >= 2 (valid tag) or 0 (do nothing), sets initial selection
 FOR i as integer = 0 to v_len(tagid) - 1
  IF tagid[i] = ABS(starttag) THEN
   state.pt = i
   EXIT FOR
  END IF
 NEXT i

 DIM int_browsing as bool = NO
 DIM uninterrupted_alt_press as bool = NO
 DIM alt_pt as integer

 DIM do_search as bool = NO
 DIM search_cur_str as string
 DIM search_found as bool = NO

 setkeys YES
 DO
  setwait 55
  setkeys YES
  IF keyval(ccCancel) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "tagnames"
  IF keyval(scCTRL) > 0 ANDALSO keyval(scF) > 1 THEN
   IF prompt_for_string(searchstring, "Search") THEN
    do_search = YES
   END IF
  END IF
  IF keyval(scF3) > 1 THEN
   do_search = YES
  END IF
  IF do_search THEN
   do_search = NO
   IF searchstring <> "" THEN
    FOR i as integer = large(state.pt + 1, 1) TO v_len(tagid) - 1
     IF tagid[i] < 2 THEN CONTINUE FOR
     search_cur_str = load_tag_name(tagid[i])
     IF INSTR(LCASE(search_cur_str), LCASE(searchstring)) THEN
      state.pt = i
      correct_menu_state state
      search_found = YES
      EXIT FOR
     END IF
    NEXT i
    IF NOT search_found THEN
     '--wrap the search
     FOR i as integer = 1 TO state.pt - 1
      IF tagid[i] < 2 THEN CONTINUE FOR
      search_cur_str = load_tag_name(tagid[i])
      IF INSTR(LCASE(search_cur_str), LCASE(searchstring)) THEN
       state.pt = i
       correct_menu_state state
       search_found = YES
       EXIT FOR
      END IF
     NEXT i
    END IF
    search_found = NO
   END IF
  END IF
  IF usemenu(state) THEN
   IF tagid[state.pt] >= 2 THEN
    alt_pt = tagid[state.pt]
   ELSE
    alt_pt = 0
   END IF
  END IF
  IF keyval(scAlt) AND 4 THEN uninterrupted_alt_press = YES
  IF keyval(scAlt) = 0 AND uninterrupted_alt_press = YES THEN
   uninterrupted_alt_press = NO
   int_browsing XOR= YES
   IF tagid[state.pt] >= 2 THEN
    alt_pt = tagid[state.pt]
   ELSE
    alt_pt = 0
   END IF
  END IF
  IF int_browsing THEN
   IF intgrabber(alt_pt, 0, gen(genMaxTagName) + 1) THEN
    FOR i as integer = 0 TO v_len(tagid) - 1
     IF alt_pt = tagid[i] THEN
      state.pt = i
      correct_menu_state state
      EXIT FOR
     END IF
    NEXT i
   END IF
  ELSEIF showsign THEN
   IF keyval(ccLeft) > 1 ORELSE keyval(ccRight) > 1 THEN
    tagsign = tagsign * -1
   END IF
  END IF
  IF tagid[state.pt] = -1 AND enter_space_click(state) THEN
   'We want to cancel out with no changes
   ret = starttag
   EXIT DO
  END IF
  IF tagid[state.pt] = 0 AND enter_space_click(state) THEN
   'We want to return 0, clearing the tag set/check
   ret = 0
   EXIT DO
  END IF
  IF tagid[state.pt] = 1 AND enter_space_click(state) THEN
   'We want to return -1, indicating a tag-check of "ALWAYS"
   IF NOT checktag THEN debug "tags_menu() returned -1 ALWAYS when not in checktag mode."
   ret = -1
   EXIT DO
  END IF
  IF tagid[state.pt] >= 2 THEN
   IF keyval(scTab) > 1 THEN
    IF tag_is_autoset(tagid[state.pt], NO) THEN  'inc_chained=NO
     tag_autoset_warning tagid[state.pt]
    ELSE
     chained_tag_editor(tagid[state.pt])
    END IF
   END IF
   IF keyval(scAnyEnter) > 1 ORELSE menu_click(state) THEN ' Can't call enter_space_click() because we can type spaces when editing tag names
    IF menu[state.pt].disabled THEN
     tag_autoset_warning tagid[state.pt]
    ELSEIF picktag THEN
     ret = tagid[state.pt] * tagsign
     EXIT DO
    END IF
   END IF
   thisname = load_tag_name(tagid[state.pt])  'safe_tag
   IF int_browsing = NO ANDALSO strgrabber(thisname, 30) THEN
    uninterrupted_alt_press = NO
    SaveTag tagid[state.pt], thisname, chainedtags(tagid[state.pt])
    menu[state.pt].text = "Tag " & tagid[state.pt] & ":" & thisname
    IF tagid[state.pt] = gen(genMaxTagName) + 1 THEN
     IF gen(genMaxTagName) < max_tag() THEN
      gen(genMaxTagName) += 1
      REDIM PRESERVE chainedtags(gen(genMaxTagName))
      v_resize menu, v_len(menu) + 1
      v_resize tagid, v_len(tagid) + 1
      tagid[state.pt + 1] = tagid[state.pt] + 1
      menu[state.pt + 1].text = "Tag " & tagid[state.pt + 1] & ":"
      state.last += 1
     END IF
    END IF
   END IF
  END IF

  clearpage dpage
  standardmenu menu, state, 0, 0, dpage, menuopts
  DIM tmpstr as string
  IF int_browsing THEN
   textcolor uilook(uiText), uilook(uiHighlight)
   tmpstr = "Tag " & alt_pt
  ELSE
   textcolor uilook(uiDisabledItem), 0
   tmpstr = "Alt:Tag #"
  END IF
  printstr tmpstr, pRight, 0, dpage

  IF NOT int_browsing THEN
   printstr "CTRL+F Search", pRight, 10, dpage
   IF LEN(searchstring) > 0 THEN
    printstr "F3 Again", pRight, 20, dpage
   END IF
  END IF

  IF showsign THEN
   ' Show whether we are picking a tag that can be ON or OFF
   DIM signstr as string
   IF checktag THEN
    signstr = "Check if tag is"
   ELSE
    signstr = "Set tag ="
   END IF
   signstr = signstr & " " & IIF(tagsign = 1, "ON", "OFF")
   textcolor uilook(uiText), 0
   DIM signrect as RectType
   signrect = str_rect(signstr, 0 , 0)
   signrect.x = vpages(dpage)->w - signrect.size.x
   signrect.y = vpages(dpage)->h - 16
   IF rect_collide_point(signrect, readmouse.pos) THEN
    textcolor uilook(uiSelectedItem + state.tog), uilook(uiHighlight)
    IF readmouse.release AND mouseLeft THEN tagsign *= -1
   END IF
   printstr signstr, pRight, pBottom - 8, dpage
  END IF

  IF tag_is_autoset(tagid[state.pt], NO) THEN  'inc_chained=NO
   'Showing tag autoset status is not important when using picktag for a tag check
   'so we only show it when in set-tag more or non-tag-picking mode
   textcolor uilook(uiDisabledItem), 0
   printstr "An auto-set tag. Press TAB for details", 0, pBottom, dpage
  ELSE 'IF picktag = NO THEN
   textcolor uilook(uiDisabledItem), 0
   printstr "Press TAB to edit tag chains", 0, pBottom, dpage
  END IF

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 setkeys

 v_free menu
 RETURN ret
END FUNCTION


'==========================================================================================
'                                      Conditions
'==========================================================================================

'default: meaning of the null condition (true: ALWAYS, false: NEVER)
'alwaysedit: experimental parameter, changes behaviour of enter/space
'Return value is currently very unreliable.
FUNCTION cond_grabber (cond as Condition, default as bool = NO, alwaysedit as bool, st as MenuState) as bool

 DIM intxt as string = getinputtext
 DIM entered_operator as bool = NO
 DIM temp as integer

 WITH cond

  'debug "cond_grabber: .comp = " & comp_strings(.comp) & " tag/var = " & .tag & " value = " & .value & " editst = " & .editstate & " lastchar = " & CHR(.lastinput) & "  default = " & default

  IF keyval(scDelete) > 1 THEN
   .comp = 0
   RETURN YES
  END IF

  'Simplify
  IF .comp = compTag AND .tag = 0 THEN .comp = 0

  'enter_or_space
  IF .comp = compTag AND alwaysedit = NO THEN
   IF enter_or_space() THEN
    DIM browse_tag as integer
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
   IF keyval(scAnyEnter) > 1 THEN cond_editor(cond, default, st)
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
    DIM newcomp as CompType = -1

    IF .comp = compNone OR .comp = compTag OR .editstate = 1 OR .editstate = 5 THEN
     'Ignore the current operator; we're pretending there is none
     newcomp = a_findcasei(comp_strings(), inchar)

    ELSE
     'First check whether in the middle of typing a comparison operator.
     'This special check ensure that eg. typing >= causes the operator to
     'change to >= regardless of initial state
     IF .lastinput THEN
      'Only checking input strings of len 2
      newcomp = a_findcasei(comp_strings(), CHR(.lastinput) + inchar)
     END IF

     IF newcomp = -1 THEN
      'This _temp variable is to work around a FB bug, https://sourceforge.net/p/fbc/bugs/816/
      '(Fixed in FB 1.06.)
      'It only occurs when compiling with debug=0 (without -exx. Whether adding/removing -exx causes
      'the bug to occur depends on the surrounding context in the function).
      DIM _temp as integer = charnum - 1
      DIM tempcomp as string = statetable(_temp, .comp)
      newcomp = a_findcasei(comp_strings(), tempcomp)
     END IF
    END IF

    IF newcomp > -1 THEN
     IF .comp = compNone OR .comp = compTag THEN
      'In future, largest allowable tag ID will increase
      .varnum = small(ABS(.tag), maxScriptGlobals)
      .value = 0
      .editstate = 2
     END IF
     .comp = newcomp
    END IF
   END IF

   .lastinput = ASC(inchar)
  NEXT

  'Other input: a finite state machine
  IF .comp = compNone THEN
   'No need to check for entered_operator: the comp would have changed
   .tag = 0
   IF intgrabber(.tag, -max_tag(), max_tag()) THEN
    .comp = compTag
   END IF
  ELSEIF .comp = compTag THEN
   'editstate meaning (asterisks indicate highlighting)
   '0: Tag #=OFF/ON  (no highlight)
   '1: Tag *#*=OFF/ON
   'No need to check for entered_operator
   IF INSTR(intxt, "!") THEN
    .tag = -.tag
   ELSE
    intgrabber(.tag, -max_tag(), max_tag())
   END IF
  ELSE  'Globals
   .varnum = bound(.varnum, 0, maxScriptGlobals)  'Could be negative if it was a tag condition
   'editstate is just a state id, defining the way the condition is edited and displayed
   '(below, asterisks indicate highlighting)
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
      IF keyval(ccLeft) > 0 OR keyval(ccRight) > 0 THEN temp = .varnum
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
      .comp = compNone
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
      DIM newcomp as string = comp_strings(.comp)
      IF .editstate = 5 THEN  'state 5 simulates LEN(newcomp) = 0
       .editstate = 1
      ELSEIF LEN(newcomp) = 1 THEN
       IF .editstate = 2 THEN
        .editstate = 1
       ELSEIF .editstate = 4 THEN
        .editstate = 5
       END IF
      ELSE 'LEN = 2
       .comp = a_findcasei(comp_strings(), LEFT(newcomp, 1))
      END IF
     ELSE
      temp = 0
      'IF .editstate <> 2 THEN temp = .value
      'Don't erase previous value when trying to inc/decrement it
      IF keyval(ccLeft) > 0 OR keyval(ccRight) > 0 THEN temp = .value
      IF intgrabber(temp, -2147483648, 2147483647, , , YES) THEN
       .value = temp
       .editstate = 3
      END IF
     END IF
   END SELECT
  END IF

 END WITH

 'FIXME: check if anything changed, and return YES if so
END FUNCTION

'default: meaning of the null condition (true: ALWAYS, false: NEVER)
SUB cond_editor (cond as Condition, default as bool = NO, outer_state as MenuState)
 DIM menu(10) as string
 DIM compty(10) as integer  'CompType (can't pass that to a_find)
 menu(0)  = "Cancel"
 menu(1)  = "Always"
 menu(2)  = "Never"
 menu(3)  = "Tag # ON"        : compty(3)  = compTag
 menu(4)  = "Tag # OFF"       : compty(4)  = compTag
 menu(5)  = "Global # = #"    : compty(5)  = compEq
 menu(6)  = "Global # <> #"   : compty(6)  = compNe
 menu(7)  = "Global # < #"    : compty(7)  = compLt
 menu(8)  = "Global # <= #"   : compty(8)  = compLe
 menu(9)  = "Global # > #"    : compty(9)  = compGt
 menu(10) = "Global # >= #"   : compty(10) = compGe

 DIM st as MenuState
 st.last = UBOUND(menu)
 st.size = st.last + 1
 DIM starttag as integer = 1

 ' Determine initial menu selection
 IF cond.comp = compTag AND cond.tag = 0 THEN cond.comp = compNone
 IF cond.comp = compNone THEN
  st.pt = IIF(default, 1, 2)
 ELSEIF cond.comp = compTag THEN
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
 ELSE
  st.pt = a_find(compty(), cond.comp)
  IF st.pt = -1 THEN st.pt = 1   'If cond.comp is invalid
 END IF

 DIM menuopts as MenuOptions
 menuopts.wide = 13 * 8  ' Minimum width
 menuopts.calc_size = YES

 ' Position to draw the menu (calculated next)
 DIM mpos as XYPair = (60, 0)

 ' Precompute the menu size
 calc_menustate_size st, menuopts, mpos.x, mpos.y, vpage

 ' Calculate screen position of the outer menu
 ' (Note: MenuState doesn't tell where the menu will be drawn; we have to assume 0,0!)
 WITH outer_state
  ' Position the new menu so that the initially selected menu item
  ' is at the same y position as the current item in the previous menu
  mpos.y = (.pt - .top) * .spacing - (st.pt - st.top) * st.spacing
  ' Make sure the new position is fully onscreen (and leave extra space at the bottom of the screen)
  mpos.y = bound(mpos.y, 0, vpages(vpage)->h - .spacing)
  IF mpos.y + st.rect.high > vpages(vpage)->h - 15 THEN mpos.y -= st.rect.high - st.spacing
 END WITH

 DIM holdpage as integer = allocatepage
 copypage vpage, holdpage

 DO
  setwait 55
  setkeys
  IF keyval(ccCancel) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "cond_editor"

  ' Typing a number could be any type. Select what's under the cursor
  IF compty(st.pt) <> 0 AND INSTR(getinputtext, ANY "0123456789") > 0 THEN
   cond.comp = compty(st.pt)
   cond.varnum = 0  'Clear ID so you can type it in
   cond.editstate = 6  'Editing global ID. Also valid editstate for tags.
   EXIT DO
  END IF

  ' If you start typing a relation, exit to cond_grabber which will handle it
  ' FIXME: regardless of editstate, the cond_grabber ignores the keypress
  IF INSTR(getinputtext, ANY "=<>!") > 0 THEN
   IF cond.comp = compTag OR cond.comp = compNone THEN cond.comp = compEq
   cond.editstate = 6
   EXIT DO
  END IF

  ' Exit on TAB so that you simultaneously change to the selected comparison
  ' and cond_grabber processes the TAB.
  ' Also, press TAB to select a tag option but skip the tag browser.
  IF enter_space_click(st) OR keyval(scTab) > 1 THEN
   IF compty(st.pt) THEN cond.comp = compty(st.pt)
   SELECT CASE st.pt
    CASE 0:
     EXIT DO
    CASE 1:
     IF default THEN
      cond.comp = compNone
     ELSE
      cond.comp = compTag
      cond.tag = -1
     END IF
    CASE 2:
     IF default = NO THEN
      cond.comp = compNone
     ELSE
      cond.comp = compTag
      cond.tag = 1
     END IF
    CASE 3, 4:
     IF st.pt = 4 THEN starttag *= -1  'tag=OFF
     IF keyval(scTab) > 1 THEN
      cond.tag = starttag
     ELSE
      cond.tag = tags_menu(starttag, YES, YES)
     END IF
    CASE ELSE:
     'TODO: global variable browser
     cond.editstate = 6  'start by entering global variable number
   END SELECT
   EXIT DO
  END IF

  usemenu st

  copypage holdpage, vpage
  edgeboxstyle mpos.x - 5, mpos.y - 5, st.rect.wide + 10, st.rect.high + 10, 2, vpage
  DIM msg as string
  IF compty(st.pt) = compNone THEN
  ELSEIF compty(st.pt) = compTag THEN
   msg = "ENTER to pick tag/TAB confirm"
  ELSE
   msg = "Type expression, TAB to switch"
  END IF
  edgeprint "F1 Help  " + msg, pLeft, pBottom, uilook(uiText), vpage
  standardmenu menu(), st, mpos.x, mpos.y, vpage, menuopts
  setvispage vpage
  dowait
 LOOP
 freepage holdpage
END SUB

'Returns a printable representation of a Condition with lots of ${K} colours
'default: the text displayed for a null Condition
'selected: whether this menu item is selected
'wide: max string length to return (not implemented yet)
FUNCTION condition_string (cond as Condition, selected as bool, default as string = "Always", wide as integer = 40) as string
 DIM ret as string = default
 DIM hlcol as integer = uilook(uiHighlight2)

 IF selected = NO THEN
  cond.editstate = 0
  cond.lastinput = 0
 ELSEIF cond.editstate = 0 THEN
  ' Set initial edit state to highlight the relevant part
  IF cond.comp = compTag THEN
   cond.editstate = 1
  ELSEIF cond.comp <> compNone THEN
   cond.editstate = 6   ' Initially, the global ID is edited
  END IF
 END IF

 IF cond.comp = compNone THEN
 ELSEIF cond.comp = compTag THEN
  IF cond.tag = 0 THEN
  ELSE
   IF cond.editstate = 0 THEN
    ret = "Tag " & ABS(cond.tag)
   ELSE
    ret = "Tag " & hilite(STR(ABS(cond.tag)), hlcol)
   END IF
   ret += IIF(cond.tag >= 0, "=ON", "=OFF")
   IF cond.tag = 1 THEN
    ret += " [Never]"
   ELSEIF cond.tag = -1 THEN
    ret += " [Always]"
   ELSE
    ret += " (" & load_tag_name(ABS(cond.tag)) & ")"
   END IF
  END IF
 ELSEIF cond.comp >= compEq AND cond.comp <= compGe THEN
  SELECT CASE cond.editstate
   CASE 0
    ret = "Global #" & cond.varnum & " " & comp_strings(cond.comp) & " " & cond.value
   CASE 1
    ret = "Global #" & hilite(str(cond.varnum), hlcol)
   CASE 2
    ret = "Global #" & cond.varnum & " " & hilite(comp_strings(cond.comp), hlcol)
   CASE 3
    ret = "Global #" & cond.varnum & " " & comp_strings(cond.comp) & hilite(" " & cond.value, hlcol)
   CASE 4
    ret = "Global #" & cond.varnum & " " & hilite(comp_strings(cond.comp), hlcol) & " " & cond.value
   CASE 5
    'FIXME: a tag for text background colour hasn't been implemented yet
    ret = "Global #" & cond.varnum & hilite(" ? ", hlcol) & cond.value
   CASE 6
    ret = "Global #" & hilite(cond.varnum & " ", hlcol) & comp_strings(cond.comp) & " " & cond.value
  END SELECT
 ELSE
  ret = "[Corrupt condition data]"
 END IF

 IF selected THEN
  ' Provide an indication that you can press Enter
  ret += "..."
 END IF

 RETURN ret
END FUNCTION


'==========================================================================================
'                                      Percent conditions
'==========================================================================================

'Return initial representation string for percent_cond_grabber
FUNCTION format_percent_cond(cond as AttackElementCondition, default as string, byval decimalplaces as integer = 4) as string
 IF cond.comp = compNone THEN
  RETURN default
 ELSE
  RETURN " " + comp_strings(cond.comp) + " " + format_percent(cond.value, decimalplaces)
 END IF
END FUNCTION

'This will probably only be used for editing AttackElementConditions, but it's more general than that.
'Returns whether cond was edited. If ret_if_repr_changed, also returns true if repr changed.
FUNCTION percent_cond_grabber(byref cond as AttackElementCondition, byref repr as string, default as string, byval min as double, byval max as double, byval decimalplaces as integer = 4, ret_if_repr_changed as bool = YES) as bool
 WITH cond
  DIM intxt as string = getinputtext
  DIM newcomp as CompType = .comp
  DIM oldrepr as string = repr
  DIM ret as bool

  IF keyval(scDelete) > 1 THEN newcomp = compNone

  'Listen for comparison operator input
  IF INSTR(intxt, "<") THEN newcomp = compLt
  IF INSTR(intxt, ">") THEN newcomp = compGt

  IF newcomp <> .comp THEN
   IF .comp = compNone THEN .value = 0
   .comp = newcomp
   repr = format_percent_cond(cond, default, decimalplaces)
   ret = YES
  ELSEIF .comp = compNone THEN
   DIM temp as string = "0%"
   .value = 0
   'typing 0 doesn't change the value or repr, workaround
   IF percent_grabber(.value, temp, min, max, decimalplaces, NO) OR INSTR(intxt, "0") > 0 THEN
    repr = " < " + temp  'Default
    .comp = compLt
    ret = YES
   END IF
  ELSE
   'Trim comparison operator
   repr = MID(repr, 4)
   IF keyval(scBackspace) > 1 ANDALSO repr = "0%" THEN
    repr = default
    .comp = compNone
    ret = YES
   ELSE
    ret OR= percent_grabber(.value, repr, min, max, decimalplaces, NO)
    'Add the operator back
    repr = " " + comp_strings(.comp) + " " + repr
   END IF
  END IF

  IF ret_if_repr_changed THEN ret OR= (repr <> oldrepr)
  RETURN ret
 END WITH
END FUNCTION

SUB percent_cond_editor (cond as AttackElementCondition, byval min as double, byval max as double, byval decimalplaces as integer = 4, do_what as string = "...", percent_of_what as string = "")
 DIM cond_types(2) as CompType = {compNone, compLt, compGt}
 DIM comp_num as CompType
 FOR i as integer = 0 TO 2
  IF cond.comp = cond_types(i) THEN comp_num = i
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
  IF keyval(ccCancel) > 1 OR enter_space_click(st) THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "percent_cond_editor"
  SELECT CASE st.pt
   CASE 1: IF intgrabber(comp_num, 0, 2) THEN cond.comp = cond_types(comp_num)
   CASE 2: percent_grabber(cond.value, repr, min, max, decimalplaces)
  END SELECT

  'Update
  IF cond.comp = compNone THEN menu(1) = "Condition: Never"
  IF cond.comp = compGt THEN menu(1) = "Condition: " + do_what + " when more than..."
  IF cond.comp = compLt THEN menu(1) = "Condition: " + do_what + " when less than..."
  menu(2) = "Threshold: " + repr + percent_of_what
  st.last = IIF(cond.comp = compNone, 1, 2)

  usemenu st

  clearpage vpage
  standardmenu menu(), st, 0, 0, vpage
  setvispage vpage
  dowait
 LOOP
END SUB


'==========================================================================================
'                                       Test menu
'==========================================================================================

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
  setkeys YES
  IF keyval(ccCancel) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "condition_test"
  tmp = 0
  IF st.pt = 0 THEN
   IF enter_space_click(st) THEN EXIT DO
  ELSEIF st.pt = 2 THEN
   tmp = cond_grabber(cond1, YES , NO, st)
  ELSEIF st.pt = 3 THEN
   tmp = cond_grabber(cond2, NO, NO, st)
  ELSEIF st.pt = 5 THEN
   tmp = cond_grabber(cond3, YES, YES, st)
  ELSEIF st.pt = 6 THEN
   tmp = cond_grabber(cond4, NO, YES, st)
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
