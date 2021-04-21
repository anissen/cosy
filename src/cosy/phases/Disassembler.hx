package cosy.phases;

import cosy.phases.CodeGenerator.ByteCodeOpValue;
enum OutputPart {
    Instruction(s: String);
    Arg(d: Any);
    Hint(h: Any);
    Error(s: String);
}

/* TODO: Make the output assembly easier to read, e.g. more like the following from snekky-lang.org

00 | 00 | Constant {index: 0, value: UserFunction(10,2)}
01 | 05 | Jump {index: 33}
02 | 10 | Store {index: 0, name: a}
03 | 15 | Store {index: 1, name: b}
04 | 20 | Load {index: 0, name: a}
05 | 25 | Load {index: 1, name: b}
06 | 30 | Add
07 | 31 | Return
08 | 32 | Return
09 | 33 | Store {index: 2, name: add}
10 | 38 | Constant {index: 1, value: Number(2)}
11 | 43 | Constant {index: 2, value: Number(1)}
12 | 48 | Load {index: 2, name: add}
13 | 53 | Call {parametersCount: 2}
14 | 58 | Pop
*/

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
        var token_index = 0;
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
                case Function: 
                    var index = program.getInt32(pos);
                    pos += 4;
                    var argCount = program.getInt32(pos);
                    pos += 4;
                    var nameIndex = program.get(pos);
                    pos += 4;
                    [Instruction('fn'), Arg(index), Arg(argCount)];
                case Call: 
                    var argCount = program.getInt32(pos);
                    pos += 4;
                    [Instruction('call'), Arg(argCount)];
                // case _: [Error('[Unknown bytecode: "$code"]')];
            }

            var prev_token = (token_index > 0 ? bytecode.tokens[token_index - 1] : null);
            var cur_token = bytecode.tokens[token_index++];
            if (cur_token != null && prev_token != cur_token) {
                // lpad('line $l ║ ', 13)
                output += '\033[1;30mLine ${cur_token.line} (${cur_token.type} "${cur_token.lexeme}")\033[0m\n';
            }

            var disassembly = [ for (part in parts) color(part) ].join('');
            output += '· ${lpad(Std.string(ipPos), 5, "0")}  ${pos - ipPos}B  $disassembly\n';
        }
        return output;
    }
}
