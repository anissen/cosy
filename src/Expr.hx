package;

enum Expr {
	Binary(left:Expr, op:Token, right:Expr);
	Grouping(e:Expr);
	Literal(v:Any);
	Unary(op:Token, right:Expr);
}