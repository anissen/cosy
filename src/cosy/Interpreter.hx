package cosy;

class Interpreter {
    final globals:Environment;
    final locals = new Locals();

    var environment:Environment;
    static final uninitialized :Any = {};

    public function new() {
        globals = new Environment();
        globals.define('clock', new ClockCallable());
        globals.define('random', new RandomCallable());
        globals.define('str_length', new StringLengthCallable());
        globals.define('str_charAt', new StringCharAtCallable());
        globals.define('input', new InputCallable());
        environment = globals;
    }

    public function interpret(statements:Array<Stmt>) {
        try {
            for (statement in statements) execute(statement);
        } catch (e:RuntimeError) {
            Cosy.runtimeError(e);
        }
    }

    function execute(statement:Stmt) {
        switch statement {
            case Block(statements):
                executeBlock(statements, new Environment(environment));
            case Class(name, superclass, meths):
                var superclass:Klass =
                    if(superclass != null) {
                        var sc = evaluate(superclass);
                        if(!Std.is(sc, Klass)) throw new RuntimeError(switch superclass {
                            case Variable(name): name;
                            case _: throw 'unreachable';
                        }, 'Superclass must be a class');
                        sc;
                    } else null;
                environment.define(name.lexeme, null);
                if(superclass != null) {
                    environment = new Environment(environment);
                    environment.define('super', superclass);
                }
                var methods = new Map();
                for(method in meths) switch method {
                    case Function(name, params, body, returnType):
                        var func = new Function(name, params, body, environment, name.lexeme == 'init');
                        methods.set(name.lexeme, func);
                    case _: // unreachable
                }
                var klass = new Klass(name.lexeme, superclass, methods);
                if(superclass != null) environment = environment.enclosing;
                environment.assign(name, klass);
            case Expression(e):
                evaluate(e);
            case For(keyword, name, from, to, body):
                var fromVal = evaluate(from);
                if (!Std.is(fromVal, Float)) Cosy.error(keyword, 'Number expected in "from" clause of loop.');
                var toVal = evaluate(to);
                if (!Std.is(toVal, Float)) Cosy.error(keyword, 'Number expected in "to" clause of loop.');
                var env = new Environment(environment);
                for (counter in (fromVal :Int)...(toVal :Int)) {
                    if (name != null) env.define(name.lexeme, counter);
                    executeBlock(body, env); // TODO: Is it required to create a new environment if name is null?
                }
            case ForArray(name, array, body):
                var arr :Array<Any> = evaluate(array); // TODO: Implicit cast to array :(
                var env = new Environment(environment);
                for (elem in arr) {
                    env.define(name.lexeme, elem);
                    executeBlock(body, env);
                }
            case ForCondition(cond, body):
                var env = new Environment(environment);
                while(cond != null ? isTruthy(evaluate(cond)) : true) executeBlock(body, env);
            case Function(name, params, body, returnType):
                environment.define(name.lexeme, new Function(name, params, body, environment, false));
            case If(cond, then, el):
                if (isTruthy(evaluate(cond))) execute(then);
                else if (el != null) execute(el);
            case Print(e):
                Cosy.println(stringify(evaluate(e)));
            case Return(keyword, value):
                var value = if(value == null) null else evaluate(value);
                throw new Return(value);
            case Struct(name, declarations):
                environment.define(name.lexeme, null);
                var previousEnv = environment;
                environment = new Environment(environment);
                var fields:Map<String, Any> = new Map();
                for (decl in declarations) switch decl {
                    case Var(name, type, init): fields.set(name.lexeme, init != null ? evaluate(init) : null);
                    case Mut(name, type, init): fields.set(name.lexeme, init != null ? evaluate(init) : null);
                    case _: // should never happen
                }
                environment = previousEnv;
                var struct = new StructInstance(name, fields);
                environment.assign(name, struct);
            case Var(name, type, init):
                var value:Any = uninitialized;
                if (init != null) value = evaluate(init);
                environment.define(name.lexeme, value);
            case Mut(name, type, init):
                var value:Any = uninitialized;
                if (init != null) value = evaluate(init);
                environment.define(name.lexeme, value);
        }
    }

    public function resolve(expr:Expr, depth:Int) {
        locals.set(expr, depth);
    }

    public function executeBlock(statements:Array<Stmt>, environment:Environment) {
        var previous = this.environment;
        try {
            this.environment = environment;
            for(statement in statements) execute(statement);
            this.environment = previous; // emulates "finally" statement
        } catch(e:Dynamic) {
            this.environment = previous; // emulates "finally" statement
            throw e;
        }
    }

