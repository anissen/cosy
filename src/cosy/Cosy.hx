package cosy;

import cosy.phases.*;

#if sys
import sys.io.File;
#end

class Cosy {
    static final interpreter = new Interpreter();
    public static final foreignFunctions :Map<String, ForeignFunction> = new Map();
    public static final foreignVariables :Map<String, Any> = new Map();

    static var hadError = false;
    static var hadRuntimeError = false;
    static var prettyPrint = false;
    static var javascript = false;
    static var validateOnly = false;
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
        if (Sys.args().length == 0) {
            return runPrompt();
        }
        var argErrors = [];
        for (i in 0...Sys.args().length - 1) {
            var arg = Sys.args()[i];
            switch arg {
                case '--prettyprint': prettyPrint = true;
                case '--javascript': javascript = true;
                case '--strict': strict = true;
                case '--validate-only': validateOnly = true;
                case _: argErrors.push(arg);
            }
        }
        
        if (argErrors.length > 0) {
            Sys.println('Unknown argument(s): ${argErrors.join(", ")}\n');
            Sys.println(
'Usage: cosy (options) [source file]

Options:
--prettyprint    Prints the formatted source.
--javascript     Prints the corresponding JavaScript code.
--strict         Enable strict enforcing of types.
--validate-only  Only perform code validation.'
            );
            Sys.exit(64);
        }

        var file = Sys.args()[Sys.args().length - 1];
        if (!sys.FileSystem.exists(file)) {
            Sys.println('Source file not found: "$file"');
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

    static function runPrompt() {
        var stdin = Sys.stdin();
        while (true) {
            Sys.print('> ');
            run(stdin.readLine());
        }
    }
    #end

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

    @:expose
    public static function run(source:String) {
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
        if (validateOnly) return;

        var optimizer = new Optimizer();
        statements = optimizer.optimize(statements);

        if (prettyPrint) {
            var printer = new AstPrinter();
            for (stmt in statements) println(printer.printStmt(stmt));
            return;
        }

        if (javascript) {
            // Hack to inject a JavaScript standard library
            var stdLib = '// standard library\nlet clock = Date.now;\n';
            println(stdLib);

            var printer = new JavaScriptPrinter();
            for (stmt in statements) println(printer.printStmt(stmt));
            return;
        }

        var codeGenerator = new CodeGenerator();
        var bytecode = codeGenerator.generate(statements);
        trace('GENERATED CODE:');
        trace('------------------\n' + bytecode.join('\n'));
        trace('------------------');

        var vm = new VM();
        vm.run(bytecode);

        trace('AST interpreter:');
        interpreter.interpret(statements);
    }

    static function reportWarning(line:Int, where:String, message:String) {
        println('[line $line] Warning $where: $message');
    }

    public static function warning(data:ErrorData, message:String) {
        switch data {
            case Line(line): reportWarning(line, '', message);
            case Token(token) if (token.type == Eof): reportWarning(token.line, 'at end', message);
            case Token(token): reportWarning(token.line, 'at "${token.lexeme}"', message);
        }
    }

    static function report(line:Int, where:String, message:String) {
        // println('\033[1;31m[line $line] Error $where: $message\033[0m');
        println('[line $line] Error $where: $message');
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
        println('[line ${e.token.line}] Runtime Error: ${e.message}');
        hadRuntimeError = true;
    }
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
