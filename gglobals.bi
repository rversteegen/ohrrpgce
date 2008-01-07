'OHRRPGCE GAME - Globals
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'

#include "udts.bi"

'Misc game globals
EXTERN sourcerpg as string
EXTERN prefsdir as string ' currently only used by Linux
EXTERN savefile as string
EXTERN timing() as integer
EXTERN pal16() as integer
EXTERN names() as string
EXTERN speedcontrol as integer
EXTERN deferpaint as integer
EXTERN presentsong as integer
EXTERN foemaph as integer
EXTERN lastsaveslot as integer
EXTERN abortg as integer
EXTERN usepreunlump as integer
EXTERN fatal as integer
EXTERN backcompat_sound_slot_mode as integer
EXTERN backcompat_sound_slots()

'Input handling globals
EXTERN as integer carray(), csetup()
EXTERN as integer gotj(), joy()
EXTERN as integer mouse()

'Game state globals
EXTERN tag() as integer
EXTERN global() as integer

'Vehicle globals
EXTERN veh() as integer

'Hero globals
EXTERN hero() as integer
EXTERN eqstuf() as integer
EXTERN lmp() as integer
EXTERN bmenu() as integer
EXTERN spell() as integer
EXTERN exlev() AS LONG
EXTERN herobits()
EXTERN itembits()
EXTERN hmask() as integer
EXTERN gold AS LONG
EXTERN nativehbits() as integer

'Map state globals
EXTERN gmap() as integer
EXTERN scroll() as integer
EXTERN pass() as integer
EXTERN as integer mapx, mapy
EXTERN framex as integer
EXTERN framey as integer

'Hero walkabout globals
EXTERN as integer catx(), caty(), catz(), catd()
EXTERN herospeed() as integer
EXTERN as integer xgo(), ygo()
EXTERN wtog() as integer
EXTERN catermask() as integer

'NPC globals
EXTERN npcs() as NPCType
EXTERN npc() as NPCInst

'Item globals
EXTERN inventory() as InventSlot

'Script globals
EXTERN script() as ScriptData
EXTERN heap() as integer
EXTERN scrat() as ScriptInst
EXTERN retvals() as integer
EXTERN nowscript as integer
EXTERN scriptret as integer
EXTERN numloadedscr as integer
EXTERN totalscrmem as integer
EXTERN scriptctr as integer
EXTERN scrst as Stack

'Script string globals
'EXTERN plotstring() as string
'EXTERN plotstrX(), plotstrY()
'EXTERN plotstrCol()
'EXTERN plotstrBGCol()
'EXTERN plotstrBits()
EXTERN plotstr() as Plotstring

'Battle globals
EXTERN battlecaption as string
EXTERN battlecaptime as integer
EXTERN battlecapdelay as integer
EXTERN bstackstart as integer
EXTERN learnmask() as integer

EXTERN timers() as Timer

EXTERN map_draw_mode as integer

'Menu globals
EXTERN menus() as MenuDef
EXTERN mstates() as MenuState
EXTERN menu_set as MenuSet
EXTERN topmenu as INTEGER
