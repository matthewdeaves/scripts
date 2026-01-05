#!/bin/bash
set -e

# Docker Management Script
# Comprehensive tool for managing Docker containers, images, volumes, and networks

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running or you don't have permission"
        print_info "Try: sudo systemctl start docker"
        print_info "Or add yourself to docker group: sudo usermod -aG docker \$USER"
        exit 1
    fi
}

# Show usage/help
show_usage() {
    local script_name
    script_name=$(basename "$0")

    echo -e "${BOLD}Docker Management Script${NC}"
    echo
    echo -e "${BOLD}Usage:${NC} $script_name <command> [options]"
    echo
    echo -e "${BOLD}Container Commands:${NC}"
    echo "  list, ls              List all containers with status"
    echo "  stop-all              Stop all running containers"
    echo "  start <id|name>       Start a container"
    echo "  stop <id|name>        Stop a container"
    echo "  restart <id|name>     Restart a container"
    echo "  logs <id|name>        Show container logs (use -f to follow)"
    echo "  shell <id|name>       Open shell in container"
    echo "  inspect <id|name>     Show container details"
    echo "  rm <id|name>          Remove a container"
    echo "  rm-all                Remove all stopped containers"
    echo
    echo -e "${BOLD}Image Commands:${NC}"
    echo "  images                List all images"
    echo "  rmi <id|name>         Remove an image"
    echo "  rmi-all               Remove all images (forces removal of unused)"
    echo "  rmi-dangling          Remove dangling images"
    echo
    echo -e "${BOLD}Volume Commands:${NC}"
    echo "  volumes               List all volumes"
    echo "  rmv <name>            Remove a volume"
    echo "  rmv-all               Remove all unused volumes"
    echo "  rmv-force             Remove ALL volumes (dangerous!)"
    echo
    echo -e "${BOLD}Network Commands:${NC}"
    echo "  networks              List all networks"
    echo "  rmn <name>            Remove a network"
    echo "  rmn-all               Remove all custom networks"
    echo
    echo -e "${BOLD}Cleanup Commands:${NC}"
    echo "  prune                 Remove unused containers, networks, images"
    echo -e "  nuke                  ${RED}DANGER:${NC} Complete Docker reset (removes EVERYTHING)"
    echo "  destroy <id|name>     Remove container and its volumes"
    echo
    echo -e "${BOLD}Info Commands:${NC}"
    echo "  stats                 Show live resource usage"
    echo "  disk                  Show Docker disk usage"
    echo "  info                  Show Docker system info"
    echo
    echo -e "${BOLD}Interactive Mode:${NC}"
    echo "  interactive, -i       Launch interactive TUI mode"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  -h, --help, help      Show this help message"
    echo "  -y, --yes             Skip confirmation prompts"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  $script_name -i                    # Interactive mode"
    echo "  $script_name list"
    echo "  $script_name stop-all"
    echo "  $script_name logs mycontainer -f"
    echo "  $script_name destroy mycontainer"
    echo "  $script_name nuke -y"
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

# List containers with nice formatting
list_containers() {
    print_header "Docker Containers"

    local running=$(docker ps -q | wc -l)
    local total=$(docker ps -aq | wc -l)

    echo -e "${BOLD}Summary:${NC} $running running / $total total\n"

    if [[ $total -eq 0 ]]; then
        print_info "No containers found"
        return
    fi

    docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | \
        sed '1s/.*/\x1b[1m&\x1b[0m/'
}

# Stop all running containers
stop_all_containers() {
    local containers=$(docker ps -q)

    if [[ -z "$containers" ]]; then
        print_info "No running containers to stop"
        return
    fi

    local count=$(echo "$containers" | wc -l)
    print_warn "This will stop $count running container(s)"

    if confirm "Continue?"; then
        print_info "Stopping all containers..."
        docker stop $containers
        print_success "All containers stopped"
    fi
}

# Remove all stopped containers
remove_all_containers() {
    local containers=$(docker ps -aq)

    if [[ -z "$containers" ]]; then
        print_info "No containers to remove"
        return
    fi

    local count=$(echo "$containers" | wc -l)
    print_warn "This will remove $count container(s)"

    if confirm "Continue?"; then
        # Stop running containers first
        local running=$(docker ps -q)
        if [[ -n "$running" ]]; then
            print_info "Stopping running containers first..."
            docker stop $running
        fi

        print_info "Removing all containers..."
        docker rm $containers
        print_success "All containers removed"
    fi
}

# List images
list_images() {
    print_header "Docker Images"

    local count=$(docker images -q | wc -l)
    local dangling=$(docker images -f "dangling=true" -q | wc -l)

    echo -e "${BOLD}Summary:${NC} $count total / $dangling dangling\n"

    if [[ $count -eq 0 ]]; then
        print_info "No images found"
        return
    fi

    docker images --format "table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | \
        sed '1s/.*/\x1b[1m&\x1b[0m/'
}

# Remove all images
remove_all_images() {
    local images=$(docker images -q)

    if [[ -z "$images" ]]; then
        print_info "No images to remove"
        return
    fi

    local count=$(echo "$images" | wc -l)
    print_warn "This will remove $count image(s)"

    if confirm "Continue?"; then
        print_info "Removing all images..."
        docker rmi -f $images 2>/dev/null || true
        print_success "All images removed"
    fi
}

# Remove dangling images
remove_dangling_images() {
    local images=$(docker images -f "dangling=true" -q)

    if [[ -z "$images" ]]; then
        print_info "No dangling images to remove"
        return
    fi

    local count=$(echo "$images" | wc -l)
    print_info "Removing $count dangling image(s)..."
    docker rmi $images
    print_success "Dangling images removed"
}

# Build volume usage map (volume -> container,image)
# Sets global associative arrays VOLUME_CONTAINERS and VOLUME_IMAGES
declare -A VOLUME_CONTAINERS
declare -A VOLUME_IMAGES

build_volume_map() {
    VOLUME_CONTAINERS=()
    VOLUME_IMAGES=()

    # Get all container info in one pass
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local container_name=$(echo "$line" | cut -d'|' -f1)
        local container_image=$(echo "$line" | cut -d'|' -f2)
        local mounts=$(echo "$line" | cut -d'|' -f3-)

        # Parse each volume mount
        for vol in $mounts; do
            [[ -z "$vol" ]] && continue
            if [[ -n "${VOLUME_CONTAINERS[$vol]}" ]]; then
                VOLUME_CONTAINERS[$vol]="${VOLUME_CONTAINERS[$vol]}, $container_name"
            else
                VOLUME_CONTAINERS[$vol]="$container_name"
                VOLUME_IMAGES[$vol]="$container_image"
            fi
        done
    done < <(docker ps -a --format '{{.Names}}|{{.Image}}|{{range .Mounts}}{{.Name}} {{end}}' 2>/dev/null)
}

# Get containers using a volume (uses cached map)
get_volume_usage() {
    local volume_name="$1"
    echo "${VOLUME_CONTAINERS[$volume_name]:-}"
}

# Get image that created a volume (uses cached map)
get_volume_image() {
    local volume_name="$1"
    echo "${VOLUME_IMAGES[$volume_name]:-}"
}

# List volumes
list_volumes() {
    print_header "Docker Volumes"

    local count=$(docker volume ls -q | wc -l)
    local unused=$(docker volume ls -qf dangling=true | wc -l)
    echo -e "${BOLD}Summary:${NC} $count total / $unused unused\n"

    if [[ $count -eq 0 ]]; then
        print_info "No volumes found"
        return
    fi

    # Build volume usage map (single pass through containers)
    build_volume_map

    # Print header
    printf "${BOLD}%-35s %-10s %-25s %-30s${NC}\n" "NAME" "DRIVER" "USED BY" "IMAGE"
    echo "-----------------------------------------------------------------------------------------------------"

    # List each volume with usage info
    while IFS= read -r volume_name; do
        [[ -z "$volume_name" ]] && continue

        local driver=$(docker volume inspect "$volume_name" --format '{{.Driver}}' 2>/dev/null)
        local containers=$(get_volume_usage "$volume_name")
        local image=$(get_volume_image "$volume_name")

        # Truncate long names
        local display_name="${volume_name:0:33}"
        local display_containers="${containers:0:23}"
        local display_image="${image:0:28}"

        # Color unused volumes yellow
        if [[ -z "$containers" ]]; then
            printf "${YELLOW}%-35s${NC} %-10s ${YELLOW}%-25s${NC} %-30s\n" \
                "$display_name" "$driver" "(unused)" "$display_image"
        else
            printf "%-35s %-10s ${GREEN}%-25s${NC} %-30s\n" \
                "$display_name" "$driver" "$display_containers" "$display_image"
        fi
    done < <(docker volume ls -q 2>/dev/null)
}

# Remove all unused volumes
remove_unused_volumes() {
    print_warn "This will remove all unused volumes"

    if confirm "Continue?"; then
        print_info "Removing unused volumes..."
        docker volume prune -f
        print_success "Unused volumes removed"
    fi
}

# Remove ALL volumes (force)
remove_all_volumes() {
    local volumes=$(docker volume ls -q)

    if [[ -z "$volumes" ]]; then
        print_info "No volumes to remove"
        return
    fi

    local count=$(echo "$volumes" | wc -l)
    print_error "WARNING: This will forcefully remove ALL $count volume(s)!"
    print_error "This may cause data loss!"

    if confirm "Are you absolutely sure?"; then
        print_info "Removing all volumes..."
        docker volume rm -f $volumes 2>/dev/null || true
        print_success "All volumes removed"
    fi
}

# List networks
list_networks() {
    print_header "Docker Networks"

    local count=$(docker network ls -q | wc -l)
    echo -e "${BOLD}Summary:${NC} $count total\n"

    docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}" | \
        sed '1s/.*/\x1b[1m&\x1b[0m/'
}

