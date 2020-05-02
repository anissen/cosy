package cosy.phases;

// typedef ByteCode = {
//     opcode: String,
//     value: Null<Any>,
// }

class CodeGenerator {
	public function new() {

	}

	public inline function generate(stmts: Array<Stmt>): Array<String> {
        return genStmts(stmts);
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
            case Var(name, type, init, mut, foreign): (init != null ? genExpr(init).concat(['set_var', name.lexeme]) : []); // TODO: Should probably be an index instead of a key for faster lookup
            case Expression(expr): genExpr(expr);
			case _: trace('Unhandled statement: $stmt'); [];
		}
	}

    // TODO: We also need line information for each bytecode
	function genExpr(expr: Expr): Array<String> {
		return switch expr {
            case Assign(name, op, value): genExpr(value).concat(['set_var', name.lexeme]);
            case Binary(left, op, right): genExpr(left).concat(genExpr(right)).concat([binaryOpCode(op)]);
            case Literal(v) if (Std.isOfType(v, Bool)): ['push_bool', '$v'];
            case Literal(v) if (Std.isOfType(v, Float)): ['push_num', '$v'];
            case Literal(v) if (Std.isOfType(v, String)): ['push_str', '$v'];
            case Variable(name): ['get_var', name.lexeme]; // TODO: Should probably be an index instead of a key for faster lookup
            case Unary(op, right): if (!op.type.match(Minus)) throw 'error'; genExpr(right).concat(['op_negate']);
			case _: trace('Unhandled expression: $expr'); [];
		}
    }

    function binaryOpCode(op: Token) {
        return switch op.type {
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
