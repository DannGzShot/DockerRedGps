# Autor: DannGzShot
# Fecha de creacion: 16/03/2026
# Descripcion: Centraliza comandos para levantar, construir y administrar el entorno Docker local.

-include .env
export

SSHUTTLE_REMOTE ?= qa
SSH_TUNNEL_EXCLUDE_HOST ?= $(or $(SSH_TUNNEL_HOST),127.0.0.1)
REDIS_REMOTE_PATH ?= /home/redgps/redisCache.ini
REDIS_LOCAL_PATH ?= docker/php/redisCache.ini

.PHONY: up build down ps config \
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
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y ca-certificates curl openssl sshuttle; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y ca-certificates curl openssl sshuttle; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y ca-certificates curl openssl sshuttle; \
	elif command -v pacman >/dev/null 2>&1; then \
		sudo pacman -Sy --needed ca-certificates curl openssl sshuttle; \
	else \
		echo "No se detecto apt-get, dnf, yum ni pacman. Instala ca-certificates, curl, openssl y sshuttle manualmente."; \
		exit 1; \
	fi

install-tools-mac:
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "Homebrew no esta instalado. Instala Homebrew desde https://brew.sh/ y vuelve a ejecutar make install-tools."; \
		exit 1; \
	fi
	brew install openssl@3 sshuttle

doctor:
	@command -v docker >/dev/null 2>&1 || { echo "Falta docker."; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "Falta Docker Compose v2."; exit 1; }
	@command -v sshuttle >/dev/null 2>&1 || { echo "Falta sshuttle. Ejecuta make install-tools."; exit 1; }
	@command -v openssl >/dev/null 2>&1 || { echo "Falta openssl. Ejecuta make install-tools."; exit 1; }
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
	scp -F $$HOME/.ssh/config $(SSHUTTLE_REMOTE):$(REDIS_REMOTE_PATH) $(REDIS_LOCAL_PATH)

setup-qa:
	$(MAKE) install-tools
	$(MAKE) hosts-install
	$(MAKE) certs
	$(MAKE) certs-install
	$(MAKE) redis-config-qa
	$(MAKE) build

vpn-qa:
	sudo sshuttle --dns --disable-ipv6 -r $(SSHUTTLE_REMOTE) -e "ssh -F $$HOME/.ssh/config" -x $(SSH_TUNNEL_EXCLUDE_HOST)/32 -x 127.0.0.0/8 0/0
