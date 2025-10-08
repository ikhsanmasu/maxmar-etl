# Setup Summary
1. run dbt destination untuk simulasi destination postgres
  docker compose up -d
2. setup airbyte and make the Extract Transform setting
  abctl local install
3. setup and run dbt
  docker compose run --rm dbt run
4. setting dbt cron job / scheduler


AIRBYTE NOTES

# Airbyte Setup Guide — Windows, Linux, and Production

This guide shows how to run Airbyte locally (Windows & Linux) and how to deploy it for production (Kubernetes/Helm), including scheduling, backups, and troubleshooting.

---

## 0) Quick Overview

Airbyte lets you move data from **Sources** (e.g., Postgres, MySQL, APIs) to **Destinations** (e.g., Postgres, BigQuery, S3) using **Connectors** and **Connections**. It keeps state so incremental syncs fetch only new/changed data. For deletes, enable **CDC** (where supported).

**Local Dev (recommended):**
- Use **`abctl`** to install and manage a local Airbyte instance on Windows (PowerShell) or Linux (bash).

**Production (recommended):**
- Use **Kubernetes with Helm**. `values.yaml` controls settings for webapp, server, database, storage, logs, ingress, etc.

---

## 1) Local Setup on Windows (PowerShell)

### 1.1 Install `abctl`
```powershell
# Run in PowerShell as Administrator if needed
# Download the latest abctl (example):
# (If you have a direct installer link, use that. Otherwise follow official instructions.)
# After download, add the folder to your PATH so "abctl" works in any terminal.

abctl version
```

> If `abctl` is not recognized, make sure the folder containing `abctl.exe` is added to your **System PATH**, then reopen PowerShell.

### 1.2 Start Airbyte locally
```powershell
# Standard local install
abctl local install

# (Optional) Low-resource mode for small machines
abctl local install --low-resource-mode

# (Optional) Custom host/domain (e.g., airbyte.local)
abctl local install --host airbyte.local --insecure-cookies
```

### 1.3 Get login credentials & access UI
```powershell
abctl local credentials
```
- Open the UI: `http://localhost:8000` (or your host).
- Login with the credentials shown above (you can update the password after login).

### 1.4 Create a Connection (via UI)
- Add **Source** (e.g., Postgres): host, port, db, user, password, SSL, etc.
- Add **Destination** (e.g., Postgres or S3).
- Create **Connection**:
  - **Sync mode**: Incremental (Append / Append + Deduped) or Full Refresh.
  - **Cursor field** (for Incremental): typically `updated_at`.
  - **Primary key** (for Deduped).
  - **Schedule**: manual, cron-like, or periodic.
- Click **Sync now** to test.

### 1.5 Manage lifecycle
```powershell
# Stop (keeping data)
abctl local uninstall

# Remove all persisted data
abctl local uninstall --persisted
# Then optionally remove the abctl home folder (if you want a clean slate):
# rm -r ~/.airbyte/abctl (on Linux/WSL); on Windows delete the corresponding folder
```

---

## 2) Local Setup on Linux (bash)

### 2.1 Install `abctl`
```bash
# Install abctl
curl -LsfS https://get.airbyte.com | bash -

# Verify
abctl version
```

### 2.2 Start Airbyte locally
```bash
# Standard local install
abctl local install

# Low-resource mode
abctl local install --low-resource-mode

# Custom host (domain) and insecure cookies (HTTP)
abctl local install --host airbyte.local --insecure-cookies
```

### 2.3 Credentials & UI Access
```bash
abctl local credentials
```
- UI at `http://localhost:8000` by default.
- Log in with the shown credentials; you can change password in the UI.

### 2.4 Create a Connection (via UI)
Same as the Windows section above.

### 2.5 Lifecycle
```bash
# Stop (preserving data)
abctl local uninstall

# Remove everything (including persisted state)
abctl local uninstall --persisted
rm -rf ~/.airbyte/abctl  # optional full cleanup
```

---

## 3) Scheduling Syncs

### 3.1 Use Airbyte’s built-in schedules
- When creating/editing a **Connection**, set a schedule (e.g., hourly, daily, or cron).
- Airbyte orchestrates the syncs for you.

### 3.2 External scheduler (optional)
- For tighter control or dependencies, trigger syncs via Airbyte API/CLI from **cron**, **Airflow**, or **Dagster**.
- Example cron calling HTTP API (pseudo):
```bash
# Example: trigger a connection by ID using curl (replace YOUR_TOKEN & CONNECTION_ID)
0 * * * * curl -X POST   -H "Authorization: Bearer YOUR_TOKEN"   -H "Content-Type: application/json"   -d '{"connectionId":"<CONNECTION_ID>"}'   http://localhost:8000/api/public/v1/connections/sync
```

---

## 4) When to Use CDC
- **Incremental cursor** won’t detect **hard deletes**. Use **CDC** (e.g., Postgres logical replication, MySQL binlog) to capture inserts/updates/deletes.
- Ensure proper DB configuration (e.g., wal_level, replication slots for Postgres; binlog enable for MySQL).

---

## 5) Production Deployment (Kubernetes + Helm)

### 5.1 Prerequisites
- Kubernetes cluster (EKS/GKE/AKS/k3s, etc.).
- `kubectl` and `helm` installed.
- A **domain** (for Ingress) and TLS (recommend cert-manager/Let’s Encrypt).
- External **Postgres** for Airbyte metadata (recommended for prod).
- Object storage (S3/MinIO) for logs/artifacts (recommended).

