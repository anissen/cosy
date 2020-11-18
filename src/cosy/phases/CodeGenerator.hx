package cosy.phases;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesOutput;

// typedef ByteCode = {
//     opcode: String,
//     value: Null<Any>,
// }

enum ByteCodeOp {
    ConstantString(str: String);
    GetLocal(index: Int);
    SetLocal(index :Int);
    Pop(n: Int);
    PushTrue;
    PushFalse;
    PushNumber(n: Float);
    BinaryOp(type: TokenType);

    JumpIfFalse;
    JumpIfTrue;
    Jump;
    Print;
    Equal;
    Addition;
    Subtraction;
    Multiplication;
    Division;
    Less;
    LessEqual;
    Greater;
    GreaterEqual;
}

enum abstract ByteCodeOpValue(Int) to Int from Int {
    // New instructions *must* be added at the end to avoid breaking backwards compability
    final NoOp = 0;
    final ConstantString;
    final GetLocal;
    final SetLocal;
    final Pop;
    final PushTrue;
    final PushFalse;
    final PushNumber;
    final JumpIfFalse;
    final JumpIfTrue;
    final Jump;
    final Print;
    final Equal;
    final Addition;
    final Subtraction;
    final Multiplication;
    final Division;
    final Less;
    final LessEqual;
    final Greater;
    final GreaterEqual;
}

// typedef Byte = Int; //TODO: Should be packed as bytes

abstract Byte(Int) from Int to Int {
    inline function new(value: Int) {
        if (value < 0 || value > 255) throw 'Invalid byte value: $value';
        this = value;
    }
}

class Output {
    // functionIPs: Map<String, int>,
    public var strings: Array<String>;
    public var bytecode: Bytes;

    public function new() {
        strings = [];
        // bytecode = new Bytes();
    }
}

class CodeGenerator {
    var localsCounter :Int;
    var localIndexes :Map<String, Int>;
    var constantsCounter :Int;
    // var bytecode :Array<String>;
    var codes: Array<ByteCodeOp>;
    var output: Output;

    var bytes: BytesOutput; // TODO: Bytecode may not be compatible between target languages due to differences in how bytes are represented in haxe.io.Bytes

	public function new() {

	}

	public inline function generate(stmts: Array<Stmt>): Output {
        localsCounter = 0;
        constantsCounter = 0;
        localIndexes = new Map();
        // bytecode = [];
        codes = [];
        output = new Output();
        bytes = new BytesOutput();
        genStmts(stmts);
        output.bytecode = bytes.getBytes();
        return output;
    }

	function genStmts(stmts: Array<Stmt>) {
        for (stmt in stmts) {
            genStmt(stmt);
        }
	}

    function genExprs(exprs: Array<Expr>) {
        for (expr in exprs) {
            genExpr(expr);
        }
    }

	function genStmt(stmt: Stmt) {
        if (stmt == null) return;
		switch stmt {
            case Print(keyword, expr):
                genExpr(expr);
                emit(Print);
            case Var(name, type, init, mut, foreign):
                genExpr(init);
                localIndexes[name.lexeme] = localsCounter++;
                // emit(GetLocal(localsCounter++));
            case Block(statements):
                var previousLocalsCounter = localsCounter;
                genStmts(statements);
                var pops = localsCounter - previousLocalsCounter;
                if (pops > 0) emit(Pop(pops));
                localsCounter = previousLocalsCounter;
            case If(cond, then, el):
                genExpr(cond);
                var thenJump = emitJump(JumpIfFalse);
                emit(Pop(1));
                genStmt(then);
                
                var elseJump = emitJump(Jump);

                patchJump(thenJump);
                emit(Pop(1));

                if (el != null) genStmt(el);
                patchJump(elseJump);

            case ForCondition(cond, body):
                var loopStart = bytes.length;
                if (cond != null) {
                    genExpr(cond);
                    var exitJump = emitJump(JumpIfFalse);
                    emit(Pop(1));
                    genStmts(body);
                    
                    emitLoop(loopStart);

                    patchJump(exitJump);
                    emit(Pop(1));
                }


            // case ForCondition(cond, body):
            //     var start = mark();
            //     genExpr(cond);
            //     emit(JumpIfZero(end));
            //     genStmts(body);
            //     emit(Jump(start));
            //     var end = label();
            case Expression(expr):
                genExpr(expr);
			case _: trace('Unhandled statement: $stmt'); [];
		}
    }
    
