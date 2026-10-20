PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: all build test install uninstall clean verify setup

all: build

setup:
	@pre-commit install --allow-missing-config -q 2>/dev/null || true
	@pre-commit install --hook-type pre-push --allow-missing-config -q 2>/dev/null || true

build: setup
	swift build -c release

test: setup
	swift test

install: build
	mkdir -p $(DESTDIR)$(BINDIR)
	install -m 755 .build/release/deskloop $(DESTDIR)$(BINDIR)/deskloop

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/deskloop

clean:
	rm -rf .build dist

verify: setup
	gitleaks detect --verbose
	swift test
	swift build
	swift build -c release
	python3 Scripts/verify-cli.py .build/release/deskloop
