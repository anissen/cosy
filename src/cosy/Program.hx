package cosy;

import cosy.phases.Interpreter;
#if (sys || nodejs)
import sys.io.File;
#end

class Program {
    public final foreignFunctions: Map<String, ForeignFunction> = new Map();
    public final foreignVariables: Map<String, Any> = new Map();

    public var statements: Array<Stmt> = new Array();

    public function new() {
        setFunction('random_int', (args) -> return Std.random(args[0]));
        setFunction('floor', (args) -> return Math.floor(args[0]));
        setFunction('string_to_number', (args) -> {
            // TODO: Should return an error if failing to parse. For now, it simply returns zero.
            final value = Std.parseInt(args[0]);
            return (value != null ? value : 0);
        });
        setFunction('string_from_char_code', (args) -> String.fromCharCode(args[0]));

        #if (sys || nodejs)
        setFunction('read_input', (args) -> Sys.stdin().readLine());
        setFunction('read_lines', (args) -> {
            var lines = File.getContent(args[0]).split('\n');
            lines.pop(); // remove last line (assuming empty line)
            return lines;
        });
        setFunction('read_file', (args) -> File.getContent(args[0]));
        #end
    }

    // @:expose // TODO: Expose only works with static fields
    public function setFunction(name: String, func: Array<Any>->Any) {
        foreignFunctions[name] = new ForeignFunction(func);
    }

    // @:expose
    public function setVariable(name: String, variable: Any) {
        foreignVariables[name] = variable;
    }
}

// TODO: Should probably be in it's own class
class ForeignFunction implements Callable {
    final method: (args: Array<Any>) -> Any;

    public function new(method: (args: Array<Any>) -> Any) {
        this.method = method;
    }

    public function arity(): Int return 0; // never called

    public function call(interpreter: Interpreter, args: Array<Any>): Any return method(args);

    public function toString(): String return '<foreign fn>';
}
