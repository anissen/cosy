package cosy.phases;

import cosy.phases.Resolver.Variable;

using cosy.VariableType.VariableTypeTools;

class AstPrinter {
    public function new() {}

    var indentAmount: Int = 0;

    function indent(): String {
        return [for (_ in 0...indentAmount) "    "].join("");
    }

    public function printStmts(stmts: Array<Stmt>): String {
        return [for (stmt in stmts) indent() + printStmt(stmt)].join('\n');
    }

    function printBlock(stmts: Array<Stmt>): String {
        indentAmount++;
        var s = printStmts(stmts);
        indentAmount--;
        return '{\n$s\n${indent()}}';
    }

    function printExprs(exprs: Array<Expr>): String {
        return [for (expr in exprs) indent() + printExpr(expr)].join('\n');
    }

    function printExprBlock(exprs: Array<Expr>): String {
        indentAmount++;
        var s = printExprs(exprs);
        indentAmount--;
        return '{\n$s\n${indent()}}';
    }

    public function printStmt(statement: Stmt): String {
        return switch statement {
            case Block(statements): printBlock(statements);
            case Break(keyword): keyword.lexeme;
            case Continue(keyword): keyword.lexeme;
            case Expression(e): '${printExpr(e)}';
            case For(keyword, name, from, to, body): 'for ${name != null ? name.lexeme + " in " : ""}${printExpr(from)}..${printExpr(to)} ${printBlock(body)}';
            case ForArray(name, array, body): 'for ${name.lexeme} in ${printExpr(array)} ${printBlock(body)}';
            case ForCondition(keyword, cond, body): '${keyword.lexeme} ${cond != null ? printExpr(cond) : ""} ${printBlock(body)}';
            case Function(name, params, body, returnType, foreign):
                var declaration = '${foreign ? "foreign fn" : "fn"} ${name.lexeme}';
                var parameters = formatParams(params);
                var retType = returnType.annotated.formatType(true);
                if (retType != '') retType = ' $retType';
                if (foreign) return '$declaration($parameters)$retType';
                var block = printBlock(body);
                '$declaration($parameters)$retType $block';
            case If(keyword, cond, then, el): '${keyword.lexeme} ${printExpr(cond)} ${printStmt(then)}' + (el != null ? ' else ${printStmt(el)}' : '');
            case Print(keyword, e): '${keyword.lexeme} ${printExpr(e)}';
            case Return(keyword, value): keyword.lexeme + (value != null ? ' ${printExpr(value)}' : '');
            case Struct(name, declarations): 'struct ${name.lexeme} ${printBlock(declarations)}';
            case Let(v, init): '${v.foreign ? "foreign " : ""}${v.mut ? "mut" : "let"} ${v.name.lexeme}' + (init != null ? ' = ${printExpr(init)}' : '');
        }
    }

    public function printExpr(expr: Expr): String {
        return switch expr {
            case ArrayLiteral(keyword, exprs): '[' + [for (expr in exprs) ${printExpr(expr)}].join(',') + ']';
            case Assign(name, op, value): '${name.lexeme} ${op.lexeme} ${printExpr(value)}';
            case Binary(left, op, right): '${printExpr(left)} ${op.lexeme} ${printExpr(right)}';
            case Call(callee, paren, arguments): '${printExpr(callee)}(${[for (arg in arguments) printExpr(arg)].join(', ')})';
            case Get(obj, name): '${printExpr(obj)}.${name.lexeme}';
            case GetIndex(obj, ranged, from, to): '${printExpr(obj)}[${formatIndexRange(ranged, from, to)}]';
            case Grouping(e): '(${printExpr(e)})';
            case Literal(v): if (Std.isOfType(v, String)) {
                    '\'$v\'';
                } else {
                    '$v';
                };
            case Logical(left, op, right): '${printExpr(left)} ${op.type.match(Or) ? 'or' : 'and'} ${printExpr(right)}';
            case MutArgument(keyword, name): 'mut ${name.lexeme}';
            case Set(obj, name, op, value): '${printExpr(obj)}.${name.lexeme} ${op.lexeme} ${printExpr(value)}';
            case SetIndex(obj, ranged, from, to, op, value): '${printExpr(obj)}[${formatIndexRange(ranged, from, to)}] ${op.lexeme} ${printExpr(value)}';
            case StringInterpolation(exprs): "'" + [
                    for (i => expr in exprs) {
                        var e = printExpr(expr);
                        (i % 2 == 0 ? e.substr(1, e.length - 2) : '{$e}');
                    }
                ].join('') + "'";
            case StructInit(name, decls): printExprBlock(decls);
            case Unary(op, right): '${op.lexeme}${printExpr(right)}';
            case Variable(name): name.lexeme;
            case AnonFunction(params, body, returnType):
                var parameters = formatParams(params);
                var block = printStmt(Block(body));
                var retType = returnType.annotated.formatType(true);
                if (retType != '') retType = ' $retType';
                'fn($parameters)$retType $block';
        }
    }

    function formatIndexRange(ranged: Bool, from: Expr, to: Expr): String {
        if (!ranged) return printExpr(from);
        return (from != null ? printExpr(from) : '') + '..' + (to != null ? printExpr(to) : '');
    }

    function formatParams(params: Array<Param>): String {
        return [for (param in params) formatParam(param)].join(", ");
    }

    function formatParam(param: Param): String {
        // Ignore Unknown in this case to leave it out of the prettified code
        var typeStr = param.type.formatType(true);
        if (typeStr != '') typeStr = ' $typeStr';
        return param.name.lexeme + typeStr;
    }
}
