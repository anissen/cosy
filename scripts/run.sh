# haxe build.hxml && java -jar bin/jvm/Cosy.jar $@ 
# haxe build.hxml && cp bin/js/cosy.js docs/playground/cosy.js && java -jar bin/jvm/Cosy.jar $@ 

# haxe -cp src -D no-inline --run cosy.Cosy $@
haxe -cp src --run cosy.Cosy $@