# Remove all custom networks
remove_all_networks() {
    # Get networks excluding default ones
    local networks=$(docker network ls --format '{{.Name}}' | grep -vE '^(bridge|host|none)$')

    if [[ -z "$networks" ]]; then
        print_info "No custom networks to remove"
        return
    fi

    local count=$(echo "$networks" | wc -l)
    print_warn "This will remove $count custom network(s)"

    if confirm "Continue?"; then
        print_info "Removing custom networks..."
        echo "$networks" | xargs -r docker network rm 2>/dev/null || true
        print_success "Custom networks removed"
    fi
}

# Docker prune (cleanup unused resources)
docker_prune() {
    print_warn "This will remove:"
    echo "  - All stopped containers"
    echo "  - All unused networks"
    echo "  - All dangling images"
    echo "  - All build cache"

    if confirm "Continue?"; then
        print_info "Pruning Docker system..."
        docker system prune -f
        print_success "Docker system pruned"
    fi
}

# Nuclear option - remove everything
docker_nuke() {
    print_header "NUCLEAR OPTION"
    print_error "WARNING: This will completely reset Docker!"
    print_error "ALL containers, images, volumes, and networks will be DELETED!"
    echo

    if confirm "Are you absolutely sure you want to NUKE everything?"; then
        echo
        if confirm "FINAL WARNING: This cannot be undone. Continue?"; then
            echo

            # Stop all containers
            local running=$(docker ps -q)
            if [[ -n "$running" ]]; then
                print_info "Stopping all containers..."
                docker stop $running 2>/dev/null || true
            fi

            # Remove all containers
            local containers=$(docker ps -aq)
            if [[ -n "$containers" ]]; then
                print_info "Removing all containers..."
                docker rm -f $containers 2>/dev/null || true
            fi

            # Remove all volumes
            local volumes=$(docker volume ls -q)
            if [[ -n "$volumes" ]]; then
                print_info "Removing all volumes..."
                docker volume rm -f $volumes 2>/dev/null || true
            fi

            # Remove all networks
            local networks=$(docker network ls --format '{{.Name}}' | grep -vE '^(bridge|host|none)$')
            if [[ -n "$networks" ]]; then
                print_info "Removing all networks..."
                echo "$networks" | xargs -r docker network rm 2>/dev/null || true
            fi

            # Remove all images
            local images=$(docker images -q)
            if [[ -n "$images" ]]; then
                print_info "Removing all images..."
                docker rmi -f $images 2>/dev/null || true
            fi

            # Final prune
            print_info "Final cleanup..."
            docker system prune -af --volumes 2>/dev/null || true

            echo
            print_success "Docker has been completely reset"
        fi
    fi
}

