.PHONY: build test release check

build:
	swift build

test:
	swift test

release:
	./scripts/build-release.sh

check:
	bash -n scripts/*.sh
	swift package dump-package >/dev/null
	swift test
	git diff --check
