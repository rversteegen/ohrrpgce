'OHRRPGCE - bmod.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from bmod.bas

#IFNDEF BMOD_BI
#DEFINE BMOD_BI

#INCLUDE "udts.bi"

'--local const and types only used in this module

'This type controls the state of the battle engine, for example,
'who's turn it is, what each character is doing, and targetting information
TYPE BattleState
 acting AS INTEGER    'Hero or enemy who is currently taking their turn to act
 hero_turn AS INTEGER 'Hero currently selecting an attack
END TYPE

'This type controls the visual state of the victory display
CONST vicGOLDEXP = 1
CONST vicLEVELUP = 2
CONST vicSPELLS  = 3
CONST vicITEMS   = 4
'negative are non-displaying exit states
CONST vicEXITDELAY = -1
CONST vicEXIT    = -2
TYPE VictoryState
 state AS INTEGER 'vicSTATENAME or 0 for none
 box AS INTEGER   'NO when not displaying a box, YES when displaying a box
 showlearn AS INTEGER 'NO when not showing spell learning, YES when already showing a learned spell
 learnwho AS INTEGER 'battle slot of hero currently displaying learned spells
 learnlist AS INTEGER 'spell list of hero currently displaying learned spells
 learnslot AS INTEGER 'spell list slot of hero currently displaying learned spells
 item_name AS STRING 'name of currently displaying found item or "" for none
 found_index AS INTEGER 'index into the found() array that lists items found in this battle
 gold_caption AS STRING
 exp_caption AS STRING
 item_caption AS STRING
 plural_item_caption AS STRING
 gold_name AS STRING
 exp_name AS STRING
 level_up_caption AS STRING
 levels_up_caption AS STRING
 learned_caption AS STRING
END TYPE

'This type is just used by RewardState
TYPE RewardsStateItem
 id AS INTEGER
 num AS INTEGER
END TYPE

'This type controls the state of rewards gathered in the current battle
TYPE RewardsState
 plunder AS INTEGER
 exper AS INTEGER
 found(16) AS RewardsStateItem
END TYPE

declare function battle (form, fatal, exstat())
declare function checknorunbit (bstat() AS BattleStats, ebits(), bslot() as battlesprite)
declare sub checktagcond (t, check, tg, tagand)
declare function focuscost (cost, focus)
declare sub herobattlebits (bitbuf(), who)
declare sub invertstack
declare sub quickinflict (harm, targ, hc(), hx(), hy(), bslot() as battlesprite, harm$(), bstat() AS BattleStats)
DECLARE SUB anim_end()
DECLARE SUB anim_wait(ticks%)
DECLARE SUB anim_waitforall()
DECLARE SUB anim_inflict(who%)
DECLARE SUB anim_disappear(who%)
DECLARE SUB anim_appear(who%)
DECLARE SUB anim_setframe(who%, frame%)
DECLARE SUB anim_setpos(who%, x%, y%, d%)
DECLARE SUB anim_setz(who%, z%)
DECLARE SUB anim_setmove(who%, xm%, ym%, xstep%, ystep%)
DECLARE SUB anim_absmove(who%, tox%, toy%, xspeed%, yspeed%)
DECLARE SUB anim_zmove(who%, zm%, zstep%)
DECLARE SUB anim_walktoggle(who%)
DECLARE SUB anim_sound(which)
DECLARE SUB anim_align(who, target, dire, offset)
DECLARE SUB anim_setcenter(who, target, offx, offy)
DECLARE SUB anim_align2(who, target, edgex, edgey, offx, offy)
DECLARE SUB anim_relmove(who, tox, toy, xspeed, yspeed)
DECLARE SUB anim_setdir(who, d)
DECLARE FUNCTION dieWOboss(BYVAL who, bstat() AS BattleStats, ebits())
DECLARE SUB dead_enemy(deadguy AS INTEGER, BYREF rew AS RewardsState, bstat() AS BattleStats, bslot() AS BattleSprite, es(), atktype(), formdata(), p(), bits(), ebits(), batname$())
#ENDIF
