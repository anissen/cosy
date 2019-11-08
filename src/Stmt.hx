package;

enum Stmt {
	Block(statements:Array<Stmt>);
	Class(name:Token, superclass:Expr, methods:Array<Stmt>);
	Expression(e:Expr);
	Function(name:Token, params:Array<Token>, body:Array<Stmt>);
	If(cond:Expr, then:Stmt, el:Stmt);
	Print(e:Expr);
	Return(keyword:Token, value:Expr);
	While(cond:Expr, body:Stmt);
	Var(name:Token, init:Expr);
}