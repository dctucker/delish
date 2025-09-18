all: debug

src/packcc.h:
src/packcc.c: src/delish.packcc
	cd src && packcc -o packcc delish.packcc && cd ..

SOURCES=$(wildcard src/*.nim)
debug: src/packcc.c $(SOURCES)
	nimble build -f -d:deepDebug

release: debug
	nimble build -d:release --passC:-ffast-math --opt:size

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish

packdeli: src/packcc.c Makefile
	cd src ; packcc -o packcc delish.packcc ; cd ..
	gcc -Og src/packcc.c -o packdeli

#tests/%.nim: $(SOURCES)

tests/bin/%: tests/%.nim src/packcc.c src/packcc.h $(SOURCES)
	nim c -o=tests/bin/ $<

test: debug
test: $(patsubst tests/%.nim,tests/bin/%,$(wildcard tests/*.nim))
	#for f in tests/*.nim; do nim c -o=tests/bin/ $$f ; done
	for f in tests/bin/*; do $$f ; done

.PHONY: clean
clean:
	nimble clean
	rm -f tests/bin/*
	rm -f delish
	rm -f src/packcc.*
