package;

class Function implements Callable {
	final name:Token;
	final params:Array<Token>;
	final body:Array<Stmt>;
	final closure:Environment;
	final isInitializer:Bool;
	
	public function new(name, params, body, closure, isInitializer) {
		this.name = name;
		this.params = params;
		this.body = body;
		this.closure = closure;
		this.isInitializer = isInitializer;
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
			if(isInitializer) closure.getAt(0, 'this');
			else ret.value;
		}
		
		if(isInitializer) return closure.getAt(0, 'this');
		
	}
	
	public function bind(instance:Instance):Function {
		var env = new Environment(closure);
		env.define('this', instance);
		return new Function(name, params, body, env, isInitializer);
	}
	
	public function toString() return '<fn ${name.lexeme}>';
}