'OHRRPGCE - Simple expression parser and evaluator
'(C) Copyright 1997-2025 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.

#include "config.bi"
#include "expressions.bi"
#include "util.bi"
#include "common.bi"

#define PARSEDBG(message)
'#define PARSEDBG(message) ? message


operator TypedValue.cast() as double
	return iif(valtype = vtyInt, int_value, float_value)
end operator

' Always formats floats with decimals or scientific notation (which we can't parse back)
operator TypedValue.cast() as string
	if valtype = vtyInt then return str(int_value)
	dim ret as string = str(float_value)
	if instr(ret, any ".+") = 0 then ret &= ".0"
	return ret
end operator

/'
function TypedValue.repr() as string
	select case valtype
		case vtyInt:   return "IntVal(" & int_value & ")"
		case vtyFloat: return "FloatVal("  & float_value & ")"
		case else:    return "TypedValue(vtype=" & valtype & ")"
	end select
end function
'/

operator =(lhs as TypedValue, rhs as TypedValue) as bool
	return cast(double, lhs) = cast(double, rhs)
end operator

sub ExpressionParser.show_error(msg as string)
	? "Parse error: " & msg
end sub

function ExprNode.dump(indent as integer = 0) as string
	static typenames(...) as string * 10 = {"INVALID", "Int", "Float", "XY"}
	static nodetypenames(...) as string * 10 = {"const", "var", "binop", "func"}
	dim ret as string
	ret = space(indent * 2) & "ExprNode(" & nodetypenames(nodetype)
	if nodetype = exprConst then
		ret &= ") = " & value'.repr()
	else
		ret &= " " & name & " is " & typenames(value.valtype - vtyINVALID) & ")"
	end if
	for idx as integer = 0 to ubound(args)
		ret &= !"\n" & args(idx)->dump(indent + 1)
	next
	return ret
end function

sub ExpressionParser.skip_whitespace()
	while parser_pos <= len(parse_input) and parse_input[parser_pos - 1] = asc(" ")
		parser_pos += 1
	wend
end sub

function ExpressionParser.peek_char() as byte
	skip_whitespace
	if parser_pos <= len(parse_input) then
		return parse_input[parser_pos - 1]
	else
		return 0
	end if
end function

function ExpressionParser.advance_char() as byte
	parser_pos += 1
	skip_whitespace
	return peek_char
end function

' If there is something that looks like a number here parse it, otherwise return NULL
function ExpressionParser.parse_number() as ExprNode ptr
	dim c as byte = peek_char  'Skips leading whitespace
	dim start_pos as integer = parser_pos
	dim token as string

	' Glob -?[0-9. ]*, discard whitespace
	'if c = asc("-") then token &= "-" c = advance_char
	while isdigit(c) orelse c = asc(".") orelse c = asc("-")
		token &= chr(c)
		c = advance_char
	wend

	' if c = asc("-") then c = advance_char
	' while isdigit(c) or c = asc(".")
	'     c = advance_char
	' wend

	if parser_pos = start_pos then return NULL  'Nothing here

	'dim token as string = mid(parse_input, start_pos, parser_pos - start_pos)
	if token = "-" then
		'No unary minus for simplicity
		parse_error = "Use -1*... to negate a value"
		return NULL
	end if

	dim node as ExprNode ptr = new ExprNode
	node->nodetype = exprConst

	dim int_val as integer
	dim float_val as double

	if parse_int(token, @int_val) then
		node->value = IntVal(int_val)
	elseif instr(token, ".") andalso parse_float(token, @float_val) then
		node->value = FloatVal(float_val)
	else
		parse_error = "Invalid number: " + token
		return NULL
	end if

	return node
end function

function ExpressionParser.parse_identifier() as string
	dim token as string = ""
	dim c as byte = peek_char
	' Stop at operators, parentheses, comma
	while c andalso instr("+-*/(),", chr(c)) = 0
		token &= chr(c)
		c = advance_char
	wend
	if sanitize_script_identifier(token) = token then return token  'Valid
	return ""
end function

