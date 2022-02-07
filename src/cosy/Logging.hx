package cosy;

enum Color {
    Error;
    Warning;
    Hint;
    Misc;
}

enum ErrorDataType {
    Line(v: Int);
    Token(v: Token);
}

abstract ErrorData(ErrorDataType) from ErrorDataType to ErrorDataType {
    @:from inline static function line(v: Int): ErrorData return Line(v);

    @:from inline static function token(v: Token): ErrorData return Token(v);
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

function reportWarning(line: Int, where: String, message: String) {
    var msg = '[line $line] Warning $where: $message';
    println(color(msg, Warning));
}

function warning(data: ErrorData, message: String) {
    switch data {
        case Line(line): reportWarning(line, '', message);
        case Token(token) if (token.type == Eof): reportWarning(token.line, 'at end', message);
        case Token(token): reportWarning(token.line, 'at "${token.lexeme}"', message);
    }
}

function report(/* fileName: String, sourceCode: String, */ line: Int, token: Null<Token>, message: String) {
    final fileName = '(placeholder)';
    final sourceCode = '';
    println('■' + color(' $fileName, line $line:', Misc));

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
        if (lineNumber == line && token != null) {
            final pos = token.position;
            final lexeme = token.lexeme;
            println(color(lineDecoration, Error) + replaceSubstring(codeLine, pos, lexeme.length, color(lexeme, Error)));
            var s = [for (i in 0...(lineDecoration.length + pos)) ' '].join('');
            s += color([for (i in 0...lexeme.length) '^'].join('') + ' $message', Error);
            println(s);
        } else {
            if (lineNumber == line) lineDecoration = color(lineDecoration, Error);
            println(lineDecoration + codeLine);
        }
    }
    println();
}

function error(data: ErrorData, message: String) {
    switch data {
        case Line(line): report(line, null, message);
        case Token(token): report(token.line, token, message);
    }
}

function replaceSubstring(str: String, start: Int, length: Int, replaceWith: String) {
    return str.substr(0, start) + replaceWith + str.substr(start + length);
}

function hint(token: Token, message: String) {
    var msg = '[line ${token.line}] Hint: $message';
    println(color(msg, Hint));
}

function runtimeError(e: RuntimeError) {
    var msg = '[line ${e.token.line}] Runtime Error: ${e.message}';
    println(color(msg, Error));
    trace(msg);
}

function color(text: String, color: Color): String {
    return switch color {
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
    measureOutput += Logging.color('$tag took\t${round2(duration, 3)} ms', Logging.Color.Misc);
    println(measureOutput);
}
