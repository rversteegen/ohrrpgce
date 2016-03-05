#ifndef SLICES_BI
#define SLICES_BI
'OHRRPGCE GAME - Slice related functionality
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Except, this module isn't very crappy

#include "udts.bi"
#include "common.bi"
#include "reload.bi"

CONST ENABLE_SLICE_DEBUG = NO

'These constants also need to be updated in slices.bas and plotscr.hsd
'and plotdict.xml. You may choose to just update them here and then run
' misc/sl_lookup.py
'to update the other files. Be aware that once you have picked a number
'for one of these, you should not change it, because it could get used
'as a constant in someone's script, and changing it would break any
'non-recompiled script that used it.

'<SLICE LOOKUP CODES>
CONST SL_ROOT                 = -100000
CONST SL_TEXTBOX_TEXT         = -100001
CONST SL_TEXTBOX_PORTRAIT     = -100002
CONST SL_TEXTBOX_CHOICE0      = -100003
CONST SL_TEXTBOX_CHOICE1      = -100004
CONST SL_TEXTBOX_BOX          = -100016
CONST SL_TEXTBOX_PORTRAIT_BOX = -100017
CONST SL_TEXTBOX_CHOICE_BOX   = -100018
CONST SL_TEXTBOX_ROOT         = -100019
CONST SL_SCRIPT_LAYER         = -100005
CONST SL_TEXTBOX_LAYER        = -100006
CONST SL_STRING_LAYER         = -100007
CONST SL_MAPROOT              = -100008
CONST SL_OBSOLETE_OVERHEAD    = -100009
CONST SL_WALKABOUT_LAYER      = -100010
CONST SL_HERO_LAYER           = -100011
CONST SL_NPC_LAYER            = -100012
CONST SL_WALKABOUT_SPRITE_COMPONENT = -100013
CONST SL_WALKABOUT_SHADOW_COMPONENT = -100014
CONST SL_BACKDROP             = -100015
CONST SL_MAP_LAYER0           = -101000
CONST SL_MAP_LAYER1           = -101001
CONST SL_MAP_LAYER2           = -101002
CONST SL_MAP_LAYER3           = -101003
CONST SL_MAP_LAYER4           = -101004
CONST SL_MAP_LAYER5           = -101005
CONST SL_MAP_LAYER6           = -101006
CONST SL_MAP_LAYER7           = -101007
CONST SL_STATUS_PORTRAIT      = -102000
CONST SL_STATUS_WALKABOUT     = -102001
CONST SL_STATUS_BATTLESPRITE  = -102002
CONST SL_STATUS_PAGE_SELECT   = -102003
CONST SL_STATUS_STATLIST      = -102004
CONST SL_STATUS_HIDE_IF_NO_MP = -102005
CONST SL_STATUS_HIDE_IF_NO_LMP = -102006
CONST SL_STATUS_HIDE_IF_MAX_LEV = -102007
CONST SL_PLANK_HOLDER         = -102008
CONST SL_STATUS_HIDE_IF_NO_PORTRAIT = -102009
CONST SL_ITEM_ITEMLIST        = -102010
CONST SL_ITEM_EXITBUTTON      = -102011
CONST SL_ITEM_SORTBUTTON      = -102012
CONST SL_ITEM_TRASHBUTTON     = -102013
CONST SL_PLANK_MENU_SELECTABLE = -102014
CONST SL_SPELL_LISTLIST       = -102015
CONST SL_SPELL_SPELLLIST      = -102016
CONST SL_SPELL_HIDE_IF_NO_LIST = -102017
CONST SL_SPELL_CANCELBUTTON   = -102018
CONST SL_VIRTUAL_KEYBOARD_BUTTON     = -102019
CONST SL_VIRTUAL_KEYBOARD_BUTTONTEXT = -102020
CONST SL_VIRTUAL_KEYBOARD_SHIFT      = -102021
CONST SL_VIRTUAL_KEYBOARD_SYMBOLS    = -102022
CONST SL_VIRTUAL_KEYBOARD_SELECT     = -102023
CONST SL_VIRTUAL_KEYBOARD_ENTRYTEXT  = -102024
CONST SL_VIRTUAL_KEYBOARD_DEL        = -102025
CONST SL_VIRTUAL_KEYBOARD_ENTER      = -102026
'</SLICE LOOKUP CODES>

