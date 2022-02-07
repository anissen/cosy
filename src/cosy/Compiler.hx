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

// Stuff related to error logging
enum ErrorType {
    Error;
    RuntimeError;
    Warning;
    Hint;
}

enum Phase {
    Scanner;
    Parser;
    Resolver;
    Typer;
    Optimizer;
    AstPrinter;
    Disassembler;
    Interpreter;
    MarkdownPrinter;
    JavaScriptPrinter;
    CodeGenerator;
    VM;
    None;
}

typedef ScriptError = {
    var pos: Logging.ErrorData;
    var message: String;
    var type: ErrorType;
    var phase: Phase;
}

class Compiler {
    var fileName: String;
    var sourceCode: String;

    public final foreignFunctions: Map<String, ForeignFunction> = new Map();
    public final foreignVariables: Map<String, Any> = new Map();

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

    public var errors: Array<ScriptError> = [];

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
        setFunction('abs', (args) -> Math.abs(args[0]));
        setFunction('clock', (args) -> haxe.Timer.stamp() * 1000);
        setFunction('random', (args) -> Math.random());
        setFunction('random_int', (args) -> Std.random(args[0]));

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
        fileName = path;
        var content = File.getContent(path);
        sourceCode = content;
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
        Logging.startMeasure('Scanner');
        var scanner = new Scanner(source);
        var tokens = scanner.scanTokens();
        Logging.endMeasure('Scanner');

        Logging.startMeasure('Parser');
        var parser = new Parser(tokens);
        var statements = parser.parse();
        Logging.endMeasure('Parser');

        if (hadError) return null;

        Logging.startMeasure('Optimizer');
        var optimizer = new Optimizer();
        statements = optimizer.optimize(statements);
        Logging.endMeasure('Optimizer');

        Logging.startMeasure('Resolver');
        var resolver = new Resolver(interpreter, this);
        resolver.resolve(statements);
        Logging.endMeasure('Resolver');

        Logging.startMeasure('Typer');
        var typer = new Typer();
        typer.type(statements, strict);
        Logging.endMeasure('Typer');

        if (hadError) return null;
        if (validateOnly) return null;

        return statements;
    }

    @:expose
    public function runStatements(statements: Array<Stmt>, hotReload = false): Void {
        if (statements == null) return Logging.println('Statements list is null.');
        if (statements.length == 0) return Logging.println('Statements list is empty.');
        interpreter.run(statements, this, hotReload);
    }

    @:expose
    public function runFunction(name: String, ...args: Any) {
        interpreter.runFunction(name, args);
    }

    @:expose
    public function run(source: String) {
        hadError = false;
        Logging.println(Logging.color('Times:', Logging.Color.Misc));

        var start = Timer.stamp();
        final statements = parse(source);

        if (hadError) return;
        if (validateOnly) return;

        if (outputPrettyPrint) {
            var printer = new AstPrinter();
            for (stmt in statements)
                Logging.println(printer.printStmt(stmt));
            return;
        }

        if (outputJavaScript) {
            // Hack to inject a JavaScript standard library
            var stdLib = '// standard library\n';
            stdLib += 'const clock = Date.now;\n';
            stdLib += 'const string_from_char_code = String.fromCharCode;';
            Logging.println(stdLib);

            var printer = new JavaScriptPrinter();
            for (stmt in statements)
                Logging.println(printer.printStmt(stmt));
            return;
        }

        if (outputMarkdown) {
            Logging.println('# Cosy file');
            Logging.println('## Functions');

            var printer = new MarkdownPrinter();
            Logging.println(printer.printStatements(statements));
            return;
        }

        if (outputBytecode || outputDisassembly) {
            Logging.startMeasure('Code generator');
            var codeGenerator = new CodeGenerator();
            var bytecodeOutput = codeGenerator.generate(statements);
            // var bytecode = bytecodeOutput.bytecode;
            Logging.endMeasure('Code generator');

            if (outputDisassembly) {
                Logging.startMeasure('Disassembler');
                var disassembly = cosy.phases.Disassembler.disassemble(bytecodeOutput, !noColors);
                Logging.endMeasure('Disassembler');
                Logging.printlines([disassembly]);
            }

            if (outputBytecode) {
                trace('-------------');
                trace('VM interpreter');
                Logging.startMeasure('VM interpreter');
                var vm = new VM();
                vm.run(bytecodeOutput);
                Logging.endMeasure('VM interpreter');
                trace('-------------');
            }
        }

        // trace('AST interpreter');
        Logging.startMeasure('AST interpreter');
        // trace('AST output:');
        interpreter.run(statements, this, false);
        Logging.endMeasure('AST interpreter');
        // trace('-------------');

        if (outputTimes) {
            var end = Timer.stamp();
            var totalDuration = (end - start) * 1000;
            Logging.println(Logging.color('Total: ${Logging.round2(totalDuration, 3)} ms', Logging.Color.Misc));
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

    // error handling stuff...
    public function error(pos: Logging.ErrorData, message: String) {
        errors.push({
            pos: pos,
            type: Error,
            message: message,
            phase: None
        });
    }

    public function hint(pos: Logging.ErrorData, message: String) {
        errors.push({
            pos: pos,
            type: Hint,
            message: message,
            phase: None
        });
    }

    public function runtimeError(e: RuntimeError) {
        errors.push({
            pos: e.token,
            type: RuntimeError,
            message: e.message,
            phase: None
        });
        hadRuntimeError = true;
    }

    // ...end of error handling stuff
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
