package lox;

enum TokenType {
	LeftParen; RightParen; LeftBrace; RightBrace;
	Comma; Dot; DotDot; Minus; Plus; Slash; Star;
	
	Bang; BangEqual;
	Equal; EqualEqual;
	Greater; GreaterEqual;
	Less; LessEqual;
	
	Identifier; String; Number;
	
	And; Class; Else; False; Fun; For; In; If; Nil; Or;
	Print; Return; Super; This; True; Var;
	
	Eof;
}
