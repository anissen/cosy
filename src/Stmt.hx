package;

enum Stmt {
	Block(statements:Array<Stmt>);
	Expression(e:Expr);
	Print(e:Expr);
	Var(name:Token, init:Expr);
}