Enum SliceTypes
 slInvalid = -1
 slRoot = 0
 slSpecial
 slContainer
 slRectangle
 slSprite
 slText
 slMap
 slGrid
 slEllipse
 slScroll
 slSelect
 slPanel
End Enum

Enum AttachTypes
 slSlice
 slScreen
End Enum

Enum AutoSortModes
 slAutoSortNone
 slAutoSortCustom
 slAutoSortY
 slAutoSortTopY
 slAutoSortCenterY
 slAutoSortBottomY
End Enum

Enum FillModes
 sliceFillFull = 0
 sliceFillHoriz = 1
 sliceFillVert = 2
End Enum

'Also used for anchoring
Enum AlignTypes
 alignLeft = 0
 alignTop = 0
 alignMiddle = 1
 alignRight = 2
 alignBottom = 2
End Enum

Extern "C"
Type SliceFwd as Slice
Type SliceDraw as Sub(Byval as SliceFwd ptr, byval stupidPage as integer)
Type SliceDispose as Sub(Byval as SliceFwd ptr)
Type SliceClone as Sub(Byval as SliceFwd ptr, byval as SliceFwd ptr)
Type SliceSave as Sub(Byval as SliceFwd ptr, byval node as Reload.Nodeptr)
Type SliceLoad as Sub(Byval sl as SliceFwd ptr, byval node as Reload.Nodeptr)
Type SliceChildRefresh as Sub(Byval par as SliceFwd ptr, Byval ch as SliceFwd ptr)
Type SliceChildDraw as Sub(Byval s as SliceFwd ptr, Byval page as integer)
End Extern

TYPE Slice
  Parent as Slice Ptr
  FirstChild as Slice Ptr
  LastChild as Slice Ptr
  NextSibling as Slice Ptr
  PrevSibling as Slice Ptr
  NumChildren as integer
  
  X as integer 'the X,Y relative to whatever the slice is attached to
  Y as integer
  ScreenX as integer 'the actual X,Y, updated every frame
  ScreenY as integer
  Width as integer
  Height as integer
  Visible as bool
  Mobile as bool  'Whether to apply target and velocity movement to this slice tree (default true)
  Clip as bool
  
  'moving at a constant pixels-per-tick speed (direct setting should cancel targ)
  Velocity as XYPair
  'limit the number of cycles to apply velocity before auto-clearing it (-1 means forever, 0 clears instantly)
  VelTicks as XYPair

  'moving to a destination in constant time. (replaces velocity)
  Targ as XYPair
  TargResidue_X as double
  TargResidue_Y as double
  TargTicks as integer

  TableSlot as integer 'which slot in plotslices() holds a reference to this slice, or 0 for none
  Lookup as integer

  EditorColor as integer 'Not saved, used only by slice editor

  AutoSort as AutoSortModes
  Sorter as integer 'Only used by CustomSortChildSlices
  Extra(2) as integer

  AlignHoriz as AlignTypes  'Relative to parent. Only used when not filling
  AlignVert as AlignTypes   'Relative to parent. Only used when not filling
  AnchorHoriz as AlignTypes 'Relative to self. Only used when not filling
  AnchorVert as AlignTypes  'Relative to self. Only used when not filling
  
  as integer PaddingTop, PaddingLeft, PaddingRight, PaddingBottom

  ' Note that setting a slice to Fill causes its size to be modified, and its
  ' position to be ignored. This inconsistency is unfortunate. It also means
  ' the size of non-resizeable slices can be changed, which is a bug.
  Fill as bool
  FillMode as FillModes
  
  Attach as AttachTypes
  Union
   Attached as Slice ptr
  End Union
  
  Draw as SliceDraw
  Dispose as SliceDispose
  Clone as SliceClone
  Save as SliceSave
  Load as SliceLoad
  ChildRefresh as SliceChildRefresh
  ChildDraw as SliceChildDraw
  
  SliceData as any ptr
  SliceType as SliceTypes
  
  Protect as bool
  'Protect is used to mark slices that script authors should not be
  'allowed to directly delete or reparent.
  'Note that this is only checked when a slice is directly freed or
  'moved, so if a Protected slice has an unprotected ancestor, then
  'it can still be deleted or moved indirectly.
  
END TYPE

