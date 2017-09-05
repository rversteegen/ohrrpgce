#IFNDEF THINGBROWSER_BI
#DEFINE THINGBROWSER_BI

Type ThingBrowser extends Object
 'Displays the browser, and retuns the selected result (or start_id if canceled)
 declare function browse(byref start_id as integer=0) as integer
 declare sub build_thing_list()

 root as Slice ptr
 plank_size as XYPair 'This is calculated dynamically from the largest plank returned by create_thing_plank()

 helpkey as string
 index as integer

 declare virtual function init_helpkey() as string
 declare virtual function lowest_id() as integer
 declare virtual function highest_id() as integer
 
 'the lookup code SL_PLANK_HOLDER will be automatically applied to whatever slice is returned.
 'Any slices with SL_PLANK_MENU_SELECTABLE should be created as children
 ' The thing id number will automatically be written into the plank's ->Extra(0) slot
 declare virtual function create_thing_plank(byval id as integer) as Slice ptr

 'If the plank is purely text based, just override this rather than .create_thing_plank()
 declare virtual function thing_text_for_id(byval id as integer) as string

End Type

Type ItemBrowser extends ThingBrowser
 declare virtual function init_helpkey() as string
 declare virtual function highest_id() as integer
 declare virtual function thing_text_for_id(byval id as integer) as string
End Type

#ENDIF