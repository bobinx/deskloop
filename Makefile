PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: all build test install uninstall clean

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
