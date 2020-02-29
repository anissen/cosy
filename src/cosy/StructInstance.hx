package cosy;

class StructInstance {
    final structName: Token;
	final fields: Map<String, Any>;
	
	public function new(name: Token, fields: Map<String, Any>) {
		this.structName = name;
		this.fields = fields;
    }
    
    public function newInstance() {
        return new StructInstance(structName, fields.copy());
    }
	
	public function get(name:Token):Any {
		if (fields.exists(name.lexeme)) return fields.get(name.lexeme);
		throw new RuntimeError(name, 'Undefined property "${name.lexeme}".');
	}
	
	public function set(name:Token, value:Any) {
        if (!fields.exists(name.lexeme)) return Cosy.error(name, '${name.lexeme} is not a property of ${name.lexeme}');
		fields.set(name.lexeme, value);
	}
    
    @:keep public function toString() :String {
        var formatValue = (value: Any) -> (Std.is(value, String) ? '"$value"' : '$value');
        var fieldsArray = [ for (key => value in fields) '$key = ${formatValue(value)}' ];
		return '${structName.lexeme} instance { ${fieldsArray.join(', ')} }';
	}
}
