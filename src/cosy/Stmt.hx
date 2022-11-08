package cosy;

import cosy.VariableType;

enum Stmt {
    Block(statements: Array<Stmt>);
    Break(keyword: Token);
    Continue(keyword: Token);
    Expression(e: Expr);
    For(keyword: Token, name: Token, from: Expr, to: Expr, body: Array<Stmt>);
    ForArray(name: Token, array: Expr, body: Array<Stmt>);
    ForCondition(keyword: Token, ?cond: Expr, body: Array<Stmt>);
    Function(name: Token, params: Array<Param>, body: Array<Stmt>, returnType: ComputedVariableType, foreign: Bool);
    If(keyword: Token, cond: Expr, then: Stmt, el: Null<Stmt>);
    Print(keyword: Token, e: Expr);
    Return(keyword: Token, value: Expr);
    Struct(name: Token, declarations: Array<Stmt>);
    Let(name: Token, type: VariableType, init: Expr, mut: Bool, foreign: Bool); // TODO: `type` should be ComputedVariableType
}
