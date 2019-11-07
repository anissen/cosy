package;

interface Callable {
	function arity():Int;
	function call(interpreter:Interpreter, arguments:Array<Any>):Any;
}