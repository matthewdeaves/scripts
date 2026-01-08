#!/bin/bash
set -e

# FTP Server Management Script
# Comprehensive tool for managing vsftpd FTP server with anonymous access

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
VSFTPD_CONF="/etc/vsftpd.conf"
DEFAULT_FTP_ROOT="/srv/ftp"

# Output functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}\n"
}

# Check if running as root or can use sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            print_error "This operation requires sudo privileges"
            print_info "Please run with sudo or enter your password when prompted"
            # Test sudo access
            if ! sudo true; then
                exit 1
            fi
        fi
    fi
}

# Check if vsftpd is installed
is_vsftpd_installed() {
    command -v vsftpd &> /dev/null
}

# Check if vsftpd service is running
is_vsftpd_running() {
    systemctl is-active --quiet vsftpd 2>/dev/null
}

# Get vsftpd config value
get_config_value() {
    local key="$1"
    local default="$2"
    if [[ -f "$VSFTPD_CONF" ]]; then
        local value=$(grep -E "^${key}=" "$VSFTPD_CONF" 2>/dev/null | tail -1 | cut -d'=' -f2-)
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi
    echo "$default"
}

# Set vsftpd config value
set_config_value() {
    local key="$1"
    local value="$2"
    check_sudo

    if grep -qE "^${key}=" "$VSFTPD_CONF" 2>/dev/null; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" "$VSFTPD_CONF"
    elif grep -qE "^#${key}=" "$VSFTPD_CONF" 2>/dev/null; then
        sudo sed -i "s|^#${key}=.*|${key}=${value}|" "$VSFTPD_CONF"
    else
        echo "${key}=${value}" | sudo tee -a "$VSFTPD_CONF" > /dev/null
    fi
}

# Show usage/help
show_usage() {
    local script_name
    script_name=$(basename "$0")

    echo -e "${BOLD}FTP Server Management Script${NC}"
    echo
    echo -e "${BOLD}Usage:${NC} $script_name <command> [options]"
    echo
    echo -e "${BOLD}Setup Commands:${NC}"
    echo "  install               Install and configure vsftpd"
    echo "  setup [path]          Configure vsftpd for anonymous access"
    echo "  uninstall             Remove vsftpd"
    echo
    echo -e "${BOLD}Service Commands:${NC}"
    echo "  start                 Start FTP server"
    echo "  stop                  Stop FTP server"
    echo "  restart               Restart FTP server"
    echo "  status                Show server status and configuration"
    echo
    echo -e "${BOLD}Configuration Commands:${NC}"
    echo "  set-root <path>       Set the FTP root directory"
    echo "  set-port <port>       Set FTP listen port (default: 21)"
    echo "  enable-uploads        Create writable 'uploads' folder for anonymous users"
    echo "  disable-uploads       Remove write access (read-only)"
    echo "  config                Show current configuration"
    echo "  logs                  Show FTP server logs"
    echo
    echo -e "${BOLD}Firewall Commands:${NC}"
    echo "  open-firewall         Open FTP ports in firewall (21 + passive)"
    echo "  close-firewall        Close FTP ports in firewall"
    echo "  firewall-status       Show firewall status for FTP ports"
    echo
    echo -e "${BOLD}Diagnostics:${NC}"
    echo "  test                  Test FTP connectivity and uploads"
    echo "  diagnose              Full diagnostic check"
    echo
    echo -e "${BOLD}Interactive Mode:${NC}"
    echo "  interactive, -i       Launch interactive TUI mode"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  -h, --help, help      Show this help message"
    echo "  -y, --yes             Skip confirmation prompts"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  $script_name install              # Install vsftpd"
    echo "  $script_name setup                # Configure for anonymous access"
    echo "  $script_name start                # Start the FTP server"
    echo "  $script_name enable-uploads       # Allow anonymous uploads"
    echo "  $script_name set-root /data/ftp   # Set FTP root to /data/ftp"
    echo "  $script_name -i                   # Interactive mode"
    echo
    echo -e "${BOLD}Notes:${NC}"
    echo "  - This script configures vsftpd for anonymous access"
    echo "  - Anonymous users can read files but cannot upload by default"
    echo "  - Default FTP root: $DEFAULT_FTP_ROOT"
}

