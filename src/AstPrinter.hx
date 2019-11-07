package;

class AstPrinter {
	public function new() {}
	
	public function print(expr:Expr) {
		return switch expr {
			case Literal(null): 'nil';
			case Literal(v): Std.string(v);
			case Unary(op, e): parenthesize(op.lexeme, [e]);
			case Binary(left, op, right): parenthesize(op.lexeme, [left, right]);
			case Grouping(e): parenthesize('group', [e]);
		}
	}
	
	function parenthesize(name:String, exprs:Array<Expr>) {
		var buf = new StringBuf();
		
		buf.add('(');
		buf.add(name);
		for(expr in exprs) {
			buf.add(' ');
			buf.add(print(expr));
		}
		buf.add(')');
		return buf.toString();
	}
}