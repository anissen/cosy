package cosy.phases;

import cosy.phases.CodeGenerator.ByteCodeOpValue;
enum OutputPart {
    Instruction(s: String);
    Arg(d: Any);
    Hint(h: Any);
    Error(s: String);
}

class Disassembler {
    
    static public function disassemble(bytecode: cosy.phases.CodeGenerator.Output, colors: Bool = false): String {
        function lpad(str: String, length: Int, char: String = ' ') {
            final diff = length - str.length;
            if (diff > 0) str = [ for (_ in 0...diff) char].join('') + str;
            return str;
        }
        function rpad(str: String, length: Int) {
            final diff = length - str.length;
            if (diff > 0) str += [ for (_ in 0...diff) ' '].join('');
            return str;
        }

        function color(part: OutputPart): String {
            final str = switch part {
                case Instruction(s): rpad(s, 15);
                case Arg(d): lpad('$d', 5);
                case Hint(h): '  ($h)';
                case Error(s): s;
            };
            if (!colors) return str;
            final color = switch part {
                case Instruction(_): 34; // blue
                case Arg(_): 33; // orange
                case Hint(_): 35; // purple
                case Error(_): 31; // red
            }
            return '\033[1;${color}m${str}\033[0m';
        }

        var output = '\n';
        var program = bytecode.bytecode;
        final sizeFloat = 4;
        var pos = 0;
        while (pos < program.length) {
            var ipPos = pos;
            var code: ByteCodeOpValue = program.get(pos++);
            var parts = switch code {
                case NoOp: [Instruction('no_op')];
                case PushTrue: [Instruction('push_true')];
                case PushFalse: [Instruction('push_false')];
                case PushNumber: 
                    var num = program.getFloat(pos);
                    pos += sizeFloat;
                    [Instruction('push_num'), Arg(num)];
                    // 'push_num $num';
                case ConstantString:
                    var index = program.getInt32(pos);
                    pos += 4;
                    [Instruction('constant_str'), Arg(index), Hint('${bytecode.strings[index]}')];
                    // 'constant_str $index ("${bytecode.strings[index]}")';
                case Print: [Instruction('print')];
                case Pop: [Instruction('pop'), Arg(program.get(pos++))];
                case GetLocal: [Instruction('get_local'), Arg(program.get(pos++))];
                case SetLocal: [Instruction('set_local'), Arg(program.get(pos++))];
                case JumpIfFalse:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    final absolute = pos + offset;
                    [Instruction('jump_if_false'), Arg(offset), Hint('$ipPos => $absolute')];
                case JumpIfTrue:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    final absolute = pos + offset;
                    [Instruction('jump_if_true'), Arg(offset), Hint('$ipPos => $absolute')];
                case Jump:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    final absolute = pos + offset;
                    [Instruction('jump'), Arg(offset), Hint('$ipPos => $absolute')];
                case Equal: [Instruction('equal'), Arg(''), Hint('==')];
                case Addition: [Instruction('add'), Arg(''), Hint('+')];
                case Subtraction: [Instruction('sub'), Arg(''), Hint('-')];
                case Multiplication: [Instruction('mult'), Arg(''), Hint('*')];
                case Division: [Instruction('div'), Arg(''), Hint('/')];
                case Modulus: [Instruction('mod'), Arg(''), Hint('%')];
                case Less: [Instruction('less'), Arg(''),  Hint('<')];
                case LessEqual: [Instruction('less_equal'), Arg(''),  Hint('<=')];
                case Greater: [Instruction('greater'), Arg(''),  Hint('>')];
                case GreaterEqual: [Instruction('greater_equal'), Arg(''),  Hint('>=')];
                case Negate: [Instruction('negate'), Arg(''), Hint('-')];
                // case _: [Error('[Unknown bytecode: "$code"]')];
            }

            var disassembly = [ for (part in parts) color(part) ].join('');
            output += '· ${lpad(Std.string(ipPos), 5, "0")}  ${pos - ipPos}B  $disassembly\n';
        }
        return output;
    }
}
