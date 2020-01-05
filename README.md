
# Cosy

Cosy is a simple and pleasant programming language. It has an multi-platform interpreter and can trans-compile to JavaScript.

```javascript
print 'hello world'
```

```javascript
var max = 3
for i 0..max {
    print 'loop #' + i
}
```

## High-level features

* Familiar syntax
* Lambda functions (anonymous functions)
* Small and concise
  * Cosy is made with fewer than 2000 lines of source code
  * Few keywords (`and`, `class`, `else`, `false`, `for`, `fun`, `in`, `if`, `mut`, `or`, `print`, `return`, `super`, `this`, `true` and `var`)
* Safety 
  * Variable are immutable by default
  * No `null` or `nil`
  * No variable shadowing
* Compile-time validation
  * Unused variables
  * Simple dead code detection, i.e. statements following an unconditional `return` in a block
* Has built-in code formatter
* (...)


<!--
Notes:
* Variables starting with _ are considered unused, i.e. using them will result in a compile-time error
* Pretty printing

Inspiration from
* Lox
* V
* Haxe
* Rust
-->
