SHELL := /bin/bash
ROOT_DIR := $(shell pwd)

.PHONY: test ci-test install uninstall

TESTS := tests

# Run tests with Bats if available, otherwise fallback to shell runner
test:
	@bash $(TESTS)/run_tests.sh

ci-test:
	@bash -c 'if command -v bats >/dev/null 2>&1; then bats --tap $(TESTS)/*.bats; else bash $(TESTS)/run_tests.sh; fi'

install:
	@mkdir -p $(HOME)/.local/bin
	@ln -sf $(ROOT_DIR)/bin/lamplight $(HOME)/.local/bin/lamplight
	@echo "Installed to $(HOME)/.local/bin/lamplight. Ensure ~/.local/bin is on your PATH."

uninstall:
	@rm -f $(HOME)/.local/bin/lamplight
	@echo "Removed $(HOME)/.local/bin/lamplight"
