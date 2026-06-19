# =============================================================================
# Makefile - Build, install, and package ecobz CLI
# =============================================================================

VERSION    := 1.0.0
PREFIX     ?= /usr/local
BINDIR     := $(PREFIX)/bin
LIBDIR     := $(PREFIX)/lib/ecobz
MANDIR     := $(PREFIX)/share/man/man1
BUILD_DIR  := build
DEB_DIR    := $(BUILD_DIR)/ecobz_$(VERSION)_all

.PHONY: all install uninstall deb clean ppa-source ppa-upload help

PPA := ppa:manonsanoi-h/ecobz

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
# Build .deb package
# -----------------------------------------------------------------------------
deb:
	@echo "Building .deb package for ecobz v$(VERSION)..."
	rm -rf $(BUILD_DIR)
	mkdir -p $(DEB_DIR)/DEBIAN
	mkdir -p $(DEB_DIR)/usr/bin
	mkdir -p $(DEB_DIR)/usr/lib/ecobz

	# Control file
	sed 's/Version:.*/Version: $(VERSION)/' debian/control > $(DEB_DIR)/DEBIAN/control

	# Post-install script
	echo '#!/bin/bash' > $(DEB_DIR)/DEBIAN/postinst
	echo 'chmod 755 /usr/bin/ecobz' >> $(DEB_DIR)/DEBIAN/postinst
	echo 'echo "ecobz installed. Run: sudo ecobz server-config"' >> $(DEB_DIR)/DEBIAN/postinst
	chmod 755 $(DEB_DIR)/DEBIAN/postinst

	# Copy files
	install -m 755 ecobz $(DEB_DIR)/usr/bin/ecobz
	install -m 644 lib/*.sh $(DEB_DIR)/usr/lib/ecobz/

	# Build
	dpkg-deb --build $(DEB_DIR)
	mv $(BUILD_DIR)/ecobz_$(VERSION)_all.deb .
	rm -rf $(BUILD_DIR)
	@echo ""
	@echo "Package built: ecobz_$(VERSION)_all.deb"
	@echo "Install with: sudo dpkg -i ecobz_$(VERSION)_all.deb"

# -----------------------------------------------------------------------------
# Clean build artifacts
# -----------------------------------------------------------------------------
clean:
	rm -rf $(BUILD_DIR) ecobz_*.deb ecobz_*.dsc ecobz_*.tar.xz ecobz_*_source.*

# -----------------------------------------------------------------------------
# Build source package for Launchpad PPA
# -----------------------------------------------------------------------------
ppa-source:
	@echo "Building source package for $(PPA)..."
	@command -v debuild >/dev/null 2>&1 || { echo "Install devscripts: sudo apt install devscripts"; exit 1; }
	@command -v dh >/dev/null 2>&1 || { echo "Install debhelper: sudo apt install debhelper"; exit 1; }
	@echo "Cleanup old builds..."
	rm -rf $(BUILD_DIR) ecobz_*.dsc ecobz_*.tar.xz ecobz_*_source.* ecobz_*.deb
	debuild -S -sa
	@echo ""
	@echo "=============================================="
	@echo " Source package built."
	@echo " Now upload with: make ppa-upload"
	@echo "=============================================="

# -----------------------------------------------------------------------------
# Upload source package to Launchpad PPA
# -----------------------------------------------------------------------------
ppa-upload:
	@command -v dput >/dev/null 2>&1 || { echo "Install dput: sudo apt install dput"; exit 1; }
	@changes=$$(ls -t ../ecobz_*_source.changes 2>/dev/null | head -1); \
	if [ -z "$$changes" ]; then \
		echo "No .changes found. Run 'make ppa-source' first."; \
		exit 1; \
	fi; \
	echo "Uploading $$changes to $(PPA)..."; \
	dput "$(PPA)" "$$changes"

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@echo "ecobz Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make install     Install ecobz to system (PREFIX=$(PREFIX))"
	@echo "  make uninstall   Remove ecobz from system"
	@echo "  make deb         Build a .deb package"
	@echo "  make ppa-source  Build source package for Launchpad PPA"
	@echo "  make ppa-upload  Upload to $(PPA)"
	@echo "  make clean       Remove build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX           Installation prefix (default: /usr/local)"
	@echo "  DESTDIR          Staging directory for packaging"
