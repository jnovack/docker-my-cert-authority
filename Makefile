.PHONY: clean build run dev all warning option restore rebuild showcert showkey showca showcrl
.DEFAULT_GOAL := all

DOMAIN?=domain.localhost
CN=default

IMAGE_EXISTS:=$(shell docker image inspect jnovack/my-cert-authority > /dev/null && echo 0 || echo 1 )
CONTAINER_EXISTS:=$(shell docker volume inspect ca-$(DOMAIN) -f {{.Name}} 2> /dev/null && echo 0 || echo 1 )

all: build run

clean:
	docker rmi jnovack/my-cert-authority || true
	docker volume rm ca-$(DOMAIN) || true

build:
	@if [[ "$(IMAGE_EXISTS)" == "1" ]]; then docker build -t jnovack/my-cert-authority .; fi

run: warning
	@echo "\n ** domain: $(DOMAIN)\n ** volume: ca-$(DOMAIN)\n"
	@if [[ "$(CONTAINER_EXISTS)" == "1" ]]; then docker volume create ca-$(DOMAIN) > /dev/null; fi
	@docker run -it --mount source=ca-$(DOMAIN),target=/opt --rm jnovack/my-cert-authority

dev: build
	@echo "\n ** domain: $(DOMAIN)\n ** volume: ca-$(DOMAIN)\n"
	docker run -it --mount source=ca-$(DOMAIN),target=/opt --entrypoint=/bin/sh --rm jnovack/my-cert-authority

rebuild:
	docker build -t jnovack/my-cert-authority .

warning:
	@if [[ "$(DOMAIN)" == "domain.localhost" ]]; then \
		echo "\n !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"; \
		echo " !!!! WARNING: Using default domain 'domain.localhost'                         !!!!"; \
		echo " !!!!   Run 'make DOMAIN=new.localhost option' to permanently change setting. !!!!"; \
		echo " !!!!   OR  'make DOMAIN=new.localhost' to temporarily work with new.localhost !!!!"; \
		echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"; \
	fi

option:
	@sed -i '' "s/^DOMAIN\?\=.*/DOMAIN\?\=${DOMAIN}/" Makefile
	@echo "Default domain set to: $(DOMAIN)"

restore:
	@sed -i '' "s/^DOMAIN\?\=.*/DOMAIN\?\=domain.localhost/" Makefile
	@echo "Default domain set to: domain.localhost"

showcert:
	@docker run -it --mount source=ca-$(DOMAIN),target=/opt --rm jnovack/my-cert-authority -p ${CN}

showkey:
	@docker run -it --mount source=ca-$(DOMAIN),target=/opt --rm jnovack/my-cert-authority -k ${CN}

showca:
	@docker run -it --mount source=ca-$(DOMAIN),target=/opt --rm jnovack/my-cert-authority -c

showcrl:
	@docker run -it --mount source=ca-$(DOMAIN),target=/opt --rm jnovack/my-cert-authority -l
