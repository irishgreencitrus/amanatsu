# Amanatsu
[![Documentation](https://img.shields.io/badge/documentation-available-blue)](https://irishli.me/amanatsu)

[![GitHub issues](https://img.shields.io/github/issues/irishgreencitrus/amanatsu)](https://github.com/irishgreencitrus/amanatsu/issues) [![GitHub forks](https://img.shields.io/github/forks/irishgreencitrus/amanatsu)](https://github.com/irishgreencitrus/amanatsu/network) [![GitHub stars](https://img.shields.io/github/stars/irishgreencitrus/amanatsu)](https://github.com/irishgreencitrus/amanatsu/stargazers) [![GitHub license](https://img.shields.io/github/license/irishgreencitrus/amanatsu)](https://github.com/irishgreencitrus/amanatsu/blob/main/LICENSE) ![GitHub commit activity](https://img.shields.io/github/commit-activity/m/irishgreencitrus/amanatsu?color=orange&label=commits) 


![VSCode Syntax](https://img.shields.io/badge/vscode-supported-brightgreen)

![Atom Syntax](https://img.shields.io/badge/atom-supported-brightgreen)

![Vim Syntax](https://img.shields.io/badge/vim-supported-brightgreen)

The progressive, concatenative, stack-based programming language to rival verbosity and complexity.
## Installation
Install [Zig](https://ziglang.org) in whichever way you normally do.

```
git clone https://github.com/irishgreencitrus/amanatsu
cd amanatsu
zig build
```

The binary will then be in `zig-out/bin/`.
### Running a program
```
amanatsu name-of-program.amnt
```
## Built with clarity in mind
### No hidden control flow
If something doesn't look like it calls a function, it doesn't.
```amnt
"Hello World" print
```
Does `"Hello World"` look like a function? No it doesn't, so it is not a function

Does `print` look like a function? It does, so it is a function.
### Variables are functions and functions are variables
A variable is just a function that places its contents upon the stack.

A function is just a variable that executes its contents.

A functions contents is the same as a variable.

There is no special syntax to define a function.
```amnt
:my_fav_num 42 define

:my_hello_func [
    "Hello World" print
] define
```
They both use the `define` statement in the same way.
The only difference is a function contains multiple instructions whereas a variable contains one.
### Compact, clever design
```amnt
3 4 + 8 * print
```
Maths is finally readable.

No order of operations.

In programming, you should not have to worry about how something happens, only what happens. This should extend to maths as well.

We don't care the specifics of how the `print` function works, or how the stack works in the source code, but we know `print` prints to the screen and that's enough.
### Challenges the C standard
Everything is dynamic when it eases development, and not when it doesn't make sense to.

You should be able to `print` any value without a formatter, but not apply a `+` to something that isn't a number.
### An ambitious roadmap
Amanatsu is designed for months to come, and will improve as long as I can be bothered.
### Acknowlegements
- [Bog](https://github.com/Vexu/bog)
- [Docs Theme](https://github.com/codeandmedia/zola_docsascode_theme)
- [PMLO](https://github.com/irishgreencitrus/PMLO)
- [Zig](https://ziglang.org)