# Confirmation prompt
confirm() {
    local message="$1"
    if [[ "$SKIP_CONFIRM" == "true" ]]; then
        return 0
    fi
    echo -en "${YELLOW}$message [y/N]: ${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Setup/configure vsftpd for anonymous access
setup_vsftpd() {
    check_sudo

    if ! is_vsftpd_installed; then
        print_error "vsftpd is not installed. Run '$0 install' first"
        exit 1
    fi

    local ftp_root="${1:-$DEFAULT_FTP_ROOT}"

    # Create FTP root directory
    if [[ ! -d "$ftp_root" ]]; then
        print_info "Creating FTP root: $ftp_root"
        sudo mkdir -p "$ftp_root"
    fi
    sudo chmod 755 "$ftp_root"

    # Backup original config
    if [[ -f "$VSFTPD_CONF" ]]; then
        sudo cp "$VSFTPD_CONF" "${VSFTPD_CONF}.backup.$(date +%Y%m%d%H%M%S)"
        print_info "Backed up existing config"
    fi

    # Configure for anonymous access
    print_info "Configuring vsftpd for anonymous access..."

    sudo tee "$VSFTPD_CONF" > /dev/null << EOF
# vsftpd configuration - Anonymous FTP Server
# Generated by ftp-manager.sh

# Run in standalone mode
listen=YES
listen_ipv6=NO

# Anonymous access settings
anonymous_enable=YES
anon_root=$ftp_root
no_anon_password=YES

# Security settings - read-only by default
local_enable=NO
write_enable=NO
anon_upload_enable=NO
anon_mkdir_write_enable=NO

# Connection settings
connect_from_port_20=YES
listen_port=21

# Passive mode (required for NAT/firewalls and older clients)
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
pasv_addr_resolve=NO
pasv_address=$(hostname -I | awk '{print $1}')

# Logging
xferlog_enable=YES
xferlog_std_format=YES

# Misc
dirmessage_enable=YES
use_localtime=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd

# Banner
ftpd_banner=Welcome to FTP Server
EOF

    # Create secure chroot directory if it doesn't exist
    sudo mkdir -p /var/run/vsftpd/empty

    print_success "vsftpd configured for anonymous access"
    print_info "FTP root directory: $ftp_root"

    # Restart if running
    if is_vsftpd_running; then
        print_info "Restarting FTP server..."
        sudo systemctl restart vsftpd
        print_success "FTP server restarted"
    else
        print_info "Run '$0 start' to start the FTP server"
    fi
}

# Install vsftpd
install_vsftpd() {
    check_sudo

    if is_vsftpd_installed; then
        print_warn "vsftpd is already installed"
        if confirm "Run setup to reconfigure for anonymous access?"; then
            setup_vsftpd
        fi
        return
    fi

    print_info "Installing vsftpd..."

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y vsftpd
    elif command -v brew &> /dev/null; then
        brew install vsftpd
    else
        print_error "No supported package manager found (apt-get or brew)"
        exit 1
    fi

    print_success "vsftpd installed"

    # Run setup
    setup_vsftpd
}

# Uninstall vsftpd
uninstall_vsftpd() {
    if ! is_vsftpd_installed; then
        print_warn "vsftpd is not installed"
        return
    fi

    print_warn "This will remove vsftpd and its configuration"

    if confirm "Continue with uninstall?"; then
        check_sudo

        # Stop service first
        if is_vsftpd_running; then
            print_info "Stopping vsftpd..."
            sudo systemctl stop vsftpd
        fi

        print_info "Removing vsftpd..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get remove -y vsftpd
            sudo apt-get autoremove -y
        elif command -v brew &> /dev/null; then
            brew uninstall vsftpd
        fi

        print_success "vsftpd removed"
        print_info "Note: FTP root directory was not removed"
    fi
}

# Start FTP server
start_ftp() {
    if ! is_vsftpd_installed; then
        print_error "vsftpd is not installed. Run '$0 install' first"
        exit 1
    fi

    if is_vsftpd_running; then
        print_warn "FTP server is already running"
        return
    fi

    check_sudo
    print_info "Starting FTP server..."
    sudo systemctl start vsftpd
    sudo systemctl enable vsftpd 2>/dev/null || true

    if is_vsftpd_running; then
        print_success "FTP server started"
        local port=$(get_config_value "listen_port" "21")
        local root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
        print_info "Listening on port $port"
        print_info "FTP root: $root"
        echo
        print_info "Connect from clients on your network:"
        local ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -5)
        if [[ -n "$ips" ]]; then
            while read -r ip; do
                echo -e "       ${CYAN}ftp://${ip}${NC}"
            done <<< "$ips"
        fi
    else
        print_error "Failed to start FTP server"
        exit 1
    fi
}

# Stop FTP server
stop_ftp() {
    if ! is_vsftpd_installed; then
        print_error "vsftpd is not installed"
        exit 1
    fi

    if ! is_vsftpd_running; then
        print_warn "FTP server is not running"
        return
    fi

    check_sudo
    print_info "Stopping FTP server..."
    sudo systemctl stop vsftpd
    print_success "FTP server stopped"
}

# Restart FTP server
restart_ftp() {
    if ! is_vsftpd_installed; then
        print_error "vsftpd is not installed. Run '$0 install' first"
        exit 1
    fi

    check_sudo
    print_info "Restarting FTP server..."
    sudo systemctl restart vsftpd

    if is_vsftpd_running; then
        print_success "FTP server restarted"
        local port=$(get_config_value "listen_port" "21")
        local root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
        print_info "Listening on port $port"
        print_info "FTP root: $root"
        echo
        print_info "Connect from clients on your network:"
        local ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -5)
        if [[ -n "$ips" ]]; then
            while read -r ip; do
                echo -e "       ${CYAN}ftp://${ip}${NC}"
            done <<< "$ips"
        fi
    else
        print_error "Failed to restart FTP server"
        exit 1
    fi
}

# Show status
show_status() {
    print_header "FTP Server Status"

    # Installation status
    if is_vsftpd_installed; then
        echo -e "  ${BOLD}Installed:${NC}    ${GREEN}Yes${NC}"
    else
        echo -e "  ${BOLD}Installed:${NC}    ${RED}No${NC}"
        print_info "Run '$0 install' to install vsftpd"
        return
    fi

    # Service status
    if is_vsftpd_running; then
        echo -e "  ${BOLD}Status:${NC}       ${GREEN}Running${NC}"
    else
        echo -e "  ${BOLD}Status:${NC}       ${RED}Stopped${NC}"
    fi

    # Configuration
    local port=$(get_config_value "listen_port" "21")
    local root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
    local anon=$(get_config_value "anonymous_enable" "NO")
    local upload=$(get_config_value "anon_upload_enable" "NO")

    echo -e "  ${BOLD}Port:${NC}         $port"
    echo -e "  ${BOLD}FTP Root:${NC}     $root"
    echo -e "  ${BOLD}Anonymous:${NC}    $anon"

    # Show upload status with color
    if [[ "$upload" == "YES" ]]; then
        echo -e "  ${BOLD}Uploads:${NC}      ${GREEN}Enabled${NC} (to ${root}/uploads)"
    else
        echo -e "  ${BOLD}Uploads:${NC}      ${YELLOW}Disabled${NC} (read-only)"
    fi

    # Passive mode info
    local pasv=$(get_config_value "pasv_enable" "NO")
    local pasv_addr=$(get_config_value "pasv_address" "")
    local pasv_range=$(get_passive_ports)
    if [[ "$pasv" == "YES" ]]; then
        echo -e "  ${BOLD}Passive Mode:${NC} ${GREEN}Enabled${NC} (ports $pasv_range)"
        if [[ -n "$pasv_addr" ]]; then
            echo -e "  ${BOLD}Passive IP:${NC}   $pasv_addr"
        fi
    else
        echo -e "  ${BOLD}Passive Mode:${NC} ${YELLOW}Disabled${NC}"
    fi

    # Show IP addresses for connection
    echo
    echo -e "  ${BOLD}Connect via:${NC}"

    # Get local IPs
    local ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -5)
    if [[ -n "$ips" ]]; then
        while read -r ip; do
            echo -e "    ftp://${ip}:${port}"
        done <<< "$ips"
    else
        echo -e "    ftp://localhost:${port}"
    fi

    # Check FTP root directory
    echo
    if [[ -d "$root" ]]; then
        local file_count=$(find "$root" -maxdepth 1 -type f 2>/dev/null | wc -l)
        local dir_count=$(find "$root" -maxdepth 1 -type d 2>/dev/null | wc -l)
        ((dir_count--)) # exclude the root itself
        echo -e "  ${BOLD}Root Contents:${NC} $file_count files, $dir_count directories"
    else
        echo -e "  ${BOLD}Root Contents:${NC} ${YELLOW}Directory does not exist${NC}"
    fi
}

