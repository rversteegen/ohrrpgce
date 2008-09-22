#IFNDEF UDTS_BI
#DEFINE UDTS_BI

#INCLUDE "const.bi"

UNION XYPair
  TYPE
   x AS INTEGER
   y AS INTEGER
  END TYPE
  n(1) AS INTEGER
END UNION

TYPE RectType
  x AS INTEGER
  y AS INTEGER
  wide AS INTEGER
  high AS INTEGER
END TYPE

TYPE Palette16
	col(15) as ubyte 'indicies into the master palette
	refcount as integer 'private
END TYPE

'sprites use this
type Frame
	w as integer
	h as integer
	image as ubyte ptr
	mask as ubyte ptr
	refcount as integer
	cache as string
end type

TYPE GraphicPair
	sprite as frame ptr
	pal as palette16 ptr
END TYPE

TYPE MenuSet
  menufile  AS STRING
  itemfile AS STRING
END TYPE

TYPE MenuDefItem
  handle    AS INTEGER
  exists    AS INTEGER
  disabled  AS INTEGER ' set at run-time based on .tag1 and .tag2
  member    AS INTEGER
  caption   AS STRING
  sortorder AS INTEGER
  t         AS INTEGER
  sub_t     AS INTEGER
  tag1      AS INTEGER
  tag2      AS INTEGER
  settag    AS INTEGER
  togtag    AS INTEGER
  extra(2)  AS INTEGER
  hide_if_disabled  AS INTEGER ' Bitset
  close_if_selected AS INTEGER ' Bitset
END TYPE

TYPE MenuDef
  record    AS INTEGER
  handle    AS INTEGER
  name      AS STRING
  boxstyle  AS INTEGER
  textcolor AS INTEGER
  maxrows   AS INTEGER
  edit_mode AS INTEGER 'Never hide disabled items, allow selection of unselectable items
  items(20) AS MenuDefItem
  translucent      AS INTEGER ' Bitset 0
  no_scrollbar     AS INTEGER ' Bitset 1
  allow_gameplay   AS INTEGER ' Bitset 2
  suspend_player   AS INTEGER ' Bitset 3
  no_box           AS INTEGER ' Bitset 4
  no_close         AS INTEGER ' Bitset 5
  no_controls      AS INTEGER ' Bitset 6
  prevent_main_menu AS INTEGER ' Bitset 7
  advance_textbox  AS INTEGER ' Bitset 8
  rect      AS RectType
  offset    AS XYPair
  anchor    AS XYPair
  align     AS INTEGER
  min_chars AS INTEGER
  max_chars AS INTEGER
  bordersize AS INTEGER
END TYPE

TYPE MenuState
  active    AS INTEGER
  pt        AS INTEGER 'currently selected item
  top       AS INTEGER 'scroll position for long lists
  first     AS INTEGER 'first element (usually zero)
  last      AS INTEGER 'last element
  size      AS INTEGER 'number of elements to display at a time (actually index of last to display relative to top, so "size"-1)
  need_update AS INTEGER 'menu needs some kind of update
  tog       AS INTEGER ' For flashing cursor
END TYPE

TYPE NPCType
  picture as integer     '+0
  palette as integer     '+1
  movetype as integer    '+2
  speed as integer       '+3  real speed, not value in .d
  textbox as integer     '+4
  facetype as integer    '+5
  item as integer        '+6
  pushtype as integer    '+7
  activation as integer  '+8
  tag1 as integer        '+9   appear only if
  tag2 as integer        '+10  appear only if 2
  usetag as integer      '+11
  script as integer      '+12
  scriptarg as integer   '+13
  vehicle as integer     '+14
  sprite as frame ptr
  pal as palette16 ptr
END TYPE

TYPE NPCInst
  x as integer      'npcl+0
  y as integer      'npcl+300
  xgo as integer    'npcl+1500   warning: positive to go LEFT, negative RIGHT
  ygo as integer    'npcl+1800   reversed as above
  id as integer     'npcl+600
  dir as integer    'npcl+900
  frame as integer  'npcl+1200
  extra1 as integer
  extra2 as integer
END TYPE

TYPE InventSlot
  used as integer	'use this to check if empty, not num!

  'following fields should not be used if used = 0
  id as integer		'absolute, not +1!!
  num as integer
  text as string	'text field which shows up in inventory, blank if empty
END TYPE

TYPE Timer
  count as integer
  speed as integer
  ticks as integer
  trigger as integer
  flags as integer
  st as integer 'string, but both str and string are reserved
END TYPE

TYPE Plotstring
  s as string
  X as integer
  Y as integer
  col as integer
  bgcol as integer
  bits as integer
END TYPE

TYPE ScriptInst
  scrnum as integer     'slot number in script() array
  scrdata as integer ptr 'convenience pointer to script(.scrnum).ptr
  heap as integer       'position of the script's local vars in the buffer
  state as integer      'what the script is doing right now
  ptr as integer        'the execution pointer (in int32's from the start of the script data)
  ret as integer        'the scripts current return value
  curargn as integer    'current arg for current statement
  depth as integer      'stack depth of current script
  id as integer         'id number of current script
  waitarg as integer    'wait state argument

  'these 3 items are only current/correct for inactive scripts. The active script's current
  'command is pointed to by the curcmd (ScriptCommand ptr) global, and copied here
  'when a script is stopped (either suspended, or interpretloop is left)
  curkind as integer    'kind of current statement
  curvalue as integer   'value of current statement
  curargc as integer    'number of args for current statement
