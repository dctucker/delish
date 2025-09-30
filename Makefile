all: debug

src/language/packcc.h:
src/language/packcc.c: src/language/delish.packcc
	cd src/language && packcc -o packcc delish.packcc && cd ../..

SOURCES=$(wildcard src/**/*.nim)
debug: src/language/packcc.c $(SOURCES)
	nimble build -f -d:deepDebug

profile: src/language/packcc.c $(SOURCES)
	nimble build -f -d:nimprof --profiler:on --stacktrace:on

release: debug
	nimble build -d:release --passC:-ffast-math --opt:size

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish

packdeli: src/packcc.c Makefile
	cd src/language ; packcc -o packcc delish.packcc ; cd ../..
	gcc -Og src/language/packcc.c -o packdeli

#tests/%.nim: $(SOURCES)

tests/bin/%: tests/%.nim src/language/packcc.c src/language/packcc.h $(SOURCES)
	nim c --hint:XDeclaredButNotUsed:off -o=tests/bin/ $<

test: debug
test: $(patsubst tests/test_%.nim,tests/bin/test_%,$(wildcard tests/test_*.nim))
	#for f in tests/*.nim; do nim c -o=tests/bin/ $$f ; done
	for f in tests/bin/test_*; do $$f ; done

.PHONY: clean
clean:
	nimble clean
	rm -f delish tests/bin/* src/language/packcc.* src/language/kind.h