# Show configuration
show_config() {
    print_header "vsftpd Configuration"

    if [[ ! -f "$VSFTPD_CONF" ]]; then
        print_error "Configuration file not found: $VSFTPD_CONF"
        exit 1
    fi

    # Show non-comment, non-empty lines
    grep -v '^#' "$VSFTPD_CONF" | grep -v '^$' | while read -r line; do
        local key=$(echo "$line" | cut -d'=' -f1)
        local value=$(echo "$line" | cut -d'=' -f2-)
        printf "  ${BOLD}%-25s${NC} %s\n" "$key" "$value"
    done
}

# Set root directory
set_root_dir() {
    local new_root="$1"

    if [[ -z "$new_root" ]]; then
        print_error "Please specify a directory path"
        echo "Usage: $0 set-root <path>"
        exit 1
    fi

    # Convert to absolute path
    new_root=$(realpath -m "$new_root")

    # Check if directory exists
    if [[ ! -d "$new_root" ]]; then
        print_warn "Directory does not exist: $new_root"
        if confirm "Create it?"; then
            check_sudo
            sudo mkdir -p "$new_root"
            sudo chmod 755 "$new_root"
            print_success "Created directory: $new_root"
        else
            exit 1
        fi
    fi

    check_sudo
    set_config_value "anon_root" "$new_root"
    print_success "FTP root set to: $new_root"

    # Restart if running
    if is_vsftpd_running; then
        print_info "Restarting FTP server to apply changes..."
        sudo systemctl restart vsftpd
        print_success "FTP server restarted"
    fi
}

# Enable uploads - create writable uploads folder
enable_uploads() {
    if ! is_vsftpd_installed; then
        print_error "vsftpd is not installed"
        exit 1
    fi

    check_sudo

    local ftp_root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
    local uploads_dir="${ftp_root}/uploads"

    # Create uploads directory
    print_info "Creating uploads directory: $uploads_dir"
    sudo mkdir -p "$uploads_dir"

    # Set permissions - owned by ftp user, world-writable for anonymous uploads
    sudo chown ftp:ftp "$uploads_dir"
    sudo chmod 777 "$uploads_dir"

    # Update config to enable writes
    print_info "Enabling write access..."
    set_config_value "write_enable" "YES"
    set_config_value "anon_upload_enable" "YES"
    set_config_value "anon_mkdir_write_enable" "YES"

    # Restart if running
    if is_vsftpd_running; then
        print_info "Restarting FTP server..."
        sudo systemctl restart vsftpd
    fi

    print_success "Uploads enabled"
    print_info "Anonymous users can now upload to: $uploads_dir"
    print_info "The root folder ($ftp_root) remains read-only"
}

# Disable uploads - make read-only
disable_uploads() {
    if ! is_vsftpd_installed; then
        print_error "vsftpd is not installed"
        exit 1
    fi

    check_sudo

    print_info "Disabling write access..."
    set_config_value "write_enable" "NO"
    set_config_value "anon_upload_enable" "NO"
    set_config_value "anon_mkdir_write_enable" "NO"

    # Restart if running
    if is_vsftpd_running; then
        print_info "Restarting FTP server..."
        sudo systemctl restart vsftpd
    fi

    print_success "Write access disabled - FTP is now read-only"
}

# Show logs
show_logs() {
    print_header "FTP Server Logs"

    if command -v journalctl &> /dev/null; then
        sudo journalctl -u vsftpd --no-pager -n 50
    else
        print_warn "journalctl not available"
        if [[ -f /var/log/vsftpd.log ]]; then
            tail -50 /var/log/vsftpd.log
        else
            print_info "No logs found"
        fi
    fi
}

# Set FTP port
set_ftp_port() {
    local new_port="$1"

    if [[ -z "$new_port" ]]; then
        print_error "Please specify a port number"
        echo "Usage: $0 set-port <port>"
        exit 1
    fi

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1 ]] || [[ "$new_port" -gt 65535 ]]; then
        print_error "Invalid port number: $new_port"
        exit 1
    fi

    check_sudo
    set_config_value "listen_port" "$new_port"
    print_success "FTP port set to: $new_port"

    if is_vsftpd_running; then
        print_info "Restarting FTP server..."
        sudo systemctl restart vsftpd
        print_success "FTP server restarted on port $new_port"
    fi

    print_warn "Remember to update firewall if needed: $0 open-firewall"
}

