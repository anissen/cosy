package cosy.phases;

import cosy.TokenType;

class Scanner {
    final source: String;
    final tokens: Array<Token> = [];

    static final keywords = [
        'and' => And, 'break' => Break, 'continue' => Continue, 'else' => Else, 'false' => False, 'for' => For, 'foreign' => Foreign, 'fn' => Fn, 'in' => In,
        'if' => If, 'mut' => Mut, 'or' => Or, 'print' => Print, 'return' => Return, 'struct' => Struct, 'true' => True, 'var' => Var, 'Bool' => BooleanType,
        'Num' => NumberType, 'Str' => StringType, 'Void' => VoidType, 'Fn' => FunctionType, 'Array' => ArrayType,
    ];

    var start = 0;
    var current = 0;
    var line = 1;
    var position = 0;
    var interpolationMode = false;

    public function new(source: String) {
        this.source = source;
    }

    public function scanTokens(): Array<Token> {
        while (!isAtEnd()) {
            start = current;
            scanToken();
        }
        tokens.push(new Token(Eof, '', null, line, position));
        return tokens;
    }

    inline function scanToken() {
        final c = advance();
        switch c {
            case '('.code: addToken(LeftParen);
            case ')'.code: addToken(RightParen);
            case '{'.code: addToken(interpolationMode ? StringInterpolationEnd : LeftBrace);
            case '}'.code:
                if (interpolationMode) {
                    addToken(StringInterpolationEnd);
                    interpolationMode = false;
                    string(); // the lexeme is wrong!
                } else {
                    addToken(RightBrace);
                }
            case '['.code: addToken(LeftBracket);
            case ']'.code: addToken(RightBracket);
            case ','.code: addToken(Comma);
            case '-'.code: addToken(match('='.code) ? MinusEqual : Minus);
            case '+'.code: addToken(match('='.code) ? PlusEqual : Plus);
            case '*'.code: addToken(match('='.code) ? StarEqual : Star);
            case '%'.code: addToken(match('='.code) ? PercentEqual : Percent);
            case '_'.code if (!isAlpha(peek())): addToken(Underscore);
            case '.'.code: addToken(match('.'.code) ? DotDot : Dot);
            case '!'.code: addToken(match('='.code) ? BangEqual : Bang);
            case '='.code: addToken(match('='.code) ? EqualEqual : Equal);
            case '<'.code: addToken(match('='.code) ? LessEqual : Less);
            case '>'.code: addToken(match('='.code) ? GreaterEqual : Greater);
            case '/'.code:
                if (match('/'.code)) {
                    while (peek() != '\n'.code && !isAtEnd()) advance();
                } else {
                    addToken(match('='.code) ? SlashEqual : Slash);
                }
            case ' '.code | '\r'.code | '\t'.code: // Ignore whitespace.
            case '\n'.code:
                line++;
                position = 0;
            case '\''.code: string();
            case '"'.code: rawString();
            case _:
                if (isDigit(c)) {
                    number();
                } else if (isAlpha(c)) {
                    identifier();
                } else {
                    Cosy.error(line, 'Unexpected character: ${std.String.fromCharCode(c)}');
                }
        }
    }

    function identifier() {
        while (isAlphaNumeric(peek())) advance();

        final text = source.substring(start, current);
        final type: TokenType = switch keywords[text] {
            case null: Identifier;
            case v: v;
        }

        addToken(type);
    }

    function string() {
        while ((peek() != '\''.code || peekPrevious() == '\\'.code) && !isAtEnd()) {
            // It is a string interpolation type string
            // Output:
            // String
            // 		// repeat for each {}-pair
            // 		StringInterpolationStart
            // 		{Interpolation tokens}
            // 		StringInterpolationEnd
            // 		(String)
            if (peek() == '{'.code) {
                var value = source.substring(start + 1, current);
                value = value.replace('\\n', '\n');
                value = value.replace('\\t', '\t');
                value = value.replace('\\\'', '\'');
                addToken(String, value);

                start = current;
                advance(); // Skip '{'
                addToken(StringInterpolationStart);
                start = current;
                interpolationMode = true;
                return;
            }
            if (peek() == '\n'.code) line++;
            advance();
        }

        if (isAtEnd()) {
            Cosy.error(line, 'Unterminated string.');
            return;
        }

        // The closing '
        advance();

        var value = source.substring(start + 1, current - 1);
        value = value.replace('\\n', '\n');
        value = value.replace('\\t', '\t');
        value = value.replace('\\\'', '\'');
        addToken(String, value);
    }

    function rawString() {
        while (peek() != '"'.code && !isAtEnd()) {
            if (peek() == '\n'.code) line++;
            advance();
        }

        if (isAtEnd()) {
            Cosy.error(line, 'Unterminated raw string.');
            return;
        }

        // The closing "
        advance();

        var value = source.substring(start + 1, current - 1);
        addToken(String, value);
    }

    function number() {
        while (isDigit(peek())) advance();

        if (peek() == '.'.code && isDigit(peekNext())) {
            advance();
            while (isDigit(peek())) advance();
        }

        addToken(Number, Std.parseFloat(source.substring(start, current)));
    }

    inline function isDigit(c: Int) {
        return c >= '0'.code && c <= '9'.code;
    }

    inline function isAlpha(c: Int) {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || c == '_'.code;
    }

    inline function isAlphaNumeric(c: Int) {
        return isAlpha(c) || isDigit(c);
    }

    function match(expected: Int) {
        if (isAtEnd()) return false;
        if (source.charCodeAt(current) != expected) return false;
        current++;
        position++;
        return true;
    }

    inline function peek() {
        if (isAtEnd()) return 0;
        return source.charCodeAt(current);
    }

    inline function peekNext() {
        if (current + 1 >= source.length) return 0;
        return source.charCodeAt(current + 1);
    }

    inline function peekPrevious() {
        if (current - 1 >= source.length) return 0;
        return source.charCodeAt(current - 1);
    }

    function advance(): Int {
        current++;
        position++;
        return source.charCodeAt(current - 1);
    }

    inline function addToken(type: TokenType, ?literal: Any) {
        tokens.push(new Token(type, source.substring(start, current), literal, line, position - (current - start)));
    }

    inline function isAtEnd() {
        return current >= source.length;
    }
}
