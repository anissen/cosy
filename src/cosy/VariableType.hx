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

class VariableTypeTools {
    static public function formatType(type: VariableType) {
        return switch type {
            case Function(paramTypes, returnType):
                var paramStr = [ for (paramType in paramTypes) formatType(paramType) ];
                'Fn(${paramStr.join(", ")})';
            case Array(t): StringTools.trim('Array ' + formatType(t));
            case Text: 'Str';
            case Number: 'Num';
            case Boolean: 'Bool';
            case Unknown: 'Unknown';
            case _: '$type';
        }
    }
}