# Destroy container and its volumes
destroy_container() {
    local container="$1"

    if [[ -z "$container" ]]; then
        print_error "Container name or ID required"
        exit 1
    fi

    # Check if container exists
    if ! docker inspect "$container" &>/dev/null; then
        print_error "Container '$container' not found"
        exit 1
    fi

    print_warn "This will remove container '$container' and its associated volumes"

    if confirm "Continue?"; then
        # Stop if running
        if docker ps -q --filter "name=$container" | grep -q .; then
            print_info "Stopping container..."
            docker stop "$container"
        fi

        # Remove with volumes
        print_info "Removing container and volumes..."
        docker rm -v "$container"
        print_success "Container '$container' destroyed"
    fi
}

# Show container logs
show_logs() {
    local container="$1"
    shift

    if [[ -z "$container" ]]; then
        print_error "Container name or ID required"
        exit 1
    fi

    docker logs "$container" "$@"
}

# Open shell in container
container_shell() {
    local container="$1"

    if [[ -z "$container" ]]; then
        print_error "Container name or ID required"
        exit 1
    fi

    # Try bash first, fall back to sh
    docker exec -it "$container" bash 2>/dev/null || docker exec -it "$container" sh
}

# Show disk usage
show_disk_usage() {
    print_header "Docker Disk Usage"
    docker system df -v
}

