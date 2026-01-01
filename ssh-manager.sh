#!/bin/bash

# SSH Manager for Ubuntu
# Manages SSH server installation, service, and boot configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -v 2>/dev/null; then
            print_error "This operation requires sudo privileges"
            exit 1
        fi
        SUDO="sudo"
    else
        SUDO=""
    fi
}

# Check if openssh-server is installed
is_installed() {
    dpkg -l openssh-server 2>/dev/null | grep -q "^ii"
}

# Check if SSH service is running
is_running() {
    systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null
}

# Check if SSH is enabled on boot
is_enabled() {
    systemctl is-enabled --quiet ssh 2>/dev/null || systemctl is-enabled --quiet sshd 2>/dev/null
}

# Get the correct service name
get_service_name() {
    if systemctl list-unit-files ssh.service &>/dev/null; then
        echo "ssh"
    else
        echo "sshd"
    fi
}

# Show current status
show_status() {
    echo ""
    echo "===== SSH Server Status ====="
    echo ""

    if is_installed; then
        print_success "SSH server is installed"
    else
        print_warn "SSH server is NOT installed"
        echo ""
        return
    fi

    if is_running; then
        print_success "SSH service is running"
    else
        print_warn "SSH service is NOT running"
    fi

    if is_enabled; then
        print_success "SSH starts on boot: enabled"
    else
        print_warn "SSH starts on boot: disabled"
    fi

    echo ""

    # Show connection info if running
    if is_running; then
        echo "--- Connection Info ---"
        local ip_addrs
        ip_addrs=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -5)
        local user
        user=$(whoami)
        echo "Connect using:"
        for ip in $ip_addrs; do
            echo "  ssh ${user}@${ip}"
        done
        echo ""

        # Show SSH port
        local port
        port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        if [[ -z "$port" ]]; then
            port="22 (default)"
        fi
        echo "SSH Port: $port"
    fi
    echo ""
}

# Install SSH server
install_ssh() {
    print_info "Installing OpenSSH server..."

    if is_installed; then
        print_success "SSH server is already installed"
        return 0
    fi

    check_sudo

    print_info "Updating package list..."
    $SUDO apt-get update -qq

    print_info "Installing openssh-server..."
    $SUDO apt-get install -y openssh-server

    local svc
    svc=$(get_service_name)

    # Enable and start by default
    print_info "Enabling SSH to start on boot..."
    $SUDO systemctl enable "$svc"

    print_info "Starting SSH service..."
    $SUDO systemctl start "$svc"

    # Configure firewall if ufw is active
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        print_info "Configuring firewall to allow SSH..."
        $SUDO ufw allow ssh
    fi

    print_success "SSH server installed and started successfully!"
    show_status
}

# Start SSH service
start_ssh() {
    if ! is_installed; then
        print_error "SSH server is not installed. Run: $0 install"
        exit 1
    fi

    if is_running; then
        print_success "SSH service is already running"
        return 0
    fi

    check_sudo
    local svc
    svc=$(get_service_name)

    print_info "Starting SSH service..."
    $SUDO systemctl start "$svc"
    print_success "SSH service started"
}

# Stop SSH service
stop_ssh() {
    if ! is_installed; then
        print_error "SSH server is not installed"
        exit 1
    fi

    if ! is_running; then
        print_warn "SSH service is already stopped"
        return 0
    fi

    check_sudo
    local svc
    svc=$(get_service_name)

    print_info "Stopping SSH service..."
    $SUDO systemctl stop "$svc"
    print_success "SSH service stopped"
}

# Restart SSH service
restart_ssh() {
    if ! is_installed; then
        print_error "SSH server is not installed. Run: $0 install"
        exit 1
    fi

    check_sudo
    local svc
    svc=$(get_service_name)

    print_info "Restarting SSH service..."
    $SUDO systemctl restart "$svc"
    print_success "SSH service restarted"
}

# Enable SSH on boot
enable_boot() {
    if ! is_installed; then
        print_error "SSH server is not installed. Run: $0 install"
        exit 1
    fi

    if is_enabled; then
        print_success "SSH is already enabled on boot"
        return 0
    fi

    check_sudo
    local svc
    svc=$(get_service_name)

    print_info "Enabling SSH to start on boot..."
    $SUDO systemctl enable "$svc"
    print_success "SSH will now start on boot"
}

# Disable SSH on boot
disable_boot() {
    if ! is_installed; then
        print_error "SSH server is not installed"
        exit 1
    fi

    if ! is_enabled; then
        print_warn "SSH is already disabled on boot"
        return 0
    fi

    check_sudo
    local svc
    svc=$(get_service_name)

    print_info "Disabling SSH from starting on boot..."
    $SUDO systemctl disable "$svc"
    print_success "SSH will no longer start on boot"
}

# Uninstall SSH server
uninstall_ssh() {
    if ! is_installed; then
        print_warn "SSH server is not installed"
        return 0
    fi

    echo ""
    print_warn "This will remove the SSH server from your system."
    read -rp "Are you sure? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled"
        return 0
    fi

    check_sudo

    print_info "Stopping SSH service..."
    $SUDO systemctl stop ssh 2>/dev/null || $SUDO systemctl stop sshd 2>/dev/null || true

    print_info "Removing openssh-server..."
    $SUDO apt-get remove -y openssh-server

    print_success "SSH server has been removed"
}

# Show usage
show_usage() {
    cat << EOF

SSH Manager for Ubuntu
======================

Usage: $0 <command>

Commands:
  install      Install SSH server and enable on boot (default setup)
  uninstall    Remove SSH server from the system

  start        Start the SSH service
  stop         Stop the SSH service
  restart      Restart the SSH service

  enable       Enable SSH to start on boot
  disable      Disable SSH from starting on boot

  status       Show current SSH status and connection info
  help         Show this help message

Examples:
  $0 install     # First-time setup
  $0 status      # Check if SSH is running
  $0 disable     # Stop SSH from auto-starting on boot
  $0 stop        # Stop SSH service (until next start/reboot)

EOF
}

# Main
main() {
    local cmd="${1:-}"

    case "$cmd" in
        install)
            install_ssh
            ;;
        uninstall|remove)
            uninstall_ssh
            ;;
        start)
            start_ssh
            ;;
        stop)
            stop_ssh
            ;;
        restart)
            restart_ssh
            ;;
        enable)
            enable_boot
            ;;
        disable)
            disable_boot
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            print_error "Unknown command: $cmd"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
