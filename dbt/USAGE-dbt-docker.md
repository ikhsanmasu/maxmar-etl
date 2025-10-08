# 🧭 Panduan Penggunaan dbt (Docker Setup)

File ini menjelaskan cara pakai **dbt** dengan **Docker**, perintah-perintah penting, environment variables, logging, dan contoh **cron job** untuk production.

---

## ⚙️ 1. Struktur Dasar
```
maxmar-etl/
├── dbt/
│   ├── dbt_project.yml
│   ├── models/
│   ├── profiles/profiles.yml
│   ├── target/ (hasil run & logs)
│   └── Dockerfile
└── docker-compose.yml
```
> Jalankan semua perintah dari folder yang memiliki `docker-compose.yml` dan folder `dbt/`.

---

## 🚀 2. Perintah Dasar

### 🔹 Cek koneksi & profil
```bash
docker compose run --rm dbt debug
```
- Harus muncul `profiles.yml [OK]` dan `Connection test: OK`.

### 🔹 Jalankan semua model
```bash
docker compose run --rm dbt run
```

### 🔹 Jalankan test
```bash
docker compose run --rm dbt test
```

### 🔹 Build lengkap (run + test + snapshot)
```bash
docker compose run --rm dbt build
```

### 🔹 Generate & serve dokumentasi
```bash
docker compose run --rm dbt docs generate
docker compose run --rm -p 8080:8080 dbt docs serve --port 8080 --host 0.0.0.0 --no-browser
# buka http://localhost:8080
```

### 🔹 Seleksi model tertentu
```bash
docker compose run --rm dbt run --select stg_example
docker compose run --rm dbt run --select tag:daily
docker compose run --rm dbt run --select path:models/marts/*
```

### 🔹 Mode debug (lihat query SQL penuh)
```bash
docker compose run --rm dbt run --debug
```

---

## 🧰 3. Environment Variables

| Key           | Default                 | Fungsi                           |
|---------------|-------------------------|----------------------------------|
| `DB_HOST`     | `host.docker.internal`  | Host Postgres                    |
| `DB_PORT`     | `5432` / `5435`         | Port Postgres                    |
| `DB_USER`     | `postgres`              | Username                         |
| `DB_PASSWORD` | `postgres`              | Password                         |
| `DB_NAME`     | `analytics`             | Nama database                    |
| `DB_SCHEMA`   | `analytics` / `public`  | Schema tempat dbt menulis        |
| `DBT_THREADS` | `4`                     | Jumlah thread paralel            |

> Pastikan `DBT_PROFILES_DIR=/usr/app/profiles` diset di service `dbt` agar container membaca `profiles/profiles.yml` dari proyek.

Contoh potongan `docker-compose.yml`:
```yaml
services:
  dbt:
    image: ghcr.io/dbt-labs/dbt-postgres:1.9.0
    working_dir: /usr/app
    volumes:
      - ./dbt:/usr/app
    environment:
      DBT_PROFILES_DIR: /usr/app/profiles
      DB_HOST: host.docker.internal
      DB_PORT: "5435"
      DB_USER: postgres
      DB_PASSWORD: postgres
      DB_NAME: analytics
      DB_SCHEMA: analytics
      DBT_THREADS: "4"
```

---

## 🧾 4. Logging

Lokasi log dbt:
```
dbt/target/logs/dbt.log
```

Pantau live log:
- **Linux/WSL/Git Bash**
  ```bash
  tail -f dbt/target/logs/dbt.log
  ```
- **PowerShell**
  ```powershell
  Get-Content dbt	arget\logs\dbt.log -Wait
  ```

---

## 🕐 5. Scheduling (Cron Job di Production)

### 🔸 Opsi A — Script + Cron (disarankan)
1) Buat skrip `/opt/dbt/run-daily.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

cd /opt/maxmar-etl   # ganti ke folder project di server

export DB_HOST=db.prod.internal
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=postgres
export DB_NAME=analytics
export DB_SCHEMA=analytics
export DBT_THREADS=4

# Jalankan build (run + test + snapshots)
docker compose run --rm dbt build
```
Beri izin eksekusi:
```bash
sudo chmod +x /opt/dbt/run-daily.sh
```

2) Tambahkan ke crontab (01:30 WIB):
```bash
sudo crontab -e
```
Isi:
```bash
30 1 * * * /opt/dbt/run-daily.sh >> /var/log/dbt/daily.log 2>&1
```
> Buat folder log jika belum ada: `sudo mkdir -p /var/log/dbt`

### 🔸 Opsi B — Cron langsung panggil Compose
```bash
30 1 * * * cd /opt/maxmar-etl && docker compose run --rm dbt build >> /var/log/dbt/daily.log 2>&1
```

### 🔸 Opsi C — Kubernetes CronJob (kalau pakai K8s)
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dbt-build-daily
spec:
  schedule: "30 18 * * *"  # UTC 18:30 ≈ 01:30 WIB
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: dbt
              image: ghcr.io/dbt-labs/dbt-postgres:1.9.0
              args: ["build", "--select", "tag:daily"]
              env:
                - name: DB_HOST     ; value: "db.prod.internal"
                - name: DB_PORT     ; value: "5432"
                - name: DB_USER     ; value: "postgres"
                - name: DB_PASSWORD ; valueFrom: {secretKeyRef: {name: pg-secret, key: password}}
                - name: DB_NAME     ; value: "analytics"
                - name: DB_SCHEMA   ; value: "analytics"
                - name: DBT_THREADS ; value: "4"
```

---

## 🔧 6. Troubleshooting Cepat

| Gejala                               | Penyebab Umum                         | Solusi                                                                 |
|--------------------------------------|---------------------------------------|------------------------------------------------------------------------|
| `profiles.yml not found`             | Path salah/DBT_PROFILES_DIR belum ada | Set `DBT_PROFILES_DIR=/usr/app/profiles` & pastikan volume `./dbt:/usr/app` |
| `Connection test failed`             | Env salah / DB belum siap             | Cek `DB_HOST/PORT/USER/PASSWORD/NAME/SCHEMA`, DB up & accessible       |
| `No such command 'tail'`             | Salah ketik (`dbt tail`)              | Gunakan `tail -f dbt/target/logs/dbt.log`                              |
| Model tidak jalan                    | File `.sql` tidak ada/salah path      | Pastikan file ada di `dbt/models/`                                     |
| Hasil tidak update                   | Materialization `view` saja           | Pakai `table`/`incremental` (`{{ config(materialized='table') }}`)     |

---

## ✅ 7. Best Practices
- Gunakan **`dbt build`** untuk job terjadwal (run + test + snapshot).
- Kelompokkan model via **tag** (`tag:daily`, `tag:hourly`) dan folder (`staging/`, `marts/`).
- Simpan secret database di **.env/secret manager** (hindari hardcode).
- Aktifkan logging dan **logrotate** untuk file `/var/log/dbt/*.log`.
- Untuk observability, pertimbangkan **Loki + Promtail + Grafana**.

---

Happy shipping! 🚀
