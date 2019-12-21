package lox;

enum Stmt {
	Block(statements:Array<Stmt>);
	Class(name:Token, superclass:Expr, methods:Array<Stmt>);
	Expression(e:Expr);
	For(name:Token, from:Expr, to:Expr, body:Stmt);
	ForCondition(?cond:Expr, body:Stmt);
	Function(name:Token, params:Array<Token>, body:Array<Stmt>);
	If(cond:Expr, then:Stmt, el:Stmt);
	Print(e:Expr);
	Return(keyword:Token, value:Expr);
	Var(name:Token, init:Expr);
}
