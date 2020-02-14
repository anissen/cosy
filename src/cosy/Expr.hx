package cosy;

enum Expr {
	ArrayLiteral(keyword:Token, exprs:Array<Expr>);
    Assign(name:Token, value:Expr);
	Binary(left:Expr, op:Token, right:Expr);
	Call(callee:Expr, paren:Token, arguments:Array<Expr>);
	Get(obj:Expr, name:Token);
	Grouping(e:Expr);
	Literal(v:Any);
	Logical(left:Expr, op:Token, right:Expr);
	Set(obj:Expr, name:Token, value:Expr);
	This(keyword:Token);
	Super(keyword:Token, method:Token);
	StructInit(name:Token, decls:Array<Expr>);
	Unary(op:Token, right:Expr);
	Variable(name:Token);
	AnonFunction(params:Array<Param>, body:Array<Stmt>, returnType:Typer.VariableType);
}