# Get passive port range
get_passive_ports() {
    local min=$(get_config_value "pasv_min_port" "40000")
    local max=$(get_config_value "pasv_max_port" "40100")
    echo "$min:$max"
}

# Check if ufw is available and active
is_ufw_active() {
    command -v ufw &> /dev/null && sudo ufw status 2>/dev/null | grep -q "Status: active"
}

# Check if iptables is being used
is_iptables_active() {
    command -v iptables &> /dev/null && [[ $(sudo iptables -L INPUT -n 2>/dev/null | wc -l) -gt 2 ]]
}

# Open firewall ports for FTP
open_firewall() {
    check_sudo

    local ftp_port=$(get_config_value "listen_port" "21")
    local pasv_range=$(get_passive_ports)

    print_info "Opening FTP ports..."
    print_info "  FTP control: $ftp_port/tcp"
    print_info "  Passive mode: $pasv_range/tcp"

    if is_ufw_active; then
        print_info "Using ufw..."
        sudo ufw allow "$ftp_port/tcp" comment "FTP control"
        sudo ufw allow "$pasv_range/tcp" comment "FTP passive mode"
        print_success "Firewall ports opened (ufw)"
    elif is_iptables_active; then
        print_info "Using iptables..."
        sudo iptables -A INPUT -p tcp --dport "$ftp_port" -j ACCEPT
        local min_port=$(echo "$pasv_range" | cut -d: -f1)
        local max_port=$(echo "$pasv_range" | cut -d: -f2)
        sudo iptables -A INPUT -p tcp --dport "$min_port:$max_port" -j ACCEPT
        print_success "Firewall ports opened (iptables)"
        print_warn "Note: iptables rules are not persistent. Use iptables-save to persist."
    else
        print_warn "No active firewall detected (ufw/iptables)"
        print_info "Ports should already be accessible"
    fi
}

# Close firewall ports for FTP
close_firewall() {
    check_sudo

    local ftp_port=$(get_config_value "listen_port" "21")
    local pasv_range=$(get_passive_ports)

    print_info "Closing FTP ports..."

    if is_ufw_active; then
        sudo ufw delete allow "$ftp_port/tcp" 2>/dev/null || true
        sudo ufw delete allow "$pasv_range/tcp" 2>/dev/null || true
        print_success "Firewall ports closed (ufw)"
    elif is_iptables_active; then
        sudo iptables -D INPUT -p tcp --dport "$ftp_port" -j ACCEPT 2>/dev/null || true
        local min_port=$(echo "$pasv_range" | cut -d: -f1)
        local max_port=$(echo "$pasv_range" | cut -d: -f2)
        sudo iptables -D INPUT -p tcp --dport "$min_port:$max_port" -j ACCEPT 2>/dev/null || true
        print_success "Firewall ports closed (iptables)"
    else
        print_warn "No active firewall detected"
    fi
}

# Show firewall status for FTP ports
show_firewall_status() {
    print_header "Firewall Status"

    local ftp_port=$(get_config_value "listen_port" "21")
    local pasv_range=$(get_passive_ports)

    echo -e "  ${BOLD}FTP Port:${NC}      $ftp_port/tcp"
    echo -e "  ${BOLD}Passive Ports:${NC} $pasv_range/tcp"
    echo

    if is_ufw_active; then
        echo -e "  ${BOLD}Firewall:${NC} ${GREEN}ufw (active)${NC}"
        echo
        echo -e "  ${BOLD}FTP-related rules:${NC}"
        sudo ufw status | grep -E "(${ftp_port}|4[0-9]{4})" | while read -r line; do
            echo "    $line"
        done
        if ! sudo ufw status | grep -qE "(${ftp_port}|4[0-9]{4})"; then
            echo -e "    ${YELLOW}No FTP rules found - run 'open-firewall'${NC}"
        fi
    elif is_iptables_active; then
        echo -e "  ${BOLD}Firewall:${NC} ${GREEN}iptables (active)${NC}"
        echo
        echo -e "  ${BOLD}Relevant rules:${NC}"
        sudo iptables -L INPUT -n --line-numbers | grep -E "(dpt:${ftp_port}|dpts:)" | while read -r line; do
            echo "    $line"
        done
    else
        echo -e "  ${BOLD}Firewall:${NC} ${YELLOW}Not detected/inactive${NC}"
        echo -e "  ${GREEN}Ports should be accessible${NC}"
    fi
}

# Test FTP connectivity
test_ftp() {
    print_header "FTP Connection Test"

    if ! is_vsftpd_installed; then
        print_error "vsftpd is not installed"
        exit 1
    fi

    if ! is_vsftpd_running; then
        print_error "FTP server is not running"
        exit 1
    fi

    local ftp_port=$(get_config_value "listen_port" "21")
    local ftp_root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
    local upload_enabled=$(get_config_value "anon_upload_enable" "NO")

    # Test 1: Basic connection
    print_info "Test 1: Basic connection..."
    if echo -e "USER anonymous\nQUIT" | nc -w 5 localhost "$ftp_port" 2>/dev/null | grep -q "220"; then
        print_success "Basic connection: OK"
    else
        print_error "Basic connection: FAILED"
        return 1
    fi

    # Test 2: Anonymous login
    print_info "Test 2: Anonymous login..."
    local login_result=$(echo -e "USER anonymous\nPASS test@test.com\nPWD\nQUIT" | nc -w 5 localhost "$ftp_port" 2>&1)
    if echo "$login_result" | grep -q "230"; then
        print_success "Anonymous login: OK"
    else
        print_error "Anonymous login: FAILED"
        echo "$login_result"
        return 1
    fi

    # Test 3: Upload (if enabled)
    if [[ "$upload_enabled" == "YES" ]]; then
        print_info "Test 3: Upload test..."
        local test_file="/tmp/ftp_test_$$"
        echo "FTP upload test $(date)" > "$test_file"

        if curl -s -T "$test_file" "ftp://anonymous:@localhost:${ftp_port}/uploads/test_upload_$$.txt" 2>/dev/null; then
            if [[ -f "${ftp_root}/uploads/test_upload_$$.txt" ]]; then
                print_success "Upload test: OK"
                rm -f "${ftp_root}/uploads/test_upload_$$.txt" 2>/dev/null
            else
                print_error "Upload test: FAILED (file not created)"
            fi
        else
            print_error "Upload test: FAILED"
        fi
        rm -f "$test_file"
    else
        print_info "Test 3: Upload test skipped (uploads disabled)"
    fi

    echo
    print_success "FTP server is working correctly"

    # Show connection info
    echo
    echo -e "${BOLD}Connect from other machines:${NC}"
    local ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -3)
    if [[ -n "$ips" ]]; then
        while read -r ip; do
            echo -e "  ${CYAN}ftp://${ip}:${ftp_port}${NC}"
        done <<< "$ips"
    fi
}

