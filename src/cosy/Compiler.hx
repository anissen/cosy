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
    var fileName: String = '???';
    var sourceCode: String = '';

    public final logger = new Logging.Logger();

    public final foreignFunctions: Map<String, ForeignFunction> = new Map();
    public final foreignVariables: Map<String, Any> = new Map();

    final interpreter = new Interpreter();

    // TODO: All these properties should not be publically available to get/set
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
            if (logger.hadError) Sys.exit(65);
            if (logger.hadRuntimeError) Sys.exit(70);
        }
    }
    #end

    @:expose
    public function validate(source: String): Bool {
        logger.hadError = false;
        logger.hadRuntimeError = false;
        logger.log = [];

        final scanner = new Scanner(source, logger);
        final tokens = scanner.scanTokens();
        final parser = new Parser(tokens, logger);
        final statements = parser.parse();

        if (logger.hadError) return false;

        final resolver = new Resolver(interpreter, this);
        resolver.resolve(statements);

        final typer = new Typer(logger);
        typer.type(statements, strict);

        if (logger.hadError) return false;

        return true;
    }

    @:expose
    public function parse(source: String): Array<Stmt> {
        logger.hadError = false;
        logger.hadRuntimeError = false;
        logger.log = [];
        sourceCode = source;

        Logging.startMeasure('Scanner');
        var scanner = new Scanner(source, logger);
        var tokens = scanner.scanTokens();
        Logging.endMeasure('Scanner');

        Logging.startMeasure('Parser');
        var parser = new Parser(tokens, logger);
        var statements = parser.parse();
        Logging.endMeasure('Parser');

        Logging.reportAll(fileName, sourceCode, logger.log);
        if (logger.hadError) return [];

        Logging.startMeasure('Optimizer');
        var optimizer = new Optimizer(logger);
        statements = optimizer.optimize(statements);
        Logging.endMeasure('Optimizer');

        Logging.startMeasure('Resolver');
        var resolver = new Resolver(interpreter, this);
        resolver.resolve(statements);
        Logging.endMeasure('Resolver');

        Logging.startMeasure('Typer');
        var typer = new Typer(logger);
        typer.type(statements, strict);
        Logging.endMeasure('Typer');

        Logging.reportAll(fileName, sourceCode, logger.log);
        if (logger.hadError) return [];
        if (validateOnly) return [];
        return statements;
    }

    @:expose
    public function runStatements(statements: Array<Stmt>, hotReload = false): Void {
        if (statements == null) return Logging.println('Statements list is null.');
        if (statements.length == 0) return Logging.println('Statements list is empty.');
        logger.hadRuntimeError = false;
        logger.log = [];
        interpreter.run(statements, this, hotReload);
    }

    @:expose
    public function runFunction(name: String, ...args: Any) {
        interpreter.runFunction(name, args);
    }

    @:expose
    public function run(source: String) {
        // Logging.println(Logging.color('Times:', Logging.Color.Misc));

        var start = Timer.stamp();
        final statements = parse(source);

        if (logger.hadError) return;
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
        // Logging.reportAll(fileName, sourceCode, logger.log);
        Logging.endMeasure('AST interpreter');
        // trace('-------------');

        if (outputTimes) {
            var end = Timer.stamp();
            var totalDuration = (end - start) * 1000;
            Logging.println(Logging.color('Total: ${Logging.round2(totalDuration, 3)} ms', Logging.LogType.Misc));
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
} // TODO: Should probably be in it's own class

class ForeignFunction implements Callable {
    final method: (args: Array<Any>) -> Any;

    public function new(method: (args: Array<Any>) -> Any) {
        this.method = method;
    }

    public function arity(): Int return 0; // never called

    public function call(interpreter: Interpreter, args: Array<Any>): Any return method(args);

    public function toString(): String return '<foreign fn>';
}
