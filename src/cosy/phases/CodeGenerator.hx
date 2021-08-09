package cosy.phases;

import haxe.io.Bytes;
import haxe.io.BytesOutput;

enum ByteCodeOp {
    ConstantString(str: String);
    GetLocal(index: Int);
    SetLocal(index: Int);
    Pop(n: Int);
    PushTrue;
    PushFalse;
    PushNumber(n: Float);
    BinaryOp(type: TokenType);
    Function(argCount: Int, name: String);
    Call(argCount: Int);
    Return;

    JumpIfFalse;
    JumpIfTrue;
    Jump;
    Print;
    Equal;
    Addition;
    Subtraction;
    Multiplication;
    Division;
    Modulus;
    Less;
    LessEqual;
    Greater;
    GreaterEqual;
    Negate;
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
    final Modulus;
    final Less;
    final LessEqual;
    final Greater;
    final GreaterEqual;
    final Negate;
    final Function;
    final Call;
    final Return;
}

typedef FunctionDefinition = {
    var name: String;
    var pos: Int;
    var length: Int;
}

class Output {
    public var strings: Array<String> = [];
    public var functions: Array<FunctionDefinition> = [];
    public var bytecode: Bytes;
    public var tokens = new Map<Int, Token>();

    public function new() {}
}

class CodeGenerator {
    var localsCounter: Int;
    var localIndexes: Map<String, Int>;
    var output: Output;
    var emitCount = 0;

    var bytes: BytesOutput; // TODO: Bytecode may not be compatible between target languages due to differences in how bytes are represented in haxe.io.Bytes

    public function new() {}

