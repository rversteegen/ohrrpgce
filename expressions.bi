'OHRRPGCE - Simple expression parser and evaluator
'(C) Copyright 1997-2025 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.

#ifndef EXPRESSIONS_BI
#define EXPRESSIONS_BI

'Uncomment for ExpressionParser debugging
'#define PARSEDBG(message) ? message
#define PARSEDBG(message)

#include "config.bi"

'''' TypedValue

enum ValueType
	' The following are valid values in a TypedValue
	vtyBool
	vtyInt
	vtyFloat
	vtyError    'Propagate errors through eval_node
	'vtyString  'Future
	'vtyXY      'Future
	' The following are NOT valid in a TypedValue
	vtyUnknown
	vtyNumber   'Either vtyInt or vtyFloat or vtyBool
end enum

type TypedValue
	valtype as ValueType
	union
		int_value as integer   'vtyBool or vtyInt
		float_value as double  'vtyFloat
		error_value as string * 256 'vtyError
		'xy_value as XYPair
	end union

	'declare function repr() as string
	declare operator cast() as string
	declare operator cast() as double
end type
declare operator =(lhs as TypedValue, rhs as TypedValue) as bool

' TypedValue constructors

#define IntVal(x) type<TypedValue>(vtyInt, x)

private function FloatVal(x as double) as TypedValue
	dim ret as TypedValue = type<TypedValue>(vtyFloat)
	ret.float_value = x
	return ret
end function

private function BoolVal(x as bool) as TypedValue
	dim ret as TypedValue = type<TypedValue>(vtyBool)
	ret.int_value = iif(x, 1, 0)
	return ret
end function

private function ErrorVal(msg as string) as TypedValue
	dim ret as TypedValue = type<TypedValue>(vtyError)
	ret.error_value = msg
	return ret
end function




'''' ExprNode

enum ExprNodeType
	exprConst
	exprVariable
	exprBinaryOp
	exprFunction
end enum

' static of an expression's AST
type ExprNode
	nodetype as ExprNodeType
	name as string  'For exprVariable, exprBinaryOp, exprFunction
	union
		valtype as ValueType  'For all nodetypes
		value as TypedValue   'For exprConst
	end union
	args(any) as ExprNode ptr     'For exprBinaryOp, exprFunction
	precedence as integer         'For exprBinaryOp

	declare function dump(indent as integer = 0) as string
end type


'''' ExpressionParser

type ExprFuncInfo
	minargs as integer
	maxargs as integer
	rettype as ValueType  'Can be vtyUnknown or vtyNumber
end type

' Expression parser. Extended to implement recognition of identifiers and evaluation of nodes.
type ExpressionParser extends object
	parse_input as string
	parser_pos as integer  '(1-based) position in parse_input
	parse_error as string  'Nonempty if an error occurred

	declare abstract function get_function_info(ident as string) as ExprFuncInfo ptr
	declare abstract function check_global(ident as string) as bool

	declare function parse_string(input as string) as ExprNode ptr
	declare function ast_to_string(node as ExprNode ptr, omit_parens as bool = YES, parent_precedence as integer = -1) as string

	' Implements operators and constants only, subclasses handle exprVariable and exprFunction
	declare virtual function eval_node(node as ExprNode ptr) as TypedValue

	declare virtual sub show_error(msg as string)

  private:
	declare sub skip_whitespace()
	declare function peek_char() as string
	declare function advance_char() as string
	declare function parse_number() as ExprNode ptr
	declare function parse_identifier() as string
	declare function parse_primary() as ExprNode ptr
	declare function parse_expression(min_prec as integer = 0) as ExprNode ptr
end type

#endif
