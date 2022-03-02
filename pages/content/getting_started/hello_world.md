+++
title = "Hello World"
weight = 1
+++
## Hello World
Almost every 'Hello World' program is very simplistic, and Amanatsu is no exception.
However, most programming languages have a 'Hello World' that looks like this:
```py
print("Hello World")
```
Note that the `print` function takes direct arguments.
Amanatsu does not work like this.
It operates directly on the stack.

> See "Concatination Explaination" for
> more details on how a stack works

On the roadmap, there will be an ability to assert that the stack contains certain types at the top.
For example if your function is a mathematical function, you want to be able to check that the top of the stack contains a number.

As of now, this functionality is not in the core language. However, functions still use type annotations to ease developers.
The 'print' function/builtin ( Builtins refer to special cases in the compiler, but they have the same functionality as any function could have )
has this type annotation.

```amnt
print :: Any -> Void
```

This means that the print function operates on **any** type on the stack, but returns **nothing**.
It effectively swallows the value, while having a side effect of printing to the screen. Pretty cool.

Now for that 'Hello World' function.

```amnt
"Hello World" print
```

The string literal just appends "Hello World" to top the stack.
'print' takes 1 argument (as denoted by the type annotation), which in this case is "Hello World", the value at the top of the stack.

There is now **nothing** at the top of the stack. You cannot print "Hello World" again! That value is gone!

If that confused you, just remember that in Amanatsu **all functions** are **always** destructive.
You cannot use any value without first removing it from the stack.
Even the `dup` function which 'duplicates' the top value on the stack, first takes the top value off the stack, and then readds it twice.
This design decision allows all functions to have predictable behavior, a core value in Amanatsu.
