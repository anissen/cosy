package cosy;

class Parser {
	final tokens: Array<Token>;
	var structNames = new Array<String>();
	var current = 0;
	
	public function new(tokens: Array<Token>) {
		this.tokens = tokens;
	}
	
	public function parse() {
		var statements = [];
		while (!isAtEnd())
			statements.push(declaration());
		return statements;
	}
	
	function expression():Expr {
		return assignment();
	}
	
	function declaration() {
		try {
			if (match([Class])) return classDeclaration();
			if (match([Struct])) return structDeclaration();
			if (match([Fn])) return func('function');
			if (match([Var])) return varDeclaration();
			if (match([Mut])) return mutDeclaration();
			return statement();
		} catch (e :ParseError) {
			synchronize();
			return null;
		}
	}
	
	function statement():Stmt {
        // TODO: this list of match can be optimized by doing switch tokens[current]
		if (match([For])) return forStatement();
		if (match([If])) return ifStatement();
		if (match([Print])) return printStatement();
		if (match([Return])) return returnStatement();
		if (match([LeftBrace])) return Block(block());
		return expressionStatement();
	}

	function forStatement():Stmt {
       return if (checkUntil(DotDot, LeftBrace)) {
            var keyword = previous();

            // ForMinMax:
            // for 0..10
            // for i in 0..10
            var name = null;
            if (check(Identifier)) {
                name = consume(Identifier, 'Expect variable name.');
                if (StringTools.startsWith(name.lexeme, '_')) error(name, 'Loop counters cannot be marked as unused. Use `for min...max` syntax instead.');
                consume(In, 'Expect "in" after for loop identifier.');
            }

            var from = expression();
            consume(DotDot, 'Expect ".." between from and to numbers.');
            var to = expression();
            
            consume(LeftBrace, 'Expect "{" before loop body.');    
            var body = block();
            
            For(keyword, name, from, to, body);
        } else if (checkUntil(In, LeftBrace)) {
            // ForArray:
            // for i in [3,4,5]
            var name = consume(Identifier, 'Expect variable name.');
            consume(In, 'Expect "in" after for loop identifier.');

            var array = expression();
            
            consume(LeftBrace, 'Expect "{" before loop body.');    
            var body = block();
            
            ForArray(name, array, body);
        } else {
            // ForCondition:
            // for i < 10
            // for
            var condition = (check(LeftBrace) ? null : expression());
                
            consume(LeftBrace, 'Expect "{" before loop body.');
            var body = block();
            
            ForCondition(condition, body);
        }
	}
	
	function ifStatement():Stmt {
		var condition = expression();
		var then = statement();
		var el = if (match([Else])) statement() else null;
		return If(condition, then, el);
	}
	
	function printStatement():Stmt {
		var value = expression();
		return Print(value);
	}
	
	function returnStatement():Stmt {
		var keyword = previous();
		var value = if (match([Underscore])) null else expression();
		return Return(keyword, value);
	}
	
	function expressionStatement():Stmt {
		var expr = expression();
		return Expression(expr);
	}
	
	function block():Array<Stmt> {
		var statements = [];
		while (!check(RightBrace) && !isAtEnd()) {
			statements.push(declaration());
		}
		
		consume(RightBrace, 'Expect "}" after block.');
		return statements;
	}
	
	function varDeclaration():Stmt {
        var name = consume(Identifier, 'Expect variable name.');
        var type = paramType();
		
		var initializer = null;
		if (match([Equal])) initializer = expression();
		
		return Var(name, type, initializer);
	}
    
    function mutDeclaration():Stmt {
        var name = consume(Identifier, 'Expect variable name.');
        var type = paramType();
		
		var initializer = null;
		if (match([Equal])) initializer = expression();
		
		return Mut(name, type, initializer);
	}
	
