package cosy.phases;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;

// typedef ByteCode = {
//     opcode: String,
//     value: Null<Any>,
// }

enum ByteCodeOp {
    Print;
    ConstantString(str: String);
    GetLocal(index: Int);
    // SetLocal(index :Int);
    Pop(n: Int);
    PushTrue;
    PushFalse;
    PushNumber(n: Float);
    BinaryOp(type: TokenType);
}

class ByteCodeOpValue { // TODO: Auto-create this class by a macro?
    static public final Print = 0x0;
    static public final ConstantString = 0x1;
    static public final GetLocal = 0x2;
    static public final Pop = 0x3;
    static public final PushTrue = 0x4;
    static public final PushFalse = 0x5;
    static public final PushNumber = 0x6;
    static public final BinaryOp = 0x7;
}

// enum abstract ByteCodeValue(Int) {
//     var PrintByte; // implicit value: 0
//     var NoOpByte;
//     var PopByte;
//     var GetLocalByte;
// }

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
    var output: Output;

    var bytesBuffer: BytesBuffer; // TODO: Bytecode may not be compatible between target languages due to differences in how bytes are represented in haxe.io.Bytes

	public function new() {

	}

	public inline function generate(stmts: Array<Stmt>): Output {
        localsCounter = 0;
        constantsCounter = 0;
        localIndexes = new Map();
        // bytecode = [];
        output = new Output();
        bytesBuffer = new BytesBuffer();
        genStmts(stmts);
        output.bytecode = bytesBuffer.getBytes();
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
		switch stmt {
            case Print(keyword, expr):
                genExpr(expr);
                emit(Print);
            case Var(name, type, init, mut, foreign):
                if (init != null) genExpr(init);
                localIndexes[name.lexeme] = localsCounter++;
                // emit(GetLocal(localsCounter++));
            case Block(statements):
                var previousLocalsCounter = localsCounter;
                genStmts(statements);
                emit(Pop(localsCounter - previousLocalsCounter));
                // for (_ in previousLocalsCounter...localsCounter) {
                //     emit(Pop);
                // }
                localsCounter = previousLocalsCounter;
            case Expression(expr):
                genExpr(expr);
			case _: trace('Unhandled statement: $stmt'); [];
		}
	}

    // TODO: We also need line information for each bytecode
	function genExpr(expr: Expr) {
		switch expr {
            case Assign(name, op, value): genExpr(value); //.concat(['save_var', name.lexeme]);
            case Binary(left, op, right): genExpr(left); genExpr(right); emit(BinaryOp(op.type));
            case Literal(v) if (Std.isOfType(v, Bool)): (v ? emit(PushTrue) : emit(PushFalse));
            case Literal(v) if (Std.isOfType(v, Float)): emit(PushNumber(v));
            case Literal(v) if (Std.isOfType(v, String)): emit(ConstantString(v));
            case Grouping(expr): genExpr(expr);
            case Variable(name): emit(GetLocal(localIndexes[name.lexeme]));
            case Unary(op, right): if (!op.type.match(Minus)) throw 'error'; genExpr(right); //.concat(['op_negate']);
			case _: trace('Unhandled expression: $expr'); [];
		}
    }

    function emit(op :ByteCodeOp) {
        switch op {
            case Print: bytesBuffer.addByte(ByteCodeOpValue.Print);
            case ConstantString(str):
                var stringIndex = output.strings.length;
                output.strings.push(str);
                bytesBuffer.addByte(ByteCodeOpValue.ConstantString);
                bytesBuffer.addByte(stringIndex);
            case GetLocal(index): 
                // 'get_local $index';
                // [ByteCodeOpValue.GetLocal, index];
                bytesBuffer.addByte(ByteCodeOpValue.GetLocal);
                bytesBuffer.addByte(index);
                // case SetLocal(index): 'set_local $index';
            case Pop(n): 
                // 'pop $n';
                // [ByteCodeOpValue.Pop, n];
                bytesBuffer.addByte(ByteCodeOpValue.Pop);
                bytesBuffer.addByte(n);
            case PushTrue: 
                // 'push_true';
                bytesBuffer.addByte(ByteCodeOpValue.PushTrue);
            case PushFalse:
                // 'push_false';
                // [ByteCodeOpValue.PushTrue];
                bytesBuffer.addByte(ByteCodeOpValue.PushFalse);
            case PushNumber(n):
                // 'push_num $n';
                // [ByteCodeOpValue.PushNumber, BytesData. n];
                bytesBuffer.addByte(ByteCodeOpValue.PushNumber);
                bytesBuffer.addFloat(n);
            case BinaryOp(type): 
                // [binaryOpCode(type)];
                bytesBuffer.addByte(binaryOpCode(type)); // TODO: This is wrong as it maps into ByteCodeOpValue
        }
    }

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

    function binaryOpCode(type: TokenType) {
        return ByteCodeOpValue.BinaryOp + type.getIndex(); // HACK: Horrible hack!
        // return switch type {
        //     case EqualEqual: 'op_equals';
        //     case Plus: 'op_add';
        //     case Minus: 'op_sub';
        //     case Star: 'op_mult';
        //     case Slash: 'op_div';
        //     case Less: 'op_less';
        //     case LessEqual: 'op_less_eq';
        //     case Greater: 'op_greater';
        //     case GreaterEqual: 'op_greater_eq';
        //     case _: throw 'error';
        // }
    }
}
