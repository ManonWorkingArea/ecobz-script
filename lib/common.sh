#!/usr/bin/env bash
# =============================================================================
# common.sh - Shared utility functions for ecobz
# =============================================================================

# -----------------------------------------------------------------------------
# Colours
# -----------------------------------------------------------------------------
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'
C_NC='\033[0m' # No Colour

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log_info()  { echo -e "${C_GREEN}[INFO]${C_NC}  $*"; }
log_warn()  { echo -e "${C_YELLOW}[WARN]${C_NC}  $*"; }
log_error() { echo -e "${C_RED}[ERROR]${C_NC} $*" >&2; }
log_step()  { echo -e "${C_CYAN}==>${C_NC} ${C_BOLD}$*${C_NC}"; }

# -----------------------------------------------------------------------------
# Check if running on Ubuntu
# -----------------------------------------------------------------------------
is_ubuntu() {
    [[ -f /etc/os-release ]] && grep -qi "ubuntu" /etc/os-release
}

check_ubuntu() {
    if ! is_ubuntu; then
        log_error "This script is designed for Ubuntu Linux only."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Check if a command exists
# -----------------------------------------------------------------------------
command_exists() {
    command -v "$1" &>/dev/null
}

# -----------------------------------------------------------------------------
# Ask yes/no question
# -----------------------------------------------------------------------------
confirm() {
    local prompt="$1"
    local default="${2:-y}"

    if [[ "$default" == "y" ]]; then
        read -r -p "$prompt [Y/n]: " answer
        [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
    else
        read -r -p "$prompt [y/N]: " answer
        [[ "$answer" =~ ^[Yy] ]]
    fi
}

# -----------------------------------------------------------------------------
# Run apt update & upgrade
# -----------------------------------------------------------------------------
apt_update_upgrade() {
    log_step "Running apt update..."
    apt-get update -qq

    log_step "Running apt upgrade..."
    apt-get upgrade -y -qq

    log_info "System updated successfully."
}

# -----------------------------------------------------------------------------
# Install packages if missing
# -----------------------------------------------------------------------------
install_packages() {
    local pkg
    local to_install=()

    for pkg in "$@"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_step "Installing: ${to_install[*]}"
        apt-get install -y -qq "${to_install[@]}"
    else
        log_info "All specified packages are already installed."
    fi
}

# -----------------------------------------------------------------------------
# Set hostname
# -----------------------------------------------------------------------------
set_hostname() {
    local new_hostname="$1"

    if [[ -z "$new_hostname" ]]; then
        log_error "Hostname cannot be empty."
        return 1
    fi

    local current
    current=$(hostnamectl --static)

    if [[ "$current" == "$new_hostname" ]]; then
        log_info "Hostname is already '${new_hostname}'."
        return 0
    fi

    log_step "Setting hostname to '${new_hostname}'..."
    hostnamectl set-hostname "$new_hostname"

    # Update /etc/hosts
    if ! grep -q "127.0.1.1.*${new_hostname}" /etc/hosts; then
        sed -i "/127.0.1.1/c\127.0.1.1\t${new_hostname}" /etc/hosts
    fi

    log_info "Hostname set to '${new_hostname}'."
}

# -----------------------------------------------------------------------------
# Set timezone
# -----------------------------------------------------------------------------
set_timezone() {
    local tz="${1:-Asia/Bangkok}"

    log_step "Setting timezone to '${tz}'..."
    timedatectl set-timezone "$tz"
    log_info "Timezone set to '${tz}'."
    log_info "Current time: $(date)"
}

# -----------------------------------------------------------------------------
# Configure automatic security updates (unattended-upgrades)
# -----------------------------------------------------------------------------
configure_auto_updates() {
    log_step "Configuring automatic security updates..."

    install_packages unattended-upgrades update-notifier-common

    # Enable automatic updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # Enable security updates in unattended-upgrades config
    sed -i 's|//\s*"${distro_id}:${distro_codename}-security";|"${distro_id}:${distro_codename}-security";|g' \
        /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true

    # Enable updates
    sed -i 's|//\s*"${distro_id}:${distro_codename}-updates";|"${distro_id}:${distro_codename}-updates";|g' \
        /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true

    log_info "Automatic security updates configured."
}

# -----------------------------------------------------------------------------
# Configure UFW firewall
# -----------------------------------------------------------------------------
configure_firewall() {
    log_step "Configuring UFW firewall..."

    install_packages ufw

    # Default deny incoming, allow outgoing
    ufw --force default deny incoming
    ufw --force default allow outgoing

    # Allow SSH
    ufw allow ssh

    # Enable UFW
    ufw --force enable

    log_info "UFW firewall configured (SSH allowed, default deny incoming)."
}

# -----------------------------------------------------------------------------
# Configure NTP time sync
# -----------------------------------------------------------------------------
configure_ntp() {
    log_step "Configuring NTP time synchronization..."

    if command_exists timedatectl; then
        timedatectl set-ntp true
        log_info "NTP enabled via systemd-timesyncd."
    else
        install_packages chrony
        systemctl enable --now chrony 2>/dev/null || true
        log_info "NTP enabled via chrony."
    fi
}

# -----------------------------------------------------------------------------
# Create swap file if needed
# -----------------------------------------------------------------------------
create_swap() {
    local size_mb="${1:-2048}"

    if swapon --show | grep -q .; then
        log_info "Swap already exists; skipping."
        return 0
    fi

    log_step "Creating ${size_mb}MB swap file..."
    fallocate -l "${size_mb}M" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    if ! grep -q /swapfile /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    log_info "Swap file created (${size_mb}MB)."
}

# -----------------------------------------------------------------------------
# Install custom MOTD (Welcome screen showing specs + monitoring guide)
# -----------------------------------------------------------------------------
install_motd() {
    log_step "Installing custom welcome screen (MOTD)..."

    cat > /etc/update-motd.d/99-ecobz-welcome <<'MOTDEOF'
#!/bin/bash
# =============================================================================
# ecobz Welcome Screen — Server specs & Monitoring guide
# =============================================================================

# Colours
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# ── System Specs ────────────────────────────────────────────────────────────
echo -e "${C}┌──────────────────────────────────────────────────────┐${N}"
echo -e "${C}│${W}  SYSTEM INFORMATION${C}                                  │${N}"
echo -e "${C}├──────────────────────────────────────────────────────┤${N}"

# Hostname & OS
printf "${C}│${N}  ${W}Hostname${N}    : ${G}%s${N}\n" "$(hostname)"
printf "${C}│${N}  ${W}OS${N}          : ${G}%s${N}\n" "$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
printf "${C}│${N}  ${W}Kernel${N}      : ${G}%s${N}\n" "$(uname -r)"
printf "${C}│${N}  ${W}Uptime${N}      : ${G}%s${N}\n" "$(uptime -p | sed 's/up //')"

# CPU
cpu_model=$(lscpu 2>/dev/null | grep 'Model name' | head -1 | sed 's/Model name:\s*//')
cpu_cores=$(nproc)
printf "${C}│${N}  ${W}CPU${N}         : ${G}%s (%s cores)${N}\n" "$cpu_model" "$cpu_cores"

# RAM
mem_total=$(free -h | awk '/^Mem:/{print $2}')
mem_used=$(free -h | awk '/^Mem:/{print $3}')
mem_percent=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
printf "${C}│${N}  ${W}RAM${N}         : ${G}%s / %s (%s%%)${N}\n" "$mem_used" "$mem_total" "$mem_percent"

# Disk
disk_info=$(df -h / | awk 'NR==2{print $3" / "$2" ("$5")"}')
printf "${C}│${N}  ${W}Disk (/)${N}    : ${G}%s${N}\n" "$disk_info"

# Swap
swap_total=$(free -h | awk '/^Swap:/{print $2}')
swap_used=$(free -h | awk '/^Swap:/{print $3}')
printf "${C}│${N}  ${W}Swap${N}        : ${G}%s / %s${N}\n" "${swap_used:-0}" "${swap_total:-0}"

# IP Addresses
echo -e "${C}├──────────────────────────────────────────────────────┤${N}"
printf "${C}│${N}  ${W}IP Addresses${N}:${N}\n"
ip -4 addr show scope global | grep inet | while read -r line; do
    iface=$(echo "$line" | awk '{print $NF}')
    ipaddr=$(echo "$line" | awk '{print $2}')
    printf "${C}│${N}    ${C}%-10s${N} ${G}%s${N}\n" "$iface" "$ipaddr"
done

# Load
load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
printf "${C}│${N}  ${W}Load Avg${N}    : ${G}%s${N}\n" "$load"

echo -e "${C}└──────────────────────────────────────────────────────┘${N}"
echo ""

# ── Monitoring Quick Guide ──────────────────────────────────────────────────
echo -e "${C}┌──────────────────────────────────────────────────────┐${N}"
echo -e "${C}│${W}  MONITORING QUICK GUIDE${C}                              │${N}"
echo -e "${C}├──────────────────────────────────────────────────────┤${N}"
echo -e "${C}│${N}  ${G}glances${N}     ภาพรวมทั้งหมด (CPU,RAM,Disk,Net)   ${C}│${N}"
echo -e "${C}│${N}  ${G}htop${N}        ดู process + CPU/RAM แบบ interact  ${C}│${N}"
echo -e "${C}│${N}  ${G}iotop${N}       process ที่กิน disk I/O มากสุด       ${C}│${N}"
echo -e "${C}│${N}  ${G}iftop${N}       ดู network traffic แบบ real-time    ${C}│${N}"
echo -e "${C}│${N}  ${G}sensors${N}     วัดอุณหภูมิ CPU + ความเร็วพัดลม     ${C}│${N}"
echo -e "${C}│${N}  ${G}iostat -x 1${N} disk I/O stats รายวินาที            ${C}│${N}"
echo -e "${C}│${N}  ${G}ncdu /${N}       ดูว่า folder ไหนกินเนื้อที่มากสุด  ${C}│${N}"
echo -e "${C}│${N}  ${G}df -h${N}       เช็คพื้นที่ disk ทั้งหมด             ${C}│${N}"
echo -e "${C}│${N}  ${G}free -h${N}     เช็ค RAM + Swap                     ${C}│${N}"
echo -e "${C}└──────────────────────────────────────────────────────┘${N}"
MOTDEOF

    chmod 755 /etc/update-motd.d/99-ecobz-welcome

    # Disable default boring MOTD parts (keep our custom one only)
    chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true
    chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true
    chmod -x /etc/update-motd.d/50-landscape-sysinfo 2>/dev/null || true

    log_info "Custom welcome screen installed."
}

# -----------------------------------------------------------------------------
# Configure logrotate for key system logs (prevent disk full)
# -----------------------------------------------------------------------------
configure_logrotate() {
    log_step "Configuring logrotate..."

    install_packages logrotate

    cat > /etc/logrotate.d/ecobz-system <<'LREOF'
# ecobz — system logs rotation (prevents disk full)
/var/log/syslog
/var/log/messages
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/debug
/var/log/daemon.log
{
    rotate 7
    daily
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        systemctl kill -s HUP rsyslog.service 2>/dev/null || true
    endscript
}

/var/log/btmp
/var/log/wtmp
{
    rotate 4
    monthly
    missingok
    notifempty
    compress
    create 0600 root utmp
}

/var/log/unattended-upgrades/unattended-upgrades.log
{
    rotate 4
    monthly
    missingok
    notifempty
    compress
}

/var/log/dpkg.log
/var/log/apt/history.log
/var/log/apt/term.log
{
    rotate 4
    monthly
    missingok
    notifempty
    compress
}
LREOF

    log_info "Logrotate configured (7 daily rotates for system logs, 4 monthly for others)."
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------
print_banner() {
    echo -e "${C_CYAN}"
    echo "   ______          __           "
    echo "  / ____/_________/ /_  ____    "
    echo " / __/  / ___/ __  / __ \\/ _ \\  "
    echo " \\_____/\\__/\\__,_/\\___/\\___/  "
    echo -e "${C_NC}"
    echo -e "${C_BOLD}ecobz v${VERSION} - Ubuntu Server Auto-Config${C_NC}"
    echo ""
}
