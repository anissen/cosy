package cosy;

enum Value {
    Text(s: String);
    Number(n: Float);
    Boolean(b: Bool);
    Array(a: Array<Value>);
    Function(f: String);
    // Op(o: String);
}

typedef FunctionObj = {
    name: String,
    // ...
}

typedef CallFrame = {
    // function: FunctionObj,
    ip: Int,
    slots: Array<Value>, // relative indexes into the values on the stack (e.g. for finding locals in functions)
}

class VM {
    var stack: Array<Value>;
    var callFrames: Array<CallFrame>;
    var index: Int;
    var bytecode: Array<String>; // TODO: Should probably be something like { code: String, line: Int, (module: String) }
    var variables: Map<String, Value>;

    public function new() {

    }

    public function run(program: Array<String>) {
        // TODO: The global environment should also be treated like a function to get consistent behavior (see http://www.craftinginterpreters.com/calls-and-functions.html)

        bytecode = program;
        stack = [];
        callFrames = [{ ip: 0, slots: [] }];
        index = 0; // TODO: Should be `ip`
        variables = new Map();
        var foundMain = false;
        while (index < bytecode.length) {
            var startIndex = index;
            var code = bytecode[index++];
            var endIndex = index;
            var hasJumped = false;
            if (!foundMain) {
                foundMain = (code == 'main:');
                continue;
            }
            var frame = callFrames[callFrames.length - 1];
            /*
            TODO:
            Convert bytecode into the form of [[instruction, args...], [instruction, args..], ...]
            and do:
            switch (code) {
                case ['jump', length]: ...
            }
            or better yet:
            switch (code) {
                case [OP_JUMP, length]: ...
            }
            */
            switch code { // TODO: Use bytes/ints instead of strings
                case 'label': bytecode[index++];
                case 'push_true': push(Boolean(true));
                case 'push_false': push(Boolean(false));
                case 'push_num': push(Number(Std.parseFloat(bytecode[index++])));
                case 'push_str': push(Text(bytecode[index++]));
                case 'push_fn': push(Function(bytecode[index++]));
                case 'to_array': toArray();
                case 'call': call();
                case 'op_print': opPrint();
                case 'op_equals': opEquals();
                case 'op_inc': opInc();
                case 'op_add': opAdd();
                case 'op_sub': push(Number(popNumber() - popNumber()));
                case 'op_mult': push(Number(popNumber() * popNumber()));
                case 'op_div': push(Number(popNumber() / popNumber()));
                case 'op_negate': push(Number(-popNumber()));
                case 'op_less': push(Boolean(popNumber() > popNumber())); // operator is reversed because arguments are reversed on stack
                case 'op_less_eq': push(Boolean(popNumber() >= popNumber()));
                case 'op_greater': push(Boolean(popNumber() < popNumber()));
                case 'op_greater_eq': push(Boolean(popNumber() <= popNumber()));
                case 'load_local':
                    var slot = Std.int(popNumber());
                    push(frame.slots[slot]);
                case 'save_local':
                    var slot = Std.int(popNumber());
                    frame.slots[slot] = peek();
                case 'save_var': variables.set(bytecode[index++], pop());
                case 'load_var': push(variables.get(bytecode[index++]));
                // case 'load_array_index':
                case 'jump':
                    var offset = Std.parseInt(bytecode[index++]);
                    endIndex = index;
                    frame.ip += offset;
                    index += offset;
                    hasJumped = true;
                case 'jump_if_not':
                    var condition = popBoolean(); // TODO: Condition could be an expr!
                    var offset = Std.parseInt(bytecode[index++]);
                    endIndex = index;
                    if (!condition) index += offset; // skip the 'then' branch
                    hasJumped = true;
                case _: trace('Unknown bytecode: "$code".');
            }
            trace('  ' + bytecode.slice(startIndex, (hasJumped ? endIndex : index)) + '\t\t## Index: $index, Stack: $stack, Vars: $variables');
            // trace('## Stack: $stack, Vars: $variables');
        }
    }

    function toArray() {
        var length = Std.parseInt(bytecode[index++]);
        var arr = popReversed(length);
        return push(Array(arr));
    }

    function call() {
        // TODO: Make a frame with arguments
        var argumentCount = Std.parseInt(bytecode[index++]);
        var arguments = popReversed(argumentCount);
        trace('[call] arguments: $arguments');
        var functionName = switch pop() {
            case Function(f): f;
            case _: throw 'error';
        }
        trace('[call] function: $functionName');

        // TODO: Needs to record the index of the first local slot (to be able to reference other slots with relative indexes) (that is, the call frame)
        // TODO: Store `index` as the return address
        return 0;
    }

    function opPrint() {
        switch pop() {
            case Text(s): trace(s);
            case Boolean(b): trace(b);
            case Number(n): trace(n);
            case Array(a): trace(a.map(unwrapValue));
            case Function(f): trace('<fn $f>');
        }
    }

    function opEquals() {
        var a = pop();
        var b = pop();
        push(Boolean(a.equals(b)));
    }

    function unwrapValue(value: Value): Any { // TODO: Evil Any!
        return switch value {
            case Text(s): s;
            case Boolean(b): b;
            case Number(n): n;
            case Array(a): a.map(unwrapValue);
            case Function(f): f;
        }
    }

    function opInc() {
        var variable = bytecode[index++];
        switch variables.get(variable) {
            case Number(n): variables.set(variable, Number(n + 1));
            case _: throw 'error';
        }
    }

    function opAdd() {
        var value = switch [pop(), pop()] {
            case [Number(n1), Number(n2)]: Number(n1 + n2);
            case [Text(s1),   Text(s2)]:   Text(s1 + s2);
            case [Number(n1), Text(s2)]:   Text(n1 + s2);
            case [Text(s1),   Number(n2)]: Text(s1 + n2);
            case _: throw 'error';
        }
        return push(value);
    }

    function push(value: Value) {
        return stack.push(value);
    }

    function pop(): Value {
        return stack.pop();
    }

    function peek(): Value {
        return stack[stack.length - 1];
    }

    function popReversed(count: Int): Array<Value> {
        return stack.splice(-count, count);
    }

    function popNumber(): Float {
        return switch pop() {
            case Number(n): n;
            case _: throw 'error';
        }
    }

    function popText(): String {
        return switch pop() {
            case Text(s): s;
            case _: throw 'error';
        }
    }

    function popBoolean(): Bool {
        return switch pop() {
            case Boolean(b): b;
            case _: throw 'error';
        }
    }
}
