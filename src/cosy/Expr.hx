package cosy;

import cosy.VariableType;

// enum IndexRange {
//     Single(index: Int);
//     Range(start: Null<Int>, end: Null<Int>);
// }
enum Expr {
    ArrayLiteral(keyword: Token, exprs: Array<Expr>);
    Assign(name: Token, op: Token, value: Expr);
    Binary(left: Expr, op: Token, right: Expr);
    Call(callee: Expr, paren: Token, arguments: Array<Expr>);
    Get(obj: Expr, name: Token); // TODO: `name` should be the first argument
    GetIndex(obj: Expr, ranged: Bool, from: Null<Expr>, to: Null<Expr>);
    Grouping(e: Expr);
    Literal(v: Any);
    Logical(left: Expr, op: Token, right: Expr);
    MutArgument(keyword: Token, name: Token);
    Set(obj: Expr, name: Token, op: Token, value: Expr);
    SetIndex(obj: Expr, ranged: Bool, from: Null<Expr>, to: Null<Expr>, op: Token, value: Expr);
    StructInit(name: Token, decls: Array<Expr>);
    StringInterpolation(parts: Array<Expr>); // n string parts, n - 1 interpolation parts. [str1, interp1, str2, interp2, str3]
    Unary(op: Token, right: Expr);
    Variable(name: Token);
    AnonFunction(params: Array<Param>, body: Array<Stmt>, returnType: ComputedVariableType);
    Print(keyword: Token, e: Expr);

    Spawn(keyword: Token, args: Array<Expr>);
}
