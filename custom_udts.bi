#IFNDEF CUSTOM_UDTS_BI
#DEFINE CUSTOM_UDTS_BI

'This file contains UDTs that only get used in custom mode, and not in game,
'so as to prevent them from cluttering up the global udts.bi file

#include "slices.bi"

ENUM ToolIDs
  no_tool = -1
  'These are the tools available in the sprite, tile and map editors
  draw_tool
  box_tool
  line_tool
  fill_tool
  oval_tool
  airbrush_tool
  mark_tool
  clone_tool
  replace_tool
  scroll_tool
  SPRITEEDITOR_LAST_TOOL = scroll_tool

  paint_tool
  draw_wall_tool 'pass_mode draw tool has special mouse handling
  stamp_tool    'Variant on draw_tool in pass_mode, to draw a certain wall bit
  'The following tools don't do anything, but just determine what cursor to use
  select_tool   'Show a normal cursor (door and foe mapping)
  npc_tool      'NPC placement mode - the cursor is an NPC
  NUM_TOOLS
END ENUM

TYPE ToolInfoType
  name as string
  icon as string
  shortcut as integer
  cursor as integer
  areanum as integer
END TYPE

TYPE MouseArea
  x as integer
  y as integer
  w as integer
  h as integer
  hidecursor as bool
END TYPE

TYPE UndoStep as any

TYPE CommonEditState EXTENDS Object
  message as string          'Message shown at the top of the screen
  message_ticks as integer   'Remaining ticks to display message

  'Undo
  history as UndoStep ptr 'TileEditUndoStep vector
  history_step as integer    'In undo_history, [0, history_step) are undos, and the rest are redos

  DECLARE VIRTUAL SUB undo_stroke_internal(byref changelist as UndoStep ptr, byval redo as bool = NO)

END TYPE

TYPE SpriteEditStatic
  'The clone/mark tool buffer
  clone_brush as Frame ptr
  clonepos as XYPair   'Position of handle on the clone brush (defaults to center)

  'Used for Ctrl+C/V/T copying of sprites, by both spriteset browser and sprite editor! NULL if none.
  spriteclip as Frame ptr

  'Used for Alt+C/V copying of palettes; NULL if none
  pal_clipboard as Palette16 ptr

  'Minor remembered settings
  cursor as XYPair    'Last drawing cursor position
  tool as integer
  airsize as integer
  mist as integer
  hidemouse as bool
  palindex as integer
END TYPE

TYPE FnSpriteSaver as SUB(spr as Frame ptr, context as any ptr, defpal as integer)

'sprite_editor state
TYPE SpriteEditState
  'Members which should be set by the caller to sprite_editor
  wide as integer
  high as integer
  framename as string
  default_export_filename as string
  save_callback as FnSpriteSaver   'Called to save the sprite
  save_callback_context as any ptr 'To be passed to save_callback
  'The following are used only by import and palette menus; would like to get rid of this
  fileset as SpriteType
  spriteset_num as integer
  fullset as bool       'Whether editing full spritesets rather than frames (Used only by import menu)

  'Internal state
  sprite as Frame ptr   'The current edit state
  zoom as integer
  x as integer
  y as integer
  lastcpos as XYPair '.x/.y (cursor position) last tick
  lastpos as XYPair  'something totally different
  fastmovestep as integer 'How fast to move when holding Shift
  zonenum as integer
  zone as XYPair
  zonecursor as integer
  gotmouse as bool
  mouse as MouseInfo
  hidemouse as bool
  number_typing_deadline as double  'Deadline for typing more digits of a color idx
  drawcursor as integer 'Icon to use for the cursor, (character in the font)
  tool as integer
  pal_num as integer    'Palette used by current sprite
  curcolor as integer   'Index in master palette (equal to .palette->col(.palindex))
  palindex as integer   'Index in 16 color palette
  palette as Palette16 ptr 'The current palette
  airsize as integer
  mist as integer
  hold as integer
  tick as integer
  tog as integer        '0/1
  holdpos as XYPair
  radius as double
  ellip_minoraxis as double '--For non-circular elipses. Not implemented yet
  ellip_angle as double
  undodepth as integer  'A value in [0, len(undo_history)] (i.e. inclusive). Indicates
                        'the index in the history equal to the current edit state (with
                        'indices before being undo steps and after being redo steps); if
                        'equal to len, indicates the current edits aren't saved in history.
  undomax as integer    'Max allowable length of undo_history
  undo_history as Frame ptr vector  'A stack of previous states. The most recent is at the end
  didscroll as bool     'have scrolled since selecting the scroll tool
  delay as integer
  movespeed as integer
  readjust as bool
  adjustpos as XYPair
  showcolnum as integer 'Ticks remaining to show the number of selected master palette color

  'Fixed members
  previewpos as XYPair
  toolinfo(SPRITEEDITOR_LAST_TOOL) as ToolInfoType
  area(25) as MouseArea
