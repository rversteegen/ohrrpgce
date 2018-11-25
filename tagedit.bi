#ifndef TAGEDIT_BI
#define TAGEDIT_BI

#include "udts.bi"

DECLARE SUB condition_test_menu ()

DECLARE FUNCTION tag_grabber (byref n as integer, state as MenuState, allowspecial as bool=YES, always_choice as bool=NO, allowneg as bool=YES) as bool
DECLARE FUNCTION tag_id_grabber (byref n as integer, state as MenuState) as bool
DECLARE FUNCTION tag_set_grabber (byref n as integer, state as MenuState) as bool
DECLARE FUNCTION tags_menu (byval starttag as integer=0, byval picktag as bool=NO, byval allowspecial as bool=YES, showsign as bool=NO, byval always_choice as bool=NO) as integer
DECLARE FUNCTION tag_toggle_caption(byval n as integer, prefix as string="Toggle tag", byval allowspecial as bool=NO) as string
DECLARE FUNCTION tag_set_caption(byval n as integer, prefix as string="Set Tag", byval allowspecial as bool=NO) as string
DECLARE FUNCTION tag_choice_caption(byval n as integer, prefix as string="", byval allowspecial as bool=NO) as string
DECLARE FUNCTION tag_condition_caption(byval n as integer, prefix as string="Tag", zerocap as string, onecap as string="Never", negonecap as string="Always") as string
DECLARE FUNCTION describe_two_tag_condition(prefix as string, truetext as string, falsetext as string, byval zerovalue as bool, byval tag1 as integer, byval tag2 as integer) as string

DECLARE FUNCTION cond_grabber (cond as Condition, default as bool = NO, alwaysedit as bool, st as MenuState) as bool
DECLARE FUNCTION condition_string (cond as Condition, byval selected as integer, default as string = "Always", byval wide as integer = 40) as string

DECLARE FUNCTION format_percent_cond(cond as AttackElementCondition, default as string, byval decimalplaces as integer = 4) as string
DECLARE FUNCTION percent_cond_grabber(byref cond as AttackElementCondition, byref repr as string, default as string, byval min as double, byval max as double, byval decimalplaces as integer = 4, ret_if_repr_changed as bool = YES) as bool
DECLARE SUB percent_cond_editor (cond as AttackElementCondition, byval min as double, byval max as double, byval decimalplaces as integer = 4, do_what as string = "...", percent_of_what as string = "")

#endif
