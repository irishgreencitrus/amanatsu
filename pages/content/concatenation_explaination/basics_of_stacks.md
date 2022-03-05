+++
title = "Basics of Stacks"
description = "An explaination of the stack data structure"
weight = 1
+++
## Basics of Stacks
Amanatsu is different to languages like Python, JavaScript, and C in the fact that there is one
central data structure in which all functions push to, pull from, and manipulate in order to do
their job. This data structure is known as a stack.

The stack is fairly simple in reality.

If we add something to the end stack (known as pushing),
that will always be the thing we have to take off (known as popping).

In short, the last thing you push to the stack is the first thing you can take off.
This is called a LIFO data structure (last in first out).

### A simple example involving just about nothing

Let's say we have two numbers, `3` and `7`.

We want to add them to the stack.

If we say the leftmost item is the top of the stack, because it's easier to read,
and then we pushed (the order is important), `3` and then `7` to the stack, it would look like this:
```
Start of program (stack is empty):
[]
Push 3 to the stack:
[3]
Push 7 to the stack:
[7, 3]
```
We now cannot access the `3` without first popping the `7` off the stack.
This is the basics of how a stack works.
In Amanatsu, the stack can contain more than just numbers.
It can contain (among numbers), lists, strings, and atomics (names for variables or functions).

### A simple example involving Amanatsu

We have the same two numbers as above, `3` and `7`.

In Amanatsu, you can just write out the numbers to add them to the stack which looks like:

```amnt
3 7
```

It really couldn't be simpler.

Let's say we want to print the top value off the stack.

I'm going to take the same code as above and add a `print` function.

```amnt
3 7 print
```

If you've read this whole article you should be able to predict it outputs:

```
7
```

to your terminal.

If you don't understand why that happened, please read [this bit](#a-simple-example-involving-just-about-nothing) more thoroughly.
