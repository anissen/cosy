package cosy.phases;

import cosy.phases.CodeGenerator.ByteCodeOpValue;
import haxe.ds.GenericStack;

enum Value {
    Text(s: String);
    Number(n: Float);
    Boolean(b: Bool);
    Function(i: Int);
}

class VM {
    var stack: Array<Value>;

    var ip: Int;

    public function new() {}

    public function run(bytecode: cosy.phases.CodeGenerator.Output) {
        // TODO: The global environment should also be treated like a function to get consistent behavior (see http://www.craftinginterpreters.com/calls-and-functions.html)

        var constantStrings = bytecode.strings;
        var constantFunctions = bytecode.functions;
        var x: GenericStack<Int>;
        var program = bytecode.bytecode;
        stack = [];
        ip = 0;
        final sizeFloat = 4;
        final sizeInt = 4;
        var pos = 0;
        var output = '';

        function readFloat() {
            final value = program.getFloat(pos);
            pos += sizeFloat;
            return value;
        }

        function readInt() {
            final value = program.getInt32(pos);
            pos += sizeInt;
            return value;
        }

        function readByte() {
            return program.get(pos++);
        }

        var return_to_pos = -1;

        while (pos < program.length) {
            var code: ByteCodeOpValue = readByte();
            // trace('### code: $code');
            // trace('IP ${pos-1}: $code');
            // var stackBefore = stack.copy(); // TODO: Only for testing! Remove it

            switch code {
                case NoOp: trace('no_op instruction. This is an error.');
                case PushTrue: push(Boolean(true));
                case PushFalse: push(Boolean(false));
                case PushNumber: push(Number(readFloat()));
                case ConstantString:
                    var index = readInt();
                    push(Text(constantStrings[index]));
                // case ConstantFunction: // TODO: Maybe??

                case Print: output += asString(pop()) + '\n';
                case Pop: popMultiple(readByte());
                case GetLocal:
                    final slot = readByte();
                    // trace('getlocal $slot, ${stack[slot]} (@ pos ${pos - 2})');
                    push(stack[slot]);
                case SetLocal:
                    final slot = readByte();
                    // trace('setlocal $slot, ${peek()}');
                    // trace('--> stack before: $stack');
                    stack[slot] = peek();
                // trace('--> stack after: $stack');
                case JumpIfFalse:
                    final offset = readInt();
                    if (isFalsey(peek())) pos += offset;
                case JumpIfTrue:
                    final offset = readInt();
                    if (!isFalsey(peek())) pos += offset;
                case Jump:
                    final offset = readInt();
                    pos += offset;
                case Equal: opEquals();
                case Addition: opAdd();
                case Subtraction:
                    var right = popNumber();
                    var left = popNumber();
                    push(Number(left - right));
                case Multiplication:
                    var right = popNumber();
                    var left = popNumber();
                    push(Number(left * right));
                case Division:
                    var right = popNumber();
                    var left = popNumber();
                    push(Number(left / right));
                case Modulus:
                    var right = popNumber();
                    var left = popNumber();
                    push(Number(left % right));
                case Less: push(Boolean(popNumber() > popNumber()));
                case LessEqual: push(Boolean(popNumber() >= popNumber()));
                case Greater: push(Boolean(popNumber() < popNumber()));
                case GreaterEqual: push(Boolean(popNumber() <= popNumber()));
                case Negate: push(Number(-popNumber()));
                case Function:
                    var functionPos = readInt();
                    // trace('fn at pos $functionPos');
                    push(Function(functionPos));

                // var argCount = readByte();
                // var nameIndex = readInt();
                // var name = constantStrings[nameIndex];
                // trace('fn $name (pos $functionPos) $argCount argument(s)');

                // var functionIndex = readInt();
                // var functionDef = constantFunctions[functionIndex];
                // trace('fn ${functionDef.name}, pos ${functionDef.pos}, length: ${functionDef.length}');
                case Call:
                    var argCount = readByte();
                    // trace('call function with $argCount argument(s)');

                    return_to_pos = pos;
                    pos = popFunctionPos();
                // trace('function pos: $pos');

                // var functionIndex = Std.int(popNumber());
                // var functionDef = constantFunctions[functionIndex];
                // trace('fn ${functionDef.name}, pos ${functionDef.pos}, length: ${functionDef.length}');
                // pos = functionDef.pos;

                // pos = Std.int(popNumber());
                // pos = Std.int(v);
                // trace(pos);
                case Return:
                    pos = return_to_pos; // Sys.exit(0); // TODO: Implement
            }
            // trace(' ## IP: $ip, Op: $code,\t Stack: $stackBefore => $stack');
        }
        if (output.length > 0) {
            trace('\n$output');
        }
    }

    inline function asString(value: Value): String {
        return switch value {
            case Text(s): s;
            case Boolean(b): b ? 'true' : 'false';
            case Number(n): '$n';
            case Function(i):
                'func #$i'; // TODO: Get the function name from constantFunctions
                // case Array(a): trace(a.map(unwrapValue));
                // case Function(f): trace('<fn $f>');
        }
    }

    function opEquals() {
        final right = pop();
        final left = pop();
        final equals = switch right {
            case Text(t): switch left {
                    case Text(t2): t == t2;
                    case _: false;
                }
            case Boolean(b): switch left {
                    case Boolean(b2): b == b2;
                    case _: false;
                }
            case Number(n): switch left {
                    case Number(n2): n == n2;
                    case _: false;
                }
            case _: throw 'cannot compare $left and $right';
        }
        push(Boolean(equals));
    }

    // function opInc() {
    //     var variable = bytecode[ip++];
    //     switch variables.get(variable) {
    //         case Number(n): variables.set(variable, Number(n + 1));
    //         case _: throw 'error';
    //     }
    // }

    inline function opAdd() {
        return push(switch [pop(), pop()] {
            case [Number(n1), Number(n2)]: Number(n1 + n2);
            case [Text(s1), Text(s2)]: Text(s1 + s2);
            case [Number(n1), Text(s2)]: Text(n1 + s2);
            case [Text(s1), Number(n2)]: Text(s1 + n2);
            case _: throw 'error';
        });
    }

    inline function push(value: Value) {
        return stack.push(value);
    }

    inline function pop(): Value {
        return stack.pop();
    }

    inline function popMultiple(count: Int) {
        stack.splice(-count, count);
    }

    inline function peek(): Value {
        return stack[stack.length - 1];
    }

    inline function isFalsey(value: Value): Bool {
        return switch value {
            case Number(n): n == 0;
            case Boolean(b): !b;
            case Text(s): false;
            case _: throw 'error';
        }
    }

    inline function popNumber(): Float {
        return switch pop() {
            case Number(n): n;
            case _: throw 'error';
        }
    }

    inline function popFunctionPos(): Int {
        return switch pop() {
            case Function(i): i;
            case _: throw 'error';
        }
    }

    // inline function popText(): String {
    //     return switch pop() {
    //         case Text(s): s;
    //         case _: throw 'error';
    //     }
    // }
    // inline function popBoolean(): Bool {
    //     return switch pop() {
    //         case Boolean(b): b;
    //         case _: throw 'error';
    //     }
    // }
}
