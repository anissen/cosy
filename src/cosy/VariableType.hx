package cosy;

enum VariableType {
    Unknown;
    Void;
    Boolean;
    Number;
    Text;
    Instance;
    Function(paramTypes: Array<VariableType>, returnType: VariableType);
    Array(type: VariableType);
    Struct(variables: Map<String, VariableType>);
    NamedStruct(name: String);
    Mutable(type: VariableType);
}

typedef ComputedVariableType = {
    annotated: VariableType,
    ?computed: VariableType,
}

class VariableTypeTools {
    static public function formatType(type: VariableType, hideUnknown: Bool = true) {
        return switch type {
            case Function(paramTypes, returnType):
                var paramStr = [for (paramType in paramTypes) formatType(paramType)];
                'Fn(${paramStr.join(", ")}) ${formatType(returnType, hideUnknown)}';
            case Array(t): StringTools.trim('Array ' + formatType(t));
            case Text: 'Str';
            case Number: 'Num';
            case Boolean: 'Bool';
            case Unknown: (hideUnknown ? '' : 'Unknown');
            case _: '$type';
        }
    }
}
