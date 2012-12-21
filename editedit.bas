'OHRRPGCE CUSTOM - Editor Editor
'(C) Copyright 2010 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Except, this module APOLOGISES FOR NOTHING!
'

#ifdef LANG_DEPRECATED
 #define __langtok #lang
 __langtok "deprecated"
 OPTION STATIC
 OPTION EXPLICIT
#endif

#include "config.bi"
#include "allmodex.bi"
#include "common.bi"
#include "slices.bi"
#include "customsubs.bi"
#include "loading.bi"
#include "reload.bi"
#include "reloadext.bi"
#include "editrunner.bi"

#include "editedit.bi"

USING Reload
USING Reload.Ext

'-----------------------------------------------------------------------

TYPE EEState
 state AS MenuState
 menu AS MenuDef
 indent AS INTEGER
 doc AS DocPtr
 root AS NodePtr
 seek_widget AS NodePtr
 clipboard AS NodePtr
 clipboard_is AS NodePtr
 filename AS STRING
 changed AS INTEGER
END TYPE

TYPE WEStateF AS WEState
TYPE WidgetRefreshSub AS SUB(BYREF st AS WEStateF, BYVAL widget AS Nodeptr)

TYPE WidgetCode
 refresh_callback AS WidgetRefreshSub
END TYPE

TYPE WEState
 state AS MenuState
 menu AS MenuDef
 changed AS INTEGER
 code AS WidgetCode
END TYPE

'-----------------------------------------------------------------------

DECLARE SUB ee_create_new_editor_file(BYREF st AS EEState)
DECLARE SUB ee_refresh OVERLOAD (BYREF st AS EEState)
DECLARE SUB ee_refresh OVERLOAD (BYREF st AS EEState, BYVAL widget AS NodePtr)
DECLARE FUNCTION ee_widget_string(BYREF st AS EEState, BYVAL widget AS Nodeptr) AS STRING
DECLARE SUB ee_focus_widget(BYREF st AS EEState, BYVAL widget AS Nodeptr)
DECLARE SUB ee_export(BYREF st AS EEState)
DECLARE FUNCTION ee_browse(BYREF st AS EEState) AS INTEGER
DECLARE FUNCTION ee_load(filename AS STRING, BYREF st AS EEState) AS INTEGER
DECLARE SUB ee_save(filename AS STRING, BYREF st AS EEState)
DECLARE FUNCTION ee_okay_to_unload(BYREF st AS EEState) AS INTEGER
DECLARE SUB ee_insertion(BYREF st AS EEState, BYVAL widget AS Nodeptr)
DECLARE SUB ee_rearrange(BYREF st AS EEState, mi AS MenuDefItem Ptr)
DECLARE SUB ee_swap_widget_up(BYVAL widget AS Nodeptr)
DECLARE SUB ee_swap_widget_down(BYVAL widget AS Nodeptr)
DECLARE SUB ee_swap_widget_left(BYVAL widget AS Nodeptr)
DECLARE SUB ee_swap_widget_right(BYVAL widget AS Nodeptr)
DECLARE SUB ee_edit_menu_item(BYREF st AS EEState, mi AS MenuDefItem Ptr)
DECLARE FUNCTION ee_edit_widget(BYREF st AS EEState, BYVAL widget AS NodePtr) AS INTEGER

DECLARE FUNCTION ee_prompt_for_widget_kind() AS STRING
DECLARE FUNCTION ee_create_widget(BYREF st AS EEState, kind AS STRING) AS NodePtr
DECLARE FUNCTION ee_container_check(BYVAL cont AS NodePtr, BYVAL widget AS NodePtr) AS INTEGER
DECLARE FUNCTION ee_widget_has_caption(BYVAL widget AS NodePtr) AS INTEGER

DECLARE FUNCTION widget_editor(BYVAL widget AS NodePtr) AS INTEGER
DECLARE SUB widget_editor_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)

DECLARE SUB ee_get_widget_code(BYREF code AS WidgetCode, BYVAL widget AS NodePtr)

'-----------------------------------------------------------------------

