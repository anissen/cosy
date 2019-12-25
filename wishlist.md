
# Bugs
- [ ] Counter variable in for-loops are declared in the scope containing the for-loop instead of inside the loop
- [ ] [line 2] Error at "x": Local variable is not used.
```js
x()
fun x() { print "hej" }
```

# Wish list
- [x] Immutable-by-default (e.g. introduce a `mut` keyword)
- [ ] Compile-time error to redefine variable/function
- [x] No semi-colons
- [ ] Change assignment to be a statement instead of an expression?
- [ ] Everything is an expression (because it's easier), alternatively make _most_ statements into expressions
- [x] No variable shadowing
- [ ] Avoid local function variables overwriting function arguments (e.g. `var a = "local"`)
- [ ] Static analysis for
    - [ ] Dead code
- [ ] Class functions cannot override other functions (must be uniquely named)
- [x] for-loop without sugaring (makes output code ugly)
- [ ] Strong types by requiring variables to be initialized
- [ ] Replace classes with structs, interfaces, traits and member-functions
- [ ] Fibers á la Wren
- [ ] Yield functionality (generators or coroutines)
- [ ] Modules
- [ ] Experiment with bytecode
- [ ] Support for arrays
- [ ] Support for maps
- [ ] String interpolation
- [ ] ++ operator
- [ ] Strong types (requires variable initialization)
- [ ] Typing phase
- [ ] Optimization phase
- [ ] Improve readme/documentation
- [x] Compile-time error if a variable is marked as `mut` but is not reassigned
- [ ] `break` keyword
- [ ] A more convient way to handle a standard library
- [ ] Replace `return _` with `return`. Look at how semicolons are handling in the original implementation.
- [ ] Simplify code now that...
  - [ ] Variable shadowing is gone
  - [ ] nil is gone (done?)
- [ ] Compile for JavaScript
  - [x] Make simple Cosy playground website
  - [ ] Make playground available through github pages
- [ ] Make "Undefined variable" a compile-time error instead of a runtime error, e.g. `print "hej"\nasdf`


# Project wishlist
- [ ] Enable null-safety feature for Haxe
- [ ] Unit tests
- [ ] Simple CI?
- [ ] VSCode tasks

## Long shots
- [ ] Built-in ECS functionality somehow
- [ ] Easy to integrate C/C++ libraries
- [ ] Yield as a language construct
- [ ] Built-in threading
