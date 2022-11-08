package cosy.phases;

class Parser {
    final tokens: Array<Token>;
    var structNames = new Array<String>();
    var current = 0;
    final logger: cosy.Logging.Logger;

    public function new(tokens: Array<Token>, logger: cosy.Logging.Logger) {
        this.tokens = tokens;
        this.logger = logger;
    }

    public function parse() {
        var statements = [];
        while (!isAtEnd()) statements.push(declaration());
        return statements;
    }

    function expression(): Expr {
        return assignment();
    }

    function declaration(): Stmt {
        try {
            if (match([Struct])) return structDeclaration();
            var foreign = match([Foreign]);
            if (match([Fn])) return func('function', foreign);
            if (match([Let])) return letDeclaration(false, foreign);
            if (match([Mut])) return letDeclaration(true, foreign);
            return statement();
        } catch (e: ParseError) {
            synchronize();
            return null;
        }
    }

    function statement(): Stmt {
        // TODO: this list of match can be optimized by doing switch tokens[current]
        if (match([For])) return forStatement();
        if (match([If])) return ifStatement();
        if (match([Print])) return printStatement();
        if (match([Return])) return returnStatement();
        if (match([Break])) return Break(previous());
        if (match([Continue])) return Continue(previous());
        if (match([LeftBrace])) return Block(block());
        return expressionStatement();
    }

