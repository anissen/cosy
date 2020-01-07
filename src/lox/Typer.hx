package lox;

enum VariableType {
    Unknown;
    Boolean;
    Number;
    Text;
    Instance;
    // Function;
    Function(/* params:Array<VariableType> */ ret:VariableType);
}

class Typer {
	final interpreter:Interpreter;
    var variableTypes :Map<String, VariableType> = new Map();
    var functionName:String = null; // Hack to determine the function return type from the return keyword
    var returnValue :VariableType = Unknown; // Hack to determine the function return type from the return keyword
	
	public function new(interpreter) {
		this.interpreter = interpreter;
	}
	
	public inline function type(stmts:Array<Stmt>) {
        typeStmts(stmts);
	}

	function typeStmts(stmts:Array<Stmt>) {
        for (stmt in stmts) {
            typeStmt(stmt);
        }
	}

    function typeExprs(exprs:Array<Expr>) {
        for (expr in exprs) {
            typeExpr(expr);
        }
	}

	function typeStmt(stmt:Stmt) {
        // trace(stmt.getName());
		switch stmt {
			case Block(statements): typeStmts(statements);
			case Class(name, superclass, methods): typeStmts(methods);
			case Var(name, init): 
                // trace('set ${name.lexeme} (var)');
                variableTypes.set(name.lexeme, (init != null ? typeExpr(init) : Unknown)); 
            case Mut(name, init):
                // trace('set ${name.lexeme} (mut)');
                variableTypes.set(name.lexeme, (init != null ? typeExpr(init) : Unknown));
            case For(name, from, to, body): typeStmts(body);
            case ForCondition(cond, body): typeStmts(body);
			case Function(name, params, body):
                functionName = name.lexeme;
                typeStmts(body);
                // trace('function $functionName has type $returnValue');
                variableTypes.set(name.lexeme, (returnValue != null ? returnValue : Unknown)); 
                functionName = null;
			case Expression(e): typeExpr(e);
            case Print(e):
			case If(cond, then, el): typeStmt(then); if (el != null) typeStmt(el);
			case Return(kw, val):
                // trace('return $val');
                // variableTypes.set(functionName, (val != null ? typeExpr(val) : Unknown));
                if (val != null) returnValue = typeExpr(val); // TODO: This is not enough for nested functions!
		}
	}
	
	function typeExpr(expr:Expr) :VariableType {
		var ret = switch expr {
			case Assign(name, value):
                // trace('assign, ${name.lexeme} <= $value');
                var assigningType = typeExpr(value);
                // trace('get ${name.lexeme}');
                var varType = variableTypes.get(name.lexeme);
                // trace('varType: $varType');
                // trace('var type: ${varType.getName()}, assigning type: ${assigningType.getName()}');
                if (varType.match(Unknown)) {
                    variableTypes.set(name.lexeme, assigningType);
                } else if (!matchType(varType, assigningType)) {
                    Lox.error(name, 'TYPER: Cannot assign ${assigningType} to ${varType}');
                }
                return assigningType;
			case Variable(name):
                // trace('Variable ${name.lexeme} has type ${variableTypes.get(name.lexeme)}');
                return variableTypes.get(name.lexeme);
			case Binary(left, _, right): 
                var leftType = typeExpr(left);
                var rightType = typeExpr(right);
                if (leftType.match(Text) || rightType.match(Text)) return Text;
                if (leftType.match(Number) || rightType.match(Number)) return Number;
                return Unknown;
            case Logical(left, _, right): Boolean;
			case Call(callee, paren, arguments):
                // trace('callee: $callee');
                var calleeType = typeExpr(callee);
                // trace('calleeType: $calleeType');
                // if (!calleeType.match(Function(_))) {
                //     Lox.error(paren, 'Can only call functions and classes');
                // }
                // trace(paren);
                // trace(arguments);
                //Unknown;
                calleeType;
			case Get(obj, name): Unknown;
			case Set(obj, name, value): Unknown;
			case Grouping(e) | Unary(_, e): typeExpr(e);
			case Super(kw, method): Instance;
			case This(kw): Instance;
			case Literal(v) if (Std.is(v, Float)): Number;
			case Literal(v) if (Std.is(v, String)): Text;
			case Literal(v) if (Std.is(v, Bool)): Boolean;
			case Literal(v): Unknown;
			case AnonFunction(params, body):
                returnValue = Unknown; // TODO: This is not good enough for nested functions -- we need to keep track of scoping!
                typeStmts(body);
                Function(returnValue);
		}
        // trace(expr.getName() + ' => $ret');
        return ret;
	}

    function matchType(type1 :VariableType, type2 :VariableType) :Bool {
        return switch type1 {
            case Function(v1):
                switch type2 {
                    case Function(v2): matchType(v1, v2);
                    case _: false;
                }
            case _: type1 == type2;
        }
    }
}
