'This file automatically generated by sourceslices/update.sh
'######## This file was auto-generated by the slice2bas tool! ########
'######## Rather than editing this file, it may be better to  ########
'######## edit the reload file in the slice collection editor ########
'######## and then re-convert it with slice2bas               ########

#include "slices.bi"

Sub default_item_plank (byval sl1 as Slice Ptr)
 ReplaceSliceType(sl1, NewSliceOfType(slContainer))
 sl1->fill = -1
  dim sl2 as Slice Ptr = NewSliceOfType(slContainer)
  sl2->lookup = -102008
  sl2->x = 140
  sl2->y = 70
  sl2->width = 117
  sl2->height = 8
  sl2->paddingleft = 4
  sl2->paddingright = 4
   dim sl3 as Slice Ptr = NewSliceOfType(slRectangle)
   sl3->lookup = -102014
   sl3->fill = -1
   ChangeRectangleSlice sl3, , , 19, -2, , 
   SetSliceParent(sl3, sl2)
   sl3 = NewSliceOfType(slText)
   sl3->lookup = -102014
   sl3->width = 56
   sl3->height = 10
   ChangeTextSlice sl3, !"${ITEM}", , , , 
   SetSliceParent(sl3, sl2)
   sl3 = NewSliceOfType(slText)
   sl3->lookup = -102014
   sl3->width = 48
   sl3->height = 10
   sl3->alignhoriz = 2
   sl3->anchorhoriz = 2
   ChangeTextSlice sl3, !"${NUM}", , , , 
   SetSliceParent(sl3, sl2)
  SetSliceParent(sl2, sl1)
End Sub
'######## This file was auto-generated by the slice2bas tool! ########
'######## Rather than editing this file, it may be better to  ########
'######## edit the reload file in the slice collection editor ########
'######## and then re-convert it with slice2bas               ########

#include "slices.bi"

Sub default_item_screen (byval sl1 as Slice Ptr)
 ReplaceSliceType(sl1, NewSliceOfType(slContainer))
 sl1->fill = -1
  dim sl2 as Slice Ptr = NewSliceOfType(slContainer)
  sl2->paddingtop = 5
  sl2->paddingleft = 8
  sl2->paddingright = 8
  sl2->paddingbottom = 16
  sl2->fill = -1
   dim sl3 as Slice Ptr = NewSliceOfType(slRectangle)
   sl3->paddingtop = 6
   sl3->paddingleft = 6
   sl3->paddingright = 6
   sl3->paddingbottom = 6
   sl3->fill = -1
   ChangeRectangleSlice sl3, 0, , , , , 
    dim sl4 as Slice Ptr = NewSliceOfType(slScroll)
    sl4->clip = -1
    sl4->fill = -1
    ChangeScrollSlice sl4, , 
     dim sl5 as Slice Ptr = NewSliceOfType(slGrid)
     sl5->height = 8
     sl5->fill = -1
     sl5->fillmode = 1
     ChangeGridSlice sl5, , 3, 
      dim sl6 as Slice Ptr = NewSliceOfType(slContainer)
      sl6->lookup = -102011
      sl6->paddingleft = 4
      sl6->paddingright = 4
      sl6->fill = -1
       dim sl7 as Slice Ptr = NewSliceOfType(slRectangle)
       sl7->lookup = -102014
       sl7->fill = -1
       ChangeRectangleSlice sl7, , , 20, -2, , 
       SetSliceParent(sl7, sl6)
       sl7 = NewSliceOfType(slText)
       sl7->lookup = -102014
       sl7->width = 56
       sl7->height = 10
       ChangeTextSlice sl7, !"${EXIT}", -2, , , 
       SetSliceParent(sl7, sl6)
      SetSliceParent(sl6, sl5)
      sl6 = NewSliceOfType(slContainer)
      sl6->lookup = -102012
      sl6->paddingleft = 4
      sl6->paddingright = 4
      sl6->fill = -1
       sl7 = NewSliceOfType(slRectangle)
       sl7->lookup = -102014
       sl7->fill = -1
       ChangeRectangleSlice sl7, , , 20, -2, , 
       SetSliceParent(sl7, sl6)
       sl7 = NewSliceOfType(slText)
       sl7->lookup = -102014
       sl7->width = 56
       sl7->height = 10
       ChangeTextSlice sl7, !"${SORT}", -2, , , 
       SetSliceParent(sl7, sl6)
      SetSliceParent(sl6, sl5)
      sl6 = NewSliceOfType(slContainer)
      sl6->lookup = -102013
      sl6->paddingleft = 4
      sl6->paddingright = 4
      sl6->fill = -1
       sl7 = NewSliceOfType(slRectangle)
       sl7->lookup = -102014
       sl7->fill = -1
       ChangeRectangleSlice sl7, , , 20, -2, , 
       SetSliceParent(sl7, sl6)
       sl7 = NewSliceOfType(slText)
       sl7->lookup = -102014
       sl7->width = 64
       sl7->height = 10
       ChangeTextSlice sl7, !"${TRASH}", -2, , , 
       SetSliceParent(sl7, sl6)
      SetSliceParent(sl6, sl5)
     SetSliceParent(sl5, sl4)
     sl5 = NewSliceOfType(slGrid)
     sl5->lookup = -102010
     sl5->y = 8
     sl5->height = 8
     sl5->fill = -1
     sl5->fillmode = 1
     ChangeGridSlice sl5, , 3, 
     SetSliceParent(sl5, sl4)
    SetSliceParent(sl4, sl3)
   SetSliceParent(sl3, sl2)
  SetSliceParent(sl2, sl1)
  sl2 = NewSliceOfType(slContainer)
  sl2->height = 16
  sl2->alignhoriz = 2
  sl2->alignvert = 2
  sl2->anchorhoriz = 1
  sl2->anchorvert = 2
  sl2->paddingleft = 2
  sl2->paddingright = 2
  sl2->fill = -1
  sl2->fillmode = 1
   sl3 = NewSliceOfType(slRectangle)
   sl3->fill = -1
   ChangeRectangleSlice sl3, 1, , , , 1, 
   SetSliceParent(sl3, sl2)
  SetSliceParent(sl2, sl1)
