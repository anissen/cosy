package;

enum Stmt {
	Block(statements:Array<Stmt>);
	Expression(e:Expr);
	If(cond:Expr, then:Stmt, el:Stmt);
	Print(e:Expr);
	While(cond:Expr, body:Stmt);
	Var(name:Token, init:Expr);
}