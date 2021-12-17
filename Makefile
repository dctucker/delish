all: debug

LEG=./src/delish.leg

src/delish.leg: Makefile src/delish.peg src/delish.head.c src/delish.tail.c
	echo "%{"                >${LEG}
	cat ./src/delish.head.c >>${LEG}
	echo "%}"               >>${LEG}
	cat src/delish.peg \
		| sed 's@ \\n@ "\\n"@g' \
		| sed 's@\\s@\[ \\n\\r\\t\]@g' \
		| sed 's/ @@ \([^)]*\)/ (!\1 .)* \1/g' \
		| sed 's@ { @ < @g' \
		| sed 's@ } @ > @g' \
		| sed 's@ }$$@ >@g' \
		| sed 's@\\w@[0-9A-Za-z]@g' \
		| sed 's@\\S@[^ \\t\\n\\r]@g' \
		| sed 's@\\d@[0-9]@g' \
		| sed 's@^\([^ ]*\) *<- *\([^#]*\)$$@\1 = \@{ yyenter(dk\1); } ( ( \2 ) ~{ yyleave(dk\1); } ) { $$$$ = something(dk\1, yytext, yyleng); yyleave(dk\1); }@g' \
		| sed 's@ / @ | @g' \
		| sed 's@ <- @ = @g' \
		>> ${LEG}
	echo "%%"               >>${LEG}
	cat ./src/delish.tail.c >>${LEG}
	#| sed 's/^\([^ ]*\) \(.*\)$$/\1 \2 { printf("%d \1\\n", $$$$ ); }/g' \

src/delish.yy.c: src/delish.leg
	leg -o./src/delish.yy.c ${LEG}

yyparse: src/delish.yy.c
	#gcc -DYY_DEBUG=1 ./src/delish.yy.c -o yyparse
	gcc ./src/delish.yy.c -o yyparse

debug: src/delish.yy.c
	nimble build

release:
	nimble build -d:release --passC:-ffast-math --opt:size

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish
