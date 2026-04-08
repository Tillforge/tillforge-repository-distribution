# Tillforge Repository Customer Install

This bundle is source-free and runs only prebuilt containers from GHCR.

Download from public distro repo:

```bash
git clone https://github.com/<org>/<distro-repo>.git
cd <distro-repo>
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
cp .env.example .env
nano .env
```

Required values:
- `REPO_ADMIN_API_KEY`
- `SYNC_API_SHARED_SECRET`

For PostgreSQL mode also set:
- `POSTGRES_PASSWORD`

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
