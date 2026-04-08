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

owner_uid() {
  local path="$1"
  if stat --version >/dev/null 2>&1; then
    stat -c %u "$path"
  else
    stat -f %u "$path"
  fi
}

owner_gid() {
  local path="$1"
  if stat --version >/dev/null 2>&1; then
    stat -c %g "$path"
  else
    stat -f %g "$path"
  fi
}

for p in "$DATA_DIR" "$DATA_DIR/database" "$DATA_DIR/storage" "$DATA_DIR/ssl"; do
  OWNER_UID="$(owner_uid "$p")"
  OWNER_GID="$(owner_gid "$p")"
  if [[ "$OWNER_UID" != "10001" || "$OWNER_GID" != "10001" ]]; then
    echo "ERROR: $p owner is ${OWNER_UID}:${OWNER_GID}, expected 10001:10001."
    echo "Run: sudo chown -R 10001:10001 \"$DATA_DIR\""
    exit 1
  fi
done

has_env_value() {
  local key="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -q "^${key}=.+" "$ENV_FILE"
  else
    grep -Eq "^${key}=.+" "$ENV_FILE"
  fi
}

has_env_value "REPO_ADMIN_API_KEY" || { echo "ERROR: REPO_ADMIN_API_KEY missing"; exit 1; }
has_env_value "SYNC_API_SHARED_SECRET" || { echo "ERROR: SYNC_API_SHARED_SECRET missing"; exit 1; }
if [[ "$MODE" == "postgresql" ]]; then
  has_env_value "POSTGRES_PASSWORD" || { echo "ERROR: POSTGRES_PASSWORD missing"; exit 1; }
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null
echo "Preflight passed for $MODE."
