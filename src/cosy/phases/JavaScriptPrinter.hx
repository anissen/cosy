package cosy.phases;

/*
Features:
- Converts "var" to "let" (reverted, as it does not work with global/local block scopes)
- Converts "==" to "==="
*/

class JavaScriptPrinter {
	public function new() {}

	var indentAmount:Int = 0;

	function indent():String {
		return [ for (_ in 0...indentAmount) "    " ].join("");
	}

    function printBlock(statements:Array<Stmt>):String {
        indentAmount++;
        var s = [ for (stmt in statements) indent() + printStmt(stmt) ].join('\n');
        indentAmount--;
        return '{\n$s\n${indent()}}';
    }

	public function printStmt(statement:Stmt):String {
		return switch statement {
            case Block(statements): printBlock(statements);
            case Break(keyword): 'break;';
            case Continue(keyword): 'continue;';
			case Expression(e): '${printExpr(e)};';
			case For(keyword, name, from, to, body):
                var counter = (name != null ? name.lexeme : '__i');
                'for (var $counter = ${printExpr(from)}; $counter < ${printExpr(to)}; $counter++) ${printBlock(body)}';
			case ForArray(name, array, body): 'for (${name.lexeme} of ${printExpr(array)}) ${printBlock(body)}';
			case ForCondition(keyword, cond, body): 'while (${cond != null ? printExpr(cond) : "true"}) ${printBlock(body)}';
			case Function(name, params, body, returnType, foreign):
                if (foreign) return ''; // TODO: Is this correct behavior?
				var declaration = 'function ${name.lexeme}';
				var parameters = [ for (token in params) token.name.lexeme ].join(',');
				var block = printStmt(Block(body));
				'$declaration($parameters) $block';
			case If(keyword, cond, then, el): 'if (${printExpr(cond)}) ${printStmt(then)}' + (el != null ? ' else ${printStmt(el)}' : '');
            case Print(keyword, e): 'console.log(${printExpr(e)});';
            case Struct(name, declarations): '// ${name.lexeme} struct';
			case Return(keyword, value): 'return' + (value != null ? ' ${printExpr(value)}' : '') + ';';
			case Var(name, type, init, mut, foreign):
                if (foreign) return ''; // TODO: Is this correct behavior?
                '${mut ? "var" : "const"} ${name.lexeme}' + (init != null ? ' = ${printExpr(init)}' : '') + ';';
		}
	}

	function std_function_get_map(token: Token) {
		return switch token.lexeme {
			case 'char_at': 'charAt';
			case 'char_code_at': 'charCodeAt';
			case lexeme: lexeme;
		}
	}
	
	function std_function_map(str: String) {
		return switch str {
			case 'floor': 'Math.floor';
			case _: str;
		}
	}
	
	public function printExpr(expr:Expr):String {
		return switch expr {
            case ArrayLiteral(keyword, exprs): '[' + exprs.map(printExpr).join(', ') + ']';
			case Assign(name, op, value): '${name.lexeme} ${op.lexeme} ${printExpr(value)}';
			case Binary(left, op, right): '${printExpr(left)} ${op.type.match(EqualEqual) ? '===' : op.lexeme} ${printExpr(right)}';
			case Call(callee, paren, arguments): 
                var calleeName = std_function_map(printExpr(callee));
                '$calleeName(${arguments.map(printExpr).join(',')})';
			case Get(obj, name): '${printExpr(obj)}.${std_function_get_map(name)}';
			case GetIndex(obj, index): '${printExpr(obj)}[${printExpr(index)}]';
			case Grouping(e): '(${printExpr(e)})';
			case MutArgument(keyword, name): name.lexeme;
			case Literal(v): if (v == null) { 'null'; } else if (Std.isOfType(v, String)) { '"$v"'; } else { '$v'; };
			case Logical(left, op, right): '${printExpr(left)} ${op.type.match(Or) ? '||' : '&&'} ${printExpr(right)}';
			case Set(obj, name, op, value): '${printExpr(obj)}.${name.lexeme} ${op.lexeme} ${printExpr(value)}';
			case SetIndex(obj, index, op, value): '${printExpr(obj)}[${printExpr(index)}] ${op.lexeme} ${printExpr(value)}';
			case StringInterpolation(exprs): '`' + [ for (i => expr in exprs) { var e = printExpr(expr); (i % 2 == 0 ? e.substr(1, e.length - 2) : "${" + e + "}"); } ].join('') + '`';
            case StructInit(name, decls): 
                var init = [ for (decl in decls) StringTools.replace(printExpr(decl), ' = ', ': ') ];
                '{ ${init.join(", ")} }';
			case Unary(op, right): '${op.lexeme}${printExpr(right)}';
			case Variable(name): name.lexeme;
			case AnonFunction(params, body, returnType):
				var parameters = [ for (token in params) token.name.lexeme ].join(', ');
				var block = printStmt(Block(body));
				'function ($parameters) $block';
		}
	}
}
