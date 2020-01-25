package cosy;

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
            case If(cond, then, el): If(optimizeExpr(cond), optimizeStmt(then), (el != null ? optimizeStmt(el) : null));
            case Mut(name, init): Mut(name, (init != null ? optimizeExpr(init) : init));
            case Print(e): Print(optimizeExpr(e));
            case Var(name, init): Var(name, (init != null ? optimizeExpr(init) : init));
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
                        if (Std.is(v1, Float) && Std.is(v2, Float)) {
                            Expr.Literal(switch op.type {
                                case Plus:  (v1 :Float) + (v2 :Float);
                                case Minus: (v1 :Float) - (v2 :Float);
                                case Star:  (v1 :Float) * (v2 :Float);
                                case Slash: (v1 :Float) / (v2 :Float);
                                case _: Cosy.error(op, 'Invalid operator.'); return Expr.Binary(l, op, r);
                            });
                        } else if (Std.is(v1, String) && Std.is(v2, String)) {
                            Expr.Literal((v1 :String) + (v2 :String));
                        } else {
                            Expr.Binary(l, op, r);
                        }
                    case _: Expr.Binary(l, op, r);
                };
			case _: expr;
		}
    }
}
