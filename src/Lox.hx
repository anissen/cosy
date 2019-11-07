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
		for(token in tokens) {
			Sys.println(token);
		}
	}
	
	public static function error(line:Int, message:String) {
		report(line, '', message);
	}
	
	static function report(line:Int, where:String, message:String) {
		Sys.println('[line $line] Error $where: $message');
		hadError = true;
	}
}