SUB editor_editor()
 DIM st AS EEState
 
 st.changed = NO
 st.doc = CreateDocument()
 st.root = CreateNode(st.doc, "")
 SetRootNode(st.doc, st.root)
 ee_create_new_editor_file st
  
 st.state.pt = 0
 st.state.need_update = YES
 st.state.active = YES

 ClearMenuData st.menu
 WITH st.menu
  .anchor.x = -1
  .anchor.y = -1
  .offset.x = -160
  .offset.y = -100
  .bordersize = -4
  .align = -1
  .maxrows = 18
 END WITH
 
 setkeys YES
 DO
  setwait 55
  setkeys YES

  IF st.state.need_update THEN
   DeleteMenuItems st.menu
   st.indent = 0
   ee_refresh st
   init_menu_state st.state, st.menu
   IF st.seek_widget THEN
    ee_focus_widget st, st.seek_widget
    st.seek_widget = 0
   END IF
   st.state.need_update = NO
  END IF
  
  IF keyval(scESC) > 1 THEN
   IF ee_okay_to_unload(st) THEN EXIT DO 
  END IF
  IF keyval(scF1) > 1 THEN show_help("editor_editor")
  IF keyval(scF3) > 1 THEN
   IF ee_okay_to_unload(st) THEN
    IF ee_browse(st) THEN
     setkeys YES
     st.state.need_update = YES
    END IF
   END IF
  END IF
  IF keyval(scF2) > 1 THEN
   ee_export st
  END IF
  IF keyval(scF5) > 1 THEN
   editor_runner st.root
  END IF

  IF st.state.pt >= 0 AND st.state.pt <= st.menu.numitems - 1 THEN
   ee_edit_menu_item st, st.menu.items[st.state.pt]
   ee_rearrange st, st.menu.items[st.state.pt]
  ELSE
   ee_insertion st, 0
  END IF

  IF keyval(scShift) = 0 THEN
   usemenu st.state
  END IF

  clearpage dpage
  draw_menu st.menu, st.state, dpage
  edgeprint "F1=Help", 0, 190, uilook(uiText), dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 IF st.clipboard <> 0 THEN FreeNode(st.clipboard)
 FreeDocument(st.doc)
 
END SUB

'-----------------------------------------------------------------------

SUB ee_create_new_editor_file(BYREF st AS EEState)
 RenameNode st.root, "editor"
 AppendChildNode st.root, "datafile"
 AppendChildNode st.root, "recordnode"
 AppendChildNode st.root, "enums"
 AppendChildNode st.root, "widgets"
END SUB

SUB ee_edit_menu_item(BYREF st AS EEState, mi AS MenuDefItem Ptr)
 IF mi = 0 THEN debug "ee_edit_menu_item: null mi": EXIT SUB
 DIM widget AS NodePtr
 widget = mi->dataptr
 IF widget = 0 THEN debug "ee_edit_menu_item: mi has null widget node": EXIT SUB

 IF ee_edit_widget(st, widget) THEN
  mi->caption = STRING(mi->extra(0), " ") & ee_widget_string(st, widget)
  st.changed = YES
 END IF

END SUB

FUNCTION ee_edit_widget(BYREF st AS EEState, BYVAL widget AS NodePtr) AS INTEGER
 IF widget = 0 THEN debug "ee_edit_widget: null widget" : RETURN NO

 DIM changed AS INTEGER = NO

 IF ee_widget_has_caption(widget) THEN
  DIM cap AS STRING
  cap = GetChildNodeStr(widget, "caption")
  IF strgrabber(cap, 40) THEN
   IF cap = "" THEN
    SetChildNode(widget, "caption")
   ELSE
    SetChildNode(widget, "caption", cap)
   END IF
   changed = YES
  END IF
 END IF
 
 IF keyval(scEnter) > 1 THEN
  IF widget_editor(widget) THEN
   changed = YES
  END IF
 END IF
 
 RETURN changed
END FUNCTION

