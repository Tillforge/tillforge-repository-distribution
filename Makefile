SHELL := /bin/bash
.PHONY: help init-sqlite init-postgresql check-env up-sqlite up-postgresql down-sqlite down-postgresql logs-sqlite logs-postgresql

ENV_FILE ?= .env

help:
	@echo "Customer bundle commands"
	@echo "  make init-sqlite      # create $(ENV_FILE) with generated/entered secrets"
	@echo "  make init-postgresql  # same + postgres password and backend settings"
	@echo "  make up-sqlite"
	@echo "  make up-postgresql"
	@echo "  make down-sqlite"
	@echo "  make down-postgresql"
	@echo "  make logs-sqlite"
	@echo "  make logs-postgresql"

init-sqlite:
	@if [[ -f "$(ENV_FILE)" ]]; then \
		echo "ERROR: $(ENV_FILE) already exists. Remove it first or set ENV_FILE=..."; \
		exit 1; \
	fi
	@cp .env.example "$(ENV_FILE)"
	@ADMIN_KEY="$$(openssl rand -hex 24 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(24))')"; \
	SYNC_SECRET="$$(openssl rand -hex 32 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(32))')"; \
	read -r -p "REPO_ADMIN_API_KEY (Enter = auto-generate): " INPUT_ADMIN; \
	read -r -p "SYNC_API_SHARED_SECRET (Enter = auto-generate): " INPUT_SYNC; \
	if [[ -n "$$INPUT_ADMIN" ]]; then ADMIN_KEY="$$INPUT_ADMIN"; fi; \
	if [[ -n "$$INPUT_SYNC" ]]; then SYNC_SECRET="$$INPUT_SYNC"; fi; \
	ESC_ADMIN="$$(printf '%s' "$$ADMIN_KEY" | sed -e 's/[\\/&]/\\&/g')"; \
	ESC_SYNC="$$(printf '%s' "$$SYNC_SECRET" | sed -e 's/[\\/&]/\\&/g')"; \
	sed -i.bak "s|^REPO_ADMIN_API_KEY=.*|REPO_ADMIN_API_KEY=$$ESC_ADMIN|" "$(ENV_FILE)"; \
	sed -i.bak "s|^SYNC_API_SHARED_SECRET=.*|SYNC_API_SHARED_SECRET=$$ESC_SYNC|" "$(ENV_FILE)"; \
	sed -i.bak "s|^REPO_DB_BACKEND=.*|REPO_DB_BACKEND=sqlite|" "$(ENV_FILE)"; \
	sed -i.bak "s|^SYNC_DB_BACKEND=.*|SYNC_DB_BACKEND=sqlite|" "$(ENV_FILE)"; \
	rm -f "$(ENV_FILE).bak"; \
	echo "SUCCESS: $(ENV_FILE) created for SQLite mode."

