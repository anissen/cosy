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
    var bytecode: Array<String>;

    public function new() {

    }

    public function run(code: Array<String>) {
        bytecode = code;
        stack = [];
        index = 0;
        while (index < bytecode.length) {
            switch bytecode[index++] {
                case 'push': pushNext();
                case 'op_print': opPrint();
                case 'op_add': opAdd();
                case 'op_sub': push(Number(popNumber() - popNumber()));
                case 'op_mult': push(Number(popNumber() * popNumber()));
                case 'op_div': push(Number(popNumber() / popNumber()));
            }
        }
    }

    function pushNext() {
        var code = bytecode[index++];
        if (code.charAt(0) == '"') push(Text(code.substr(1, code.length - 2)));
        else if (code == 'true') push(Boolean(true));
        else if (code == 'false') push(Boolean(true));
        else push(Number(Std.parseFloat(code)));
    }

    function opPrint() {
        var value: Any = switch pop() {
            case Text(s): s;
            case Boolean(b): b;
            case Number(n): n;
            case _: throw 'error';
        }
        trace(value);
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
}