# Show stats
show_stats() {
    print_header "Container Resource Usage"
    docker stats --no-stream
}

# ============================================================================
# INTERACTIVE MODE
# ============================================================================

# Current view state
CURRENT_VIEW="containers"
SELECTED_INDEX=0
ITEMS=()
STATUS_MESSAGE=""

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
    local running=$(docker ps -q 2>/dev/null | wc -l)
    local total=$(docker ps -aq 2>/dev/null | wc -l)
    local images=$(docker images -q 2>/dev/null | wc -l)
    local volumes=$(docker volume ls -q 2>/dev/null | wc -l)

    echo -e "${BOLD}${CYAN}+------------------------------------------------------------------------------+${NC}"
    echo -e "${BOLD}${CYAN}|${NC}                         ${BOLD}Docker Manager - Interactive${NC}                         ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}+------------------------------------------------------------------------------+${NC}"
    printf "${BOLD}${CYAN}|${NC}  Containers: ${GREEN}%d${NC} running / %d total  |  Images: %d  |  Volumes: %d          ${BOLD}${CYAN}|${NC}\n" "$running" "$total" "$images" "$volumes"
    echo -e "${BOLD}${CYAN}+------------------------------------------------------------------------------+${NC}"
}

# Draw view tabs
draw_tabs() {
    local tabs=("Containers" "Images" "Volumes" "Networks")
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

# Load items for current view
load_items() {
    ITEMS=()
    case "$CURRENT_VIEW" in
        containers)
            while IFS= read -r line; do
                [[ -n "$line" ]] && ITEMS+=("$line")
            done < <(docker ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}' 2>/dev/null)
            ;;
        images)
            while IFS= read -r line; do
                [[ -n "$line" ]] && ITEMS+=("$line")
            done < <(docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}' 2>/dev/null)
            ;;
        volumes)
            # Build volume usage map first (single pass through containers)
            build_volume_map
            while IFS= read -r volume_name; do
                [[ -z "$volume_name" ]] && continue
                local driver=$(docker volume inspect "$volume_name" --format '{{.Driver}}' 2>/dev/null)
                local containers=$(get_volume_usage "$volume_name")
                local image=$(get_volume_image "$volume_name")
                [[ -z "$containers" ]] && containers="(unused)"
                ITEMS+=("$volume_name|$driver|$containers|$image")
            done < <(docker volume ls -q 2>/dev/null)
            ;;
        networks)
            while IFS= read -r line; do
                [[ -n "$line" ]] && ITEMS+=("$line")
            done < <(docker network ls --format '{{.ID}}|{{.Name}}|{{.Driver}}|{{.Scope}}' 2>/dev/null)
            ;;
    esac

    # Reset selection if out of bounds
    if [[ $SELECTED_INDEX -ge ${#ITEMS[@]} ]]; then
        SELECTED_INDEX=0
    fi
}

# Draw the item list
draw_items() {
    local max_items=$((TERM_ROWS - 15))
    local start=0
    local count=${#ITEMS[@]}

    # Header row based on view
    case "$CURRENT_VIEW" in
        containers)
            printf "  ${BOLD}%-14s %-20s %-25s %-20s${NC}\n" "ID" "NAME" "IMAGE" "STATUS"
            ;;
        images)
            printf "  ${BOLD}%-14s %-35s %-12s %-15s${NC}\n" "ID" "REPOSITORY:TAG" "SIZE" "CREATED"
            ;;
        volumes)
            printf "  ${BOLD}%-30s %-10s %-20s %-20s${NC}\n" "NAME" "DRIVER" "USED BY" "IMAGE"
            ;;
        networks)
            printf "  ${BOLD}%-14s %-25s %-15s %-15s${NC}\n" "ID" "NAME" "DRIVER" "SCOPE"
            ;;
    esac
    draw_line 80

    if [[ $count -eq 0 ]]; then
        echo
        echo -e "  ${YELLOW}No ${CURRENT_VIEW} found${NC}"
        echo
        return
    fi

    # Scroll if needed
    if [[ $SELECTED_INDEX -ge $max_items ]]; then
        start=$((SELECTED_INDEX - max_items + 1))
    fi

    for ((i = start; i < count && i < start + max_items; i++)); do
        local item="${ITEMS[$i]}"
        IFS='|' read -ra fields <<< "$item"

        local prefix="  "
        local suffix="${NC}"

        if [[ $i -eq $SELECTED_INDEX ]]; then
            prefix="${BOLD}${CYAN}► "
            suffix="${NC}"
        fi

        case "$CURRENT_VIEW" in
            containers)
                local status_color="${NC}"
                if [[ "${fields[3]}" == *"Up"* ]]; then
                    status_color="${GREEN}"
                elif [[ "${fields[3]}" == *"Exited"* ]]; then
                    status_color="${RED}"
                fi
                printf "${prefix}%-14s %-20s %-25s ${status_color}%-20s${suffix}\n" \
                    "${fields[0]:0:12}" "${fields[1]:0:18}" "${fields[2]:0:23}" "${fields[3]:0:18}"
                ;;
            images)
                printf "${prefix}%-14s %-35s %-12s %-15s${suffix}\n" \
                    "${fields[0]:0:12}" "${fields[1]:0:33}" "${fields[2]:0:10}" "${fields[3]:0:13}"
                ;;
            volumes)
                local usage_color="${NC}"
                if [[ "${fields[2]}" == "(unused)" ]]; then
                    usage_color="${YELLOW}"
                else
                    usage_color="${GREEN}"
                fi
                printf "${prefix}%-30s %-10s ${usage_color}%-20s${NC} %-20s${suffix}\n" \
                    "${fields[0]:0:28}" "${fields[1]:0:8}" "${fields[2]:0:18}" "${fields[3]:0:18}"
                ;;
            networks)
                printf "${prefix}%-14s %-25s %-15s %-15s${suffix}\n" \
                    "${fields[0]:0:12}" "${fields[1]:0:23}" "${fields[2]:0:13}" "${fields[3]:0:13}"
                ;;
        esac
    done
}

