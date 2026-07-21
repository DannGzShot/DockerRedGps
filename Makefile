# Autor: DannGzShot
# Fecha de creacion: 16/03/2026
# Descripcion: Centraliza comandos para levantar, construir y administrar el entorno Docker local.

-include .env
export

SSHUTTLE_REMOTE ?= qa
SSH_CONFIG ?= $(shell printf '%s/.ssh/config' "$$HOME")
SSHUTTLE_SSH_CMD ?= ssh -F $(SSH_CONFIG)
SSHUTTLE_EXCLUDE_HOST ?= $(shell ssh -F "$(SSH_CONFIG)" -G "$(SSHUTTLE_REMOTE)" 2>/dev/null | awk '$$1 == "hostname" {print $$2; exit}')
SSHUTTLE_EXCLUDE_PORT ?= $(shell ssh -F "$(SSH_CONFIG)" -G "$(SSHUTTLE_REMOTE)" 2>/dev/null | awk '$$1 == "port" {print $$2; exit}')
SSH_TUNNEL_EXCLUDE_HOST ?= $(if $(SSHUTTLE_EXCLUDE_HOST),$(SSHUTTLE_EXCLUDE_HOST),$(or $(SSH_TUNNEL_HOST),127.0.0.1))
SSH_TUNNEL_EXCLUDE_PORT ?= $(if $(SSHUTTLE_EXCLUDE_PORT),$(SSHUTTLE_EXCLUDE_PORT),$(or $(SSH_TUNNEL_PORT),22))
SSHUTTLE_EXCLUDE_REMOTE ?= $(SSH_TUNNEL_EXCLUDE_HOST):$(SSH_TUNNEL_EXCLUDE_PORT)
SSHUTTLE_LOOPBACK_EXCLUDE ?= 127.0.0.1/32
SSHUTTLE_ROUTES ?= 0/0
SSHUTTLE_FLAGS ?= --dns
REDIS_REMOTE_PATH ?= /home/redgps/redisCache.ini
REDIS_LOCAL_PATH ?= docker/php/redisCache.ini
PYTHON ?= python3

.PHONY: up build down ps config \
	setup-wizard setup-wizard-dry-run doctor-qa \
	install-tools install-tools-linux install-tools-mac doctor hosts-print hosts-install \
	logs-dev logs-dev-apache logs-dev-php logs-dev-cli logs-dev-full \
	logs-qa logs-qa-apache logs-qa-php logs-qa-cli logs-qa-full \
	logs-gateway logs-master logs-master-apache logs-master-php logs-master-cli logs-master-full \
	logs-clear logs-clear-dev logs-clear-qa logs-clear-gateway logs-clear-master \
	certs certs-install certs-install-linux certs-install-mac redis-config-qa setup-qa vpn-qa

up:
	docker compose up -d

build:
	docker compose up -d --build

down:
	docker compose down

ps:
	docker compose ps

config:
	docker compose config

setup-wizard:
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "Falta python3. Instala python3 o ejecuta make install-tools."; exit 1; }
	$(PYTHON) docker/bin/setup-wizard

setup-wizard-dry-run:
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "Falta python3. Instala python3 o ejecuta make install-tools."; exit 1; }
	$(PYTHON) docker/bin/setup-wizard --dry-run

doctor-qa:
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "Falta python3. Instala python3 o ejecuta make install-tools."; exit 1; }
	$(PYTHON) docker/bin/setup-wizard --doctor-only

install-tools:
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		$(MAKE) install-tools-mac; \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		$(MAKE) install-tools-linux; \
	else \
		echo "Sistema no soportado para instalacion automatica de herramientas: $$(uname -s)"; \
		exit 1; \
	fi

install-tools-linux:
	@set -eu; \
	if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update; \
		sudo apt-get install -y ca-certificates curl wget openssl sshuttle python3 || true; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y ca-certificates curl wget openssl sshuttle python3 || true; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y ca-certificates curl wget openssl sshuttle python3 || true; \
	elif command -v zypper >/dev/null 2>&1; then \
		sudo zypper --non-interactive install ca-certificates curl wget openssl sshuttle python3 || true; \
	elif command -v pacman >/dev/null 2>&1; then \
		sudo pacman -Sy --needed ca-certificates curl wget openssl sshuttle python || true; \
	elif command -v apk >/dev/null 2>&1; then \
		sudo apk add --no-cache ca-certificates curl wget openssl sshuttle python3 || true; \
	else \
		echo "No se detecto un gestor soportado para instalar paquetes base."; \
	fi; \
	if ! command -v sshuttle >/dev/null 2>&1 && command -v snap >/dev/null 2>&1; then \
		echo "Intentando instalar sshuttle con snap..."; \
		sudo snap install sshuttle || sudo snap install sshuttle --classic || true; \
	fi; \
	missing=""; \
	for tool in python3 openssl sshuttle; do \
		command -v "$$tool" >/dev/null 2>&1 || missing="$$missing $$tool"; \
	done; \
	if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then \
		missing="$$missing curl-o-wget"; \
	fi; \
	if [ -n "$$missing" ]; then \
		echo "Faltan herramientas despues de instalar:$$missing"; \
		echo "Instalalas manualmente o revisa permisos/repositorios del gestor de paquetes."; \
		exit 1; \
	fi

