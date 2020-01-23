package cosy;

enum Stmt {
	Block(statements:Array<Stmt>);
	Class(name:Token, superclass:Expr, methods:Array<Stmt>);
	Expression(e:Expr);
	For(name:Token, from:Expr, to:Expr, body:Array<Stmt>);
	ForCondition(?cond:Expr, body:Array<Stmt>);
	Function(name:Token, params:Array<Param>, body:Array<Stmt>, returnType:Typer.VariableType);
	If(cond:Expr, then:Stmt, el:Stmt);
	Mut(name:Token, init:Expr);
	Print(e:Expr);
	Return(keyword:Token, value:Expr);
	Var(name:Token, init:Expr);
}
