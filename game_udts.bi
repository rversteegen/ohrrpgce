#IFNDEF GAME_UDTS_BI
#DEFINE GAME_UDTS_BI

#INCLUDE "slices.bi"

'This file contains UDTs that only get used in game mode, and not in custom,
'so as to prevent them from cluttering up the global udts.bi file

TYPE MapModeState
  id       as integer
  lastmap  as integer 'ID of the last loaded map
  same     as bool    'flag that indicates when you are moving through a same-map door
  name     as string
  door(99) as Door
  doorlinks(199) as doorlink
END TYPE

TYPE HeroStats
  base as Stats  'Without equipment, caps, (or in future buffs) applied
  cur as Stats
  max as Stats
END TYPE

TYPE HeroState
 id as integer = -1 ' set to -1 for empty slots
 name as string
 locked as bool
 stat as HeroStats
 lev as integer
 lev_gain as integer
 exp_cur as integer
 exp_next as integer
 wep_pic as integer
 wep_pal as integer
 battle_pic as integer
 battle_pal as integer
 def_wep as integer  'default weapon
 pic as integer
 pal as integer
 portrait_pic as integer
 portrait_pal as integer
 rename_on_status as bool  'Renameable in status menu
 elementals(maxElements - 1) as single
 hand_pos(1) as XYPair
END TYPE

TYPE HeroWalkabout
  sl as Slice Ptr
  xgo as integer
  ygo as integer
  wtog as integer
  speed as integer
  curzones as integer vector = 0
  'x, y, z, dir are in catx(), caty(), catz(), catd() instead *grumble*

  Declare Destructor()  'Free curzones
END TYPE

TYPE ScriptLoggingState
  enabled as bool
  filename as string
  tick as integer                    'Number of times interpret has been called
  last_logged as integer             'scrat index
  output_flag as bool                'Set to true after script_log_out called
  last_wait_msg as string
  wait_msg_repeats as integer        'Number of ticks in a row with identical last_wait_msg
  last_script_childtime as double    'Seconds of child run time by the last watched script to finish
END TYPE

'Set by script commands (or other triggers) to signal that they want something to be done after leaving the
'script interpreter (used to be called wantdoor, etc).
'These actions are delayed for historical/backcompat reasons; see interpret().
TYPE ScriptWantSignals
  box as integer      'Textbox, or 0 for none (can't ask to show box 0)
  door as integer     'Door number +1
  battle as integer   'Formation number +1
  teleport as bool    'Map num has changed, call preparemap()
  usenpc as integer   'NPC instance +1
  rungame as string   'Path to game to load, or ""
  loadgame as integer 'Save slot +1
  resetgame as bool   'Called "reset game"
  dont_quit_to_loadmenu as bool 'If no title screen, don't quit to the load menu.

  script_args(any) as integer  'Arguments to newgame/loadgame
END TYPE

'Used when automatically updating the visibility of the virtual gamepad
'(Android only)
TYPE VirtualGamePadState
  in_battle as bool = NO
  script_hide_virtual_gamepad as bool
  script_show_virtual_gamepad as bool
  script_wants_keys as integer = 0
  being_shown as bool
END TYPE

TYPE GameState
  map as MapModeState
  wonbattle as bool                  'Indicates the status of the last battle (won as opposed to dying or running or 'force exit')
  remembermusic as integer           'Remembers music from before battle starts
  music_change_delay as integer      'Number of ticks to wait before changing music; <= 0 if no change pending
  delayed_music as integer           'Song number to change to, -1 to stop music
  random_battle_countdown as integer
  stock(99, 49) as integer           'Keeps track of available inventory at each shop (shop, stuffnum)
                                     'Each entry is either -1 (infinite stock), 0 (not loaded; will be loaded
                                     'when the shop is visited unless stuffnum is past the last stuff)
                                     'or remainingstock+1 if >= 0
  foe_freq(254) as integer           'A cache of the fight frequency for each formation set
  walk_through_walls as bool         'used for F11 cheat mode
  mouse_enabled as bool              'initmouse called
  mouse as MouseInfo
  hero(40) as HeroState
  debug_showtags as bool
  debug_npc_info as bool
  autorungame as bool                'Game was autorun, not selected from RPG browser
  return_to_browser as bool          'Return to browser when quitting the game
  need_fade_in as bool
  fade_in_delay as integer
  fade_in_script_overridable as bool 'If true, the fade in can be cancelled by a fadescreenout command
  current_master_palette as integer  'Modified by "load palette" command
  showtext as string                 'Used for map names and other alerts
  showtext_ticks as integer          'Remaining number of ticks
  showstring as string               'The text shown by showvalue/showstring commands
  getinputtext_enabled as bool
  script_log as ScriptLoggingState
  want as ScriptWantSignals
  quit as bool                       'Quit back to titlescreen
  pad as VirtualGamePadState
  user_toggled_fullscreen as bool    'User changed the default for this game
  non_elemental_elements(63) as bool 'Loaded by load_non_elemental_elements()
