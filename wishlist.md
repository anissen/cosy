
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
- [ ] Change more statements into expressions
- [x] No variable shadowing
- [x] Avoid local function variables overwriting function arguments (e.g. `let a = "local"`)
- [x] Static analysis for
  - [x] Simple dead code
  - [x] Using uninitialized variables (`let`)
  - [x] Using uninitialized variables (`mut`)
  - [x] `if` with constant conditional expression
  - [ ] Useless expressions, e.g. `'hello world'`
  - [x] Function and variable names uses snake_case
  - [ ] Struct names uses PascalCase (??)
  - [ ] All paths not returning a value if the function has a return value
  - [ ] Ensure correct number of arguments at compile time instead of at runtime
  - [ ] Checking that if a function returns a value, the invoking code uses (or discards) that value 
- [ ] Optimizer
  - [ ] Optimize usages of literals in `let`'s. They're constants in pratice.
  - [ ] Optimize e.g. `x + 2 + 3 + 4 + 5 + 6` to `x + 20`
- [x] for-loop without sugaring (makes output code ugly)
- [x] Strong types by requiring variables to be initialized (later this may be handle by static analysis)
- [x] Replace classes with structs
- [ ] Modules
- [ ] Experiment with bytecode
- [x] Support for arrays
  - [x] Support for array literal
  - [x] Support for array length
  - [x] Support for push
  - [x] Support for getting value at index
  - [x] Support for array indexing
  - [x] Support for map function
  - [x] Support for filter function
- [ ] Support for maps
- [x] String interpolation
- [x] +=, -=, *=, /= operators
- [x] Typing phase
- [x] Optimization phase
- [ ] Improve readme/documentation
- [x] Compile-time error if a variable is marked as `mut` but is not reassigned
- [x] `break` keyword
- [x] `continue` keyword
- [ ] A more convient way to handle a standard library
- [ ] Replace `return _` with `return`. Look at how semicolons are handling in the original implementation.
- [ ] Simplify code now that...
  - [ ] Variable shadowing is gone (scopes may be simplified)
  - [x] nil is gone
  - [x] for-loops can be made without an identifer (underscores are not required on unused loop counters anymore)
  - [x] Classes are gone
- [x] Cosy playground
  - [x] Compile for JavaScript
  - [x] Make simple Cosy playground website
  - [x] Make playground available through github pages
  - [x] Scan + parse + resolve the code on keypress or after a timeout
  - [-] Syntax highlighting for codemirror
