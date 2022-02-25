package cosy;

class Token {
    public final type: TokenType;
    public final lexeme: String;
    public final literal: Null<Any>;
    public final line: Int;
    public final position: Int;

    public function new(type, lexeme, literal, line, position) {
        this.type = type;
        this.lexeme = lexeme;
        this.literal = literal;
        this.line = line;
        this.position = position;
    }

    public function toString(): String {
        return 'Token { type: $type, lexeme: "$lexeme", line: $line' + (literal != null ? ', literal: $literal' : '') + ' }';
    }
}