TYPE SliceTable_
  root as Slice Ptr
  maproot as Slice Ptr
  maplayer(maplayerMax) as Slice Ptr
  obsoleteoverhead as Slice Ptr
  Backdrop as Slice Ptr
  Walkabout as Slice Ptr
  HeroLayer as Slice Ptr
  NPCLayer as Slice Ptr
  scriptsprite as Slice Ptr
  textbox as Slice Ptr
  menu as Slice Ptr
  scriptstring as Slice Ptr
END TYPE

'--Data containers for various slice types

TYPE RectangleSliceData
 'If any of fgcol, bgcol or border are manually changed, set style=-1 and style_loaded=0
 fgcol as integer
 border as integer 'Should default to -1
 translucent as RectTransTypes
 fuzzfactor as integer 'Should default to 50
 bgcol as integer
 'if style is changed then set style_loaded = NO
 style as integer 'Should default to -1
 style_loaded as integer 'Used internally flag whether a change of style has been applied to fgcol, bgcol, or border
 'Declare constructor (byval style as integer = -1, byval bgcol as integer=0, byval translucent as integer = NO, byval fgcol as integer = -1, byval border as integer = -1)
END TYPE

Type TextSliceData
 col as integer
 bgcol as integer
 outline as integer
 s as String
 s_orig as string 'Used when expanding ${} codes, so the codes can be re-expanded again later
 wrap as integer
 'Declare constructor(st as string, byval col as integer = -1, byval ol as integer = YES)
 insert as integer 'char offset of insertion pointer. Zero-based!
 show_insert as integer ' set to YES to display insertion point
 insert_tog as integer 'flashing
 first_line as integer 'used in scrolling
 line_limit as integer 'use to stop wrapping text from flowing too far down. 0 is no limit
                       '-1 can be used to hide all lines
 line_count as integer 'automatically populated when the slice changes
End Type

'FIXME: Support for modifying sprites and flipping is pretty tacked on; generalise!
Type SpriteSliceData
 spritetype as SpriteType
 record as integer  'Meaningless if spritetype is sptTypeFrame
 frame as integer   'Currently displaying frame number. Must be 0 if spritetype is sptTypeFrame
 paletted as bool   'UNSAVED: YES: 4-bit, NO: 8-bit  (could remove this when 256-colour palettes added, or change meaning)
 pal as integer     '(UNSAVED if unpaletted) Set pal to -1 for the default. Ignored for unpaletted
 trans as bool      'Draw transparently?
 flipHoriz as bool  'NO normal, YES horizontally flipped
 flipVert as bool   'NO normal, YES vertically flipped
 loaded as bool     'UNSAVED: Set to NO to force a re-load on the next draw
 img as GraphicPair 'UNSAVED: No need to manually populate this, done in draw (.pal = NULL for unpaletted)
 'dissolve state data
 dissolving as bool
 d_time as integer ' number of ticks that the dissolve should last
 d_tick as integer ' counts which tick the dissolve is in right now
 d_type as integer ' id number of the dissolve animation
 d_back as bool ' NO dissolve away, YES dissolve back in
 d_auto as bool ' YES if the dissolve is animating automatically
End Type

'Shows the currently loaded map at the given slice pos
'Doesn't yet have the ability to load other non-current maps
Type MapSliceData
 'FIXME: Should I even use this at all in this early
 'incarnation? maybe not yet. (It certainly was a huge hassle when rewriting up tilemap stuff)
 map as integer 'Currently read-only informational
 transparent as integer 'Whether or not color 0 is transparent
 overlay as integer 'For backcompat with layers that observe the old overlay feature.
 tileset as TilesetData ptr 'NOTE: ptr to the same memory pointed to by the ptrs in the tilesets() array in game.bas (Not owned!)
 tiles as TileMap ptr 'NOTE: ptr to one of maptiles() in game.bas (Not owned!)
 pass as TileMap ptr 'NOTE: ptr to pass in game.bas (Not owned!) May be NULL for non-overhead layers
End Type

Type GridSliceData
 show as integer
 rows as integer
 cols as integer
End Type

Type EllipseSliceData
 bordercol as integer
 fillcol as integer
 last_draw_size as XYPair  'UNSAVED: used to detect size changes to force a redraw of the frame
 last_draw_bordercol as integer 'UNSAVED
 last_draw_fillcol as integer   'UNSAVED
 frame as Frame Ptr 'UNSAVED: No need to manually populate this, done in draw
End Type

