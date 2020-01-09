# haxe build.hxml && java -jar bin/java/Lox.jar $@ 
haxe build.hxml && cp bin/js/hlox.js docs/playground/cosy.js && java -jar bin/java/Lox.jar $@ 
# haxe -cp src --run lox.Lox $@
