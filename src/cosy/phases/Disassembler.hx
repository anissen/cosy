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
        function color(part: OutputPart): String {
            if (!colors) return switch part {
                case Instruction(s): s;
                case Arg(d): d;
                case Hint(h): h;
                case Error(s): s;
            };
            return switch part {
                case Instruction(s): '\033[1;34m$s\033[0m'; // blue
                case Arg(d): '\033[0;33m$d\033[0m'; // orange
                case Hint(h): '\033[0;35m$h\033[0m'; // purple
                case Error(s): '\033[0;31m$s\033[0m'; // red
            }
        }

        var output = '\n';
        var program = bytecode.bytecode;
        final sizeFloat = 4;
        var pos = 0;
        while (pos < program.length) {
            var ipPos = pos;
            var code = program.get(pos++);
            var parts = switch code {
                case ByteCodeOpValue.PushTrue: [Instruction('push_true')];
                case ByteCodeOpValue.PushFalse: [Instruction('push_false')];
                case ByteCodeOpValue.PushNumber: 
                    var num = program.getFloat(pos);
                    pos += sizeFloat;
                    [Instruction('push_num'), Arg(num)];
                    // 'push_num $num';
                case ByteCodeOpValue.ConstantString:
                    var index = program.get(pos);
                    pos += 4;
                    [Instruction('constant_str'), Arg(index), Hint('(${bytecode.strings[index]})')];
                    // 'constant_str $index ("${bytecode.strings[index]}")';
                case ByteCodeOpValue.Print: [Instruction('print')];
                case ByteCodeOpValue.Pop: [Instruction('pop ${program.get(pos++)}')];
                case ByteCodeOpValue.GetLocal: [Instruction('get_local ${program.get(pos++)}')];
                case ByteCodeOpValue.JumpIfFalse:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    final absolute = pos + offset;
                    [Instruction('jump_if_false'), Arg(offset), Hint('($ipPos => $absolute)')];
                case ByteCodeOpValue.JumpIfTrue:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    final absolute = pos + offset;
                    [Instruction('jump_if_true'), Arg(offset), Hint('($ipPos => $absolute)')];
                case ByteCodeOpValue.Jump:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    final absolute = pos + offset;
                    [Instruction('jump'), Arg(offset), Hint('($ipPos => $absolute)')];
                case _: [Error('[Unknown bytecode: "$code"]')];
            }

            var disassembly = [ for (part in parts) color(part) ].join('\t');
            output += '$ipPos\t${pos - ipPos}B\t$disassembly\n';
        }
        return output;
    }
}
