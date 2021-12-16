all: release strip

LEG=./src/delish.leg

src/delish.leg: src/delish.peg
	echo -e "%{"             >${LEG}
	cat ./src/delish.head.c >>${LEG}
	echo -e "%}\n"          >>${LEG}
	cat src/delish.peg \
		| sed 's/ \\n/ "\\n"/g' \
		| sed 's/\\s/\[ \\n\\r\\t\]/g' \
		| sed 's/ @@ \([^)]*\)/ (!\1 .)* \1/g' \
		| sed 's/ { / < /g' \
		| sed 's/ } / > /g' \
		| sed 's/ }$$/ >/g' \
		| sed 's/\\w/[0-9A-Za-z]/g' \
		| sed 's/\\S/[^ \\t\\n\\r]/g' \
		| sed 's/\\d/[0-9]/g' \
		| sed 's/^\([^ ]*\) \(.*\)$$/\1 \2 { printf("%d \1\\n", $$$$ ); }/g' \
		| sed 's@ / @ | @g' \
		| sed 's@ <- @ = @g' \
		>> ${LEG}
	echo -e "\n%%\n"        >>${LEG}
	cat ./src/delish.tail.c >>${LEG}

src/delish.yy.c: src/delish.leg
	leg ${LEG} > ./src/delish.yy.c

yyparse: src/delish.yy.c
	#gcc -DYY_DEBUG=1 ./src/delish.yy.c -o yyparse
	gcc ./src/delish.yy.c -o yyparse

debug:
	nimble build

release:
	nimble build -d:release --passC:-ffast-math --opt:size

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish
