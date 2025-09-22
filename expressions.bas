' Expression AST types and parser for FreeBASIC

#include "config.bi"
#include "util.bi"
#include "common.bi"
#include "testing.bi"

enum ValueType
    tyInt
    tyFloat
    'tyXY
    tyINVALID = -1  'For get_function_ret_type only
end enum

enum ExprNodeType
    EXPR_CONST
    EXPR_VARIABLE
    EXPR_BINARY_OP
    EXPR_FUNCTION
end enum

type TypedVal
    value_type as ValueType
    union
        int_value as integer
        float_value as double
    end union

    declare operator cast() as string
    declare operator cast() as double
end type

operator TypedVal.cast() as double
    return iif(value_type = tyInt, int_value, float_value)
end operator

type ExprNode
    node_type as ExprNodeType
    name as string ' For EXPR_VARIABLE, EXPR_BINARY_OP, EXPR_FUNCTION_CALL
    union
        value as TypedVal
        type
            value_type as ValueType
            union  ' For EXPR_CONST
                int_value as integer
                float_value as double
            end union
        end type
    end union
    'For EXPR_BINARY_OP, EXPR_FUNCTION_CALL:
    args(any) as ExprNode ptr

    declare function dump(indent as integer = 0) as string
end type

type FuncArgsInfo
    minargs as integer
    maxargs as integer
end type

#define IntVal(x) type<TypedVal>(tyInt, x)
'#define FloatVal(x) type<TypedVal>(tyFloat, x)

private function FloatVal(x as double) as TypedVal
    dim ret as TypedVal = type<TypedVal>(tyFloat)
    ret.float_value = x
    return ret
end function

operator TypedVal.cast() as string
    if value_type = tyInt then
        return str(int_value)
    elseif value_type = tyFloat then
        return str(float_value)
    else
        return "TypedVal(type=" & value_type & ")"
    end if
end operator

type ParserState extends object
    parse_input as string
    parser_pos as integer  '1-based positiong
    parse_error as string

    declare abstract function get_function_args(ident as string) as FuncArgsInfo ptr
    declare abstract function get_function_ret_type(node as ExprNode ptr, byref errmsg as string) as ValueType
    declare abstract function check_global(ident as string) as bool
    declare abstract function eval_node(node as ExprNode ptr) as TypedVal

    declare sub skip_whitespace()
    declare function peek_char() as byte
    declare function advance_char() as byte
    declare function parse_number() as ExprNode ptr
    declare function parse_identifier() as string
    declare function parse_primary() as ExprNode ptr
    declare function parse_expression(min_prec as integer) as ExprNode ptr
    declare function parse_string_to_ast(input as string) as ExprNode ptr
    declare function ast_to_string(node as ExprNode ptr) as string

    declare sub show_error(msg as string)
end type

