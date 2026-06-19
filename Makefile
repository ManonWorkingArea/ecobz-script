# =============================================================================
# Makefile - Build, install, and package ecobz CLI
# =============================================================================

VERSION    := 1.0.0
PREFIX     ?= /usr/local
BINDIR     := $(PREFIX)/bin
LIBDIR     := $(PREFIX)/lib/ecobz

.PHONY: all install uninstall clean help

# -----------------------------------------------------------------------------
# Default target
# -----------------------------------------------------------------------------
all: help

# -----------------------------------------------------------------------------
# Install directly (no package)
# -----------------------------------------------------------------------------
install:
	@echo "Installing ecobz v$(VERSION) to $(PREFIX)..."
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(LIBDIR)
	install -m 755 ecobz $(DESTDIR)$(BINDIR)/ecobz
	install -m 644 lib/*.sh $(DESTDIR)$(LIBDIR)/
	@echo "ecobz installed successfully."
	@echo "Run: sudo ecobz server-config"

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------
uninstall:
	@echo "Uninstalling ecobz..."
	rm -f $(DESTDIR)$(BINDIR)/ecobz
	rm -rf $(DESTDIR)$(LIBDIR)
	@echo "ecobz uninstalled."

# -----------------------------------------------------------------------------
# Clean build artifacts
# -----------------------------------------------------------------------------
clean:
	@echo "Nothing to clean."

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@echo "ecobz Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make install     Install ecobz to system (PREFIX=$(PREFIX))"
	@echo "  make uninstall   Remove ecobz from system"
	@echo "  make clean       Remove build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX           Installation prefix (default: /usr/local)"
	@echo "  DESTDIR          Staging directory for packaging"
