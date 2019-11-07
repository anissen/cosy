package;

class Interpreter {
	public function new() {}
	
	public function interpret(expression:Expr) {
		try {
			var v = evaluate(expression);
			Sys.println(stringify(v));
		} catch(e:RuntimeError) {
			Lox.runtimeError(e);
		}
	}
	
	function evaluate(expr:Expr):Any {
		return switch expr {
			case Literal(v):
				v;
			case Unary(op, right):
				var right = evaluate(right);
				return switch op.type {
					case Bang:
						!isTruthy(right);
					case Minus:
						checkNumberOperand(op, right);
						-(right:Float);
					case _:
						null;
				}
			case Binary(left, op, right):
				var left:Any = evaluate(left);
				var right:Any = evaluate(right);
				
				return switch op.type {
					case Minus:
						checkNumberOperands(op, left, right);
						(left:Float) - (right:Float);
					case Slash:
						checkNumberOperands(op, left, right);
						(left:Float) / (right:Float);
					case Star:
						checkNumberOperands(op, left, right);
						(left:Float) * (right:Float);
					case Plus:
						if(Std.is(left, Float) && Std.is(right, Float))
							(left:Float) + (right:Float);
						else if(Std.is(left, String) && Std.is(right, String))
							(left:String) + (right:String);
						else
							throw new RuntimeError(op, 'Operands must be two numbers or two strings.');
					case Greater:
						checkNumberOperands(op, left, right);
						(left:Float) > (right:Float);
					case GreaterEqual:
						checkNumberOperands(op, left, right);
						(left:Float) >= (right:Float);
					case Less:
						checkNumberOperands(op, left, right);
						(left:Float) < (right:Float);
					case LessEqual:
						checkNumberOperands(op, left, right);
						(left:Float) <= (right:Float);
					case BangEqual:
						!isEqual(left, right);
					case EqualEqual:
						isEqual(left, right);
					case _:
						null;
				}
			case Grouping(e):
				evaluate(e);
		}
	}
	
	function isTruthy(v:Any):Bool {
		if(v == null) return false;
		if(Std.is(v, Bool)) v;
		return true;
	}
	
	function isEqual(a:Any, b:Any) {
		if(a == null && b == null) return true;
		if(a == null) return false;
		return a == b;
	}
	
	function checkNumberOperand(op:Token, operand:Any) {
		if(Std.is(operand, Float)) return;
		throw new RuntimeError(op, 'Operand must be a number');
	}
	
	function checkNumberOperands(op:Token, left:Any, right:Any) {
		if(Std.is(left, Float) && Std.is(right, Float)) return;
		throw new RuntimeError(op, 'Operand must be a number');
	}
	
	function stringify(v:Any) {
		if(v == null) return 'nil';
		
		return Std.string(v);
	}
}

