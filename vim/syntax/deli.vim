
syn match  deliDollarVar  '\$\h\w*'
syn match  deliQuoted     '\\.'
syn match  deliComment    '^#.*'
syn match  deliPath       '\.*/[A-Za-z._/-]*'
syn match  deliArgument   '--\h[A-Za-z_-]*'
syn match  deliArgument   '\s-\h\s'
syn match  deliOperator   '=\~\|=\|+=\|==\|!=\||=\|<\|>'
syn match  deliRegex      'r/[^/]\+/'
syn region deliString matchgroup=deliStringDelimiter start=+"+  end=+"+ fold contains=deliDollarVar,deliQuoted
syn region deliString matchgroup=deliStringDelimiter start=+'+  end=+'+ fold
" syn region deliRegex  matchgroup=deliRegexDelimiter  start=+r/+ end=+/+ fold contains=deliQuoted
syn region deliFunction   start=+\w*(+ end=+)+ fold contains=deliString,deliDollarVar,deliMacro,deliReserved,deliPath
" syn region deliRunStatement start=+\s*run&\? + end=+$+ fold contains=deliString,deliDollarVar,deliArgument

syn keyword deliReserved return break continue for if assert exit arg redir async include and or not set env local run prompt pipe open match
syn keyword deliMacro in out err true false

hi def link deliReserved         Keyword
hi def link deliDollarVar        Identifier
hi def link deliString           String
hi def link deliStringDelimiter  String
hi def link deliRegex            String
hi def link deliComment          Comment
hi def link deliOperator         Operator
hi def link deliRunStatement     Function
hi def link deliMacro            Macro
hi def link deliArgument         Identifier
hi def link deliQuoted           SpecialChar
hi def link deliPath             StorageClass
hi def link deliFunction         Function
