package;

class Klass implements Callable {
	public final name:String;
	public final methods:Map<String, Function>;
	
	public function new(name, methods) {
		this.name = name;
		this.methods = methods;
	}
	
	public function arity() {
		return switch findMethod('init') {
			case null: 0;
			case init: init.arity();
		}
	}
	
	public function call(interpreter:Interpreter, args:Array<Any>):Any {
		var instance = new Instance(this);
		switch findMethod('init') {
			case null:
			case init: init.bind(instance).call(interpreter, args);
		}
		return instance;
	}
	
	public function findMethod(name:String):Function {
		if(methods.exists(name))
			return methods.get(name);
		return null;
	}
	
	public function toString() {
		return name;
	}
}