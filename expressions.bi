'OHRRPGCE - Simple expression parser and evaluator
'(C) Copyright 1997-2025 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.

#ifndef EXPRESSIONS_BI
#define EXPRESSIONS_BI


#include "config.bi"

'''' TypedValue

enum ValueType
	vtyINVALID  'For get_function_ret_type only
	vtyInt
	vtyFloat
	'vtyXY   'Future
end enum

type TypedValue
	valtype as ValueType
	union
		int_value as integer
		float_value as double
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

	declare function dump(indent as integer = 0) as string
end type


'''' ExpressionParser

type FuncArgsInfo
	minargs as integer
	maxargs as integer
end type

' Expression parser. Extended to implement recognition of identifiers and evaluation of nodes.
type ExpressionParser extends object
	parse_input as string
	parser_pos as integer  '(1-based) position in parse_input
	parse_error as string  'Nonempty if an error occurred

	declare abstract function get_function_args(ident as string) as FuncArgsInfo ptr
	declare abstract function get_function_ret_type(node as ExprNode ptr, byref errmsg as string) as ValueType
	declare abstract function check_global(ident as string) as bool
	declare abstract function eval_node(node as ExprNode ptr) as TypedValue

	declare function parse_string(input as string) as ExprNode ptr
	declare function ast_to_string(node as ExprNode ptr) as string

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
