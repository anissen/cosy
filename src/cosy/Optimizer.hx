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
			case Var(name, init): Var(name, (init != null ? optimizeExpr(init) : init));
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
                        if (Std.is(v1, Float) && Std.is(v2, Float)) Expr.Literal((v1 :Float) + (v2 :Float));
                        else Expr.Binary(l, op, r);
                    case _: Expr.Binary(l, op, r);
                };
			case _: expr;
		}
    }
}
