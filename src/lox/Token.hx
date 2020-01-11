package lox;

class Token {
	public final type:TokenType;
	public final lexeme:String;
	public final literal:Any;
	public final line:Int;
	
	public function new(type, lexeme, literal, line) {
		this.type = type;
		this.lexeme = lexeme;
		this.literal = literal;
		this.line = line;
	}
	
	public function toString() {
		return '$type $lexeme $literal';
	}
}
