# x-grep -- the GREP lang for x-lang
#
# INSTALL PUTS THIS BUNDLE WHERE `-l` LOOKS: an installed x searches
# <share>/langs/*/lang.xon, so a lang is "installed" when its files are there.
#
#   make install                  into the x on PATH
#   PREFIX=$HOME/.local make install    into a particular prefix

X ?= x

# THE VERSION IS DERIVED, NEVER COMMITTED -- lang.xon declares what this lang
# REQUIRES, and the installed artifact carries what it IS (git describe).
LANG_VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
SHARE := $(if $(PREFIX),$(PREFIX)/share/x,$(shell $(X) --share-dir))
DEST  := $(SHARE)/langs/grep

# What a consumer needs to RUN the lang: the declaration, the entry, the
# modules.  Not the suite, not the tooling, not CI.
PAYLOAD := lang.xon run.x grep

.PHONY: install
install: ## Install into <share>/langs/grep
	@test -n "$(SHARE)" || { echo "x-grep: cannot find an x tree -- set PREFIX or X" >&2; exit 1; }
	@test -d "$(SHARE)" || { echo "x-grep: no x tree at $(SHARE)" >&2; exit 1; }
	rm -rf "$(DEST)"
	mkdir -p "$(DEST)"
	cp -R $(PAYLOAD) "$(DEST)/"
	printf '%s\n' '$(LANG_VERSION)' > "$(DEST)/version"
	@echo "x-grep: installed to $(DEST)"
	@echo "x-grep: writing the boot image"
	"$(X)" --image -l grep || true
	@echo "x-grep: try  x -l grep"

.PHONY: uninstall
uninstall: ## Remove it again
	rm -rf "$(DEST)"
	@echo "x-grep: removed $(DEST)"

.PHONY: test
test: ## Run the spec suite (every failure is loud)
	X="$(X)" sh tests/spec-runner.sh

.PHONY: check
check: lint ## Run the suite against tests/contract/known-failures.txt -- what CI gates on
	X="$(X)" sh tests/spec-gate.sh

# EVERY RULE THE PLATFORM'S LINTER KNOWS, on this bundle's own sources.
# It rides `check` rather than a tier of its own: what it catches -- a
# nested-if ladder, a definition nothing reads -- is invisible in a diff
# that only shows the new arm, which is the same argument the suite makes
# for itself.  #3 removed this bundle's ladders by hand before anything
# could run the rule here; this is what keeps them gone.
.PHONY: lint
lint: ## Lint the bundle's own sources -- structural rules gated
	X="$(X)" sh tests/lint.sh

.PHONY: bundle
bundle: ## Roll a release tarball and print its pin
	sh tools/bundle.sh

.PHONY: help
help: ## Show targets
	@grep 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[32m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
