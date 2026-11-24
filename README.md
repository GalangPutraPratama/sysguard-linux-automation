# SysGuard: Otomasi Monitoring Layanan dan Backup Linux

Solusi administrasi sistem Linux modular berbasis Bash dan Docker untuk monitoring layanan secara real-time, backup otomatis dengan validasi kondisi, serta pemulihan (restore) data terverifikasi menggunakan checksum MD5.

Proyek ini disusun untuk memenuhi tugas **Proyek Akhir Praktikum Sistem Operasi (Pilihan A: Backup dan Monitoring Layanan)**.

---

## 1. Identitas Proyek

- **Mata Kuliah**: Praktikum Sistem Operasi
- **Pilihan Proyek**: A - Backup dan Monitoring Layanan
- **Repository**: [https://github.com/GalangPutraPratama/sysguard-linux-automation](https://github.com/GalangPutraPratama/sysguard-linux-automation)
- **Tag Final**: `P2-FINAL-v01`
- **Platform**: Linux (WSL 2 Ubuntu / Docker Desktop Engine)

### Anggota Kelompok

| No | Nama Lengkap | NIM | Peran / Kontribusi Utama |
|---|---|---|---|
| 1 | Galang Putra Pratama | 2510501047 | Project Owner, System Integration, `run.sh`, `common.sh`, Final Testing & Release |
| 2 | Delia Ayu Nandhita | 2510501043 | Monitoring Module Owner (`monitor.sh`), CGroup & Stats Inspector |
| 3 | Shelenia Violine Karo Karo | 2510501041 | Backup & Restore Module Owner (`backup.sh`, `restore.sh`), Checksum Verification |
| 4 | Rania Zoya Irfan | 2510501042 | Container & Security Owner (`Dockerfile`, `compose.yaml`, SSH Hardening, Evidence) |

---

## 2. Arsitektur dan Alur Kerja

```text
[ Host Linux (WSL 2) ]
        │
        ├── common.sh ────> Load config.conf / config.example.conf & Helper logging
        │
        ├── monitor.sh ───> Inspeksi Container, Disk Threshold, cgroup (CPU/RAM), Logs
        │                         │
        │                         ▼ (Kondisi Sistem)
        │
        ├── backup.sh ────> [Validasi: Container Aktif? Disk Cukup?]
        │                         │
        │                         ├──> TIDAK  ──> [ABORT: Exit Status 2 / 3]
        │                         └──> YA     ──> Tar GZ Archive ke backups/
        │
        └── restore.sh ───> Extract Archive ke data/restored/
                                  │
                                  ▼
                            Verifikasi MD5 Checksum (data/source vs data/restored)
```

### Pembagian Komponen Host dan Container

1. **Host (Linux / WSL 2)**:
   - Menjalankan seluruh logika shell script (`run.sh`, `monitor.sh`, `backup.sh`, `restore.sh`, `common.sh`).
   - Menyimpan arsip backup terkompresi di folder `backups/`.
   - Menjalankan verifikasi integritas data menggunakan `md5sum` dan `diff`.
   - Mengelola siklus hidup container melalui Docker CLI.

2. **Container (Docker)**:
   - **Service Nginx (`sysguard-nginx`)**: Menjalankan layanan web server dengan mount direktori data simulasi secara read-only (`data/source -> /usr/share/nginx/html:ro`). Dibatasi limit CPU (0.5 core) dan Memori (128 MB).
   - **Service SSH (`sysguard-ssh`)**: Layanan secure access berbasis Alpine Linux untuk pengujian remote connection dan privilege access control (allowed user vs denied user).

---

## 3. Struktur Direktori

```text
sysguard-linux-automation/
├── config/
│   └── config.example.conf    # Template konfigurasi sistem
├── data/
│   ├── source/                # Data simulasi yang dipantau dan dibackup
│   └── restored/              # Target ekstraksi data saat pemulihan
├── docker/
│   ├── Dockerfile             # Build image Nginx custom
│   ├── Dockerfile.ssh         # Build image SSH server custom
│   ├── compose.yaml           # Orkestrasi multi-container & resource limits
│   └── default.conf           # Konfigurasi Nginx
├── scripts/
│   ├── common.sh              # Library fungsi bersama, logging, validasi
│   ├── monitor.sh             # Modul monitoring layanan dan kapasitas disk
│   ├── backup.sh              # Modul backup otomatis terintegrasi
│   ├── restore.sh             # Modul restore dan verifikasi integritas
│   └── run.sh                 # Unified CLI entry point
├── backups/                   # Direktori output file tar.gz (runtime)
├── logs/                      # Log aktivitas sistem (runtime)
├── evidence/                  # Bukti output terminal aktual per skenario uji
├── tests/
│   └── test_backup_restore.sh # Script otomatisasi pengujian
├── .gitignore                 # Filter tracking file sensitif & runtime
└── README.md                  # Dokumentasi teknis proyek
```

---

## 4. Prasyarat Lingkungan

- Sistem Operasi: Linux (Ubuntu 20.04/22.04 LTS atau WSL 2 di Windows 11)
- Bash Shell: versi 5.0 ke atas
- Docker Engine & Docker Compose v2
- Utility Linux: `tar`, `md5sum`, `df`, `du`, `awk`, `grep`

---

## 5. Panduan Instalasi dan Menjalankan

### A. Clone Repository

```bash
git clone https://github.com/GalangPutraPratama/sysguard-linux-automation.git
cd sysguard-linux-automation
```

### B. Konfigurasi Lingkungan

Salin template konfigurasi:

```bash
cp config/config.example.conf config/config.conf
```

### C. Menjalankan Container Service

Jalankan container Nginx dan SSH di latar belakang:

```bash
docker compose -f docker/compose.yaml up -d
```

Pastikan container aktif:

```bash
docker ps
```

Container `sysguard-nginx` akan terekspos di port `8085` dan `sysguard-ssh` di port `2222`.

---

## 6. Penggunaan Modul Otomasi

Seluruh modul dapat dipanggil melalui entry point `scripts/run.sh`:

### 1. Monitoring Sistem dan Layanan

```bash
./scripts/run.sh monitor
```

Output mencakup status service, utilisasi disk, kuota CPU/Memory cgroup v2, docker stats snapshot, dan 10 baris terakhir log container.

### 2. Backup Data Layanan

```bash
./scripts/run.sh backup
```

Alur kerja:
- Memeriksa direktori sumber data.
- Memeriksa apakah container Nginx aktif (wajib aktif).
- Memeriksa sisa kapasitas disk (minimal 100 MB free space).
- Membuat arsip `backups/sysguard-backup_<timestamp>.tar.gz`.
- Melakukan rotasi otomatis (hanya menyimpan 5 backup terbaru).

### 3. Restore dan Verifikasi Data

```bash
./scripts/run.sh restore
```

Alur kerja:
- Menampilkan daftar arsip backup yang tersedia beserta ukuran dan waktu pembuatan.
- Menerima pilihan nomor arsip dari pengguna.
- Mengekstrak file ke direktori `data/restored/`.
- Menghitung checksum MD5 setiap file di `data/source/` dan membandingkannya dengan `data/restored/`.
- Melaporkan status integritas: `[VERIFIKASI BERHASIL]` jika identik.

### 4. Cek Status Singkat

```bash
./scripts/run.sh status
```

---

## 7. Pengujian dan Hasil Evaluasi

Skenario pengujian yang telah diuji dan didokumentasikan di folder `evidence/`:

| ID Uji | Modul / Fitur | Kondisi / Input | Hasil yang Diharapkan | Hasil Aktual | Status | File Bukti |
|---|---|---|---|---|---|---|
| T01 | Backup Otomatis | Service aktif & disk memadai | Backup berhasil, file .tar.gz terbentuk | File terbentuk di folder backups/ | SUCCESS | `evidence/T01-backup-success.txt` |
| T02 | Integrasi Guard | Service Nginx di-stop (`docker stop`) | Backup ditolak dengan exit status 2 | Backup ditolak, error tercatat di log | SUCCESS | `evidence/T02-backup-rejected-service-down.txt` |
| T03 | Proteksi Storage | Simulasi kapasitas disk penuh / batas threshold | Backup ditolak dengan exit status 3 | Backup ditolak, peringatan disk muncul | SUCCESS | `evidence/T03-backup-rejected-disk-low.txt` |
| T04 | Restore Modul | Arsip valid diekstrak ke `data/restored/` | Seluruh data pulih, struktur utuh | Seluruh file ter-ekstrak sempurna | SUCCESS | `evidence/T04-restore-success.txt` |
| T05 | Integritas Data | Komparasi checksum MD5 source vs restored | Checksum identik 100% | Checksum cocok, verifikasi lolos | SUCCESS | Dilaporkan pada log runtime restore |
| T06 | Persistensi Data | Container dibuat ulang (`down` lalu `up -d`) | Data pada bind mount tetap utuh | Data simulasi tetap dapat diakses | SUCCESS | `evidence/T06-persistence-after-recreate.txt` |
| T07 | Akses Aman | Login SSH user resmi (`sysguard`) | Akses diberikan (auth password) | Login berhasil | SUCCESS | `evidence/T07-allowed-access.txt` |
| T08 | Akses Ditolak | Login SSH user non-otoritas (`denied_user`) | Akses ditolak oleh sshd config | Permission denied | SUCCESS | `evidence/T08-denied-access.txt` |
| T09 | Resource Limits | Cek cgroup `cpu.max` dan `memory.max` | Nilai sesuai limit compose (0.5 CPU, 128MB RAM) | Limit aktif pada kernel container | SUCCESS | `evidence/T09-resource-limits.txt` |
| T10 | Log & Monitoring | Ekstraksi status real-time dan log container | Informasi container terpetakan rapi | Log dan visual stats tampil | SUCCESS | `evidence/T10-monitoring-and-logs.txt` |

---

## 8. Panduan Cleanup dan Rollback

### Pembersihan Container dan Jaringan

Untuk menghentikan dan menghapus container serta jaringan bridge proyek:

```bash
docker compose -f docker/compose.yaml down
```

### Rollback Data dan Bersihkan Hasil Runtime

Untuk membersihkan data hasil restore dan file arsip sementara tanpa menghapus struktur utama:

```bash
rm -rf data/restored/*
rm -rf backups/*.tar.gz
rm -rf logs/*.log
```

---

## 9. Keterbatasan Solusi

1. **Mekanisme Backup Lokal**: Backup saat ini disimpan di filesystem lokal host Linux; belum menerapkan off-site replication ke cloud storage (S3/GCS).
2. **Metode Otentikasi SSH**: Akses SSH dalam container simulasi masih mengandalkan password-based authentication; belum diwajibkan berbasis SSH Public Key Authentication murni.
3. **Penyimpanan Log**: Log aktivitas disimpan dalam format file teks lokal (`logs/sysguard.log`) dan belum diteruskan ke sistem log aggregator tersentralisasi seperti Graylog atau Grafana Loki.
