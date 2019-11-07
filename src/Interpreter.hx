package;

class Interpreter {
	var environment = new Environment();
	
	public function new() {}
	
	public function interpret(statements:Array<Stmt>) {
		try {
			for(statement in statements) execute(statement);
		} catch(e:RuntimeError) {
			Lox.runtimeError(e);
		}
	}
	
	function execute(statement:Stmt) {
		switch statement {
			case Block(statements):
				executeBlock(statements, new Environment(environment));
			case Expression(e):
				evaluate(e);
			case Print(e):
				Sys.println(stringify(evaluate(e)));
			case Var(name, init):
				var value:Any = null;
				if(init != null) value = evaluate(init);
				environment.define(name.lexeme, value);
		}
	}
	
	function executeBlock(statements:Array<Stmt>, environment:Environment) {
		var previous = this.environment;
		try {
			this.environment = environment;
			for(statement in statements) execute(statement);
			this.environment = previous; // emulates "finally" statement
		} catch(e:Dynamic) {
			this.environment = previous; // emulates "finally" statement
			throw e;
		}
	}
	
	function evaluate(expr:Expr):Any {
		return switch expr {
			case Assign(name, value):
				var value = evaluate(value);
				environment.assign(name, value);
				value;
			case Literal(v):
				v;
			case Unary(op, right):
				var right = evaluate(right);
				switch op.type {
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
				
				switch op.type {
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
			case Variable(name):
				environment.get(name);
		}
	}
	
	function isTruthy(v:Any):Bool {
		if(v == null) return false;
		if(Std.is(v, Bool)) return v;
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

