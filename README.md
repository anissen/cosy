<p align="center">
  <a href="https://github.com/anissen/cosy">
    <img src="./cosy-logo.svg" height="50%" width="50%">
  </a>

  <p align="center">
    A simple and pleasant programming language.
    <!-- <br />
    <a href="https://github.com/anissen/cosy"><strong>Explore the docs »</strong></a>
    <br /> -->
    <br />
    <a href="http://andersnissen.com/cosy/playground">Online Playground</a>
    ·
    <a href="https://github.com/anissen/cosy/issues">Report Bug</a>
    ·
    <a href="https://github.com/anissen/cosy/issues">Request Feature</a>
  </p>
</p>

## Cosy

Cosy is a simple and pleasant programming language. Cosy is simple to read and write and has extensive compile-time validating. It has an multi-platform interpreter and can trans-compile to JavaScript.

```js
print 'hello world'
```

<!-- [![Product Name Screen Shot][product-screenshot]](https://example.com) -->

## High-level features
* Familiar syntax.
* Lambda functions (anonymous functions).
* Gradural typing.
* Small and concise.
  * Cosy is made with fewer than 2100 lines of source code.
  * Only 19 keywords (`and`, `else`, `false`, `for`, `fn`, `in`, `if`, `mut`, `or`, `print`, `return`, `struct`, `true`, `var`, `Bool`, `Num`, `Str`, `Array` and `Fn`).
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
<details>
<summary>Cosy basics</summary>

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

</details>


## Getting Started

To get a local copy up and running follow these simple steps.

### Prerequisites

Cosy is written in [Haxe](https://haxe.org/) and requires the Haxe compiler to build.


### Installation
 
Clone the cosy repository
```sh
git clone https://github.com/anissen/cosy.git
```


### Usage

Usage: `cosy (options) (source file)`

Options:
* `--prettyprint`
  
    Prints the formatted source.

* `--javascript`
  
    Prints the corresponding JavaScript code.

If called without arguments, Cosy is started in REPL mode.

<!--
Information about using Cosy as stand-alone and integrated into other code as a library
-->

#### Using Haxe interpreter
Build & run: `haxe -cp src --run cosy.Cosy [OPTIONS] [SOURCE_FILE]`.

#### Using JavaScript
Build: `haxe scripts/javascript.hxml`.

Include in your HTML body: `<script src="cosy.js"></script>`.

Run: `window.cosy.Cosy.run([SOURCE])`.

#### Using Java
Build: `haxe -cp src -main cosy.Cosy -java bin/java`.

Run: `java -jar bin/java/cosy.jar [OPTIONS] [SOURCE_FILE]`.

<!--
#### Using C++
_Coming soon_

#### Using HashLink bytecode or C
_Coming soon_
-->

_For more examples, please refer to the [Documentation](https://example.com)_



## Roadmap

See the [wishlist](https://github.com/anissen/cosy/wishlist.md) for a list of proposed features (and known issues).


<!-- 
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request
-->


## License

Distributed under the MIT License. See `LICENSE` for more information.


<!-- 
## Acknowledgements

* []()
* []()
* []()
-->

