package cosy.phases;

using cosy.VariableType.VariableTypeTools;

class MarkdownPrinter {
    var astPrinter: AstPrinter;
    var result: String;

	public function new() {
        astPrinter = new AstPrinter();
    }

    function print(s: String) {
        result += '$s\n';
    }

    public function printStatements(statements:Array<Stmt>):String {
        result = '';
        for (stmt in statements) {
            printStmt(stmt);
        }
        return result;
    }

	function printStmt(statement:Stmt) {
		switch statement {
			case Function(name, params, body, returnType, foreign):
                if (foreign) return;
                
                var params = [ for (param in params) '${param.name.lexeme} ${param.type.formatType()}' ].join(", ");
                print('### `${name.lexeme}($params) ${returnType.computed.formatType()}`'); // TODO: This ignores the actual types found in the typer phase :/

                print('Annotated return type: ${returnType.annotated.formatType()}\n');
                print('Computed return type: ${returnType.computed.formatType()}\n');

                // if (params.length > 0) {
                //     s += 'Parameters:\n';
                //     for (p in params) s += '* ${p.name.lexeme} (${astPrinter.formatType(p.type)})\n';
                //     s += '\n';
                // }
                
                // if (!returnType.match(Void)) {
                //     s += 'Return type: ${astPrinter.formatType(returnType)}\n'; // TODO: This ignores the actual types found in the typer phase :/
                // }

                print('<details>
<summary>Code</summary>

```js
${astPrinter.printStmts(body)}
```
</details>

');
            // case Block(statements): Lambda.foreach(statements, printStmt);
            case Block(statements): for (stmt in statements) printStmt(stmt);
			case _:
		}
	}
	
	public function printExpr(expr:Expr):String {
		return astPrinter.printExpr(expr);
	}
}
