package lox;

class Error {
	public final message:Null<String>;
	public function new(?message) {
		this.message = message;
	}
}
