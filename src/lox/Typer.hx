package lox;

enum VariableType {
    Unknown;
    Void;
    Boolean;
    Number;
    Text;
    Instance;
    // Function;
    Function(paramTypes:Array<VariableType>, returnType:VariableType);
}

class Typer {
	final interpreter:Interpreter;
    var variableTypes :Map<String, VariableType> = new Map();
    var functionName:String = null; // Hack to determine the function return type from the return keyword
    var returnValue :VariableType = Void; // Hack to determine the function return type from the return keyword
	
	public function new(interpreter) {
		this.interpreter = interpreter;
        variableTypes.set('clock', Number);
        variableTypes.set('random', Number);
        variableTypes.set('str_length', Number);
        variableTypes.set('str_charAt', Text);
        variableTypes.set('input', Text);
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
                switch typeExpr(from) {
                    case Unknown: Lox.warning(name, '"From" clause has type Unknown');
                    case Number:
                    case _: Lox.error(name, '"From" clause must evaluate to a number');
                }
                switch typeExpr(to) {
                    case Unknown: Lox.warning(name, '"To" clause has type Unknown');
                    case Number:
                    case _: Lox.error(name, '"To" clause must evaluate to a number');
                }
                variableTypes.set(name.lexeme, Number); // TODO: This may change when arrays are introduced
                typeStmts(body);
            case ForCondition(cond, body): typeStmts(body);
			case Function(name, params, body, returnType): handleFunc(name, params, body, returnType);
			case Expression(e): typeExpr(e);
            case Print(e): typeExpr(e);
			case If(cond, then, el): typeStmt(then); if (el != null) typeStmt(el);
			case Return(kw, val):
                // trace('return $val');
                // variableTypes.set(functionName, (val != null ? typeExpr(val) : Unknown));

                // TODO: Check that the return type matches that of the function

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
                // trace('var type: ${formatType(varType)}, assigning type: ${formatType(assigningType)}');
                if (varType.match(Unknown)) {
                    variableTypes.set(name.lexeme, assigningType);
                } else if (!matchType(varType, assigningType)) {
                    Lox.error(name, 'Cannot assign ${formatType(assigningType)} to ${formatType(varType)}');
                }
                return assigningType;
			case Variable(name):
                // trace('Variable ${name.lexeme} has type ${variableTypes.get(name.lexeme)}');
                if (variableTypes.exists(name.lexeme)) {
                    return variableTypes.get(name.lexeme);
                } else { // can happen for recursive function calls
                    return Unknown;
                }
			case Binary(left, _, right): 
                var leftType = typeExpr(left);
                var rightType = typeExpr(right);
                if (leftType.match(Text) || rightType.match(Text)) return Text;
                if (leftType.match(Number) || rightType.match(Number)) return Number;
                return Unknown;
            case Logical(left, _, right): Boolean;
			case Call(callee, paren, arguments):
                // trace('callee: $callee, line ${paren.line}');
                // trace(arguments);
                var calleeType = typeExpr(callee);
                var type = Unknown;
                switch calleeType {
                    case Function(paramTypes, returnType):
                        type = returnType;
                        var argumentTypes = [ for (arg in arguments) typeExpr(arg) ];
                        if (arguments.length != paramTypes.length) {
                            Lox.error(paren, 'Expected ${paramTypes.length} argument(s) but got ${arguments.length}.');
                        } else {
                            for (i in 0...paramTypes.length) {
                                if (argumentTypes[i].match(Unknown)) Lox.warning(paren, 'Argument ${i + 1} has type Unknown.');
                                if (paramTypes[i].match(Unknown)) continue;
                                if (!matchType(argumentTypes[i], paramTypes[i])) {
                                    Lox.error(paren, 'Expected argument ${i + 1} to be ${formatType(paramTypes[i])} but got ${formatType(argumentTypes[i])}.');
                                }
                            }
                        }
                    case _:
                }
                // trace(calleeType);
                // if (!matchType(calleeType, Function(argumentTypes, Unknown))) {
                //     Lox.error(paren, 'Cannot call ${calleeType} with ${argumentTypes}');
                // }
                
                // TODO: Here I should be able to determine (á la Interpreter.evaluate()) the function name and each argument name. This information I could use to set the types for the arguments (e.g. in the form 'function_name.arg_name' => type, alternatively associate a scope with each function). Subsequent calls to that function could then be checked against the same types
                
                // calleeType;
                // trace(type);
                type;
			case Get(obj, name): Unknown; // TODO: Implement
			case Set(obj, name, value): Unknown; // TODO: Implement
			case Grouping(e) | Unary(_, e): typeExpr(e);
			case Super(kw, method): Instance;
			case This(kw): Instance;
			case Literal(v) if (Std.is(v, Float)): Number;
			case Literal(v) if (Std.is(v, String)): Text;
			case Literal(v) if (Std.is(v, Bool)): Boolean;
			case Literal(v): Unknown;
			case AnonFunction(params, body, returnType): handleFunc(null, params, body, returnType);
		}
        if (ret == null) {
            trace('-----------');
            trace('null!!');
            trace(expr);
            switch expr {
                case Call(callee, paren, arguments): trace('line ${paren.line}');
                case _:
            }
            trace('-----------');
        }
        // trace(expr.getName() + ' => $ret');
        if (ret.match(Unknown)) {
            switch expr {
                case Call(callee, paren, arguments): Lox.warning(paren, '${expr.getName()} has type Unknown');
                case _: Lox.warning(-1, '${expr.getName()} has type Unknown');
            }
        }
        return ret;
    }
    
    function handleFunc(name:Token, params:Array<Param>, body:Array<Stmt>, returnType:Typer.VariableType) :VariableType {
        // TODO: Enable if strict.
        // for (i in 0...params.length) {
        //     if (params[i].type.match(Unknown)) Lox.warning(params[i].name, 'Parameter has type Unknown');
        // }
        var types = [ for (param in params) param.type ];
        for (param in params) variableTypes.set(param.name.lexeme, param.type); // TODO: These parameter names may be overwritten in later code, and thus be invalid when we enter this function. The solution is probably to have a scope associated with each function or block.

        // for (param in params) variableTypes.set(name.lexeme + '.' + param.lexeme, Unknown); // TODO: Temp hack!

        functionName = (name != null ? name.lexeme : null);
        returnValue = Void;
        typeStmts(body);
        // trace('function $functionName has type $returnValue');
        // var returnType = (returnValue != null ? returnValue : Void);

        var computedReturnType = switch returnType {
            case Unknown: returnValue;
            case _: returnType;
        }

        if (name != null) variableTypes.set(name.lexeme, Function(types, computedReturnType)); 
        functionName = null;
        return Function(types, computedReturnType);
    }

    function matchType(type1 :VariableType, type2 :VariableType) :Bool {
        return switch type1 {
            case Function(params1, v1):
                switch type2 {
                    case Function(params2, v2):
                        if (params1.length != params2.length) return false;
                        for (param1 in params1) {
                            for (param2 in params2) {
                                if (!matchType(param1, param2)) return false;
                            }
                        }
                        matchType(v1, v2);
                    case _: false;
                }
            case _: type1 == type2;
        }
    }

    function formatType(type :VariableType) :String {
        return switch type {
            case Function(paramTypes, returnType):
                var paramStr = [ for (paramType in paramTypes) formatType(paramType) ];
                var returnStr = switch returnType {
                    case Void: '';
                    case _: ' -> ' + formatType(returnType);
                }
                var funcStr = 'Fun(${paramStr.join(", ")})$returnStr';
                return (returnType.match(Void) ? funcStr : '($funcStr)');
            case Text: 'Str';
            case Number: 'Num';
            case Boolean: 'Bool';
            case _: Std.string(type);
        }
    }
}