END TYPE

TYPE TileEditUndoStep
  tilenum as integer
  img as Frame ptr      'A 20x20 image
END TYPE

DECLARE_VECTOR_OF_TYPE(TileEditUndoStep, TileEditUndoStep)

TYPE TileCloneBuffer
  exists as integer
  buf(19,19) as UBYTE
  size as XYPair
  offset as XYPair
END TYPE

TYPE TileEditState EXTENDS CommonEditState
  tilesetnum as integer
  drawframe as Frame Ptr  '--Don't write to this! It's for display only
  x as integer      'x/y are used both in tilecut and for the tool pos in the individual tile editor!
  y as integer
  lastcpos as XYPair  '.x/.y (cursor position) last tick
  fastmovestep as integer   'How fast to move when holding Shift
  tilex as integer  'Selected tile in the tileset: 0-15
  tiley as integer  '0-9
  DECLARE FUNCTION tilenum() as integer  'Selected tile, 0-159
  gotmouse as bool
  drawcursor as integer
  preview_content as integer   'tile preview mode (0=neighbours/1=tiled)
  tool as integer
  curcolor as integer
  hidemouse as bool
  radius as double
  airsize as integer
  mist as integer
  undo as integer
  allowundo as integer
  zone as integer
  justpainted as integer
  hold as integer
  holdpos as XYPair
  cutfrom as integer
  cuttileset as integer
  canpaste as integer
  delay as integer
  readjust as integer
  adjustpos as XYPair
  didscroll as integer  'have scrolled since selecting the scroll tool
  defaultwalls as integer vector  'always length 160
END TYPE

TYPE HeroEditState
  changed as integer
  previewframe as integer
  battle    as GraphicPair
  walkabout as GraphicPair
  portrait  as GraphicPair
  preview_steps as integer
  preview_walk_direction as integer
  preview_walk_pos as XYPair
END TYPE

TYPE TextboxEditState
  id as integer
  portrait as GraphicPair
  search as string
END TYPE

TYPE TextboxConnectNode
  lines(2) as string
  id as integer 'ID of box or < 0 for script
  style as integer
  add as integer 'NO normally. YES if this is for adding a new box
END TYPE

ENUM MapEditMode
  tile_mode
  pass_mode
  door_mode
  npc_mode
  foe_mode
  zone_mode
END ENUM

ENUM ZoneEditSubmode
  zone_edit_mode
  zone_view_mode
END ENUM

ENUM LayerDisplayMode
  layerDisplayNormal
  layerDisplayTinted    'Tinted by height
  layerDisplayHighlight 'Highlight the selected one, greyscale others
  layerDisplayNUM
END ENUM

ENUM MapMouseAttention
  focusNowhere
  focusMap
  focusViewport  'Main part of the screen, but off the map edge
  focusToolbar   'The tool buttons
  focusTopbar
END ENUM

ENUM WallStylesEnum
  wallStyleAnts = 0
  wallStyleOutlined = 1
  wallStylePulse = 2
  wallStyleLAST = 2
END ENUM

ENUM ScreenOutlineMode
  outlineHidden
  outlineFixed
  outlineFollowsCursor
  outlineLAST = 2
END ENUM

'MapIDs used for undo steps
'FIXME:a bit of a mess, clean up later
ENUM 'MapID
  mapIDMetaBEGIN = -11
  mapIDMetaCursor = -11    'Stores cursor position at beginning of stroke
  mapIDMetaEditmode = -10  'to -1. .value is mode specific.
  mapIDMetaEditmodeEND = -1
  mapIDZone = 0   'to 9999
  mapIDPass = 10000
  mapIDFoe = 10001
  mapIDLayer = 10002  'to 10099
END ENUM
TYPE MapID as short

TYPE MapEditUndoTile
  x as ushort
  y as ushort
  value as short
  mapid as MapID
END TYPE

DECLARE_VECTOR_OF_TYPE(MapEditUndoTile, MapEditUndoTile)
DECLARE_VECTOR_OF_TYPE(MapEditUndoTile vector, MapEditUndoTile_vector)

TYPE MapEditStateFwd as MapEditState

TYPE FnBrush as SUB (st as MapEditStateFwd, byval x as integer, byval y as integer, byval value as integer = -1, byval extraarg as integer = -1)
TYPE FnReader as FUNCTION (st as MapEditStateFwd, byval x as integer, byval y as integer, byval extraarg as integer = -1) as integer

