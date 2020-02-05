package cosy;

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

    function printBlock(statements:Array<Stmt>):String {
        indentAmount++;
        var s = [ for (stmt in statements) indent() + printStmt(stmt) ].join('\n');
        indentAmount--;
        return '{\n$s\n${indent()}}';
    }

	public function printStmt(statement:Stmt):String {
		return switch statement {
			case Block(statements): printBlock(statements);
			case Class(name, superclass, methods):
                var className = name.lexeme;
                classNames.push(className);
				var declaration = 'class $className' + (superclass != null ? ' extends ${printExpr(superclass)}' : '');
				isInClass = true;
				var body = printBlock(methods);
				isInClass = false;
				'$declaration $body';
			case Expression(e): '${printExpr(e)};';
			case For(keyword, name, from, to, body):
                var counter = (name != null ? name.lexeme : '__i');
                'for (var $counter = ${printExpr(from)}; $counter < ${printExpr(to)}; $counter++) ${printBlock(body)}';
			case ForArray(name, array, body): 'for (${name.lexeme} of ${printExpr(array)}) ${printBlock(body)}';
			case ForCondition(cond, body): 'while (${cond != null ? printExpr(cond) : "true"}) ${printBlock(body)}';
			case Function(name, params, body, returnType):
				var declaration = '${isInClass ? "" : "function "}${name.lexeme}';
				var parameters = [ for (token in params) token.name.lexeme ].join(',');
				var block = printStmt(Block(body));
				'$declaration($parameters) $block';
			case If(cond, then, el): 'if (${printExpr(cond)}) ${printStmt(then)}' + (el != null ? ' else ${printStmt(el)}' : '');
            case Print(e): 'console.log(${printExpr(e)});';
            case Struct(name, declarations): 'class ${name.lexeme} ${printBlock(declarations)}'; // TODO: This does not work.
			case Return(keyword, value): 'return' + (value != null ? ' ${printExpr(value)}' : '') + ';';
			case Var(name, init): 'const ${name.lexeme}' + (init != null ? ' = ${printExpr(init)}' : '') + ';';
			case Mut(name, init): 'var ${name.lexeme}' + (init != null ? ' = ${printExpr(init)}' : '') + ';';
		}
	}
	
	public function printExpr(expr:Expr):String {
		return switch expr {
            case ArrayLiteral(keyword, exprs): '[' + [ for (expr in exprs) ${printExpr(expr)} ].join(',') + ']';
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
			case AnonFunction(params, body, returnType):
				var parameters = [ for (token in params) token.name.lexeme ].join(',');
				var block = printStmt(Block(body));
				'function ($parameters) $block';
		}
	}
}
