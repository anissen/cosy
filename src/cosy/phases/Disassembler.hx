package cosy.phases;

import cosy.phases.CodeGenerator.ByteCodeOpValue;

class Disassembler {
    static public function disassemble(bytes: haxe.io.Bytes): String {
        var output = '\n';
        var program = bytes;
        final sizeFloat = 4;
        var ip = 0;
        var pos = 0;
        while (pos < program.length) {
            var code = program.get(pos++);
            var disassembly = switch code {
                case ByteCodeOpValue.PushTrue: 'push_true';
                case ByteCodeOpValue.PushFalse: 'push_false';
                case ByteCodeOpValue.PushNumber: 
                    var num = program.getFloat(pos);
                    pos += sizeFloat;
                    'push_num $num';
                case ByteCodeOpValue.ConstantString:
                    var index = program.get(pos);
                    pos += 4;
                    'constant_str $index';
                case ByteCodeOpValue.Print: 'print';
                case ByteCodeOpValue.Pop: 'pop ${program.get(pos++)}';
                case ByteCodeOpValue.GetLocal: 'get_local ${program.get(pos++)}';
                case ByteCodeOpValue.JumpIfFalse:
                    final offset = program.getInt32(pos);
                    pos += 4;
                    'jump_if_false ${offset}';
                case _: '[Unknown bytecode: "$code"]';
            }
            output += '$ip\t$disassembly\n';
            ip++;
        }
        return output;
    }
}