### 5.2 Minimal `values.yaml` (dev/single-node friendly)
```yaml
# values.yaml
global:
  edition: oss

webapp:
  service:
    type: ClusterIP

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: airbyte.example.com
      paths:
        - path: /
          pathType: Prefix

persistence:
  enabled: true
  size: 20Gi

server:
  resources:
    requests: { cpu: "250m", memory: "512Mi" }
    limits:   { cpu: "1",    memory: "1Gi" }

externalDatabase:
  enabled: false   # Use built-in DB for dev only (not recommended for prod)
```

Install:
```bash
helm repo add airbyte https://airbytehq.github.io/helm-charts
helm repo update
kubectl create namespace airbyte
helm upgrade --install airbyte airbyte/airbyte -n airbyte -f values.yaml
```

### 5.3 Production-ish `values.yaml` (external DB + S3/MinIO)
```yaml
global:
  edition: oss

# Use external Postgres for metadata
externalDatabase:
  enabled: true
  host: "pg.prod.internal"
  port: 5432
  database: "airbyte"
  user: "airbyte"
  existingSecret: "airbyte-db-secret"
  existingSecretPasswordKey: "password"

# Store logs/artifacts in S3 (or use MinIO config)
logs:
  storage: s3
  s3:
    bucket: "airbyte-logs"
    region: "ap-southeast-1"
    existingSecret: "airbyte-s3-secret"
    accessKeyId: "AWS_ACCESS_KEY_ID"
    secretAccessKey: "AWS_SECRET_ACCESS_KEY"

persistence:
  enabled: true
  size: 100Gi
  storageClass: "fast-ssd"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: airbyte.prod.example.com
      paths:
        - path: /
          pathType: Prefix

server:
  replicaCount: 2
  resources:
    requests: { cpu: "500m", memory: "1Gi" }
    limits:   { cpu: "2",    memory: "4Gi" }
```

Create required Secrets:
```bash
# DB password
kubectl create secret generic airbyte-db-secret   -n airbyte   --from-literal=password='YOUR_DB_PASSWORD'

# S3 credentials
kubectl create secret generic airbyte-s3-secret   -n airbyte   --from-literal=AWS_ACCESS_KEY_ID='YOUR_KEY'   --from-literal=AWS_SECRET_ACCESS_KEY='YOUR_SECRET'
```

Install/Upgrade:
```bash
helm upgrade --install airbyte airbyte/airbyte -n airbyte -f values.yaml
```

### 5.4 Operations (Helm/K8s)
```bash
# Upgrade after editing values.yaml
helm upgrade airbyte airbyte/airbyte -n airbyte -f values.yaml

# Rollback
helm rollback airbyte 1 -n airbyte

# Check pods
kubectl get pods -n airbyte
kubectl logs -n airbyte deploy/airbyte-server
```

---

## 6) Migration Paths
- **Dev → Prod**: Start with `abctl` locally. For production, move to Kubernetes with Helm.
- **Compose → abctl/Helm**: If you used old Docker Compose, migrate to `abctl` for dev or Helm for prod.

---

## 7) Monitoring & Alerting
- Expose metrics or send logs to centralized storage (e.g., Loki + Promtail + Grafana).
- For job failures, configure alerting (via your log/monitoring stack).

---

## 8) Backups & Disaster Recovery
- Back up the **Airbyte metadata database** (external Postgres).
- If using S3/MinIO for logs/artifacts, configure bucket versioning & lifecycle.
- For on-prem PVCs, ensure snapshots or storage-level backups.

---

## 9) Security Notes
- Restrict UI access (Ingress with auth/ip-whitelist, or behind VPN).
- Rotate credentials periodically.
- Store secrets in Kubernetes Secrets or a proper secrets manager (AWS/GCP).

---

## 10) Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| UI won’t load | Service not ready/port conflict | Check `abctl local status` (if available) or logs. Verify port 8000, stop conflicting services. |
| Can’t log in | Wrong credentials | Run `abctl local credentials` to retrieve/reset. |
| Sync re-reads all data | Connection set to Full Refresh or reset state | Use Incremental/CDC; don’t reset state unless needed. |
| Deletes not mirrored | Using cursor-based incremental | Enable CDC mode where supported. |
| OOM / slowness | Insufficient CPU/RAM | Use `--low-resource-mode` for dev, or allocate more resources in Helm. |
| Connector missing | Not installed/pulled | Search/install new connector in UI; for air-gapped, pre-pull images. |

---

## 11) Airbyte Cloud (Alternative)
If you don’t want to manage infrastructure, consider **Airbyte Cloud** (managed). You just configure sources, destinations, and connections.

---

### Appendix — Example Postgres Source Fields
- Host, Port, Database, Username, Password
- SSL mode (disable/allow/require/verify-ca/verify-full)
- **Replication**:
  - **Standard** (cursor-based incremental) → set **Cursor field** in stream settings.
  - **CDC** (logical decoding for Postgres) → requires WAL settings and replication slot. Consult DB admin.

---

**That’s it!** You can now run Airbyte locally with `abctl` and deploy production with Helm. Save this file in your repo as `AIRBYTE-SETUP.md`.
