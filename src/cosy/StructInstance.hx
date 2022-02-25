package cosy;

class StructInstance {
    final structName: Token;
    final fields: Map<String, Any>;
    final logger: cosy.Logging.Logger;

    public function new(name: Token, fields: Map<String, Any>, logger: cosy.Logging.Logger) {
        this.structName = name;
        this.fields = fields;
        this.logger = logger;
    }

    public function clone() { // Make a deep copy of fields
        var clonedFields = new Map();
        for (key => value in fields) {
            if (Std.isOfType(value, StructInstance)) clonedFields[key] = (value: StructInstance).clone();
            else clonedFields[key] = value;
        }
        return new StructInstance(structName, clonedFields, logger);
    }

    public function get(name: Token): Null<Any> {
        if (fields.exists(name.lexeme)) return fields.get(name.lexeme);
        throw new RuntimeError(name, 'Undefined property "${name.lexeme}".');
    }

    public function set(name: Token, value: Any) {
        if (!fields.exists(name.lexeme)) return logger.error(name, '${name.lexeme} is not a property of ${name.lexeme}');
        fields.set(name.lexeme, value);
    }

    @:keep public function toString(): String {
        var formatValue = (value: Any) -> (Std.isOfType(value, String) ? '"$value"' : '$value');
        var fieldsArray = [for (key => value in fields) '$key = ${formatValue(value)}'];
        fieldsArray.sort(function(a, b) {
            if (a < b) return -1;
            if (b < a) return 1;
            return 0;
        });
        return '${structName.lexeme} { ${fieldsArray.join(', ')} }';
    }
}
