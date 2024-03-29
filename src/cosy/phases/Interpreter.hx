package cosy.phases;

import haxe.CallStack;

class Interpreter {
    final globals: Environment;
    final locals = new Locals();

    var environment: Environment;

    var compiler: Compiler = null;
    var logger: cosy.Logging.Logger = null;
    var hotReload = false;

    static final uninitialized: Any = {};

    public function new() {
        globals = new Environment();
        environment = globals;
    }

    public function run(statements: Array<Stmt>, compiler: Compiler, hotReload: Bool) {
        this.compiler = compiler;
        this.logger = compiler.logger;
        this.hotReload = hotReload;
        interpret(statements);
    }

    function interpret(statements: Array<Stmt>) {
        try {
            for (statement in statements) {
                execute(statement);
            }
        } catch (e: RuntimeError) {
            logger.runtimeError(e);
        } catch (e: haxe.Exception) {
            // logger.runtimeError(new RuntimeError(null, e.toString()));
            trace(e.stack);
            throw e;
        }
    }

    public function runFunction(name: String, args: Array<Any>) {
        final func: Callable = environment.getAt(0, name); // globals.getAt(0, name);
        // trace('runFunction: $func');
        if (func != null) {
            // trace('before');
            func.call(this, args);
            // trace('after');
        }
    }

    public function setForeignVariable(name: String, value: Any) {
        // globals.setAt(0, name, value);
        environment.define(name, value);
    }

    function execute(statement: Stmt) {
        switch statement {
            case Block(statements): executeBlock(statements, new Environment(environment));
            case Break(keyword): throw new Break();
            case Continue(keyword): throw new Continue();
            case Expression(e): evaluate(e);
            case For(keyword, name, from, to, body):
                final fromVal = evaluate(from);
                if (!Std.isOfType(fromVal, Float)) logger.error(keyword, 'Number expected in "from" clause of loop.');
                final toVal = evaluate(to);
                if (!Std.isOfType(toVal, Float)) logger.error(keyword, 'Number expected in "to" clause of loop.');
                var env = new Environment(environment);
                try {
                    final step = ((fromVal: Int) < (toVal: Int)) ? 1 : -1;
                    var counter: Int = fromVal;
                    while (counter != toVal) {
                        if (name != null) env.define(name.lexeme, counter);
                        try {
                            executeBlock(body, env); // TODO: Is it required to create a new environment if name is null?
                        } catch (err: Continue) {
                            // do nothing
                        }
                        counter += step;
                    }
                } catch (err: Break) {
                    // do nothing
                }
            case ForArray(name, mut, array, body):
                final arr: Array<Any> = evaluate(array); // TODO: Implicit cast to array :(
                final env = new Environment(environment);
                try {
                    for (elem in arr) {
                        env.define(name.lexeme, elem);
                        try {
                            executeBlock(body, env);
                        } catch (err: Continue) {
                            // do nothing
                        }
                    }
                } catch (err: Break) {
                    // do nothing
                }
            case ForCondition(keyword, cond, body):
                final env = new Environment(environment);
                try {
                    while (cond != null ? isTruthy(evaluate(cond)) : true) {
                        try {
                            executeBlock(body, env);
                        } catch (err: Continue) {
                            // do nothing
                        }
                    }
                } catch (err: Break) {
                    // do nothing
                }
            case Function(name, params, body, returnType, foreign):
                if (foreign) {
                    environment.define(name.lexeme, compiler.foreignFunctions[name.lexeme]);
                    return;
                }

                environment.define(name.lexeme, new Function(name, params, body, environment, false, logger));
            case If(keyword, cond, then, el): if (isTruthy(evaluate(cond))) execute(then);
                else if (el != null) execute(el);
            case Print(keyword, e): Logging.println(stringify(evaluate(e)));
            case Return(keyword, value):
                var value = if (value == null) null else evaluate(value);
                throw new Return(value);
            case Struct(name, declarations):
                environment.define(name.lexeme, null);
                final previousEnv = environment;
                environment = new Environment(environment);
                final fields: Map<String, Any> = new Map();
                for (decl in declarations)
                    switch decl {
                        case Let(v, init): fields.set(v.name.lexeme, init != null ? evaluate(init) : null);
                        case _: // should never happen
                    }
                environment = previousEnv;
                final struct = new StructInstance(name, fields, logger);
                environment.assign(name, struct);
            case Let(v, init):
                if (v.foreign) {
                    environment.define(v.name.lexeme, compiler.foreignVariables[v.name.lexeme]);
                    return;
                }

                var value: Any = uninitialized;
                if (init != null) value = evaluate(init);
                // Uncomment this if you want structs to be be passed by value instead of by reference
                // if (Std.isOfType(value, StructInstance)) {
                //     value = (value: StructInstance).clone();
                // }
                if (!hotReload) {
                    environment.define(v.name.lexeme, value);
                } else {
                    // Hack for hot reload to disregard already setup variables
                    if (init != null) environment.define(v.name.lexeme, value);
                }
        }
    }

