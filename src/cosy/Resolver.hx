package cosy;

typedef Variable = {
	var name:Token;
    var state:VariableState;
    var mutable:Bool;
    var member:Bool;
}

class Resolver {
	final interpreter:Interpreter;
	
	final scopes = new Stack<Map<String, Variable>>();
	var currentFunction:FunctionType = None;
	var currentStruct:StructType = None;
	var currentClass:ClassType = None;
	
	public function new(interpreter) {
		this.interpreter = interpreter;
	}
	
	public inline function resolve(s) {
        beginScope();
		resolveStmts(s);
        endScope();
	}
	
	function resolveStmts(stmts:Array<Stmt>) {
        var returnToken = null;
        for (stmt in stmts) {
            switch stmt {
                case Break(kw): returnToken = kw;
                case Continue(kw): returnToken = kw;
                case Return(kw, _): returnToken = kw;
                case _:
                    if (returnToken != null) {
                        // We cannot report the correct token so we simply report the return token
                        Cosy.error(returnToken, 'Unreachable code after return statement.');
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
            case Break(keyword):
            case Continue(keyword):
			case Class(name, superclass, methods):
				var enclosingClass = currentClass;
				currentClass = Class;
				declare(name);
				define(name);
				
				if(superclass != null) {
					switch superclass {
						case Variable(sname) if(name.lexeme == sname.lexeme): Cosy.error(sname, 'A class cannot inherit from itself');
						case _:
					}
					currentClass = Subclass;
					resolveExpr(superclass);
					beginScope();
					scopes.peek().set('super', { name: new Token(Super, 'super', null, name.line), state: Read, mutable: false, member: false });
				}
				
				beginScope();
				scopes.peek().set('this', { name: new Token(This, 'this', null, name.line), state: Read, mutable: false, member: false });
				
				for(method in methods) switch method {
					case Function(name, params, body, returnType, foreign):
						var declaration = name.lexeme == 'init' ? Initializer : Method;
						resolveFunction(name, params, body, declaration);
					case _: // unreachable
				}
				endScope();
				
				if(superclass != null) endScope();
				
				currentClass = enclosingClass;
			case Var(name, type, init, foreign):
                if (foreign && !Cosy.foreignVariables.exists(name.lexeme)) Cosy.error(name, 'Foreign variable not set.');
                var member = currentStruct.match(Struct);
				declare(name, false, member);
				if(init != null) resolveExpr(init);
				define(name, false, member);
            case Mut(name, type, init, foreign):
                if (foreign && !Cosy.foreignVariables.exists(name.lexeme)) Cosy.error(name, 'Foreign variable not set.');
                var member = currentStruct.match(Struct);
				declare(name, true, member);
				if(init != null) resolveExpr(init);
				define(name, true, member);
            case For(keyword, name, from, to, body):
                resolveExpr(from);
                resolveExpr(to);
                
                beginScope();
                if (name != null) {
                    declare(name);
                    define(name);
                }
                if (body.length == 0) Cosy.error(keyword, 'Loop body is empty.');
                resolveStmts(body);
                endScope();
            case ForArray(name, array, body):
                resolveExpr(array);
                
                beginScope();
                declare(name);
                define(name);
                if (body.length == 0) Cosy.error(name, 'Loop body is empty.');
                resolveStmts(body);
                endScope();
            case ForCondition(cond, body):
				if (cond != null) resolveExpr(cond);
                beginScope();
				resolveStmts(body);
                endScope();
			case Function(name, params, body, returnType, foreign):
                if (foreign) {
                    var found = false;
                    for (foreignFunc in Cosy.foreignFunctions) {
                        if (foreignFunc.name() == name.lexeme) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) Cosy.error(name, 'Foreign function not set.');
                }
				declare(name);
				define(name);
                if (!foreign) resolveFunction(name, params, body, Function);
			case Expression(e) | Print(e):
				resolveExpr(e);
			case If(cond, then, el):
				resolveExpr(cond);
				resolveStmt(then);
				if(el != null) resolveStmt(el);
			case Return(kw, val):
				if(currentFunction == None) Cosy.error(kw, 'Cannot return from top-level code.');
				if(val != null) {
					if(currentFunction == Initializer) Cosy.error(kw, 'Cannot return value from an initializer.');
					resolveExpr(val);
                }
            case Struct(name, declarations):
                declare(name);
                define(name);
                currentStruct = Struct;
                beginScope();
                resolveStmts(declarations);
                endScope();
                currentStruct = None;
		}
	}
	
	function resolveExpr(expr:Expr) {
		switch expr {
            case ArrayLiteral(keyword, exprs):
                for (expr in exprs) resolveExpr(expr);
			case Assign(name, op, value):
                var variable = findInScopes(name);
                if (variable != null && !variable.mutable) Cosy.error(name, 'Cannot reassign non-mutable variable.');
				resolveExpr(value);
				resolveLocal(expr, name, false);
			case Variable(name):
				if (scopes.peek().exists(name.lexeme) && scopes.peek().get(name.lexeme).state.match(Declared))
					Cosy.error(name, 'Cannot read local variable in its own initializer');
                if (StringTools.startsWith(name.lexeme, '_')) Cosy.error(name, 'Variables starting with _ are considered unused.');
				resolveLocal(expr, name, true);
			case Binary(left, _, right) | Logical(left, _, right):
				resolveExpr(left);
				resolveExpr(right);
			case Call(callee, paren, arguments):
                // TODO: Check if the method call can mutate its object, e.g. Array.push(x) or Struct.func()
				resolveExpr(callee);
				for (arg in arguments) resolveExpr(arg);
			case Get(obj, name):
                resolveExpr(obj);
            case MutArgument(keyword, name):
                resolveLocal(expr, name, true);
			case Set(obj, name, value):
				resolveExpr(value);
                resolveExpr(obj);

                switch obj {
                    case Variable(objName):
                        var variable = findInScopes(objName);
                        if (variable != null && !variable.mutable) Cosy.error(name, 'Cannot reassign properties on non-mutable struct.');
                    case Get(getObj, getName): // ignore???
                    case This(keyword): // ignore
                    case _: trace(obj); throw 'this is unexpected';
                }
			case Grouping(e) | Unary(_, e):
				resolveExpr(e);
			case Super(kw, method):
				switch currentClass {
					case None: Cosy.error(kw, 'Cannot use "super" outside of a class.');
					case Class: Cosy.error(kw, 'Cannot use "super" in a class with no superclass.');
					case Subclass: // ok
				}
                resolveLocal(expr, kw, true);
            case StructInit(name, decls):
                for (decl in decls) {
                    switch decl {
                        case Assign(name, op, value): resolveExpr(value);
                        case _:
                    }
                }
                resolveLocal(expr, name, true);
			case This(kw):
				if (currentClass == None) Cosy.error(kw, 'Cannot use "this" outside of a class.');
				else resolveLocal(expr, kw, true);
			case Literal(_):
				// skip
			case AnonFunction(params, body, returnType): 
				resolveFunction(null, params, body, Function);
		}
	}
	
	function resolveFunction(name:Token, params:Array<Param>, body:Array<Stmt>, type:FunctionType) {
		var enclosingFunction = currentFunction;
		currentFunction = type;
		beginScope();
		for (param in params) {
            var mutable = param.type.match(Mutable(_));
			declare(param.name, mutable);
			define(param.name, mutable);
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
            if (StringTools.startsWith(variable.name.lexeme, '_')) continue; // ignore variables starting with underscore
			if (!variable.member && variable.state.match(Defined)) Cosy.error(variable.name, "Local variable is not used.");
		}
	}
	
	function declare(name:Token, mutable:Bool = false, member:Bool = false) {
		var scope = scopes.peek();
		if (scope.exists(name.lexeme)) {
            Cosy.error(name, 'Variable with this name already declared in this scope.');
        } else {
            var variable = findInScopes(name);
            if (variable != null) Cosy.error(name, 'Shadows existing variable.');
        }
		scope.set(name.lexeme, { name: name, state: Declared, mutable: mutable, member: member });
	}
	
	function define(name:Token, mutable:Bool = false, member:Bool = false) {
		scopes.peek().set(name.lexeme, { name: name, state: Defined, mutable: mutable, member: member });
	}
	
	function resolveLocal(expr:Expr, name:Token, isRead:Bool) {
		var i = scopes.length - 1;
		while (i >= 0) {
            var scope = scopes.get(i);
			if (scope.exists(name.lexeme)) {
				interpreter.resolve(expr, scopes.length - 1 - i);

				if (isRead) {
					scope.get(name.lexeme).state = Read;
				}
				return;
			}
			i--;
		}
        if (name.lexeme == 'clock' || name.lexeme == 'random' || name.lexeme == 'input') return; // TODO: Hack to handle standard library function only defined in interpreter.globals
        Cosy.error(name, 'Variable not declared in this scope.');
	}

    function findInScopes(name: Token) :Null<Variable> {
        var identifier = name.lexeme;
        var i = scopes.length - 1;
        while (i >= 0) {
            var scope = scopes.get(i);
            if (scope.exists(identifier)) return scope.get(identifier);
            i--;
        }
        return null;
    }
}

@:forward(push, pop, length)
abstract Stack<T>(Array<T>) {
	public inline function new() this = [];
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
private enum StructType {
	None;
	Struct;
}
private enum ClassType {
	None;
	Class;
	Subclass;
}
