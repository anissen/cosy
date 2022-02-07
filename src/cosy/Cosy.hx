package cosy;

#if (sys || nodejs)
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
#end

class Cosy {
    static var compiler: Compiler = new Compiler();

    static function main() {
        #if (cpp && static_link)
        return;
        #end

        #if (!sys && !nodejs)
        return;
        #end

        #if nodejs
        final usedAsModule = js.Syntax.code('require.main !== module');
        if (usedAsModule) return;
        #end

        #if (sys || nodejs)
        var args = Sys.args();
        var argErrors = [];
        for (i in 0...args.length - 1) {
            var arg = args[i];
            switch arg {
                case '--prettyprint': compiler.outputPrettyPrint = true;
                case '--bytecode': compiler.outputBytecode = true;
                case '--disassembly': compiler.outputDisassembly = true;
                case '--javascript': compiler.outputJavaScript = true;
                case '--markdown': compiler.outputMarkdown = true;
                case '--strict': compiler.strict = true;
                case '--validate-only': compiler.validateOnly = true;
                case '--watch': compiler.watch = true;
                case '--times': compiler.outputTimes = true;
                case '--no-colors': compiler.noColors = true;
                case _: argErrors.push(arg);
            }
        }

        if (args.length == 0 || argErrors.length > 0) {
            if (argErrors.length > 0) {
                Sys.println('Unknown argument(s): ${argErrors.join(", ")}\n');
            }
            Sys.println('Cosy compiler (${getGitCommitSHA()} @ ${getBuildDate()})
Usage: cosy <options> [source file]

Options:
--prettyprint    Prints the formatted source.
--bytecode       Prints the compiled Cosy bytecode.
--disassembly    Pretty-print Cosy bytecode.
--javascript     Prints the corresponding JavaScript code.
--markdown       Prints the code as Markdown documentation.
--strict         Enable strict enforcing of types.
--validate-only  Only perform code validation.
--times          Output time spent in each phase.
--watch          Watch the file for changes and automatically rerun.
--no-colors      Disable colors in log output.');

            Sys.exit(64);
        }

        var printCount = 0;
        if (compiler.outputPrettyPrint) printCount++;
        if (compiler.outputBytecode) printCount++;
        // if (compiler.outputDisassembly) printCount++;
        if (compiler.outputJavaScript) printCount++;
        if (compiler.outputMarkdown) printCount++;
        if (printCount > 1) {
            Sys.println('Only pass one of --prettyprint/--bytecode/--disassembly/--javascript/--markdown\n');
            Sys.exit(64);
        }

        var file = args[args.length - 1];
        if (!sys.FileSystem.exists(file)) {
            Logging.println(Logging.color('Source file not found: "$file".', Error));

            var dir = Path.directory(file);
            var filename = Path.withoutDirectory(file);
            var files = sys.FileSystem.readDirectory(dir).filter(f -> !sys.FileSystem.isDirectory(Path.join([dir, f])));
            var bestMatches = EditDistance.bestMatches(filename, files);
            if (bestMatches.length > 0) {
                bestMatches = bestMatches.map(m -> '"${Path.join([dir, m])}"');
                var lastMatch = bestMatches.pop();
                var formattedMatches = (bestMatches.length > 0 ? bestMatches.join(', ') + ' or ' + lastMatch : lastMatch);
                Logging.println(Logging.color('Did you mean $formattedMatches?', Logging.Color.Hint));
            }

            Sys.exit(64);
        }

        runFile(file);

        // TODO: Move file watching into its own file?
        if (compiler.watch) {
            var stat = FileSystem.stat(file);
            function has_file_changed(): Bool {
                if (stat == null) return false;
                var new_stat = FileSystem.stat(file);
                if (new_stat == null) return false;
                var has_changed = (new_stat.mtime.getTime() != stat.mtime.getTime());
                stat = new_stat;
                return has_changed;
            }
            function watch_file() {
                if (has_file_changed()) {
                    var time = Date.now();
                    var text = '> "$file" changed at $time';
                    Sys.println(compiler.noColors ? text : '\033[1;34m$text\033[0m');
                    compiler.runFile(file);
                }
            }
            var timer = new haxe.Timer(1000);
            timer.run = watch_file;
        }
        #end
    }

    // TODO: Move macros into their own file?
    static macro function getBuildDate(): haxe.macro.Expr {
        #if !display
        return macro $v{Date.now().toString()};
        #else
        return macro $v{''};
        #end
    }

    static macro function getGitCommitSHA(): haxe.macro.Expr {
        #if !display
        var process = new sys.io.Process('git', ['rev-parse', '--short', 'HEAD']);
        if (process.exitCode() != 0) {
            var message = process.stderr.readAll().toString();
            var pos = haxe.macro.Context.currentPos();
            haxe.macro.Context.error('Cannot execute `git rev-parse --short HEAD`. $message', pos);
        }
        var commitSHA = process.stdout.readLine();
        return macro $v{commitSHA};
        #else
        return macro $v{''};
        #end
    }

    @:expose
    public static function validate(source: String): Bool {
        return compiler.validate(source);
    }

    #if (sys || nodejs)
    @:expose
    public static function runFile(path: String) {
        compiler.runFile(path);
    }
    #end

    @:expose
    public static function runSource(source: String) {
        compiler.run(source);
    }

    @:expose
    public static function createCompiler(): Compiler {
        compiler = new Compiler(); // HACK to replace the static compiler instance to be able to capture errors etc. with the correct context
        return compiler;
    }

    public static function warning(data: Logging.ErrorData, message: String) {
        switch data {
            case Logging.ErrorDataType.Line(line): Logging.reportWarning(line, '', message);
            case Logging.ErrorDataType.Token(token) if (token.type == Eof): Logging.reportWarning(token.line, 'at end', message);
            case Logging.ErrorDataType.Token(token): Logging.reportWarning(token.line, 'at "${token.lexeme}"', message);
        }
    }

    public static function error(data: Logging.ErrorData, message: String) {
        compiler.error(data, message);
        switch data {
            case Logging.ErrorDataType.Line(line): Logging.report(line, null, message);
            case Logging.ErrorDataType.Token(token): Logging.report(token.line, token, message);
        }
    }

    public static function hint(token: Token, message: String) {
        var msg = '[line ${token.line}] Hint: $message';
        Logging.println(Logging.color(msg, Hint));
    }

    public static function runtimeError(e: RuntimeError) {
        var msg = '[line ${e.token.line}] Runtime Error: ${e.message}';
        Logging.println(Logging.color(msg, Error));
        trace(msg);
        compiler.hadRuntimeError = true;
    }
}