# Full diagnostic check
run_diagnostics() {
    print_header "FTP Server Diagnostics"

    local issues=0

    # Check 1: Installation
    echo -e "${BOLD}[1/8] Installation${NC}"
    if is_vsftpd_installed; then
        print_success "vsftpd is installed"
    else
        print_error "vsftpd is NOT installed"
        ((issues++))
    fi

    # Check 2: Service status
    echo -e "\n${BOLD}[2/8] Service Status${NC}"
    if is_vsftpd_running; then
        print_success "vsftpd is running"
    else
        print_error "vsftpd is NOT running"
        ((issues++))
    fi

    # Check 3: Configuration file
    echo -e "\n${BOLD}[3/8] Configuration${NC}"
    if [[ -f "$VSFTPD_CONF" ]]; then
        print_success "Config file exists: $VSFTPD_CONF"
        local anon=$(get_config_value "anonymous_enable" "NO")
        if [[ "$anon" == "YES" ]]; then
            print_success "Anonymous access: enabled"
        else
            print_warn "Anonymous access: disabled"
        fi
    else
        print_error "Config file missing!"
        ((issues++))
    fi

    # Check 4: FTP root directory
    echo -e "\n${BOLD}[4/8] FTP Root Directory${NC}"
    local ftp_root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
    if [[ -d "$ftp_root" ]]; then
        print_success "FTP root exists: $ftp_root"
        local perms=$(stat -c "%a" "$ftp_root")
        echo -e "  Permissions: $perms"
    else
        print_error "FTP root does NOT exist: $ftp_root"
        ((issues++))
    fi

    # Check 5: Uploads directory
    echo -e "\n${BOLD}[5/8] Uploads Directory${NC}"
    local uploads_dir="${ftp_root}/uploads"
    local upload_enabled=$(get_config_value "anon_upload_enable" "NO")
    if [[ "$upload_enabled" == "YES" ]]; then
        if [[ -d "$uploads_dir" ]]; then
            print_success "Uploads dir exists: $uploads_dir"
            local perms=$(stat -c "%a" "$uploads_dir")
            local owner=$(stat -c "%U:%G" "$uploads_dir")
            echo -e "  Permissions: $perms (need 777)"
            echo -e "  Owner: $owner (need ftp:ftp)"
            if [[ "$perms" != "777" ]]; then
                print_warn "Uploads dir should be 777"
                ((issues++))
            fi
        else
            print_error "Uploads dir missing (run enable-uploads)"
            ((issues++))
        fi
    else
        print_info "Uploads disabled (read-only mode)"
    fi

    # Check 6: Passive mode
    echo -e "\n${BOLD}[6/8] Passive Mode${NC}"
    local pasv=$(get_config_value "pasv_enable" "NO")
    local pasv_addr=$(get_config_value "pasv_address" "")
    local pasv_min=$(get_config_value "pasv_min_port" "")
    local pasv_max=$(get_config_value "pasv_max_port" "")
    if [[ "$pasv" == "YES" ]]; then
        print_success "Passive mode: enabled"
        echo -e "  Port range: ${pasv_min:-not set}-${pasv_max:-not set}"
        if [[ -n "$pasv_addr" ]]; then
            echo -e "  Address: $pasv_addr"
        else
            print_warn "pasv_address not set (may cause issues with remote clients)"
            ((issues++))
        fi
    else
        print_warn "Passive mode: disabled (may cause issues)"
        ((issues++))
    fi

    # Check 7: Port listening
    echo -e "\n${BOLD}[7/8] Port Status${NC}"
    local ftp_port=$(get_config_value "listen_port" "21")
    if ss -tlnp 2>/dev/null | grep -q ":${ftp_port} " || netstat -tlnp 2>/dev/null | grep -q ":${ftp_port} "; then
        print_success "Listening on port $ftp_port"
    else
        if is_vsftpd_running; then
            print_warn "Port $ftp_port status unclear"
        else
            print_error "Not listening (server stopped)"
            ((issues++))
        fi
    fi

    # Check 8: Firewall
    echo -e "\n${BOLD}[8/8] Firewall${NC}"
    if is_ufw_active; then
        echo -e "  Firewall: ufw (active)"
        if sudo ufw status | grep -qE "${ftp_port}/tcp.*ALLOW"; then
            print_success "FTP port allowed in firewall"
        else
            print_warn "FTP port may be blocked - run 'open-firewall'"
            ((issues++))
        fi
    elif is_iptables_active; then
        echo -e "  Firewall: iptables (active)"
        print_info "Check iptables rules manually"
    else
        print_success "No firewall detected"
    fi

    # Summary
    echo
    draw_line 60
    if [[ $issues -eq 0 ]]; then
        print_success "All checks passed!"
    else
        print_warn "Found $issues issue(s) - see above"
    fi
}

