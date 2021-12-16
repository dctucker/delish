all: release strip

.PHONY: src/delish.leg# src/delish_yy.c
src/delish.leg:
	cat src/delish.peg \
		| sed 's/ \\n/ "\\n" /g' \
		| sed 's/\\s/\[ \\n\\r\\t\]/g' \
		| sed 's/ @@ \([^)]*\)/ (!\1 .)* \1/g' \
		| sed 's/ { / < /g' \
		| sed 's/ } / > /g' \
		| sed 's/ }$$/ >/g' \
		| sed 's/\\w/[0-9A-Za-z]/g' \
		| sed 's/\\S/[^ \\t\\n\\r]/g' \
		| sed 's/\\d/[0-9]/g' \
		> src/delish.leg

src/delish.yy.c: src/delish.leg
	peg ./src/delish.leg > ./src/delish.yy.c
	echo "int main() { while(yyparse()) puts(\"success\n\"); return 0; }" >> ./src/delish.yy.c

yyparse: src/delish.yy.c
	gcc ./src/delish.yy.c -o yyparse

debug:
	nimble build

release:
	nimble build -d:release --passC:-ffast-math --opt:size

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish
