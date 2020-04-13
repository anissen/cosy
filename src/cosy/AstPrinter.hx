package cosy;

class AstPrinter {
	public function new() {}

	var indentAmount:Int = 0;
	var isInClass:Bool = false;

	function indent():String {
		return [ for (_ in 0...indentAmount) "  " ].join("");
	}

    function printBlock(statements:Array<Stmt>):String {
        indentAmount++;
        var s = [ for (stmt in statements) indent() + printStmt(stmt) ].join('\n');
        indentAmount--;
        return '{\n$s\n${indent()}}';
    }

    function printExprBlock(exprs:Array<Expr>):String {
        indentAmount++;
        var s = [ for (expr in exprs) indent() + printExpr(expr) ].join('\n');
        indentAmount--;
        return '{\n$s\n${indent()}}';
    }

	public function printStmt(statement:Stmt):String {
		return switch statement {
            case Block(statements): printBlock(statements);
            case Break(keyword): keyword.lexeme;
            case Continue(keyword): keyword.lexeme;
			case Class(name, superclass, methods):
				var declaration = 'class ${name.lexeme}' + (superclass != null ? ' < ${printExpr(superclass)}' : '');
				isInClass = true;
                var body = printBlock(methods);
				isInClass = false;
				'$declaration $body';
			case Expression(e): '${printExpr(e)}';
			case For(keyword, name, from, to, body): 'for ${name != null ? name.lexeme + " in" : ""}${printExpr(from)}..${printExpr(to)} ${printBlock(body)}';
			case ForArray(name, array, body): 'for ${name.lexeme} in ${printExpr(array)} ${printBlock(body)}';
            case ForCondition(cond, body): 'for ${cond != null ? printExpr(cond) : ""} ${printBlock(body)}';
			case Function(name, params, body, returnType, foreign):
				var declaration = '${isInClass ? "" : (foreign ? "foreign fn" : "fn")} ${name.lexeme}';
                var parameters = [ for (param in params) formatParam(param) ].join(', ');
                if (foreign) return '$declaration($parameters)';
                var block = printBlock(body);
				'$declaration($parameters) $block';
			case If(cond, then, el): 'if ${printExpr(cond)} ${printStmt(then)}' + (el != null ? ' else ${printStmt(el)}' : '');
			case Print(keyword, e): '${keyword.lexeme} ${printExpr(e)}';
            case Return(keyword, value): keyword.lexeme + (value != null ? ' ${printExpr(value)}' : '');
            case Struct(name, declarations): 'struct ${name.lexeme} ${printBlock(declarations)}';
			case Var(name, type, init, mut, foreign): '${foreign ? "foreign " : ""}${mut ? "mut" : "var"} ${name.lexeme}' + (init != null ? ' = ${printExpr(init)}' : '');
		}
	}
	
	public function printExpr(expr:Expr):String {
		return switch expr {
            case ArrayLiteral(keyword, exprs): '[' + [ for (expr in exprs) ${printExpr(expr)} ].join(',') + ']';
			case Assign(name, op, value): '${name.lexeme} ${op.lexeme} ${printExpr(value)}';
			case Binary(left, op, right): '${printExpr(left)} ${op.lexeme} ${printExpr(right)}';
			case Call(callee, paren, arguments): '${printExpr(callee)}(${[ for (arg in arguments) printExpr(arg) ].join(', ')})';
			case Get(obj, name): '${printExpr(obj)}.${name.lexeme}';
			case Grouping(e): '(${printExpr(e)})';
			case Literal(v): if (Std.is(v, String)) { '\'$v\''; } else { '$v'; };
            case Logical(left, op, right): '${printExpr(left)} ${op.type.match(Or) ? 'or' : 'and'} ${printExpr(right)}';
            case MutArgument(keyword, name): 'mut ${name.lexeme}';
			case Set(obj, name, value): '${printExpr(obj)}.${name.lexeme} = ${printExpr(value)}';
			case This(keyword): keyword.lexeme;
            case Super(keyword, method): '${keyword.lexeme}.${method.lexeme}';
            case StructInit(name, decls): printExprBlock(decls);
            case Unary(op, right): '${op.lexeme}${printExpr(right)}';
			case Variable(name): name.lexeme;
			case AnonFunction(params, body, returnType):
				var parameters = [ for (param in params) formatParam(param) ].join(',');
				var block = printStmt(Block(body));
				'fn ($parameters) $block';
		}
    }
    
    function formatType(type :Typer.VariableType) {
        return switch type {
            case Function(paramTypes, returnType):
                var paramStr = [ for (paramType in paramTypes) formatType(paramType) ];
                'Fn(${paramStr.join(", ")})';
            case Array(t): StringTools.trim('Array ' + formatType(t));
            case Text: 'Str';
            case Number: 'Num';
            case Boolean: 'Bool';
            case Unknown: ''; // Ignore Unknown in this case to leave it out of the prettified code
            case _: '$type';
        }
    }

    function formatParam(param :Param) :String {
        var typeStr = formatType(param.type);
        return param.name.lexeme + (typeStr != '' ? ' $typeStr' : '');
    }
}
