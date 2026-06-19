#!/usr/bin/env bash
# =============================================================================
# install.sh - Quick install script for ecobz (curl | bash style)
# =============================================================================
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/ecobz/ecobz-script/main"
VERSION="${ECOBZ_VERSION:-1.0.0}"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}"
echo "   ______          __           "
echo "  / ____/_________/ /_  ____    "
echo " / __/  / ___/ __  / __ \\/ _ \\  "
echo " \\_____/\\__/\\__,_/\\___/\\___/  "
echo -e "${NC}"
echo -e "${BOLD}ecobz installer${NC}"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This installer must be run as root (use sudo).${NC}"
    exit 1
fi

# Check Ubuntu
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${RED}This installer is for Ubuntu Linux only.${NC}"
    exit 1
fi

# Install directory
INSTALL_DIR="/usr/local"
BIN_DIR="${INSTALL_DIR}/bin"
LIB_DIR="${INSTALL_DIR}/lib/ecobz"

echo -e "${GREEN}[*]${NC} Creating directories..."
mkdir -p "$BIN_DIR" "$LIB_DIR"

# Check if running from local clone or remote
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/ecobz" ]]; then
    # Local install
    echo -e "${GREEN}[*]${NC} Installing from local sources..."
    install -m 755 "${SCRIPT_DIR}/ecobz" "${BIN_DIR}/ecobz"
    install -m 644 "${SCRIPT_DIR}/lib/"*.sh "${LIB_DIR}/"
else
    # Remote install
    echo -e "${GREEN}[*]${NC} Downloading from remote..."
    curl -fsSL "${REPO_URL}/ecobz" -o "${BIN_DIR}/ecobz"
    chmod 755 "${BIN_DIR}/ecobz"
    for lib in common.sh server-config.sh help.sh; do
        curl -fsSL "${REPO_URL}/lib/${lib}" -o "${LIB_DIR}/${lib}"
    done
fi

echo ""
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  ecobz v${VERSION} installed successfully!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
echo -e "  Run: ${BOLD}sudo ecobz server-config${NC}"
echo ""
