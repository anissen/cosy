package lox;

typedef Variable = {
	var name:Token;
	var state:VariableState;
}

class Resolver {
	final interpreter:Interpreter;
	
	final scopes = new Stack<Map<String, Variable>>();
	var currentFunction:FunctionType = None;
	var currentClass:ClassType = None;
	
	public function new(interpreter) {
		this.interpreter = interpreter;
	}
	
	public inline function resolve(s) {
		resolveStmts(s);
	}
	
	function resolveStmts(stmts:Array<Stmt>) {
        var returnToken = null;
        for (stmt in stmts) {
            switch stmt {
                case Return(kw, _): returnToken = kw;
                case _:
                    if (returnToken != null) {
                        // TODO: We cannot report the correct token so we simply report the return token
                        Lox.error(returnToken, 'Unreachable code after return statement.');
                        returnToken = null;
                    }
            }
            resolveStmt(stmt);
        }
	}

	function resolveStmt(stmt:Stmt) {
		switch stmt {
			case Block(statements):
				beginScope();
				resolveStmts(statements);
				endScope();
			case Class(name, superclass, methods):
				var enclosingClass = currentClass;
				currentClass = Class;
				declare(name);
				define(name);
				
				if(superclass != null) {
					switch superclass {
						case Variable(sname) if(name.lexeme == sname.lexeme): Lox.error(sname, 'A class cannot inherit from itself');
						case _:
					}
					currentClass = Subclass;
					resolveExpr(superclass);
					beginScope();
					scopes.peek().set('super', { name: new Token(Super, 'super', null, name.line), state: Read });
				}
				
				beginScope();
				scopes.peek().set('this', { name: new Token(This, 'this', null, name.line), state: Read });
				
				for(method in methods) switch method {
					case Function(name, params, body):
						var declaration = name.lexeme == 'init' ? Initializer : Method;
						resolveFunction(name, params, body, declaration);
					case _: // unreachable
				}
				endScope();
				
				if(superclass != null) endScope();
				
				currentClass = enclosingClass;
			case Var(name, init):
				declare(name);
				if(init != null) resolveExpr(init);
				define(name);
            case For(name, from, to, body):
                declare(name);
                define(name);
                resolveExpr(from);
                resolveExpr(to);
                resolveStmt(body);
            case ForCondition(cond, body):
				if (cond != null) resolveExpr(cond);
				resolveStmt(body);
			case Function(name, params, body):
				declare(name);
				define(name);
				resolveFunction(name, params, body, Function);
			case Expression(e) | Print(e):
				resolveExpr(e);
			case If(cond, then, el):
				resolveExpr(cond);
				resolveStmt(then);
				if(el != null) resolveStmt(el);
			case Return(kw, val):
				if(currentFunction == None) Lox.error(kw, 'Cannot return from top-level code.');
				if(val != null) {
					if(currentFunction == Initializer) Lox.error(kw, 'Cannot return value from an initializer.');
					resolveExpr(val);
				}
		}
	}
	
	function resolveExpr(expr:Expr) {
		switch expr {
			case Assign(name, value):
				resolveExpr(value);
				resolveLocal(expr, name, false);
			case Variable(name):
				if(!scopes.isEmpty() && scopes.peek().exists(name.lexeme) && scopes.peek().get(name.lexeme).state.match(Declared))
					Lox.error(name, 'Cannot read local variable in its own initializer');
				resolveLocal(expr, name, true);
			case Binary(left, _, right) | Logical(left, _, right):
				resolveExpr(left);
				resolveExpr(right);
			case Call(callee, paren, arguments):
				resolveExpr(callee);
				for(arg in arguments) resolveExpr(arg);
			case Get(obj, name):
				resolveExpr(obj);
			case Set(obj, name, value):
				resolveExpr(value);
				resolveExpr(obj);
			case Grouping(e) | Unary(_, e):
				resolveExpr(e);
			case Super(kw, method):
				switch currentClass {
					case None: Lox.error(kw, 'Cannot use "super" outside of a class.');
					case Class: Lox.error(kw, 'Cannot use "super" in a class with no superclass.');
					case Subclass: // ok
				}
				resolveLocal(expr, kw, true);
			case This(kw):
				if(currentClass == None)
					Lox.error(kw, 'Cannot use "this" outside of a class.');
				else 
					resolveLocal(expr, kw, true);
			case Literal(_):
				// skip
			case AnonFunction(params, body): 
				resolveFunction(null, params, body, Function);
		}
	}
	
	function resolveFunction(name:Token, params:Array<Token>, body:Array<Stmt>, type:FunctionType) {
		var enclosingFunction = currentFunction;
		currentFunction = type;
		beginScope();
		for(param in params) {
			declare(param);
			define(param);
		}
        resolveStmts(body);
		endScope();
		currentFunction = enclosingFunction;
	}
	
	function beginScope() {
		scopes.push([]);
	}
	
	function endScope() {
		var scope = scopes.pop();

		for (name => variable in scope) {
			if (variable.state.match(Defined)) Lox.error(variable.name, "Local variable is not used.");
		}
	}
	
	function declare(name:Token) {
		if(scopes.isEmpty()) return;
		var scope = scopes.peek();
		if(scope.exists(name.lexeme)) Lox.error(name, 'Variable with this name already declared in this scope.');
		scope.set(name.lexeme, { name: name, state: Declared });
	}
	
	function define(name:Token) {
		if(scopes.isEmpty()) return;
		scopes.peek().set(name.lexeme, { name: name, state: Defined });
	}
	
	function resolveLocal(expr:Expr, name:Token, isRead:Bool) {
		var i = scopes.length - 1;
		while(i >= 0) {
			if(scopes.get(i).exists(name.lexeme)) {
				interpreter.resolve(expr, scopes.length - 1 - i);

				if(isRead) {
					scopes.get(i).get(name.lexeme).state = Read;
				}
				return;
			}
			i--;
		}
	}
}

@:forward(push, pop, length)
abstract Stack<T>(Array<T>) {
	public inline function new() this = [];
	public inline function isEmpty() return this.length == 0;
	public inline function peek() return this[this.length - 1];
	public inline function get(i:Int) return this[i];
}
private enum VariableState {
	Declared;
	Defined;
	Read;
}
private enum FunctionType {
	None;
	Method;
	Initializer;
	Function;
}
private enum ClassType {
	None;
	Class;
	Subclass;
}
