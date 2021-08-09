package cosy;

@:forward(push, pop, length)
abstract Stack<T>(Array<T>) {
    public inline function new() this = [];

    public inline function peek() return this[this.length - 1];

    public inline function get(i: Int) return this[i];
}
