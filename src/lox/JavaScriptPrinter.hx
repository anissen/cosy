package lox;

/*
Features:
- Converts "var" to "let" (reverted, as it does not work with global/local block scopes)
- Converts "==" to "==="

ISSUES:
- "super.init(...)" isn't translated to "super(...)"
- We keep track of classes to see if we need to translate "Foo()" to "new Foo()". However, we don't take into account that the class might be defined LATER than the usage.
*/

class JavaScriptPrinter {
	public function new() {}

	var indentAmount:Int = 0;
	var isInClass:Bool = false;
    var classNames = new Array<String>();

	function indent():String {
		return [ for (_ in 0...indentAmount) "  " ].join("");
	}

	public function printStmt(statement:Stmt):String {
		return switch statement {
			case Block(statements):
				indentAmount++;
				var s = [ for (stmt in statements) indent() + printStmt(stmt) ].join('\n');
				indentAmount--;
				'{\n$s\n${indent()}}';
			case Class(name, superclass, methods):
                var className = name.lexeme;
                classNames.push(className);
				var declaration = 'class $className' + (superclass != null ? ' extends ${printExpr(superclass)}' : '');
				indentAmount++;
				isInClass = true;
				var body = [ for (method in methods) indent() + printStmt(method) ].join('\n');
				isInClass = false;
				indentAmount--;
				'$declaration {\n$body\n${indent()}}';
			case Expression(e): '${printExpr(e)};';
			case Function(name, params, body):
				var declaration = '${isInClass ? "" : "function "}${name.lexeme}';
				var parameters = [ for (token in params) token.lexeme ].join(',');
				var block = printStmt(Block(body));
				'$declaration($parameters) $block';
			case If(cond, then, el): 'if (${printExpr(cond)}) ${printStmt(then)}' + (el != null ? ' else ${printStmt(el)}' : '');
			case Print(e): 'console.log(${printExpr(e)});';
			case Return(keyword, value): 'return' + (value != null ? ' ${printExpr(value)}' : '') + ';';
			case While(cond, body): 'while (${printExpr(cond)}) ${printStmt(body)}';
			case Var(name, init): 'var ${name.lexeme}' + (init != null ? ' = ${printExpr(init)}' : '') + ';';
		}
	}
	
	public function printExpr(expr:Expr):String {
		return switch expr {
			case Assign(name, value): '${name.lexeme} = ${printExpr(value)}';
			case Binary(left, op, right): '${printExpr(left)} ${op.type.match(EqualEqual) ? '===' : op.lexeme} ${printExpr(right)}';
			case Call(callee, paren, arguments): 
                var calleeName = printExpr(callee);
                var isClassName = (classNames.indexOf(calleeName) != -1);
                (isClassName ? 'new ' : '') + '$calleeName(${[ for (arg in arguments) printExpr(arg) ].join(',')})';
			case Get(obj, name): '${printExpr(obj)}.${name.lexeme}';
			case Grouping(e): '(${printExpr(e)})';
			case Literal(v): if (v == null) { 'null'; } else if (Std.is(v, String)) { '"$v"'; } else { '$v'; };
			case Logical(left, op, right): '${printExpr(left)} ${op.type.match(Or) ? '||' : '&&'} ${printExpr(right)}';
			case Set(obj, name, value): '${printExpr(obj)}.${name.lexeme} = ${printExpr(value)}';
			case This(keyword): 'this';
			case Super(keyword, method): 'super.${method.lexeme}';
			case Unary(op, right): '${op.lexeme}${printExpr(right)}';
			case Variable(name): name.lexeme;
			case AnonFunction(params, body):
				var parameters = [ for (token in params) token.lexeme ].join(',');
				var block = printStmt(Block(body));
				'function ($parameters) $block';
		}
	}
}