End Sub
'######## This file was auto-generated by the slice2bas tool! ########
'######## Rather than editing this file, it may be better to  ########
'######## edit the reload file in the slice collection editor ########
'######## and then re-convert it with slice2bas               ########

#include "slices.bi"

Sub default_status_screen (byval sl1 as Slice Ptr)
 ReplaceSliceType(sl1, NewSliceOfType(slContainer))
 sl1->fill = -1
  dim sl2 as Slice Ptr = NewSliceOfType(slContainer)
  sl2->paddingtop = 8
  sl2->paddingleft = 8
  sl2->paddingright = 8
  sl2->paddingbottom = 8
  sl2->fill = -1
   dim sl3 as Slice Ptr = NewSliceOfType(slRectangle)
   sl3->fill = -1
   ChangeRectangleSlice sl3, 3, , , , 1, 45
    dim sl4 as Slice Ptr = NewSliceOfType(slPanel)
    sl4->paddingtop = 8
    sl4->paddingleft = 8
    sl4->paddingright = 8
    sl4->paddingbottom = 12
    sl4->fill = -1
    ChangePanelSlice sl4, -1, , 42, 0, 8
     dim sl5 as Slice Ptr = NewSliceOfType(slRectangle)
     sl5->fill = -1
     ChangeRectangleSlice sl5, 3, , , , , 
      dim sl6 as Slice Ptr = NewSliceOfType(slPanel)
      sl6->fill = -1
      ChangePanelSlice sl6, , 1, 45, 0, 
       dim sl7 as Slice Ptr = NewSliceOfType(slContainer)
       sl7->fill = -1
        dim sl8 as Slice Ptr = NewSliceOfType(slText)
        sl8->y = 4
        sl8->width = 88
        sl8->height = 10
        sl8->alignhoriz = 1
        sl8->anchorhoriz = 1
        ChangeTextSlice sl8, !"${HERONAME}", , , , 
        SetSliceParent(sl8, sl7)
        sl8 = NewSliceOfType(slText)
        sl8->y = 14
        sl8->width = 144
        sl8->height = 10
        sl8->alignhoriz = 1
        sl8->anchorhoriz = 1
        ChangeTextSlice sl8, !"${LEVLABEL} ${LEV}", , , , 
        SetSliceParent(sl8, sl7)
        sl8 = NewSliceOfType(slText)
        sl8->x = 4
        sl8->y = 24
        sl8->width = 360
        sl8->height = 10
        ChangeTextSlice sl8, !"${EXPNEED} ${EXPLABEL} ${FORNEXT} ${LEVLABEL}", , , , 
        SetSliceParent(sl8, sl7)
       SetSliceParent(sl7, sl6)
       sl7 = NewSliceOfType(slContainer)
       sl7->fill = -1
        sl8 = NewSliceOfType(slSprite)
        sl8->lookup = -102002
        sl8->x = 1
        sl8->width = 32
        sl8->height = 40
        sl8->alignhoriz = 1
        sl8->alignvert = 1
        sl8->anchorhoriz = 1
        sl8->anchorvert = 1
        ChangeSpriteSlice sl8, , , , , , , 
        SetSliceParent(sl8, sl7)
        sl8 = NewSliceOfType(slRectangle)
        sl8->lookup = -102009
        sl8->x = 8
        sl8->y = -8
        sl8->width = 50
        sl8->height = 50
        sl8->alignhoriz = 2
        sl8->anchorhoriz = 2
        ChangeRectangleSlice sl8, 3, , , , , 
         dim sl9 as Slice Ptr = NewSliceOfType(slSprite)
         sl9->lookup = -102000
         sl9->width = 50
         sl9->height = 50
         sl9->alignhoriz = 1
         sl9->alignvert = 1
         sl9->anchorhoriz = 1
         sl9->anchorvert = 1
         ChangeSpriteSlice sl9, 8, , , , , , 
         SetSliceParent(sl9, sl8)
        SetSliceParent(sl8, sl7)
       SetSliceParent(sl7, sl6)
      SetSliceParent(sl6, sl5)
     SetSliceParent(sl5, sl4)
     sl5 = NewSliceOfType(slSelect)
     sl5->lookup = -102003
     sl5->fill = -1
     ChangeSelectSlice sl5, 
      sl6 = NewSliceOfType(slPanel)
      sl6->fill = -1
      ChangePanelSlice sl6, , , , , 12
       sl7 = NewSliceOfType(slRectangle)
       sl7->fill = -1
       ChangeRectangleSlice sl7, 3, , , , , 
        sl8 = NewSliceOfType(slScroll)
        sl8->paddingtop = 2
        sl8->paddingleft = 4
        sl8->paddingright = 4
        sl8->paddingbottom = 2
        sl8->fill = -1
        ChangeScrollSlice sl8, , 
         sl9 = NewSliceOfType(slGrid)
         sl9->lookup = -102004
         sl9->height = 10
         sl9->fill = -1
         sl9->fillmode = 1
         ChangeGridSlice sl9, , , 
         SetSliceParent(sl9, sl8)
        SetSliceParent(sl8, sl7)
       SetSliceParent(sl7, sl6)
       sl7 = NewSliceOfType(slRectangle)
       sl7->fill = -1
       ChangeRectangleSlice sl7, 3, , , , , 
        sl8 = NewSliceOfType(slScroll)
        sl8->clip = -1
        sl8->paddingtop = 2
        sl8->paddingleft = 4
        sl8->paddingright = 4
        sl8->paddingbottom = 2
        sl8->fill = -1
        ChangeScrollSlice sl8, , 
         sl9 = NewSliceOfType(slText)
         sl9->y = 3
         sl9->width = 80
         sl9->height = 10
         sl9->alignhoriz = 1
         sl9->anchorhoriz = 1
         ChangeTextSlice sl9, !"${HPLABEL}", , , , 
         SetSliceParent(sl9, sl8)
         sl9 = NewSliceOfType(slText)
         sl9->y = 13
         sl9->width = 136
         sl9->height = 10
         sl9->alignhoriz = 1
         sl9->anchorhoriz = 1
         ChangeTextSlice sl9, !"${HPCUR}/${HPMAX}", , , , 
         SetSliceParent(sl9, sl8)
         sl9 = NewSliceOfType(slText)
         sl9->lookup = -102005
         sl9->y = 34
         sl9->width = 80
         sl9->height = 10
         sl9->alignhoriz = 1
         sl9->anchorhoriz = 1
         ChangeTextSlice sl9, !"${MPLABEL}", , , , 
         SetSliceParent(sl9, sl8)
         sl9 = NewSliceOfType(slText)
         sl9->lookup = -102005
         sl9->y = 44
         sl9->width = 136
         sl9->height = 10
         sl9->alignhoriz = 1
         sl9->anchorhoriz = 1
         ChangeTextSlice sl9, !"${MPCUR}/${MPMAX}", , , , 
         SetSliceParent(sl9, sl8)
         sl9 = NewSliceOfType(slText)
         sl9->lookup = -102006
         sl9->y = 65
         sl9->width = 104
         sl9->height = 10
         sl9->alignhoriz = 1
         sl9->anchorhoriz = 1
         ChangeTextSlice sl9, !"${LEVMPLABEL}", , , , 
         SetSliceParent(sl9, sl8)
         sl9 = NewSliceOfType(slText)
         sl9->lookup = -102006
         sl9->y = 75
         sl9->width = 248
         sl9->height = 20
         sl9->alignhoriz = 1
         sl9->anchorhoriz = 1
         ChangeTextSlice sl9, !"${LMP1}/${LMP2}/${LMP3}/${LMP4}\n${LMP5}/${LMP6}/${LMP7}/${LMP8}", , , , 
         SetSliceParent(sl9, sl8)
         sl9 = NewSliceOfType(slText)
         sl9->y = 101
         sl9->width = 176
         sl9->height = 10
         sl9->alignhoriz = 1
         sl9->anchorhoriz = 1
         ChangeTextSlice sl9, !"${MONEY} ${MONEYLABEL}", -17, , , 
         SetSliceParent(sl9, sl8)
        SetSliceParent(sl8, sl7)
       SetSliceParent(sl7, sl6)
      SetSliceParent(sl6, sl5)
      sl6 = NewSliceOfType(slRectangle)
      sl6->paddingtop = 4
      sl6->paddingleft = 8
      sl6->paddingright = 8
      sl6->paddingbottom = 4
      sl6->fill = -1
      ChangeRectangleSlice sl6, 3, , , , , 
       sl7 = NewSliceOfType(slText)
       sl7->fill = -1
       ChangeTextSlice sl7, !"${ELEMENTS}", , , -1, 
       SetSliceParent(sl7, sl6)
      SetSliceParent(sl6, sl5)
     SetSliceParent(sl5, sl4)
    SetSliceParent(sl4, sl3)
   SetSliceParent(sl3, sl2)
  SetSliceParent(sl2, sl1)
End Sub
'######## This file was auto-generated by the slice2bas tool! ########
'######## Rather than editing this file, it may be better to  ########
'######## edit the reload file in the slice collection editor ########
'######## and then re-convert it with slice2bas               ########

#include "slices.bi"

Sub default_status_stat_plank (byval sl1 as Slice Ptr)
 ReplaceSliceType(sl1, NewSliceOfType(slContainer))
 sl1->fill = -1
  dim sl2 as Slice Ptr = NewSliceOfType(slContainer)
  sl2->lookup = -102008
  sl2->x = 70
  sl2->y = 50
  sl2->width = 129
  sl2->height = 10
   dim sl3 as Slice Ptr = NewSliceOfType(slText)
   sl3->width = 64
   sl3->height = 10
   ChangeTextSlice sl3, !"${LABEL}", , , , 
   SetSliceParent(sl3, sl2)
   sl3 = NewSliceOfType(slText)
   sl3->width = 48
   sl3->height = 10
   sl3->alignhoriz = 2
   sl3->anchorhoriz = 2
   ChangeTextSlice sl3, !"${CUR}", , , , 
   SetSliceParent(sl3, sl2)
  SetSliceParent(sl2, sl1)
End Sub