Type ScrollSliceData
 style as integer
 check_depth as integer '0 = check all descendants.
                         '1 = children only.
                         '2 = children+grandchildren only.
                         '3 = children+grandchildren+greatgrandchildren only...
End Type

Type SelectSliceData
 index as integer ' The numeric index of the child that is currently visible.
                   ' If out of range, then no child will be visible. Default to 0
 override as integer ' Overrides the index, used only in the Slice Collection Editor
                     ' and never saved/loaded
End Type

Type PanelSliceData
 vertical as bool 'Defaults to horizontal. Becomes vertical if this is YES
 primary as integer '0 or 1, determines if the first or second child is primary
 pixels as integer 'Fixed-pixel size of the primary. Pixels and percent are combined.
 percent as double 'Percent size of the primary. Pixels and percent are combined
                    'stored as a float. 1.0=100% 0.5=50% 0.01=1%
 padding as integer ' pixels of padding between the sub-panels
End Type

Extern "C"

DECLARE Sub SetupGameSlices
DECLARE Sub SetupMapSlices(byval to_max as integer)
DECLARE Sub DestroyGameSlices(Byval dumpdebug as integer=0)
DECLARE Function NewSlice(Byval parent as Slice ptr = 0) as Slice Ptr
DECLARE Sub DeleteSlice(Byval s as Slice ptr ptr, byval debugme as integer = 0)
DECLARE Sub DeleteSliceChildren(Byval s as Slice ptr, byval debugme as integer = 0)
DECLARE Sub DrawSlice(byval s as slice ptr, byval page as integer)
DECLARE Sub DrawSliceAt(byval s as slice ptr, byval x as integer, byval y as integer, byval w as integer = 100, byval h as integer = 100, byval page as integer, byval ignore_offset as integer = NO)
DECLARE Sub AdvanceSlice(byval s as slice ptr)
DECLARE Sub OrphanSlice(byval sl as slice ptr)
DECLARE Sub SetSliceParent(byval sl as slice ptr, byval parent as slice ptr)
DECLARE Sub ReplaceSliceType(byval sl as slice ptr, byref newsl as slice ptr)
DECLARE Sub InsertSliceBefore(byval sl as slice ptr, byval newsl as slice ptr)
DECLARE Sub SwapSiblingSlices(byval sl1 as slice ptr, byval sl2 as slice ptr)
DECLARE Function SliceIndexAmongSiblings(byval sl as slice ptr) as integer
DECLARE Function LookupSlice (byval lookup_code as integer, byval start_sl as slice ptr = NULL) as slice ptr
DECLARE Function VerifySliceLineage(byval sl as slice ptr, parent as slice ptr) as integer
DECLARE Function UpdateRootSliceSize(sl as slice ptr) as bool
DECLARE Function UpdateScreenSlice(clear_changed_flag as bool = YES) as bool
DECLARE Sub RefreshSliceScreenPos(byval sl as slice ptr)
DECLARE Function SliceXAnchor(byval sl as Slice Ptr) as integer
DECLARE Function SliceYAnchor(byval sl as Slice Ptr) as integer
DECLARE Function SliceEdgeX(byval sl as Slice Ptr, byval edge as AlignTypes) as integer
DECLARE Function SliceEdgeY(byval sl as Slice Ptr, byval edge as AlignTypes) as integer
DECLARE Function SliceCollide(byval sl1 as Slice Ptr, sl2 as Slice Ptr) as integer
DECLARE Function SliceCollidePoint(byval sl as Slice Ptr, byval x as integer, byval y as integer) as integer
DECLARE Function SliceContains(byval sl1 as Slice Ptr, byval sl2 as Slice Ptr) as integer
DECLARE Function FindSliceCollision(parent as Slice Ptr, sl as Slice Ptr, byref num as integer, descend as bool, visibleonly as bool = NO) as Slice Ptr
DECLARE Function FindSliceAtPoint(parent as Slice Ptr, x as integer, y as integer, byref num as integer, descend as bool, visibleonly as bool = NO) as Slice Ptr
DECLARE Sub SliceClamp(byval sl1 as Slice Ptr, byval sl2 as Slice Ptr)
DECLARE Sub YSortChildSlices(byval parent as slice ptr)
DECLARE Sub EdgeYSortChildSlices(byval parent as slice ptr, byval edge as integer)
DECLARE Sub CustomSortChildSlices(byval parent as slice ptr, byval wipevals as integer)
DECLARE Sub AutoSortChildren(byval s as Slice Ptr)
DECLARE Function CloneSliceTree(byval sl as slice ptr) as slice ptr
DECLARE Sub SetSliceTarg(byval s as slice ptr, byval x as integer, byval y as integer, byval ticks as integer)
DECLARE Sub ScrollToChild(byval sl as slice ptr, byval ch as slice ptr)
DECLARE Sub ScrollAllChildren(byval sl as slice ptr, byval xmove as integer, byval ymove as integer)
DECLARE Function CalcScrollMinX(byval sl as slice ptr, byval check_depth as integer, byval cur_depth as integer=1) as integer
DECLARE Function CalcScrollMaxX(byval sl as slice ptr, byval check_depth as integer, byval cur_depth as integer=1) as integer
DECLARE Function CalcScrollMinY(byval sl as slice ptr, byval check_depth as integer, byval cur_depth as integer=1) as integer
DECLARE Function CalcScrollMaxY(byval sl as slice ptr, byval check_depth as integer, byval cur_depth as integer=1) as integer
DECLARE Function SliceChildByIndex_NotForLooping(byval sl as slice ptr, byval index as integer) as Slice Ptr

