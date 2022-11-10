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
    var structsMeta: Map<String, StructMeta> = new Map();
    var variableTypes: Map<String, Variable> = new Map();
    var currentFunctionReturnType = new Stack<ComputedVariableType>();
    var strict: Bool;

    final logger: cosy.Logging.Logger;

    public function new(logger: cosy.Logging.Logger) {
        this.logger = logger;

        // variableTypes.set('clock', Function([], Number));
        // variableTypes.set('random', Function([], Number));
    }

    public inline function type(stmts: Array<Stmt>, strict: Bool): Void {
        this.strict = strict;
        typeStmts(stmts);
    }

    inline function typeStmts(stmts: Array<Stmt>) {
        for (stmt in stmts) {
            typeStmt(stmt);
        }
    }

    inline function typeExprs(exprs: Array<Expr>) {
        for (expr in exprs) {
            typeExpr(expr);
        }
    }

    function setVariableType(name: Token, type: VariableType) {
        variableTypes.set(name.lexeme, {
            name: name,
            type: type,
            mut: false,
            foreign: false
        });
    }

    function getVariableType(lexeme: String) {
        return variableTypes.get(lexeme).type;
    }

    function typeStmt(stmt: Stmt) {
        switch stmt {
            case Block(statements): typeStmts(statements);
            case Break(keyword):
            case Continue(keyword):
            case Let(v, init):
                var computedType = typeVar(v.name, v.type, init);
                // if (mut) computedType = Mutable(computedType); // TODO: We need to save the `mut` flag
                variableTypes.set(v.name.lexeme, {
                    name: v.name,
                    type: computedType,
                    mut: v.mut,
                    foreign: v.foreign
                }); // TODO: Should have both annotated and computed types
            case For(keyword, name, from, to, body):
                switch typeExpr(from) {
                    case Unknown: logger.warning(keyword, '"From" clause has type Unknown');
                    case Number:
                    case _: logger.error(keyword, '"From" clause must evaluate to a number');
                }
                switch typeExpr(to) {
                    case Unknown: logger.warning(keyword, '"To" clause has type Unknown');
                    case Number:
                    case _: logger.error(keyword, '"To" clause must evaluate to a number');
                }
                if (name != null) setVariableType(name, Number);
                typeStmts(body);
            case ForArray(name, array, body):
                var arrayType = typeExpr(array);
                switch arrayType {
                    case Array(t): setVariableType(name, t);
                    case Unknown: setVariableType(name, Unknown);
                    case _: logger.error(name, 'Can only loop over value of type array.');
                }
                typeStmts(body);
            case ForCondition(keyword, cond, body): typeStmts(body);
            case Function(name, params, body, returnType, foreign): handleFunc(name, params, body, returnType, foreign);
            case Expression(e): typeExpr(e);
            case Print(keyword, e):
                var type = typeExpr(e);
                if (type.match(Void)) logger.error(keyword, 'Cannot print values of type void.');
                type;
            case If(keyword, cond, then, el):
                var condType = typeExpr(cond);
                switch condType {
                    case Boolean:
                    case _: logger.error(keyword, 'The condition must evaluate to a be boolean value (instead of ${formatType(condType)}).');
                }
                typeStmt(then);
                if (el != null) typeStmt(el);
            case Return(kw, val):
                if (currentFunctionReturnType.length == 0) return; // Attempting to do a top-level return.
                var functionReturnType = currentFunctionReturnType.peek();
                var annotatedReturnType = functionReturnType.annotated;
                functionReturnType.computed = (val != null ? typeExpr(val) : Void);
                if (!matchType(functionReturnType.computed, annotatedReturnType)) {
                    logger.error(kw, 'Function expected to return ${formatType(annotatedReturnType)} but got ${formatType(functionReturnType.computed)}');
                }
                switch functionReturnType.annotated {
                    case NamedStruct(name, mutable):
                        if (mutable) {
                            switch val {
                                case Variable(name): if (!variableTypes.get(name.lexeme)
                                        .mut) logger.error(name, 'Attempting to return immutable value as a mutable value.');
                                case _:
                            }
                        }
                    case _:
                }
            case Struct(name, declarations):
                var structMeta: StructMeta = {members: new Map()};
                var decls: Map<String, Variable> = new Map();
                for (decl in declarations) {
                    switch decl {
                        case Let(v, init):
                            structMeta.members.set(v.name.lexeme, {mutable: v.mut, initialized: (init != null)});
                            var computedType = typeVar(v.name, v.type, init);
                            decls.set(v.name.lexeme, {
                                name: v.name,
                                type: computedType,
                                mut: v.mut,
                                foreign: v.foreign
                            });
                        case _: throw 'structs can only have let and mut'; // should never happen
                    }
                }
                structsMeta.set(name.lexeme, structMeta);
                variableTypes.set(name.lexeme, {
                    name: name,
                    type: Struct(decls),
                    mut: false,
                    foreign: false,
                });
        }
    }

    function typeVar(name: Token, type: VariableType, init: Expr): VariableType {
        var initType = (init != null ? typeExpr(init) : VariableType.Unknown);
        if (initType.match(Void)) logger.error(name, 'Cannot assign Void to a variable');
        if (init != null && !matchType(initType,
            type)) logger.error(name, 'Expected variable to have type ${formatType(type)} but got ${formatType(initType)}.');
        return (!type.match(Unknown) ? type : initType);
    }

    function isMutatable(expr: Expr): Bool {
        return switch expr {
            case Variable(name): variableTypes.get(name.lexeme).mut;
            case Get(obj, name): // isMutatable(obj); // TODO: What about `name`?
                switch typeExpr(obj) {
                    case NamedStruct(structName, mutable): mutable && structsMeta.get(structName).members.get(name.lexeme).mutable;
                    case _: isMutatable(obj);
                }
            case Call(callee, paren, arguments):
                switch typeExpr(callee) {
                    case Function(paramTypes, returnType):
                        switch returnType {
                            case NamedStruct(name, mutable): mutable;
                            case _: false;
                        }
                    case _: false;
                }
            case _: false;
        }
    }

    function typeExpr(expr: Expr): VariableType {
        var ret = switch expr {
            case ArrayLiteral(keyword, exprs):
                var arrayType = Unknown;
                for (i in 0...exprs.length) {
                    var elemType = typeExpr(exprs[i]);
                    if (!elemType.match(Unknown)) {
                        if (arrayType.match(Unknown)) {
                            arrayType = elemType;
                        } else if (!matchType(elemType, arrayType)) {
                            logger.error(keyword, 'Array values expected to be ${formatType(arrayType)} but got ${formatType(elemType)} at index $i.');
                        }
                    }
                }
                return Array(arrayType);
            case Assign(name, op, value):
                final assigningType = typeExpr(value);
                final v = variableTypes.get(name.lexeme);
                final varType = v.type;
                if (varType.match(Unknown)) {
                    v.type = assigningType;
                } else if (!matchType(varType, assigningType)) {
                    logger.error(name, 'Cannot assign ${formatType(assigningType)} to ${formatType(varType, false)}');
                }
                return assigningType;
            case Variable(name):
                if (variableTypes.exists(name.lexeme)) {
                    return getVariableType(name.lexeme);
                } else { // can happen for recursive function calls
                    return Unknown;
                }
            case Binary(left, op, right):
                var leftType = typeExpr(left);
                var rightType = typeExpr(right);
                switch op.type {
                    case Star | Slash | Minus | Percent:
                        if (strict) {
                            var isLeftNumber = leftType.match(Number);
                            if (!isLeftNumber) logger.error(op, 'Left side of "${op.lexeme}" must be a number.');

                            var isRightNumber = rightType.match(Number);
                            if (!isRightNumber) logger.error(op, 'Right side of "${op.lexeme}" must be a number.');
                        }

                        Number;
                    case BangEqual | EqualEqual | Greater | GreaterEqual | Less | LessEqual:
                        // trace(leftType);
                        // trace(rightType);
                        // if (!leftType.equals(rightType)) logger.error(op, 'Both sides of "${op.lexeme}" must have the same type.');
                        Boolean;
                    case Plus:
                        var isLeftNumber = leftType.match(Number);
                        var isRightNumber = rightType.match(Number);
                        if (isLeftNumber && isRightNumber) return Number;

                        var isLeftText = leftType.match(Text);
                        var isRightText = rightType.match(Text);
                        if (isLeftText && isRightText) return Text;

                        var isLeftTyped = !leftType.match(Unknown);
                        var isRightTyped = !rightType.match(Unknown);

                        if (strict) {
                            if (!isLeftTyped) logger.error(op, 'Left side of "+" has unknown type.');
                            if (!isRightTyped) logger.error(op, 'Right side of "+" has unknown type.');
                        }

                        if (isLeftTyped && isRightTyped) {
                            if (isLeftText || isRightText) {
                                logger.error(op, 'Values of type ${formatType(leftType)} and ${formatType(rightType)} cannot be concatinated.');
                                logger.hint(op, "Use string interpolation, e.g. {value}, to add non-string types to a string.");
                            } else if (isLeftNumber || isRightNumber) {
                                logger.error(op, 'Values of types ${formatType(leftType)} and ${formatType(rightType)} cannot be added.');
                            }
                        }

                        Unknown;
                    case _: throw 'should never happen';
                }
            case Logical(left, _, right): Boolean;
            case Call(callee, paren, arguments):
                var calleeType = typeExpr(callee);
                var type = Unknown;
                switch calleeType {
                    case Function(paramTypes, returnType):
                        type = returnType;
                        var argumentTypes = [for (arg in arguments) typeExpr(arg)];
                        if (arguments.length != paramTypes.length) {
                            // var k = new KeywordVisitor();
                            // var keywords = k.getExprKeywords([callee]);
                            // var token = keywords[keywords.length - 1];
                            logger.error(paren, 'Expected ${paramTypes.length} argument(s) but got ${arguments.length}.');
                        } else {
                            for (i in 0...paramTypes.length) {
                                if (strict && argumentTypes[i].match(Unknown)) logger.error(paren, 'Argument ${i + 1} has type Unknown.');
                                if (!matchType(argumentTypes[i], paramTypes[i])) {
                                    logger.error(paren,
                                        'Expected argument ${i + 1} to be ${formatType(paramTypes[i])} but got ${formatType(argumentTypes[i])}.');
                                }
                            }
                        }
                    case Unknown: if (strict) logger.error(paren, '[strict] Undefined type.');
                    case Void: // TODO: what?
                    case Instance: // TODO: remove
                    case _: // TODO: maybe throw 'unexpected';
                }
                type;
            case Get(obj, name):
                // final mut = switch obj {
                //     case Variable(n): variableTypes.get(n.lexeme).mut;
                //     case _: false; // TODO: Return values can never be modified as the logic is now. The issue is that we don't have meta data for the return types of functions like we do for variables.
                // }
                final mut = isMutatable(obj);
                var objType = typeExpr(obj);
                return switch objType {
                    case Array(t):
                        final errorMsg = 'Cannot call mutating method on immutable array.';
                        return switch name.lexeme {
                            case 'length': Number;
                            case 'push':
                                if (!mut) logger.error(name, errorMsg);
                                Function([t], Void);
                            case 'concat':
                                if (!mut) logger.error(name, errorMsg);
                                Function([Array(t)], Void);
                            case 'pop':
                                if (!mut) logger.error(name, errorMsg);
                                Function([], t);
                            case 'map': Function([Function([t], Unknown)], Array(Unknown));
                            case 'filter': Function([Function([t], Boolean)], Array(t));
                            case 'count': Function([Function([t], Boolean)], Number);
                            case 'sum': Function([Function([t], Number)], Number);
                            case 'sort': Function([Function([t, t], Number)], Array(t));
                            case 'reduce': Function([Function([t, t], t), t], t);
                            case 'shift':
                                if (!mut) logger.error(name, errorMsg);
                                Function([], t);
                            case 'join': Function([Text], Text);
                            case 'is_empty': Function([], Boolean);
                            case 'last': Function([], t);
                            case 'contains': Function([t], Boolean);
                            case 'index_of': Function([t], Number);
                            case 'reverse': Function([], Array(t));
                            case _:
                                logger.error(name, 'Unknown array property or function.');
                                Void;
                        }
                    case Text:
                        return switch name.lexeme {
                            case 'length': Number;
                            case 'split': Function([Text], Array(Text));
                            case 'replace': Function([Text, Text], Text);
                            case 'char_at': Function([Number], Text);
                            case 'char_code_at': Function([Number], Number);
                            case 'substr': Function([Number, Number], Text);
                            case _:
                                logger.error(name, 'Unknown text property or function.');
                                Void;
                        }
                    case NamedStruct(structName, mut):
                        return switch getVariableType(structName) {
                            case Struct(structType):
                                if (structType.exists(name.lexeme)) {
                                    return structType[name.lexeme].type;
                                } else {
                                    logger.error(name, 'No member named "${name.lexeme}" in struct of type ${formatType(objType, false)}');
                                    return Unknown;
                                }
                            case _:
                                trace(name);
                                throw 'Get on unknown type ${objType}';
                        }
                    case Struct(structType):
                        if (structType.exists(name.lexeme)) {
                            return structType[name.lexeme].type;
                        } else {
                            logger.error(name, 'No member named "${name.lexeme}" in struct of type ${formatType(objType, false)}');
                            return Unknown;
                        }
                    case Unknown:
                        if (strict) logger.error(name, 'has unknown type.');
                        Unknown;
                    case _:
                        trace(name);
                        throw 'Get "${name.lexeme}" on unknown type ${objType}';
                        // case _: logger.error(name, 'Attempting to get "${name.lexeme}" from unsupported type.'); Void;
                }
            case GetIndex(obj, ranged, from, to):
                var objType = typeExpr(obj);
                if (!ranged) {
                    return switch objType {
                        case Array(t): t;
                        case Text: Text;
                        case _: throw 'Get index of unknown type ${objType} with index $from';
                    }
                } else {
                    return switch objType {
                        case Array(t): Array(t);
                        case Text: Text;
                        case _: throw 'Get index of unknown type ${objType} with start index $from and end index $to';
                    }
                }
            case MutArgument(keyword, name):
                // TODO: Handle this
                var v = variableTypes.get(name.lexeme);
                if (!v.mut) logger.error(name, 'Only mutable structs and arrays can be passed as "mut". You passed ${formatType(v.type, false)}.');
                v.type;
            case Set(obj, name, op, value):
                var objType = typeExpr(obj);
                objType = switch objType {
                    case NamedStruct(n, mut): getVariableType(n);
                    case _: objType; // TODO: throw 'unexpected';
                }
                switch objType {
                    case Struct(v):
                        if (v.exists(name.lexeme)) {
                            var valueType = typeExpr(value);
                            var structDeclType = v[name.lexeme];
                            if (!structDeclType.mut) logger.error(name, 'Member is not mutable.');
                            else if (!matchType(valueType, structDeclType.type))
                                logger.error(name, 'Expected value of type ${formatType(structDeclType.type)} but got ${formatType(valueType)}');
                        } else {
                            logger.error(name, 'No member named "${name.lexeme}" in struct of type ${formatType(objType, false)}');
                        }
                    case _: // trace(objType); TODO: throw 'unexpected';
                }
                typeExpr(value);
            case SetIndex(obj, ranged, from, to, op, value):
                var objType = typeExpr(obj);
                final mut = switch obj {
                    case Variable(name): variableTypes.get(name.lexeme).mut;
                    case _: true;
                }
                // if (op.type == TokenType.PlusEqual) {
                //     // TODO: check that array is of number type
                // } else {
                switch objType {
                    case Array(t):
                        if (!mut) logger.error(op, 'Cannot set value on immutable array.');
                        final type = (ranged ? Array(t) : t);
                        var valueType = typeExpr(value);
                        switch op.type {
                            case Equal:
                                if (!matchType(valueType, type)) logger.error(op, 'Cannot assign ${formatType(valueType)} to ${formatType(type)}');
                            case PlusEqual | MinusEqual | StarEqual | SlashEqual | PercentEqual | EqualEqual | BangEqual: if (!matchType(valueType,
                                    t)) logger.error(op, 'Expected value of type ${formatType(t)} but got ${formatType(valueType)}');
                            case _: logger.error(op, 'Unsupported operator ${op.type} for set index.');
                        }
                    case _: logger.error(op, 'Can only set index on array (not on type ${formatType(objType, false)}).');
                }
                // }
                typeExpr(value);
            case StringInterpolation(exprs): Text; // TODO: Is this good enough?
            case Grouping(e): typeExpr(e);
            case Unary(op, e):
                final exprType = typeExpr(e);
                switch op.type {
                    case Bang:
                        if (strict && !exprType.match(Boolean)) logger.error(op, '"!" expects a boolean type');
                        Boolean;
                    case Minus:
                        if (strict && !exprType.match(Number)) logger.error(op, '"-" expects a number type');
                        Number;
                    case _: throw 'should never happen';
                }
            case StructInit(structName, decls):
                var structType = variableTypes.get(structName.lexeme);
                var assignedMembers = [];
                var structMembers = switch structType.type {
                    case Struct(variables): variables;
                    case _: throw 'unexpected';
                }

                for (decl in decls) {
                    switch decl {
                        case Assign(name, op, value):
                            // TODO: These tests should be done in Resolver instead
                            if (!structMembers.exists(name.lexeme)) {
                                logger.error(name, 'No member named "${name.lexeme}" in struct ${structName.lexeme}');
                                break;
                            } else if (assignedMembers.indexOf(name.lexeme) != -1) {
                                logger.error(name, 'Member already assigned in initializer.');
                                break;
                            }
                            var valueType = typeExpr(value);
                            var memberType = structMembers[name.lexeme];
                            assignedMembers.push(name.lexeme);
                            if (!matchType(valueType,
                                memberType.type)) logger.error(name,
                                    'Expected value to be of type ${formatType(memberType.type)} but got ${formatType(valueType)}');
                        case _: throw 'unexpected';
                    }
                }
                for (memberName => memberMeta in structsMeta[structName.lexeme].members) {
                    if (!memberMeta.initialized) {
                        if (assignedMembers.indexOf(memberName) == -1) logger.error(structName, 'Member "$memberName" not initialized.');
                    }
                }
                structType.type;
            case AnonFunction(params, body, returnType): handleFunc(null, params, body, returnType, false);
            case Literal(v) if (Std.isOfType(v, Float)): Number;
            case Literal(v) if (Std.isOfType(v, String)): Text;
            case Literal(v) if (Std.isOfType(v, Bool)): Boolean;
            case Literal(v): Unknown;
        }
        if (strict && ret.match(Unknown)) {
            switch expr {
                case Call(callee, paren, arguments): logger.error(paren, '[strict] ${expr.getName()} has unknown type.');
                case _: logger.warning(-1, '[strict] ${expr.getName()} has unknown type.');
            }
        }
        return ret;
    }

    function handleFunc(name: Token, params: Array<Param>, body: Array<Stmt>, returnType: ComputedVariableType, foreign: Bool): VariableType {
        if (strict) {
            for (i in 0...params.length) {
                if (params[i].type.match(Unknown)) logger.error(params[i].name, '[strict] Parameter has unknown type.');
            }
        }
        for (param in params) {
            variableTypes.set(param.name.lexeme,
                {
                    name: param.name,
                    type: param.type,
                    mut: param.mut,
                    foreign: false,
                }); // TODO: These parameter names may be overwritten in later code, and thus be invalid when we enter this function. The solution is probably to have a scope associated with each function or block.
        }
        currentFunctionReturnType.push({annotated: returnType.annotated, computed: Void});
        typeStmts(body);
        var computedReturnType = currentFunctionReturnType.pop().computed;

        returnType.computed = switch returnType.annotated {
            case Unknown if (!foreign): computedReturnType;
            case _: returnType.annotated;
        }
        var types = [for (param in params) param.type];
        if (name != null) setVariableType(name, Function(types, returnType.computed));
        return Function(types, returnType.computed);
    }

    function matchType(valueType: VariableType, expectedType: VariableType): Bool {
        // trace('-----');
        // trace('valueType: $valueType');
        // trace('expectedType: $expectedType');
        return switch [valueType, expectedType] {
            case [_, Unknown]: true;
            case [Unknown, _]: true;
            // case [Mutable(t1), Mutable(t2)]: matchType(t1, t2); // TODO: Probably handle this!
            case [NamedStruct(name1, mut1), NamedStruct(name2, mut2)]: mut1 == mut2 && matchType(getVariableType(name1), getVariableType(name2));
            case [NamedStruct(name1, mut), t2]: matchType(getVariableType(name1), t2);
            case [t1, NamedStruct(name, mut)]: matchType(t1, getVariableType(name));
            // case [Mutable(t1), t2]: matchType(t1, t2); // TODO: Probably handle this!
            case [Function(params1, v1), Function(params2, v2)]:
                if (params1.length != params2.length) return false;
                for (i in 0...params1.length) {
                    if (!matchType(params1[i], params2[i])) return false;
                }
                matchType(v1, v2);
            case [Array(Unknown), Array(_)]: true; // handle case where e.g. let a Array Num = []
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

    function formatType(type: VariableType, showMutable: Bool = true): String {
        return switch type {
            case Function(paramTypes, returnType):
                var paramStr = [for (paramType in paramTypes) formatType(paramType)];
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
            // case Mutable(t): showMutable ? 'Mut(${formatType(t)})' : formatType(t);
            case NamedStruct(name, mut): (mut ? 'mut ' : '') + formatType(getVariableType(name));
            case Struct(decls):
                var declsStr = [for (name => type in decls) '$name ${formatType(type.type)}'];
                declsStr.sort(function(a, b) {
                    if (a < b) return -1;
                    if (b < a) return 1;
                    return 0;
                });
                'Struct { ${declsStr.join(", ")} }';
            case _: '$type';
        }
    }
}