END TYPE

TYPE ScriptData
  id as integer         'id number of script  (set to 0 to mark as unused slot)
  refcount as integer   'number of ScriptInst pointing to this data
  totaluse as integer   'total number of times this script has been requested since loading
  lastuse as integer
  ptr as integer ptr    'pointer to allocated memory
  size as integer       'amount the script takes up in the buffer
  vars as integer       'variable (including arguments) count
  args as integer       'number of arguments
  strtable as integer   'pointer to string table (offset from start of script data in long ints)
END TYPE

TYPE ScriptCommand
  kind as integer
  value as integer
  argc as integer
  args(999999) as integer
END TYPE

UNION RGBcolor
	as uinteger col
		TYPE
			as ubyte b, g, r, a
		END TYPE
END UNION

Type TileAnimState
 cycle AS INTEGER
 pt AS INTEGER
 skip AS INTEGER
END Type

Type TilesetData
  num as integer
  refcount as integer  'exists (and unused) in spr too, but using that one would be tacky
  spr as Frame ptr     '(uncached) could be a Frame, but sprite_delete doesn't like that
  anim(1) as TileAnimState
  tastuf(40) as integer
End Type

Type Door
	as integer x, y
	as integer bits(0)
End Type

Type DoorLink
	as integer source, dest, dest_map, tag1, tag2
End Type

Union Stats
       Type
               hp as integer
               mp as integer
               str as integer
               acc as integer
               def as integer
               dog as integer
               mag as integer
               wil as integer
               spd as integer
               ctr as integer
               foc as integer
               hits as integer
       End Type
       sta(11) as integer
End Union

Type SpellList
	attack as integer
	learned as integer
End Type

Type HeroDef
	name as string
	sprite as integer
	sprite_pal as integer
	walk_sprite as integer
	walk_sprite_pal as integer
	portrait as integer
	portrait_pal as integer
	def_level as integer
	def_weapon as integer
	Lev0 as stats
	Lev99 as stats
	spell_lists(3,23) as SpellList
	bits(2) as integer
	list_name(3) as string
	list_type(3) as integer
	have_tag as integer
	alive_tag as integer
	leader_tag as integer
	active_tag as integer
	max_name_len as integer
	hand_a_x as integer
	hand_a_y as integer
	hand_b_x as integer
	hand_b_y as integer
End Type

TYPE TextBox
  text(7) AS STRING
  instead_tag AS INTEGER
  instead     AS INTEGER
  settag_tag  AS INTEGER
  settag1     AS INTEGER
  settag2     AS INTEGER
  battle_tag  AS INTEGER
  battle      AS INTEGER
  shop_tag    AS INTEGER
  shop        AS INTEGER
  hero_tag    AS INTEGER
  hero_addrem AS INTEGER
  hero_swap   AS INTEGER
  hero_lock   AS INTEGER
  after_tag   AS INTEGER
  after       AS INTEGER
  money_tag   AS INTEGER
  money       AS INTEGER
  door_tag    AS INTEGER
  door        AS INTEGER
  item_tag    AS INTEGER
  item        AS INTEGER
  menu_tag    AS INTEGER
  menu        AS INTEGER
  choice_enabled AS INTEGER
  no_box      AS INTEGER
  opaque      AS INTEGER
  restore_music AS INTEGER
  choice(1)   AS STRING
  choice_tag(1) AS INTEGER
  vertical_offset AS INTEGER ' in 4-pixel increments
  shrink      AS INTEGER     ' in 4-pixel increments
  textcolor   AS INTEGER     ' 0=default
  boxstyle    AS INTEGER
  backdrop    AS INTEGER     ' +1
  music       AS INTEGER     ' +1
  portrait_box  AS INTEGER
  portrait_type AS INTEGER
  portrait_id   AS INTEGER
  portrait_pal  AS INTEGER
  portrait_pos  AS XYPair
END TYPE

TYPE MouseArea
  x AS INTEGER
  y AS INTEGER
  w AS INTEGER
  h AS INTEGER
  hidecursor AS INTEGER
END TYPE

TYPE ToolInfoType
  name AS STRING
  icon AS STRING
  shortcut AS INTEGER
  cursor AS INTEGER
  areanum AS INTEGER
END TYPE

'yuck. FB has multidimensional arrays, why doesn't it let us utilise 'em? would like to write
'DIM defaults(2,160)
'loadpasdefaults defaults(i), foo
TYPE DefArray
 a(160) AS INTEGER  '161 elements required
END TYPE

'it's not possible to include utils.bi in here, because of compat.bi
#ifndef UTIL_BI
TYPE Stack
  pos as integer ptr
  bottom as integer ptr
  size as integer
END TYPE
#endif

'Documentation of veh() in game, which is different from the VEH lump
'0 is true (-1) if in/mounting/dismounting a vehicle
'1-4 unused
'5 is the npc ref of the vehicle
'6 contains (a second set of) bitsets describing what the vehicle is doing
'veh(6)==0 is checked to see if something vehicle related is happening
''bit 0 scrambling/mounting
''bit 1 rising
''bit 2 falling
''bit 3 initiate dismount
''bit 4 clear - set to clean up to officially end vehicle use
''bit 5 ahead - set while getting off (dismount ahead only)
'7 remembers the speed of the leader 
'8-21 are copied from VEH


#ENDIF
