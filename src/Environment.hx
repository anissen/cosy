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
	
	public function assign(name:Token, value:Any) {
		if(values.exists(name.lexeme))
			values.set(name.lexeme, value);
		else if(enclosing != null)
			enclosing.assign(name, value);
		else
			throw new RuntimeError(name, 'Undefined variable "${name.lexeme}".');
	}
}