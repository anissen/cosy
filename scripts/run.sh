# haxe jvm.hxml && java -jar bin/jvm/cosy.jar $@ 
# haxe jvm.hxml && cp bin/js/cosy.js docs/playground/cosy.js && java -jar bin/jvm/cosy.jar $@ 

# haxe -cp src -D no-inline --run cosy.Cosy $@
haxe -cp src --run cosy.Cosy $@
