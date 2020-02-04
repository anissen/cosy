
# Cosy
Cosy is a simple and pleasant programming language. It has an multi-platform interpreter and can trans-compile to JavaScript.

```js
print 'hello world'
```

## High-level features
* Familiar syntax.
* Lambda functions (anonymous functions).
* Gradural typing.
* Small and concise.
  * Cosy is made with fewer than 2000 lines of source code.
  * Only 18 keywords (`and`, `else`, `false`, `for`, `fn`, `in`, `if`, `mut`, `or`, `print`, `return`, `true`, `var`, `Bool`, `Num`, `Str`, `Array` and `Fn`).
* Safety.
  * Variable are immutable by default.
  * No `null` or `nil`.
  * No variable shadowing.
* Compile-time validation.
  * Unused variables.
  * Simple dead code detection, i.e. statements following an unconditional `return` in a block.
  * Type checking.
* Has built-in code formatter.
* Web based [playground](http://andersnissen.com/cosy/playground/).
* Interactive ([REPL](https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop)) mode.
* Simple code optimization.
* Inspired by [V](https://vlang.io/), [Rust](https://www.rust-lang.org/) and [Haxe](https://haxe.org/). Originally based on [Lox](http://www.craftinginterpreters.com/).


## Code examples
```js
// the basics of cosy

// print to output
print 'hello world!'


// variables and types
var a = true     // Boolean
var b = 1.2      // Number
var c = 'hello'  // String
var d = [3, 4]   // Array

// variables are immutable by default
var immutable = 42
// immutable = 24 // error

// use the `mut` keyword to create a mutable variable
mut mutable = 42
mutable = 24 // ok


// conditional branching
if 3 < 5 and 4 == 4 {
    print 'true'
} else {
    print 'false'
}


// loop with counter
for i in 0..3 {
    print 'loop #' + i
}

// loop without counter
for 0..3 {
    print 'no counter'
}

// loop with condition
mut j = 0
for j < 3 {
    print 'conditional loop #i'
    j = j + 1
}

// loop over array
for i in [5, 6, 7] {
    print 'array value: ' + i
}


// functions
fn say(name) {
    print 'hello ' + name
}
say('world')

// lambda functions
var square = fn(value Num) {
    return value * value
}
print '5 * 5 = ' + square(5)

// functions can return functions
fn say_with_extra_text(extra_text Str) {
    return fn(text) {
        print text + extra_text
    }
}
var print_courteously = say_with_extra_text(', please!')
print_courteously('make me a sandwich')

// functions can tage functions as arguments
fn do_n_times(f Fn(Num), n Num) {
    for i in 0..n {
        f(i)
    }
}
do_n_times(fn(x Num) { print 'i\'m called ' + (x + 1) + ' time(s)' }, 3)

// functions act as closures
fn counter(start, increment) Fn() Num {
    mut count = start
    return fn() {
        count = count + increment
        return count
    }
}
print 'counting down...'
var count_down = counter(3, -1)
print count_down()
print count_down()
print count_down()


// dead code is not allowed
fn dead_code() {
    print 'i\'m always printing this'
    return true
    // print 'i\'m never printing this' // error
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
if !a print b + c + d + immutable + mutable

// variables can be marked purposely unused with an underscore
fn some_function(_unused) {
    print 'the arg is unused, but that\'s okay'
}
some_function(1234)


// that's it for the basics
// for more examples see:
// https://github.com/anissen/cosy/tree/master/test/scripts
```

<!--
<details>
<summary>Cosy basics</summary>
...
</details>
-->

## Usage
Usage: `cosy (options) (source file)`

Options:
* `--prettyprint`
  
    Prints the formatted source.

* `--javascript`
  
    Prints the corresponding JavaScript code.

If called without arguments, Cosy is started in REPL mode.

Cosy is written in [Haxe](https://haxe.org/) and requires the Haxe compiler to build.

<!--
Information about using Cosy as stand-alone and integrated into other code as a library
-->

### Using Haxe interpreter
Build & run: `haxe -cp src --run cosy.Cosy [OPTIONS] [SOURCE_FILE]`.

### Using JavaScript
Build: `haxe scripts/javascript.hxml`.

Include in your HTML body: `<script src="cosy.js"></script>`.

Run: `window.cosy.Cosy.run([SOURCE])`.

### Using Java
Build: `haxe -cp src -main cosy.Cosy -java bin/java`.

Run: `java -jar bin/java/cosy.jar [OPTIONS] [SOURCE_FILE]`.

<!--
### Using C++
_Coming soon_

### Using HashLink bytecode or C
_Coming soon_
-->

## License
MIT
