package cosy;

enum Stmt {
	Block(statements:Array<Stmt>);
	Break(keyword:Token);
	Continue(keyword:Token);
	Expression(e:Expr);
	For(keyword:Token, name:Token, from:Expr, to:Expr, body:Array<Stmt>);
	ForArray(name:Token, array:Expr, body:Array<Stmt>);
	ForCondition(?cond:Expr, body:Array<Stmt>);
	Function(name:Token, params:Array<Param>, body:Array<Stmt>, returnType: cosy.phases.Typer.VariableType, foreign:Bool);
	If(cond:Expr, then:Stmt, el:Stmt);
	Print(keyword:Token, e:Expr);
	Return(keyword:Token, value:Expr);
	Struct(name:Token, declarations:Array<Stmt>);
	Var(name:Token, type: cosy.phases.Typer.VariableType, init:Expr, mut:Bool, foreign:Bool);
}
