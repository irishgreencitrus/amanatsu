+++
title = "Defining Variables"
weight = 3
+++
## Variable == Function
In Amanatsu, variables and functions are equivilent.

A 'variable' (in other language terms) is just a function that **pushes** its stored value to the stack.

A 'function' (in other language terms) is just a variable that **executes** its stored value.

## Simple Variables
They are defined in the same way, as shown below:
```amnt
:meaning_of_life 42 define
```
The special name with a colon before it is known as an atom. It is effectively an identifier which conforms to the same naming requirements of functions (unlike strings which allow spaces).
## Naming Requirements
The naming requirements for atoms/functions/variables are:
- Cannot contain a space
- Can only contain the letters `a-z`, as well as uppercase `A-Z`, underscores and finally numbers.
- Cannot start with a number
## Proving Variables
We can add to the code snippet above to prove that the variables work.
```amnt
:meaning_of_life 42 define

meaning_of_life print
```
This prints `42` to the terminal!

However, what if we want to define a function instead?
## Simple Functions
We use the same `define` builtin, but we put square brackets around the value instead.

We can use this to push multiple values to the stack, as well as much more powerful things shown later.
```amnt
:my_favourite_numbers [
    42 7 8 5
] define
#
Don't forget square brackets! 
They are critical as they allow the several numbers to form one value on the stack
#
```
## Proving Functions
This pushes **all** the four values to the stack when you run the function as shown below:
```amnt
:my_favourite_numbers [
    42 7 8 5
] define
my_favourite_numbers print
```
This prints `5`, as the `print` function only consumes **one** value off the stack.

We can do the print function several times to consume the rest of the values.
```amnt
:my_favourite_numbers [
    42 7 8 5
] define
my_favourite_numbers print print print print 
```
> Whitespace is unimportant in Amanatsu, so this is valid code

This prints, in order:
- 5
- 8
- 7
- 42

Although, this code looks horribly inefficient.

Why don't we encapsulate the 4 print functions into one function?
## Functions as Encapsulation
```amnt
:show4 [
    print
    print
    print
    print
] define
:my_favourite_numbers [
    42 7 8 5
] define
my_favourite_numbers show4
```
That looks better!
> If you want to improve this code even more, check the page on 'Iteration and Recursion'

We can now reuse our `show4` function everytime we need to print `4` values, sweet!