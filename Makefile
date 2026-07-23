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
CACHE_SERVERS_REMOTE_PATH ?= /var/cache/files/cache_servidores
CACHE_SERVERS_LOCAL_PATH ?= docker/var-cache/files/cache_servidores
CACHE_SERVER_FILES ?= cache_servers_.json cache_servers_ALERTA.json cache_servers_API.json cache_servers_GATEWAY.json cache_servers_HISTORY.json cache_servers_HISTORY2.json cache_servers_HISTORY3.json cache_servers_HISTORYWEB.json cache_servers_MASTER.json cache_servers_MONGODB.json cache_servers_MQTT.json cache_servers_OTHER.json cache_servers_PAQUETES.json cache_servers_PROCESSHIST.json cache_servers_PROCESSMQ.json cache_servers_REDISMQ.json cache_servers_REGION_DATACENTER.json cache_servers_SLAVE.json cache_servers_SLAVEDATOGPS.json cache_servers_STREAMING.json cache_servers_WEBGEO.json cache_servers_WEBSOCK.json cache_servers_WEBSRV.json last_update.txt
PYTHON ?= python3

.PHONY: up build down ps config \
	setup-wizard setup-wizard-dry-run doctor-qa \
	install-tools install-tools-linux install-tools-mac doctor hosts-print hosts-install \
	app-repos-status app-repos-pull app-repos-pull-dev app-repos-pull-qa \
	logs-dev logs-dev-apache logs-dev-php logs-dev-cli logs-dev-full \
	logs-qa logs-qa-apache logs-qa-php logs-qa-cli logs-qa-full logs-qa-fatal \
	logs-gateway logs-master logs-master-apache logs-master-php logs-master-cli logs-master-full \
	logs-clear logs-clear-dev logs-clear-qa logs-clear-gateway logs-clear-master \
	certs certs-install certs-install-linux certs-install-mac redis-config-qa cache-servers-qa cache-autoload-qa setup-qa vpn-qa

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
	docker/bin/install-tools Linux

install-tools-mac:
	docker/bin/install-tools Darwin

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

app-repos-status:
	docker/bin/update-app-repos all --status

app-repos-pull:
	docker/bin/update-app-repos all

app-repos-pull-dev:
	docker/bin/update-app-repos dev

app-repos-pull-qa:
	docker/bin/update-app-repos qa

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

# Muestra en tiempo real solo fallos PHP que detienen o impiden ejecutar la aplicacion.
logs-qa-fatal:
	@docker compose logs -f --tail="$${TAIL:-100}" qa_web | grep --line-buffered -Ei 'PHP (Fatal|Parse|Compile|Startup) error|Fatal error|Parse error|Uncaught (Error|Exception)|Allowed memory size.*exhausted'

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
	@if command -v certutil >/dev/null 2>&1; then \
		mkdir -p "$$HOME/.pki/nssdb"; \
		if [ ! -f "$$HOME/.pki/nssdb/cert9.db" ]; then \
			certutil -N --empty-password -d sql:"$$HOME/.pki/nssdb"; \
		fi; \
		certutil -D -d sql:"$$HOME/.pki/nssdb" -n redgps-local-dev-ca >/dev/null 2>&1 || true; \
		certutil -A -d sql:"$$HOME/.pki/nssdb" -t "C,," -n redgps-local-dev-ca -i docker/apache/certs/redgps-local-dev-ca.crt; \
		echo "CA local instalada en NSS para navegadores Chromium/Chrome del usuario."; \
	else \
		echo "certutil no esta instalado. Chrome/Chromium puede seguir mostrando el certificado en rojo."; \
		echo "Instala libnss3-tools/nss-tools y vuelve a ejecutar make certs-install-linux."; \
	fi

certs-install-mac:
	sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain docker/apache/certs/redgps-local-dev-ca.crt

redis-config-qa:
	scp -F $(SSH_CONFIG) $(SSHUTTLE_REMOTE):$(REDIS_REMOTE_PATH) $(REDIS_LOCAL_PATH)

cache-servers-qa:
	@mkdir -p "$(CACHE_SERVERS_LOCAL_PATH)"
	@ssh -F "$(SSH_CONFIG)" "$(SSHUTTLE_REMOTE)" 'cd "$(CACHE_SERVERS_REMOTE_PATH)" && set -- $(CACHE_SERVER_FILES); existing=""; for file do [ -f "$$file" ] && existing="$$existing $$file"; done; if [ -z "$$existing" ]; then echo "No se encontraron archivos cache_servers en $(CACHE_SERVERS_REMOTE_PATH)" >&2; exit 1; fi; tar -cf - $$existing' | tar -C "$(CACHE_SERVERS_LOCAL_PATH)" -xf -
	@echo "Cache de servidores actualizado en $(CACHE_SERVERS_LOCAL_PATH)."

cache-autoload-qa:
	@docker compose exec -T -w /var/www/html/web/redgps/public qa_web php -r 'require "/home/redgps/commons/libs/debug.php"; require "/var/www/html/web/atomic/Atomic.php"; $$app = Atomic::getInstance("bootstrap.php"); $$app->getAutoloadManager()->generate(); $$classes = include "/var/cache/files/autoloads/autoload_redgps"; echo "Autoload QA regenerado (" . count($$classes) . " clases)." . PHP_EOL;'

setup-qa:
	$(MAKE) install-tools
	$(MAKE) hosts-install
	$(MAKE) certs
	$(MAKE) certs-install
	$(MAKE) redis-config-qa
	$(MAKE) cache-servers-qa
	$(MAKE) build

vpn-qa:
	sshuttle $(SSHUTTLE_FLAGS) -r $(SSHUTTLE_REMOTE) -e "$(SSHUTTLE_SSH_CMD)" -x $(SSHUTTLE_EXCLUDE_REMOTE) -x $(SSHUTTLE_LOOPBACK_EXCLUDE) $(SSHUTTLE_ROUTES)