sub ParserState.show_error(msg as string)
    ?"show_error(""" & msg & """)"
end sub

function ExprNode.dump(indent as integer = 0) as string
    static typenames(...) as string * 10 = {"INVALID", "Int", "Float", "XY"}
    static nodetypenames(...) as string * 10 = {"CONST", "VAR", "BINOP", "FUNC"}
    dim ret as string
    ret = space(indent * 2) & "ExprNode(" & nodetypenames(node_type) & " " & name & " is " & typenames(value_type - tyINVALID) & ")"
    if node_type = EXPR_CONST then
        if value_type = tyInt then ret &= int_value
        if value_type = tyFloat then ret &= float_value
    end if
    for idx as integer = 0 to ubound(args)
        ret &= !"\n" & args(idx)->dump(indent + 1)
    next
    return ret
end function

sub ParserState.skip_whitespace()
    while parser_pos <= len(parse_input) and parse_input[parser_pos - 1] = asc(" ")
        parser_pos += 1
    wend
end sub

function ParserState.peek_char() as byte
    skip_whitespace
    if parser_pos <= len(parse_input) then
        return parse_input[parser_pos - 1]
    else
        return 0
    end if
end function

function ParserState.advance_char() as byte
    parser_pos += 1
    skip_whitespace
    return peek_char
end function

function parse_float (stri as string, ret as double ptr) as bool
    dim success as bool = YES
    *ret = VAL(stri)
    'TODO: use scanf instead of VAL
    ? "parse_float(""" & stri & """, ret) = " & success & ", ret = " & *ret
    return success
end function

function ParserState.parse_number() as ExprNode ptr
    dim c as byte = peek_char  'Skips leading whitespace
    dim start_pos as integer = parser_pos
    dim result as string

    ' Glob -?[0-9. ]*, discard whitespace
    'if c = asc("-") then result &= "-" c = advance_char
    while isdigit(c) orelse c = asc(".") orelse c = asc("-")
        result &= chr(c)
        c = advance_char
    wend

    ' if c = asc("-") then c = advance_char
    ' while isdigit(c) or c = asc(".")
    '     c = advance_char
    ' wend

    if parser_pos = start_pos then return 0  'Nothing here

    'dim result as string = mid(parse_input, start_pos, parser_pos - start_pos)
    if result = "-" then
        'No unary minus for simplicity
        parse_error = "Use -1*... to negate a value"
        return NULL
    end if

    dim node as ExprNode ptr = new ExprNode
    node->node_type = EXPR_CONST

    dim int_val as integer
    dim float_val as double

    if parse_int(result, @int_val) then
        node->value = IntVal(int_val)
        ' node->value_type = tyInt
        ' node->int_value = int_val
    elseif parse_float(result, @float_val) then
        node->value = FloatVal(float_val)
        ' node->value_type = tyFloat
        ' node->float_value = float_val
    else
        parse_error = "Invalid number: " + result
        return NULL
    end if

    return node
end function

function ParserState.parse_identifier() as string
    dim result as string = ""
    dim c as byte = peek_char
    ' Stop at operators, parentheses, comma
    while c andalso instr("+-*/(),", chr(c)) = 0
        result &= chr(c)
        c = advance_char
    wend
    if sanitize_script_identifier(result) = result then return result  'Valid
    return ""
end function

function ParserState.parse_primary() as ExprNode ptr
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

    c = peek_char()
    if c = asc("(") then
        if args_info = NULL then
            parse_error = "Unknown function: " & ident
            return NULL
        end if
    end if

    ' Determine if this is a function call
    dim is_function as bool = false
    c = peek_char()
    if c = asc("(") then
        is_function = true
    elseif args_info andalso args_info->minargs = 0 then
        ' Zero-arg function can be called without parens
        is_function = true
    end if

    if is_function then
        dim node as ExprNode ptr = new ExprNode
        node->node_type = EXPR_FUNCTION
        node->name = ident
        'redim node->args(-1) ' Start with empty array

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
        node->value_type = get_function_ret_type(node, errmsg)
        if node->value_type = tyINVALID then
            parse_error = errmsg
            return NULL
        end if

        return node
    else
        ' It's a variable
        if not check_global(ident) then
            parse_error = "Unknown variable: " + ident
            return NULL
        end if

        dim node as ExprNode ptr = new ExprNode
        node->node_type = EXPR_VARIABLE
        node->name = ident
        node->value_type = tyInt
        'erase node->args(-1)
        return node
    end if
end function

function ParserState.parse_expression(min_prec as integer) as ExprNode ptr
    dim left_expr as ExprNode ptr = parse_primary()
    if left_expr = NULL then return NULL

    while true
        dim op_char as byte = peek_char()
        if INSTR("+-*/", chr(op_char)) = NULL then exit while

        dim prec as integer = iif(INSTR("+-", chr(op_char)), 1, 2)
        if prec < min_prec then exit while

        advance_char()
        dim right_expr as ExprNode ptr = parse_expression(prec + 1)
        if right_expr = NULL then return NULL

        dim node as ExprNode ptr = new ExprNode
        node->node_type = EXPR_BINARY_OP
        node->name = chr(op_char)
        redim node->args(1)
        node->args(0) = left_expr
        node->args(1) = right_expr

        dim errmsg as string
        node->value_type = get_function_ret_type(node, errmsg)
        if node->value_type = tyINVALID then
            parse_error = errmsg
            return NULL
        end if

        left_expr = node
    wend

    return left_expr
end function

function ParserState.parse_string_to_ast(toparse as string) as ExprNode ptr
    print
    print "parse_string_to_ast(""" & toparse & """)"

    parse_input = toparse
    parser_pos = 1
    parse_error = ""

    if len(toparse) = 0 then
        parse_error = "Empty expression"
        show_error("Parse error: " + parse_error)
        return NULL
    end if

    skip_whitespace
    dim result as ExprNode ptr = parse_expression(0)

    if result <> NULL and peek_char() <> 0 then
        parse_error = "Unexpected characters at end"
        result = NULL
    end if

    if result = NULL and parse_error <> "" then
        show_error("Parse error: " + parse_error)
    end if

    return result
end function

function ParserState.ast_to_string(node as ExprNode ptr) as string
    if node = NULL then return ""

    select case node->node_type
        case EXPR_CONST:
            return cast(string, node->value)
        case EXPR_VARIABLE:
            return node->name
        case EXPR_BINARY_OP:
            return "(" + ast_to_string(node->args(0)) + " " + node->name + " " + ast_to_string(node->args(1)) + ")"
        case EXPR_FUNCTION:
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
' function ParserState.get_function_args(ident as string) as FuncArgsInfo ptr
'     return 0
' end function

' function ParserState.get_function_ret_type(node as ExprNode ptr, byref errmsg as string) as ValueType
'     return tyINVALID
' end function

' function ParserState.check_global(ident as string) as bool
'     return false
' end function

' function ParserState.eval_node(node as ExprNode ptr) as double
'     return 0
' end function

' Mock implementation for testing
type MockParser extends ParserState
    declare function get_function_args(ident as string) as FuncArgsInfo ptr
    declare function get_function_ret_type(node as ExprNode ptr, byref errmsg as string) as ValueType
    declare function check_global(ident as string) as bool
    declare function eval_node(node as ExprNode ptr) as TypedVal
end type

function MockParser.get_function_args(ident as string) as FuncArgsInfo ptr

    static mock_xy_args as FuncArgsInfo = (2, 2)
    static mock_quarter_args as FuncArgsInfo = (1, 1)
    static mock_sum_args as FuncArgsInfo = (0, 999)
    static mock_childcount_args as FuncArgsInfo = (0, 0)

    ?"get_function_args(""" & ident & """)"
    select case lcase(ident)
        case "xy": return @mock_xy_args
        case "quarter": return @mock_quarter_args
        case "sum": return @mock_sum_args
        case "childcount": return @mock_childcount_args
        case else: return NULL
    end select
end function

function MockParser.get_function_ret_type(node as ExprNode ptr, byref errmsg as string) as ValueType
    ?"get_function_ret_type(""" & node->name & """)"
    select case node->node_type
        case EXPR_FUNCTION:
            select case lcase(node->name)
                'case "xy": return tyXY
                case "quarter": return tyFloat
                case "sum": return tyInt
                case "childcount": return tyInt
            end select
        case EXPR_BINARY_OP:
            dim left_type as ValueType = node->args(0)->value_type
            dim right_type as ValueType = node->args(1)->value_type
            if left_type = tyFloat or right_type = tyFloat then
                return tyFloat
            else
                return tyInt
            end if
    end select
    return tyINVALID
end function

function MockParser.check_global(ident as string) as bool
    ?"check_global(""" & ident & """)"
    return ident = "x" or ident = "xvelocity" or ident = "pi" or ident = "y"
end function

function MockParser.eval_node(node as ExprNode ptr) as TypedVal
    if node = NULL then return IntVal(0)

    select case node->node_type
        case EXPR_CONST:
            return node->value
            ' if node->value_type = tyInt then
            '     return node->int_value
            ' else
            '     return node->float_value
            ' end if
        case EXPR_VARIABLE:
            select case node->name
                case "x": return IntVal(10)
                case "xvelocity": return IntVal(20)
                case "pi": return FloatVal(M_PI)'3.14159
                case "y": return IntVal(0)
            end select
        case EXPR_BINARY_OP:
            dim left_tv as TypedVal = eval_node(node->args(0))
            dim right_tv as TypedVal = eval_node(node->args(1))
            ?"eval binop, left = "& left_tv & " right = " &  right_tv
            dim left_val as double = left_tv
            dim right_val as double = right_tv
            ?"eval binop " & node->name & " " & left_Val & " " & right_val
            select case node->name
                case "+": return FloatVal(left_val + right_val)
                case "-": return FloatVal(left_val - right_val)
                case "*": return FloatVal(left_val * right_val)
                case "/": return FloatVal(left_val / right_val)
            end select
        case EXPR_FUNCTION:
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
    parser.parse_error = ""
    ast = parser.parse_string_to_ast(expr)
    if ast = NULL then fail
#endmacro

#macro testParseError(expr, expected_msg)
    parser.parse_error = ""
    ast = parser.parse_string_to_ast(expr)
    if ast <> NULL then fail
    testEqual(parser.parse_error, expected_msg)
#endmacro

#macro testEval(expr, expected)
    ast = parser.parse_string_to_ast(expr)
    if ast = NULL then fail
    ? ast->dump(0)
    testEqual(cast(double, parser.eval_node(ast)), expected)
#endmacro

startTest(test_basic_parsing)
    dim parser as MockParser
    dim ast as ExprNode ptr

    ' Test integer
    testParseOK("42")
    testEqual(ast->node_type, EXPR_CONST)
    testEqual(ast->value_type, tyInt)
    testEqual(ast->int_value, 42)

    testParseOK("3.14")
    testEqual(ast->node_type, EXPR_CONST)
    testEqual(ast->value_type, tyFloat)
    testEqual(ast->float_value, 3.14)

    testParseOK("x")
    testEqual(ast->node_type, EXPR_VARIABLE)
    testEqual(ast->name, "x")

    testParseOK("sum(12)")
    testEqual(ast->node_type, EXPR_FUNCTION)
    testEqual(ast->name, "sum")
    testEqual(ubound(ast->args), 0)

    testParseOK("sum(-1,-2)")
    testEqual(ubound(ast->args), 1)

    ' Function parens optional
    testParseOK("childcount()")
    testEqual(ast->node_type, EXPR_FUNCTION)
    testEqual(ast->name, "childcount")
    testEqual(ubound(ast->args), -1)

    testParseOK("child count")
    testEqual(ast->node_type, EXPR_FUNCTION)
    testEqual(ast->name, "childcount")
    testEqual(ubound(ast->args), -1)

    ' Test whitespace in various places
    testParseOK(" - 42 ")
    testEqual(ast->int_value, -42)

    testParseOK(" 1 000 ")
    testEqual(ast->int_value, 1000)

    testParseOK("x + x velocity")
    testEqual(ast->node_type, EXPR_BINARY_OP)

    testParseOK(" c hildcoun t (   ) ")
    testEqual(ast->node_type, EXPR_FUNCTION)
    testEqual(ast->name, "childcount")
    testEqual(ubound(ast->args), -1)

    testParseOK("sum( 1 , 2 , 3 )")
    testEqual(ubound(ast->args), 2)
endTest

startTest(test_parse_errors)
    dim parser as MockParser
    dim ast as ExprNode ptr

    ' Test various error conditions
    testParseError("", "Empty expression")
    testParseError("42 junk", "Unexpected characters at end")
    testParseError("UNKNOWN(1)", "Unknown function: UNKNOWN")
    testParseError("UNKNOWN ()", "Unknown function: UNKNOWN")
    testParseError("unknown_var", "Unknown variable: unknown_var")
    testParseError("(3+4", "Expected ')'")
    testParseError("XY(1)", "Function XY expects 2 arguments")
    testParseError("XY(1,2,3)", "Function XY expects 2 arguments")
    testParseError("quarter()", "Function quarter expects 1 arguments")
    testParseError("3 +", "Expected number or identifier")
    testParseError("quarter(1,)", "Expected number or identifier")
endTest

startTest(test_nested_expressions)
    dim parser as MockParser
    dim ast as ExprNode ptr

    ' Test deeply nested expressions
    testEval("((1 + 2) * 3)", IntVal(9))
    testEval("quarter(30.0)", 7.5)
    testEval("quarter(40)", 10)
    testEval("quarter(x + 2*xvelocity)", 12.5)
    testEval("sum(1, 2 * 3, x)", 17) ' 1 + 6 + 10
    testEval("x + x velocity * 2", 50) ' 10 + 20 * 2
    testEval("(x + x velocity) * 2", 60) ' (10 + 20) * 2

    ' Test complex nesting
    testParseOK("sum(quarter(pi), x + 1, y * 2)")
    testEqual(ast->node_type, EXPR_FUNCTION)
    testEqual(ubound(ast->args), 2) ' 3 arguments
endTest
