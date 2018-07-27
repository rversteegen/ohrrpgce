#IFNDEF __UICONST_BI__
#DEFINE __UICONST_BI__

'OHRRPGCE - UICONST.BI - UI colour constants
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'
CONST uiColorLast = 51
CONST uiColorOldLast = 17 ' the last uilook saved in uicolors.bin
CONST uiBoxLast = 14
CONST uiBoxOldLast = 14 ' the last boxlook saved in uicolors.bin

'Lowest value that's interpreted as a valid color, eg for ColorIndex()
CONST minColorCode = -1 * uiColorLast - 1

CONST uiBackground = 0          'background colour (not for transparent! transparent is always 0)
CONST uiMenuItem = 1			'normal menu item
CONST uiDisabledItem = 2		'disabled menu item
CONST uiSelectedItem = 3		'selection (1st col)
CONST uiSelectedItem2 = 4		'selection (2nd col) - flashes when used as slice color
CONST uiSelectedDisabled = 5	'selected disabled item (1st col)
CONST uiSelectedDisabled2 = 6	'selected disabled item (2nd col) - flashes when used as slice color
CONST uiHighlight = 7			'background to selected menu item
CONST uiHighlight2 = 8			'background used in equip menu
CONST uiTimeBar = 9				'hero's time bar
CONST uiTimeBarFull = 10		'time bar when full
CONST uiHealthBar = 11			'hero's health bar
CONST uiHealthBarFlash = 12		'health bar flash colour (?)
CONST uiText = 13				'Default text colour
CONST uiOutline = 14			'Text outline colour
CONST uiDescription = 15		'Spell description
CONST uiGold = 16				'Total cash
CONST uiShadow = 17				'Vehicle shadow
CONST uiSpecialItem = 18		'Special menu item
CONST uiSelectedSpecial	 = 19	'Selected Special item (1st col)
CONST uiSelectedSpecial2 = 20	'Selected Special item (2nd col) - flashes when used as slice color
'---Just for the items screen---
CONST uiItemScreenSwap = 21	
CONST uiItemScreenSwapDisabled = 22	
CONST uiItemScreenSwapSpecial = 23
CONST uiItemScreenItem = 24
CONST uiItemScreenDisabled = 25
CONST uiItemScreenSpecial = 26
CONST uiItemScreenSelected = 27
CONST uiItemScreenSelected2 = 28  'flashes when used as slice color
CONST uiItemScreenSelectedDisabled = 29
CONST uiItemScreenSelectedDisabled2 = 30 'flashes when used as slice color
CONST uiItemScreenSelectedSpecial = 31
CONST uiItemScreenSelectedSpecial2 = 32  'flashes when used as slice color
CONST uiItemScreenHighlight = 33
CONST uiItemScreenHighlight2 = 34        'flashes when used as slice color
CONST uiItemScreenSwapHighlight = 35
CONST uiItemScreenSwapHighlight2 = 36    'flashes when used as slice color
'-------------------------
CONST uiMouseHoverItem = 37	'A menu item over which the mouse is hovering
CONST uiBattleDamage = 38
CONST uiBattleHeal = 39
CONST uiBattleAbsorb = 40
CONST uiBattlePoison = 41
CONST uiBattleRegen = 42
CONST uiFadeOutNewGame = 43
CONST uiFadeOutLoadGame = 44
CONST uiFadeOutDeath = 45
CONST uiFadeOutQuit = 46
CONST uiFadeOutDoor = 47
CONST uiFadeOutInn = 48
CONST uiFadeOutEnterBattle = 49
CONST uiFadeOutWonBattle = 50
CONST uiFadeOutExitBattle = 51

'When you add more constants you will need to update GuessDefaultUIColors
'and UiColorCaption, and possibly FillMissingUIColor, in loading.rbas.
'And don't forget to update uiColorLast above.

'If you add any new colors that need to auto-flash when used by slices,
'add them to ColorIndex.

'Although not requiring manual updating, other places UI colours are looped over:
'-automatic remapping in remappalette in subs4.bas
'-used master palette colours indicated in masterpalettemenu in subs4.bas

#ENDIF
