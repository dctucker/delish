all: debug

src/packcc.c: src/delish.packcc src/packcc.h
	cd src && packcc -o packcc delish.packcc && cd ..

debug: src/packcc.c #src/delish.yy.c
	nimble build -d:deepDebug

release:
	nimble build -d:release --passC:-ffast-math --opt:size

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish

packdeli: src/packcc.c Makefile
	cd src ; packcc -o packcc delish.packcc ; cd ..
	gcc -Og src/packcc.c -o packdeli

#SOURCES=$(wildcard src/*.nim)
#tests/%.nim: $(SOURCES)

#tests/bin/%: tests/%.nim
#	nim c -o=tests/bin/ $^

test: $(patsubst tests/%.nim,tests/bin/%,$(wildcard tests/*.nim))
	for f in tests/*.nim; do nim c -o=tests/bin/ $$f ; done
	for f in tests/bin/*; do $$f ; done