    public function resolve(expr: Expr, depth: Int) {
        locals.set(expr, depth);
    }

    public function executeBlock(statements: Array<Stmt>, env: Environment) {
        final previous = environment;
        try {
            environment = env;
            for (statement in statements)
                execute(statement);
            environment = previous; // emulates "finally" statement
        } catch (e: Any) {
            environment = previous; // emulates "finally" statement
            throw e;
        }
    }

    function plusEqual(left: Any, op: Token, right: Any): Any {
        return if (Std.isOfType(left, Float) && Std.isOfType(right, Float)) (left: Float) + (right: Float);
            // else if (Std.isOfType(left, Float) && Std.isOfType(right, String))
            //     (left:Float) + (right:String);
            // else if (Std.isOfType(left, String) && Std.isOfType(right, Float))
        //     (left:String) + (right:Float);
        else if (Std.isOfType(left, String) && Std.isOfType(right, String)) (left: String) + (right: String);
            // else if (Std.isOfType(left, Bool) && Std.isOfType(right, String))
            //     (left:String) + (right:String);
            // else if (Std.isOfType(left, String) && Std.isOfType(right, Bool))
            //     (left:String) + (right:String);
            // else if (Std.isOfType(left, String) && Std.isOfType(right, Array))
            //     (left:String) + (right:String);
            // else if (Std.isOfType(left, Array) && Std.isOfType(right, String))
        //     (left:String) + (right:String);
        else throw new RuntimeError(op, 'Operands ${getPrintableValue(left)} and ${getPrintableValue(right)} cannot be concatenated.');
    }

    function getPrintableValue(value: Any): Any {
        if (Std.isOfType(value, String)) return '"$value"';
        return value;
    }

    function resultingValue(left: Any, op: Token, right: Any): Any {
        return switch op.type {
            case Equal: right;
            case PlusEqual: plusEqual(left, op, right);
            case MinusEqual:
                checkNumberOperands(op, left, right);
                (left: Float) - (right: Float);
            case SlashEqual:
                checkNumberOperands(op, left, right);
                (left: Float) / (right: Float);
            case StarEqual:
                checkNumberOperands(op, left, right);
                (left: Float) * (right: Float);
            case PercentEqual:
                checkNumberOperands(op, left, right);
                (left: Float) % (right: Float);
            case _: throw 'error';
        }
    }

