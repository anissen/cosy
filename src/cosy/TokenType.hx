package cosy;

enum TokenType {
	LeftParen; RightParen; LeftBrace; RightBrace;
	Comma; Dot; DotDot; Minus; Plus; Slash; Star; Underscore;
	
	Bang; BangEqual;
	Equal; EqualEqual;
	Greater; GreaterEqual;
	Less; LessEqual;
	
	Identifier; String; Number;
	
	And; Class; Else; False; Fun; For; In; If; Mut; Or;
	Print; Return; Super; This; True; Var;

    BooleanType; NumberType; StringType; FunctionType;
	
	Eof;
}
