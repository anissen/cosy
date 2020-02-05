package cosy;

enum VariableType {
    Unknown;
    Void;
    Boolean;
    Number;
    Text;
    Instance;
    Function(paramTypes:Array<VariableType>, returnType:VariableType);
    Array(type:VariableType);
}

class Typer {
    var variableTypes :Map<String, VariableType> = new Map();
    var typedReturnType :VariableType = Unknown;
    var inferredReturnType :VariableType = Void;
	
	public function new() {
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
		switch stmt {
			case Block(statements): typeStmts(statements);
			case Class(name, superclass, methods): typeStmts(methods);
			case Var(name, init): 
                var initType = (init != null ? typeExpr(init) : Unknown);
                if (initType.match(Void)) Cosy.error(name, 'Cannot assign Void to a variable');
                variableTypes.set(name.lexeme, initType);
            case Mut(name, init):
                var initType = (init != null ? typeExpr(init) : Unknown);
                if (initType.match(Void)) Cosy.error(name, 'Cannot assign Void to a variable');
                variableTypes.set(name.lexeme, initType);
            case For(keyword, name, from, to, body):
                switch typeExpr(from) {
                    case Unknown: Cosy.warning(keyword, '"From" clause has type Unknown');
                    case Number:
                    case _: Cosy.error(keyword, '"From" clause must evaluate to a number');
                }
                switch typeExpr(to) {
                    case Unknown: Cosy.warning(keyword, '"To" clause has type Unknown');
                    case Number:
                    case _: Cosy.error(keyword, '"To" clause must evaluate to a number');
                }
                if (name != null) variableTypes.set(name.lexeme, Number); // TODO: This may change when arrays are introduced
                typeStmts(body);
            case ForArray(name, array, body):
                // TODO: Implement this
                variableTypes.set(name.lexeme, Number); // TODO: This may change when arrays are introduced
                typeStmts(body);
            case ForCondition(cond, body): typeStmts(body);
			case Function(name, params, body, returnType): handleFunc(name, params, body, returnType);
			case Expression(e): typeExpr(e);
            case Print(e): typeExpr(e);
			case If(cond, then, el): typeStmt(then); if (el != null) typeStmt(el);
			case Return(kw, val):
                if (val != null) {
                    inferredReturnType = typeExpr(val);
                    
                    if (!matchType(inferredReturnType, typedReturnType)) {
                        Cosy.error(kw, 'Function expected to return ${formatType(typedReturnType)} but got ${formatType(inferredReturnType)}');
                    }
                } else {
                    inferredReturnType = Void;
                }
            case Struct(name, declarations): typeStmts(declarations);
		}
	}
	
	function typeExpr(expr:Expr) :VariableType {
		var ret = switch expr {
            case ArrayLiteral(keyword, exprs):
                var arrayType = Unknown;
                for (i in 0...exprs.length) {
                    var elemType = typeExpr(exprs[i]);
                    if (!elemType.match(Unknown)) {
                        if (arrayType.match(Unknown)) {
                            arrayType = elemType;
                        } else if (!matchType(elemType, arrayType)) {
                            Cosy.error(keyword, 'Array values expected to be ${formatType(arrayType)} but got ${formatType(elemType)} at index $i.');
                        }
                    }
                }
                return Array(arrayType);
			case Assign(name, value):
                var assigningType = typeExpr(value);
                var varType = variableTypes.get(name.lexeme);
                if (varType.match(Unknown)) {
                    variableTypes.set(name.lexeme, assigningType);
                } else if (!matchType(varType, assigningType)) {
                    Cosy.error(name, 'Cannot assign ${formatType(assigningType)} to ${formatType(varType)}');
                }
                return assigningType;
			case Variable(name):
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
                var calleeType = typeExpr(callee);
                var type = Unknown;
                switch calleeType {
                    case Function(paramTypes, returnType):
                        type = returnType;
                        var argumentTypes = [ for (arg in arguments) typeExpr(arg) ];
                        if (arguments.length != paramTypes.length) {
                            Cosy.error(paren, 'Expected ${paramTypes.length} argument(s) but got ${arguments.length}.');
                        } else {
                            for (i in 0...paramTypes.length) {
                                if (argumentTypes[i].match(Unknown)) Cosy.warning(paren, 'Argument ${i + 1} has type Unknown.');
                                if (!matchType(argumentTypes[i], paramTypes[i])) {
                                    Cosy.error(paren, 'Expected argument ${i + 1} to be ${formatType(paramTypes[i])} but got ${formatType(argumentTypes[i])}.');
                                }
                            }
                        }
                    case _:
                }
                type;
			case Get(obj, name):
                var objType = typeExpr(obj);
                return switch objType {
                    case Array(t):
                        return switch name.lexeme {
                            case 'length': Number;
                            case 'push': Function([t], Void);
                            case 'concat': Function([Array(t)], Void);
                            case 'pop': Function([], t);
                            case 'get': Function([Number], t);
                            case _: Cosy.error(name, 'Unknown array property or function.'); Void;
                        }
                    case _: Unknown;
                    // case _: Cosy.error(name, 'Attempting to get "${name.lexeme}" from unsupported type.'); Void;
                }
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
        // TODO: Enable as error if strict
        // if (ret.match(Unknown)) {
        //     switch expr {
        //         case Call(callee, paren, arguments): Cosy.warning(paren, '${expr.getName()} has type Unknown');
        //         case _: Cosy.warning(-1, '${expr.getName()} has type Unknown');
        //     }
        // }
        return ret;
    }
    
    function handleFunc(name:Token, params:Array<Param>, body:Array<Stmt>, returnType:Typer.VariableType) :VariableType {
        // TODO: Enable if strict.
        // for (i in 0...params.length) {
        //     if (params[i].type.match(Unknown)) Cosy.warning(params[i].name, 'Parameter has type Unknown');
        // }
        var types = [ for (param in params) param.type ];
        for (param in params) variableTypes.set(param.name.lexeme, param.type); // TODO: These parameter names may be overwritten in later code, and thus be invalid when we enter this function. The solution is probably to have a scope associated with each function or block.

        typedReturnType = returnType;
        inferredReturnType = Void;
        typeStmts(body);
        
        var computedReturnType = switch returnType {
            case Unknown: inferredReturnType;
            case _: returnType;
        }

        if (name != null) variableTypes.set(name.lexeme, Function(types, computedReturnType));
        return Function(types, computedReturnType);
    }

    function matchType(to :VariableType, from :VariableType) :Bool {
        return switch [to, from] {
            case [_, Unknown]: true;
            case [Function(params1, v1), Function(params2, v2)]:
                if (params1.length != params2.length) return false;
                for (param1 in params1) {
                    for (param2 in params2) {
                        if (!matchType(param1, param2)) return false;
                    }
                }
                matchType(v1, v2);
            case [Array(t1), Array(t2)]: matchType(t1, t2);
            case _: to == from;
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
                var funcStr = 'Fn(${paramStr.join(", ")})$returnStr';
                return (returnType.match(Void) ? funcStr : '($funcStr)');
            case Array(t): (t.match(Unknown) ? 'Array' : 'Array(${formatType(t)})');
            case Text: 'Str';
            case Number: 'Num';
            case Boolean: 'Bool';
            case _: '$type';
        }
    }
}
