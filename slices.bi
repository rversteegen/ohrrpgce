#ifndef SLICES_BI
#define SLICES_BI
'OHRRPGCE GAME - Slice related functionality
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Except, this module isn't very crappy

#include "udts.bi"

Enum SliceTypes
 slRoot
 slSpecial
 slRectangle
 slStyleRectangle
 slSprite
 slText
 slMenu
 slMenuItem
End Enum

Enum AttachTypes
 slSlice
 slScreen
End Enum

TYPE SliceFileWrite
  name AS STRING
  handle AS INTEGER
  indent AS INTEGER
END TYPE

Type SliceFwd as Slice
Type SliceDraw as Sub(Byval as SliceFwd ptr, byval stupidPage as integer)
Type SliceDispose as Sub(Byval as SliceFwd ptr)
Type SliceUpdate as Sub(Byval as SliceFwd ptr)
Type SliceSave as Sub(Byval as SliceFwd ptr, byref f as SliceFileWrite)

TYPE Slice
  Parent as Slice Ptr
  FirstChild as Slice Ptr
  NextSibling as Slice Ptr
  PrevSibling as Slice Ptr
  NumChildren as Integer
  
  X as integer 'the X,Y relative to whatever the slice is attached to
  Y as integer
  ScreenX as integer 'the actual X,Y, updated every frame
  ScreenY as integer
  Width as integer 'FIXME: Might it make sense to keep width/height separate from computed slice-system width/height, similar to how we do for X/Y and screenX/ScreenY? Consider the case of a SpriteSlice which is set to 50x50 by the sprite loading code but is set to Fill=YES
  Height as integer
  Visible as integer
  
  AlignHoriz as integer 'FIXME: not implemented yet
  AlignVert as integer  'FIXME: not implemented yet
  
  as integer PaddingTop, PaddingLeft, PaddingRight, PaddingBottom
  
  Fill as integer
  
  Attach as AttachTypes
  Union
   Attached as Slice ptr
  End Union
  
  Draw as SliceDraw
  Dispose as SliceDispose
  Update as SliceUpdate
  Save as SliceSave
  SliceData as any ptr
  SliceType as SliceTypes
  
  'whatever else
  
END TYPE

TYPE SliceTable_
  root AS Slice Ptr
  map  AS Slice Ptr
  scriptsprite AS Slice Ptr
  textbox AS Slice Ptr
  menu AS Slice Ptr
  scriptstring AS Slice Ptr
END TYPE

'--Data containers for various slice types

TYPE RectangleSliceData
 fgcol as integer
 bgcol as integer
 transparent as integer
 border as integer
 'Declare constructor (byval bgcol as integer, byval transparent as integer = YES, byval fgcol as integer = -1, byval border as integer = -1)
END TYPE

TYPE StyleRectangleSliceData
 style as integer
 transparent as integer
 hideborder as integer
 'Declare constructor (byval bgcol as integer, byval transparent as integer = YES, byval style as integer = 0)
END TYPE

Type TextSliceData
 col as integer
 outline as integer
 s as String
 'lines() as string
 wrap as integer
 'Declare constructor(byval st as string, byval col as integer = -1, byval ol as integer = YES)
End Type

Type SpriteSliceData
 spritetype AS INTEGER 'PT0 thru PT8
 record AS INTEGER
 pal AS INTEGER     'Set pal to -1 for the default
 frame AS INTEGER   'Currently displaying frame
 loaded AS INTEGER  'UNSAVED: Set to NO to force a re-load on the next draw
 img AS GraphicPair 'UNSAVED: No need to manually populate this, done in draw
End Type

Type MenuSliceData
 selected as integer
 tog as integer
End Type

Type MenuItemSliceData
 ordinal as integer
 caption as string
 disabled as integer
End Type


DECLARE Sub SetupGameSlices
DECLARE Sub DestroyGameSlices
DECLARE Function NewSlice(Byval parent as Slice ptr = 0) as Slice Ptr
DECLARE Sub DeleteSlice(Byval s as Slice ptr ptr)
DECLARE Sub DrawSlice(byval s as slice ptr, byval page as integer)
DECLARE Sub SetSliceParent(byval sl as slice ptr, byval parent as slice ptr)
DECLARE Sub ReplaceSlice(byval sl as slice ptr, byref newsl as slice ptr)
DECLARE Sub InsertSiblingSlice(byval sl as slice ptr, byval newsl as slice ptr)
DECLARE Sub SwapSiblingSlices(byval sl1 as slice ptr, byval sl2 as slice ptr)
DECLARE Function verifySliceLineage(byval sl as slice ptr, parent as slice ptr) as integer
DECLARE FUNCTION SliceTypeName (sl AS Slice Ptr) AS STRING

DECLARE Function NewRectangleSlice(byval parent as Slice ptr, byref dat as RectangleSliceData) as slice ptr
DECLARE Function NewStyleRectangleSlice(byval parent as Slice ptr, byref dat as StyleRectangleSliceData) as slice ptr
DECLARE Function NewTextSlice(byval parent as Slice ptr, byref dat as TextSliceData) as slice ptr
DECLARE Function NewMenuSlice(byval parent as Slice ptr, byref dat as MenuSliceData) as slice ptr
DECLARE Function NewMenuItemSlice(byval parent as Slice ptr, byref dat as MenuItemSliceData) as slice ptr

DECLARE Sub DisposeSpriteSlice(byval sl as slice ptr)
DECLARE Sub DrawSpriteSlice(byval sl as slice ptr, byval p as integer)
DECLARE Function GetSpriteSliceData(byval sl as slice ptr) as SpriteSliceData ptr
DECLARE Function NewSpriteSlice(byval parent as Slice ptr, byref dat as SpriteSliceData) as slice ptr

DECLARE Sub OpenSliceFileWrite (BYREF f AS SliceFileWrite, filename AS STRING)
DECLARE Sub CloseSliceFileWrite (BYREF f AS SliceFileWrite)
DECLARE Sub WriteSliceFileLine (BYREF f AS SliceFileWrite, s AS STRING)
DECLARE Sub WriteSliceFileVal OVERLOAD (BYREF f AS SliceFileWrite, nam AS STRING, s AS STRING, quotes AS INTEGER=YES)
DECLARE Sub WriteSliceFileVal OVERLOAD (BYREF f AS SliceFileWrite, nam AS STRING, n AS INTEGER)
DECLARE Sub WriteSliceFileBool (BYREF f AS SliceFileWrite, nam AS STRING, b AS INTEGER)
DECLARE Sub SaveSlice (BYREF f AS SliceFileWrite, BYVAL sl AS Slice Ptr)


EXTERN Slices() as Slice ptr
EXTERN AS SliceTable_ SliceTable


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
 
 return ret
end function
'==END OF <TYPENAME>SLICEDATA
'/


#endif
