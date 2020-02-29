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
    Struct(variables:Map<String, VariableType>);
    NamedStruct(name:String);
    Mutable(type:VariableType);
}

typedef VariableMeta = {
    var mutable: Bool;
    var initialized: Bool;
}

typedef StructMeta = {
    var members: Map<String, VariableMeta>;
}

class Typer {
    var structsMeta :Map<String, StructMeta> = new Map();
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
			case Break(keyword):
			case Continue(keyword):
			case Class(name, superclass, methods): typeStmts(methods);
			case Var(name, type, init): variableTypes.set(name.lexeme, typeVar(name, type, init));
            case Mut(name, type, init): variableTypes.set(name.lexeme, Mutable(typeVar(name, type, init)));
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
                if (name != null) variableTypes.set(name.lexeme, Number);
                typeStmts(body);
            case ForArray(name, array, body):
                var arrayType = typeExpr(array);
                switch arrayType {
                    case Array(t): variableTypes.set(name.lexeme, t);
                    case Unknown: variableTypes.set(name.lexeme, Unknown);
                    case _: Cosy.error(name, 'Can only loop over value of type array.');
                }
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
            case Struct(name, declarations):
                var structMeta :StructMeta = { members: new Map() };
                var decls :Map<String, VariableType> = new Map();
                for (decl in declarations) {
                    switch decl {
                        case Var(name, type, init): 
                            structMeta.members.set(name.lexeme, { mutable: false, initialized: (init != null) });
                            decls.set(name.lexeme, typeVar(name, type, init));
                        case Mut(name, type, init):
                            structMeta.members.set(name.lexeme, { mutable: true, initialized: (init != null) });
                            decls.set(name.lexeme, Mutable(typeVar(name, type, init)));
                        case _: throw 'structs can only have var and mut'; // should never happen
                    }
                }
                structsMeta.set(name.lexeme, structMeta);
                variableTypes.set(name.lexeme, Struct(decls));
		}
    }
    
    function typeVar(name: Token, type: VariableType, init: Expr) :VariableType {
        var initType = (init != null ? typeExpr(init) : Unknown);
        if (initType.match(Void)) Cosy.error(name, 'Cannot assign Void to a variable');
        if (init != null && !matchType(initType, type)) Cosy.error(name, 'Expected variable to have type ${formatType(type)} but got ${formatType(initType)}.');
        return (!type.match(Unknown) ? type : initType);
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
			case Assign(name, op, value):
                var assigningType = typeExpr(value);
                var varType = variableTypes.get(name.lexeme);
                if (varType.match(Unknown) || varType.match(Mutable(Unknown))) {
                    variableTypes.set(name.lexeme, assigningType);
                } else if (!matchType(varType, assigningType)) {
                    Cosy.error(name, 'Cannot assign ${formatType(assigningType)} to ${formatType(varType, false)}');
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
                calleeType = switch (calleeType) {
                    case Mutable(f): f;
                    case _: calleeType;
                }
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
                    case Unknown: // TODO: should error in strict
                    case Instance: // TODO: remove
                    case _: throw 'unexpected';
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
                        // case Struct(_): Struct;
                    case _: Unknown;
                    // case _: Cosy.error(name, 'Attempting to get "${name.lexeme}" from unsupported type.'); Void;
                }
			case Set(obj, name, value):
                var objType = typeExpr(obj);
                switch objType {
                    case Mutable(Struct(v)) | Struct(v):
                        if (v.exists(name.lexeme)) {
                            var valueType = typeExpr(value);
                            var structDeclType = v[name.lexeme];
                            if (!structDeclType.match(Mutable(_))) Cosy.error(name, 'Member is not mutable.');
                            else if (!matchType(structDeclType, valueType)) Cosy.error(name, 'Expected value of type ${formatType(structDeclType)} but got ${formatType(valueType)}');
                        } else {
                            Cosy.error(name, 'No member named "${name.lexeme}" in struct of type ${formatType(objType, false)}');
                        }
                    case _:
                }
                Unknown; // TODO: What should Set return?
			case Grouping(e) | Unary(_, e): typeExpr(e);
            case Super(kw, method): Instance;
            case StructInit(structName, decls):
                var structType = variableTypes.get(structName.lexeme);
                var assignedMembers = [];
                var structMembers = switch structType {
                    case Struct(variables): variables;
                    case _: throw 'unexpected';
                }
                
                for (decl in decls) {
                    switch decl {
                        case Assign(name, op, value):
                            // TODO: These tests should be done in Resolver instead
                            if (!structMembers.exists(name.lexeme)) {
                                Cosy.error(name, 'No member named "${name.lexeme}" in struct ${structName.lexeme}');
                                break;
                            } else if (assignedMembers.indexOf(name.lexeme) != -1) {
                                Cosy.error(name, 'Member already assigned in initializer.');
                                break;
                            }
                            var valueType = typeExpr(value);
                            var memberType = structMembers[name.lexeme];
                            assignedMembers.push(name.lexeme);
                            if (!matchType(valueType, memberType)) Cosy.error(name, 'Expected value to be of type ${formatType(memberType)} but got ${formatType(valueType)}');
                        case _: throw 'unexpected';
                    }
                }
                for (memberName => memberMeta in structsMeta[structName.lexeme].members) {
                    if (!memberMeta.initialized) {
                        if (assignedMembers.indexOf(memberName) == -1) Cosy.error(structName, 'Member "$memberName" not initialized.');
                    }
                }
                structType;
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
            case [Mutable(t1), t2]: matchType(t1, t2);
            case [t1, Mutable(t2)]: matchType(t1, t2);
            case [_, Unknown]: true;
            case [Function(params1, v1), Function(params2, v2)]:
                if (params1.length != params2.length) return false;
                for (param1 in params1) {
                    for (param2 in params2) {
                        if (!matchType(param1, param2)) return false;
                    }
                }
                matchType(v1, v2);
            case [Array(Unknown), Array(_)]: true; // handle case where e.g. var a Array Num = []
            case [Array(t1), Array(t2)]: matchType(t1, t2);
            case [t1, NamedStruct(name)]: matchType(t1, variableTypes.get(name));
            case [Struct(v1), Struct(v2)]:
                for (key => value in v1) {
                    if (!v2.exists(key) || v2[key] != value) return false;
                }
                for (key => value in v2) {
                    if (!v1.exists(key) || v1[key] != value) return false;
                }
                return true;
            case _: to == from;
        }
    }

    function formatType(type: VariableType, showMutable: Bool = true) :String {
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
            case Mutable(t): showMutable ? 'Mut(${formatType(t)})' : formatType(t);
            case NamedStruct(name): formatType(variableTypes.get(name));
            case Struct(decls): 
                var declsStr = [ for (name => type in decls) '$name ${formatType(type)}' ];
                declsStr.sort(function (a, b) {
                    if (a < b) return -1;
                    if (b < a) return 1;
                    return 0;
                });
                'Struct { ${declsStr.join(", ")} }';
            case _: '$type';
        }
    }
}
