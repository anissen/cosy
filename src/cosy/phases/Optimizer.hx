package cosy.phases;

class Optimizer {
	public function new() {

	}
	
	public inline function optimize(stmts:Array<Stmt>) :Array<Stmt> {
        return optimizeStmts(stmts);
	}

	function optimizeStmts(stmts: Array<Stmt>) {
        return [ for (stmt in stmts) optimizeStmt(stmt) ];
	}

    function optimizeExprs(exprs: Array<Expr>) {
        return [ for (expr in exprs) optimizeExpr(expr) ];
    }

	function optimizeStmt(stmt: Stmt) :Stmt {
		return switch stmt {
            case Block(statements): Block(optimizeStmts(statements));
            case Expression(e): Expression(optimizeExpr(e));
            case If(keyword, cond, then, el): If(keyword, optimizeExpr(cond), optimizeStmt(then), (el != null ? optimizeStmt(el) : null));
            case Print(keyword, e): Print(keyword, optimizeExpr(e));
            case Var(name, type, init, mut, foreign): Var(name, type, (init != null ? optimizeExpr(init) : init), mut, foreign);
            case Return(keyword, value): Return(keyword, (value != null ? optimizeExpr(value) : null));
			case _: stmt;
		}
	}
	
	function optimizeExpr(expr: Expr) :Expr {
		return switch expr {
			case Binary(left, op, right): 
                var l = optimizeExpr(left);
                var r = optimizeExpr(right);
                return switch [l, r] {
                    case [Expr.Literal(v1), Expr.Literal(v2)]:
                        if (Std.isOfType(v1, Float) && Std.isOfType(v2, Float)) {
                            Expr.Literal(switch op.type {
                                case Plus:  (v1 :Float) + (v2 :Float);
                                case Minus: (v1 :Float) - (v2 :Float);
                                case Star:  (v1 :Float) * (v2 :Float);
                                case Slash: (v1 :Float) / (v2 :Float);
                                case Less:  (v1 :Float) < (v2 :Float);
                                case LessEqual: (v1 :Float) <= (v2 :Float);
                                case Greater: (v1 :Float) > (v2 :Float);
                                case GreaterEqual: (v1 :Float) >= (v2 :Float);
                                case EqualEqual: (v1 :Float) == (v2 :Float);
                                case BangEqual: (v1 :Float) != (v2 :Float);
                                case _: Cosy.error(op, 'Invalid operator.'); return Expr.Binary(l, op, r);
                            });
                        } else if (Std.isOfType(v1, String) && Std.isOfType(v2, String)) {
                            Expr.Literal((v1 :String) + (v2 :String));
                        } else {
                            Expr.Binary(l, op, r);
                        }
                    case _: Expr.Binary(l, op, r);
                };
            case Logical(left, op, right):
                var l = optimizeExpr(left);
                var r = optimizeExpr(right);
                return switch [l, r] {
                    case [Expr.Literal(v1), Expr.Literal(v2)] if (Std.isOfType(v1, Bool) && Std.isOfType(v2, Bool)):
                        Expr.Literal(switch op.type {
                            case And: (v1 :Bool) && (v2 :Bool);
                            case Or: (v1 :Bool) || (v2 :Bool);
                            case _: Cosy.error(op, 'Invalid operator.'); return Expr.Binary(l, op, r);
                        });
                    case _: Expr.Logical(l, op, r);
                }
			case _: expr;
		}
    }
}