    @SuppressWarnings('checkstyle:CyclomaticComplexity', 'checkstyle:NestedControlFlow', 'checkstyle:MethodLength')
    function evaluate(expr: Expr): Any {
        return switch expr {
            case ArrayLiteral(keyword, exprs):
                [for (expr in exprs) evaluate(expr)];
            case Assign(name, op, value):
                var right = evaluate(value);
                var value: Any = switch op.type {
                    case Equal: right;
                    case _:
                        var left = lookUpVariable(name, expr);
                        resultingValue(left, op, right);
                }
                switch locals.get(expr) {
                    case null: globals.assign(name, value);
                    case distance: environment.assignAt(distance, name, value);
                }
                value;
            case Literal(v):
                v;
            case Logical(left, op, right):
                final left = evaluate(left);
                switch op.type {
                    case Or if (isTruthy(left)): left;
                    case And if (!isTruthy(left)): left;
                    case _: evaluate(right);
                }
            case Unary(op, right):
                final right = evaluate(right);
                switch op.type {
                    case Bang: !isTruthy(right);
                    case Minus:
                        checkNumberOperand(op, right);
                        - (right: Float);
                    case _: null; // unreachable
                }
            case Binary(left, op, right):
                final left: Any = evaluate(left);
                final right: Any = evaluate(right);

                switch op.type {
                    case Minus:
                        checkNumberOperands(op, left, right);
                        (left: Float) - (right: Float);
                    case Slash:
                        checkNumberOperands(op, left, right);
                        (left: Float) / (right: Float);
                    case Star:
                        checkNumberOperands(op, left, right);
                        (left: Float) * (right: Float);
                    case Plus:
                        plusEqual(left, op, right);
                    case Percent:
                        checkNumberOperands(op, left, right);
                        (left: Float) % (right: Float);
                    case Greater:
                        checkNumberOperands(op, left, right);
                        (left: Float) > (right: Float);
                    case GreaterEqual:
                        checkNumberOperands(op, left, right);
                        (left: Float) >= (right: Float);
                    case Less:
                        checkNumberOperands(op, left, right);
                        (left: Float) < (right: Float);
                    case LessEqual:
                        checkNumberOperands(op, left, right);
                        (left: Float) <= (right: Float);
                    case BangEqual: !isEqual(left, right);
                    case EqualEqual: isEqual(left, right);
                    case _: throw 'Binary op type "${op.type}" is unhandled!'; // unreachable
                }
            case Call(callee, paren, args):
                final callee = evaluate(callee);
                final args = args.map(evaluate);
                if (!Std.isOfType(callee, Callable)) {
                    throw new RuntimeError(paren, 'Can only call functions.');
                } else {
                    final func: Callable = callee;
                    if (!Std.isOfType(func, Compiler.ForeignFunction)) {
                        final arity = func.arity();
                        if (args.length != arity) throw new RuntimeError(paren, 'Expected $arity argument(s) but got ${args.length}.');
                    }
                    func.call(this, args);
                }
            case Get(obj, name):
                final obj = evaluate(obj);

                if (Std.isOfType(obj,
                    Array)) return arrayGet(obj,
                        name); else if (Std.isOfType(obj,
                    StructInstance)) (obj: StructInstance).get(name); else if (Std.isOfType(obj,
                    String)) return stringGet(obj, name); else throw new RuntimeError(name, 'Only instances have properties');
            case GetIndex(obj, ranged, from, to):
                // var a = new AstPrinter();
                // trace(a.printExpr(obj));
                // var k = new KeywordVisitor();
                // trace(k.getExprKeywords([obj]));
                final obj = evaluate(obj);
                final from = (from != null ? evaluate(from) : null);
                final to = (to != null ? evaluate(to) : null);
                // trace('obj:');
                // trace(obj);

                if (Std.isOfType(obj, Array)) {
                    final arr: Array<Any> = obj;
                    return switch getIndexRange(ranged, from, to, arr.length) {
                        case Single(index): arr[index];
                        case Range(fromIndex, toIndex, reversed):
                            var result = arr.slice(fromIndex, toIndex);
                            if (reversed) result.reverse();
                            return result;
                    }
                } else if (Std.isOfType(obj, String)) {
                    final str: String = obj;
                    return switch getIndexRange(ranged, from, to, str.length) {
                        case Single(index): str.charAt(index);
                        case Range(fromIndex, toIndex, reversed):
                            var result = str.substring(fromIndex, toIndex);
                            if (!reversed) return result;
                            var reversedStr = '';
                            for (i in 0...result.length) {
                                reversedStr += result.charAt(result.length - i - 1);
                            }
                            return reversedStr;
                    }
                }
                throw 'Bracket operator can only be used on arrays and strings.'; // TODO: Use RuntimeError with keyword
            case Set(obj, name, op, value):
                final obj = evaluate(obj);
                if (Std.isOfType(obj, StructInstance)) {
                    final instance: StructInstance = obj;
                    final value = evaluate(value);
                    instance.set(name, resultingValue(instance.get(name), op, value));
                } else throw new RuntimeError(name, 'Only instances have fields');
                value;
            case SetIndex(obj, ranged, from, to, op, value):
                final obj = evaluate(obj);
                final fromValue = evaluate(from);
                final toValue = (to != null ? evaluate(to) : null);

                if (Std.isOfType(obj, Array)) {
                    final value = evaluate(value);
                    final valueArr: Array<Any> = value;
                    final arr: Array<Any> = obj;
                    return switch getIndexRange(ranged, fromValue, toValue, arr.length) {
                        case Single(index):
                            arr[index] = resultingValue(arr[index], op, value); // TODO: Check that the types match
                        case Range(fromIndex, toIndex, reversed):
                            // TODO: Handle the case where x[y..z] = [1,2,3] and z - y != 3
                            // TODO: Handle the case where x[y..z] += 3
                            // TODO: Handle the case where x[z..y] = ...
                            // TODO: Handle the case where x[y..y] = ...
                            // TODO: Handle newLength < arr.length
                            // TODO: What about reversed?
                            // e.g. [2,3,4,5,6,7][2..5] = [8,9] => [2,3,8,9,7]
                            switch op.type {
                                case Equal:
                                    if (!Std.isOfType(value, Array)) throw new RuntimeError(op, 'Can only assign array to array.');

                                    final newLength = fromIndex + valueArr.length + (arr.length - toIndex);
                                    if (newLength > arr.length) {
                                        final lengthDiff = (newLength - arr.length);
                                        arr.resize(newLength);
                                        for (i in 0...lengthDiff) {
                                            arr[arr.length - lengthDiff + i] = arr[toIndex + i];
                                        }
                                        for (i => v in valueArr) {
                                            arr[fromIndex + i] = v;
                                        }
                                    } else {
                                        // e.g. [2,3,4,5,6,7][1..5] = [8] => [2,8,7]
                                        for (i => v in valueArr) {
                                            arr[fromIndex + i] = v;
                                        }
                                        arr.splice(fromIndex + valueArr.length, toIndex - fromIndex - valueArr.length);
                                    }
                                    return arr;
                                case _:
                                    // TODO: Check that the types match
                                    for (i in fromIndex...toIndex) {
                                        arr[i] = resultingValue(arr[i], op, value);
                                    }
                                    return arr;
                            }
                    }
                } else throw new RuntimeError(op, 'Bracket notion is only allowed on arrays');
            case StringInterpolation(exprs): [for (e in exprs) stringify(evaluate(e))].join('');
            case Grouping(e): evaluate(e);
            case MutArgument(keyword, name): lookUpVariable(name, expr);
            case Variable(name): lookUpVariable(name, expr);
            case StructInit(name, decls):
                var structObj: StructInstance = lookUpVariable(name, expr);
                if (!Std.isOfType(structObj, StructInstance)) throw new RuntimeError(name, 'Struct initializer on non-struct object.');
                structObj = structObj.clone();
                for (decl in decls) {
                    switch decl {
                        case Assign(variableName, op, value): structObj.set(variableName, evaluate(value));
                        case _: // unreachable
                    }
                }
                structObj;
            case AnonFunction(params, body, returnType): new Function(null, params, body, environment, false, logger);
        }
    }