SUB ee_insertion(BYREF st AS EEState, BYVAL widget AS Nodeptr)
 IF keyval(scInsert) > 1 THEN
 DIM kind AS STRING
  kind = ee_prompt_for_widget_kind()
  IF kind <> "" THEN
   DIM newnode AS Nodeptr
   newnode = ee_create_widget(st, kind)
   IF widget THEN
    AddSiblingAfter widget, newnode
   ELSE
    DIM node AS Nodeptr
    node = NodeByPath(st.root, "/widgets")
    IF node = 0 THEN
     debuginfo "unable to find /widgets container node!"
     EXIT SUB
    END IF
    AddChild node, newnode
   END IF
   st.seek_widget = newnode
   st.changed = YES
   st.state.need_update = YES
  END IF
 END IF
END SUB

SUB ee_rearrange(BYREF st AS EEState, mi AS MenuDefItem Ptr)
 DIM widget AS Nodeptr
 widget = mi->dataptr
 
 DIM changed AS INTEGER = NO

 ee_insertion st, widget

 IF keyval(scShift) > 0 THEN
  IF copy_keychord() THEN
   '--copy this widget
   IF st.clipboard <> 0 THEN FreeNode(st.clipboard)
   st.clipboard = CloneNodeTree(widget)
   st.clipboard_is = widget
   changed = YES
  END IF
  IF paste_keychord() THEN
   '--paste this widget
   IF st.clipboard <> 0 THEN
    AddSiblingAfter(widget, CloneNodeTree(st.clipboard))
    IF NodeHasAncestor(widget, st.clipboard_is) THEN st.clipboard_is = 0 'cosmetic importance only
    changed = YES
   END IF
  END IF
 END IF
 
 IF keyval(scShift) > 0 THEN
  IF keyval(scUP) > 1 THEN
   ee_swap_widget_up widget
   st.seek_widget = widget
   changed = YES
  END IF
  IF keyval(scDOWN) > 1 THEN
   ee_swap_widget_down widget
   st.seek_widget = widget
   changed = YES
  END IF
  IF keyval(scLEFT) > 1 THEN
   ee_swap_widget_left widget
   st.seek_widget = widget
   changed = YES
  END IF
  IF keyval(scRIGHT) > 1 THEN
   ee_swap_widget_right widget
   st.seek_widget = widget
   changed = YES
  END IF
 END IF
 
 IF keyval(scDelete) > 1 THEN
  IF yesno("Delete this widget?" & CHR(10) & ee_widget_string(st, widget)) THEN
   FreeNode(widget)
   changed = YES
  END IF
 END IF
 
 IF changed THEN
  st.state.need_update = YES
  st.changed = YES
 END IF
END SUB

SUB ee_swap_widget_up(BYVAL widget AS Nodeptr)
 IF widget = 0 THEN EXIT SUB
 DIM sib AS NodePtr
 sib = PrevSibling(widget, "widget")
 IF sib = 0 THEN EXIT SUB
 SwapSiblingNodes(widget, sib)
END SUB

SUB ee_swap_widget_down(BYVAL widget AS Nodeptr)
 IF widget = 0 THEN EXIT SUB
 DIM sib AS NodePtr
 sib = NextSibling(widget, "widget")
 IF sib = 0 THEN EXIT SUB
 SwapSiblingNodes(widget, sib)
END SUB

SUB ee_swap_widget_left(BYVAL widget AS Nodeptr)
 IF widget = 0 THEN EXIT SUB
 DIM parent AS NodePtr
 parent = NodeParent(widget)
 IF parent = 0 THEN EXIT SUB
 AddSiblingAfter(parent, widget)
END SUB

SUB ee_swap_widget_right(BYVAL widget AS Nodeptr)
 IF widget = 0 THEN EXIT SUB
 DIM sib AS NodePtr
 sib = PrevSibling(widget, "widget")
 IF sib = 0 THEN EXIT SUB
 IF ee_container_check(sib, widget) = NO THEN EXIT SUB
 AddChild(sib, widget)
END SUB

SUB ee_refresh (BYREF st AS EEState)
 DIM widgets_container AS NodePtr
 widgets_container = NodeByPath(st.doc, "/widgets")
 IF widgets_container = 0 THEN EXIT SUB
 DIM widget AS NodePtr
 widget = FirstChild(widgets_container, "widget")
 DO WHILE widget
  ee_refresh st, widget
  widget = NextSibling(widget, "widget")
 LOOP
END SUB

