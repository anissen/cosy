package cosy;

enum TokenType {
	LeftParen; RightParen; LeftBrace; RightBrace; LeftBracket; RightBracket;
    
    Comma; Dot; DotDot;

    Underscore;
    
    Minus; MinusEqual;
    Plus; PlusEqual;
    Slash; SlashEqual;
    Star; StarEqual;
	
	Bang; BangEqual;
	Equal; EqualEqual;
	Greater; GreaterEqual;
	Less; LessEqual;
	
	Identifier; String; Number;
	
	And; Break; Continue; Class; Else; False; Fn; For; Foreign; In; If; Mut; Or;
	Print; Return; Struct; Super; This; True; Var;

    BooleanType; NumberType; StringType; FunctionType; ArrayType;
	
	Eof;
}