    function arrayGet(array: Array<Any>, name: Token): Any {
        // TODO: This functions should (together with the Array functionality in Typer) be moved out into its own class, like Klass.
        // TODO: Argument types must match! Change arity to array of types, e.g. 'get' has Number
        return switch name.lexeme {
            case 'length': array.length;
            case 'push': new CustomCallable(1, (args->args.map(array.push)));
            case 'concat': new CustomCallable(1, (args -> (args[0]: Array<Any>).map(array.push)));
            case 'contains': new CustomCallable(1, (args -> array.indexOf(args[0]) != -1));
            case 'index_of': new CustomCallable(1, args -> array.indexOf(args[0]));
            case 'pop': new CustomCallable(0, (_ -> (array.length == 0?throw new RuntimeError(name, 'Cannot pop from empty array.'): array.pop())));
            case 'shift': new CustomCallable(0, (_ -> (array.length == 0?throw new RuntimeError(name, 'Cannot shift from empty array.'): array.shift())));
            case 'join': new CustomCallable(1, (args -> array.join(args[0])));
            case 'is_empty': new CustomCallable(0, _ -> array.length == 0);
            case 'last': new CustomCallable(0, _ -> array[array.length - 1]);
            case 'reverse': new CustomCallable(0, _ -> {
                    final tmp = array.copy();
                    tmp.reverse();
                    return tmp;
                });
            case 'remove': new CustomCallable(1,
                    (args -> (array.length == 0?throw new RuntimeError(name, 'Cannot remove from empty array.'): array.splice(args[0], 1))));
            case 'map': new CustomCallable(1, function(args) {
                    var arg: Callable = args[0];
                    return [for (v in array) arg.call(this, [v])];
                });
            case 'filter': new CustomCallable(1, (args) -> {
                    var arg: Callable = args[0];
                    var res = [];
                    for (v in array) {
                        var r = arg.call(this, [v]);
                        if (r) res.push(v);
                    }
                    return res;
                });
            case 'count': new CustomCallable(1, (args) -> {
                    var sum = 0;
                    final arg: Callable = args[0];
                    for (v in array) {
                        var r = arg.call(this, [v]);
                        if (r) sum++;
                    }
                    return sum;
                });
            case 'sum': new CustomCallable(1, (args) -> {
                    var sum = 0;
                    final arg: Callable = args[0];
                    for (v in array) {
                        var r: Int = arg.call(this, [v]);
                        sum += r;
                    }
                    return sum;
                });
            case 'sort': new CustomCallable(1, (args) -> {
                    var f: Callable = args[0];
                    var array_copy = array;
                    array_copy.sort((a, b) -> f.call(this, [a, b]));
                    return array_copy;
                });
            case 'reduce': new CustomCallable(2, (args) -> {
                    final f: Callable = args[0];
                    final first: Any = args[1];
                    var acc = first;
                    for (v in array) {
                        acc = f.call(this, [acc, v]);
                    }
                    return acc;
                });
            case _: throw new RuntimeError(name, 'Undefined method "${name.lexeme}".');
        }
    }

