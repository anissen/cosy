package cosy.phases;

import cosy.VariableType;

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
    var currentFunctionReturnType = new cosy.Stack<ComputedVariableType>();
	
	public function new() {
        variableTypes.set('clock', Function([], Number));
        variableTypes.set('random', Function([], Number));
	}
	
	public inline function type(stmts:Array<Stmt>): Void {
        typeStmts(stmts);
	}

	inline function typeStmts(stmts:Array<Stmt>) {
        for (stmt in stmts) {
            typeStmt(stmt);
        }
	}

    inline function typeExprs(exprs:Array<Expr>) {
        for (expr in exprs) {
            typeExpr(expr);
        }
    }

	function typeStmt(stmt:Stmt) {
		switch stmt {
			case Block(statements): typeStmts(statements);
			case Break(keyword):
			case Continue(keyword):
			case Var(name, type, init, mut, foreign): 
                var computedType = typeVar(name, type, init);
                if (mut) computedType = Mutable(computedType);
                variableTypes.set(name.lexeme, computedType);
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
                    case Array(t) | Mutable(Array(t)): variableTypes.set(name.lexeme, t);
                    case Unknown: variableTypes.set(name.lexeme, Unknown);
                    case _: Cosy.error(name, 'Can only loop over value of type array.');
                }
                typeStmts(body);
            case ForCondition(keyword, cond, body): typeStmts(body);
			case Function(name, params, body, returnType, foreign): handleFunc(name, params, body, returnType, foreign);
			case Expression(e): typeExpr(e);
            case Print(keyword, e): 
                var type = typeExpr(e);
                if (type.match(Void)) Cosy.error(keyword, 'Cannot print values of type void.');
                type;
			case If(keyword, cond, then, el):
                var condType = typeExpr(cond);
                switch condType {
                    case Boolean | Mutable(Boolean):
                    case _: Cosy.error(keyword, 'The condition must evaluate to a be boolean value (instead of ${formatType(condType)}).');
                }
                typeStmt(then);
                if (el != null) typeStmt(el);
			case Return(kw, val):
                if (currentFunctionReturnType.length == 0) return; // Attempting to do a top-level return.
                var functionReturnType = currentFunctionReturnType.peek();
                var annotatedReturnType = functionReturnType.annotated;
                functionReturnType.computed = (val != null ? typeExpr(val) : Void);
                if (!matchType(functionReturnType.computed, annotatedReturnType)) {
                    Cosy.error(kw, 'Function expected to return ${formatType(annotatedReturnType)} but got ${formatType(functionReturnType.computed)}');
                }
            case Struct(name, declarations):
                var structMeta :StructMeta = { members: new Map() };
                var decls :Map<String, VariableType> = new Map();
                for (decl in declarations) {
                    switch decl {
                        case Var(name, type, init, mut, foreign): 
                            structMeta.members.set(name.lexeme, { mutable: mut, initialized: (init != null) });
                            var computedType = typeVar(name, type, init);
                            if (mut) computedType = Mutable(computedType);
                            decls.set(name.lexeme, computedType);
                        case _: throw 'structs can only have var and mut'; // should never happen
                    }
                }
                structsMeta.set(name.lexeme, structMeta);
                variableTypes.set(name.lexeme, Struct(decls));
		}
    }
    
    function typeVar(name: Token, type: VariableType, init: Expr): VariableType {
        var initType = (init != null ? typeExpr(init) : VariableType.Unknown);
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
			case Binary(left, op, right): 
                switch op.type {
                    case Star | Slash | Minus | Percent: Number;
                    case Bang | BangEqual | Equal | EqualEqual | Greater | GreaterEqual | Less | LessEqual: Boolean;
                    case Plus:
                        var leftType = typeExpr(left);
                        var rightType = typeExpr(right);
                        if (leftType.match(Text) || rightType.match(Text)) return Text;
                        if (leftType.match(Number) || rightType.match(Number)) return Number;
                        Unknown;
                    case _: throw 'should never happen';
                }
            case Logical(left, _, right): Boolean;
			case Call(callee, paren, arguments):
                var calleeType = typeExpr(callee);
                calleeType = switch (calleeType) {
                    case Mutable(f): f;
                    case _: calleeType;
                }
                var type = Unknown;
                // trace(callee);
                // trace(calleeType);
                // trace(arguments);
                switch calleeType {
                    case Function(paramTypes, returnType):
                        type = returnType;
                        var argumentTypes = [ for (arg in arguments) typeExpr(arg) ];
                        // trace(paramTypes);
                        // trace(argumentTypes);
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
                    case Unknown: if (Cosy.strict) Cosy.error(paren, '[strict] Undefined type.');
                    case Void: // TODO: what?
                    case Instance: // TODO: remove
                    case _: // TODO: maybe throw 'unexpected';
                }
                type;
			case Get(obj, name):
                var objType = typeExpr(obj);
                return switch objType {
                    case Mutable(Array(t)):
                        return switch name.lexeme {
                            case 'length': Number;
                            case 'push': Function([t], Void);
                            case 'concat': Function([Array(t)], Void);
                            case 'pop': Function([], t);
                            case 'get': Function([Number], t);
                            case 'map': Function([Function([t], Unknown)], Array(Unknown));
                            case 'filter': Function([Function([t], Boolean)], Array(t));
                            case 'count': Function([Function([t], Boolean)], Number);
                            case 'sum': Function([Function([t], Number)], Number);
                            case 'sort': Function([Function([t, t], Number)], Array(t));
                            case _: Cosy.error(name, 'Unknown array property or function.'); Void;
                        }
                    case Array(t):
                        return switch name.lexeme {
                            case 'length': Number;
                            case 'push': Cosy.error(name, 'Cannot call mutating method on immutable array.'); Void;
                            case 'concat': Cosy.error(name, 'Cannot call mutating method on immutable array.'); Void;
                            case 'pop': Cosy.error(name, 'Cannot call mutating method on immutable array.'); Void;
                            case 'get': Function([Number], t);
                            case 'map': Function([Function([t], Unknown)], Array(Unknown));
                            case 'filter': Function([Function([t], Boolean)], Array(t));
                            case 'count': Function([Function([t], Boolean)], Number);
                            case 'sum': Function([Function([t], Number)], Number);
                            case 'sort': Function([Function([t, t], Number)], Array(t));
                            case _: Cosy.error(name, 'Unknown array property or function.'); Void;
                        }
                    case Text | Mutable(Text):
                        return switch name.lexeme {
                            case 'length': Number;
                            case 'split': Function([Text], Array(Text));
                            case 'replace': Function([Text, Text], Text);
                            case 'charAt': Function([Number], Text);
                            case 'substr': Function([Number, Number], Text);
                            case _: Cosy.error(name, 'Unknown array property or function.'); Void;
                        }
                    case NamedStruct(structName) | Mutable(NamedStruct(structName)): 
                        return switch variableTypes.get(structName) {
                            case Struct(structType) | Mutable(Struct(structType)):
                                if (structType.exists(name.lexeme)) {
                                    return structType[name.lexeme];
                                } else {
                                    Cosy.error(name, 'No member named "${name.lexeme}" in struct of type ${formatType(objType, false)}');
                                    return Unknown;
                                }
                            case _: throw 'Get on unknown type ${objType}';
                        }
                    case Struct(structType) | Mutable(Struct(structType)):
                        if (structType.exists(name.lexeme)) {
                            return structType[name.lexeme];
                        } else {
                            Cosy.error(name, 'No member named "${name.lexeme}" in struct of type ${formatType(objType, false)}');
                            return Unknown;
                        }
                    case _: throw 'Get "${name.lexeme}" on unknown type ${objType}';
                    // case _: Cosy.error(name, 'Attempting to get "${name.lexeme}" from unsupported type.'); Void;
                }
            case MutArgument(keyword, name):
                var type = Mutable(variableTypes.get(name.lexeme));
                switch type {
                    // case Mutable(Struct(_)):
                    case Mutable(Mutable(Struct(_))):
                    case _: Cosy.error(name, 'Only mutable structs can be passed as "mut". You passed ${formatType(type, false)}.');
                }
                type;
			case Set(obj, name, value):
                var objType = typeExpr(obj);
                objType = switch objType {
                    case Mutable(NamedStruct(n)) | NamedStruct(n): variableTypes.get(n);
                    case Mutable(Struct(v)): Struct(v);
                    case _: objType; // TODO: throw 'unexpected';
                }
                switch objType {
                    case Struct(v):
                        if (v.exists(name.lexeme)) {
                            var valueType = typeExpr(value);
                            var structDeclType = v[name.lexeme];
                            var nonMutableStructDeclType = switch structDeclType {
                                case Mutable(t): t;
                                case t: t;
                            }
                            if (!structDeclType.match(Mutable(_))) Cosy.error(name, 'Member is not mutable.');
                            else if (!matchType(valueType, nonMutableStructDeclType)) Cosy.error(name, 'Expected value of type ${formatType(nonMutableStructDeclType)} but got ${formatType(valueType)}');
                        } else {
                            Cosy.error(name, 'No member named "${name.lexeme}" in struct of type ${formatType(objType, false)}');
                        }
                    case _: //trace(objType); TODO: throw 'unexpected';
                }
                Unknown; // TODO: What should Set return?
            case Grouping(e): typeExpr(e);
            case Unary(op, e): 
                switch op.type {
                    case Bang: Boolean;
                    case Minus: Number;
                    case _: throw 'should never happen';
                }
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
                            var memberType = switch structMembers[name.lexeme] { // get the non-mutable type version of the struct member (for comparison reasons)
                                case Mutable(t): t;
                                case t: t;
                            }
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
			case AnonFunction(params, body, returnType): handleFunc(null, params, body, returnType, false);
			case Literal(v) if (Std.isOfType(v, Float)): Number;
			case Literal(v) if (Std.isOfType(v, String)): Text;
			case Literal(v) if (Std.isOfType(v, Bool)): Boolean;
			case Literal(v): Unknown;
		}
        if (Cosy.strict && ret.match(Unknown)) {
            switch expr {
                case Call(callee, paren, arguments): Cosy.error(paren, '[strict] ${expr.getName()} has unknown type.');
                case _: Cosy.warning(-1, '[strict] ${expr.getName()} has unknown type.');
            }
        }
        return ret;
    }
    
    function handleFunc(name:Token, params:Array<Param>, body:Array<Stmt>, returnType: ComputedVariableType, foreign: Bool) :VariableType {
        if (Cosy.strict) {
            for (i in 0...params.length) {
                if (params[i].type.match(Unknown)) Cosy.error(params[i].name, '[strict] Parameter has unknown type.');
            }
        }
        var types = [ for (param in params) param.type ];
        for (param in params) variableTypes.set(param.name.lexeme, param.type); // TODO: These parameter names may be overwritten in later code, and thus be invalid when we enter this function. The solution is probably to have a scope associated with each function or block.

        currentFunctionReturnType.push({ annotated: returnType.annotated, computed: Void });
        typeStmts(body);
        var computedReturnType = currentFunctionReturnType.pop().computed;
        
        returnType.computed = switch returnType.annotated {
            case Unknown if (!foreign): computedReturnType;
            case _: returnType.annotated;
        }

        if (name != null) variableTypes.set(name.lexeme, Function(types, returnType.computed));
        return Function(types, returnType.computed);
    }

    function matchType(valueType :VariableType, expectedType :VariableType) :Bool {
        // trace('-----');
        // trace('valueType: $valueType');
        // trace('expectedType: $expectedType');
        return switch [valueType, expectedType] {
            case [_, Unknown]: true;
            case [Unknown, _]: true;
            case [Mutable(t1), Mutable(t2)]: matchType(t1, t2);
            case [NamedStruct(name1), NamedStruct(name2)]: matchType(variableTypes.get(name1), variableTypes.get(name2));
            case [t1, NamedStruct(name)]: matchType(t1, variableTypes.get(name));
            case [Mutable(t1), t2]: matchType(t1, t2);
            case [Function(params1, v1), Function(params2, v2)]:
                if (params1.length != params2.length) return false;
                for (i in 0...params1.length) {
                    if (!matchType(params1[i], params2[i])) return false;
                }
                matchType(v1, v2);
            case [Array(Unknown), Array(_)]: true; // handle case where e.g. var a Array Num = []
            case [Array(t1), Array(t2)]: matchType(t1, t2);
            case [Struct(v1), Struct(v2)]:
                for (key => value in v1) {
                    if (!v2.exists(key) || v2[key] != value) return false;
                }
                for (key => value in v2) {
                    if (!v1.exists(key) || v1[key] != value) return false;
                }
                return true;
            case _: valueType == expectedType;
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
