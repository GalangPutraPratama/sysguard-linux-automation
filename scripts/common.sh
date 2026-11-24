#!/bin/bash
# common.sh - Shared functions for SysGuard

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config/config.conf"
DEFAULT_CONFIG="$PROJECT_DIR/config/config.example.conf"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    elif [[ -f "$DEFAULT_CONFIG" ]]; then
        source "$DEFAULT_CONFIG"
        log "WARN" "config.conf not found, using config.example.conf"
    else
        echo "[ERROR] No configuration file found"
        exit 1
    fi

    # Convert relative paths to absolute
    DATA_DIR="$PROJECT_DIR/$DATA_DIR"
    BACKUP_DIR="$PROJECT_DIR/$BACKUP_DIR"
    RESTORE_DIR="$PROJECT_DIR/$RESTORE_DIR"
    LOG_DIR="$PROJECT_DIR/$LOG_DIR"
    LOG_FILE="$PROJECT_DIR/$LOG_FILE"
    COMPOSE_FILE="$PROJECT_DIR/$COMPOSE_FILE"
}

# ============================================================
# Logging
# ============================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[$timestamp] [$level] $message"

    echo "$entry"

    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo "$entry" >> "$LOG_FILE"
    fi
}

# ============================================================
# Validation
# ============================================================

check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log "ERROR" "Command not found: $cmd"
        return 1
    fi
}

check_directory() {
    local dir="$1"
    local label="$2"
    if [[ ! -d "$dir" ]]; then
        log "ERROR" "$label directory not found: $dir"
        return 1
    fi
}

check_file() {
    local file="$1"
    local label="$2"
    if [[ ! -f "$file" ]]; then
        log "ERROR" "$label file not found: $file"
        return 1
    fi
}

# ============================================================
# Docker helpers
# ============================================================

container_running() {
    docker ps --filter "name=$CONTAINER_NAME" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"
}

container_exists() {
    docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"
}

# ============================================================
# Disk helpers
# ============================================================

get_free_space_mb() {
    local dir="$1"
    df -BM "$dir" 2>/dev/null | awk 'NR==2 {gsub(/M/,"",$4); print $4}'
}

check_disk_space() {
    local dir="$1"
    local required_mb="$2"
    local free_mb
    free_mb=$(get_free_space_mb "$dir")

    if [[ -z "$free_mb" ]]; then
        log "ERROR" "Cannot check disk space for $dir"
        return 1
    fi

    if (( free_mb < required_mb )); then
        log "ERROR" "Insufficient disk space: ${free_mb}MB free, ${required_mb}MB required"
        return 1
    fi

    log "INFO" "Disk space OK: ${free_mb}MB free (minimum ${required_mb}MB)"
    return 0
}
