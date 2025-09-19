syn clear
syntax include @packccC syntax/c.vim

syn match   packccArrow       '<-'
syn match   packccOperator    '/\|\$\|\~\|*\|+\|\!\|&\|\[\|\]\|\.\|?'
syn match   packccParen       '(\|)\|<[^-]\|>'
syn match   packccRule        /^[A-Za-z0-9_]\+/
syn match   packccRuleRef     '\([a-z]:\)'
syn region  packccString      matchgroup=packccStringDel start=+"+ skip=+\\\\\|\\"+ end=+"+ fold
syn region  packccString      matchgroup=packccStringDel start=+'+ skip=+\\\\\|\\'+ end=+'+ fold
syn region  packccClass       matchgroup=packccClassDel  start=+\[+ end=+\]+ fold
syn match   packccBraces      '{\|}'
syn keyword packccSection     source earlysource common earlycommon header earlyheader value auxil prefix marker import contained
syn match   packccSectionName '%[a-z]\+' contains=packccSection

syn match   packccCOperator   ';\|,\|=\|>=\|<=\|==\|!=\|+\|-\|*\|/\|&\|^\|!\|\~' contained
syn region  packccCString     matchgroup=packccStringDel start=+"+ skip=+\\\\\|\\"+ end=+"+ fold contained
syn region  packccCString     matchgroup=packccStringDel start=+'+ skip=+\\\\\|\\'+ end=+'+ fold contained
syn match   packccCMacro                                '^\s*#.*$' contained
syn match   packccCComment    '/\*.*\*/\|//.*$' contained
syn region  packccAction      matchgroup=packccBraces start='{' end='}' fold contains=packccAction,packccString,packccCOperator,packccParen,packccCMacro,packccCComment,packccVariable
syn match   packccVariable    '\$\$\|auxil\|\$[0-9][se]\?\|@@\|@\w\+' contained

hi def link packccArrow       Statement
hi def link packccOperator    Macro
hi def link packccParen       Special
hi def link packccString      String
hi def link packccStringDel   Special
hi def link packccClass       String
hi def link packccClassDel    Special
hi def link packccRule        Type
hi def link packccRuleRef     Identifier
hi def link packccSectionName Statement
hi def link packccSection     Statement
hi def link packccBraces      Statement

hi def link packccCOperator   Operator
hi def link packccCMacro      Macro
hi def link packccCComment    Comment
hi def link packccVariable    Identifier
