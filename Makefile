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

app:     ## assemble a menubar .app bundle (implemented later; see feature app-bundle-packaging)
	@echo "app-bundle-packaging feature not implemented yet — see feature_list.json" && exit 1

clean:   ## remove build artifacts
	swift package clean
	rm -rf .build