# Draw context menu based on current view
draw_menu() {
    echo
    draw_line 80

    case "$CURRENT_VIEW" in
        containers)
            echo -e "  ${BOLD}Actions:${NC} [s]tart  s[t]op  [r]estart  [l]ogs  s[h]ell  [d]elete  [D]estroy+vols"
            echo -e "  ${BOLD}Bulk:${NC}    stop-[A]ll  [R]emove-all  [X] destroy-all  [V] destroy-all+vols  [P]rune"
            ;;
        images)
            echo -e "  ${BOLD}Actions:${NC} [d]elete image"
            echo -e "  ${BOLD}Bulk:${NC}    delete-[A]ll  delete-[D]angling  [P]rune"
            ;;
        volumes)
            echo -e "  ${BOLD}Actions:${NC} [d]elete volume"
            echo -e "  ${BOLD}Bulk:${NC}    delete-[U]nused  delete-[A]ll (force)"
            ;;
        networks)
            echo -e "  ${BOLD}Actions:${NC} [d]elete network"
            echo -e "  ${BOLD}Bulk:${NC}    delete-[A]ll custom"
            ;;
    esac

    echo -e "  ${BOLD}Nav:${NC}     [↑/k] up  [↓/j] down  [1-4] switch view  [?] stats  [q]uit"
    draw_line 80

    # Status message
    if [[ -n "$STATUS_MESSAGE" ]]; then
        echo -e "  ${STATUS_MESSAGE}"
    else
        echo -e "  ${CYAN}Ready${NC}"
    fi
}

