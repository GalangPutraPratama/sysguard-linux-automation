#!/bin/bash
# run.sh - SysGuard entry point

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

usage() {
    echo "Usage: $0 {monitor|backup|restore|status}"
    echo ""
    echo "Commands:"
    echo "  monitor   Check service and system status"
    echo "  backup    Backup service data"
    echo "  restore   Restore from backup"
    echo "  status    Quick container status"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    monitor)
        bash "$SCRIPT_DIR/monitor.sh"
        ;;
    backup)
        bash "$SCRIPT_DIR/backup.sh"
        ;;
    restore)
        bash "$SCRIPT_DIR/restore.sh" "${@:2}"
        ;;
    status)
        if container_running; then
            log "INFO" "Container $CONTAINER_NAME is running"
            docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            log "WARN" "Container $CONTAINER_NAME is not running"
        fi
        ;;
    *)
        usage
        ;;
esac
