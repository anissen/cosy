package;

import sys.io.File;

class Lox {
	static var hadError = false;
	
	static function main() {
		
		switch Sys.args() {
			case []:
				runPrompt();
			case [v]:
				runFile(v);
			case _:
				Sys.println('Usage: hlox [script]');
				Sys.exit(64);
		}
	}
	
	static function runFile(path:String) {
		var content = File.getContent(path);
		run(content);
		if(hadError) Sys.exit(65);
	}
	
	static function runPrompt() {
		var stdin = Sys.stdin();
		while(true) {
			Sys.print('> ');
			run(stdin.readLine());
		}
	}
	
	static function run(source:String) {
		var scanner = new Scanner(source);
		var tokens = scanner.scanTokens();
		var parser = new Parser(tokens);
		var expression = parser.parse();
		
		if(hadError) return;
		
		Sys.println(new AstPrinter().print(expression));
	}
	
	static function report(line:Int, where:String, message:String) {
		Sys.println('[line $line] Error $where: $message');
		hadError = true;
	}
	
	public static function error(data:ErrorData, message:String) {
		switch data {
			case Line(line): report(line, '', message);
			case Token(token) if(token.type ==  Eof): report(token.line, ' at end', message);
			case Token(token): report(token.line, 'at "${token.lexeme}}"', message);
		}
	}
}

enum ErrorDataType {
	Line(v:Int);
	Token(v:Token);
}

abstract ErrorData(ErrorDataType) from ErrorDataType to ErrorDataType {
	@:from static inline function line(v:Int):ErrorData return Line(v);
	@:from static inline function token(v:Token):ErrorData return Token(v);
}