End Extern

'Declare any overloaded functions here. Overloaded functions can't be accessed from C/C++

DECLARE FUNCTION SliceTypeName OVERLOAD (sl as Slice Ptr) as string
DECLARE FUNCTION SliceTypeName OVERLOAD (t as SliceTypes) as string
DECLARE FUNCTION SliceLookupCodename OVERLOAD (sl as Slice Ptr) as string
DECLARE FUNCTION SliceLookupCodename OVERLOAD (byval code as integer) as string

Extern "C"

'slice accessors
DECLARE Function SliceGetParent( byval s as Slice ptr ) as Slice ptr
DECLARE Function SliceGetFirstChild( byval s as Slice ptr ) as Slice ptr
DECLARE Function SliceGetLastChild( byval s as Slice ptr ) as Slice ptr
DECLARE Function SliceGetNextSibling( byval s as Slice ptr ) as Slice ptr
DECLARE Function SliceGetPrevSibling( byval s as Slice ptr ) as Slice ptr
DECLARE Function SliceGetNumChildren( byval s as Slice ptr ) as integer
DECLARE Function SliceGetX( byval s as Slice ptr ) as integer
DECLARE Function SliceGetY( byval s as Slice ptr ) as integer
DECLARE Function SliceGetWidth( byval s as Slice ptr ) as integer
DECLARE Function SliceGetHeight( byval s as Slice ptr ) as integer
DECLARE Function SliceIsVisible( byval s as Slice ptr ) as integer
DECLARE Function SliceIsMobile( byval s as Slice ptr ) as integer
DECLARE Function SliceIsClipping( byval s as Slice ptr ) as integer
'slice mutators
DECLARE Sub SliceSetX( byval s as Slice ptr, byval x as integer )
DECLARE Sub SliceSetY( byval s as Slice ptr, byval y as integer )
DECLARE Sub SliceSetWidth( byval s as Slice ptr, byval w as integer )
DECLARE Sub SliceSetHeight( byval s as Slice ptr, byval h as integer )
DECLARE Sub SliceSetVisibility( byval s as Slice ptr, byval b as integer )
DECLARE Sub SliceSetMobility( byval s as Slice ptr, byval b as integer )
DECLARE Sub SliceSetClipping( byval s as Slice ptr, byval b as integer )


DECLARE FUNCTION NewSliceOfType (byval t as SliceTypes, byval parent as Slice Ptr=0, byval lookup_code as integer=0) as Slice Ptr

DECLARE SUB SliceDebugRemember(sl as Slice Ptr)
DECLARE SUB SliceDebugForget(sl as Slice Ptr)
DECLARE SUB SliceDebugDump(byval noisy as integer = NO)
DECLARE SUB SliceDebugDumpTree(sl as Slice Ptr, byval indent as integer = 0)
DECLARE FUNCTION SliceDebugCheck(sl as Slice Ptr) as integer
DECLARE SUB SliceDebugLinks(sl as Slice Ptr, recurse as bool = NO, prefix as string = "", indent as integer = 0)


