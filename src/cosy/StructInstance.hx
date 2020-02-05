package cosy;

class StructInstance {
    final name: Token;
	final fields: Map<String, Any>;
	
	public function new(name: Token, fields: Map<String, Any>) {
		this.name = name;
		this.fields = fields;
	}
	
	public function get(name:Token):Any {
		if (fields.exists(name.lexeme)) return fields.get(name.lexeme);
		throw new RuntimeError(name, 'Undefined property "${name.lexeme}".');
	}
	
	public function set(name:Token, value:Any) {
		fields.set(name.lexeme, value);
	}
	
	public function toString() {
        var fieldsArray = [ for (key => value in fields) '$key = $value' ];
		return '${name.lexeme} instance { ${fieldsArray.join(', ')} }';
	}
}
