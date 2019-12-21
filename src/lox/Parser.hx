package lox;

class Parser {
	final tokens:Array<Token>;
	var current = 0;
	
	public function new(tokens:Array<Token>) {
		this.tokens = tokens;
	}
	
	public function parse() {
		var statements = [];
		while(!isAtEnd())
			statements.push(declaration());
		return statements;
	}
	
	function expression():Expr {
		return assignment();
	}
	
	function declaration() {
		try {
			if(match([Class])) return classDeclaration();
			if(match([Fun])) return func('function');
			if(match([Var])) return varDeclaration();
			return statement();
		} catch(e:ParseError) {
			synchronize();
			return null;
		}
	}
	
	function statement():Stmt {
        // TODO: this list of match can be optimized by doing switch tokens[current]
		if(match([For])) return forStatement();
		if(match([If])) return ifStatement();
		if(match([Print])) return printStatement();
		if(match([Return])) return returnStatement();
		if(match([LeftBrace])) return Block(block());
		return expressionStatement();
	}
	
	function forStatement():Stmt {
        if (doubleCheck(In)) { // check if the next (not current) token is In
            // for i min..max {
            var name = consume(Identifier, 'Expect variable name.');
            consume(In, 'Expect "in" after for loop identifier.');
            var from = addition();
            consume(DotDot, 'Expect ".." between from and to numbers.');
            var to = addition();
            var body = statement();
            return For(name, from, to, body);
        } else {
            // for CONDITION {
            // for {
            var condition = (check(LeftBrace) ? null : expression());
            var body = statement();
            return ForCondition(condition, body);
        }
	}
	
	function ifStatement():Stmt {
		consume(LeftParen, 'Expect "(" after "if".');
		var condition = expression();
		consume(RightParen, 'Expect ")" after condition.');
		
		var then = statement();
		var el = if(match([Else])) statement() else null;
		return If(condition, then, el);
	}
	
	function printStatement():Stmt {
		var value = expression();
		return Print(value);
	}
	
	function returnStatement():Stmt {
		var keyword = previous();
		//var value = if (check(NewLine)) null else expression();
		var value = expression();
		return Return(keyword, value);
	}
	
	function expressionStatement():Stmt {
		var expr = expression();
		return Expression(expr);
	}
	
	function block():Array<Stmt> {
		var statements = [];
		
		while(!check(RightBrace) && !isAtEnd()) {
			statements.push(declaration());
		}
		
		consume(RightBrace, 'Expect "}" after block.');
		return statements;
	}
	
	function varDeclaration():Stmt {
		var name = consume(Identifier, 'Expect variable name.');
		
		var initializer = null;
		
		if(match([Equal])) initializer = expression();
		
		return Var(name, initializer);
	}
	
	function classDeclaration():Stmt {
		var name = consume(Identifier, 'Expect class name');
		
		var superclass:Expr = 
			if(match([Less])) {
				consume(Identifier, 'Expect superclass name');
				Variable(previous());
			} else null;
		
		consume(LeftBrace, 'Expect "{" before class body.');
		
		var methods = [];
		while(!check(RightBrace) && !isAtEnd())
			methods.push(func('method'));
			
		consume(RightBrace, 'Expect "}" after class body.');
		return Class(name, superclass, methods);
	}

	function func(kind:String):Stmt {
		var name = consume(Identifier, 'Expect $kind name.');
		var functionExpr = funcBody(kind);
		return switch functionExpr {
			case AnonFunction(params, body): Function(name, params, body);
			case _: throw new RuntimeError(name, 'Invalid function declaration.');
		}
	}
	
	function funcBody(kind:String):Expr {
		consume(LeftParen, 'Expect "(" after $kind name.');
		var params = [];
		if(!check(RightParen)) {
			do {
				if(params.length >= 255) error(peek(), 'Cannot have more than 255 parameters.');
				params.push(consume(Identifier, 'Expect parameter name.'));
			} while(match([Comma]));
		}
		
		consume(RightParen, 'Expect ")" after parameters.');
		
		consume(LeftBrace, 'Expect "{" before $kind body');

		var body = block();
		
		return AnonFunction(params, body);
	}
	
	function assignment():Expr {
		var expr = or();
		
		if(match([Equal])) {
			var equals = previous();
			var value = assignment();
			
			switch expr {
				case Variable(name): return Assign(name, value);
				case Get(obj, name): return Set(obj, name, value);
				case _:
			}
			
			error(equals, 'Invalid assignment target.');
		}
		
		return expr;
	}
	
	function or():Expr {
		var expr = and();
		while(match([Or])) {
			var op = previous();
			var right = and();
			expr = Logical(expr, op, right);
		}
		return expr;
	}
	
	function and():Expr {
		var expr = equality();
		while(match([And])) {
			var op = previous();
			var right = equality();
			expr = Logical(expr, op, right);
		}
		return expr;
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
			call();
		}
	}
	
	function call():Expr {
		var expr = primary();
		
		while(true) {
			if(match([LeftParen]))
				expr = finishCall(expr);
			else if(match([Dot])) {
				var name = consume(Identifier, 'Expect property name after ".".');
				expr = Get(expr, name);
			} else
				break;
		}
		
		return expr;
	}
	
	function finishCall(callee:Expr):Expr {
		var args = [];
		if(!check(RightParen)) {
			do {
				if(args.length >= 255) error(peek(), 'Cannot have more than 255 arguments');
				args.push(expression());
			} while(match([Comma]));
		}
		
		var paren = consume(RightParen, 'Expect ")" after arguments.');
		return Call(callee, paren, args);
	}
	
	function primary():Expr {
		if(match([False])) return Literal(false);
		if(match([True])) return Literal(true);
		if(match([Nil])) return Literal(null);
		if(match([Number, String])) return Literal(previous().literal);
		if(match([Super])) {
			var keyword = previous();
			consume(Dot, 'Expect "." after "super".');
			var method = consume(Identifier, 'Expect superclass method name.');
			return Super(keyword, method);
		}
		if(match([This])) return This(previous());
		if(match([Identifier])) return Variable(previous());
		if(match([Fun])) return funcBody("function");
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

    function doubleCheck(type:TokenType) {
		if (isAtEnd()) return false;
        var next = tokens[current + 1];
		if (next.type == Eof) return false;
		return (next.type == type);
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
		return new ParseError();
	}
	
	function synchronize() {
		advance();
		while(!isAtEnd()) {
			switch peek().type {
				case Class | Fun | Var | For | If | Print | Return: return;
				case _: advance();
			}
		}
	}
}

private class ParseError extends Error {}
