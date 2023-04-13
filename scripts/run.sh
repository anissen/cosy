# Target: Java
# haxe scripts/jvm.hxml && java -jar bin/jvm/cosy.jar $@ 

# Target: Node (JavaScript)
# haxe scripts/node.hxml && node bin/node/cosy.js $@

# Target: C++
# haxe scripts/cpp.hxml && ./bin/cpp/cosy $@

# Target: Haxe Eval
haxe scripts/eval_debug.hxml $@