install-tools-mac:
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Homebrew no esta instalado. Instala Homebrew desde https://brew.sh/ y vuelve a ejecutar make install-tools."; \
		exit 1; \
	fi
	brew install python curl wget openssl@3 sshuttle

doctor:
	@command -v docker >/dev/null 2>&1 || { echo "Falta docker."; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "Falta Docker Compose v2."; exit 1; }
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "Falta python3. Ejecuta make install-tools."; exit 1; }
	@command -v sshuttle >/dev/null 2>&1 || { echo "Falta sshuttle. Ejecuta make install-tools."; exit 1; }
	@command -v openssl >/dev/null 2>&1 || { echo "Falta openssl. Ejecuta make install-tools."; exit 1; }
	@(command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1) || { echo "Falta curl o wget. Ejecuta make install-tools."; exit 1; }
	@echo "Herramientas basicas disponibles."

hosts-print:
	@printf '%s\n' \
		'127.0.0.1 dev.redgps.local' \
		'127.0.0.1 dev.reportes.local' \
		'127.0.0.1 dev.partners.local' \
		'127.0.0.1 qa.redgps.local' \
		'127.0.0.1 qa.reportes.local' \
		'127.0.0.1 qa.partners.local'

hosts-install:
	@if grep -q 'dev.redgps.local' /etc/hosts && grep -q 'qa.redgps.local' /etc/hosts; then \
		echo "Hosts locales ya estan configurados."; \
	else \
		{ \
			echo ''; \
			echo '# REDGPS Docker local'; \
			$(MAKE) --no-print-directory hosts-print; \
		} | sudo tee -a /etc/hosts >/dev/null; \
		echo "Hosts locales agregados a /etc/hosts."; \
	fi

logs-dev logs-dev-full:
	docker/bin/logs dev full

logs-dev-apache:
	docker/bin/logs dev apache

logs-dev-php:
	docker/bin/logs dev php

logs-dev-cli:
	docker/bin/logs dev cli

logs-qa logs-qa-full:
	docker/bin/logs qa full

logs-qa-apache:
	docker/bin/logs qa apache

logs-qa-php:
	docker/bin/logs qa php

logs-qa-cli:
	docker/bin/logs qa cli

logs-gateway:
	docker/bin/logs gateway full

logs-master logs-master-full logs-master-apache logs-master-php logs-master-cli:
	@echo "MASTER queda preparado, pero no esta integrado en este docker-compose."

logs-clear:
	docker/bin/clear-logs all

logs-clear-dev:
	docker/bin/clear-logs dev

logs-clear-qa:
	docker/bin/clear-logs qa

logs-clear-gateway:
	docker/bin/clear-logs gateway

logs-clear-master:
	docker/bin/clear-logs master

certs:
	docker/bin/generate-certs

certs-install:
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		$(MAKE) certs-install-mac; \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		$(MAKE) certs-install-linux; \
	else \
		echo "Sistema no soportado para instalar certificados automaticamente: $$(uname -s)"; \
		exit 1; \
	fi

certs-install-linux:
	sudo cp docker/apache/certs/redgps-local-dev-ca.crt /usr/local/share/ca-certificates/redgps-local-dev-ca.crt
	sudo update-ca-certificates

certs-install-mac:
	sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain docker/apache/certs/redgps-local-dev-ca.crt

redis-config-qa:
	scp -F $(SSH_CONFIG) $(SSHUTTLE_REMOTE):$(REDIS_REMOTE_PATH) $(REDIS_LOCAL_PATH)

setup-qa:
	$(MAKE) install-tools
	$(MAKE) hosts-install
	$(MAKE) certs
	$(MAKE) certs-install
	$(MAKE) redis-config-qa
	$(MAKE) build

vpn-qa:
	sshuttle $(SSHUTTLE_FLAGS) -r $(SSHUTTLE_REMOTE) -e "$(SSHUTTLE_SSH_CMD)" -x $(SSHUTTLE_EXCLUDE_REMOTE) -x $(SSHUTTLE_LOOPBACK_EXCLUDE) $(SSHUTTLE_ROUTES)
