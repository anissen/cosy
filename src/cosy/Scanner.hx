package cosy;

import cosy.TokenType;

class Scanner {
	final source:String;
	final tokens:Array<Token> = [];
	
	static final keywords = [
		'and' => And,
		'class' => Class, // TODO: remove
		'else' => Else,
		'false' => False,
		'for' => For,
		'fn' => Fn,
		'in' => In,
		'if' => If,
		'mut' => Mut,
		'or' => Or,
		'print' => Print,
		'return' => Return,
		'struct' => Struct,
		'super' => Super, // TODO: remove
		'this' => This, // TODO: remove
		'true' => True,
		'var' => Var,
		'Bool' => BooleanType,
		'Num' => NumberType,
		'Str' => StringType,
		'Fn' => FunctionType,
		'Array' => ArrayType,
	];
	
	var start = 0;
	var current = 0;
	var line = 1;
	
	public function new(source) {
		this.source = source;
	}
	
	public function scanTokens() {
		while(!isAtEnd()) {
			start = current;
			scanToken();
		}
		tokens.push(new Token(Eof, '', null, line));
		return tokens;
	}
	
	function scanToken() {
		var c = advance();
		switch c {
			case '('.code: addToken(LeftParen);
			case ')'.code: addToken(RightParen);
			case '{'.code: addToken(LeftBrace);
			case '}'.code: addToken(RightBrace);
			case '['.code: addToken(LeftBracket);
			case ']'.code: addToken(RightBracket);
			case ','.code: addToken(Comma);
			// case ':'.code: addToken(Colon);
			case '-'.code: addToken(Minus);
			case '+'.code: addToken(Plus);
			case '*'.code: addToken(Star);
			case '_'.code if (!isAlpha(peek())): addToken(Underscore);
			case '.'.code: addToken(match('.'.code) ? DotDot : Dot);
			case '!'.code: addToken(match('='.code) ? BangEqual : Bang);
			case '='.code: addToken(match('='.code) ? EqualEqual : Equal);
			case '<'.code: addToken(match('='.code) ? LessEqual : Less);
			case '>'.code: addToken(match('='.code) ? GreaterEqual : Greater);
			case '/'.code:
				if(match('/'.code)) {
					while(peek() != '\n'.code && !isAtEnd()) advance();
				} else {
					addToken(Slash);
				}
			case ' '.code | '\r'.code | '\t'.code: // Ignore whitespace.
			case '\n'.code: line++;
			case '\''.code: string();
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
		while(isAlphaNumeric(peek())) advance();
		
		var text = source.substring(start, current);
		var type = switch keywords[text] {
			case null: Identifier;
			case v: v;
		}
		
		addToken(type);
	}
	
	function string() {
		while ((peek() != '\''.code || peekPrevious() == '\\'.code) && !isAtEnd()) {
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
		addToken(String, StringTools.replace(value, '\\\'', '\''));
	}
	
	function number() {
		while(isDigit(peek())) advance();
		
		if (peek() == '.'.code && isDigit(peekNext())) {
			advance();
			while(isDigit(peek())) advance();
		}
		
		addToken(Number, Std.parseFloat(source.substring(start, current)));
	}
	
	function isDigit(c:Int) {
		return c >= '0'.code && c <= '9'.code;
	}
	
	function isAlpha(c:Int) {
		return (c >= 'a'.code && c <= 'z'.code) ||
		       (c >= 'A'.code && c <= 'Z'.code) ||
		        c == '_'.code;
	}

	function isAlphaNumeric(c:Int) {
		return isAlpha(c) || isDigit(c);
	}
	
	function match(expected:Int) {
		if (isAtEnd()) return false;
		if (source.charCodeAt(current) != expected) return false;
		current++;
		return true;
	}
	
	function peek() {
		if (isAtEnd()) return 0;
		return source.charCodeAt(current);
	}
	
	function peekNext() {
		if (current + 1 >= source.length) return 0;
		return source.charCodeAt(current + 1);
    }
    
    function peekPrevious() {
		if (current - 1 >= source.length) return 0;
		return source.charCodeAt(current - 1);
	}
	
	function advance():Int {
		current++;
		return source.charCodeAt(current - 1);
	}
	
	function addToken(type:TokenType, ?literal:Any) {
		var text = source.substring(start, current);
		tokens.push(new Token(type, text, literal, line));
	}
	
	function isAtEnd() {
		return current >= source.length;
	}
}