    @SuppressWarnings('checkstyle:CyclomaticComplexity', 'checkstyle:NestedControlFlow', 'checkstyle:MethodLength')
    function evaluate(expr :Expr) :Any {
        return switch expr {
            case ArrayLiteral(keyword, exprs):
                [ for (expr in exprs) evaluate(expr) ];
            case Assign(name, op, value):
                var value: Any = switch op.type {
                    case Equal: evaluate(value);
                    case PlusEqual:
                        var left = lookUpVariable(name, expr);
                        var right = evaluate(value);
                        if (Std.is(left, Float) && Std.is(right, Float))
                            (left:Float) + (right:Float);
                        else if (Std.is(left, Float) && Std.is(right, String))
                            (left:Float) + (right:String);
                        else if (Std.is(left, String) && Std.is(right, Float))
                            (left:String) + (right:Float);
                        else if (Std.is(left, String) && Std.is(right, String))
                            (left:String) + (right:String);
                        else throw new RuntimeError(op, 'Operands cannot be concatinated.');
                    case MinusEqual:
                        var left = lookUpVariable(name, expr);
                        var right = evaluate(value);
                        checkNumberOperands(op, left, right);
                        (left: Float) - (right: Float);
                    case SlashEqual:
                        var left = lookUpVariable(name, expr);
                        var right = evaluate(value);
                        checkNumberOperands(op, left, right);
                        (left: Float) / (right: Float);
                    case StarEqual:
                        var left = lookUpVariable(name, expr);
                        var right = evaluate(value);
                        checkNumberOperands(op, left, right);
                        (left: Float) * (right: Float);
                    case _: throw 'error';
                }
                switch locals.get(expr) {
                    case null: globals.assign(name, value);
                    case distance: environment.assignAt(distance, name, value);
                }
                value;
            case Literal(v):
                v;
            case Logical(left, op, right):
                var left = evaluate(left);
                switch op.type {
                    case Or if (isTruthy(left)): left;
                    case And if (!isTruthy(left)): left;
                    case _: evaluate(right);
                }
            case Unary(op, right):
                var right = evaluate(right);
                switch op.type {
                    case Bang: !isTruthy(right);
                    case Minus:
                        checkNumberOperand(op, right);
                        -(right :Float);
                    case _: null; // unreachable
                }
            case Binary(left, op, right):
                var left:Any = evaluate(left);
                var right:Any = evaluate(right);

                switch op.type {
                    case Minus:
                        checkNumberOperands(op, left, right);
                        (left:Float) - (right:Float);
                    case Slash:
                        checkNumberOperands(op, left, right);
                        (left:Float) / (right:Float);
                    case Star:
                        checkNumberOperands(op, left, right);
                        (left:Float) * (right:Float);
                    case Plus:
                        if (Std.is(left, Float) && Std.is(right, Float))
                            (left:Float) + (right:Float);
                        else if (Std.is(left, Float) && Std.is(right, String))
                            (left:Float) + (right:String);
                        else if (Std.is(left, String) && Std.is(right, Float))
                            (left:String) + (right:Float);
                        else if (Std.is(left, String) && Std.is(right, String))
                            (left:String) + (right:String);
                        else throw new RuntimeError(op, 'Operands cannot be concatinated.');
                    case Greater:
                        checkNumberOperands(op, left, right);
                        (left:Float) > (right:Float);
                    case GreaterEqual:
                        checkNumberOperands(op, left, right);
                        (left:Float) >= (right:Float);
                    case Less:
                        checkNumberOperands(op, left, right);
                        (left:Float) < (right:Float);
                    case LessEqual:
                        checkNumberOperands(op, left, right);
                        (left:Float) <= (right:Float);
                    case BangEqual: !isEqual(left, right);
                    case EqualEqual: isEqual(left, right);
                    case _: null; // unreachable
                }
            case Call(callee, paren, args):
                var callee = evaluate(callee);
                var args = args.map(evaluate);

                if (!Std.is(callee, Callable)) {
                    throw new RuntimeError(paren, 'Can only call functions and classes');
                } else {
                    var func:Callable = callee;
                    var arity = func.arity();
                    if (args.length != arity) throw new RuntimeError(paren, 'Expected $arity argument(s) but got ${args.length}.');
                    func.call(this, args);
                }
            case Get(obj, name):
                var obj = evaluate(obj);
                
                if (Std.is(obj, Array)) return arrayGet(obj, name);
                else if (Std.is(obj, StructInstance)) (obj :StructInstance).get(name);
                else if (Std.is(obj, Instance)) return (obj: Instance).get(name);
                else throw new RuntimeError(name, 'Only instances have properties');
            case Set(obj, name, value):
                var obj = evaluate(obj);
                var value = evaluate(value);
                if (Std.is(obj, Instance)) (obj: Instance).set(name, value);
                else if (Std.is(obj, StructInstance)) (obj :StructInstance).set(name, value);
                else throw new RuntimeError(name, 'Only instances have fields');
                value;
            case Grouping(e):
                evaluate(e);
            case Variable(name) | This(name):
                lookUpVariable(name, expr);
            case Super(kw, meth):
                var distance = locals.get(expr);
                var superclass:Klass = environment.getAt(distance, 'super');
                var obj:Instance = environment.getAt(distance - 1, 'this');
                var method = superclass.findMethod(meth.lexeme);
                if (method == null) throw new RuntimeError(meth, 'Undefined property "${meth.lexeme}".');
                method.bind(obj);
            case StructInit(name, decls):
                var structObj :StructInstance = lookUpVariable(name, expr);
                if (!Std.is(structObj, StructInstance)) throw new RuntimeError(name, 'Struct initializer on non-struct object.');
                for (decl in decls) {
                    switch decl {
                        case Assign(variableName, op, value): structObj.set(variableName, evaluate(value));
                        case _: // unreachable
                    }
                }
                structObj;
            case AnonFunction(params, body, returnType):
                new Function(null, params, body, environment, false);
        }
    }

