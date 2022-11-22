package cosy;

import cosy.QueryArg;
import cosy.VariableType;

enum Stmt {
    Block(statements: Array<Stmt>);
    Break(keyword: Token);
    Continue(keyword: Token);
    Expression(e: Expr);
    For(keyword: Token, name: Token, from: Expr, to: Expr, body: Array<Stmt>);
    ForArray(name: Token, mut: Bool, array: Expr, body: Array<Stmt>);
    ForCondition(keyword: Token, ?cond: Expr, body: Array<Stmt>);
    Function(name: Token, params: Array<Param>, body: Array<Stmt>, returnType: ComputedVariableType, foreign: Bool);
    If(keyword: Token, cond: Expr, then: Stmt, el: Null<Stmt>);
    Print(keyword: Token, e: Expr);
    Return(keyword: Token, value: Expr);
    Struct(name: Token, declarations: Array<Stmt>);
    Let(v: Variable, init: Expr);

    Query(keyword: Token, queryArgs: Array<QueryArg>, body: Array<Stmt>);
}