TYPE MapEditState EXTENDS CommonEditState
  map as MapData

  editmode as integer        'ENUM MapEditMode
  seteditmode as integer     'Normally -1, set to an editmode to cause a switch
  UNION
    TYPE
      x as integer           'Cursor position, in tiles
      y as integer
    END TYPE
    pos as XYPair
  END UNION
  UNION
    TYPE
      mapx as integer            'Camera position (top left of viewable area), in pixels
      mapy as integer
    END TYPE
    camera as XYPair
  END UNION
  viewport as RectType       'The part of the screen where the map is drawn
                             '(not clamped to actual map size)
  viewport_p2 as XYPair      'For convenience, bottom-right corner of viewport

  'Layer state
  layer as integer
  visible(maplayerMax \ 16) as integer  'Bitsets: layers which are visible
  jiggle(maplayerMax \ 16) as integer   'Bitsets: layers which are jiggling
  layer_display_mode as LayerDisplayMode  'What effect to apply to layers
  layerpals(maplayerMax + 1) as Palette16 ptr  '+1 for overhead layer
  shadowpal as Palette16 ptr 'Palette used for things in shadow
  per_layer_skew as XYPair   'Amount to displace map layer 1. In tenths of a pixel
  mouse_skewing as bool      'Currently using the right mouse button to skew the map
  drag_camera_start as XYPair 'st.camera at start of pan

  mouse_attention as MapMouseAttention 'What currently recieves mouse input
  mouse_active as bool       'The mouse was last used to move the cursor, rather than the keyboard
  defpass as bool            'Default passability ON/OFF
  cur_foe as integer         'Formation set selected for placement
  cur_npc as integer         'NPC ID selected for placement
  cur_door as integer        'Door number selected
  usetile(0 to maplayerMax) as integer  'Tile selected for each layer

  menubarstart(0 to maplayerMax) as integer
  menubar as TileMap
  cursor as GraphicPair
  npc_cursor_frame as integer  'frame num for the NPC cursor in npc_mode
  npc_inst_iter as integer    'Current NPC instance number, when `C`ycling through them
  tilesets(maplayerMax) as TilesetData ptr  'Tilesets is fixed size at the moment. It must always be at least as large as the number of layers on a map
  npc_img(any) as GraphicPair
  defaultwalls as integer vector vector  'indexed by layer (variable length) and then by tile (always 0-159)
  temptilemap as TileMap     'A temporary TileMap. Normally remains uninitialised
  moved as integer          'used when detecting cursor movement
  walk as integer           'used for animating NPC walking
  doorid as integer

  modenames(5) as string
  mode_tools as integer vector
  toolsbar_available as integer  'Whether you can select the current tool
  drawing_allowed as integer     'Whether you can actually draw
  toolinfo(NUM_TOOLS) as ToolInfoType
  hero_gfx as GraphicPair
  overlaytileset as Frame ptr
  zonetileset(2) as Frame ptr
  arrow_icons(12) as Frame ptr
  lockedzonelist(any) as integer
 
  tiny as bool               'whether or not to show the tiny screen relative to map area
  screen_outline as ScreenOutlineMode 'Setting for showing an outline of how large the in-game screen is
  screen_outline_focus as XYPair      'Center of the screen outline, in map-coord pixels
  wallmap_mask as integer    'used by wallbitsbrush

  'Editor customisation options
  shift_speed as XYPair      'Cursor move speen when holding Shift
  cursor_follows_mouse as bool 'st.pos follows the mouse
  wall_style as WallStylesEnum  'How walls appear
  wallthickness as integer   'How many pixels thick to draw the walls in pass_mode
  show_overhead_bit as bool  'Show 'O' while in tilemap mode
  animations_enabled as bool 'Tile animations
  layers_share_usetile as bool 'Current tile is per-tileset
  mouse_pan_mult as double   'When panning the map with the mouse, how much to multiply the movements by
  shadows_when_skewing as bool
  show_grid as bool
  grid_color as integer      'Master pal color index, or 0 to flash instead

  'Tool stuff
  tool as integer            'Tool ID (index in toolinfo), or -1 if none (meaning none available)
  brush as FnBrush           'What to draw with
  reader as FnReader         'What to read with
  tool_value as integer      'Value (eg. tile) with which to draw. Should never be -1.
  reset_tool as bool         'When true, tool_value should be set to some default
  tool_hold as bool          'True if one coordinate has been selected
  tool_hold_pos as XYPair    'Held coordinate
  last_pos as XYPair         'Position of the cursor last tick
  new_stroke as bool         'True before beginning a new editing operation (group of brush() calls)
  'history is in CommonEditState
  'history as MapEditUndoTile vector vector   'Vector of groups of tile edits
  history_size as integer    'Size of history, in number of MapEditUndoTiles (each is 8 bytes)
  'history_step as integer    'In history, [0, history_step) are undos, and the rest are redos
  secondary_undo_buffer as MapEditUndoTile vector
                             'Usually NULL. If not, undo steps are added to this vector instead
                             'of the history. Used for previewing undoable changes.

  DECLARE SUB undo_stroke_internal(byref changelist as MapEditUndoTile vector, byval redo as bool = NO)

  'Mark+clone
  cloned as MapEditUndoTile vector  'Cloned brush. NULL if none. Offsets are 0,0 at topleft of brush
  clone_offset as XYPair     'Handle point on the clone brush
  clone_size as XYPair       'Size of the cloned brush in tiles
  multitile_draw_brush as bool 'When true and clone tool is in use the clone brush is meant to act like
                               'the draw tool: changing map layer or .tool_value resets the tool to Draw
  clone_merge as bool        'Whether to preserve existing tiles rather than removing them

  'Zone stuff (st.editmode = zone_mode)
  zonesubmode as ZoneEditSubmode
  cur_zone as integer        'Zone ID selected for placement
  cur_zinfo as ZoneInfo ptr  '== GetZoneInfo(zonemaps, cur_zone)
  zones_needupdate as integer
  zoneviewmap as TileMap     'Each bit indicates one of 8 currently displayed zones
  zoneoverlaymap as TileMap  'For other overlays drawn by zonemode
  zoneminimap as Frame ptr   '1/20x zoomed view of cur_zone
  zoneviewtileset as integer 'Which of zonetileset() to use to draw zoneviewmap
  autoshow_zones as integer  'Zones at current tile become visible ("Autoshow zones")
  showzonehints as integer   'Display 'hints' where nonvisible zones are ("Show other")
  zonecolours(7) as integer  'The zone assigned to each colour, or 0. Includes "memories" of zones not currently displayed
  'Zone stuff (npc_mode)
  cur_npc_zone as integer    'Movement zone for currently selected NPC in NPC placer
  cur_npc_wall_zone as integer 'Avoidance zone for currently selected NPC in NPC placer

  zonemenu as SimpleMenuItem vector
  zonemenustate as MenuState
  npczone_needupdate as bool
  gauze_ticker as integer = 0  'for hidden zones animation
