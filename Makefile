PREFIX ?= /usr/local
BINARY_NAME = xcode-helper

.PHONY: build install clean test

build:
	swift build -c release --disable-sandbox

install: build
	install -d $(PREFIX)/bin
	install .build/release/$(BINARY_NAME) $(PREFIX)/bin/

uninstall:
	rm -f $(PREFIX)/bin/$(BINARY_NAME)

clean:
	rm -rf .build

test:
	swift test

run:
	swift run $(BINARY_NAME)

help:
	swift run $(BINARY_NAME) --help
