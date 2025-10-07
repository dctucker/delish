all: debug

src/language/packcc.h:
src/language/packcc.c: src/language/delish.packcc
	cd src/language && packcc -o packcc delish.packcc && cd ../..

src/errnos.nim: Makefile
	echo 'type PosixError* {.pure.} = enum' >  $@
	echo '  ERROR = 0,' >> $@
	gcc -E -dD - <<<'#include <errno.h>' | \
		awk '/^#define E[A-Z0-9]+ *[0-9]+/ { printf "  %s = %s,\n", $$2, $$3 }' | \
		uniq -f 2 >> $@

src/signals.nim: Makefile
	echo 'type PosixSignal* {.pure.} = enum' >  $@
	echo '  SIGNAL = 0,' >> $@
	gcc -E -dD - <<<'#include <signal.h>' | \
		awk '/^#define SIG[A-Z0-9]+ *[0-9]{1,3} *$$/ { printf "  %s = %s,\n", $$2, $$3 }' | \
		sort -nuk 3 >> $@

SOURCES=$(wildcard src/**/*.nim)
debug: src/language/packcc.c src/signals.nim src/errnos.nim $(SOURCES)
	nimble build -f -d:deepDebug

profile: src/language/packcc.c $(SOURCES)
	nimble build -f -d:profiler --profiler:on --stacktrace:on

release: debug
	nimble build -d:release --passC:-ffast-math --opt:speed

strip: release
	strip --strip-all -R .note -R .comment -R .eh_frame -R .eh_frame_hdr delish
	sstrip -z delish

packdeli: src/packcc.c Makefile
	cd src/language ; packcc -o packcc delish.packcc ; cd ../..
	gcc -Og src/language/packcc.c -o packdeli

parsley: src/language/packcc.c src/parsley.nim $(SOURCES)
	nim c --hint:XDeclaredButNotUsed:off -o=parsley src/parsley.nim

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
