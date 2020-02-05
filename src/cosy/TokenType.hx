package cosy;

enum TokenType {
	LeftParen; RightParen; LeftBrace; RightBrace; LeftBracket; RightBracket;
	Comma; /* Colon; */ Dot; DotDot; Minus; Plus; Slash; Star; Underscore;
	
	Bang; BangEqual;
	Equal; EqualEqual;
	Greater; GreaterEqual;
	Less; LessEqual;
	
	Identifier; String; Number;
	
	And; Class; Else; False; Fn; For; In; If; Mut; Or;
	Print; Return; Struct; Super; This; True; Var;

    BooleanType; NumberType; StringType; FunctionType; ArrayType;
	
	Eof;
}
