package;

enum Expr {
	Assign(name:Token, value:Expr);
	Binary(left:Expr, op:Token, right:Expr);
	Call(callee:Expr, paren:Token, arguments:Array<Expr>);
	Grouping(e:Expr);
	Literal(v:Any);
	Logical(left:Expr, op:Token, right:Expr);
	Unary(op:Token, right:Expr);
	Variable(name:Token);
}