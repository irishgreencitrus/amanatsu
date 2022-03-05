+++
title = "Iteration and Recursion"
description = "How to repeat things programatically"
weight = 4
+++
# Repetition
Programming languages are practically useless without some form of repetition.
It is required to have it in some form to even be *considered* a programming language.

Of repetition, Amanatsu (and most programming languages) has two forms:
- Iteration
- Recursion

# Iteration
Perhaps the simplest form is iteration.

Iteration in Amanatsu comes in two forms:
- A `while` loop
- A `for` loop

## Usage of the while loop
```amnt
[1] [
	"This will print forever" print	
] while
```
This is how this works:
- Execute first `TokenList`
- After executing the first `TokenList`:
	- If the top value on the stack is `1`:
		- Execute the second `TokenList` and jump back to step 1
	- If the top value on the stack is **not** `1`
		- Skip past the second `TokenList` and continue for the rest of the program

## Usage of the for loop
```amnt
1 10 range :i [
	i print
] for
```
`1 10 range` resolves to a `IntList` which can be iterated over by the for loop.

- For every item in the `IntList`:
	- Assign that item to `:i` (like how `define` works)
	- Execute the `TokenList`

Soon there will be a way to not assign anything at a for loop by using `:_` as the variable and that will just discard the value.
# Recursion
Recursion in its simplest form is when a function calls itself.

This method of repetition is not recommended for most cases as there is no optimisation.
Optimisation is on the roadmap so this may be implemented in the future.

Due to the fact that tokens are not executed until they absolutely need to be, recursion is possible:
```amnt
:hello_forever [
	"HELLO WORLD" print 
	hello_forever
] define
hello_forever
```
After the first function call, this function will never return and should print "HELLO WORLD" forever.

At the moment, it doesn't.

The function call stack overflows due to lack of optimisation.
For this reason you should use iteration at all times for the minute but know that recursion is supported.