# Tillforge Repository Customer Install

This bundle is source-free and runs only prebuilt containers from GHCR.

Download from public distro repo:

```bash
sudo mkdir -p /opt
cd /opt
git clone https://github.com/Tillforge/tillforge-repository-distribution.git
cd tillforge-repository-distribution
```

If already cloned:

```bash
cd /opt/tillforge-repository-distribution
git pull
```

## 1) Prepare machine

- Install Docker + Docker Compose v2
- Create host data path:

```bash
sudo mkdir -p /data/tillforge-repo/{database,storage,ssl,clamav,clamav-app,postgres}
sudo chown -R 10001:10001 /data/tillforge-repo
```

If this machine already had a previous install, run the same `chown` command again before `make up-*`.

## 2) Configure environment

```bash
make init-sqlite
```

This interactive setup creates `.env` and asks for (or auto-generates):
- `REPO_ADMIN_API_KEY`
- `SYNC_API_SHARED_SECRET`

For PostgreSQL, use:

```bash
make init-postgresql
```

This also sets `POSTGRES_PASSWORD` and PostgreSQL connection variables automatically.

Network/ports note (important):
- Port `8001`: Repository web/API endpoint.
- Port `9001`: Sync API endpoint for server-to-server sync.
- Default bind is `127.0.0.1` (local-only).
- For VPC deployments where another instance must reach `9001`, set bind addresses to `0.0.0.0` in `.env`.

Recommended in VPC:

```env
REPO_BIND_ADDRESS=0.0.0.0
SYNC_BIND_ADDRESS=0.0.0.0
# Keep API key-only auth for /api/*
REPO_API_KEY_ONLY=true
# Keep docs closed in production
REPO_EXPOSE_API_DOCS=false
# Restrict accepted Host headers
REPO_ALLOWED_HOSTS=repo.example.com,localhost,127.0.0.1
# Allow only explicit browser origins if cross-origin is needed
# REPO_CORS_ALLOW_ORIGINS=https://repo.example.com
```

Firewall / security group rules:
- Allow inbound `8001` from intended public path (for example LB, reverse proxy, or explicit source range).
- Allow inbound `9001` only from private IPs/security-group of trusted sync peer instances.
- Do not expose `9001` to the public internet.

ClamAV note:
- ClamAV sidecar is enabled by default via Docker Compose.
- You do **not** need to uncomment ClamAV lines in `.env` for normal use.
- Auto scan schedule is configured in Admin UI (Malware Scan section). Settings persist in the app database.
- Startup race protection is enabled by default (scheduler waits before first auto-scan and retries sidecar readiness quietly).
- Only set `CLAMAV_TCP_HOST`, `CLAMAV_TCP_PORT`, `CLAMAV_SCAN_TARGET`, `CLAMAV_SCAN_TARGET_HOST`, `CLAMAV_SCAN_TIMEOUT_SECONDS`, `CLAMAV_ROOT_DIR`, `CLAMAV_QUARANTINE_ENABLED`, `CLAMAV_QUARANTINE_DIR`, `CLAMAV_AUTO_SCAN`, `CLAMAV_AUTO_SCAN_INTERVAL_SECONDS`, `CLAMAV_AUTO_SCAN_STARTUP_DELAY_SECONDS`, `CLAMAV_AUTO_SCAN_RETRY_DELAY_SECONDS` when you want non-default values.

Default image stays on:
- `REPO_IMAGE=ghcr.io/tillforge/tillforge-repository:latest`

Automatic TLS renewal is enabled by default in-container:
- `CERTBOT_AUTO_RENEW=true`
- `CERTBOT_RENEW_INTERVAL_SECONDS=21600`
- `CERTBOT_AUTO_RESTART_ON_RENEW=true`

Manual DNS certificates usually require manual renewal. For full unattended renewal, use a DNS API provider mode.

## 3) Start service

SQLite (recommended for most tenants):

```bash
make up-sqlite
```

PostgreSQL (optional):

```bash
make up-postgresql
```

## 4) Operations

```bash
make logs-sqlite
make down-sqlite
```

PostgreSQL equivalents:

```bash
make logs-postgresql
make down-postgresql
```

If Docker reports a container name conflict (for example `tillforge-repository already in use`), run:

```bash
make clean-conflicts
```

Or do a full resilient restart flow:

```bash
make recover-postgresql
# or
make recover-sqlite
```

Update to latest images and recreate running services:

```bash
make refresh-sqlite
# or
make refresh-postgresql
```

Run security posture self-check:

```bash
make security-check
```

## 5) Malware scanning (recommended)

This bundle starts a dedicated `clamav` container sidecar by default.  
The admin page can trigger scans and read status/log output through the repository API.

Behavior:
- Admin scan supports **on-demand** and scheduled auto-scan (configurable in Admin UI).
- Infected files are automatically moved to quarantine (`CLAMAV_QUARANTINE_ENABLED=true` by default).
- Audit events (scan start/completion, quarantine success/failure) are stored in a persistent audit log.
- Default quarantine path: `/data/tillforge-repo/clamav-app/quarantine`
- Default audit log path: `/data/tillforge-repo/clamav-app/audit.jsonl`

What gets scanned:
- `/data/tillforge-repo/storage` on the host
- mounted as `/data/storage` in both `repository` and `clamav` containers
- Admin/API status shows the in-container path (`/data/storage`), which maps to the host path above.

Check ClamAV sidecar health:

```bash
docker logs --tail=120 tillforge-repository-clamav
```

Optional: force malware DB refresh in sidecar:

```bash
docker exec tillforge-repository-clamav freshclam
```