    function arrayGet(array: Array<Any>, name: Token) :Any {
        // TODO: This functions should (together with the Array functionality in Typer) be moved out into its own class, like Klass.
        // TODO: Argument types must match! Change arity to array of types, e.g. 'get' has Number
        return switch name.lexeme {
            case 'length': array.length;
            case 'get': new ArrayCallable(1, (args -> array[(args[0] :Int)]));
            case 'push': new ArrayCallable(1, (args -> args.map(array.push)));
            case 'concat': new ArrayCallable(1, (args -> (args[0] :Array<Any>).map(array.push)));
            case 'pop': new ArrayCallable(0, (_ -> (array.length == 0 ? throw new RuntimeError(name, 'Cannot pop from empty array.') : array.pop())));
            case _: throw new RuntimeError(name, 'Undefined method "${name.lexeme}".');
        }
    }

    function lookUpVariable(name: Token, expr: Expr) :Any {
        var value = switch locals.get(expr) {
            case null: globals.get(name);
            case distance: environment.getAt(distance, name.lexeme);
        }
        if (value == uninitialized) throw new RuntimeError(name, 'Accessing uninitialized variable "${name.lexeme}".');
        return value;
    }

    function isTruthy(v :Any):Bool {
        if (v == null) return false;
        if (Std.is(v, Bool)) return v;
        return true;
    }

    function isEqual(a :Any, b :Any) :Bool {
        if (a == null && b == null) return true;
        if (a == null) return false;
        return a == b;
    }

    function checkNumberOperand(op:Token, operand:Any) {
        if (Std.is(operand, Float)) return;
        throw new RuntimeError(op, 'Operand must be a number');
    }

    function checkNumberOperands(op:Token, left:Any, right:Any) {
        if (Std.is(left, Float) && Std.is(right, Float)) return;
        throw new RuntimeError(op, 'Operand must be a number');
    }

    function stringify(v: Any) :String {
        if (v == null) return 'nil';
        return '$v';
    }
}

private class ClockCallable implements Callable {
    public function new() {}
    public function arity() :Int return 0;
    public function call(interpreter:Interpreter, args:Array<Any>):Any return haxe.Timer.stamp() * 1000;
    public function toString() :String return '<native fn>';
}

private class RandomCallable implements Callable {
    public function new() {}
    public function arity() :Int return 0;
    public function call(interpreter:Interpreter, args:Array<Any>):Any return Math.random();
    public function toString() :String return '<native fn>';
}

private class StringLengthCallable implements Callable {
    public function new() {}
    public function arity() :Int return 1;
    public function call(interpreter:Interpreter, args:Array<Any>):Any return (args[0] :String).length;
    public function toString() :String return '<native fn>';
}

private class StringCharAtCallable implements Callable {
    public function new() {}
    public function arity() :Int return 2;
    public function call(interpreter:Interpreter, args:Array<Any>):Any return (args[0] :String).charAt((args[1] :Int));
    public function toString() :String return '<native fn>';
}

private class InputCallable implements Callable {
    public function new() {}
    public function arity() :Int return 0;
    public function call(interpreter:Interpreter, args:Array<Any>):Any {
        #if sys
        return Sys.stdin().readLine();
        #else
        throw 'Not implemented on this platform!';
        #end
    }
    public function toString() :String return '<native fn>';
}

private class ArrayCallable implements Callable {
    final arityValue: Int;
    final method: (args: Array<Any>) -> Any;
    public function new(arityValue: Int, method: (args: Array<Any>) -> Any) {
        this.arityValue = arityValue;
        this.method = method;
    }
    public function arity() :Int return arityValue;
    public function call(interpreter :Interpreter, args :Array<Any>) :Any return method(args);
    public function toString() :String return '<native fn>';
}

abstract Locals(Map<{}, Int>) {
    public inline function new() this = new Map();
    public inline function get(expr:Expr):Null<Int> return this.get(cast expr); // this is a hack, depends on implementation details of ObjectMap
    public inline function set(expr:Expr, v:Int) this.set(cast expr, v); // this is a hack, depends on implementation details of ObjectMap
}
