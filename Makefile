.PHONY: help up-sqlite up-postgresql down-sqlite down-postgresql logs-sqlite logs-postgresql

ENV_FILE ?= .env

help:
	@echo "Customer bundle commands"
	@echo "  make up-sqlite"
	@echo "  make up-postgresql"
	@echo "  make down-sqlite"
	@echo "  make down-postgresql"
	@echo "  make logs-sqlite"
	@echo "  make logs-postgresql"

up-sqlite:
	./docker-preflight.sh sqlite
	docker compose --env-file $(ENV_FILE) -f docker-compose.sqlite.yml up -d

up-postgresql:
	./docker-preflight.sh postgresql
	docker compose --env-file $(ENV_FILE) -f docker-compose.postgresql.yml up -d

down-sqlite:
	docker compose --env-file $(ENV_FILE) -f docker-compose.sqlite.yml down

down-postgresql:
	docker compose --env-file $(ENV_FILE) -f docker-compose.postgresql.yml down

logs-sqlite:
	docker compose --env-file $(ENV_FILE) -f docker-compose.sqlite.yml logs -f

logs-postgresql:
	docker compose --env-file $(ENV_FILE) -f docker-compose.postgresql.yml logs -f