DECLARE Function NewRectangleSlice(byval parent as Slice ptr, byref dat as RectangleSliceData) as slice ptr
DECLARE Sub ChangeRectangleSlice(byval sl as slice ptr,_
                      byval style as integer=-2,_
                      byval bgcol as integer=-99,_
                      byval fgcol as integer=-99,_
                      byval border as integer=-3,_
                      byval translucent as RectTransTypes=transUndef,_
                      byval fuzzfactor as integer=0)

DECLARE Function NewTextSlice(byval parent as Slice ptr, byref dat as TextSliceData) as slice ptr
DECLARE Sub UpdateTextSlice(byval sl as slice ptr)
DECLARE Sub ChangeTextSlice(byval sl as slice ptr,_
                      s as string=CHR(1) & CHR(255),_
                      byval col as integer=-99,_
                      byval outline as integer=-2,_
                      byval wrap as integer=-2,_
                      byval bgcol as integer=-1)
DECLARE Function GetTextSliceString(byval sl as slice ptr) as string

DECLARE Sub DisposeSpriteSlice(byval sl as slice ptr)
DECLARE Sub DrawSpriteSlice(byval sl as slice ptr, byval p as integer)
DECLARE Function GetSpriteSliceData(byval sl as slice ptr) as SpriteSliceData ptr
DECLARE Sub SetSpriteToFrame(byval sl as slice ptr, byval fr as Frame ptr, byval pal as integer)
DECLARE Function NewSpriteSlice(byval parent as Slice ptr, byref dat as SpriteSliceData) as slice ptr
DECLARE Sub ChangeSpriteSlice(byval sl as slice ptr,_
                      byval spritetype as SpriteType = sprTypeInvalid,_
                      byval record as integer=-1,_
                      byval pal as integer = -2,_
                      byval frame as integer = -1,_
                      byval fliph as integer = -2,_
                      byval flipv as integer = -2,_
                      byval trans as integer = -2)  ' All arguments default to no change
DECLARE Sub DissolveSpriteSlice(byval sl as slice ptr, byval dissolve_type as integer, byval over_ticks as integer=-1, byval start_tick as integer=0, byval backwards as bool=NO, byval auto_animate as bool=YES)
DECLARE Function SpriteSliceIsDissolving(byval sl as slice ptr, byval only_auto as bool=YES) as bool

DECLARE Sub DisposeMapSlice(byval sl as slice ptr)
DECLARE Sub DrawMapSlice(byval sl as slice ptr, byval p as integer)
DECLARE Function GetMapSliceData(byval sl as slice ptr) as MapSliceData ptr
DECLARE Function NewMapSlice(byval parent as Slice ptr, byref dat as MapSliceData) as slice ptr
DECLARE Sub ChangeMapSliceTileset (byval sl as slice ptr, byval tileset as TilesetData ptr)
DECLARE Sub ChangeMapSlice (byval sl as slice ptr,_
                   byval tiles as TileMap ptr=cast(TileMap ptr, 1),_
                   byval pass as TileMap ptr=cast(TileMap ptr, 1),_
                   byval transparent as integer=-2,_
                   byval overlay as integer=-1) ' All arguments default to no change (explaining weird tiles default)

DECLARE Function NewGridSlice(byval parent as Slice ptr, byref dat as GridSliceData) as slice ptr
DECLARE Sub ChangeGridSlice(byval sl as slice ptr,_
                      byval rows as integer=0,_
                      byval cols as integer=0,_
                      byval show as integer=-2)

DECLARE Sub DisposeEllipseSlice(byval sl as slice ptr)
DECLARE Sub DrawEllipseSlice(byval sl as slice ptr, byval p as integer)
DECLARE Function NewEllipseSlice(byval parent as Slice ptr, byref dat as EllipseSliceData) as slice ptr
DECLARE Sub ChangeEllipseSlice(byval sl as slice ptr,_
                      byval bordercol as integer=-1,_
                      byval fillcol as integer=-1)  ' All arguments default to no change

DECLARE Function NewScrollSlice(byval sl as slice ptr, byref dat as ScrollSliceData) as Slice ptr
DECLARE Sub ChangeScrollSlice(byval sl as slice ptr,_
                      byval style as integer=-1,_
                      byval check_depth as integer=-1)

DECLARE Function NewSelectSlice(byval sl as slice ptr, byref dat as SelectSliceData) as Slice ptr
DECLARE Sub ChangeSelectSlice(byval sl as slice ptr,_
                      byval index as integer=-2,_
                      byval override as integer=-2) ' All arguments default to no change
