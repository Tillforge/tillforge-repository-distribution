# Tillforge Repository Customer Install

This bundle is source-free and runs only prebuilt containers from GHCR.

Download from public distro repo:

```bash
sudo mkdir -p /opt
cd /opt
git clone https://github.com/Tillforge/tillforge-repository-distribution.git
cd tillforge-repository-distribution
```

## 1) Prepare machine

- Install Docker + Docker Compose v2
- Create host data path:

```bash
sudo mkdir -p /data/tillforge-repo
sudo chown -R 10001:10001 /data/tillforge-repo
```

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

## 5) Malware scanning (recommended)

This bundle starts a dedicated `clamav` container sidecar by default.  
The admin page can trigger scans and read status/log output through the repository API.

What gets scanned:
- `/data/tillforge-repo/storage` on the host
- mounted as `/data/storage` in both `repository` and `clamav` containers

Check ClamAV sidecar health:

```bash
docker logs --tail=120 tillforge-repository-clamav
```

Optional: force malware DB refresh in sidecar:

```bash
docker exec tillforge-repository-clamav freshclam
```