init-postgresql:
	@if [[ -f "$(ENV_FILE)" ]]; then \
		echo "ERROR: $(ENV_FILE) already exists. Remove it first or set ENV_FILE=..."; \
		exit 1; \
	fi
	@cp .env.example "$(ENV_FILE)"
	@ADMIN_KEY="$$(openssl rand -hex 24 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(24))')"; \
	SYNC_SECRET="$$(openssl rand -hex 32 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(32))')"; \
	PG_PASSWORD="$$(openssl rand -hex 24 2>/dev/null || python3 -c 'import secrets; print(secrets.token_hex(24))')"; \
	read -r -p "REPO_ADMIN_API_KEY (Enter = auto-generate): " INPUT_ADMIN; \
	read -r -p "SYNC_API_SHARED_SECRET (Enter = auto-generate): " INPUT_SYNC; \
	read -r -p "POSTGRES_PASSWORD (Enter = auto-generate): " INPUT_PG; \
	if [[ -n "$$INPUT_ADMIN" ]]; then ADMIN_KEY="$$INPUT_ADMIN"; fi; \
	if [[ -n "$$INPUT_SYNC" ]]; then SYNC_SECRET="$$INPUT_SYNC"; fi; \
	if [[ -n "$$INPUT_PG" ]]; then PG_PASSWORD="$$INPUT_PG"; fi; \
	PG_PASSWORD_URL="$$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$$PG_PASSWORD")"; \
	ESC_ADMIN="$$(printf '%s' "$$ADMIN_KEY" | sed -e 's/[\\/&]/\\&/g')"; \
	ESC_SYNC="$$(printf '%s' "$$SYNC_SECRET" | sed -e 's/[\\/&]/\\&/g')"; \
	ESC_PG="$$(printf '%s' "$$PG_PASSWORD" | sed -e 's/[\\/&]/\\&/g')"; \
	ESC_PG_URL="$$(printf '%s' "$$PG_PASSWORD_URL" | sed -e 's/[\\/&]/\\&/g')"; \
	sed -i.bak "s|^REPO_ADMIN_API_KEY=.*|REPO_ADMIN_API_KEY=$$ESC_ADMIN|" "$(ENV_FILE)"; \
	sed -i.bak "s|^SYNC_API_SHARED_SECRET=.*|SYNC_API_SHARED_SECRET=$$ESC_SYNC|" "$(ENV_FILE)"; \
	sed -i.bak "s|^REPO_DB_BACKEND=.*|REPO_DB_BACKEND=postgresql|" "$(ENV_FILE)"; \
	sed -i.bak "s|^SYNC_DB_BACKEND=.*|SYNC_DB_BACKEND=postgresql|" "$(ENV_FILE)"; \
	sed -i.bak "s|^# POSTGRES_DB=.*|POSTGRES_DB=repository|" "$(ENV_FILE)"; \
	sed -i.bak "s|^# POSTGRES_USER=.*|POSTGRES_USER=repo_user|" "$(ENV_FILE)"; \
	sed -i.bak "s|^# POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$$ESC_PG|" "$(ENV_FILE)"; \
	sed -i.bak "s|^# REPO_DATABASE_URL=.*|REPO_DATABASE_URL=postgresql://repo_user:$$ESC_PG_URL@postgres:5432/repository|" "$(ENV_FILE)"; \
	sed -i.bak "s|^# SYNC_DB_NAME=.*|SYNC_DB_NAME=pos_cmdb|" "$(ENV_FILE)"; \
	sed -i.bak "s|^# SYNC_DATABASE_URL=.*|SYNC_DATABASE_URL=postgresql://repo_user:$$ESC_PG_URL@postgres:5432/pos_cmdb|" "$(ENV_FILE)"; \
	rm -f "$(ENV_FILE).bak"; \
	echo "SUCCESS: $(ENV_FILE) created for PostgreSQL mode."

check-env:
	@if [[ ! -f "$(ENV_FILE)" ]]; then \
		echo "ERROR: $(ENV_FILE) not found. Run 'make init-sqlite' or 'make init-postgresql' first."; \
		exit 1; \
	fi

up-sqlite: check-env
	./docker-preflight.sh sqlite
	docker compose --env-file $(ENV_FILE) -f docker-compose.sqlite.yml up -d

up-postgresql: check-env
	./docker-preflight.sh postgresql
	docker compose --env-file $(ENV_FILE) -f docker-compose.postgresql.yml up -d

down-sqlite: check-env
	docker compose --env-file $(ENV_FILE) -f docker-compose.sqlite.yml down

down-postgresql: check-env
	docker compose --env-file $(ENV_FILE) -f docker-compose.postgresql.yml down

logs-sqlite: check-env
	docker compose --env-file $(ENV_FILE) -f docker-compose.sqlite.yml logs -f

logs-postgresql: check-env
	docker compose --env-file $(ENV_FILE) -f docker-compose.postgresql.yml logs -f