DECLARE Sub SelectSliceNext(byval sl as Slice ptr, byval can_loop as bool=YES)

DECLARE Function NewPanelSlice(byval parent as Slice ptr, byref dat as PanelSliceData) as slice ptr
DECLARE Sub ChangePanelSlice(byval sl as slice ptr,_
                      byval vertical as integer=-2,_ 'verical is actually bool, use -2 to signal no change
                      byval primary as integer=-1,_
                      byval pixels as integer=-1,_
                      byval percent as double=-1.0,_
                      byval padding as integer=-1)
DECLARE Function GetSelectSliceData(byval sl as slice ptr) as SelectSliceData ptr
DECLARE Function GetScrollSliceData(byval sl as slice ptr) as ScrollSliceData ptr

'--Saving and loading slices
DECLARE Sub SliceSaveToNode(byval sl as Slice Ptr, node as Reload.Nodeptr, save_handles as bool=NO)
DECLARE Sub SliceSaveToFile(byval sl as Slice Ptr, filename as string, save_handles as bool=NO)
DECLARE Sub SliceLoadFromNode(byval sl as Slice Ptr, node as Reload.Nodeptr, load_handles as bool=NO)
DECLARE Sub SliceLoadFromFile(byval sl as Slice Ptr, filename as string, load_handles as bool=NO)


EXTERN as SliceTable_ SliceTable

EXTERN NumDrawnSlices as integer

End Extern


'NEW SLICE TYPE TEMPLATE
'INSTRUCTIONS: Copy the following block into Slices.bas.
' Then, select the block, and use Find and Replace to switch
' <TYPENAME> with whatever name you need. Then, add the drawing code to
' Draw<TYPENAME>Slice.
/'
'==START OF <TYPENAME>SLICEDATA
Sub Dispose<TYPENAME>Slice(byval sl as slice ptr)
 if sl = 0 then exit sub
 if sl->SliceData = 0 then exit sub
 dim dat as <TYPENAME>SliceData ptr = cptr(<TYPENAME>SliceData ptr, sl->SliceData)
 delete dat
 sl->SliceData = 0
end sub

Sub Draw<TYPENAME>Slice(byval sl as slice ptr, byval p as integer)
 if sl = 0 then exit sub
 if sl->SliceData = 0 then exit sub
 
 dim dat as <TYPENAME>SliceData ptr = cptr(<TYPENAME>SliceData ptr, sl->SliceData)

 '''DRAWING CODE GOES HERE!
end sub

Function Get<TYPENAME>SliceData(byval sl as slice ptr) as <TYPENAME>SliceData ptr
 return sl->SliceData
End Function

Sub Save<TYPENAME>Slice(byval sl as slice ptr, byref f as SliceFileWrite)
 DIM dat as <TYPENAME>SliceData Ptr
 dat = sl->SliceData
 'WriteSliceFileVal f, "keyname", dat->datamember
End Sub

Function Load<TYPENAME>Slice (Byval sl as SliceFwd ptr, key as string, valstr as string, byval n as integer, byref checkn as integer) as integer
 'Return value is YES if the key is understood, NO if ignored
 'set checkn=NO if you read a string. checkn defaults to YES which causes integer/boolean checking to happen afterwards
 dim dat as <TYPENAME>SliceData Ptr
 dat = sl->SliceData
 select case key
  'case "keyname": dat->datamember = n
  case else: return NO
 end select
 return YES
End Function

Function New<TYPENAME>Slice(byval parent as Slice ptr, byref dat as <TYPENAME>SliceData) as slice ptr
 dim ret as Slice ptr
 ret = NewSlice(parent)
 if ret = 0 then 
  debug "Out of memory?!"
  return 0
 end if
 
 dim d as <TYPENAME>SliceData ptr = new <TYPENAME>SliceData
 *d = dat
 
 ret->SliceType = sl<TYPENAME>
 ret->SliceData = d
 ret->Draw = @Draw<TYPENAME>Slice
 ret->Dispose = @Dispose<TYPENAME>Slice
 ret->Clone = @Clone<TYPENAME>Slice
 ret->Save = @Save<TYPENAME>Slice
 ret->Load = @Load<TYPENAME>Slice
 
 return ret
end function
'==END OF <TYPENAME>SLICEDATA
'/


#endif
