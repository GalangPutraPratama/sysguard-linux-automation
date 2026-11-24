#!/bin/bash
# backup.sh — Modul Backup SysGuard
# Owner: Shelenia Violine Karo Karo
#
# Fungsi:
#   1. Cek status container Nginx  → tolak backup kalau mati
#   2. Cek disk space              → tolak backup kalau di bawah threshold
#   3. Buat archive .tar.gz        → simpan ke backups/
#   4. Tulis log aktivitas

set -euo pipefail

# ============================================================
# Load common functions & config
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

# ============================================================
# Fungsi utama backup
# ============================================================
do_backup() {
    echo "========================================"
    echo "  SysGuard — Backup Module"
    echo "========================================"
    echo ""

    log "INFO" "=== Memulai proses backup ==="

    # 1. Validasi: direktori source harus ada dan tidak kosong
    if [[ ! -d "$DATA_DIR" ]]; then
        log "ERROR" "Direktori source tidak ditemukan: ${DATA_DIR}"
        echo ""
        echo "[GAGAL] Direktori source '${DATA_DIR}' tidak ada."
        exit 1
    fi

    local file_count
    file_count="$(find "$DATA_DIR" -type f ! -name ".gitkeep" | wc -l)"

    if [[ "$file_count" -eq 0 ]]; then
        log "ERROR" "Direktori source kosong: ${DATA_DIR}"
        echo ""
        echo "[GAGAL] Tidak ada file di '${DATA_DIR}' untuk di-backup."
        exit 1
    fi

    log "INFO" "Ditemukan ${file_count} file di ${DATA_DIR}"

    # 2. Cek status container → TOLAK jika mati
    echo "[1/3] Mengecek status container '${CONTAINER_NAME}'..."
    if ! container_running; then
        log "ERROR" "Container '${CONTAINER_NAME}' tidak aktif"
        echo ""
        echo "========================================"
        echo "  [BACKUP DITOLAK]"
        echo "  Container '${CONTAINER_NAME}' tidak aktif."
        echo "  Jalankan container terlebih dahulu."
        echo "========================================"
        log "ERROR" "Backup DITOLAK — container tidak aktif"
        exit 2
    fi
    log "INFO" "Container '${CONTAINER_NAME}' sedang berjalan"
    echo ""

    # 3. Cek disk space → TOLAK jika kurang
    echo "[2/3] Mengecek ruang disk (minimum: ${MIN_FREE_SPACE_MB}MB)..."
    if ! check_disk_space "$BACKUP_DIR" "$MIN_FREE_SPACE_MB"; then
        echo ""
        echo "========================================"
        echo "  [BACKUP DITOLAK]"
        echo "  Ruang disk kurang dari ${MIN_FREE_SPACE_MB}MB."
        echo "  Bebaskan ruang disk terlebih dahulu."
        echo "========================================"
        log "ERROR" "Backup DITOLAK — disk tidak cukup"
        exit 3
    fi
    echo ""

    # 4. Buat archive
    echo "[3/3] Membuat archive backup..."
    mkdir -p "$BACKUP_DIR"

    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"

    local archive_name="sysguard-backup_${timestamp}.tar.gz"
    local archive_path="${BACKUP_DIR}/${archive_name}"

    if tar -czf "$archive_path" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"; then
        local archive_size
        archive_size="$(du -h "$archive_path" | cut -f1)"

        log "INFO" "Backup berhasil: ${archive_name} (${archive_size})"
        echo ""
        echo "========================================"
        echo "  [BACKUP BERHASIL]"
        echo "  File   : ${archive_name}"
        echo "  Ukuran : ${archive_size}"
        echo "  Lokasi : ${archive_path}"
        echo "  Waktu  : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"

        # Cleanup: hapus backup lama kalau melebihi MAX_BACKUP_COUNT
        cleanup_old_backups

        log "INFO" "=== Proses backup selesai ==="
        exit 0
    else
        log "ERROR" "Gagal membuat archive: ${archive_name}"
        echo ""
        echo "[GAGAL] Tidak bisa membuat file backup."
        exit 4
    fi
}

# ============================================================
# Hapus backup lama (keep MAX_BACKUP_COUNT terbaru)
# ============================================================
cleanup_old_backups() {
    local count
    count="$(find "$BACKUP_DIR" -maxdepth 1 -name "sysguard-backup_*.tar.gz" -type f | wc -l)"

    if [[ "$count" -gt "$MAX_BACKUP_COUNT" ]]; then
        local to_delete=$(( count - MAX_BACKUP_COUNT ))
        log "INFO" "Membersihkan ${to_delete} backup lama (menyimpan ${MAX_BACKUP_COUNT} terbaru)"
        find "$BACKUP_DIR" -maxdepth 1 -name "sysguard-backup_*.tar.gz" -type f -printf '%T@ %p\n' \
            | sort -n | head -n "$to_delete" | awk '{print $2}' \
            | while read -r old_file; do
                rm -f "$old_file"
                log "INFO" "Dihapus: $(basename "$old_file")"
            done
    fi
}

# ============================================================
# Jalankan
# ============================================================
do_backup
