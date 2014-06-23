#IFNDEF __UICONST_BI__
#DEFINE __UICONST_BI__

'OHRRPGCE - UICONST.BI - UI colour constants
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'
CONST uiColorLast = 36
CONST uiColorOldLast = 17 ' the last uilook saved in uicolors.bin
CONST uiBoxLast = 14
CONST uiBoxOldLast = 14 ' the last boxlook saved in uicolors.bin

CONST uiBackground = 0          'background colour (not for transparent! transparent is always 0)
CONST uiMenuItem = 1			'normal menu item
CONST uiDisabledItem = 2		'disabled menu item
CONST uiSelectedItem = 3		'selection, alternates 3 & 4
CONST uiSelectedItem2 = 4		'selection flash color
CONST uiSelectedDisabled = 5	'selected disabled item
CONST uiSelectedDisabled2 = 6	'selected disabled item flash color
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
CONST uiSelectedSpecial	 = 19	'Selected Special item
CONST uiSelectedSpecial2 = 20	'Selected Special item flash color
'---Just for the items screen---
CONST uiItemScreenSwap = 21	
CONST uiItemScreenSwapDisabled = 22	
CONST uiItemScreenSwapSpecial = 23
CONST uiItemScreenItem = 24
CONST uiItemScreenDisabled = 25
CONST uiItemScreenSpecial = 26
CONST uiItemScreenSelected = 27
CONST uiItemScreenSelected2 = 28
CONST uiItemScreenSelectedDisabled = 29
CONST uiItemScreenSelectedDisabled2 = 30
CONST uiItemScreenSelectedSpecial = 31
CONST uiItemScreenSelectedSpecial2 = 32
CONST uiItemScreenHighlight = 33
CONST uiItemScreenHighlight2 = 34
CONST uiItemScreenSwapHighlight = 35
CONST uiItemScreenSwapHighlight2 = 36

'When you add more constants you will need to update GuessDefaultUIColors
'and FillMissingUIColor and UiColorCaption in loading.rbas

'If you add any new colors that need to auto-flash when used by slices,
'add them to SliceColor in slices.bas

'You might also want to check how UI colours are automatically remapped
'in remappalette in subs4.bas and also the indication of used master
'palette colour in masterpalettemenu in subs4.bas although neither of
'those should require manual updating


#ENDIF
