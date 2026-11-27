APP = TRMNL.app
BIN = $(APP)/Contents/MacOS/TRMNL

build:
	mkdir -p $(APP)/Contents/MacOS
	swiftc -O -parse-as-library -target $(shell uname -m)-apple-macos14 TRMNL.swift -o $(BIN)
	cp Info.plist $(APP)/Contents/
	codesign --force -s - $(APP)

test: build
	$(BIN) --selftest

run: build
	open $(APP)

install: build
	rm -rf /Applications/$(APP)
	cp -R $(APP) /Applications/

.PHONY: build test run install
