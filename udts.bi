#IFNDEF UDTS_BI
#DEFINE UDTS_BI

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
  vechicle as integer    '+14
END TYPE

TYPE NPCInst
  x as integer      'npcl+0
  y as integer      'npcl+300
  xgo as integer    'npcl+1500
  ygo as integer    'npcl+1800
  id as integer     'npcl+600
  dir as integer    'npcl+900
  frame as integer  'npcl+1200
  extra1 as integer
  extra2 as integer
END TYPE

TYPE InventSlot
  used : 1 as integer	'use this to check if empty, not num!

  'following fields should not be used if used = 0
  id as integer		'absolute, not +1!!
  num as integer
  text as string	'text field which shows up in inventory, blank if empty
END TYPE

TYPE BattleSprite
  basex AS INTEGER
  basey AS INTEGER
  x AS INTEGER
  y AS INTEGER
  z AS INTEGER
  w AS INTEGER
  h AS INTEGER
  d AS INTEGER
  xmov AS INTEGER
  ymov AS INTEGER
  zmov AS INTEGER
  xspeed AS INTEGER
  yspeed AS INTEGER
  zspeed AS INTEGER
  vis AS INTEGER
  hero_untargetable AS INTEGER
  enemy_untargetable AS INTEGER
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
'  off as integer        'position of the script in the buffer
  scrnum as integer     'slot number in script() array
  heap as integer       'position of the script's local vars in the buffer
  state as integer      'what the script is doing right now
  ptr as integer        'the execution pointer
'  vars as integer       'variable (including arguments) count
  ret as integer        'the scripts current return value
  curkind as integer    'kind of current statement
  curvalue as integer   'value of current stament
  curargc as integer    'number of args for current statement
  curargn as integer    'current arg for current statement
  depth as integer      'stack depth of current script
  id as integer         'id number of current script
  waitarg as integer    'wait state argument
'  size as integer       'amount the script takes up in the buffer
'  args as integer       'number of arguments
'  strtable as integer   'pointer to string table
END TYPE

TYPE ScriptData
  id as integer         'id number of script  (set to 0 to mark as unused slot)
  refcount as integer   'number of ScriptInst pointing to this data
  totaluse as integer   'total number of times this script has been requests since loaded
  lastuse as integer
  ptr as integer ptr    'pointer to allocated memory
  size as integer       'amount the script takes up in the buffer
  vars as integer       'variable (including arguments) count
  args as integer       'number of arguments
  strtable as integer   'pointer to string table (offset from start of script data in long ints)
END TYPE

UNION RGBcolor
	as uinteger col
		TYPE
			as ubyte b, g, r, a
		END TYPE
END UNION

Type TilesetData field=1
	TransColor as Integer
End Type

TYPE TileEditState
 x as INTEGER
 y as INTEGER
 tilex as INTEGER
 tiley as INTEGER
 gotmouse as INTEGER
 drawcursor as INTEGER
 tool as INTEGER
 curcolor as INTEGER
 hidemouse as INTEGER
 airsize as INTEGER
 mist as INTEGER
 undo as INTEGER
 allowundo as INTEGER
 zone as INTEGER
 justpainted as INTEGER
 hold as INTEGER
 hox as INTEGER
 hoy as INTEGER
 cutfrom as INTEGER
 canpaste as INTEGER
 delay as INTEGER
END TYPE


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