    function stringGet(string: String, name: Token): Any {
        return switch name.lexeme {
            case 'length': string.length;
            case 'split': new CustomCallable(1, (args -> string.split(args[0])));
            case 'replace': new CustomCallable(2, (args -> string.replace(args[0], args[1])));
            case 'char_at': new CustomCallable(1, (args -> string.charAt(args[0])));
            case 'char_code_at': new CustomCallable(1, (args -> string.charCodeAt(args[0])));
            case 'substr': new CustomCallable(2, (args -> string.substr(Std.int(args[0]), Std.int(args[1]))));
            case _: throw new RuntimeError(name, 'Undefined method "${name.lexeme}".');
        }
    }

    function lookUpVariable(name: Token, expr: Expr): Any {
        final value = switch locals.get(expr) {
            case null: globals.get(name);
            case distance: environment.getAt(distance, name.lexeme);
        }
        if (value == uninitialized) throw new RuntimeError(name, 'Accessing uninitialized variable "${name.lexeme}".');
        return value;
    }

    inline function isTruthy(v: Any): Bool {
        if (v == null) return false;
        if (Std.isOfType(v, Bool)) return v;
        return true;
    }

    function isEqual(a: Any, b: Any): Bool {
        if (Std.isOfType(a, Array) && Std.isOfType(b, Array)) { // deep equals for arrays
            var a_array = (a: Array<Any>);
            var b_array = (b: Array<Any>);
            if (a_array.length != b_array.length) return false;
            for (i in 0...a_array.length) {
                if (!isEqual(a_array[i], b_array[i])) return false;
            }
            return true;
        }
        return a == b;
    }

    function getIndexRange(ranged: Bool, from: Any, to: Any, arrayLength: Int): IndexRange {
        if (from != null && !Std.isOfType(from, Int)) throw 'From index in slice range must be an Int.';
        if (!ranged) return Single((from: Int));

        var fromIndex: Int = (from != null ? from : 0);
        if (fromIndex < 0) fromIndex = arrayLength + fromIndex;
        if (fromIndex < 0 && fromIndex >= arrayLength) throw new RuntimeError(new Token(LeftBracket, 'x', fromIndex, -1, -1),
            'Array out of bounds (index $fromIndex in array of length ${arrayLength}).');

        if (to != null && !Std.isOfType(to, Int)) throw 'To index in slice range must be an Int.';
        var toIndex: Int = (to != null ? to : arrayLength);
        if (toIndex < 0) toIndex = arrayLength + toIndex;
        var reversed = false;
        if (fromIndex > toIndex) {
            reversed = true;
            var tmp = fromIndex;

            fromIndex = toIndex;
            toIndex = tmp;
        }
        if (toIndex < 0 && toIndex >= arrayLength) throw new RuntimeError(new Token(LeftBracket, 'x', toIndex, -1, -1),
            'Array out of bounds (index $toIndex in array of length ${arrayLength}).'); // TODO: Improve this
        return Range(fromIndex, toIndex, reversed);
    }

    inline function checkNumberOperand(op: Token, operand: Any) {
        if (Std.isOfType(operand, Float)) return;
        throw new RuntimeError(op, 'Operand must be a number');
    }

    inline function checkNumberOperands(op: Token, left: Any, right: Any) {
        if (Std.isOfType(left, Float) && Std.isOfType(right, Float)) return;
        throw new RuntimeError(op, 'Operand must be a number');
    }

    inline function stringify(v: Any): String {
        if (v == null) return 'nil';
        return '$v';
    }
}

enum IndexRange {
    Single(index: Int);
    Range(from: Int, to: Int, reversed: Bool);
}

private class CustomCallable implements Callable {
    final arityValue: Int;
    final method: (args: Array<Any>) -> Any;

    public function new(arityValue: Int, method: (args: Array<Any>) -> Null<Any>) {
        this.arityValue = arityValue;
        this.method = method;
    }

    public function arity(): Int return arityValue;

    public function call(interpreter: Interpreter, args: Array<Any>): Any return method(args);

    public function toString(): String return '<native fn>';
}

abstract Locals(Map < #if hl EnumValue #else {} #end, Int >) {
    public inline function new() this = new Map();

    public inline function get(expr: Expr): Null<Int> return this.get(cast expr); // this is a hack, depends on implementation details of ObjectMap

    public inline function set(expr: Expr, v: Int) this.set(cast expr, v); // this is a hack, depends on implementation details of ObjectMap
}