END TYPE

TYPE MapResizeState
  menu as MenuDef
  rect as RectType
  oldsize as XYPair
  zoom as integer
  minimap as Frame Ptr
END TYPE

TYPE AttackChainBrowserState
 root as Slice Ptr
 lbox as Slice Ptr
 rbox as Slice Ptr
 current as Slice Ptr
 after as MenuState
 before as MenuState
 chainfrom as Slice ptr vector
 chainto as Slice ptr vector
 column as integer
 refresh as integer
 focused as Slice Ptr
 done as integer
END TYPE

TYPE ShopEditState
 id as integer
 st as MenuState
 name as string
 menu(24) as string
 shaded(24) as bool
 havestuf as bool
END TYPE

TYPE ShopStuffState
 st as MenuState
 thing as integer       'Hero/item ID number
 thingname as string
 item_value as integer  'Garbage if thing is a hero
 menu(24) as string
 max(24) as integer
 min(24) as integer
END TYPE

' Abstract base class to draw a preview for a record (usually at the bottom right of the screen),
' currently used only for generic_add_new.
' TODO: this is very similar to ThingBrowser, maybe they could be merged?
TYPE RecordPreviewer EXTENDS object
  DECLARE VIRTUAL DESTRUCTOR()
  'Passing an invalid recordidx should result in no preview and is not an error.
  'update() might be called with the same record as last time, if the screen size has changed.
  DECLARE ABSTRACT SUB update(recordidx as integer)
  DECLARE ABSTRACT SUB draw(xpos as RelPos, ypos as RelPos, page as integer)
END TYPE

' Preview a map by showing a minimap. The minimap doesn't try to cover the whole screen:
' the maximum size of the minimap is the screen size minus margin.
' Generation of the minimap is delayed, so that it doesn't make controls unresponsive
TYPE MapPreviewer EXTENDS RecordPreviewer
  PRIVATE:
    margin as XYPair             'Screen margin, reduces size of the minimap
    wantminimap as integer       'Map ID or -1 if no minimap calculation pending
    load_minimap_timer as double 'When to load a delayed minimap
    instant_threshold as integer 'Map size in tiles: if smaller, loading is not delayed
    minimap as Frame ptr

  PUBLIC:
    DECLARE CONSTRUCTOR(screen_margin as XYPair = XY(14 * 8, 0))
    DECLARE DESTRUCTOR()
    DECLARE SUB update(map_id as integer)
    DECLARE SUB draw(xpos as RelPos, ypos as RelPos, page as integer)
END TYPE

#ENDIF
