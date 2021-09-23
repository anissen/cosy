package cosy;

import haxe.Timer;
import cosy.phases.*;
#if (sys || nodejs)
import sys.io.File;
#end

class Compiler {
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

    public function new() {}

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

        var scanner = new Scanner(source);
        var tokens = scanner.scanTokens();
        var parser = new Parser(tokens);
        var statements = parser.parse();

        if (hadError) return false;

        var resolver = new Resolver(interpreter, new Program());
        resolver.resolve(statements);

        var typer = new Typer();
        typer.type(statements, strict);

        if (hadError) return false;

        return true;
    }

    @:expose
    public function parse(source: String, program: Program): Array<Stmt> {
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
        var resolver = new Resolver(interpreter, program);
        resolver.resolve(statements);
        endMeasure('Resolver');

        startMeasure('Typer');
        var typer = new Typer();
        typer.type(statements, strict);
        endMeasure('Typer');

        return statements;
    }

    @:expose
    public function run(source: String) {
        hadError = false;
        measureOutput = Cosy.color('Times:', Misc);

        var start = Timer.stamp();
        var program = new Program();
        program.statements = parse(source, program);

        if (hadError) return;
        if (validateOnly) return;

        var statements = program.statements;

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
        interpreter.run(program);
        endMeasure('AST interpreter');
        // trace('-------------');

        if (outputTimes) {
            Cosy.println('\n$measureOutput');

            var end = Timer.stamp();
            var totalDuration = (end - start) * 1000;
            Cosy.println(Cosy.color('Total: ${round2(totalDuration, 3)} ms', Misc));
        }
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
