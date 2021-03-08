package cosy;

import cosy.VariableType;

enum Expr {
	ArrayLiteral(keyword:Token, exprs:Array<Expr>);
    Assign(name:Token, op:Token, value:Expr);
	Binary(left:Expr, op:Token, right:Expr);
	Call(callee:Expr, paren:Token, arguments:Array<Expr>);
	Get(obj:Expr, name:Token);
	GetIndex(obj:Expr, index:Expr);
	Grouping(e:Expr);
	Literal(v:Any);
    Logical(left:Expr, op:Token, right:Expr);
    MutArgument(keyword:Token, name:Token);
	Set(obj:Expr, name:Token, value:Expr);
	SetIndex(obj:Expr, index:Expr, value:Expr);
	StructInit(name:Token, decls:Array<Expr>);
	Unary(op:Token, right:Expr);
	Variable(name:Token);
	AnonFunction(params:Array<Param>, body:Array<Stmt>, returnType:ComputedVariableType);
}
