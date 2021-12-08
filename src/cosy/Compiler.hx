package cosy;

import cosy.phases.AstPrinter;
import cosy.phases.CodeGenerator;
import cosy.phases.Disassembler;
import cosy.phases.Interpreter;
import cosy.phases.JavaScriptPrinter;
import cosy.phases.MarkdownPrinter;
import cosy.phases.Optimizer;
import cosy.phases.Parser;
import cosy.phases.Resolver;
import cosy.phases.Scanner;
import cosy.phases.Typer;
import cosy.phases.VM;
import haxe.Timer;
#if (sys || nodejs)
import sys.io.File;
#end

class Compiler {
    public final foreignFunctions: Map<String, ForeignFunction> = new Map();
    public final foreignVariables: Map<String, Any> = new Map();

    // public var statements: Array<Stmt> = new Array();
    final interpreter = new Interpreter();

    // TODO: All these properties should not be publically available to get/set
    public var hadError = false;
    public var hadRuntimeError = false;
    public var outputPrettyPrint = false;
    public var outputBytecode = false;
    public var outputJavaScript = false;
    public var outputMarkdown = false;
    public var outputDisassembly = false;
    public var validateOnly = false;
    public var watch = false;
    public var outputTimes = false;
    public var noColors = false;
    public var strict = false;

    public function new() {
        setFunction('random_int', (args) -> Std.random(args[0]));
        setFunction('floor', (args) -> Math.floor(args[0]));
        setFunction('string_to_number', (args) -> {
            // TODO: Should return an error if failing to parse. For now, it simply returns zero.
            final value = Std.parseInt(args[0]);
            return (value != null ? value : 0);
        });
        setFunction('string_from_char_code', (args) -> String.fromCharCode(args[0]));
        setFunction('cos', (args) -> Math.cos(args[0]));
        setFunction('sin', (args) -> Math.sin(args[0]));
        setFunction('atan2', (args) -> Math.atan2(args[0], args[1]));
        setFunction('min', (args) -> Math.min(args[0], args[1]));
        setFunction('max', (args) -> Math.max(args[0], args[1]));

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

    #if (sys || nodejs)
    @:expose // TODO: This probably only works on static fields!
    public function runFile(path: String) {
        var content = File.getContent(path);
        run(content);
        if (!watch) {
            if (hadError) Sys.exit(65);
            if (hadRuntimeError) Sys.exit(70);
        }
    }
    #end

    @:expose
    public function validate(source: String): Bool {
        hadError = false;

        final scanner = new Scanner(source);
        final tokens = scanner.scanTokens();
        final parser = new Parser(tokens);
        final statements = parser.parse();

        if (hadError) return false;

        final resolver = new Resolver(interpreter, this);
        resolver.resolve(statements);

        final typer = new Typer();
        typer.type(statements, strict);

        if (hadError) return false;

        return true;
    }

    @:expose
    public function parse(source: String): Array<Stmt> {
        startMeasure('Scanner');
        var scanner = new Scanner(source);
        var tokens = scanner.scanTokens();
        endMeasure('Scanner');

        startMeasure('Parser');
        var parser = new Parser(tokens);
        var statements = parser.parse();
        endMeasure('Parser');

        if (hadError) return null;

        startMeasure('Optimizer');
        var optimizer = new Optimizer();
        statements = optimizer.optimize(statements);
        endMeasure('Optimizer');

        startMeasure('Resolver');
        var resolver = new Resolver(interpreter, this);
        resolver.resolve(statements);
        endMeasure('Resolver');

        startMeasure('Typer');
        var typer = new Typer();
        typer.type(statements, strict);
        endMeasure('Typer');

        if (hadError) return null;
        if (validateOnly) return null;

        return statements;
    }

    @:expose
    public function runStatements(statements: Array<Stmt>): Void {
        if (statements == null) return Cosy.println('Statements list is null.');
        if (statements.length == 0) return Cosy.println('Statements list is empty.');
        interpreter.run(statements, this);
    }

    @:expose
    public function runFunction(name: String) {
        //    interpreter.run([Expr.Call(Expr.Variable(Token()))])
        interpreter.runFunction(name);
    }

    @:expose
    public function run(source: String) {
        hadError = false;
        measureOutput = Cosy.color('Times:', Misc);

        var start = Timer.stamp();
        final statements = parse(source);

        if (hadError) return;
        if (validateOnly) return;

        if (outputPrettyPrint) {
            var printer = new AstPrinter();
            for (stmt in statements)
                Cosy.println(printer.printStmt(stmt));
            return;
        }

        if (outputJavaScript) {
            // Hack to inject a JavaScript standard library
            var stdLib = '// standard library\n';
            stdLib += 'const clock = Date.now;\n';
            stdLib += 'const string_from_char_code = String.fromCharCode;';
            Cosy.println(stdLib);

            var printer = new JavaScriptPrinter();
            for (stmt in statements)
                Cosy.println(printer.printStmt(stmt));
            return;
        }

        if (outputMarkdown) {
            Cosy.println('# Cosy file');
            Cosy.println('## Functions');

            var printer = new MarkdownPrinter();
            Cosy.println(printer.printStatements(statements));
            return;
        }

        if (outputBytecode || outputDisassembly) {
            startMeasure('Code generator');
            var codeGenerator = new CodeGenerator();
            var bytecodeOutput = codeGenerator.generate(statements);
            // var bytecode = bytecodeOutput.bytecode;
            endMeasure('Code generator');

            if (outputDisassembly) {
                startMeasure('Disassembler');
                var disassembly = Disassembler.disassemble(bytecodeOutput, !noColors);
                endMeasure('Disassembler');
                Cosy.printlines([disassembly]);
            }

            if (outputBytecode) {
                trace('-------------');
                trace('VM interpreter');
                startMeasure('VM interpreter');
                var vm = new VM();
                vm.run(bytecodeOutput);
                endMeasure('VM interpreter');
                trace('-------------');
            }
        }

        // trace('AST interpreter');
        startMeasure('AST interpreter');
        // trace('AST output:');
        interpreter.run(statements, this);
        endMeasure('AST interpreter');
        // trace('-------------');

        if (outputTimes) {
            Cosy.println('\n$measureOutput');

            var end = Timer.stamp();
            var totalDuration = (end - start) * 1000;
            Cosy.println(Cosy.color('Total: ${round2(totalDuration, 3)} ms', Misc));
        }
    }

    // @:expose // TODO: Expose only works with static fields
    public function setFunction(name: String, func: Array<Any>->Any) {
        foreignFunctions[name] = new ForeignFunction(func);
    }

    // @:expose
    public function setVariable(name: String, variable: Any) {
        foreignVariables[name] = variable;
        interpreter.setForeignVariable(name, variable);
    }

    // Measurement stuff...
    static function round2(number: Float, precision: Int): Float {
        var num = number;
        num = num * Math.pow(10, precision);
        num = Math.round(num) / Math.pow(10, precision);
        return num;
    }

    var measureStarts: Map<String, Float> = new Map();
    var measureOutput = '';

    function startMeasure(phase: String) {
        if (!outputTimes) return;
        measureStarts[phase] = Timer.stamp();
    }

    function endMeasure(phase: String) {
        if (!outputTimes) return;
        if (!measureStarts.exists(phase)) throw 'Measurement for $phase has not been started';
        var end = Timer.stamp();
        var duration = (end - measureStarts[phase]) * 1000;
        while (phase.length < 15) phase += ' ';
        measureOutput += '\n· ';
        measureOutput += Cosy.color('$phase took\t${round2(duration, 3)} ms', Misc);
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
