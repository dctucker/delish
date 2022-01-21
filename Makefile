all: debug

src/packcc.c: src/delish.packcc src/packcc.h
	cd src && packcc -o packcc delish.packcc && cd ..

debug: src/packcc.c #src/delish.yy.c
	nimble build

release:
	nimble build -d:release --passC:-ffast-math --opt:size

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish

packdeli: src/packcc.c Makefile
	cd src ; packcc -o packcc delish.packcc ; cd ..
	gcc -Og src/packcc.c -o packdeli

test:
	nim c -r tests/test_parser.nim
	nim c -r tests/test_engine.nim