# ============================================================================
# INTERACTIVE MODE
# ============================================================================

# Current view state
CURRENT_VIEW="status"
STATUS_MESSAGE=""
LOG_LINES=()

# Clear screen and move cursor to top
clear_screen() {
    printf '\033[2J\033[H'
}

# Draw a horizontal line
draw_line() {
    local width=${1:-$(tput cols)}
    printf '%*s\n' "$width" '' | tr ' ' '-'
}

# Get terminal dimensions
get_term_size() {
    TERM_ROWS=$(tput lines)
    TERM_COLS=$(tput cols)
}

# Draw the header bar
draw_header() {
    local installed="No"
    local running="Stopped"
    local port=$(get_config_value "listen_port" "21")

    if is_vsftpd_installed; then
        installed="Yes"
    fi

    if is_vsftpd_running; then
        running="${GREEN}Running${NC}"
    else
        running="${RED}Stopped${NC}"
    fi

    echo -e "${BOLD}${CYAN}+------------------------------------------------------------------------------+${NC}"
    echo -e "${BOLD}${CYAN}|${NC}                          ${BOLD}FTP Manager - Interactive${NC}                          ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}+------------------------------------------------------------------------------+${NC}"
    printf "${BOLD}${CYAN}|${NC}  Installed: %-5s  |  Status: %-18b  |  Port: %-5s               ${BOLD}${CYAN}|${NC}\n" "$installed" "$running" "$port"
    echo -e "${BOLD}${CYAN}+------------------------------------------------------------------------------+${NC}"
}

# Draw view tabs
draw_tabs() {
    local tabs=("Status" "Config" "Logs" "Tools")
    local keys=("1" "2" "3" "4")

    echo -en "  "
    for i in "${!tabs[@]}"; do
        local tab="${tabs[$i]}"
        local key="${keys[$i]}"
        local lower_tab=$(echo "$tab" | tr '[:upper:]' '[:lower:]')

        if [[ "$lower_tab" == "$CURRENT_VIEW" ]]; then
            echo -en "${BOLD}${CYAN}[${key}] ${tab}${NC}  "
        else
            echo -en "${BOLD}[${key}]${NC} ${tab}  "
        fi
    done
    echo
    draw_line 80
}

# Draw status view
draw_status_view() {
    echo

    if ! is_vsftpd_installed; then
        echo -e "  ${YELLOW}vsftpd is not installed${NC}"
        echo
        echo -e "  Press ${BOLD}[I]${NC} to install vsftpd"
        return
    fi

    local port=$(get_config_value "listen_port" "21")
    local root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
    local anon=$(get_config_value "anonymous_enable" "NO")
    local upload=$(get_config_value "anon_upload_enable" "NO")

    printf "  ${BOLD}%-20s${NC} %s\n" "FTP Root:" "$root"
    printf "  ${BOLD}%-20s${NC} %s\n" "Port:" "$port"
    printf "  ${BOLD}%-20s${NC} %s\n" "Anonymous Access:" "$anon"
    if [[ "$upload" == "YES" ]]; then
        printf "  ${BOLD}%-20s${NC} ${GREEN}Enabled${NC} (${root}/uploads)\n" "Uploads:"
    else
        printf "  ${BOLD}%-20s${NC} ${YELLOW}Disabled${NC} (read-only)\n" "Uploads:"
    fi

    echo
    echo -e "  ${BOLD}Connection URLs:${NC}"

    local ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3)
    if [[ -n "$ips" ]]; then
        while read -r ip; do
            echo -e "    ${CYAN}ftp://${ip}:${port}${NC}"
        done <<< "$ips"
    else
        echo -e "    ${CYAN}ftp://localhost:${port}${NC}"
    fi

    echo
    if [[ -d "$root" ]]; then
        echo -e "  ${BOLD}Root Directory Contents:${NC}"
        ls -la "$root" 2>/dev/null | head -10 | while read -r line; do
            echo "    $line"
        done
    else
        echo -e "  ${YELLOW}Root directory does not exist: $root${NC}"
    fi
}

# Draw config view
draw_config_view() {
    echo

    if [[ ! -f "$VSFTPD_CONF" ]]; then
        echo -e "  ${YELLOW}Configuration file not found${NC}"
        return
    fi

    echo -e "  ${BOLD}Current Configuration:${NC} $VSFTPD_CONF"
    echo

    local count=0
    grep -v '^#' "$VSFTPD_CONF" 2>/dev/null | grep -v '^$' | while read -r line; do
        local key=$(echo "$line" | cut -d'=' -f1)
        local value=$(echo "$line" | cut -d'=' -f2-)
        printf "  %-25s = %s\n" "$key" "$value"
        ((count++))
        if [[ $count -ge 20 ]]; then
            echo "  ..."
            break
        fi
    done
}

# Draw logs view
draw_logs_view() {
    echo
    echo -e "  ${BOLD}Recent Logs:${NC}"
    echo

    if command -v journalctl &> /dev/null; then
        sudo journalctl -u vsftpd --no-pager -n 15 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    else
        if [[ -f /var/log/vsftpd.log ]]; then
            tail -15 /var/log/vsftpd.log 2>/dev/null | while read -r line; do
                echo "  $line"
            done
        else
            echo -e "  ${YELLOW}No logs available${NC}"
        fi
    fi
}

