'OHRRPGCE - Simple expression parser and evaluator
'(C) Copyright 1997-2025 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.

#include "config.bi"
#include "expressions.bi"
#include "util.bi"
#include "common.bi"
#include "testing.bi"


#define PARSEDBG(message)
'#define PARSEDBG(message) ? message


' Mock implementation for testing
type MockParser extends ExpressionParser
	declare function get_function_info(ident as string) as ExprFuncInfo ptr
	declare function check_global(ident as string) as bool
	declare function eval_node(node as ExprNode ptr) as TypedValue
	declare sub show_error(msg as string)

	hide_errors as bool
end type

sub MockParser.show_error(msg as string)
	if hide_errors = NO then ? "Parse error: " & msg
end sub

function MockParser.get_function_info(ident as string) as ExprFuncInfo ptr
	static mock_xy_info as ExprFuncInfo = (2, 2, vtyUnknown)
	static mock_quarter_info as ExprFuncInfo = (1, 1, vtyFloat)
	static mock_sum_info as ExprFuncInfo = (1, 99, vtyNumber)
	static mock_childcount_info as ExprFuncInfo = (0, 0, vtyInt)

	PARSEDBG("get_function_info(""" & ident & """)")
	select case lcase(ident)
		case "xy": return @mock_xy_info
		case "quarter": return @mock_quarter_info
		case "sum": return @mock_sum_info
		case "childcount": return @mock_childcount_info
		case else: return NULL
	end select
end function

function MockParser.check_global(ident as string) as bool
	PARSEDBG("check_global(""" & ident & """)")
	select case lcase(ident)
		case "x", "xvelocity", "pi", "y"
			return YES
	end select
end function

'TODO: Const/BinOp should be moved to ExpressionParser
function MockParser.eval_node(node as ExprNode ptr) as TypedValue
	if node = NULL then return IntVal(0)

	select case node->nodetype
		case exprConst:
			return node->value
		case exprVariable:
			select case node->name
				case "x": return IntVal(10)
				case "xvelocity": return IntVal(20)
				case "pi": return FloatVal(M_PI)
				case "y": return IntVal(0)
			end select
		case exprBinaryOp:
			dim left_tv as TypedValue = eval_node(node->args(0))
			dim right_tv as TypedValue = eval_node(node->args(1))
			PARSEDBG("eval binop, left = "& left_tv & " right = " &  right_tv)
			dim left_val as double = left_tv
			dim right_val as double = right_tv
			PARSEDBG("eval binop " & node->name & " " & left_Val & " " & right_val)
			select case node->name
				case "+": return FloatVal(left_val + right_val)
				case "-": return FloatVal(left_val - right_val)
				case "*": return FloatVal(left_val * right_val)
				case "/": return FloatVal(left_val / right_val)
			end select
		case exprFunction:
			select case node->name
				case "quarter": return FloatVal(cast(double, eval_node(node->args(0))) / 4)
					'case "sin": return FloatVal(sin(cast(double, eval_node(node->args(0)))))
				case "sum":
					dim total as double = 0
					for i as integer = 0 to ubound(node->args)
						total += eval_node(node->args(i))
					next
					return FloatVal(total)
				case "childcount": return IntVal(1)
			end select
	end select
	return IntVal(0)
end function

' Helper macros for testing
#macro testParseOK(expr)
	ast = parser.parse_string(expr)
	if len(parser.parse_error) then fail
	if ast = NULL then
		? "ERROR: parse_string failed, but no parse_error"
		fail
	end if
#endmacro

' Parse, dump back to string, and compare
#macro testParseAs(expr, expected_string)
	testParseOK(expr)
	testEqual(parser.ast_to_string(ast), expected_string)
#endmacro

#macro testParseError(expr, expected_msg)
	parser.hide_errors = YES
	ast = parser.parse_string(expr)
	if ast <> NULL then print "Expected parse error '" & expected_msg & "' but instead succeeded" : fail
	testEqual(parser.parse_error, expected_msg)
	parser.hide_errors = NO
#endmacro

#macro testEval(expr, expected)
	ast = parser.parse_string(expr)
	if ast = NULL then fail
	PARSEDBG(ast->dump(0))
	testEqual(cast(double, parser.eval_node(ast)), expected)
#endmacro

startTest(test_basic_parsing)
	dim parser as MockParser
	dim ast as ExprNode ptr

	' Test number parsing

	testParseOK("42")
	testEqual(ast->nodetype, exprConst)
	testEqual(ast->value.valtype, vtyInt)
	testEqual(ast->value.int_value, 42)
	if ast->value <> IntVal(42) then fail

	testParseOK("3.14")
	testEqual(ast->nodetype, exprConst)
	testEqual(ast->value.valtype, vtyFloat)
	testEqual(ast->value.float_value, 3.14)

	testParseOK(".14")
	testEqual(ast->value, FloatVal(0.14))

	testParseAs(".14", "0.14")

	testParseOK("1.")
	testEqual(ast->value.valtype, vtyFloat)
	testEqual(ast->value, FloatVal(1.0))   'Note IntVal(1) = FloatVal(1.0)

	' Test malformed numbers (parse_int/float tests in utiltest test these far
	' more extensively)
	testParseError("42..42", "Invalid number: 42..42")
	testParseError("111111111111", "Invalid number: 111111111111")  'Because it overflows


	' Test identifiers

	testParseOK("x")
	testEqual(ast->nodetype, exprVariable)
	testEqual(ast->name, "x")

	testParseAs("x", "x")
	testParseAs("X velocity", "Xvelocity")
	testParseError("UNKNOWN", "Unknown name/variable: UNKNOWN")

	' Test functions

	testParseOK("sum(12)")
	testEqual(ast->nodetype, exprFunction)
	testEqual(ast->name, "sum")
	testEqual(ubound(ast->args), 0)

	testParseOK("sum (-1,-2)")
	testEqual(ubound(ast->args), 1)

	testParseError("UNKNOWN(1)", "Unknown function: UNKNOWN")
	testParseError("UNKNOWN ()", "Unknown function: UNKNOWN")
	testParseError("quarter", "Function quarter expects 1 arguments")
	testParseError("sum()", "Function sum expects 1 to 99 arguments")
	testParseError("XY(1)", "Function XY expects 2 arguments")
	testParseAs("XY(-1,-2)", "XY(-1, -2)")
	testParseError("XY(1,2,3)", "Function XY expects 2 arguments")

	' Function parens are optional

	testParseAs("childcount()", "childcount")
	testEqual(ast->nodetype, exprFunction)
	testEqual(ast->name, "childcount")
	testEqual(ubound(ast->args), -1)

	testParseAs("child count", "childcount")
	testEqual(ast->nodetype, exprFunction)
	testEqual(ast->name, "childcount")
	testEqual(ubound(ast->args), -1)

	' Test operator parsing

	testParseAs("1-1", "1 - 1")
	testParseAs("4+-1", "4 + -1")
	' TODO: Add all the other operators here

	testParseAs("4&&1 >= 23 || -1", "4 && 1 >= 23 || -1")

	' Test whitespace in various places

	testParseOK(" - 42 ")
	testEqual(ast->value, IntVal(-42))

	testParseOK(" 1 000 ")
	testEqual(ast->value, IntVal(1000))

	testParseOK("x + x velocity")
	testEqual(ast->nodetype, exprBinaryOp)

	testParseOK(" c hildcoun t (   ) ")
	testEqual(ast->nodetype, exprFunction)
	testEqual(ast->name, "childcount")
	testEqual(ubound(ast->args), -1)

	testParseOK("sum( 1 , 2 , 3 )")
	testEqual(ubound(ast->args), 2)

	' Test complex nesting

	testParseOK("sum(quarter(pi), x + 1, y * 2)")
	testEqual(ast->nodetype, exprFunction)
	testEqual(ubound(ast->args), 2) ' 3 arguments

endTest

startTest(test_malformed_errors)
	dim parser as MockParser
	dim ast as ExprNode ptr

	' Test various other error conditions
	testParseError("", "Empty expression")
	testParseError("42 junk", "Unexpected text: ""junk""")
	testParseError("(3+4", "Expected ')'")
	testParseError("3 +", "Expected number or identifier")
	testParseError("quarter(1,)", "Expected number or identifier")
	testParseError("3|4", "Expected '||', found '|4'")
