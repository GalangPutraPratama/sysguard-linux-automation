#!/bin/bash
# monitor.sh - Monitoring module for SysGuard
# Owner: Delia Ayu Nandhita
#
# Functions:
#   1. Check Nginx container status (running / stopped / not found)
#   2. Check available disk capacity vs threshold
#   3. Check container CPU and memory limits
#   4. Read container logs
#   5. Write activity logs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

# ───────────────────────────────────────────────
# 1. Check container status
# ───────────────────────────────────────────────
check_container_status() {
    log "INFO" "=== Container Status Check ==="
    if container_running; then
        log "INFO" "Container '${CONTAINER_NAME}' is RUNNING"
        docker ps --filter "name=^${CONTAINER_NAME}$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        return 0
    elif container_exists; then
        log "WARN" "Container '${CONTAINER_NAME}' EXISTS but is STOPPED"
        docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "table {{.Names}}\t{{.Status}}"
        return 1
    else
        log "ERROR" "Container '${CONTAINER_NAME}' NOT FOUND"
        return 2
    fi
}

# ───────────────────────────────────────────────
# 2. Check disk capacity
# ───────────────────────────────────────────────
check_disk_capacity() {
    log "INFO" "=== Disk Capacity Check ==="
    df -h "$PROJECT_DIR" | awk 'NR==1 || NR==2'

    local usage
    usage=$(df "$PROJECT_DIR" | awk 'NR==2 {gsub(/%/,""); print $5}')
    if (( usage >= DISK_THRESHOLD )); then
        log "WARN" "Disk usage ${usage}% >= threshold ${DISK_THRESHOLD}%"
        return 1
    fi
    log "INFO" "Disk usage ${usage}% < threshold ${DISK_THRESHOLD}% — OK"
    return 0
}

# ───────────────────────────────────────────────
# 3. Check CPU and memory limits
# ───────────────────────────────────────────────
check_resource_limits() {
    log "INFO" "=== Container Resource Limits ==="
    if ! container_running; then
        log "ERROR" "Container '${CONTAINER_NAME}' is not running. Cannot check resources."
        return 1
    fi

    local cpu_quota mem_limit
    cpu_quota=$(docker exec "${CONTAINER_NAME}" cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo "N/A")
    mem_limit=$(docker exec "${CONTAINER_NAME}" cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "N/A")

    log "INFO" "CPU quota (cpu.max): ${cpu_quota}"
    log "INFO" "Memory limit (memory.max): ${mem_limit}"

    log "INFO" "--- Docker Stats (snapshot) ---"
    docker stats "${CONTAINER_NAME}" --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
}

# ───────────────────────────────────────────────
# 4. Read container logs
# ───────────────────────────────────────────────
read_container_logs() {
    local lines="${1:-20}"
    log "INFO" "=== Container Logs (last ${lines} lines) ==="
    if ! container_exists; then
        log "ERROR" "Container '${CONTAINER_NAME}' not found. Cannot read logs."
        return 1
    fi
    docker logs --tail "${lines}" "${CONTAINER_NAME}" 2>&1
}

# ───────────────────────────────────────────────
# 5. Full monitoring report
# ───────────────────────────────────────────────
full_report() {
    log "INFO" "=============================="
    log "INFO" "  SysGuard Monitoring Report  "
    log "INFO" "=============================="
    echo ""

    check_container_status
    local status_code=$?
    echo ""

    check_disk_capacity
    echo ""

    if [[ $status_code -eq 0 ]]; then
        check_resource_limits
        echo ""
        read_container_logs 10
    else
        log "WARN" "Skipping resource & log checks (container not running)"
    fi

    echo ""
    log "INFO" "=============================="
    log "INFO" "  Monitoring report complete  "
    log "INFO" "=============================="
}

# ───────────────────────────────────────────────
# Main: parse arguments
# ───────────────────────────────────────────────
usage() {
    cat << EOF
Usage: $(basename "$0") [COMMAND]

Commands:
    status      Check container status
    disk        Check disk capacity
    resources   Check CPU and memory limits
    logs [N]    Show last N container log lines (default: 20)
    report      Run full monitoring report
    help        Show this help message

If no command is given, 'report' is used.
EOF
}

main() {
    local cmd="${1:-report}"
    shift 2>/dev/null || true

    case "$cmd" in
        status)     check_container_status ;;
        disk)       check_disk_capacity ;;
        resources)  check_resource_limits ;;
        logs)       read_container_logs "$@" ;;
        report)     full_report ;;
        help|--help|-h) usage ;;
        *)
            log "ERROR" "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