# Draw tools view
draw_tools_view() {
    echo
    echo -e "  ${BOLD}Quick Actions:${NC}"
    echo -e "    ${CYAN}[T]${NC} Run connection test"
    echo -e "    ${CYAN}[D]${NC} Run full diagnostics"
    echo
    echo -e "  ${BOLD}Firewall:${NC}"

    local ftp_port=$(get_config_value "listen_port" "21")
    local pasv_range=$(get_passive_ports)

    if is_ufw_active 2>/dev/null; then
        echo -e "    Status: ${GREEN}ufw active${NC}"
        if sudo ufw status 2>/dev/null | grep -qE "${ftp_port}/tcp.*ALLOW"; then
            echo -e "    FTP ports: ${GREEN}Open${NC}"
        else
            echo -e "    FTP ports: ${YELLOW}Possibly blocked${NC}"
        fi
    else
        echo -e "    Status: ${YELLOW}No firewall detected${NC}"
    fi

    echo -e "    ${CYAN}[F]${NC} Open firewall ports"
    echo -e "    ${CYAN}[X]${NC} Close firewall ports"
    echo
    echo -e "  ${BOLD}Network Info:${NC}"
    echo -e "    FTP Port: $ftp_port"
    echo -e "    Passive Ports: $pasv_range"
    echo
    echo -e "  ${BOLD}Server IPs:${NC}"
    hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -4 | while read -r ip; do
        echo -e "    ${CYAN}$ip${NC}"
    done
}

# Draw the content based on current view
draw_content() {
    case "$CURRENT_VIEW" in
        status)
            draw_status_view
            ;;
        config)
            draw_config_view
            ;;
        logs)
            draw_logs_view
            ;;
        tools)
            draw_tools_view
            ;;
    esac
}

# Draw context menu
draw_menu() {
    echo
    draw_line 80

    if is_vsftpd_installed; then
        case "$CURRENT_VIEW" in
            status)
                if is_vsftpd_running; then
                    echo -e "  ${BOLD}Service:${NC} s[T]op  [R]estart"
                else
                    echo -e "  ${BOLD}Service:${NC} [S]tart"
                fi
                echo -e "  ${BOLD}Config:${NC}  [W] enable-uploads  [O] disable-uploads  [P] set-port"
                ;;
            config)
                echo -e "  ${BOLD}Setup:${NC}  [C]onfigure (reset config)  set-[D]ir  [P] set-port"
                echo -e "  ${BOLD}Write:${NC}  [W] enable-uploads  [O] disable-uploads"
                ;;
            logs)
                echo -e "  ${BOLD}Logs:${NC}   [L] refresh logs"
                ;;
            tools)
                echo -e "  ${BOLD}Test:${NC}   [T] connection test  [D] full diagnostics"
                echo -e "  ${BOLD}Fire:${NC}   [F] open firewall  [X] close firewall"
                ;;
        esac
        echo -e "  ${BOLD}Manage:${NC} [U]ninstall"
    else
        echo -e "  ${BOLD}Actions:${NC} [I]nstall vsftpd"
    fi

    echo -e "  ${BOLD}Nav:${NC}     [1] Status  [2] Config  [3] Logs  [4] Tools  [Q]uit"
    draw_line 80

    # Status message
    if [[ -n "$STATUS_MESSAGE" ]]; then
        echo -e "  ${STATUS_MESSAGE}"
    else
        echo -e "  ${CYAN}Ready${NC}"
    fi
}

# Pause and wait for keypress
pause_for_input() {
    echo
    echo -en "  ${YELLOW}Press any key to continue...${NC}"
    read -rsn1
}

# Prompt for directory
prompt_for_directory() {
    echo
    local current_root=$(get_config_value "anon_root" "$DEFAULT_FTP_ROOT")
    echo -en "  ${YELLOW}Enter new FTP root directory [${current_root}]: ${NC}"
    read -r new_dir

    if [[ -z "$new_dir" ]]; then
        STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
        return
    fi

    # Convert to absolute path
    new_dir=$(realpath -m "$new_dir")

    # Check/create directory
    if [[ ! -d "$new_dir" ]]; then
        echo -en "  ${YELLOW}Directory does not exist. Create it? [y/N]: ${NC}"
        read -rsn1 create_confirm
        echo
        if [[ "$create_confirm" =~ ^[Yy]$ ]]; then
            sudo mkdir -p "$new_dir" 2>/dev/null
            sudo chmod 755 "$new_dir" 2>/dev/null
            if [[ ! -d "$new_dir" ]]; then
                STATUS_MESSAGE="${RED}Failed to create directory${NC}"
                return
            fi
        else
            STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            return
        fi
    fi

    set_config_value "anon_root" "$new_dir"

    if is_vsftpd_running; then
        sudo systemctl restart vsftpd 2>/dev/null
    fi

    STATUS_MESSAGE="${GREEN}FTP root set to: $new_dir${NC}"
}

