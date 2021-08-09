package cosy;

import cosy.phases.Interpreter;

interface Callable {
    function arity(): Int;
    function call(interpreter: Interpreter, arguments: Array<Any>): Any;
    @:keep function toString(): String;
}
