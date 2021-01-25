package cosy.phases;

class MarkdownPrinter {
    var astPrinter: AstPrinter;

	public function new() {
        astPrinter = new AstPrinter();
    }

	public function printStmt(statement:Stmt):String {
		return switch statement {
			case Function(name, params, body, returnType, foreign):
                if (foreign) return '';

                var s = '### `${name.lexeme}(${astPrinter.formatParams(params)}) ${returnType}`\n'; // TODO: This ignores the actual types found in the typer phase :/
                // if (params.length > 0) {
                //     s += 'Parameters:\n';
                //     for (p in params) s += '* ${p.name.lexeme} (${astPrinter.formatType(p.type)})\n';
                //     s += '\n';
                // }
                
                // if (!returnType.match(Void)) {
                //     s += 'Return type: ${astPrinter.formatType(returnType)}\n'; // TODO: This ignores the actual types found in the typer phase :/
                // }

                s += '<details>
<summary>Code</summary>

```js
${astPrinter.printStmts(body)}
```
</details>

';
                return s;
			case _: '';
		}
	}
	
	public function printExpr(expr:Expr):String {
		return astPrinter.printExpr(expr);
	}
}
