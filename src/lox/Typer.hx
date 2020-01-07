package lox;

enum VariableType {
    Unknown;
    Void;
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
    var returnValue :VariableType = Void; // Hack to determine the function return type from the return keyword
	
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
                var initType = (init != null ? typeExpr(init) : Unknown);
                if (initType.match(Void)) Lox.error(name, 'Cannot assign Void to a variable');
                variableTypes.set(name.lexeme, initType);
            case Mut(name, init):
                // trace('set ${name.lexeme} (mut)');
                var initType = (init != null ? typeExpr(init) : Unknown);
                if (initType.match(Void)) Lox.error(name, 'Cannot assign Void to a variable');
                variableTypes.set(name.lexeme, initType);
            case For(name, from, to, body):
                if (!typeExpr(from).match(Number)) Lox.error(name, '"From" clause must evaluate to a number');
                if (!typeExpr(to).match(Number)) Lox.error(name, '"To" clause must evaluate to a number');
                variableTypes.set(name.lexeme, Number); // TODO: This may change when arrays are introduced
                typeStmts(body);
            case ForCondition(cond, body): typeStmts(body);
			case Function(name, params, body):
                for (param in params) variableTypes.set(param.lexeme, Unknown); // TODO: These parameter names may be overwritten in later code, and thus be invalid when we enter this function. The solution is probably to have a scope associated with each function or block.
                
                // for (param in params) variableTypes.set(name.lexeme + '.' + param.lexeme, Unknown); // TODO: Temp hack!

                functionName = name.lexeme;
                returnValue = Void;
                typeStmts(body);
                // trace('function $functionName has type $returnValue');
                var returnType = (returnValue != null ? returnValue : Void);
                variableTypes.set(name.lexeme, Function(returnType)); 
                functionName = null;
			case Expression(e): typeExpr(e);
            case Print(e):
			case If(cond, then, el): typeStmt(then); if (el != null) typeStmt(el);
			case Return(kw, val):
                // trace('return $val');
                // variableTypes.set(functionName, (val != null ? typeExpr(val) : Unknown));
                if (val != null) {
                    returnValue = typeExpr(val); // TODO: This is PROBABLY not enough for nested functions!
                } else {
                    returnValue = Void;
                }
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
                trace('leftType: $leftType');
                trace('rightType: $rightType');
                if (leftType.match(Text) || rightType.match(Text)) return Text;
                if (leftType.match(Number) || rightType.match(Number)) return Number;
                return Unknown;
            case Logical(left, _, right): Boolean;
			case Call(callee, paren, arguments):
                trace('callee: $callee');
                trace(arguments);
                var calleeType = typeExpr(callee);
                
                // TODO: Here I should be able to determine (á la Interpreter.evaluate()) the function name and each argument name. This information I could use to set the types for the arguments (e.g. in the form 'function_name.arg_name' => type, alternatively associate a scope with each function). Subsequent calls to that function could then be checked against the same types
                
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
                returnValue = Void; // TODO: This is PROBABLY not good enough for nested functions -- we need to keep track of scoping!
                typeStmts(body);
                Function(returnValue);
		}
        if (ret.match(Unknown)) {
            trace('Warning, ${expr.getName()} has type Unknown');
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
