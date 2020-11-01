package cosy;

import cosy.phases.*;
import haxe.Timer;
import haxe.io.Path;

#if sys
import sys.io.File;
#end

class Cosy {
    static final interpreter = new Interpreter();
    public static final foreignFunctions :Map<String, ForeignFunction> = new Map();
    public static final foreignVariables :Map<String, Any> = new Map();

    static var hadError = false;
    static var hadRuntimeError = false;
    static var outputPrettyPrint = false;
    static var outputBytecode = false;
    static var outputJavaScript = false;
    static var validateOnly = false;
    static var outputTimes = true; // TODO: Set to true for testing purposes, should be false by default
    static var noColors = false;
    public static var strict = false;

    static function main() {
        Cosy.setFunction('randomInt', (args) -> { return Std.random(args[0]); });
        Cosy.setFunction('readInput', (args) -> {
            #if sys
            return Sys.stdin().readLine();
            #else
            throw 'Not implemented on this platform!';
            #end
        });
        Cosy.setFunction('stringToNumber', (args) -> { return Std.parseInt(args[0]); /* can be null! */ });
        
        #if sys
        var args = Sys.args();
        var argErrors = [];
        for (i in 0...args.length - 1) {
            var arg = args[i];
            switch arg {
                case '--prettyprint': outputPrettyPrint = true;
                case '--bytecode': outputBytecode = true;
                case '--javascript': outputJavaScript = true;
                case '--strict': strict = true;
                case '--validate-only': validateOnly = true;
                case '--times': outputTimes = true;
                case '--no-colors': noColors = true;
                case _: argErrors.push(arg);
            }
        }
        
        if (args.length == 0 || argErrors.length > 0) {
            if (argErrors.length > 0) {
                Sys.println('Unknown argument(s): ${argErrors.join(", ")}\n');
            }
            Sys.println(
'Usage: cosy (options) [source file]

Options:
--prettyprint    Prints the formatted source.
--bytecode       Prints the compiled Cosy bytecode.
--javascript     Prints the corresponding JavaScript code.
--strict         Enable strict enforcing of types.
--validate-only  Only perform code validation.
--times          Output time spent in each phase.
--no-colors      Disable colors in log output.'
            );
            Sys.exit(64);
        }
        
        var printCount = 0;
        if (outputPrettyPrint) printCount++;
        if (outputBytecode) printCount++;
        if (outputJavaScript) printCount++;
        if (printCount > 1) {
            Sys.println('Only pass one of --prettyprint/--bytecode/--javascript\n');
            Sys.exit(64);
        }

        var file = args[args.length - 1];
        if (!sys.FileSystem.exists(file)) {
            var message = 'Source file not found: "$file".';

            var dir = Path.directory(file);
            var filename = Path.withoutDirectory(file);
            var files = sys.FileSystem.readDirectory(dir).filter(f -> !sys.FileSystem.isDirectory(Path.join([dir, f])));
            var bestMatches = EditDistance.bestMatches(filename, files);
            if (bestMatches.length > 0) {
                bestMatches = bestMatches.map(m -> '"${Path.join([dir, filename])}"');
                var lastMatch = bestMatches.pop();
                var formattedMatches = (bestMatches.length > 0 ? bestMatches.join(', ') + ' or ' + lastMatch : lastMatch);
                message += ' Did you mean $formattedMatches?';
            }

            Sys.println(message);
            Sys.exit(64);
        }

        runFile(file);
        #end
    }

    #if sys
    static function runFile(path:String) {
        var content = File.getContent(path);
        run(content);
        if (hadError) Sys.exit(65);
        if (hadRuntimeError) Sys.exit(70);
    }
    #end

    public static function printlines(a :Array<Dynamic>) {
        for (e in a) println(e);
    }

    public static function println(v :Dynamic) {
        #if sys
        Sys.println(v);
        #elseif js
        js.Browser.console.log(v);
        #end
    }

    @:expose // TODO: Maybe expose shallow?
    static function validate(source:String) {
        hadError = false;

        var scanner = new Scanner(source);
        var tokens = scanner.scanTokens();
        var parser = new Parser(tokens);
        var statements = parser.parse();

        if (hadError) return;

        var resolver = new Resolver(interpreter);
        resolver.resolve(statements);

        var typer = new Typer();
        typer.type(statements);

        if (hadError) return;
    }

    @:expose
    public static function setFunction(name: String, func: Array<Any> -> Any) {
        foreignFunctions[name] = new ForeignFunction(func);
    }
    
    @:expose
    public static function setVariable(name: String, variable: Any) {
        foreignVariables[name] = variable;
    }

    static function round2(number: Float, precision: Int): Float {
        var num = number;
        num = num * Math.pow(10, precision);
        num = Math.round(num) / Math.pow(10, precision);
        return num;
    }

    static var measureStarts :Map<String, Float> = new Map();
    static var measureOutput = '';
    
    static function startMeasure(phase: String) {
        if (!outputTimes) return;
        measureStarts[phase] = Timer.stamp();
    }

