+++
title = "index"
insert_anchor_links = "right"
+++
## Amanatsu
The progressive, concatanative, stack-based language.
This language is in **active** development and could change at any moment.
The language is **always** updated before the documentation,
and there is no guarantee anything will be static from one version to the next.
Only after 1.0 will the language stay static.

### Using the documentation
Everything is available on the sidebar.
If you've never come across a stack-based language before,
start with 'Concatenation Explaination'. It explains some of the features of the
language borrowed from languages like Factor and Forth.

If you have come across stack-based, just not Amanatsu,
start with 'Getting Started with Amanatsu'. This explains some of the more unique
things in the language.

If you just need to look at language specifics, such as builtins and operators and
types, check out 'The API'.

Functions/builtins are documented Haskell-like.

The types they take in are on the left, and the types they return are on the right.

This syntax in the language is currently non-existent and remains as a way to document
your functions arguments and return values, however it may appear in the language later

Example with the print builtin:
```amnt
print :: Any -> Void
```
