#!/usr/bin/env bash
# =============================================================================
# help.sh - Help system for ecobz CLI
# =============================================================================

show_main_help() {
    cat <<EOF
${C_BOLD}ecobz${C_NC} - Ubuntu Server Management CLI  v${VERSION}

${C_BOLD}USAGE:${C_NC}
    ecobz <command> [options]

${C_BOLD}COMMANDS:${C_NC}
    server-config     Auto-configure Ubuntu server with recommended settings
                      (hostname, timezone, updates, firewall, swap, etc.)

${C_BOLD}GLOBAL OPTIONS:${C_NC}
    --version, -v     Show version
    --help, -h        Show this help

${C_BOLD}EXAMPLES:${C_NC}
    sudo ecobz server-config
    sudo ecobz server-config --interactive
    sudo ecobz server-config --timezone Asia/Bangkok --hostname myserver
EOF
}

show_server_config_help() {
    cat <<EOF
${C_BOLD}ecobz server-config${C_NC} - Auto-configure Ubuntu Server

${C_BOLD}USAGE:${C_NC}
    ecobz server-config [options]

${C_BOLD}OPTIONS:${C_NC}
    --interactive, -i       Interactive mode — prompts for each setting
    --minimal               Security essentials only (skip monitoring tools)
    --hostname <name>       Set server hostname
    --timezone <tz>         Set timezone (default: Asia/Bangkok)
    --no-firewall           Skip UFW firewall configuration
    --no-auto-updates       Skip automatic security updates
    --no-swap               Skip swap file creation
    --swap-size <mb>        Swap size in MB (default: 2048)
    --extra-pkgs <list>     Comma-separated list of extra packages to install
    --help, -h              Show this help

${C_BOLD}WHAT IT DOES:${C_NC}
    1. apt update & upgrade
    2. Set hostname
    3. Set timezone
    4. Install essential packages
       (--minimal: security basics only; default: + monitoring tools)
    5. Configure automatic security updates (unattended-upgrades)
    6. Configure UFW firewall (allow SSH, default deny)
    7. Enable NTP time sync
    8. Create swap file (if no swap exists)
    9. Configure locale (en_US.UTF-8)
   10. Optimise sysctl settings
   11. Install custom welcome screen (MOTD)
   12. Configure logrotate

${C_BOLD}EXAMPLES:${C_NC}
    sudo ecobz server-config
    sudo ecobz server-config --hostname web01 --timezone Asia/Bangkok
    sudo ecobz server-config --interactive --swap-size 4096
EOF
}
