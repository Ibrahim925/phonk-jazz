.PHONY: setup dev test lint format check app clean

setup:   ## resolve + pin dependencies (SwiftPM)
	swift package resolve

dev:     ## run the menubar app locally (accessory / no Dock icon)
	swift run PhonkJazz

test:    ## run the test suite (headless, no display needed)
	swift test

lint:    ## style lint (swift-format, ships with the toolchain) + typecheck (build)
	swift format lint --strict --recursive Sources Tests Package.swift
	swift build

format:  ## auto-fix formatting in place
	swift format --in-place --recursive Sources Tests Package.swift

check: lint test  ## aggregate gate: must be green to be "done"

app:     ## assemble a menubar-only PhonkJazz.app bundle (release)
	swift build -c release --product PhonkJazz
	rm -rf PhonkJazz.app
	mkdir -p PhonkJazz.app/Contents/MacOS
	cp "$$(swift build -c release --show-bin-path)/PhonkJazz" PhonkJazz.app/Contents/MacOS/PhonkJazz
	printf '%s\n' \
	  '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '  <key>CFBundleName</key><string>PhonkJazz</string>' \
	  '  <key>CFBundleIdentifier</key><string>com.phonkjazz.app</string>' \
	  '  <key>CFBundleExecutable</key><string>PhonkJazz</string>' \
	  '  <key>CFBundlePackageType</key><string>APPL</string>' \
	  '  <key>CFBundleShortVersionString</key><string>0.1.0</string>' \
	  '  <key>LSMinimumSystemVersion</key><string>13.0</string>' \
	  '  <key>LSUIElement</key><true/>' \
	  '</dict></plist>' > PhonkJazz.app/Contents/Info.plist
	@echo "Built PhonkJazz.app (menubar-only, LSUIElement)"

clean:   ## remove build artifacts
	swift package clean
	rm -rf .build