    // function mark() {
    //     return output.bytecode.length;
    // }

    // TODO: We also need line information for each bytecode
	function genExpr(expr: Expr) {
		switch expr {
            case Assign(name, op, value): genExpr(value); emit(SetLocal(localIndexes[name.lexeme]));
            case Binary(left, op, right): genExpr(left); genExpr(right); emit(BinaryOp(op.type));
            case Literal(v) if (Std.isOfType(v, Bool)):
                // localsCounter++;
                (v ? emit(PushTrue) : emit(PushFalse));
            case Literal(v) if (Std.isOfType(v, Float)):
                // localsCounter++;
                emit(PushNumber(v));
            case Literal(v) if (Std.isOfType(v, String)):
                // localsCounter++;
                emit(ConstantString(v));
            case Grouping(expr): genExpr(expr);
            case Variable(name): emit(GetLocal(localIndexes[name.lexeme]));
            case Logical(left, op, right):
                genExpr(left);
                switch op.type {
                    case And:
                        var endJump = emitJump(JumpIfFalse);
                        emit(Pop(1));
                        genExpr(right);
                        patchJump(endJump);
                    case Or:
                        var endJump = emitJump(JumpIfTrue);
                        emit(Pop(1));
                        genExpr(right);
                        patchJump(endJump);
                    case _: throw 'Unhandled Logical case!';
                }
            case Unary(op, right): if (!op.type.match(Minus)) throw 'error'; genExpr(right); //.concat(['op_negate']);
			case _: trace('Unhandled expression: $expr'); [];
		}
    }

    // function patchJumps() {
    //     var labels = new Map<String, Int>();
    //     for (code in codes) {
    //         switch code {
    //             case Label(lbl): 
    //         }
    //     }
    // }

    // function emit(op: ByteCodeOp) {
    //     codes.push(op);
    // }

    function emit(op: ByteCodeOp) {
        // trace('emit $op');
        // var bytesCopy = bytes;
        // trace(Disassembler.disassemble(bytesCopy.getBytes()));
        switch op {
            case Print: 
                bytes.writeByte(ByteCodeOpValue.Print);
            case ConstantString(str):
                var stringIndex = output.strings.length;
                output.strings.push(str);
                bytes.writeByte(ByteCodeOpValue.ConstantString);
                bytes.writeInt32(stringIndex);
            case GetLocal(index): 
                // 'get_local $index';
                // [ByteCodeOpValue.GetLocal, index];
                bytes.writeByte(ByteCodeOpValue.GetLocal);
                bytes.writeByte(index);
                // case SetLocal(index): 'set_local $index';
            case SetLocal(index): 
                // 'get_local $index';
                // [ByteCodeOpValue.GetLocal, index];
                bytes.writeByte(ByteCodeOpValue.SetLocal);
                bytes.writeByte(index);
                // case SetLocal(index): 'set_local $index';
            case Pop(n): 
                // 'pop $n';
                // [ByteCodeOpValue.Pop, n];
                bytes.writeByte(ByteCodeOpValue.Pop);
                bytes.writeByte(n);
            case PushTrue: 
                // 'push_true';
                bytes.writeByte(ByteCodeOpValue.PushTrue);
            case PushFalse:
                // 'push_false';
                // [ByteCodeOpValue.PushTrue];
                bytes.writeByte(ByteCodeOpValue.PushFalse);
            case PushNumber(n):
                // 'push_num $n';
                // [ByteCodeOpValue.PushNumber, BytesData. n];
                bytes.writeByte(ByteCodeOpValue.PushNumber);
                bytes.writeFloat(n);
            case BinaryOp(type): 
                // [binaryOpCode(type)];
                bytes.writeByte(binaryOpCode(type));
            case JumpIfFalse:
                bytes.writeByte(ByteCodeOpValue.JumpIfFalse);
                bytes.writeInt32(666); // placeholder for jump argument
            case JumpIfTrue:
                bytes.writeByte(ByteCodeOpValue.JumpIfTrue);
                bytes.writeInt32(666); // placeholder for jump argument
            case Jump:
                bytes.writeByte(ByteCodeOpValue.Jump);
                bytes.writeInt32(666); // placeholder for jump argument
            case Equal: bytes.writeByte(ByteCodeOpValue.Equal);
            case Addition: bytes.writeByte(ByteCodeOpValue.Addition);
            case Subtraction: bytes.writeByte(ByteCodeOpValue.Subtraction);
            case Multiplication: bytes.writeByte(ByteCodeOpValue.Multiplication);
            case Division: bytes.writeByte(ByteCodeOpValue.Division);
            case Less: bytes.writeByte(ByteCodeOpValue.Less);
            case LessEqual: bytes.writeByte(ByteCodeOpValue.LessEqual);
            case Greater: bytes.writeByte(ByteCodeOpValue.Greater);
            case GreaterEqual: bytes.writeByte(ByteCodeOpValue.GreaterEqual);
        }
        // bytesCopy = bytes;
        // trace(Disassembler.disassemble(bytesCopy.getBytes()));
    }