SUB ee_refresh (BYREF st AS EEState, BYVAL widget AS NodePtr)
 IF widget = 0 THEN EXIT SUB

 IF widget = 0 THEN
  EXIT SUB
 END IF

 DIM s AS STRING
 s = STRING(st.indent, " ") & ee_widget_string(st, widget)
 
 DIM index AS INTEGER
 index = append_menu_item(st.menu, s)
 
 DIM mi AS MenuDefItem Ptr
 mi = st.menu.items[index]

 mi->dataptr = widget
 mi->extra(0) = st.indent

 st.indent += 1 
 DIM chnode AS Nodeptr
 chnode = FirstChild(widget, "widget")
 DO WHILE chnode
  ee_refresh st, chnode
  chnode = NextSibling(chnode, "widget")
 LOOP
 st.indent -= 1
END SUB

FUNCTION ee_widget_string(BYREF st AS EEState, BYVAL widget AS Nodeptr) AS STRING
 IF widget = 0 THEN debug "ee_widget_string: null node" : RETURN "<null ptr>"
 DIM s AS STRING = ""
 IF widget = st.clipboard_is OR NodeHasAncestor(widget, st.clipboard_is) then s &= "*"
 s &= "<" & GetString(widget) & ">" & GetChildNodeStr(widget, "caption", "")
 RETURN s
END FUNCTION

SUB ee_focus_widget(BYREF st AS EEState, BYVAL widget AS Nodeptr)
 DIM mi AS MenuDefItem Ptr
 DIM n AS Nodeptr
 FOR i AS INTEGER = 0 TO st.menu.numitems - 1
  mi = st.menu.items[i]
  n = mi->dataptr
  IF n = widget THEN
   st.state.pt = i
   EXIT FOR
  END IF
 NEXT i
 WITH st.state
  .pt = small(.pt, .last)
  .top = bound(.top, .pt - .size, .pt)
 END WITH
END SUB

SUB ee_export(BYREF st AS EEState)
 DIM outfile AS STRING
 outfile = inputfilename("Export editor definition", "", "", "input_file_export_ee", st.filename)
 IF outfile <> "" THEN
  IF INSTR(outfile, ".") = 0 THEN outfile &= ".editor"
  ee_save outfile, st
 END IF
END SUB

FUNCTION ee_browse(BYREF st AS EEState) AS INTEGER
 DIM filename AS STRING
 filename = browse(0, "", "*.editor", "",, "browse_import_ee")
 IF filename = "" THEN RETURN NO
 RETURN ee_load(filename, st)
END FUNCTION

FUNCTION ee_load(filename AS STRING, BYREF st AS EEState) AS INTEGER
 st.filename = ""
 FreeDocument st.doc
 st.doc = LoadDocument(filename)
 IF st.doc = 0 THEN debug "load '" & filename & "' failed: null doc": RETURN NO
 st.root = DocumentRoot(st.doc)
 IF st.root = 0 THEN debug "load '" & filename & "' failed: null root node": RETURN NO
 st.filename = trimpath(filename)
 st.changed = NO
 RETURN YES
END FUNCTION

SUB ee_save(filename AS STRING, BYREF st AS EEState)
 SerializeBin(filename, st.doc)
 st.filename = trimpath(filename)
 st.changed = NO
END SUB

FUNCTION ee_okay_to_unload(BYREF st AS EEState) AS INTEGER
 IF st.changed = NO THEN RETURN YES
 DIM choice AS INTEGER
 'Prevent attempt to quit the program, stop and wait for response first
 DIM quitting as integer = keyval(-1)
 clearkey(-1)
 choice = twochoice("Save your changes before exiting?", "Yes, save", "No, discard")
 IF keyval(-1) THEN choice = 1  'Second attempt to close the program: discard
 SELECT CASE choice
  CASE -1: 'cancelled
   RETURN NO
  CASE 0: 'yes, save!
   ee_export st
   'but only actually allow unload if the save was confirmed
   IF st.changed = NO THEN
    IF quitting THEN setquitflag
    RETURN YES
   END IF
   RETURN NO
  CASE 1: 'no discard!
   IF quitting THEN setquitflag
   RETURN YES
 END SELECT
 RETURN NO
