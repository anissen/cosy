package lox;

class Instance {
	final klass:Klass;
	final fields:Map<String, Any> = new Map();
	
	public function new(klass) {
		this.klass = klass;
	}
	
	public function get(name:Token):Any {
		if(fields.exists(name.lexeme)) return fields.get(name.lexeme);
		var method = klass.findMethod(name.lexeme);
		if(method != null) return method.bind(this);
		throw new RuntimeError(name, 'Undefined property "${name.lexeme}".');
	}
	
	public function set(name:Token, value:Any) {
		fields.set(name.lexeme, value);
	}
	
	public function toString() {
		return klass.name + ' instance';
	}
}