package cosy;

class Return extends Error {
    public final value: Any;

    public function new(value) {
        super();
        this.value = value;
    }
}
