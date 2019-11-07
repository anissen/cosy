package;

class Parser {
	final tokens:Array<Token>;
	var current = 0;
	
	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}
	
	public function parse() {
		return try {
			expression();
		} catch(e:ParserError) {
			null;
		}
	}
	
	function expression():Expr {
		return equality();
	}
	
	function equality():Expr {
		var expr = comparison();
		
		while(match([BangEqual, EqualEqual])) {
			var op = previous();
			var right = comparison();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function comparison():Expr {
		var expr = addition();
		
		while(match([Greater, GreaterEqual, Less, LessEqual])) {
			var op = previous();
			var right = addition();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function addition():Expr {
		var expr = multiplication();
		
		while(match([Minus, Plus])) {
			var op = previous();
			var right = multiplication();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function multiplication():Expr {
		var expr = unary();
		
		while(match([Star, Slash])) {
			var op = previous();
			var right = multiplication();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function unary():Expr {
		return if(match([Bang, Minus])) {
			var op = previous();
			var right = unary();
			Unary(op, right);
		} else {
			primary();
		}
	}
	
	function primary():Expr {
		if(match([False])) return Literal(false);
		if(match([True])) return Literal(true);
		if(match([Nil])) return Literal(null);
		if(match([Number, String])) return Literal(previous().literal);
		if(match([LeftParen])) {
			var expr = expression();
			consume(RightParen, 'Expect ")" after expression.');
			return Grouping(expr);
		}
		throw error(peek(), 'Expect expression.');
	}
	
	function consume(type:TokenType, message:String) {
		if(check(type)) return advance();
		throw error(peek(), message);
	}
	
	function match(types:Array<TokenType>) {
		for(type in types) {
			if(check(type)) {
				advance();
				return true;
			}
		}
		return false;
	}
	
	function check(type:TokenType) {
		if(isAtEnd()) return false;
		return peek().type == type;
	}
	
	function advance() {
		if(!isAtEnd()) current++;
		return previous();
	}
	
	function isAtEnd() {
		return peek().type == Eof;
	}
	
	function peek() {
		return tokens[current];
	}
	
	function previous() {
		return tokens[current - 1];
	}
	
	function error(token:Token, message:String) {
		Lox.error(token, message);
		return new ParserError();
	}
	
	function synchronize() {
		advance();
		while(!isAtEnd()) {
			if(previous().type == Semicolon) return;
			switch peek().type {
				case Class | Fun | Var | For | If | While | Print | Return: return;
				case _:
			}
		}
		advance();
	}
}

private class ParserError extends Error {}