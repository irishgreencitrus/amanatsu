+++
title = "List of Builtins"
weight = 1
sort_by = "weight"
+++
## How to read the type charts
Type annotations are written for the ease of the programmer, not for the ease of the stack.
They appear exactly as you would see them when you are writing code.
In `define`s case,
```amnt
define :: (Atom, Any) -> Void
```
in practice looks like
```amnt
:meaning_of_life 42 define
```
even though the `42` is technically at the top of the stack.

## `define`
```amnt
define :: (Atom, Any) -> Void
```
Takes two arguments, and defines the `Any` as the name of the `Atom`.
Can be used to define functions, as well as variables.
Recursion is allowed.
## `dup`
```amnt
dup :: Any -> (Any, Any)
```
Takes the first argument, and repushes it to the stack twice
## `float2int`
```amnt
float2int :: Float -> Int
```
Takes the first argument, and rounds it down to the nearest whole number
## `for`
```amnt
for :: (IntList, Atom, TokenList) -> Void
```
For every item in the `IntList`, defines it as the `Atom`, then executes the `TokenList`.
## `if`
```amnt
if :: (Float, TokenList) -> Void
```
If the `Float` is `1` run the `TokenList` else do nothing.
## `ifelse`
```amnt
ifelse :: (Float, TokenList, TokenList) -> Void
```
If the `Float` is `1` run the first `TokenList` else run the second `TokenList`.
## `print`
```amnt
print :: Any -> Void
```
Takes one argument, and prints it to the screen.
## `range`
```amnt
range :: (Int, Int) -> IntList
```
Generates an `IntList` with all the numbers between the first `Int` and the second `Int` (non-inclusive at the end).
## `swap`
```amnt
range :: (Any, Any) -> (Any, Any)
```
This type annotation, while technically correct, does not do this function justice so have an alternative:
```amnt
range :: (A,B) -> (B,A)
```
Swaps the two top values on the stack.