    function emitJump(op: ByteCodeOp): Int {
        emit(op);
        return bytes.length - 4; // -4 for the jump argument
    }

    function emitLoop(loopStart: Int) {
        bytes.writeByte(ByteCodeOpValue.Jump);
        var offset = bytes.length - loopStart + 4;
        // trace('loop offset: $offset (from ${bytes.length} to ${loopStart + 4})');
        bytes.writeInt32(-offset);
    }

    function patchJump(offset: Int) {
        var jump = bytes.length - offset - 4;
        // if (jump > 2147483647) {
        //     throw 'Too much code to jump over';
        // }
        // trace('offset: $offset, jump: $jump');
        overwriteInstruction(offset, jump);

        // TODO: Write a disassembler to help debugging
    }

    // TODO: This is probably expensive, but there seems to be no other way (except having the bytes buffer be an Array<Int>)
    function overwriteInstruction(pos: Int, value: Int) {
        final currentBytes = bytes.getBytes();
        // trace('before: ${currentBytes.getInt32(pos)}');
        currentBytes.setInt32(pos, value);
        // trace('after: ${currentBytes.getInt32(pos)}');
        bytes = new BytesOutput();
        bytes.write(currentBytes);
    }


    // TODO: Maybe output a ByteCodeEnum instead of raw bytecode. This would be way simpler to output and to patch jump offsets. A separate function could then convert it one-to-one to bytecode. BUT we don't know how many bytes to jump then :'(

    // function emit(op :ByteCodeOp) {
    //     var codes: Array<Byte> = switch op {
    //         case Print: [ByteCodeOpValue.Print];
    //         case ConstantString(str):
    //             var stringIndex = output.strings.length;
    //             output.strings.push(str);
    //             [ByteCodeOpValue.ConstantString, stringIndex];
    //         case GetLocal(index): 
    //             // 'get_local $index';
    //             [ByteCodeOpValue.GetLocal, index];
    //         // case SetLocal(index): 'set_local $index';
    //         case Pop(n): 
    //             // 'pop $n';
    //             [ByteCodeOpValue.Pop, n];
    //         case PushTrue: 
    //             // 'push_true';
    //             [ByteCodeOpValue.PushTrue];
    //         case PushFalse:
    //             // 'push_false';
    //             [ByteCodeOpValue.PushTrue];
    //         case PushNumber(n):
    //             // 'push_num $n';
    //             [ByteCodeOpValue.PushNumber, BytesData. n];
    //         case BinaryOp(type): [binaryOpCode(type)];
    //     }
        
    //     // bytecode.push(code);
    //     // bytecode.push('${op.getIndex()}');
    //     codes.map(c -> output.bytecode.push);
    //     // output.bytecode.push(op.getIndex());
    // }

    function binaryOpCode(type: TokenType): ByteCodeOpValue {
        // return ByteCodeOpValue.And + type.getIndex(); // HACK: Horrible hack!
        return switch type {
            case EqualEqual: Equal;
            case Plus: Addition;
            case Minus: Subtraction;
            case Star: Multiplication;
            case Slash: Division;
            case Less: Less;
            case LessEqual: LessEqual;
            case Greater: Greater;
            case GreaterEqual: GreaterEqual;
            case _: trace('unhandled type: $type'); throw 'error';
        }
    }
}