# Handle actions
handle_action() {
    local action="$1"

    case "$action" in
        install)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Installing vsftpd ===${NC}"
            echo
            install_vsftpd
            pause_for_input
            ;;
        uninstall)
            echo -en "  ${RED}Uninstall vsftpd? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                SKIP_CONFIRM=true
                clear_screen
                echo -e "${BOLD}${CYAN}=== Uninstalling vsftpd ===${NC}"
                echo
                uninstall_vsftpd
                pause_for_input
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        start)
            if is_vsftpd_running; then
                STATUS_MESSAGE="${YELLOW}Already running${NC}"
            else
                sudo systemctl start vsftpd 2>/dev/null
                if is_vsftpd_running; then
                    STATUS_MESSAGE="${GREEN}FTP server started${NC}"
                else
                    STATUS_MESSAGE="${RED}Failed to start${NC}"
                fi
            fi
            ;;
        stop)
            if ! is_vsftpd_running; then
                STATUS_MESSAGE="${YELLOW}Already stopped${NC}"
            else
                sudo systemctl stop vsftpd 2>/dev/null
                STATUS_MESSAGE="${GREEN}FTP server stopped${NC}"
            fi
            ;;
        restart)
            sudo systemctl restart vsftpd 2>/dev/null
            if is_vsftpd_running; then
                STATUS_MESSAGE="${GREEN}FTP server restarted${NC}"
            else
                STATUS_MESSAGE="${RED}Failed to restart${NC}"
            fi
            ;;
        setdir)
            prompt_for_directory
            ;;
        configure)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Configuring vsftpd for Anonymous Access ===${NC}"
            echo
            SKIP_CONFIRM=true
            setup_vsftpd
            pause_for_input
            ;;
        enable-uploads)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Enabling Uploads ===${NC}"
            echo
            enable_uploads
            pause_for_input
            ;;
        disable-uploads)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Disabling Uploads ===${NC}"
            echo
            disable_uploads
            pause_for_input
            ;;
        set-port)
            echo
            local current_port=$(get_config_value "listen_port" "21")
            echo -en "  ${YELLOW}Enter new FTP port [${current_port}]: ${NC}"
            read -r new_port
            if [[ -n "$new_port" ]]; then
                clear_screen
                echo -e "${BOLD}${CYAN}=== Setting FTP Port ===${NC}"
                echo
                set_ftp_port "$new_port"
                pause_for_input
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        open-firewall)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Opening Firewall Ports ===${NC}"
            echo
            open_firewall
            pause_for_input
            ;;
        close-firewall)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Closing Firewall Ports ===${NC}"
            echo
            close_firewall
            pause_for_input
            ;;
        test)
            clear_screen
            test_ftp
            pause_for_input
            ;;
        diagnose)
            clear_screen
            run_diagnostics
            pause_for_input
            ;;
    esac
}

# Main interactive loop
run_interactive() {
    # Disable exit-on-error for interactive mode
    set +e

    # Hide cursor
    printf '\033[?25l'

    # Restore cursor on exit
    trap 'printf "\033[?25h"; clear_screen; exit 0' EXIT INT TERM

    while true; do
        get_term_size
        clear_screen
        draw_header
        echo
        draw_tabs
        draw_content
        draw_menu

        # Read single keypress
        read -rsn1 key

        # Handle escape sequences (arrow keys)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn1 seq1
            read -rsn1 seq2
            key='IGNORE'
        fi

        STATUS_MESSAGE=""

        case "$key" in
            IGNORE)
                continue
                ;;

            # View switching
            1)
                CURRENT_VIEW="status"
                ;;
            2)
                CURRENT_VIEW="config"
                ;;
            3)
                CURRENT_VIEW="logs"
                ;;
            4)
                CURRENT_VIEW="tools"
                ;;

            # Actions
            i|I)
                if ! is_vsftpd_installed; then
                    handle_action "install"
                fi
                ;;
            u|U)
                if is_vsftpd_installed; then
                    handle_action "uninstall"
                fi
                ;;
            s|S)
                if is_vsftpd_installed && ! is_vsftpd_running; then
                    handle_action "start"
                fi
                ;;
            t|T)
                if is_vsftpd_installed; then
                    if [[ "$CURRENT_VIEW" == "tools" ]]; then
                        handle_action "test"
                    elif is_vsftpd_running; then
                        handle_action "stop"
                    fi
                fi
                ;;
            r|R)
                if is_vsftpd_installed; then
                    handle_action "restart"
                fi
                ;;
            d|D)
                if is_vsftpd_installed; then
                    if [[ "$CURRENT_VIEW" == "tools" ]]; then
                        handle_action "diagnose"
                    else
                        handle_action "setdir"
                    fi
                fi
                ;;
            c|C)
                if is_vsftpd_installed; then
                    handle_action "configure"
                fi
                ;;
            w|W)
                if is_vsftpd_installed; then
                    handle_action "enable-uploads"
                fi
                ;;
            o|O)
                if is_vsftpd_installed; then
                    handle_action "disable-uploads"
                fi
                ;;
            p|P)
                if is_vsftpd_installed; then
                    handle_action "set-port"
                fi
                ;;
            l|L)
                # Refresh (just redraw)
                STATUS_MESSAGE="${GREEN}Refreshed${NC}"
                ;;
            f|F)
                if is_vsftpd_installed; then
                    handle_action "open-firewall"
                fi
                ;;
            x|X)
                if is_vsftpd_installed; then
                    handle_action "close-firewall"
                fi
                ;;

            # Quit
            q|Q)
                break
                ;;
        esac
    done
}

# ============================================================================
# MAIN
# ============================================================================

# Parse global flags
SKIP_CONFIRM=false
ARGS=()

for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            SKIP_CONFIRM=true
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# Get command
COMMAND="${ARGS[0]:-}"
ARG="${ARGS[1]:-}"

case "$COMMAND" in
    # Help
    ""|help|-h|--help)
        show_usage
        ;;

    # Interactive mode
    interactive|-i)
        run_interactive
        ;;

    # Setup commands
    install)
        install_vsftpd
        ;;
    setup)
        setup_vsftpd "$ARG"
        ;;
    uninstall)
        uninstall_vsftpd
        ;;

    # Service commands
    start)
        start_ftp
        ;;
    stop)
        stop_ftp
        ;;
    restart)
        restart_ftp
        ;;
    status)
        show_status
        ;;

    # Configuration commands
    set-root)
        set_root_dir "$ARG"
        ;;
    enable-uploads)
        enable_uploads
        ;;
    disable-uploads)
        disable_uploads
        ;;
    config)
        show_config
        ;;
    logs)
        show_logs
        ;;

    # Port configuration
    set-port)
        set_ftp_port "$ARG"
        ;;

    # Firewall commands
    open-firewall)
        open_firewall
        ;;
    close-firewall)
        close_firewall
        ;;
    firewall-status)
        show_firewall_status
        ;;

    # Diagnostics
    test)
        test_ftp
        ;;
    diagnose)
        run_diagnostics
        ;;

    *)
        print_error "Unknown command: $COMMAND"
        echo "Run '$(basename "$0") --help' for usage"
        exit 1
        ;;
esac
