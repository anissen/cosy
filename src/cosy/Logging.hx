package cosy;

import haxe.ds.Either;

enum ErrorDataType {
    Line(v: Int);
    Pos(line: Int, col: Int, len: Int);
    Token(v: Token);
}

abstract ErrorData(ErrorDataType) from ErrorDataType to ErrorDataType {
    @:from inline static function line(v: Int): ErrorData return Line(v);

    @:from inline static function pos(v: {line: Int, col: Int, len: Int}): ErrorData return Pos(v.line, v.col, v.len);

    @:from inline static function token(v: Token): ErrorData return Token(v);
}

enum LogType {
    Error;
    RuntimeError;
    Warning;
    Hint;
    Misc;
}

typedef ScriptError = {
    var pos: Logging.ErrorData;
    var message: String;
    var type: LogType;
}

class Logger {
    public var log: Array<ScriptError> = [];
    public var hadError = false;
    public var hadRuntimeError = false;

    public function new() {}

    function report(type: LogType, pos: Logging.ErrorData, message: String) {
        log.push({
            pos: pos,
            type: type,
            message: message,
        });
    }

    public function error(pos: Logging.ErrorData, message: String) {
        report(Error, pos, message);
        hadError = true;
    }

    public function warning(pos: Logging.ErrorData, message: String) {
        report(Warning, pos, message);
    }

    public function hint(pos: Logging.ErrorData, message: String) {
        report(Hint, pos, message);
    }

    public function runtimeError(e: RuntimeError) {
        report(RuntimeError, e.token, e.message);
        hadRuntimeError = true;
    }
}

function printlines(a: Array<Any>) {
    for (e in a)
        println(e);
}

function println(v: Dynamic = '') {
    #if (sys || nodejs)
    Sys.println(v);
    #elseif js
    js.Browser.console.log(v);
    #end
}

function reportAll(fileName: String, sourceCode: String, log: Array<ScriptError>) {
    for (l in log) {
        switch l.type {
            case Hint:
                println(color('Hint: ${l.message}', Hint));
                continue;
            case _:
        }
        report(fileName, sourceCode, l);
    }
}

function getReport(fileName: String, sourceCode: String, error: ScriptError): String {
    final pos = error.pos;
    final errorType = error.type;
    final line = switch pos {
        case Line(line): line;
        case Token(token): token.line;
        case Pos(line, col, len): line;
    };
    var report = '';
    report += '■' + color(' $fileName, line $line:', errorType) + '\n';

    final linesBefore = 2;
    final linesAfter = 2;
    final fromLine = line - linesBefore;
    final toLine = line + linesAfter + 1;

    var codeLines = sourceCode.split('\n');
    for (lineNumber in fromLine...toLine) {
        if (lineNumber <= 0 || lineNumber > codeLines.length) continue;
        var lpad = '$toLine'.length > '$lineNumber'.length;
        var lineDecoration = (lpad ? ' ' : '') + '$lineNumber | ';
        var codeLine = codeLines[lineNumber - 1];
        if (lineNumber == line) {
            final col = switch pos {
                case Line(line): 0;
                case Token(token): token.position;
                case Pos(line, col, len): col;
            };
            final len = switch pos {
                case Line(line): codeLine.length;
                case Token(token): token.lexeme.length;
                case Pos(line, col, len): len;
            };
            report += color(lineDecoration, errorType)
                + codeLine.substr(0, col)
                + color(codeLine.substr(col, len), errorType)
                + codeLine.substr(col + len) + '\n';
            var s = [for (i in 0...(lineDecoration.length + col)) ' '].join('');
            s += color([for (i in 0...len) '^'].join('') + ' ${error.message}', errorType);
            report += s + '\n';
        } else {
            report += lineDecoration + codeLine + '\n';
        }
    }
    report += '\n';
    return report;
}

function report(fileName: String, sourceCode: String, error: ScriptError) {
    final pos = error.pos;
    final errorType = error.type;
    final line = switch pos {
        case Line(line): line;
        case Token(token): token.line;
        case Pos(line, col, len): line;
    };
    println('■' + color(' $fileName, line $line:', errorType));

    final linesBefore = 2;
    final linesAfter = 2;
    final fromLine = line - linesBefore;
    final toLine = line + linesAfter + 1;

    var codeLines = sourceCode.split('\n');
    for (lineNumber in fromLine...toLine) {
        if (lineNumber <= 0 || lineNumber > codeLines.length) continue;
        var lpad = '$toLine'.length > '$lineNumber'.length;
        var lineDecoration = (lpad ? ' ' : '') + '$lineNumber | ';
        var codeLine = codeLines[lineNumber - 1];
        if (lineNumber == line) {
            final col = switch pos {
                case Line(line): 0;
                case Token(token): token.position;
                case Pos(line, col, len): col;
            };
            final len = switch pos {
                case Line(line): codeLine.length;
                case Token(token): token.lexeme.length;
                case Pos(line, col, len): len;
            };
            println(color(lineDecoration, errorType)
                + codeLine.substr(0, col)
                + color(codeLine.substr(col, len), errorType)
                + codeLine.substr(col + len));
            var s = [for (i in 0...(lineDecoration.length + col)) ' '].join('');
            s += color([for (i in 0...len) '^'].join('') + ' ${error.message}', errorType);
            println(s);
        } else {
            println(lineDecoration + codeLine);
        }
    }
    println();
}

function color(text: String, type: LogType): String {
    return text; // TODO: Temp!
    // if (noColors) return text;
    return switch type {
        case RuntimeError: '\033[1;31m$text\033[0m';
        case Error: '\033[1;31m$text\033[0m';
        case Warning: '\033[0;33m$text\033[0m';
        case Hint: '\033[0;36m$text\033[0m';
        case Misc: '\033[0;35m$text\033[0m';
    }
}

function round2(number: Float, precision: Int): Float {
    var num = number;
    num = num * Math.pow(10, precision);
    num = Math.round(num) / Math.pow(10, precision);
    return num;
}

var measureStarts: Map<String, Float> = new Map();
var measureOutput = '';

function startMeasure(tag: String) {
    measureOutput = '';
    measureStarts[tag] = haxe.Timer.stamp();
    // Maybe use haxe.Timer.measure instead?
}

function endMeasure(tag: String) {
    if (!measureStarts.exists(tag)) throw 'Measurement for $tag has not been started';
    var end = haxe.Timer.stamp();
    var duration = (end - measureStarts[tag]) * 1000;
    while (tag.length < 15) tag += ' ';
    measureOutput += '· ';
    measureOutput += Logging.color('$tag took\t${round2(duration, 3)} ms', Logging.LogType.Misc);
    // println(measureOutput);
}
