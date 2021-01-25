package cosy;

enum VariableType {
    Unknown;
    Void;
    Boolean;
    Number;
    Text;
    Instance;
    Function(paramTypes:Array<VariableType>, returnType:VariableType);
    Array(type:VariableType);
    Struct(variables:Map<String, VariableType>);
    NamedStruct(name:String);
    Mutable(type:VariableType);
}