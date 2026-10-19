PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: all build test install uninstall clean verify

all: build

build:
	swift build -c release

test:
	swift test

install: build
	mkdir -p $(DESTDIR)$(BINDIR)
	install -m 755 .build/release/deskloop $(DESTDIR)$(BINDIR)/deskloop

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/deskloop

clean:
	rm -rf .build dist

verify:
	swift test
	swift build
	swift build -c release
	python3 Scripts/verify-cli.py .build/release/deskloop