    public inline function generate(stmts: Array<Stmt>): Output {
        localsCounter = 0;
        localIndexes = new Map();
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
                add_token(keyword);
                genExpr(expr);
                emit(Print);
            case Var(name, type, init, mut, foreign):
                add_token(name);
                genExpr(init);
                localIndexes[name.lexeme] = localsCounter++;
            case Block(statements):
                var previousLocalsCounter = localsCounter;
                genStmts(statements);
                var pops = localsCounter - previousLocalsCounter;
                if (pops > 0) emit(Pop(pops));
                localsCounter = previousLocalsCounter;
            case If(keyword, cond, then, el):
                add_token(keyword);
                genExpr(cond);
                var thenJump = emitJump(JumpIfFalse);
                emit(Pop(1));
                genStmt(then);

                var elseJump = emitJump(Jump);

                patchJump(thenJump);
                emit(Pop(1));

                if (el != null) genStmt(el);
                patchJump(elseJump);
            case For(keyword, name, from, to, body):
                add_token(keyword);
                // TODO: Ignore counter variable if it begins with underscore.

                genExpr(from);
                final localsIndex = localsCounter++;
                localIndexes[name.lexeme] = localsIndex;
                // Initialize counter variable to 'from'.
                emit(SetLocal(localsIndex));

                var loopStart = bytes.length;

                // Test if counter variable is less than 'to'.
                emit(GetLocal(localsIndex));
                genExpr(to);
                emit(Less);

                var exitJump = emitJump(JumpIfFalse);
                emit(Pop(1));
                genStmts(body);

                // Increment counter variable TODO: Could be replaced by an increment instruciton, e.g. "Inc(index)"
                emit(GetLocal(localsIndex));
                emit(PushNumber(1));
                emit(Addition);
                emit(SetLocal(localsIndex));
                emit(Pop(1));

                emitLoop(loopStart);

                patchJump(exitJump);
                emit(Pop(1));
            case ForCondition(keyword, cond, body):
                add_token(keyword);
                var loopStart = bytes.length;
                if (cond != null) {
                    genExpr(cond);
                    var exitJump = emitJump(JumpIfFalse);
                    emit(Pop(1));
                    genStmts(body);

                    emitLoop(loopStart);

                    patchJump(exitJump);
                    emit(Pop(1));
                } else {
                    throw 'infinite loops are not yet implemented!';
                }
            case Function(name, params, body, returnType, foreign):
                add_token(name);
                // final functionsIndex = output.functions.length;
                // emit(PushNumber(functionsIndex));
                emit(Function(params.length, name.lexeme));
                final localsIndex = localsCounter++;
                localIndexes[name.lexeme] = localsIndex;
                emit(SetLocal(localsIndex));

                var funcJump = emitJump(Jump);

                for (i => param in params) { // TODO: must be in a function frame (otherwise i is not unique)
                    localIndexes[param.name.lexeme] = localsCounter++;
                    emit(SetLocal(i));
                }
                genStmts(body);
                emit(Return);
                patchJump(funcJump);
            //     trace('function ${name.lexeme}');
            case Expression(expr): genExpr(expr);
            case _:
                trace('Unhandled statement: $stmt');
                [];
        }
    }

    function genExpr(expr: Expr) {
        if (expr == null) return;
        switch expr {
            case Assign(name, op, value):
                final localIndex = localIndexes[name.lexeme];
                add_token(name);
                genExpr(value);
                switch op.type {
                    case Equal: emit(SetLocal(localIndex));
                    case PlusEqual:
                        // TODO: We need to know the type of `name` here in order to produce optimized bytecode (instead of having to typecheck in the VM)

                        emit(GetLocal(localIndex));
                        emit(Addition);
                        emit(SetLocal(localIndex));
                    // case MinusEqual:
                    //     final left = lookUpVariable(name, expr);
                    //     final right = evaluate(value);
                    //     checkNumberOperands(op, left, right);
                    //     (left: Float) - (right: Float);
                    // case SlashEqual:
                    //     final left = lookUpVariable(name, expr);
                    //     final right = evaluate(value);
                    //     checkNumberOperands(op, left, right);
                    //     (left: Float) / (right: Float);
                    // case StarEqual:
                    //     final left = lookUpVariable(name, expr);
                    //     final right = evaluate(value);
                    //     checkNumberOperands(op, left, right);
                    //     (left: Float) * (right: Float);
                    // case PercentEqual:
                    //     final left = lookUpVariable(name, expr);
                    //     final right = evaluate(value);
                    //     checkNumberOperands(op, left, right);
                    //     (left: Float) % (right: Float);
                    case _: throw 'Unhandled case ${op.type}';
                }
            case Binary(left, op, right):
                add_token(op);
                genExpr(left);
                genExpr(right);
                emit(BinaryOp(op.type));
            case Call(callee, paren, arguments):
                add_token(paren);
                genExprs(arguments);
                genExpr(callee);
                emit(Call(arguments.length));
            // Load function?
            case Literal(v) if (Std.isOfType(v, Bool)): (v ? emit(PushTrue) : emit(PushFalse));
            case Literal(v) if (Std.isOfType(v, Float)): emit(PushNumber(v));
            case Literal(v) if (Std.isOfType(v, String)): emit(ConstantString(v));
            case Grouping(expr): genExpr(expr);
            case Variable(name):
                add_token(name);
                emit(GetLocal(localIndexes[name.lexeme]));
            case Logical(left, op, right):
                add_token(op);
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
            case Unary(op, right):
                add_token(op);
                if (!op.type.match(Minus)) throw 'error';
                genExpr(right);
                emit(Negate);
            // case _: trace('Unhandled expression: $expr'); [];
            case _: throw 'Unhandled expression: $expr';
        }
    }

    function add_token(token: Token) {
        if (!output.tokens.exists(emitCount)) {
            output.tokens[emitCount] = token;
        }
    }

    function emit(op: ByteCodeOp) {
        emitCount++;
        switch op {
            case Print: bytes.writeByte(ByteCodeOpValue.Print);
            case ConstantString(str):
                var stringIndex = output.strings.length;
                output.strings.push(str);
                bytes.writeByte(ByteCodeOpValue.ConstantString);
                bytes.writeInt32(stringIndex);
            case GetLocal(index):
                bytes.writeByte(ByteCodeOpValue.GetLocal);
                bytes.writeByte(index);
            case SetLocal(index):
                bytes.writeByte(ByteCodeOpValue.SetLocal);
                bytes.writeByte(index);
            case Pop(n):
                bytes.writeByte(ByteCodeOpValue.Pop);
                bytes.writeByte(n);
            case PushTrue: bytes.writeByte(ByteCodeOpValue.PushTrue);
            case PushFalse: bytes.writeByte(ByteCodeOpValue.PushFalse);
            case PushNumber(n):
                bytes.writeByte(ByteCodeOpValue.PushNumber);
                bytes.writeFloat(n);
            case BinaryOp(type): bytes.writeByte(binaryOpCode(type));
            case Call(argCount):
                bytes.writeByte(ByteCodeOpValue.Call);
                bytes.writeByte(argCount);
            case Function(argCount, name):
                var functionStart = bytes.length + 12; // TODO: HACK, +12 is to skip the following jump statement
                bytes.writeByte(ByteCodeOpValue.Function);
                bytes.writeInt32(functionStart);
            // bytes.writeByte(argCount);

            // var stringIndex = output.strings.length;
            // output.strings.push(name);
            // bytes.writeInt32(stringIndex);

            // var functionIndex = output.functions.length;
            // output.functions.push({ name: name, pos: functionStart, length: (bytes.length + 19) - functionStart });
            // bytes.writeInt32(functionIndex);
            case Return: bytes.writeByte(ByteCodeOpValue.Return);
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
            case Modulus: bytes.writeByte(ByteCodeOpValue.Modulus);
            case Less: bytes.writeByte(ByteCodeOpValue.Less);
            case LessEqual: bytes.writeByte(ByteCodeOpValue.LessEqual);
            case Greater: bytes.writeByte(ByteCodeOpValue.Greater);
            case GreaterEqual: bytes.writeByte(ByteCodeOpValue.GreaterEqual);
            case Negate: bytes.writeByte(ByteCodeOpValue.Negate);
        }
    }

    function emitJump(op: ByteCodeOp): Int {
        emit(op);
        return bytes.length - 4; // -4 for the jump argument
    }

    function emitLoop(loopStart: Int) {
        bytes.writeByte(ByteCodeOpValue.Jump);
        var offset = bytes.length - loopStart + 4;
        bytes.writeInt32(-offset);
    }

    function patchJump(offset: Int) {
        var jump = bytes.length - offset - 4;
        overwriteInstruction(offset, jump);
    }

    // TODO: This is probably expensive, but there seems to be no other way (except having the bytes buffer be an Array<Int>)
    function overwriteInstruction(pos: Int, value: Int) {
        final currentBytes = bytes.getBytes();
        currentBytes.setInt32(pos, value);
        bytes = new BytesOutput();
        bytes.write(currentBytes);
    }

    function binaryOpCode(type: TokenType): ByteCodeOpValue {
        return switch type {
            case EqualEqual: Equal;
            case Plus: Addition;
            case Minus: Subtraction;
            case Star: Multiplication;
            case Slash: Division;
            case Percent: Modulus;
            case Less: Less;
            case LessEqual: LessEqual;
            case Greater: Greater;
            case GreaterEqual: GreaterEqual;
            case _:
                trace('unhandled type: $type');
                throw 'error';
        }
    }
}
