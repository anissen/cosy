package;

class Environment {
	final enclosing:Environment;
	final values:Map<String, Any> = new Map();
	
	public function new(?enclosing) {
		this.enclosing = enclosing;
	}
	
	public function define(name:String, value:Any) {
		values.set(name, value);
	}
	
	public function get(name:Token):Any {
		if(values.exists(name.lexeme)) return values.get(name.lexeme);
		
		if(enclosing != null) return enclosing.get(name);
		
		throw new RuntimeError(name, 'Undefined variable "${name.lexeme}".');
	}
	
	public function getAt(distance:Int, name:String) {
		return ancestor(distance).values.get(name);
	}
	
	public function assign(name:Token, value:Any) {
		if(values.exists(name.lexeme))
			values.set(name.lexeme, value);
		else if(enclosing != null)
			enclosing.assign(name, value);
		else
			throw new RuntimeError(name, 'Undefined variable "${name.lexeme}".');
	}
	
	public function assignAt(distance:Int, name:Token, value:Any) {
		return ancestor(distance).values.set(name.lexeme, value);
	}
	
	public function ancestor(distance:Int) {
		var env = this;
		for(_ in 0...distance) env = env.enclosing;
		return env;
	}
}