# Get the selected item's ID/name
get_selected_id() {
    if [[ ${#ITEMS[@]} -eq 0 ]]; then
        echo ""
        return
    fi
    local item="${ITEMS[$SELECTED_INDEX]}"
    IFS='|' read -ra fields <<< "$item"

    case "$CURRENT_VIEW" in
        containers|images|networks)
            echo "${fields[0]}"
            ;;
        volumes)
            echo "${fields[0]}"
            ;;
    esac
}

get_selected_name() {
    if [[ ${#ITEMS[@]} -eq 0 ]]; then
        echo ""
        return
    fi
    local item="${ITEMS[$SELECTED_INDEX]}"
    IFS='|' read -ra fields <<< "$item"

    case "$CURRENT_VIEW" in
        containers)
            echo "${fields[1]}"
            ;;
        images)
            echo "${fields[1]}"
            ;;
        volumes|networks)
            echo "${fields[0]}"
            ;;
    esac
}

# Pause and wait for keypress
pause_for_input() {
    echo
    echo -en "  ${YELLOW}Press any key to continue...${NC}"
    read -rsn1
}

# Handle container actions
handle_container_action() {
    local action="$1"
    local id=$(get_selected_id)
    local name=$(get_selected_name)

    if [[ -z "$id" ]]; then
        STATUS_MESSAGE="${RED}No container selected${NC}"
        return
    fi

    case "$action" in
        start)
            if docker start "$id" &>/dev/null; then
                STATUS_MESSAGE="${GREEN}Started container: $name${NC}"
            else
                STATUS_MESSAGE="${RED}Failed to start: $name${NC}"
            fi
            ;;
        stop)
            if docker stop "$id" &>/dev/null; then
                STATUS_MESSAGE="${GREEN}Stopped container: $name${NC}"
            else
                STATUS_MESSAGE="${RED}Failed to stop: $name${NC}"
            fi
            ;;
        restart)
            if docker restart "$id" &>/dev/null; then
                STATUS_MESSAGE="${GREEN}Restarted container: $name${NC}"
            else
                STATUS_MESSAGE="${RED}Failed to restart: $name${NC}"
            fi
            ;;
        logs)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Logs: $name ===${NC}"
            echo
            docker logs --tail 50 "$id" 2>&1 || true
            pause_for_input
            ;;
        shell)
            clear_screen
            echo -e "${BOLD}${CYAN}=== Shell: $name (exit to return) ===${NC}"
            echo
            docker exec -it "$id" bash 2>/dev/null || docker exec -it "$id" sh 2>/dev/null || {
                echo -e "${RED}Could not open shell${NC}"
                pause_for_input
            }
            ;;
        delete)
            echo -en "  ${YELLOW}Delete container '$name'? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker stop "$id" &>/dev/null || true
                if docker rm "$id" &>/dev/null; then
                    STATUS_MESSAGE="${GREEN}Deleted container: $name${NC}"
                else
                    STATUS_MESSAGE="${RED}Failed to delete: $name${NC}"
                fi
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        destroy)
            echo -en "  ${RED}Destroy container '$name' AND volumes? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker stop "$id" &>/dev/null || true
                if docker rm -v "$id" &>/dev/null; then
                    STATUS_MESSAGE="${GREEN}Destroyed container and volumes: $name${NC}"
                else
                    STATUS_MESSAGE="${RED}Failed to destroy: $name${NC}"
                fi
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        stop-all)
            echo -en "  ${YELLOW}Stop ALL running containers? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                local running=$(docker ps -q)
                if [[ -n "$running" ]]; then
                    docker stop $running &>/dev/null
                    STATUS_MESSAGE="${GREEN}Stopped all containers${NC}"
                else
                    STATUS_MESSAGE="${YELLOW}No running containers${NC}"
                fi
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        remove-all)
            echo -en "  ${RED}Remove ALL containers? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "  ${CYAN}Stopping containers...${NC}"
                docker stop $(docker ps -q) 2>/dev/null || true
                echo -e "  ${CYAN}Removing containers...${NC}"
                docker rm $(docker ps -aq) 2>/dev/null || true
                STATUS_MESSAGE="${GREEN}Removed all containers${NC}"
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        destroy-all)
            echo -en "  ${RED}Destroy ALL containers (no volumes)? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "  ${CYAN}Stopping containers...${NC}"
                docker stop $(docker ps -q) 2>/dev/null || true
                echo -e "  ${CYAN}Removing containers...${NC}"
                docker rm -f $(docker ps -aq) 2>/dev/null || true
                STATUS_MESSAGE="${GREEN}Destroyed all containers${NC}"
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        destroy-all-vols)
            echo -en "  ${RED}Destroy ALL containers AND their volumes? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "  ${CYAN}Stopping containers...${NC}"
                docker stop $(docker ps -q) 2>/dev/null || true
                echo -e "  ${CYAN}Removing containers and volumes...${NC}"
                docker rm -fv $(docker ps -aq) 2>/dev/null || true
                STATUS_MESSAGE="${GREEN}Destroyed all containers and volumes${NC}"
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
    esac
    load_items
}

# Handle image actions
handle_image_action() {
    local action="$1"
    local id=$(get_selected_id)
    local name=$(get_selected_name)

    case "$action" in
        delete)
            if [[ -z "$id" ]]; then
                STATUS_MESSAGE="${RED}No image selected${NC}"
                return
            fi
            echo -en "  ${YELLOW}Delete image '$name'? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if docker rmi "$id" &>/dev/null; then
                    STATUS_MESSAGE="${GREEN}Deleted image: $name${NC}"
                else
                    STATUS_MESSAGE="${RED}Failed (may be in use): $name${NC}"
                fi
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        delete-all)
            echo -en "  ${RED}Delete ALL images? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                local imgs=$(docker images -q)
                if [[ -n "$imgs" ]]; then
                    echo -e "  ${CYAN}Deleting images (this may take a while)...${NC}"
                    docker rmi -f $imgs 2>/dev/null || true
                    STATUS_MESSAGE="${GREEN}Deleted all images${NC}"
                else
                    STATUS_MESSAGE="${YELLOW}No images to delete${NC}"
                fi
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        delete-dangling)
            local dangling=$(docker images -f "dangling=true" -q)
            if [[ -n "$dangling" ]]; then
                docker rmi $dangling &>/dev/null || true
                STATUS_MESSAGE="${GREEN}Removed dangling images${NC}"
            else
                STATUS_MESSAGE="${YELLOW}No dangling images${NC}"
            fi
            ;;
    esac
    load_items
}

