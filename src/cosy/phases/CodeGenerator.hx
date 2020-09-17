package cosy.phases;

// typedef ByteCode = {
//     opcode: String,
//     value: Null<Any>,
// }

class CodeGenerator {
    var labelCounter: Int;
    var functions: Array<String>;

    var anonFunctionsCount :Int;

	public function new() {

	}

    // TODO: Use Bytes (https://api.haxe.org/haxe/io/Bytes.html) instead
	public inline function generate(stmts: Array<Stmt>): Array<String> {
        labelCounter = 0;
        functions = [];
        anonFunctionsCount = 0;
        var code = ['main:'].concat(genStmts(stmts));
        return patchJumpPositions(functions.concat(code));
    }

    function patchJumpPositions(code: Array<String>): Array<String> {
        // TODO: Make a new array with the labels not added

        // label_start1
        // jump label_end1 (break)
        // label_end1
        // =>
        // -
        // jump XYZ
        // -

        // var patchedCode = [];

        var labels = new Map<String, Int>();
        for (index => c in code) {
            if (index == 0) continue;
            if (index > 1 && code[index - 2] == 'push_str') continue;

            var lastCode = code[index - 1];
            if (lastCode == 'label') {
                labels[c] = index + 1;
            }
        }
        trace(labels);
        for (index => c in code) {
            if (index == 0) continue;
            var lastCode = code[index - 1];
            // TODO: Make a 'label_jump' and 'label_jump_if_not' and transform them into 'jump/jump_if_not'
            // e.g. 'label_jump 4' => 'jump -13'
            if (lastCode == 'jump' || lastCode == 'jump_if_not') {
                if (c.charAt(0) == ':') { // e.g. :start_2
                    var jumpLabel = c.substr(1); // e.g. start_2
                    // trace(jumpLabel);
                    var jumpPosition = labels[jumpLabel];
                    var relativeJumpPosition = jumpPosition - index - 1;
                    code[index] = '$relativeJumpPosition';
                }
            }
        }
        trace(code);

        return code;
    }

	function genStmts(stmts: Array<Stmt>) {
        var code = [];
        for (stmt in stmts) {
            code = code.concat(genStmt(stmt));
        }
        return code;
	}

    function genExprs(exprs: Array<Expr>) {
        var code = [];
        for (expr in exprs) {
            code = code.concat(genExpr(expr));
        }
        return code;
    }

