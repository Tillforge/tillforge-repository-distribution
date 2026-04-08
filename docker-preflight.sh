#!/bin/bash
set -euo pipefail

MODE="${1:-sqlite}"
DATA_DIR="${DATA_DIR:-/data/tillforge-repo}"
ENV_FILE="${ENV_FILE:-.env}"

if [[ "$MODE" != "sqlite" && "$MODE" != "postgresql" ]]; then
  echo "ERROR: Use sqlite or postgresql"
  exit 1
fi

COMPOSE_FILE="docker-compose.${MODE}.yml"

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: docker daemon not reachable"; exit 1; }
[[ -f "$COMPOSE_FILE" ]] || { echo "ERROR: missing $COMPOSE_FILE"; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "ERROR: missing $ENV_FILE (copy .env.example first)"; exit 1; }

mkdir -p "$DATA_DIR/database" "$DATA_DIR/storage" "$DATA_DIR/ssl"

OWNER_UID="$(stat -f %u "$DATA_DIR")"
OWNER_GID="$(stat -f %g "$DATA_DIR")"
if [[ "$OWNER_UID" != "10001" || "$OWNER_GID" != "10001" ]]; then
  echo "WARNING: $DATA_DIR owner is ${OWNER_UID}:${OWNER_GID}, recommended 10001:10001"
  echo "Run: sudo chown -R 10001:10001 \"$DATA_DIR\""
fi

rg -q "^REPO_ADMIN_API_KEY=" "$ENV_FILE" || { echo "ERROR: REPO_ADMIN_API_KEY missing"; exit 1; }
rg -q "^SYNC_API_SHARED_SECRET=" "$ENV_FILE" || { echo "ERROR: SYNC_API_SHARED_SECRET missing"; exit 1; }
if [[ "$MODE" == "postgresql" ]]; then
  rg -q "^POSTGRES_PASSWORD=" "$ENV_FILE" || { echo "ERROR: POSTGRES_PASSWORD missing"; exit 1; }
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null
echo "Preflight passed for $MODE."
