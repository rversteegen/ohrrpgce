'OHRRPGCE GAME - Globals
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'

#include "udts.bi"

'Misc game globals
EXTERN sourcerpg$
EXTERN prefsdir$ ' currently only used by Linux
EXTERN savefile$
EXTERN timing()
EXTERN pal16()
EXTERN names$()
EXTERN speedcontrol
EXTERN deferpaint
EXTERN presentsong
EXTERN foemaph
EXTERN lastsaveslot
EXTERN abortg
EXTERN usepreunlump%
EXTERN fatal
EXTERN backcompat_sound_slot_mode
EXTERN backcompat_sound_slots()

'Input handling globals
EXTERN carray(), csetup()
EXTERN gotj(), joy()
EXTERN mouse()

'Game state globals
EXTERN tag()
EXTERN global()

'Vehicle globals
EXTERN veh()

'Hero globals
EXTERN hero()
EXTERN eqstuf()
EXTERN lmp()
EXTERN bmenu()
EXTERN spell()
EXTERN exlev() AS LONG
EXTERN herobits%()
EXTERN itembits%()
EXTERN hmask()
EXTERN gold AS LONG
EXTERN nativehbits()

'Map state globals
EXTERN gmap()
EXTERN scroll()
EXTERN pass()
EXTERN mapx, mapy
EXTERN framex
EXTERN framey

'Hero walkabout globals
EXTERN catx(), caty(), catz(), catd()
EXTERN herospeed()
EXTERN xgo(), ygo()
EXTERN wtog()
EXTERN catermask()

'NPC globals
EXTERN npcs() as NPCType
EXTERN npc() as NPCInst

'Item globals
EXTERN inventory() as InventSlot

'Script globals
EXTERN script() as ScriptData
EXTERN heap()
EXTERN scrat() as ScriptInst
EXTERN retvals()
EXTERN nowscript
EXTERN scriptret
EXTERN numloadedscr
EXTERN totalscrmem
EXTERN scriptctr
EXTERN scrst as Stack

'Script string globals
'EXTERN plotstring$()
'EXTERN plotstrX(), plotstrY()
'EXTERN plotstrCol()
'EXTERN plotstrBGCol()
'EXTERN plotstrBits()
EXTERN plotstr() as Plotstring

'Battle globals
EXTERN battlecaption$
EXTERN battlecaptime
EXTERN battlecapdelay
EXTERN bstackstart
EXTERN learnmask()

EXTERN timers() as Timer

EXTERN map_draw_mode as integer

'Menu globals
EXTERN menus() as MenuDef
EXTERN mstates() as MenuState
EXTERN menu_set as MenuSet
EXTERN topmenu as INTEGER
