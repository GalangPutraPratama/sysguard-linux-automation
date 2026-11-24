#!/bin/bash
# restore.sh — Modul Restore SysGuard
# Owner: Shelenia Violine Karo Karo
#
# Fungsi:
#   1. Tampilkan daftar archive backup yang tersedia
#   2. User memilih archive mana yang mau di-restore
#   3. Extract archive ke data/restored/
#   4. Verifikasi file hasil restore cocok dengan source (checksum)
#   5. Tulis log aktivitas

set -euo pipefail

# ============================================================
# Load common functions & config
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
load_config

# ============================================================
# Fungsi: hitung checksum semua file dalam direktori
# ============================================================
compute_checksums() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        echo ""
        return 1
    fi

    (cd "$dir" && find . -type f ! -name ".gitkeep" -exec md5sum {} \; | sort -k2)
}

# ============================================================
# Fungsi: tampilkan daftar backup dan biarkan user memilih
# ============================================================
select_backup() {
    local backups=()

    while IFS= read -r -d '' file; do
        backups+=("$file")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.tar.gz" -type f -print0 | sort -z)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log "ERROR" "Tidak ada file backup ditemukan di ${BACKUP_DIR}"
        echo "[GAGAL] Tidak ada file backup di '${BACKUP_DIR}'."
        exit 1
    fi

    echo "Daftar backup yang tersedia:"
    echo "----------------------------------------"
    local i=1
    for backup in "${backups[@]}"; do
        local name size date_modified
        name="$(basename "$backup")"
        size="$(du -h "$backup" | cut -f1)"
        date_modified="$(date -r "$backup" '+%Y-%m-%d %H:%M:%S')"
        printf "  [%d] %s (%s, %s)\n" "$i" "$name" "$size" "$date_modified"
        ((i++))
    done
    echo "----------------------------------------"
    echo ""

    local choice
    while true; do
        read -rp "Pilih nomor backup untuk di-restore (1-${#backups[@]}): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && \
           [[ "$choice" -ge 1 ]] && \
           [[ "$choice" -le ${#backups[@]} ]]; then
            SELECTED_BACKUP="${backups[$((choice - 1))]}"
            log "INFO" "User memilih backup: $(basename "$SELECTED_BACKUP")"
            return 0
        else
            echo "[!] Input tidak valid. Masukkan angka antara 1 dan ${#backups[@]}."
        fi
    done
}

# ============================================================
# Fungsi: extract archive ke restore directory
# ============================================================
extract_backup() {
    local archive="$1"
    local target="$RESTORE_DIR"
    local archive_name
    archive_name="$(basename "$archive")"

    echo "Meng-extract '${archive_name}' ke '${target}'..."

    if [[ -d "$target" ]]; then
        rm -rf "${target:?}/"*
        log "INFO" "Direktori restore dibersihkan: ${target}"
    fi
    mkdir -p "$target"

    if tar -xzf "$archive" -C "$target" --strip-components=1; then
        local restored_count
        restored_count="$(find "$target" -type f | wc -l)"
        log "INFO" "Extract berhasil: ${restored_count} file dari ${archive_name}"
        echo "[OK] Berhasil extract ${restored_count} file."
        return 0
    else
        log "ERROR" "Gagal extract archive: ${archive_name}"
        echo "[GAGAL] Tidak bisa extract '${archive_name}'."
        return 1
    fi
}

# ============================================================
# Fungsi: verifikasi file restored vs source menggunakan checksum
# ============================================================
verify_restore() {
    echo ""
    echo "Memverifikasi file hasil restore terhadap source..."
    echo "----------------------------------------"

    local source_checksums restored_checksums
    source_checksums="$(compute_checksums "$DATA_DIR")"
    restored_checksums="$(compute_checksums "$RESTORE_DIR")"

    if [[ -z "$source_checksums" ]]; then
        log "WARN" "Direktori source kosong, skip verifikasi"
        echo "[!] Direktori source kosong. Verifikasi di-skip."
        return 0
    fi

    if [[ -z "$restored_checksums" ]]; then
        log "ERROR" "Direktori restored kosong setelah extract"
        echo "[GAGAL] Tidak ada file di direktori restored."
        return 1
    fi

    local diff_result
    diff_result="$(diff <(echo "$source_checksums") <(echo "$restored_checksums") 2>&1 || true)"

    if [[ -z "$diff_result" ]]; then
        local verified_count
        verified_count="$(echo "$restored_checksums" | wc -l)"
        log "INFO" "Verifikasi BERHASIL — ${verified_count} file cocok dengan source"
        echo ""
        echo "========================================"
        echo "  [VERIFIKASI BERHASIL]"
        echo "  Semua ${verified_count} file cocok dengan source."
        echo "  Checksum MD5 identik."
        echo "========================================"
        return 0
    else
        log "ERROR" "Verifikasi GAGAL — file restored tidak cocok dengan source"
        echo ""
        echo "========================================"
        echo "  [VERIFIKASI GAGAL]"
        echo "  File restored TIDAK cocok dengan source!"
        echo "  Perbedaan:"
        echo "$diff_result"
        echo "========================================"
        return 1
    fi
}

# ============================================================
# Fungsi utama restore
# ============================================================
do_restore() {
    echo "========================================"
    echo "  SysGuard — Restore Module"
    echo "========================================"
    echo ""

    log "INFO" "=== Memulai proses restore ==="

    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "ERROR" "Direktori backup tidak ditemukan: ${BACKUP_DIR}"
        echo "[GAGAL] Direktori backup '${BACKUP_DIR}' tidak ada."
        exit 1
    fi

    select_backup
    echo ""

    if ! extract_backup "$SELECTED_BACKUP"; then
        log "ERROR" "=== Proses restore gagal ==="
        exit 2
    fi

    if verify_restore; then
        echo ""
        echo "========================================"
        echo "  [RESTORE BERHASIL]"
        echo "  Archive  : $(basename "$SELECTED_BACKUP")"
        echo "  Lokasi   : ${RESTORE_DIR}"
        echo "  Waktu    : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Status   : Data terverifikasi ✓"
        echo "========================================"
        log "INFO" "=== Proses restore selesai — BERHASIL ==="
        exit 0
    else
        echo ""
        echo "[PERINGATAN] Restore selesai tapi verifikasi gagal."
        log "ERROR" "=== Proses restore selesai — VERIFIKASI GAGAL ==="
        exit 3
    fi
}

# ============================================================
# Jalankan
# ============================================================
do_restore
