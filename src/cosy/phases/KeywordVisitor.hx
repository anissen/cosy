package cosy.phases; // TODO: Should be in the cosy package

class KeywordVisitor {
    var keywords: Array<Token> = [];

    public function new() {}

    public function getStmtKeywords(stmts: Array<Stmt>) {
        for (stmt in stmts)
            getKeyword(stmt);
        return keywords;
    }

    public function getExprKeywords(exprs: Array<Expr>) {
        for (expr in exprs)
            getExprKeyword(expr);
        return keywords;
    }

    function getKeyword(statement: Stmt): Void {
        return switch statement {
            case Block(statements): getStmtKeywords(statements);
            case Break(keyword): keywords.push(keyword);
            case Continue(keyword): keywords.push(keyword);
            case Expression(e): getExprKeyword(e);
            case For(keyword, name, from, to, body):
                keywords.push(keyword);
                getExprKeyword(from);
                getExprKeyword(to);
                getStmtKeywords(body);
            case ForArray(name, array, body):
                keywords.push(name);
                getExprKeyword(array);
                getStmtKeywords(body);
            case ForCondition(keyword, cond, body):
                keywords.push(keyword);
                if (cond != null) getExprKeyword(cond);
                getStmtKeywords(body);
            case Function(name, params, body, returnType, foreign):
                keywords.push(name);
                for (param in params)
                    keywords.push(param.name);
                getStmtKeywords(body);
            case If(keyword, cond, then, el):
                keywords.push(keyword);
                getExprKeyword(cond);
                getKeyword(then);
                if (el != null) getKeyword(el);
            case Print(keyword, e):
                keywords.push(keyword);
                getExprKeyword(e);
            case Return(keyword, value):
                keywords.push(keyword);
                if (value != null) getExprKeyword(value);
            case Struct(name, declarations):
                keywords.push(name);
                getStmtKeywords(declarations);
            case Var(name, type, init, mut, foreign):
                keywords.push(name);
                if (init != null) getExprKeyword(init);
        }
    }

    public function getExprKeyword(expr: Expr): Void {
        return switch expr {
            case ArrayLiteral(keyword, exprs):
                keywords.push(keyword);
                getExprKeywords(exprs);
            case Assign(name, op, value):
                keywords.push(name);
                getExprKeyword(value);
            case Binary(left, op, right):
                getExprKeyword(left);
                keywords.push(op);
                getExprKeyword(right);
            case Call(callee, paren, arguments):
                getExprKeyword(callee);
                keywords.push(paren);
                getExprKeywords(arguments);
            case Get(obj, name):
                getExprKeyword(obj);
                keywords.push(name);
            case GetIndex(obj, index):
                getExprKeyword(obj);
                getExprKeyword(index);
            case Grouping(e): getExprKeyword(e);
            case Literal(v):
            case Logical(left, op, right):
                getExprKeyword(left);
                keywords.push(op);
                getExprKeyword(right);
            case MutArgument(keyword, name): keywords.push(keyword);
            case Set(obj, name, op, value):
                getExprKeyword(obj);
                keywords.push(name);
                getExprKeyword(value);
            case SetIndex(obj, index, op, value):
                getExprKeyword(obj);
                getExprKeyword(index);
                getExprKeyword(value);
            case StringInterpolation(parts):
                getExprKeywords(parts);
            case StructInit(name, decls):
                keywords.push(name);
                getExprKeywords(decls);
            case Unary(op, right):
                keywords.push(op);
                getExprKeyword(right);
            case Variable(name):
                keywords.push(name);
            case AnonFunction(params, body, returnType):
                for (param in params)
                    keywords.push(param.name);
                getKeyword(Block(body));
        }
    }
}
