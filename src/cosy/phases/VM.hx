package cosy.phases;

import cosy.phases.CodeGenerator.ByteCodeOpValue;
import haxe.ds.GenericStack;
import haxe.ds.Vector;

using VM.ValueTools;
enum Value {
    Text(s: String);
    Number(n: Float);
    Boolean(b: Bool);
}

class ValueTools {
    static inline public function asNumber(value: Value) {
        return switch (value) {
            case Number(n): n;
            case _: throw 'error';
        }
    }
}


class VM {
    var stack: Array<Value>;

    var ip: Int;

    public function new() {

    }

    public function run(bytecode: cosy.phases.CodeGenerator.Output) {
        // TODO: The global environment should also be treated like a function to get consistent behavior (see http://www.craftinginterpreters.com/calls-and-functions.html)
    
        var constantStrings = bytecode.strings;
        var x :GenericStack<Int>;
        var program = bytecode.bytecode;
        stack = [];
        var slots = new Vector(255);
        ip = 0;
        final sizeFloat = 4;
        var pos = 0;
        var output = '';
        while (pos < program.length) {
            var code: ByteCodeOpValue = program.get(pos++);
            // trace('IP ${pos-1}: $code');
            // var stackBefore = stack.copy(); // TODO: Only for testing! Remove it
            
            switch code {
                case NoOp: trace('no_op instruction. This is an error.');
                case PushTrue: push(Boolean(true));
                case PushFalse: push(Boolean(false));
                // case 'push_num': push(Number(Std.parseFloat(program[ip++])));
                case PushNumber: 
                    push(Number(program.getFloat(pos)));
                    pos += sizeFloat;
                // case 'push_str': push(Text(program[ip++]));
                case ConstantString:
                    var index = program.get(pos);
                    pos += 4;
                    push(Text(constantStrings[index]));
                case Print: 
                    output += asString(pop()) + '\n';
                case Pop: popMultiple(program.get(pos++));
                case GetLocal: 
                    final slot = program.get(pos++);
                    push(stack[slot]);
                case SetLocal: 
                    final slot = program.get(pos++);
                    stack[slot] = peek();
                case JumpIfFalse:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    if (isFalsey(peek())) pos += offset;
                case JumpIfTrue:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    if (!isFalsey(peek())) pos += offset;
                case Jump:
                    final offset = program.getInt32(pos);
                    pos += 4 + offset;
                // case 18: opEquals();
                case Equal: opEquals();
                case Addition:
                    var right = popNumber();
                    var left  = popNumber();
                    push(Number(left + right));
                case Subtraction:
                    var right = popNumber();
                    var left  = popNumber();
                    push(Number(left - right));
                case Multiplication:
                    var right = popNumber();
                    var left  = popNumber();
                    push(Number(left * right));
                case Division:
                    var right = popNumber();
                    var left  = popNumber();
                    push(Number(left / right));
                case Less: push(Boolean(popNumber() > popNumber()));
                case LessEqual: push(Boolean(popNumber() >= popNumber()));
                case Greater: push(Boolean(popNumber() < popNumber()));
                case GreaterEqual: push(Boolean(popNumber() <= popNumber()));
                case Negate: push(Number(-popNumber()));
                // case 31:
                    
                // case 'op_sub': push(Number(popNumber() - popNumber()));
                // case 'op_mult': push(Number(popNumber() * popNumber()));
                // case 'op_div': push(Number(popNumber() / popNumber()));
                // case 'op_negate': push(Number(-popNumber()));
                // case 'op_less': push(Boolean(popNumber() > popNumber())); // operator is reversed because arguments are reversed on stack
                // case 'op_less_eq': push(Boolean(popNumber() >= popNumber()));
                // case 'op_greater': push(Boolean(popNumber() < popNumber()));
                // case 'op_greater_eq': push(Boolean(popNumber() <= popNumber()));
                // case 'load_local':
                //     var slot = Std.int(popNumber());
                //     push(frame.slots[slot]);
                // case 'save_local':
                //     var slot = Std.int(popNumber());
                //     frame.slots[slot] = peek();
                // case 'save_var': variables.set(bytecode[index++], pop());
                // case 'load_var': push(variables.get(bytecode[index++]));
                // case _: throw 'Unknown bytecode: "$code".';
            }
            // trace(' ## IP: $ip, Op: $code,\t Stack: $stackBefore => $stack');
        }
        if (output.length > 0) {
            trace('\n$output');
        }


        // while (ip < program.length) {
        //     var code = program[ip++];
        //     var stackBefore = stack.copy(); // TODO: Only for testing! Remove it
        //     switch code {
        //         case 'push_true': push(Boolean(true));
        //         case 'push_false': push(Boolean(false));
        //         // case 'push_num': push(Number(Std.parseFloat(program[ip++])));
        //         case 'push_num 2': push(Number(2));
        //         case 'push_num 3': push(Number(3));
        //         // case 'push_str': push(Text(program[ip++]));
        //         case 'constant_str':
        //             final str = program[ip];
        //             // constantStrings.push(str);
        //             push(Text(program[ip++]));
        //         case 'op_print': opPrint();
        //         case 'pop': pop();
        //         case 'pop 2': popMultiple(2);
        //         case 'get_local 0': 
        //             final slot = 0;
        //             slots[slot] = peek();
        //             push(slots[slot]);
        //         case 'get_local 1': 
        //             final slot = 1;
        //             slots[slot] = peek();
        //             push(slots[slot]);
        //         case 'op_equals': opEquals();
        //         case 'op_add': push(Number(popNumber() + popNumber()));
        //         case 'op_sub': push(Number(popNumber() - popNumber()));
        //         case 'op_mult': push(Number(popNumber() * popNumber()));
        //         case 'op_div': push(Number(popNumber() / popNumber()));
        //         case 'op_negate': push(Number(-popNumber()));
        //         case 'op_less': push(Boolean(popNumber() > popNumber())); // operator is reversed because arguments are reversed on stack
        //         case 'op_less_eq': push(Boolean(popNumber() >= popNumber()));
        //         case 'op_greater': push(Boolean(popNumber() < popNumber()));
        //         case 'op_greater_eq': push(Boolean(popNumber() <= popNumber()));
        //         // case 'load_local':
        //         //     var slot = Std.int(popNumber());
        //         //     push(frame.slots[slot]);
        //         // case 'save_local':
        //         //     var slot = Std.int(popNumber());
        //         //     frame.slots[slot] = peek();
        //         // case 'save_var': variables.set(bytecode[index++], pop());
        //         // case 'load_var': push(variables.get(bytecode[index++]));
        //         case _: trace('Unknown bytecode: "$code".');
        //     }
        //     trace(' ## IP: $ip, Op: $code,\t Stack: $stackBefore => $stack');
        // }
    }

    inline function asString(value: Value): String {
        return switch value {
            case Text(s): s;
            case Boolean(b): b ? 'true' : 'false';
            case Number(n): Std.string(n);
            // case Array(a): trace(a.map(unwrapValue));
            // case Function(f): trace('<fn $f>');
        }
        // outputText += '\n' + unwrapValue(value);
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
            case [Text(s1),   Text(s2)]:   Text(s1 + s2);
            case [Number(n1), Text(s2)]:   Text(n1 + s2);
            case [Text(s1),   Number(n2)]: Text(s1 + n2);
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
        }
    }

    // TODO: Make this a static extension instead, asNumber()
    inline function popNumber(): Float {
        return switch pop() {
            case Number(n): n;
            case _: throw 'error';
        }
    }

    inline function popText(): String {
        return switch pop() {
            case Text(s): s;
            case _: throw 'error';
        }
    }

    inline function popBoolean(): Bool {
        return switch pop() {
            case Boolean(b): b;
            case _: throw 'error';
        }
    }
}
