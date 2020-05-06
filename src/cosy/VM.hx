package cosy;

enum Type {
    Text(s: String);
    Number(n: Float);
    Boolean(b: Bool);
    // Op(o: String);
}

class VM {
    var stack: Array<Type>;
    var index: Int;
    var bytecode: Array<String>; // TODO: Should probably be something like { code: String, line: Int, (module: String) }
    var variables: Map<String, Type>;

    public function new() {

    }

    public function run(program: Array<String>) {
        bytecode = program;
        stack = [];
        index = 0;
        variables = new Map();
        while (index < bytecode.length) {
            var oldIndex = index;
            var code = bytecode[index++];
            switch code {
                case 'push_bool': push(Boolean(bytecode[index++] == 'true'));
                case 'push_num': push(Number(Std.parseFloat(bytecode[index++])));
                case 'push_str': push(Text(bytecode[index++]));
                case 'op_print': opPrint();
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
                case 'jump':
                    var jumpLength = Std.parseInt(bytecode[index++]);
                    index += jumpLength;
                case 'jump_if_not':
                    var condition = popBoolean(); // TODO: Condition could be an expr!
                    var jumpLength = Std.parseInt(bytecode[index++]);
                    if (!condition) index += jumpLength; // skip the 'then' branch
                case _: trace('Unknown bytecode: "$code".');
            }
            trace('  ' + bytecode.slice(oldIndex, index) + '\t\t## Stack: $stack, Vars: $variables');
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

    function opPrint() {
        switch pop() {
            case Text(s): trace(s);
            case Boolean(b): trace(b);
            case Number(n): trace(n);
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

    function push(type: Type) {
        return stack.push(type);
    }

    function pop(): Type {
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
