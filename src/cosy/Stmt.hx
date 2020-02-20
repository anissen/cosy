package cosy;

enum Stmt {
	Block(statements:Array<Stmt>);
	Class(name:Token, superclass:Expr, methods:Array<Stmt>);
	Expression(e:Expr);
	For(keyword:Token, name:Token, from:Expr, to:Expr, body:Array<Stmt>);
	ForArray(name:Token, array:Expr, body:Array<Stmt>);
	ForCondition(?cond:Expr, body:Array<Stmt>);
	Function(name:Token, params:Array<Param>, body:Array<Stmt>, returnType:Typer.VariableType);
	If(cond:Expr, then:Stmt, el:Stmt);
	Mut(name:Token, type:Typer.VariableType, init:Expr); // TODO: Merge these two
	Print(e:Expr);
	Return(keyword:Token, value:Expr);
	Struct(name:Token, declarations:Array<Stmt>);
	Var(name:Token, type:Typer.VariableType, init:Expr); // TODO: Merge these two
}
