#!/usr/bin/env bash
# =============================================================================
# server-config.sh - Auto-configure Ubuntu server with recommended settings
# =============================================================================

cmd_server_config() {
    local interactive=false
    local hostname=""
    local timezone="Asia/Bangkok"
    local do_firewall=true
    local do_auto_updates=true
    local do_swap=true
    local swap_size=2048
    local extra_pkgs=""

    # -------------------------------------------------------------------------
    # Parse arguments
    # -------------------------------------------------------------------------
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive|-i)
                interactive=true; shift ;;
            --hostname)
                hostname="$2"; shift 2 ;;
            --timezone)
                timezone="$2"; shift 2 ;;
            --no-firewall)
                do_firewall=false; shift ;;
            --no-auto-updates)
                do_auto_updates=false; shift ;;
            --no-swap)
                do_swap=false; shift ;;
            --swap-size)
                swap_size="$2"; shift 2 ;;
            --extra-pkgs)
                extra_pkgs="$2"; shift 2 ;;
            --help|-h)
                show_server_config_help; return 0 ;;
            *)
                log_error "Unknown option: $1"
                show_server_config_help; return 1 ;;
        esac
    done

    # -------------------------------------------------------------------------
    # Pre-flight checks
    # -------------------------------------------------------------------------
    check_ubuntu

    print_banner
    log_info "Starting Ubuntu Server auto-configuration..."
    echo ""

    # -------------------------------------------------------------------------
    # Interactive mode
    # -------------------------------------------------------------------------
    if $interactive; then
        run_interactive
    fi

    # -------------------------------------------------------------------------
    # Step 1: apt update & upgrade
    # -------------------------------------------------------------------------
    apt_update_upgrade

    # -------------------------------------------------------------------------
    # Step 2: Set hostname
    # -------------------------------------------------------------------------
    if [[ -z "$hostname" ]] && $interactive; then
        read -r -p "Enter hostname: " hostname
    fi
    if [[ -n "$hostname" ]]; then
        set_hostname "$hostname"
    else
        log_info "Skipping hostname (not specified). Current: $(hostnamectl --static)"
    fi

    # -------------------------------------------------------------------------
    # Step 3: Set timezone
    # -------------------------------------------------------------------------
    if $interactive; then
        read -r -p "Enter timezone [${timezone}]: " tz_input
        timezone="${tz_input:-$timezone}"
    fi
    set_timezone "$timezone"

    # -------------------------------------------------------------------------
    # Step 4: Install essential packages
    # -------------------------------------------------------------------------
    local essential_pkgs=(
        curl wget git vim nano htop net-tools
        ca-certificates gnupg lsb-release
        software-properties-common
        dnsutils  # dig, nslookup
        mtr       # network diagnostics
        iotop     # disk I/O monitor
        ncdu      # disk usage
        iftop     # network monitor
        lsof      # list open files
        bash-completion
        unzip zip
        jq        # JSON parser
        glances   # all-in-one system monitor
        sysstat   # sar, iostat, mpstat (historical stats)
        lm-sensors # CPU temp, fan speed
    )

    if [[ -n "$extra_pkgs" ]]; then
        IFS=',' read -ra extra_arr <<< "$extra_pkgs"
        essential_pkgs+=("${extra_arr[@]}")
    fi

    install_packages "${essential_pkgs[@]}"

    # -------------------------------------------------------------------------
    # Step 5: Configure automatic security updates
    # -------------------------------------------------------------------------
    if $do_auto_updates; then
        configure_auto_updates
    else
        log_info "Skipping automatic security updates."
    fi

    # -------------------------------------------------------------------------
    # Step 6: Configure UFW firewall
    # -------------------------------------------------------------------------
    if $do_firewall; then
        configure_firewall
    else
        log_info "Skipping firewall configuration."
    fi

    # -------------------------------------------------------------------------
    # Step 7: Enable NTP time sync
    # -------------------------------------------------------------------------
    configure_ntp

    # -------------------------------------------------------------------------
    # Step 8: Create swap
    # -------------------------------------------------------------------------
    if $do_swap; then
        create_swap "$swap_size"
    else
        log_info "Skipping swap creation."
    fi

    # -------------------------------------------------------------------------
    # Step 9: Configure locale
    # -------------------------------------------------------------------------
    log_step "Configuring locale (en_US.UTF-8)..."
    locale-gen en_US.UTF-8 2>/dev/null || true
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 2>/dev/null || true
    log_info "Locale configured."

    # -------------------------------------------------------------------------
    # Step 10: Optimise sysctl
    # -------------------------------------------------------------------------
    log_step "Applying recommended sysctl settings..."
    cat >> /etc/sysctl.d/99-ecobz.conf <<'EOF'
# ecobz recommended settings
net.core.somaxconn = 1024
net.ipv4.tcp_fastopen = 3
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
    sysctl --system &>/dev/null || true
    log_info "Sysctl optimisations applied."

    # -------------------------------------------------------------------------
    # Done
    # -------------------------------------------------------------------------
    echo ""
    log_info "=============================================="
    log_info "  Server configuration complete!"
    log_info "  Hostname : $(hostnamectl --static)"
    log_info "  Timezone : $(timedatectl show --property=Timezone --value)"
    log_info "  Uptime   : $(uptime -p)"
    log_info "=============================================="
    echo ""
    log_warn "A reboot is recommended if the kernel was upgraded."
}

# -----------------------------------------------------------------------------
# Interactive mode — ask before each major step
# -----------------------------------------------------------------------------
run_interactive() {
    echo ""
    log_info "=== Interactive Mode ==="
    echo ""

    if ! confirm "Proceed with apt update & upgrade?"; then
        log_error "Aborted by user."
        exit 0
    fi
}
