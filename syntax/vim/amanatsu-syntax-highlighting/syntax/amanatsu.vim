" Vim Syntax File
" Language: Amanatsu
" Maintainer: irishgreencitrus
"
if exists("b:current_syntax")
    finish
endif

syn region amanatsuComment start="#" end="#"
syn keyword amanatsuBuiltin global local dup float2int for ifelse if import int2float print range require_stack return swap while
syn keyword amanatsuType Bool Int Float String List Char Atom Any
syn region amanatsuString start=/\v"/ end=/\v"/
syn match amanatsuAtomic ":[a-zA-Z_]\w*"
syn match amanatsuNumeric "-\?\d\+"
syn match amanatsuNumeric "-\?\d\+\.\d\+"

highlight default link amanatsuComment Comment
highlight default link amanatsuBuiltin Statement
highlight default link amanatsuType Constant
highlight default link amanatsuAtomic Keyword
highlight default link amanatsuNumeric Number
highlight default link amanatsuString String

let b:current_syntax = "amanatsu"