	function genStmt(stmt: Stmt): Array<String> {
		return switch stmt {
            case Print(keyword, expr): genExpr(expr).concat(['op_print']);
            case Var(name, type, init, mut, foreign): (init != null ? genExpr(init).concat(['save_var', name.lexeme]) : []); // TODO: Should probably be an index instead of a key for faster lookup
            case Block(statements): genStmts(statements);
            case For(keyword, name, from, to, body):
                // example: for i in 1..3 {}

                /*
                [from]
                save [counter]
                L_start:
                [load counter]
                [to]
                op_less  (counter < to)
                jump_if_not L_end
                [body]  (can e.g. contain 'break' (jump L_end) or 'continue' (jump L_start))
                L_continue:
                op_inc [counter]
                jump L_start
                L_end:
                */

                labelCounter++;
                return genExpr(from)
                    .concat(['save_var', name.lexeme]) // i = 0 (from)
                    .concat(['label', 'start_$labelCounter'])
                    .concat(['load_var', name.lexeme])
                    .concat(genExpr(to))
                    .concat(['op_less']) // i < 2 (to)
                    .concat(['jump_if_not', ':end_$labelCounter']) // jump to loop end if false
                    .concat(genStmts(body))
                    .concat(['label', 'continue_$labelCounter'])
                    .concat(['op_inc', name.lexeme]) // increment i
                    .concat(['jump', ':start_$labelCounter']) // jump to start of loop
                    .concat(['label', 'end_$labelCounter']);
            // case ForArray(name, array, body):
                // example: for i in [3,4,5] {}

                /*
                push_num 0
                save array_index
                L_start:
                load array_index
                //how: array_length
                get_from_array
                save name
                [body]
                L_continue:
                op_inc array_index
                L_end:
                */

                // labelCounter++;
                // return genExpr(array)
                //     .concat(['push_num', '0'])
                //     .concat(['save_var', 'array_index'])
                //     .concat(['label', 'start_$labelCounter'])
                //     .concat(['load_var', 'array_index'])
                //     .concat(['load_array_index'])
                //     .concat(['save_var', '${name.lexeme}'])
                //     .concat(genStmts(body))
                //     .concat(['label', 'continue_$labelCounter'])
                //     .concat(['op_inc', 'array_index'])
                //     .concat(['label', 'end_$labelCounter']);

            case ForCondition(cond, body):
                // example: for i < 3 {}

                /*
                L_start:
                L_continue: // TODO: This ought to be removed
                [cond]
                jump_if_not L_end
                [body]  (can e.g. contain 'break' (jump L_end) or 'continue' (jump L_start))
                jump L_start
                L_end:
                */

                labelCounter++;
                var bodyCode = genStmts(body);
                var condCode = ['label', 'start_$labelCounter'].concat(cond != null ? genExpr(cond).concat(['jump_if_not', ':end_$labelCounter']) : []);
                bodyCode = bodyCode
                    .concat(['jump', ':start_$labelCounter']) // jump to condition at start of loop
                    .concat(['label', 'end_$labelCounter']);
                return condCode.concat(bodyCode);
            case If(cond, then, el):
                var thenCode = genStmt(then);
                var elseCode = (el != null ? genStmt(el) : []);
                if (elseCode.length > 0) thenCode = thenCode.concat(['jump', '${elseCode.length}']); // make the 'then' branch jump over the 'else' branch, if it exists
                return genExpr(cond)
                    .concat(['jump_if_not', '${thenCode.length}'])
                    .concat(thenCode)
                    .concat(elseCode);
            case Expression(expr): genExpr(expr);
            case Function(name, params, body, returnType, foreign):
                // labelCounter++;
                var code = ['fn ${name.lexeme}']
                // .concat(['label', 'fn_start_${name.lexeme}'])
                .concat(genStmts(body))
                .concat(['label', 'fn_end_${name.lexeme}'])
                .concat(['op_return']);
                functions = functions.concat(code);
                return ['push_fn', '${name.lexeme}', 'save_var', '${name.lexeme}'];
            case Continue(keyword): ['jump', ':continue_$labelCounter'];
            case Break(keyword): ['jump', ':end_$labelCounter'];
            case Return(keyword, value): (value != null ? genExpr(value).concat(['op_return_value']) : ['op_return']);
			case _: trace('Unhandled statement: $stmt'); [];
		}
	}

    // TODO: We also need line information for each bytecode
	function genExpr(expr: Expr): Array<String> {
		return switch expr {
            case AnonFunction(params, body, returnType):
                anonFunctionsCount++;
                var code = ['fn anon_$anonFunctionsCount']
                // .concat(['label', 'fn_start_anon_$anonFunctionsCount'])
                .concat(genStmts(body))
                .concat(['label', 'fn_end_anon_$anonFunctionsCount'])
                .concat(['op_return']);
                functions = functions.concat(code);
                return ['push_fn', 'anon_$anonFunctionsCount'];
            case Assign(name, op, value): genExpr(value).concat(['save_var', name.lexeme]);
            case ArrayLiteral(keyword, exprs): genExprs(exprs).concat(['to_array', '${exprs.length}']); // TODO: This is a very näive approach!
            case Binary(left, op, right): genExpr(left).concat(genExpr(right)).concat([binaryOpCode(op)]);
            case Call(callee, paren, arguments):
                genExpr(callee)
                .concat(genExprs(arguments))
                .concat(['call', '${arguments.length}']);
            case Literal(v) if (Std.isOfType(v, Bool)): [v ? 'push_true' : 'push_false'];
            case Literal(v) if (Std.isOfType(v, Float)): ['push_num', '$v'];
            case Literal(v) if (Std.isOfType(v, String)): ['push_str', '$v'];
            case Grouping(expr): genExpr(expr);
            case Variable(name): ['load_var', name.lexeme]; // TODO: Should probably be an index instead of a key for faster lookup
            case Unary(op, right): if (!op.type.match(Minus)) throw 'error'; genExpr(right).concat(['op_negate']);
			case _: trace('Unhandled expression: $expr'); [];
		}
    }

    function binaryOpCode(op: Token) {
        return switch op.type {
            case EqualEqual: 'op_equals';
            case Plus: 'op_add';
            case Minus: 'op_sub';
            case Star: 'op_mult';
            case Slash: 'op_div';
            case Less: 'op_less';
            case LessEqual: 'op_less_eq';
            case Greater: 'op_greater';
            case GreaterEqual: 'op_greater_eq';
            case _: throw 'error';
        }
    }
}
