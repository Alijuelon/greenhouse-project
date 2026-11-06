# Ekspor Database — AgriSense

Hasil `mysqldump` dari database **`agrisense_db`** (MySQL 8.0.46, InnoDB, utf8mb4).

| File | Ukuran | Isi |
|---|---:|---|
| `agrisense_db_20261105_1512.sql` | 1.3 MB | Struktur + seluruh data (dipakai untuk deploy) |
| `agrisense_db_20261105_1512.sql.gz` | 111 KB | Versi kompres untuk upload |
| `agrisense_db_schema_only_20261105.sql` | 8.6 KB | Struktur saja, tanpa data (untuk DB kosong/dev) |
| `agrisense_db_schema_only_20261105.sql.gz` | 1.6 KB | Versi kompres skema |
| `SHA256SUMS.txt` | — | Checksum verifikasi integritas |

## Jumlah baris saat diekspor

| Tabel | Baris |
|---|---:|
| `device_state` | 1 |
| `telemetry` | 12.007 |
| `dose_log` | 882 |
| `activity_log` | 842 |
| `automation_rule` | 5 |
| `app_settings` | 1 |
| `ai_model` | 1 |
| `ai_performance` | 1 |
| `manual_command` | 1 |

## Cara restore

```bash
# MySQL / MariaDB (MariaDB: tambahkan sed collation, lihat bawah)
mysql -u USER -p NAMA_DB < agrisense_db_20261105_1512.sql

# Dari file .gz
gunzip -c agrisense_db_20261105_1512.sql.gz | mysql -u USER -p NAMA_DB

# Kompatibel MariaDB (collation MySQL 8 → umum)
sed 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g' agrisense_db_20261105_1512.sql \
  | mysql -u USER -p NAMA_DB
```

Atau pakai `../deploy_flask_api/scripts/02_import_db.sh --mariadb --create`.

## Verifikasi integritas

```bash
sha256sum -c SHA256SUMS.txt
```

## Catatan

- Dump memakai opsi `--single-transaction`, aman dijalankan saat server hidup
  (tidak mengunci tabel, data konsisten per titik waktu).
- Nominal `AUTO_INCREMENT` ikut tersimpan sehingga ID `automation_rule`
  tetap sama → aplikasi Flutter tidak perlu mapping ulang.
- File ini **mengandung** `app_settings.api_key` (`live_sec_agri_89f2`).
  Jangan dibagikan publik; ganti kunci setelah restore ke server publik.
- Ekspor ulang kapan saja:
  ```bash
  DB_USER=root DB_PASS=123456 DB_NAME=agrisense_db \
    OUT_DIR=$PWD/database_export bash ../deploy_flask_api/scripts/01_export_db.sh
  ```
