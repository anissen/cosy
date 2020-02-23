
# Bugs
- [ ] [line 2] Error at "x": Local variable is not used.
```js
x()
fun x() { print "hej" }
```
- [ ] REPL functionality performs static analysis prematurely (e.g. `var x = 3` results in an "unused variable" error)
- [ ] Array method calls is not checked for immutability
- [ ] Printing a struct name (`print Struct`) should fail
- [ ] The following changes the `S` permanently (the fix is probably to have both a Struct and a StructInstance):
```js
struct S { var x = 4 }
print S
print S { x = 6 }
print S
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
    - [ ] Variables written multiple times without being read
    - [ ] Using uninitialized variables
    - [ ] `if` with constant conditional expression
    - [ ] Useless expressions, e.g. `'hello world'`
    - [ ] Function and variable names uses snake_case
    - [ ] Struct names uses PascalCase
- [ ] Class functions cannot override other functions (must be uniquely named)
- [x] for-loop without sugaring (makes output code ugly)
- [x] Strong types by requiring variables to be initialized (later this may be handle by static analysis)
- [ ] Replace classes with 
  - [x] structs
  - [ ] interfaces
  - [ ] traits 
  - [ ] member-functions
- [ ] Modules
- [ ] Experiment with bytecode
- [ ] Support for arrays
  - [x] Support for array literal
  - [x] Support for array length
  - [x] Support for push
  - [x] Support for getting value at index
  - [ ] Support for array indexing?
- [ ] Support for maps
- [ ] String interpolation
- [ ] ++/-- operators
- [ ] +=/-=/*=//= operators
- [x] Typing phase
- [x] Optimization phase
- [ ] Improve readme/documentation
- [x] Compile-time error if a variable is marked as `mut` but is not reassigned
- [ ] `break` keyword
- [ ] `continue` keyword
- [ ] A more convient way to handle a standard library
- [ ] Replace `return _` with `return`. Look at how semicolons are handling in the original implementation.
- [ ] Simplify code now that...
  - [ ] Variable shadowing is gone
  - [ ] nil is gone (done?)
  - [x] for-loops can be made without an identifer (underscores are not required on unused loop counters anymore)
  - [ ] Classes are gone
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
- [ ] Pure functions as default (cannot modify variables outside scope)
- [ ] "Transform" functions that promote data-oriented design; must be pure, must not include `if` + called functions must satify the same constraints. Could be done with annotations, e.g. `[transform] fn trans() { ... }`
- [ ] Better error position reporting with character from-to indexes
- [ ] A target that outputs code + documentation as markdown
- [x] `for 0..10` syntax, instead of `for _i in 0..10`
- [ ] Make a `strict` mode that requires specifying type information for function parameters and return values
- [x] Rename files from `.lox` to `.cosy`
- [x] Change `fun` to `fn`
- [x] Change `"` to `'`
- [ ] Consider integrations
- [ ] Merge `Var` and `Mut` (?)
- [ ] Need to take line breaks into account to avoid cases where parsing fails because it "continues" on the next line, e.g. `mut b\nb = '2'`
- [ ] Remove unused testing code (Cosy.hx + tests/)

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