    static function endMeasure(phase: String) {
        if (!outputTimes) return;
        if (!measureStarts.exists(phase)) throw 'Measurement for $phase has not been started';
        var end = Timer.stamp();
        var duration = (end - measureStarts[phase]) * 1000;
        while (phase.length < 15) phase += ' ';
        measureOutput += '\n· ';
        measureOutput += color('$phase took\t${round2(duration, 3)} ms', Misc);
    }
    
    @:expose
    public static function run(source :String) {
        hadError = false;
        measureOutput = color('Times:', Misc);

        var start = Timer.stamp();

        startMeasure('Scanner');
        var scanner = new Scanner(source);
        var tokens = scanner.scanTokens();
        endMeasure('Scanner');

        startMeasure('Parser');
        var parser = new Parser(tokens);
        var statements = parser.parse();
        endMeasure('Parser');

        if (hadError) return;

        startMeasure('Resolver');
        var resolver = new Resolver(interpreter);
        resolver.resolve(statements);
        endMeasure('Resolver');

        startMeasure('Typer');
        var typer = new Typer();
        typer.type(statements);
        endMeasure('Typer');

        if (hadError) return;
        if (validateOnly) return;

        startMeasure('Optimizer');
        var optimizer = new Optimizer();
        statements = optimizer.optimize(statements);
        endMeasure('Optimizer');

        if (outputPrettyPrint) {
            var printer = new AstPrinter();
            // for (stmt in statements) println(printer.printStmt(stmt));
            printlines(statements.map(printer.printStmt));
            return;
        }

        if (outputJavaScript) {
            // Hack to inject a JavaScript standard library
            var stdLib = '// standard library\nlet clock = Date.now;\n';
            println(stdLib);

            var printer = new JavaScriptPrinter();
            // for (stmt in statements) println(printer.printStmt(stmt));
            printlines(statements.map(printer.printStmt));
            return;
        }

        startMeasure('Code generator');
        var codeGenerator = new CodeGenerator();
        var bytecodeOutput = codeGenerator.generate(statements);
        var bytecode = bytecodeOutput.bytecode;
        endMeasure('Code generator');
        if (outputBytecode) {
            // printlines(bytecode);
            // printlines([bytecode.toString()]);
            return;
        }
        // var formattedBytecode = [ for (index => code in bytecode) '$index: $code' ];
        trace('GENERATED CODE:');
        printlines([bytecode.toString()]);
        // trace('------------------\n' + formattedBytecode.join('\n'));
        // trace('------------------');

        startMeasure('VM interpreter');
        var vm = new VM();
        vm.run(bytecodeOutput);
        endMeasure('VM interpreter');

        // trace('AST interpreter');
        startMeasure('AST interpreter');
        trace('AST output:');
        interpreter.interpret(statements);
        endMeasure('AST interpreter');

        if (outputTimes) {
            println('\n$measureOutput');

            var end = Timer.stamp();
            var totalDuration = (end - start) * 1000;
            println(color('Total: ${round2(totalDuration, 3)} ms', Misc));
        }
    }

    static function reportWarning(line:Int, where:String, message:String) {
        var msg = '[line $line] Warning $where: $message';
        println(color(msg, Warning));
    }

    public static function warning(data:ErrorData, message:String) {
        switch data {
            case Line(line): reportWarning(line, '', message);
            case Token(token) if (token.type == Eof): reportWarning(token.line, 'at end', message);
            case Token(token): reportWarning(token.line, 'at "${token.lexeme}"', message);
        }
    }

    static function report(line:Int, where:String, message:String) {
        var msg = '[line $line] Error $where: $message';
        println(color(msg, Error));
        hadError = true;
    }

    public static function error(data:ErrorData, message:String) {
        switch data {
            case Line(line): report(line, '', message);
            case Token(token) if (token.type == Eof): report(token.line, 'at end', message);
            case Token(token): report(token.line, 'at "${token.lexeme}"', message);
        }
    }

    public static function runtimeError(e:RuntimeError) {
        var msg = '[[line ${e.token.line}] Runtime Error: ${e.message}';
        println(color(msg, Error));
        hadRuntimeError = true;
    }

    static function color(text :String, color :Color) {
        if (noColors) return text;
        return switch color {
            case Error: '\033[1;31m$text\033[0m';
            case Warning: '\033[0;33m$text\033[0m';
            case Misc: '\033[0;35m$text\033[0m';
        }
    }
}

enum Color {
    Error;
    Warning;
    Misc;
}

enum ErrorDataType {
    Line(v:Int);
    Token(v:Token);
}

abstract ErrorData(ErrorDataType) from ErrorDataType to ErrorDataType {
    @:from static inline function line(v:Int):ErrorData return Line(v);
    @:from static inline function token(v:Token):ErrorData return Token(v);
}

class ForeignFunction implements Callable {
    final method: (args: Array<Any>) -> Any;
    public function new(method: (args: Array<Any>) -> Any) {
        this.method = method;
    }
    public function arity() :Int return 0; // never called
    public function call(interpreter :Interpreter, args :Array<Any>) :Any return method(args);
    public function toString() :String return '<foreign fn>';
}