# Handle volume actions
handle_volume_action() {
    local action="$1"
    local name=$(get_selected_name)

    case "$action" in
        delete)
            if [[ -z "$name" ]]; then
                STATUS_MESSAGE="${RED}No volume selected${NC}"
                return
            fi
            echo -en "  ${YELLOW}Delete volume '$name'? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if docker volume rm "$name" &>/dev/null; then
                    STATUS_MESSAGE="${GREEN}Deleted volume: $name${NC}"
                else
                    STATUS_MESSAGE="${RED}Failed (may be in use): $name${NC}"
                fi
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        delete-unused)
            echo -en "  ${YELLOW}Delete all unused volumes? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker volume prune -f &>/dev/null
                STATUS_MESSAGE="${GREEN}Deleted unused volumes${NC}"
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        delete-all)
            echo -en "  ${RED}Force delete ALL volumes? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker volume rm -f $(docker volume ls -q) &>/dev/null || true
                STATUS_MESSAGE="${GREEN}Deleted all volumes${NC}"
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
    esac
    load_items
}

# Handle network actions
handle_network_action() {
    local action="$1"
    local id=$(get_selected_id)
    local name=$(get_selected_name)

    case "$action" in
        delete)
            if [[ -z "$id" ]]; then
                STATUS_MESSAGE="${RED}No network selected${NC}"
                return
            fi
            if [[ "$name" =~ ^(bridge|host|none)$ ]]; then
                STATUS_MESSAGE="${RED}Cannot delete default network${NC}"
                return
            fi
            echo -en "  ${YELLOW}Delete network '$name'? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if docker network rm "$id" &>/dev/null; then
                    STATUS_MESSAGE="${GREEN}Deleted network: $name${NC}"
                else
                    STATUS_MESSAGE="${RED}Failed to delete: $name${NC}"
                fi
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
        delete-all)
            echo -en "  ${RED}Delete all custom networks? [y/N]: ${NC}"
            read -rsn1 confirm
            echo
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker network ls --format '{{.Name}}' | grep -vE '^(bridge|host|none)$' | xargs -r docker network rm &>/dev/null || true
                STATUS_MESSAGE="${GREEN}Deleted custom networks${NC}"
            else
                STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
            fi
            ;;
    esac
    load_items
}

# Handle prune
handle_prune() {
    echo -en "  ${YELLOW}Prune unused Docker resources? [y/N]: ${NC}"
    read -rsn1 confirm
    echo
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        docker system prune -f &>/dev/null
        STATUS_MESSAGE="${GREEN}Pruned unused resources${NC}"
    else
        STATUS_MESSAGE="${YELLOW}Cancelled${NC}"
    fi
    load_items
}

# Show stats popup
show_stats_popup() {
    clear_screen
    echo -e "${BOLD}${CYAN}=== Docker Stats ===${NC}"
    echo
    docker stats --no-stream 2>/dev/null || echo "No running containers"
    echo
    echo -e "${BOLD}${CYAN}=== Disk Usage ===${NC}"
    echo
    docker system df 2>/dev/null
    pause_for_input
}