END FUNCTION

'-----------------------------------------------------------------------
'an object oriented callback system might be better than these functions
'...maybe... maybe not worth it... Why bend over backwards to make FB
'act like something it isn't... haven't decided for sure yet.
'
'It is sort of a balancing act. Do I want to update each of the subs and
'functions below each time I add a widget type? Or do I want to update
'a set of fake-object-oriented callbacks like the ones in slices.bas
'with their associated boilerplate? Which is more work?
'
'Maybe the hybrid approach?

FUNCTION ee_prompt_for_widget_kind() AS STRING
 STATIC last_kind AS INTEGER = 0
 DIM w(13) AS STRING
 w(0) = "int"
 w(1) = "string"
 w(2) = "label"
 w(3) = "bit"
 w(4) = "submenu"
 w(5) = "picture"
 w(6) = "item"
 w(7) = "attack"
 w(8) = "textbox"
 w(9) = "tag"
 w(10) = "tagcheck"
 w(11) = "array"
 w(12) = "maybe"
 w(13) = "exclusive"
 DIM choice AS INTEGER
 choice = multichoice("Inset which kind of widget?", w(), last_kind, , "ee_prompt_for_widget_kind")
 IF choice = -1 THEN RETURN ""
 last_kind = choice
 RETURN w(choice)
END FUNCTION