END TYPE

'Note that .showing, .fully_shown, .sayer need to be always correct even if no box is up
TYPE TextBoxState
  id             as integer 'ID Number of the current box or -1 for none
  box            as TextBox 'Contains the data about the content of the textbox
  showing        as bool
  fully_shown    as bool    'All lines have been displayed, player is allowed to advance. False if no textbox
  choicestate    as MenuState 'Choicebox menu control
  remember_music as integer
  show_lines     as integer 'Number of lines currently on display
  sayer          as integer 'The NPC reference who triggered this textbox as a positive number, or -1 for none
  old_dir        as integer 'For NPCs that return to their previos direction after speaking
  sl             as Slice Ptr
END TYPE

TYPE EquippableList
  count as integer
  offset(inventoryMax) as integer 'Index into the inventory, or -1 for nothing
END TYPE

TYPE EquipMenuState
  mode                as integer '0=picking slot 1=picking equipment to put in slot
  who                 as integer
  slot                as integer
  eq_cursor           as MenuState
  default_weapon      as integer 'item ID + 1
  default_weapon_name as string
  unequip_caption     as string
  eq(4)               as EquippableList
  stat_bonus(11)      as integer 'Cache stat bonuses for currently selected equippable
  stat_total_bonus(11) as integer 'Total stat bonuses for all hero equip after equipping selected equippable
  hero                as HeroDef
END TYPE

TYPE SpellsMenuSlot
  id      as integer    'attack id (or -1 for none)
  name    as string
  desc    as string
  cost    as string
  can_use as bool       'Useable OOB
  targt   as integer
  tstat   as integer
END TYPE

TYPE SpellsMenuList
  name       as string
  menu_index as integer 'maps to index in spells() global
  magic_type as integer
END TYPE

TYPE SpellsMenuState
  hero      as integer
  listnum   as integer
  last      as integer 'last occupied slot in .lists()
  lists(4)  as SpellsMenuList
  spell(24) as SpellsMenuSlot
  quit      as bool
  cursor    as integer
  mset      as integer
  re_use    as bool
  page      as integer
  tog       as bool
  cancel_menu_caption as string
  has_none_caption as string
END TYPE

TYPE ShopBuyState
  shop_id        as integer
  shoptype       as integer
  stuff_list     as NodePtr
  selected       as NodePtr
  curslot        as integer
  root_sl        as Slice Ptr
  money_sl       as Slice Ptr
  info_sl        as Slice Ptr
  hero_box       as Slice Ptr
  party_box(3)    as Slice Ptr
  party_sl(3)    as Slice Ptr
  price_box      as Slice Ptr
  price_sl       as Slice Ptr
  alert_box      as Slice Ptr
  alert_sl       as Slice Ptr
  hire_box       as Slice Ptr
  hire_sl        as Slice Ptr
  portrait_box   as Slice Ptr
  portrait_sl    as Slice Ptr
  tog            as integer
  walk           as integer
  info           as MenuDef
  info_st        as MenuState
END TYPE

TYPE OrderTeamState
  party as MenuState
  reserve as MenuState
  info as string
  swapme as integer
  size as XYPair 'not in pixels
  swindex(40) as integer
  swname(40) as string
  show_reserve as bool
  page as integer
END TYPE

TYPE LumpReloadState
  mode      as integer  'one of the loadmode constants in const.bi
  dirty     as bool     'whether a script has modified this (referring to current map, if applicable)
  changed   as bool     'whether modified by Custom and not reloaded
  hash      as integer  'used to store file_hash of last version loaded
END TYPE

TYPE LumpReloadOptions
  gmap     as LumpReloadState  '.hash not (can't) be used
  maptiles as LumpReloadState
  passmap  as LumpReloadState
  foemap   as LumpReloadState  '.dirty ignored: can't be modified
  zonemap  as LumpReloadState
  npcl     as LumpReloadState  '.dirty ignored: nearly always dirty
  npcd     as LumpReloadState

  hsp      as LumpReloadState  '.hash, .dirty ignored
END TYPE

TYPE VirtualKeyboardScreenState
 sl as Slice Ptr
 result as string
 max_length as integer = -1
 prompt as string
 done as bool = NO
 entry_sl as Slice Ptr
 select_sl as Slice Ptr
 shift as bool
 symbols as bool
 arr as any ptr vector
 pushed_sl as Slice Ptr
 drag_off as bool
END TYPE

TYPE DebugMenuDef
 menu as string vector    ' List of menu item names. NULL if we're checking key combos instead
 selected_item as string  ' If this is set, find the menu item with this name instead of building the menu.
 Declare Sub start_building_menu()
 Declare Destructor()
 Declare Function def(combining_scancode as integer = 0, scancode as integer = 0, menuitem as string = "") as bool
END TYPE

#ENDIF
