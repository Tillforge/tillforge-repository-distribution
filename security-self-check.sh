#!/bin/bash
set -euo pipefail

ENV_FILE="${1:-.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: missing $ENV_FILE"
  exit 1
fi

get_env_value() {
  local key="$1"
  local value
  value="$(awk -F= -v k="$key" '$1==k {sub(/^[[:space:]]+/, "", $2); print $2}' "$ENV_FILE" | tail -n 1)"
  echo "${value%$'\r'}"
}

to_bool() {
  local raw="${1:-}"
  local lower
  lower="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" == "1" || "$lower" == "true" || "$lower" == "yes" || "$lower" == "on" ]]
}

REPO_PORT="$(get_env_value REPO_PORT)"
REPO_PORT="${REPO_PORT:-8001}"
ADMIN_KEY="$(get_env_value REPO_ADMIN_API_KEY)"
PUBLIC_ACCESS_RAW="$(get_env_value REPO_PUBLIC_ACCESS)"
API_KEY_ONLY_RAW="$(get_env_value REPO_API_KEY_ONLY)"
EXPOSE_DOCS_RAW="$(get_env_value REPO_EXPOSE_API_DOCS)"
SSL_ENABLED_RAW="$(get_env_value REPO_SSL_ENABLED)"

if [[ -z "$ADMIN_KEY" ]]; then
  echo "ERROR: REPO_ADMIN_API_KEY is empty in $ENV_FILE"
  exit 1
fi

PUBLIC_ACCESS=false
if to_bool "$PUBLIC_ACCESS_RAW"; then
  PUBLIC_ACCESS=true
fi

API_KEY_ONLY=true
if [[ -n "$API_KEY_ONLY_RAW" ]] && ! to_bool "$API_KEY_ONLY_RAW"; then
  API_KEY_ONLY=false
fi

EXPOSE_DOCS=false
if to_bool "$EXPOSE_DOCS_RAW"; then
  EXPOSE_DOCS=true
fi

SSL_ENABLED=false
if to_bool "$SSL_ENABLED_RAW"; then
  SSL_ENABLED=true
fi

status_code() {
  local url="$1"
  shift
  local code
  # Keep check running even when curl reports transport errors (52, 56, etc).
  code="$(curl -k -sS -o /dev/null -w "%{http_code}" "$@" "$url" 2>/dev/null || true)"
  if [[ -z "$code" ]]; then
    code="000"
  fi
  echo "$code"
}

pick_base_url() {
  local -a candidates=()
  if [[ "$SSL_ENABLED" == "true" ]]; then
    candidates=("https://127.0.0.1:${REPO_PORT}" "http://127.0.0.1:${REPO_PORT}")
  else
    candidates=("http://127.0.0.1:${REPO_PORT}" "https://127.0.0.1:${REPO_PORT}")
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    local code
    code="$(status_code "${candidate}/health")"
    if [[ "$code" == "200" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  echo ""
  return 1
}

BASE_URL="$(pick_base_url || true)"
if [[ -z "$BASE_URL" ]]; then
  echo "ERROR: repository health endpoint is unreachable on both HTTP and HTTPS at 127.0.0.1:${REPO_PORT}"
  echo "Hint: check container status/logs:"
  echo "  docker ps | rg tillforge-repository"
  echo "  docker logs --tail=200 tillforge-repository"
  exit 1
fi

echo "== Tillforge Security Self Check =="
echo "Base URL: $BASE_URL"
echo "Public access: $PUBLIC_ACCESS"
echo "API key only: $API_KEY_ONLY"
echo "Expose docs: $EXPOSE_DOCS"
echo "SSL enabled (env): $SSL_ENABLED"
echo

assert_status() {
  local name="$1"
  local got="$2"
  local want="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $name (expected $want, got $got)"
    exit 1
  fi
  echo "OK:   $name ($got)"
}

health_code="$(status_code "${BASE_URL}/health")"
assert_status "health endpoint" "$health_code" "200"

if [[ "$PUBLIC_ACCESS" == "false" && "$API_KEY_ONLY" == "true" ]]; then
  no_key_code="$(status_code "${BASE_URL}/api/packages")"
  assert_status "api without key is blocked" "$no_key_code" "401"

  with_key_code="$(status_code "${BASE_URL}/api/packages" -H "Authorization: Bearer ${ADMIN_KEY}")"
  assert_status "api with key works" "$with_key_code" "200"
else
  echo "WARN: key-only assertion skipped (PUBLIC_ACCESS=$PUBLIC_ACCESS API_KEY_ONLY=$API_KEY_ONLY)"
fi

admin_stats_code="$(status_code "${BASE_URL}/admin/stats")"
if [[ "$admin_stats_code" == "401" || "$admin_stats_code" == "302" || "$admin_stats_code" == "404" ]]; then
  if [[ "$admin_stats_code" == "404" ]]; then
    echo "OK:   admin stats route not present in this build (404)"
  else
    echo "OK:   admin stats requires session ($admin_stats_code)"
  fi
else
  echo "FAIL: admin stats unexpectedly public ($admin_stats_code)"
  exit 1
fi

docs_code="$(status_code "${BASE_URL}/docs")"
if [[ "$EXPOSE_DOCS" == "true" ]]; then
  if [[ "$docs_code" == "200" || "$docs_code" == "302" || "$docs_code" == "401" ]]; then
    echo "OK:   docs endpoint exposed by config ($docs_code)"
  else
    echo "FAIL: docs expected exposed but got $docs_code"
    exit 1
  fi
else
  if [[ "$docs_code" == "404" || "$docs_code" == "302" || "$docs_code" == "401" ]]; then
    echo "OK:   docs not publicly available ($docs_code)"
  else
    echo "FAIL: docs unexpectedly open ($docs_code)"
    exit 1
  fi
fi

echo
echo "Security self-check passed."
