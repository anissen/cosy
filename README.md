
# Cosy

Cosy is a simple and pleasant programming language. It has an multi-platform interpreter and can trans-compile to JavaScript.

```js
print 'hello world'
```

<!-- ```js
var max = 3
for i 0..max {
    print 'loop #' + i
}
``` -->

## High-level features

* Familiar syntax
* Lambda functions (anonymous functions)
* Gradural typing
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
  * Type checking
* Has built-in code formatter
* Interactive ([REPL](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop)) mode
* Inspired by
  * Lox
  * V
  * Rust
  * Haxe
* (...)

## Code examples
```js
// the basics of cosy

// print to output
print "hello world!"


// variables and types
var a = true     // Boolean
var b = 1        // Number
var c = "hello"  // String

// variables are immutable by default
var d = 42
// d = 24 // error

// use the `mut` keyword to create a mutable variable
mut e = 42
e = 24 // ok


// conditional branching
if 3 < 5 and 4 == 4 {
    print "true"
} else {
    print "false"
}


// loop with counter
for i in 0..3 {
    print "loop #" + i
}

// loop with condition
mut j = 0
for j < 3 {
    print "conditional loop #i"
    j = j + 1
}


// functions
fun say(name) {
    print "hello " + name
}
say("world")

// lambda functions
var square = fun(value Num) {
    return value * value
}
print "5 * 5 = " + square(5) // TODO: This is not type checked -- argument can be "5"

// functions can return functions
fun say_with_extra_text(extra_text Str) {
    return fun(text) {
        print text + extra_text
    }
}
var print_courteously = say_with_extra_text(", please!")
print_courteously("make me a sandwich")

// functions can tage functions as arguments
fun do_n_times(f Fun(Num), n Num) {
    for i in 0..n {
        f(i)
    }
}
do_n_times(fun(x Num) { print "i'm called " + (x + 1) + " time(s)" }, 3)

// functions act as closures
fun counter(start, increment) {
    mut count = start
    return fun() {
        count = count + increment
        return count
    }
}
print "counting down..."
var count_down = counter(3, -1)
print count_down()
print count_down()
print count_down()


// dead code is not allowed
fun dead_code() {
    print "i'm always printing this"
    return true
    // print "i'm never printing this" // error
}
dead_code()


// shadowing of variables are not allowed
{
    var unique = true
    {
        //var unique = 3 // error
    }
 	print unique
}


// unused variables are not allowed
var unused = 42 // error if the line below is removed
print unused
// because of this, we also have to use the variables defined at the top
if !a print b + c + d + e

// variables can be marked purposely unused with an underscore
var _unused = 42 // this is okay
for _i in 0..1 {
    print "the counter variable is unused, but that's okay"
}


// that's it for the basics
// for more examples see:
// https://github.com/anissen/cosy/tree/master/test/scripts
```

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