	function classDeclaration():Stmt {
		var name = consume(Identifier, 'Expect class name');
		
		var superclass:Expr = 
			if (match([Less])) {
				consume(Identifier, 'Expect superclass name');
				Variable(previous());
			} else null;
		
		consume(LeftBrace, 'Expect "{" before class body.');
		
		var methods = [];
		while (!check(RightBrace) && !isAtEnd())
			methods.push(func('method'));
			
		consume(RightBrace, 'Expect "}" after class body.');
		return Class(name, superclass, methods);
	}
    
    function structDeclaration(): Stmt {
		var name = consume(Identifier, 'Expect class name');
        consume(LeftBrace, 'Expect "{" before struct body.');

        var declarations = [];
        while (!check(RightBrace) && !isAtEnd()) {
            if (match([Var])) declarations.push(varDeclaration());
            else if (match([Mut])) declarations.push(mutDeclaration());
            else {
                Cosy.error(tokens[current], 'Structs can only contain variable definitions.');
                break;
            }
        }

        structNames.push(name.lexeme);
        
		consume(RightBrace, 'Expect "}" after struct body.');
		return Struct(name, declarations); //TODO: Add struct definitions type as arg
	}

	function func(kind:String):Stmt {
        var name = consume(Identifier, 'Expect $kind name.');
		var functionExpr = funcBody(kind);
		return switch functionExpr {
			case AnonFunction(params, body, returnType): Function(name, params, body, returnType);
			case _: throw new RuntimeError(name, 'Invalid function declaration.');
		}
    }
    
    function paramType() :Typer.VariableType {
        return if (match([BooleanType])) {
            Boolean;
        } else if (match([NumberType])) {
            Number;
        } else if (match([StringType])) {
            Text;
        } else if (match([FunctionType])) {
            consume(LeftParen, 'Expect "(" after Fun.');
            var funcParamTypes = [];
            while (!check(RightParen)) {
                funcParamTypes.push(paramType());
                if (!match([Comma])) break;
            }
            consume(RightParen, 'Expect ")" after parameters.');
            var returnType = paramType();
            if (returnType.match(Unknown)) returnType = Void; // implicit Void
            Function(funcParamTypes, returnType);
        } else if (match([ArrayType])) {
            Array(paramType());
        } else {
            Unknown;
        }
    }
	
	function funcBody(kind:String):Expr {
		consume(LeftParen, 'Expect "(" after $kind name.');
		var params = [];
		if (!check(RightParen)) {
			do {
				if (params.length >= 255) error(peek(), 'Cannot have more than 255 parameters.');
                var name = consume(Identifier, 'Expect parameter name.');
                params.push({ name: name, type: paramType() });
			} while (match([Comma]));
		}
		
		consume(RightParen, 'Expect ")" after parameters.');
        
        var returnType = paramType();
        // if (returnType.match(Unknown)) returnType = Void; // implicit Void

		consume(LeftBrace, 'Expect "{" before $kind body');

		var body = block();
		
		return AnonFunction(params, body, returnType);
	}
	