endTest

startTest(test_eval_operators)
	dim parser as MockParser
	dim ast as ExprNode ptr

	' TODO: Add tests for evaluating all the various operators
	testEval("((1 + 2) * 3)", IntVal(9))
endTest

startTest(test_nested_expressions)
	dim parser as MockParser
	dim ast as ExprNode ptr

	' Test deeply nested expressions
	testEval("quarter(30.0)", 7.5)
	testEval("quarter(40)", 10)
	testEval("quarter(x + 2*xvelocity)", 12.5)
	testEval("sum(1, 2 * 3, x)", 17) ' 1 + 6 + 10
	testEval("x + x velocity * 2", 50) ' 10 + 20 * 2
	testEval("(x + x velocity) * 2", 60) ' (10 + 20) * 2
endTest

startTest(test_parenthesis_omission)
	dim parser as MockParser
	dim ast as ExprNode ptr

	' Check ast_to_string parens
	testParseAs("1 + 2 * 3", "1 + 2 * 3")
	testParseAs("(1 + 2) * 3", "(1 + 2) * 3")
	testParseAs("1 * (2 + 3)", "1 * (2 + 3)")
	testParseAs("1 * 2 + 3", "1 * 2 + 3")
	testParseAs("x + y * 2", "x + y * 2")
	testParseAs("(x + y) * 2", "(x + y) * 2")

	' Extra parentheses
	testParseAs("((1 + 2) * 3)", "(1 + 2) * 3")
	testParseAs("(1 * (2 + 3))", "1 * (2 + 3)")
	testParseAs("(1 * 2) + 3", "1 * 2 + 3")
endTest


