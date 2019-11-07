package;

class Function implements Callable {
	final name:Token;
	final params:Array<Token>;
	final body:Array<Stmt>;
	final closure:Environment;
	
	public function new(name, params, body, closure) {
		this.name = name;
		this.params = params;
		this.body = body;
		this.closure = closure;
	}
	
	public function arity() return params.length;
	
	public function call(interpreter:Interpreter, args:Array<Any>):Any {
		var environment = new Environment(closure);
		
		for(i in 0...params.length) 
			environment.define(params[i].lexeme, args[i]);
			
		return try {
			interpreter.executeBlock(body, environment);
			null;
		} catch(ret:Return) {
			ret.value;
		}
		
	}
	
	public function toString() return '<fn ${name.lexeme}>';
}