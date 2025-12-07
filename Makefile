.PHONY: help build install clean completions install-completions uninstall-completions

# Default to a user-local install (no sudo required)
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
TARGET_BIN := target/release/resume

help:
	@echo "Rust CLI commands:"
	@echo "  make build    - Build the Rust CLI in release mode"
	@echo "  make install  - Build and symlink the CLI to $(BINDIR)/resume (no sudo by default)"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make completions TARGET_SHELL=<bash|zsh|fish|powershell|elvish> [OUTDIR=…] - Generate completion script(s) (CLI can now auto-install via 'resume completions')"
	@echo "  make install-completions  - Generate and install completions to user-local locations (no sudo)"
	@echo "  make uninstall-completions - Remove installed completion scripts"
	@echo ""
	@echo "Or run directly: ./$(TARGET_BIN) --help"

build:
	cargo build --release

install: build
	@mkdir -p $(BINDIR)
	@ln -sf $(CURDIR)/$(TARGET_BIN) $(BINDIR)/resume
	@echo "Installed resume CLI to $(BINDIR)/resume"

clean:
	cargo clean

# ---------- Shell completions ----------
# Default per-shell install directories (user-local)
XDG_DATA_HOME ?= $(HOME)/.local/share
BASH_COMPLETION_DIR ?= $(XDG_DATA_HOME)/bash-completion/completions
ZSH_COMPLETION_DIR ?= $(PREFIX)/share/zsh/site-functions
FISH_COMPLETION_DIR ?= $(HOME)/.config/fish/completions

# Generate completion script(s). Usage:
#   make completions TARGET_SHELL=zsh [OUTDIR=./completions]
completions: build
ifeq ($(TARGET_SHELL),)
	@echo "ERROR: Please provide TARGET_SHELL=<bash|zsh|fish|powershell|elvish>"; exit 2
endif
	@OUTDIR="$${OUTDIR:-./completions}"; \
	mkdir -p "$$OUTDIR"; \
	./$(TARGET_BIN) completions $(TARGET_SHELL) --dir "$$OUTDIR"

# Install user-local completion scripts for bash, zsh, and fish
install-completions: build
	@mkdir -p $(BASH_COMPLETION_DIR) $(ZSH_COMPLETION_DIR) $(FISH_COMPLETION_DIR)
	@./$(TARGET_BIN) completions bash --dir $(BASH_COMPLETION_DIR) >/dev/null
	@./$(TARGET_BIN) completions zsh --dir $(ZSH_COMPLETION_DIR) >/dev/null
	@./$(TARGET_BIN) completions fish --dir $(FISH_COMPLETION_DIR) >/dev/null
	@echo "Installed bash completion to: $(BASH_COMPLETION_DIR)/resume"
	@echo "Installed zsh completion to:  $(ZSH_COMPLETION_DIR)/_resume"
	@echo "Installed fish completion to: $(FISH_COMPLETION_DIR)/resume.fish"
	@echo "Note for zsh: ensure '$(ZSH_COMPLETION_DIR)' is in your fpath in ~/.zshrc, e.g. 'fpath=( $(ZSH_COMPLETION_DIR) $$fpath )' and then 'autoload -Uz compinit && compinit'"

uninstall-completions:
	@rm -f $(BASH_COMPLETION_DIR)/resume \
		$(ZSH_COMPLETION_DIR)/_resume \
		$(FISH_COMPLETION_DIR)/resume.fish || true
	@echo "Removed installed completion scripts (if they existed)."