- [x] Make "Undefined variable" a compile-time error instead of a runtime error, e.g. `print "hej"\nasdf`
- [x] Disable some static analysis for REPL, e.g. checking for unused variables
- [ ] Perserve empty lines and comments when pretty-printing and outputting to javascript
- [ ] Time a "real" project and do performance optimizations
- [ ] Algebraic data types
- [ ] Switch/match functionality
- [ ] Pure functions as default (cannot modify variables outside scope, must be deterministic, can only call other pure functions)
- [ ] "Transform" functions that promote data-oriented design; must be pure, must not include `if` + called functions must satify the same constraints. Could be done with annotations, e.g. `[transform] fn trans() { ... }`
- [x] Better error position reporting with character from-to indexes [check the "Better error messages" stash]
- [ ] A target that outputs code + documentation as markdown
- [x] `for 0..10` syntax, instead of `for _i in 0..10`
- [ ] Make a `strict` mode that requires specifying type information for function parameters and return values. It also requires functions to only access argument variables and local variables and non-mutable variables of outer scopes. I.e. it is not allowed to access mutable outer variables.
- [x] Rename files from `.lox` to `.cosy`
- [x] Change `fun` to `fn`
- [x] Change `"` to `'`
- [x] Consider integrations
- [x] Merge `Mut` into `Let`
- [ ] Need to take line breaks into account to avoid cases where parsing fails because it "continues" on the next line, e.g. `mut b\nb = '2'`
- [x] Remove unused testing code (Cosy.hx + tests/)
- [ ] Make array concat be simply `+` (or `++` like in Haskell?)
- [ ] Perserve ordering of members when printing a struct
- [x] Remove `Mutable` as a type in Typer and try an alternative implemention (e.g. metadata)
- [x] Make a new and improved Hangman example with properly typed code, structs and arrays
- [ ] Update Cosy basics example with structs, functions taking mut struct, string functions
- [ ] Submit Cosy example to "99 bottles" site (http://www.99-bottles-of-beer.net/submitnewlanguage.html)
- [ ] Cosy documentation using Dox (https://github.com/HaxeFoundation/dox)
- [ ] Make Cosy FFI work for more targets (see https://community.haxe.org/t/is-there-a-way-to-expose-a-haxe-library-as-a-library-for-another-target/508)
- [x] Make a `phases` sub-package
- [ ] Change array type annotation from e.g. `Array Num` to `num[]`
- [ ] Maybe: Change type annotation from e.g. `Str` to `string` and `Num` to `number`
- [ ] Maybe: Change type annotation from e.g. `fn F(blah Fun(string) number) number[]` to `fn F(blah: ((xyz: string) => number)): number[]`
- [ ] Compile errors ordered by line number, regardless of compilation phase (how?)
- [ ] Introduce an `Any` type that is only allowed for foreign functions
- [x] Add `--benchmark` option
- [ ] Ensure that global variables are defined before used (i.e. not late bound, like local variables). In short, make global variables work just like local variables. No late binding. No redefinition. Using a slot index in the VM.
- [ ] Find a way to be able to parse mutually recursive functions that are not "late bound"
- [ ] Just for fun: Make a version of "generative grammar" that can spit out Cosy code and format that code using `--prettyprint`
- [x] Drop the REPL?
- [x] Suggest variables/functions when misspelling variables/functions
- [ ] Use more `final` variables and `inline` functions (https://haxe.org/manual/class-field-inline.html)
- [x] Make built-in functions snake-case, e.g. `stringToNumber` to `string_to_number`
- [x] Being able to concatinate strings and booleans
- [ ] Remove brackets and use indentation checking instead?
- [ ] Make a 'docs' command that outputs the following to the 'docs' directory (docsify): index.html, readme.md, _sidebar.md and a markdown file for each cosy file.
- [ ] Make a CLI `--help` command
- [x] Make the CLI write out Cosy version and/or git commit
- [x] Detect invalid concatinations (+) in the Typer (and show a hint about string interpolation if one of the types is a string)
- [ ] Make `--times` show how many lines/second was processed (scanner + parser)
- [x] Replace `var` with `let` (because they're constants, not variables)
- [ ] Replace `print` with `log` (shorter, more concise)
- [x] Improve error messages
- [x] Split Cosy.hx into Cosy.hx and Compiler.hx
- [x] Make embedded execution be two-part: scanning, parsing, typing, optimizing + interpreting. The first part should return an AST that can be handed to the interpreter. See https://github.com/HaxeFoundation/hscript/#example
- [ ] Show a stack trace on exceptions
- [ ] Rename Resolver to StaticAnalyzer
- [ ] Make Typer return a typed AST (otherwise rename to TypeChecker)
- [x] Typer: Variables multiplied, divided or subtracted must be numbers
- [ ] Add a colored dot (●) in the error output to indicate which phases reported the error?
- [ ] MAYBE serialize function arguments coming from other languages and deserialize on the Cosy-side? It could be a way to avoid dealing with complex function arguments but it probably won't work.
- [ ] Make more of the standard library be implemented in Cosy (see https://oaklang.org/lib/std)
- [ ] Use ??, ?. and local static variables from Haxe nightly
- [ ] Make an annotation for pure functions
- [ ] Make an annotation for memorizing a function (i.e. cache inputs => output)
- [ ] A way to initialize a list with a size (like in C++; `vector<int>(height, vector<int>(width, 0)))`)
- [ ] Find a more elegant way of handling variable/parameter/return type/loop variable/named struct mutability. I may have to replace some enums with structures.
- [ ] Replace nominal typing with structural typing?

# Project wishlist
- [ ] Make a syntax highlighting extension for vscode
- [ ] Add a "Why" section to the readme
- [ ] Enable null-safety feature for Haxe
- [ ] Unit tests
- [ ] Make a Haxe-based test runner á la https://github.com/munificent/craftinginterpreters/blob/master/tool/bin/test.dart (see https://github.com/munificent/craftinginterpreters#testing). Alternatively, make built-in support for tests in Cosy.
- [x] Simple CI using Github Actions
- [ ] Add Windows CI using Github Actions
- [ ] Add all languages to CI using Github Actions
  - [ ] C++
  - [ ] Hashlink VM
  - [ ] Hashlink C++
  - ~~[ ] Java~~
  - [ ] JVM
  - [ ] Eval
  - [ ] JavaScript
  - [x] Node.js
  - [ ] Python
  - [ ] C#
  - [ ] Lua?
  - [ ] PHP?
- [ ] VSCode tasks
- [ ] Make a Cosy language server (see https://code.visualstudio.com/api/language-extensions/language-server-extension-guide, https://github.com/vshaxe/language-server-protocol-haxe, https://github.com/vshaxe/vscode-extern)
- [ ] Do some benchmarks (see https://github.com/hamaluik/benched)
- [x] Improve project build setup (see https://haxe.org/manual/compiler-usage-hxml.html)
- [ ] Add coverage and profiling (https://github.com/AlexHaxe/haxe-instrument, see https://github.com/cedx/setup-hashlink/blob/main/example/workflow.yaml#L20-L27 for usage)
- [x] Use a code formatter (https://github.com/vshaxe/vshaxe/wiki/Formatting)
- [x] Use a code linter (https://github.com/HaxeCheckstyle/haxe-checkstyle)
- [ ] Put on Haxelib
- [ ] Make auto-generated documentation for the Cosy standard library (see https://oaklang.org/lib)
- [ ] Make the playground work again

## Long shots
- [ ] Built-in ECS functionality somehow
- [ ] Fibers á la Wren
- [ ] Yield functionality (generators or coroutines)
- [ ] Hot reloading
- [ ] Make a web-based app for creative coding (á la a _very_ simplified p5.js)
- [ ] Easy to integrate into C/C++ projects
- [ ] Make a Cosy debugger (https://www.google.com/search?q=how+to+write+a+debugger, https://microsoft.github.io/debug-adapter-protocol/)
- [ ] Cosy Roguelike
