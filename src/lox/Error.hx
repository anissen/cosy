package lox;

class Error {
	public final message:String;
	public function new(?message) {
		this.message = message;
	}
}