	function assignment():Expr {
		var expr = or();
		
		if (match([Equal])) {
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
		while (match([Or])) {
			var op = previous();
			var right = and();
			expr = Logical(expr, op, right);
		}
		return expr;
	}
	
	function and():Expr {
		var expr = equality();
		while (match([And])) {
			var op = previous();
			var right = equality();
			expr = Logical(expr, op, right);
		}
		return expr;
	}
	
	function equality():Expr {
		var expr = comparison();
		
		while (match([BangEqual, EqualEqual])) {
			var op = previous();
			var right = comparison();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function comparison():Expr {
		var expr = addition();
		
		while (match([Greater, GreaterEqual, Less, LessEqual])) {
			var op = previous();
			var right = addition();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function addition():Expr {
		var expr = multiplication();
		
		while (match([Minus, Plus])) {
			var op = previous();
			var right = multiplication();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function multiplication():Expr {
		var expr = unary();
		
		while (match([Star, Slash])) {
			var op = previous();
			var right = multiplication();
			expr = Binary(expr, op, right);
		}
		
		return expr;
	}
	
	function unary():Expr {
		return if (match([Bang, Minus])) {
			var op = previous();
			var right = unary();
			Unary(op, right);
		} else {
			call();
		}
	}
	
	function call():Expr {
		var expr = primary();
		
		while (true) {
			if (match([LeftParen])) {
				expr = finishCall(expr);
            } else if (match([Dot])) {
				var name = consume(Identifier, 'Expect property name after ".".');
				expr = Get(expr, name);
			} else {
                break;
            }
		}
		
		return expr;
	}
	
	function finishCall(callee:Expr):Expr {
		var args = [];
		if (!check(RightParen)) {
			do {
				if (args.length >= 255) error(peek(), 'Cannot have more than 255 arguments');
				args.push(expression());
			} while (match([Comma]));
		}
		
		var paren = consume(RightParen, 'Expect ")" after arguments.');
		return Call(callee, paren, args);
	}
	
	function primary():Expr {
		if (match([False])) return Literal(false);
		if (match([True])) return Literal(true);
		if (match([Number, String])) return Literal(previous().literal);
		if (match([Super])) {
			var keyword = previous();
			consume(Dot, 'Expect "." after "super".');
			var method = consume(Identifier, 'Expect superclass method name.');
			return Super(keyword, method);
		}
		if (match([This])) return This(previous());
		if (match([Fn])) return funcBody("function");
		if (match([Identifier])) return identifier();
		if (match([LeftParen])) {
			var expr = expression();
			consume(RightParen, 'Expect ")" after expression.');
			return Grouping(expr);
        }
        if (match([LeftBracket])) {
            return arrayLiteral();
        }
		throw error(peek(), 'Expect expression.');
    }
    
    function arrayLiteral():Expr {
        var keyword = previous();
        var exprs = [];
        while (!check(RightBracket) && !isAtEnd()) {
            exprs.push(expression());
            if (!check(RightBracket)) {
                consume(Comma, 'Expect "," between array values.');
            }
        }
        consume(RightBracket, 'Expect "]" after array literal.');
        return ArrayLiteral(keyword, exprs);
    }

    function identifier(): Expr {
        var variable = previous();
        if (check(LeftBrace) && structNames.indexOf(variable.lexeme) != -1) {
            consume(LeftBrace, 'Expect "{" after struct name.');
            // trace('variable: $variable, ${variable.line}');
            var decls = [];
            while (!match([RightBrace]) && !isAtEnd()) {
                decls.push(assignment());
                if (!check(RightBrace)) consume(Comma, 'Expect "," between variable initializers.');
            }
            // trace('done');
            return StructInit(variable, decls);
        } else {
            return Variable(variable);
        }
    }
	
	function consume(type:TokenType, message:String):Token {
		if (check(type)) return advance();
		throw error(peek(), message);
	}
	
	function match(types:Array<TokenType>):Bool {
		for (type in types) {
			if (check(type)) {
				advance();
				return true;
			}
		}
		return false;
	}
	
	function check(type:TokenType):Bool {
		if (isAtEnd()) return false;
		return peek().type == type;
	}

    function checkUntil(type:TokenType, until:TokenType):Bool {
        var cur = current;
        do {
            if (tokens[cur].type == type) return true;
            cur++;
        } while (tokens[cur].type != until && tokens[cur].type != Eof);
        return false;
	}
	
	function advance():Token {
		if (!isAtEnd()) current++;
		return previous();
	}
	
	function isAtEnd():Bool {
		return peek().type == Eof;
	}
	
	function peek():Token {
		return tokens[current];
	}
	
	function previous():Token {
		return tokens[current - 1];
	}
	
	function error(token:Token, message:String) {
		Cosy.error(token, message);
		return new ParseError();
	}
	
	function synchronize() {
		advance();
		while (!isAtEnd()) {
			switch peek().type {
				case Class | Fn | Var | For | If | Print | Return: return;
				case _: advance();
			}
		}
	}
}

private class ParseError extends Error {}

enum LoopType {
    Unknown;
    ForMinMax;
    ForArray;
    ForCondition;
}