# Main interactive loop
run_interactive() {
    # Disable exit-on-error for interactive mode (arithmetic, read, etc. return non-zero legitimately)
    set +e

    # Hide cursor
    printf '\033[?25l'

    # Restore cursor on exit
    trap 'printf "\033[?25h"; clear_screen; exit 0' EXIT INT TERM

    while true; do
        get_term_size
        load_items
        clear_screen
        draw_header
        echo
        draw_tabs
        draw_items
        draw_menu

        # Read single keypress
        read -rsn1 key

        # Handle arrow keys (escape sequences arrive all at once, no timeout needed)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn1 seq1
            read -rsn1 seq2
            if [[ "$seq1" == "[" ]]; then
                case "$seq2" in
                    'A') key='UP' ;;
                    'B') key='DOWN' ;;
                    'C') key='RIGHT' ;;
                    'D') key='LEFT' ;;
                    *) key='IGNORE' ;;
                esac
            else
                key='IGNORE'
            fi
        fi

        STATUS_MESSAGE=""

        case "$key" in
            # Ignore unhandled escape sequences
            IGNORE|RIGHT|LEFT)
                continue
                ;;

            # Navigation
            UP|k|K)
                [[ $SELECTED_INDEX -gt 0 ]] && ((SELECTED_INDEX--))
                ;;
            DOWN|j|J)
                [[ $SELECTED_INDEX -lt $((${#ITEMS[@]} - 1)) ]] && ((SELECTED_INDEX++))
                ;;

            # View switching
            1)
                CURRENT_VIEW="containers"
                SELECTED_INDEX=0
                ;;
            2)
                CURRENT_VIEW="images"
                SELECTED_INDEX=0
                ;;
            3)
                CURRENT_VIEW="volumes"
                SELECTED_INDEX=0
                ;;
            4)
                CURRENT_VIEW="networks"
                SELECTED_INDEX=0
                ;;

            # Container actions
            s)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "start"
                ;;
            t)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "stop"
                ;;
            r)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "restart"
                ;;
            l)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "logs"
                ;;
            h)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "shell"
                ;;
            d)
                case "$CURRENT_VIEW" in
                    containers) handle_container_action "delete" ;;
                    images) handle_image_action "delete" ;;
                    volumes) handle_volume_action "delete" ;;
                    networks) handle_network_action "delete" ;;
                esac
                ;;
            D)
                case "$CURRENT_VIEW" in
                    containers) handle_container_action "destroy" ;;
                    images) handle_image_action "delete-dangling" ;;
                esac
                ;;

            # Bulk actions
            A)
                case "$CURRENT_VIEW" in
                    containers) handle_container_action "stop-all" ;;
                    images) handle_image_action "delete-all" ;;
                    volumes) handle_volume_action "delete-all" ;;
                    networks) handle_network_action "delete-all" ;;
                esac
                ;;
            R)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "remove-all"
                ;;
            X)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "destroy-all"
                ;;
            V)
                [[ "$CURRENT_VIEW" == "containers" ]] && handle_container_action "destroy-all-vols"
                ;;
            U)
                [[ "$CURRENT_VIEW" == "volumes" ]] && handle_volume_action "delete-unused"
                ;;
            P|p)
                handle_prune
                ;;

            # Info
            '?')
                show_stats_popup
                ;;

            # Quit
            q|Q)
                break
                ;;
        esac
    done
}

# Main
check_docker

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

    # Container commands
    list|ls)
        list_containers
        ;;
    stop-all)
        stop_all_containers
        ;;
    start)
        docker start "$ARG"
        print_success "Container '$ARG' started"
        ;;
    stop)
        docker stop "$ARG"
        print_success "Container '$ARG' stopped"
        ;;
    restart)
        docker restart "$ARG"
        print_success "Container '$ARG' restarted"
        ;;
    logs)
        shift
        show_logs "${ARGS[@]:1}"
        ;;
    shell)
        container_shell "$ARG"
        ;;
    inspect)
        docker inspect "$ARG"
        ;;
    rm)
        if confirm "Remove container '$ARG'?"; then
            docker rm "$ARG"
            print_success "Container '$ARG' removed"
        fi
        ;;
    rm-all)
        remove_all_containers
        ;;

    # Image commands
    images)
        list_images
        ;;
    rmi)
        if confirm "Remove image '$ARG'?"; then
            docker rmi "$ARG"
            print_success "Image '$ARG' removed"
        fi
        ;;
    rmi-all)
        remove_all_images
        ;;
    rmi-dangling)
        remove_dangling_images
        ;;

    # Volume commands
    volumes)
        list_volumes
        ;;
    rmv)
        if confirm "Remove volume '$ARG'?"; then
            docker volume rm "$ARG"
            print_success "Volume '$ARG' removed"
        fi
        ;;
    rmv-all)
        remove_unused_volumes
        ;;
    rmv-force)
        remove_all_volumes
        ;;

    # Network commands
    networks)
        list_networks
        ;;
    rmn)
        if confirm "Remove network '$ARG'?"; then
            docker network rm "$ARG"
            print_success "Network '$ARG' removed"
        fi
        ;;
    rmn-all)
        remove_all_networks
        ;;

    # Cleanup commands
    prune)
        docker_prune
        ;;
    nuke)
        docker_nuke
        ;;
    destroy)
        destroy_container "$ARG"
        ;;

    # Info commands
    stats)
        show_stats
        ;;
    disk)
        show_disk_usage
        ;;
    info)
        docker info
        ;;

    *)
        print_error "Unknown command: $COMMAND"
        echo "Run '$(basename "$0") --help' for usage"
        exit 1
        ;;
esac
