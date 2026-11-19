.PHONY: up down init test smoke backup restore-test monitoring ci clean

COMPOSE ?= docker compose

up:
	./scripts/gen-certs.sh
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

init:
	set -a; . ./.env; set +a; \
	./minio/init.sh

smoke:
	set -a; . ./.env; set +a; \
	./scripts/smoke-test.sh

test:
	./tests/run-tests.sh

backup:
	$(COMPOSE) run --rm backup /usr/local/bin/backup.sh

restore-test:
	$(COMPOSE) run --rm backup /usr/local/bin/restore-test.sh

monitoring:
	$(COMPOSE) up -d backup-exporter prometheus grafana

ci:
	$(COMPOSE) config -q
	./tests/lint.sh

clean:
	$(COMPOSE) down -v
