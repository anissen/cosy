package;

class RuntimeError extends Error {
	public final token:Token;
	
	public function new(token, message) {
		super(message);
		this.token = token;
	}
}