    function forStatement(): Stmt {
        return if (checkUntil(DotDot, LeftBrace)) {
            var keyword = previous();

            // ForMinMax:
            // for 0..10
            // for i in 0..10
            var name = null;
            if (check(Identifier)) {
                name = consume(Identifier, 'Expect variable name.');
                if (name.lexeme.startsWith('_')) error(name, 'Loop counters cannot be marked as unused. Use `for min...max` syntax instead.');
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
            var keyword = previous();
            var condition = (check(LeftBrace) ? null : expression());

            consume(LeftBrace, 'Expect "{" before loop body.');
            var body = block();

            ForCondition(keyword, condition, body);
        }
    }

    function ifStatement(): Stmt {
        var keyword = previous();
        var condition = expression();
        var then = statement();
        var el = if (match([Else])) statement() else null;
        return If(keyword, condition, then, el);
    }

    function printStatement(): Stmt {
        var keyword = previous();
        var value = expression();
        return Print(keyword, value);
    }

    function returnStatement(): Stmt {
        var keyword = previous();
        var value = if (match([Underscore])) null else expression();
        return Return(keyword, value);
    }

    function expressionStatement(): Stmt {
        var expr = expression();
        return Expression(expr);
    }

    function block(): Array<Stmt> {
        var statements = [];
        while (!check(RightBrace) && !isAtEnd()) {
            statements.push(declaration());
        }

        consume(RightBrace, 'Expect "}" after block.');
        return statements;
    }

    function letDeclaration(mut: Bool, foreign: Bool): Stmt {
        var name = consume(Identifier, 'Expect variable name.');
        var type = paramType();

        var initializer = null;
        if (!foreign && match([Equal])) initializer = expression();

        return Let(name, type, initializer, mut, foreign);
    }

    function structDeclaration(): Stmt {
        var name = consume(Identifier, 'Expect struct name');
        consume(LeftBrace, 'Expect "{" before struct body.');

        var declarations = [];
        while (!check(RightBrace) && !isAtEnd()) {
            if (match([Let])) declarations.push(letDeclaration(false, false));
            else if (match([Mut])) declarations.push(letDeclaration(true, false));
            else {
                logger.error(tokens[current], 'Structs can only contain variable definitions.');
                break;
            }
        }

        structNames.push(name.lexeme);

        consume(RightBrace, 'Expect "}" after struct body.');
        return Struct(name, declarations);
    }

    function func(kind: String, foreign: Bool): Stmt {
        var name = consume(Identifier, 'Expect $kind name.');
        var functionExpr = funcBody(kind, foreign);
        return switch functionExpr {
            case AnonFunction(params, body, returnType): Function(name, params, body, returnType, foreign);
            case _: throw new RuntimeError(name, 'Invalid function declaration.');
        }
    }

    function paramType(): VariableType {
        return if (match([BooleanType])) {
            Boolean;
        } else if (match([NumberType])) {
            Number;
        } else if (match([StringType])) {
            Text;
        } else if (match([VoidType])) {
            Void;
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
        } else if (check(Identifier) && structNames.indexOf(peek().lexeme) != -1) {
            var identifier = advance();
            NamedStruct(identifier.lexeme);
        } else {
            Unknown;
        }
    }

    function funcBody(kind: String, foreign: Bool): Expr {
        consume(LeftParen, 'Expect "(" after $kind name.');
        var params: Array<Param> = [];
        if (!check(RightParen)) {
            do {
                if (params.length >= 255) error(peek(), 'Cannot have more than 255 parameters.');
                var mutable = match([Mut]);
                var name = consume(Identifier, 'Expect parameter name.');
                var type = paramType();
                if (mutable) {
                    switch type {
                        case NamedStruct(_):
                        case Unknown:
                        case Array(_):
                        case _: error(name, 'Only struct and array parameters can be marked as `mut`.');
                    }
                    type = Mutable(type);
                }
                params.push({name: name, type: type});
            } while (match([Comma]));
        }

        consume(RightParen, 'Expect ")" after parameters.');
        var returnType = paramType();
        // if (returnType.match(Unknown)) returnType = Void; // implicit Void

        if (foreign) {
            return AnonFunction(params, [], {annotated: returnType});
        }

        consume(LeftBrace, 'Expect "{" before $kind body');
        var body = block();
        return AnonFunction(params, body, {annotated: returnType});
    }

    function assignment(): Expr {
        var expr = or();

        if (match([Equal, PlusEqual, MinusEqual, SlashEqual, StarEqual, PercentEqual])) {
            var op = previous();
            var value = assignment();

            switch expr {
                case Variable(name): return Assign(name, op, value);
                case Get(obj, name): return Set(obj, name, op, value);
                case GetIndex(obj, ranged, from, to): return SetIndex(obj, ranged, from, to, op, value);
                case _:
            }

            error(op, 'Invalid assignment target.');
        }

        return expr;
    }

    function or(): Expr {
        var expr = and();

        while (match([Or])) {
            var op = previous();
            var right = and();
            expr = Logical(expr, op, right);
        }

        return expr;
    }

    function and(): Expr {
        var expr = equality();

        while (match([And])) {
            var op = previous();
            var right = equality();
            expr = Logical(expr, op, right);
        }

        return expr;
    }

    function equality(): Expr {
        var expr = comparison();

        while (match([BangEqual, EqualEqual])) {
            var op = previous();
            var right = comparison();
            expr = Binary(expr, op, right);
        }

        return expr;
    }

    function comparison(): Expr {
        var expr = addition();

        while (match([Greater, GreaterEqual, Less, LessEqual])) {
            var op = previous();
            var right = addition();
            expr = Binary(expr, op, right);
        }

        return expr;
    }

    function addition(): Expr {
        var expr = multiplication();

        while (match([Minus, Plus])) {
            var op = previous();
            var right = multiplication();
            expr = Binary(expr, op, right);
        }

        return expr;
    }

    function multiplication(): Expr {
        var expr = unary();

        while (match([Slash, Percent, Star])) {
            var op = previous();
            var right = unary();
            expr = Binary(expr, op, right);
        }

        return expr;
    }

    function unary(): Expr {
        return if (match([Bang, Minus])) {
            var op = previous();
            var right = unary();
            Unary(op, right);
        } else {
            call();
        }
    }

    function call(): Expr {
        var expr = primary();

        while (true) {
            if (match([LeftParen])) {
                expr = finishCall(expr);
            } else if (match([Dot])) {
                var name = consume(Identifier, 'Expect property name after ".".');
                expr = Get(expr, name);
            } else if (match([LeftBracket])) {
                // cases: x[5], x[..], x[3..], x[..5], x[3..5]
                var from = null;
                var to = null;
                if (!check(DotDot)) {
                    from = expression();
                }
                var ranged = false;
                if (check(DotDot)) {
                    ranged = true;
                    consume(DotDot, 'Expect ".." after "from" in slice range.');
                    if (!check(RightBracket)) {
                        to = expression();
                    }
                }
                if (!ranged && to == null && from == null) {
                    error(peek(), 'Expect index for random access or ".." for slice range.');
                }
                expr = GetIndex(expr, ranged, from, to); // TODO: How to find a token as keyword?
                consume(RightBracket, 'Expect "}" after array indexing.');
            } else {
                break;
            }
        }

        return expr;
    }

    function finishCall(callee: Expr): Expr {
        var args: Array<Expr> = [];
        if (!check(RightParen)) {
            do {
                if (args.length >= 255) error(peek(), 'Cannot have more than 255 arguments');
                args.push(expression());
            } while (match([Comma]));
        }

        var paren = consume(RightParen, 'Expect ")" after arguments.');
        // trace(callee);
        // var k = new KeywordVisitor();
        // var xxx = k.getExprKeywords([callee]);
        // trace([for (x in xxx) x.lexeme].join('.'));
        // return Call(callee, xxx[xxx.length - 1], args);
        return Call(callee, paren, args);
    }

    function primary(): Expr {
        if (match([False])) return Literal(false);
        if (match([True])) return Literal(true);
        if (match([Number])) return Literal(previous().literal);
        if (match([String])) return string();
        if (match([Fn])) return funcBody("function", false);
        if (match([Identifier])) return identifier();
        if (match([Mut])) return MutArgument(previous(), consume(Identifier, 'Expect variable name after "mut".'));
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

    function arrayLiteral(): Expr {
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
            var decls = [];
            while (!match([RightBrace]) && !isAtEnd()) {
                decls.push(assignment());
                if (!check(RightBrace)) consume(Comma, 'Expect "," between variable initializers.');
            }
            return StructInit(variable, decls);
        } else {
            return Variable(variable);
        }
    }

    function string(): Expr {
        final expr = Expr.Literal(previous().literal);
        if (check(StringInterpolationStart)) {
            var exprs = [expr];
            do {
                if (match([StringInterpolationStart])) {
                    exprs.push(expression());
                    consume(StringInterpolationEnd, 'Expect "}" after string interpolation start.');
                } else if (match([String])) {
                    exprs.push(string());
                } else {
                    error(peek(), 'Unexpected token in string interpolation.');
                }
            } while (check(StringInterpolationStart) || check(String));
            return Expr.StringInterpolation(exprs);
        } else {
            return expr;
        }
    }

    function consume(type: TokenType, message: String): Token {
        if (check(type)) return advance();
        throw error(peek(), message);
    }

    function match(types: Array<TokenType>): Bool {
        for (type in types) {
            if (check(type)) {
                advance();
                return true;
            }
        }
        return false;
    }

    function check(type: TokenType): Bool {
        if (isAtEnd()) return false;
        return peek().type == type;
    }

    function checkUntil(type: TokenType, until: TokenType): Bool {
        var cur = current;
        do {
            if (tokens[cur].type == type) return true;
            cur++;
        } while (tokens[cur].type != until && tokens[cur].type != Eof);
        return false;
    }

    function advance(): Token {
        if (!isAtEnd()) current++;
        return previous();
    }

    function isAtEnd(): Bool {
        return peek().type == Eof;
    }

    function peek(): Token {
        return tokens[current];
    }

    function previous(): Token {
        return tokens[current - 1];
    }

    function error(token: Token, message: String) {
        logger.error(token, message);
        return new ParseError();
    }

    function synchronize() {
        advance();
        while (!isAtEnd()) {
            switch peek().type {
                case Break | Continue | Fn | Let | Foreign | For | If | Print | Return | Struct: return;
                case _: advance();
            }
        }
    }
}

private class ParseError extends Error {}
