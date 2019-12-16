package lox;

import sys.io.File;

class Lox {
    static final interpreter = new Interpreter();

    static var hadError = false;
    static var hadRuntimeError = false;
    static var prettyPrint = false;
    static var javascript = false;
    static var testing = false;
    static var testOutput = '';

    static function main() {
        switch Sys.args() {
            case []:
                runPrompt();
            case [v]:
                runFile(v);
            case ['--prettyprint', v]:
                prettyPrint = true;
                runFile(v);
            case ['--javascript', v]:
                javascript = true;
                runFile(v);
            case _:
                Sys.println('Usage: hlox (options) [script]\n\nOptions:\n --prettyprint\tPrints the formatted script\n --javascript\tPrints the corresponding JavaScript code');
                Sys.exit(64);
        }
    }

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

    static public function test(source :String, prettyprint :Bool = false) :String {
        prettyPrint = prettyprint;
        testing = true;
        testOutput = '';
        run(source);
        testing = false;
        prettyPrint = false;
        return StringTools.trim(testOutput);
    }

    static public function println(v :Dynamic) {
        if (testing) {
            testOutput += v + '\n';
        } else {
            Sys.println(v);
        }
    }

    static function run(source:String) {
        var scanner = new Scanner(source);
        var tokens = scanner.scanTokens();
        var parser = new Parser(tokens);
        var statements = parser.parse();

        if (hadError) return;

        var resolver = new Resolver(interpreter);
        resolver.resolve(statements);

        if (hadError) return;

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

        interpreter.interpret(statements);
    }

    static function report(line:Int, where:String, message:String) {
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
