
# Cosy

Cosy is a small and simple programming language. It has an multi-platform interpreter and trans-compile to JavaScript.

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
* Compile-time validation
* (...)


<!--

Notes:
* Variables starting with _ are considered unused, i.e. using them will result in a compile-time error
* Error reporting for simple dead-code, i.e. statements following an unconditional `return` in a block

-->