' Parse a number, variable, function call, or parenthesised expression
function ExpressionParser.parse_primary() as ExprNode ptr
	dim c as byte = peek_char()

	if c = asc("(") then
		advance_char()
		dim expr as ExprNode ptr = parse_expression(0)
		if expr = NULL then return NULL
		if peek_char() <> asc(")") then
			parse_error = "Expected ')'"
			return NULL
		end if
		advance_char()
		return expr
	end if

	dim num_node as ExprNode ptr = parse_number()
	if num_node <> NULL orelse len(parse_error) then return num_node

	dim ident as string = parse_identifier()
	if ident = "" then
		parse_error = "Expected number or identifier"
		return NULL
	end if

	' Look up function info
	dim args_info as FuncArgsInfo ptr = get_function_args(ident)

	' Determine if this is a function call
	dim is_function as bool = NO
	c = peek_char()
	if c = asc("(") then
		if args_info = NULL then
			parse_error = "Unknown function: " & ident
			return NULL
		end if
		is_function = YES
	elseif args_info andalso args_info->minargs = 0 then
		' Zero-arg function can be called without parens
		is_function = YES
	end if

	if is_function then
		dim node as ExprNode ptr = new ExprNode
		node->nodetype = exprFunction
		node->name = ident

		if c = asc("(") then
			advance_char() ' consume '('

			' Parse arguments if any
			if peek_char() <> asc(")") then
				do
					dim arg as ExprNode ptr = parse_expression(0)
					if arg = NULL then return NULL

					redim preserve node->args(ubound(node->args) + 1)
					node->args(ubound(node->args)) = arg

					if peek_char() = asc(",") then
						advance_char()
					elseif peek_char() = asc(")") then
						exit do
					else
						parse_error = "Expected ',' or ')'"
						return NULL
					end if
				loop
			end if

			if peek_char() <> asc(")") then
				parse_error = "Expected ')'"
				return NULL
			end if
			advance_char() ' consume ')'
		end if

		' Validate argument count
		dim num_args as integer = ubound(node->args) + 1
		if num_args < args_info->minargs or num_args > args_info->maxargs then
			parse_error = "Function " + ident + " expects "
			if args_info->minargs = args_info->maxargs then
				parse_error += str(args_info->minargs)
			else
				parse_error += str(args_info->minargs) + " to " + str(args_info->maxargs)
			end if
			parse_error += " arguments"
			return NULL
		end if

		' Get return type
		dim errmsg as string
		node->value.valtype = get_function_ret_type(node, errmsg)
		if node->value.valtype = vtyINVALID then
			parse_error = errmsg
			return NULL
		end if

		return node
	else
		' It's a variable
		if not check_global(ident) then
			parse_error = "Unknown name/variable: " + ident
			return NULL
		end if

		dim node as ExprNode ptr = new ExprNode
		node->nodetype = exprVariable
		node->name = ident
		node->value.valtype = vtyInt  'Assume all variables are ints
		return node
	end if
end function

'
function ExpressionParser.parse_expression(min_prec as integer) as ExprNode ptr
	dim left_expr as ExprNode ptr = parse_primary()
	if left_expr = NULL then return NULL

	do
		dim operatortok as string = chr(peek_char())
		dim index as integer = instr("&|<>=+-*/", operatortok)
		if index = 0 then exit do

		' The precedence can be determined from the first character of the token
		dim prec as integer = (@"112223344")[index] - asc("1")
		if prec < min_prec then exit do

		advance_char()
		if instr("<>", operatortok) then
			'Look for <= or >=
			if peek_char() = asc("=") then operatortok &= chr(advance_char())
		end if
		if instr("&|", operatortok) then
			'Must be && or ||
			var char = chr(advance_char())
			if char <> operatortok then
				parse_error = strprintf("Expected '%s%s', found '%s%s'", operatortok, operatortok,  operatortok, char)
			end if
			operatortok &= char
		end if

		dim right_expr as ExprNode ptr = parse_expression(prec + 1)
		if right_expr = NULL then return NULL

		dim node as ExprNode ptr = new ExprNode
		node->nodetype = exprBinaryOp
		node->name = operatortok
		redim node->args(1)
		node->args(0) = left_expr
		node->args(1) = right_expr
		left_expr = node

		node->value.valtype = get_function_ret_type(node, parse_error)
		if node->value.valtype = vtyINVALID then return NULL
	loop

	return left_expr
end function

function ExpressionParser.parse_string(toparse as string) as ExprNode ptr
	PARSEDBG(!"\nparse_string(""" & toparse & """)")

	parse_input = toparse
	parser_pos = 1
	parse_error = ""

	if len(toparse) = 0 then
		parse_error = "Empty expression"
		show_error(parse_error)
		return NULL
	end if

	skip_whitespace
	dim result as ExprNode ptr = parse_expression(0)

	if result <> NULL and peek_char() <> 0 then
		parse_error = "Unexpected text: """ & mid(parse_input, parser_pos) & """"
		result = NULL
	end if

	if parse_error <> "" then
		show_error(parse_error)
	end if

	return result
end function

function ExpressionParser.ast_to_string(node as ExprNode ptr) as string
	if node = NULL then return ""

	select case node->nodetype
		case exprConst:
			return node->value'.repr()
		case exprVariable:
			return node->name
		case exprBinaryOp:
			return "(" + ast_to_string(node->args(0)) + " " + node->name + " " + ast_to_string(node->args(1)) + ")"
		case exprFunction:
			dim result as string = node->name
			if ubound(node->args) >= 0 then
				result += "("
				for i as integer = 0 to ubound(node->args)
					if i > 0 then result += ", "
					result += ast_to_string(node->args(i))
				next
				result += ")"
			end if
			return result
	end select
	return ""
end function

' Virtual methods
' function ExpressionParser.get_function_args(ident as string) as FuncArgsInfo ptr
'     return 0
' end function

' function ExpressionParser.get_function_ret_type(node as ExprNode ptr, byref errmsg as string) as ValueType
'     return vtyINVALID
' end function

' function ExpressionParser.check_global(ident as string) as bool
'     return false
' end function

' function ExpressionParser.eval_node(node as ExprNode ptr) as double
'     return 0
' end function
