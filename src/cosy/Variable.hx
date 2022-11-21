package cosy;

typedef Variable = {
    name: Token,
    type: VariableType /* TODO: Should be ComputedVariableType */,
    mut: Bool,
    foreign: Bool,
}