FUNCTION ee_create_widget(BYREF st AS EEState, kind AS STRING) AS NodePtr
 DIM widget AS NodePtr
 widget = CreateNode(st.doc, "widget")
 SetContent(widget, kind)
 '--If any widget kind had any strictly mandatory sub-nodes, we could add them here...
 '  ...but I am not sure we will actually have any of those.
 SELECT CASE kind
  CASE "int":
  CASE "string":
  CASE "label":
  CASE "bit":
  CASE "submenu":
  CASE "picture":
  CASE "item":
  CASE "attack":
  CASE "textbox":
  CASE "tag":
  CASE "tagcheck":
  CASE "array":
  CASE "maybe":
  CASE "exclusive":
  CASE ELSE
   debug "Oops! Created a widget of kind """ & kind & """, but we have no idea what that is!"
 END SELECT
 RETURN widget
END FUNCTION

FUNCTION ee_container_check(BYVAL cont AS NodePtr, BYVAL widget AS NodePtr) AS INTEGER
 IF cont = 0 THEN RETURN NO
 IF widget = 0 THEN RETURN NO
 SELECT CASE GetString(cont)
  CASE "submenu": RETURN YES
  CASE "array": RETURN YES
  CASE "maybe": RETURN YES
  CASE "exclusive": RETURN YES
 END SELECT
 RETURN NO
END FUNCTION

FUNCTION ee_widget_has_caption(BYVAL widget AS NodePtr) AS INTEGER
 'True for widgets that use a caption node.
 IF widget = 0 THEN RETURN NO
 SELECT CASE GetString(widget)
  CASE "array": RETURN NO
  CASE "maybe": RETURN NO
  CASE "exclusive": RETURN NO
 END SELECT
 RETURN YES
END FUNCTION

FUNCTION ee_widget_has_data(BYVAL widget AS NodePtr) AS INTEGER
 'True for widgets that use a data node
 IF widget = 0 THEN RETURN NO
 SELECT CASE GetString(widget)
  CASE "label": RETURN NO
  CASE "submenu": RETURN NO
  CASE "maybe": RETURN NO
  CASE "exclusive": RETURN NO
 END SELECT
 RETURN YES
END FUNCTION

'-----------------------------------------------------------------------

FUNCTION widget_editor(BYVAL widget AS NodePtr) AS INTEGER

 DIM st AS WEState
 
 st.changed = NO

 st.state.pt = 1
 st.state.need_update = YES
 st.state.active = YES

 ClearMenuData st.menu
 WITH st.menu
  .anchor.x = 0
  .anchor.y = 0
  .offset.x = 0
  .offset.y = 0
  .bordersize = -4
  .align = -1
  .maxrows = 18
 END WITH
 
 ee_get_widget_code(st.code, widget)
 
 setkeys YES
 DO
  setwait 55
  setkeys YES

  IF st.state.need_update THEN
   DeleteMenuItems st.menu
   widget_editor_refresh st, widget
   init_menu_state st.state, st.menu
   st.state.need_update = NO
  END IF
  
  IF keyval(scESC) > 1 THEN
   EXIT DO 
  END IF
  IF keyval(scF1) > 1 THEN show_help("widget_editor")

  IF st.state.pt >= 0 AND st.state.pt <= st.menu.numitems - 1 THEN
   'ee_edit_menu_item st, st.menu.items[st.state.pt]
  END IF
  
  IF keyval(scShift) = 0 THEN
   usemenu st.state
  END IF

  clearpage dpage
  draw_menu st.menu, st.state, dpage
  edgeprint "F1=Help", 0, 190, uilook(uiText), dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 RETURN NO 
END FUNCTION

SUB widget_editor_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)
 DIM index AS INTEGER
 append_menu_item(st.menu, "Done Editing this Widget...")
 IF ee_widget_has_caption(widget) THEN
  append_menu_item(st.menu, "Caption:" & GetChildNodeStr(widget, "caption"))
 END IF
 IF ee_widget_has_data(widget) THEN
  append_menu_item(st.menu, "Data Node:" & GetChildNodeStr(widget, "data"))
 END IF
 st.code.refresh_callback(st, widget)
END SUB

'#######################################################################

SUB null_widget_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)
 'for widgets that don't have any extra properties.
END SUB

SUB int_widget_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)
 append_menu_item(st.menu, "Max:" & zero_default(GetChildNodeInt(widget, "max")))
 append_menu_item(st.menu, "Min:" & zero_default(GetChildNodeInt(widget, "min")))
 append_menu_item(st.menu, "Enum:" & GetChildNodeStr(widget, "enum"))
 append_menu_item(st.menu, "Optional:" & yesorno(GetChildNodeBool(widget, "optional")))
 append_menu_item(st.menu, "Zero Default:" & yesorno(GetChildNodeBool(widget, "zerodefault")))
 append_menu_item(st.menu, "-1 Default:" & yesorno(GetChildNodeBool(widget, "neg1default")))
END SUB

SUB picture_widget_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)
 append_menu_item(st.menu, "Size Group:" & GetChildNodeInt(widget, "sizegroup"))
 append_menu_item(st.menu, "Save Size:" & yesorno(GetChildNodeBool(widget, "savesize")))
END SUB

SUB tagcheck_widget_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)
 append_menu_item(st.menu, "Default Description:" & GetChildNodeStr(widget, "default"))
END SUB

SUB array_widget_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)
 append_menu_item(st.menu, "Count:" & zero_default(GetChildNodeInt(widget, "count"), "variable length"))
 append_menu_item(st.menu, "Key:" & GetChildNodeStr(widget, "key"))
 append_menu_item(st.menu, "Enum:" & GetChildNodeStr(widget, "enum"))
END SUB

SUB maybe_widget_refresh(BYREF st AS WEState, BYVAL widget AS NodePtr)
 append_menu_item(st.menu, "Hide:" & yesorno(GetChildNodeBool(widget, "hide")))
END SUB

'-----------------------------------------------------------------------
'#######################################################################

'--this is at the end of the file because I want to be lazy and not bother
'  with separate declares for each of the callbacks above.
SUB ee_get_widget_code(BYREF code AS WidgetCode, BYVAL widget AS NodePtr)
 WITH code
  .refresh_callback = @null_widget_refresh

  IF widget = 0 THEN EXIT SUB
  DIM kind AS STRING
  kind = GetString(widget)
  
  SELECT CASE kind
   CASE "int":
    .refresh_callback = @int_widget_refresh
   CASE "string":
   CASE "label":
   CASE "bit":
   CASE "picture":
    .refresh_callback = @picture_widget_refresh
   CASE "item":
   CASE "attack":
   CASE "tagcheck":
    .refresh_callback = @tagcheck_widget_refresh
   CASE "tag":
   CASE "array":
    .refresh_callback = @array_widget_refresh
   CASE "maybe":
    .refresh_callback = @maybe_widget_refresh
  END SELECT
 END WITH
END SUB
