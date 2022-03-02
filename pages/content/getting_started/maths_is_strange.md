+++
title = "Maths is Strange"
weight = 2
+++
## Maths is Strange
Basic maths is suprisingly complex. It requires knowlege of the standard order of operations,
which can be easy to forget if you are writing a program in a language like Python.
In Amanatsu, however, a `+` is just a function in the same way as `print`.
> Technically, it's not a function in the same way a function you create is a function.
> It requires a special code case in the compiler because you can't really build an addition function
> from scratch in an interpreted programming language.

`+` being a function means that it operates *directly* on the stack.
There is no such thing as an order of operations because it is unnecessary;
If something looks like it is called first, it is.

Example of Adding two numbers together:
```amnt
3 4 +
# The number at the top of the stack is, of course, 7 #
```
Even complex expressions are ridiculously readable.
```amnt
7 8 + 9 * 3 -
```
This evaluates to 7 and 8, times the result by 9, and take 3 from the result of that.
In usual mathematics this could be written in several ways, due to order of operations.

This: `7+8*9-3` is *not* the same thing, even if it looks like it.

This: `9(7+8)-3` is the same thing, but arguably less readable.

Neither of these are necessarily the wrong way of doing things,
but they are certainly weird.

