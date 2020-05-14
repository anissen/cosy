package cosy;

enum Value {
    Text(s: String);
    Number(n: Float);
    Boolean(b: Bool);
    Array(a: Array<Value>);
    // Op(o: String);
}

class VM {
    var stack: Array<Value>;
    var index: Int;
    var bytecode: Array<String>; // TODO: Should probably be something like { code: String, line: Int, (module: String) }
    var variables: Map<String, Value>;

    public function new() {

    }

    public function run(program: Array<String>) {
        bytecode = program;
        stack = [];
        index = 0;
        variables = new Map();
        while (index < bytecode.length) {
            var startIndex = index;
            var code = bytecode[index++];
            var endIndex = index;
            var hasJumped = false;
            switch code { // TODO: Use bytes/ints instead of strings
                case 'label': bytecode[index++];
                case 'push_bool': push(Boolean(bytecode[index++] == 'true'));
                case 'push_num': push(Number(Std.parseFloat(bytecode[index++])));
                case 'push_str': push(Text(bytecode[index++]));
                case 'to_array': toArray();
                case 'op_print': opPrint();
                case 'op_equals': push(Boolean(popNumber() == popNumber())); // TODO: Can be other types, e.g. String or Boolean
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
                case 'save_var': variables.set(bytecode[index++], pop());
                case 'load_var': push(variables.get(bytecode[index++]));
                // case 'load_array_index':
                case 'jump':
                    var jumpLength = Std.parseInt(bytecode[index++]);
                    endIndex = index;
                    index += jumpLength;
                    hasJumped = true;
                case 'jump_if_not':
                    var condition = popBoolean(); // TODO: Condition could be an expr!
                    var jumpLength = Std.parseInt(bytecode[index++]);
                    endIndex = index;
                    if (!condition) index += jumpLength; // skip the 'then' branch
                    hasJumped = true;
                case _: trace('Unknown bytecode: "$code".');
            }
            trace('  ' + bytecode.slice(startIndex, (hasJumped ? endIndex : index)) + '\t\t## Index: $index, Stack: $stack, Vars: $variables');
            // trace('## Stack: $stack, Vars: $variables');
        }
    }

    // function pushNext() {
    //     var code = bytecode[index++];
    //     if (code.charAt(0) == '"') push(Text(code.substr(1, code.length - 2)));
    //     else if (code == 'true') push(Boolean(true));
    //     else if (code == 'false') push(Boolean(true));
    //     else push(Number(Std.parseFloat(code)));
    // }

    function toArray() {
        var length = Std.parseInt(bytecode[index++]);
        var arr = [ for (i in 0...length) pop() ];
        arr.reverse();
        return push(Array(arr));
    }

    function opPrint() {
        switch pop() {
            case Text(s): trace(s);
            case Boolean(b): trace(b);
            case Number(n): trace(n);
            case Array(a): trace(a.map(unwrapValue));
        }
    }

    function unwrapValue(value: Value): Any { // TODO: Evil Any!
        return switch value {
            case Text(s): s;
            case Boolean(b): b;
            case Number(n): n;
            case Array(a): a.map(unwrapValue);
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
