
# Bugs
- [ ] [line 2] Error at "x": Local variable is not used.
```js
x()
fun x() { print "hej" }
```

# Wish list
- [x] Immutable-by-default (e.g. introduce a `mut` keyword)
- [x] Compile-time error to redefine variable/function
- [x] No semi-colons
- [ ] Change assignment to be a statement instead of an expression?
- [ ] Everything is an expression (because it's easier), alternatively make _most_ statements into expressions
- [x] No variable shadowing
- [x] Avoid local function variables overwriting function arguments (e.g. `var a = "local"`)
- [x] Static analysis for
    - [x] Simple dead code
- [ ] Class functions cannot override other functions (must be uniquely named)
- [x] for-loop without sugaring (makes output code ugly)
- [ ] Strong types by requiring variables to be initialized (later this may be handle by static analysis)
- [ ] Replace classes with structs, interfaces, traits and member-functions
- [ ] Modules
- [ ] Experiment with bytecode
- [ ] Support for arrays
- [ ] Support for maps
- [ ] String interpolation
- [ ] ++/-- operators
- [ ] +=/-=/*=//= operators
- [ ] Typing phase
- [ ] Optimization phase
- [ ] Improve readme/documentation
- [x] Compile-time error if a variable is marked as `mut` but is not reassigned
- [ ] `break` keyword
- [ ] `continue` keyword
- [ ] A more convient way to handle a standard library
- [ ] Replace `return _` with `return`. Look at how semicolons are handling in the original implementation.
- [ ] Simplify code now that...
  - [ ] Variable shadowing is gone
  - [ ] nil is gone (done?)
- [ ] Cosy playground
  - [x] Compile for JavaScript
  - [x] Make simple Cosy playground website
  - [x] Make playground available through github pages
  - [x] Scan + parse + resolve the code on keypress or after a timeout
  - [ ] Syntax highlighting for codemirror
- [x] Make "Undefined variable" a compile-time error instead of a runtime error, e.g. `print "hej"\nasdf`
- [ ] Disable some static analysis for REPL, e.g. checking for unused variables
- [ ] Perserve empty lines and comments when pretty-printing and outputting to javascript
- [ ] Make semicolons trigger a warning instead of an error?
- [ ] Time a "real" project and do performance optimizations
- [ ] Algebraic data types
- [ ] Better error position reporting with character from-to indexes
- [ ] A target that outputs code + documentation as markdown

# Project wishlist
- [ ] Make a syntax highlighting extension for vscode
- [ ] Enable null-safety feature for Haxe
- [ ] Unit tests
- [ ] Simple CI?
- [ ] VSCode tasks

## Long shots
- [ ] Built-in ECS functionality somehow
- [ ] Yield functionality (generators or coroutines)
- [ ] Easy to integrate C/C++ libraries
- [ ] Fibers á la Wren
- [ ] Built-in threading
