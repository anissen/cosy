package cosy.phases;

// typedef ByteCode = {
//     opcode: String,
//     value: Null<Any>,
// }

class CodeGenerator {
    var bytecode: Array<String> = [];

	public function new() {

	}

	public inline function generate(stmts: Array<Stmt>): Array<String> {
        return generateStmts(stmts);
	}

	function generateStmts(stmts: Array<Stmt>) {
        var code = [];
        for (stmt in stmts) {
            code = code.concat(generateStmt(stmt));
        }
        return code;
	}

    function generateExprs(exprs: Array<Expr>) {
        var code = [];
        for (expr in exprs) {
            code = code.concat(generateExpr(expr));
        }
        return code;
    }

	function generateStmt(stmt: Stmt): Array<String> {
		return switch stmt {
            case Print(keyword, expr): generateExpr(expr).concat(['op_print']);
			case _: [];
		}
	}

    // TODO: We also need line information for each bytecode
	function generateExpr(expr: Expr): Array<String> {
		return switch expr {
            case Binary(left, op, right): generateExpr(left).concat(generateExpr(right)).concat([binaryOpCode(op)]);
            case Literal(v) if (Std.isOfType(v, Bool)): ['push', '$v'];
            case Literal(v) if (Std.isOfType(v, Float)): ['push', '$v'];
            case Literal(v) if (Std.isOfType(v, String)): ['push', '"$v"'];
			case _: [];
		}
    }

    function binaryOpCode(op: Token) {
        return switch op.type {
            case Plus: 'op_add';
            case Minus: 'op_sub';
            case Star: 'op_mult';
            case Slash: 'op_div';
            case _: throw 'error';
        }
    }
}
