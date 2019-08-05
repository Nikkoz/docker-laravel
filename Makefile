#!/usr/bin/make

SHELL = /bin/sh
REGISTRY_HOST =
REGISTRY_PATH =
IMAGES_PREFIX := $(shell basename $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))
PUBLISH_TAGS = latest
PULL_TAG = latest

# Important: Local images naming should be in docker-compose naming style

#APP_IMAGE = $(REGISTRY_HOST)/$(REGISTRY_PATH)app
APP_IMAGE = $(REGISTRY_HOST):app
APP_IMAGE_LOCAL_TAG = $(IMAGES_PREFIX)_app
APP_IMAGE_DOCKERFILE = ./docker/app/Dockerfile
APP_IMAGE_CONTEXT = ./docker/app

#SOURCES_IMAGE = $(REGISTRY_HOST)/$(REGISTRY_PATH)sources
SOURCES_IMAGE = $(REGISTRY_HOST):soruces
SOURCES_IMAGE_LOCAL_TAG = $(IMAGES_PREFIX)_sources
SOURCES_IMAGE_DOCKERFILE = ./docker/sources/Dockerfile
SOURCES_IMAGE_CONTEXT = /var/www/html/banner-service

#NGINX_IMAGE = $(REGISTRY_HOST)/$(REGISTRY_PATH)nginx
NGINX_IMAGE = $(REGISTRY_HOST):nginx
NGINX_IMAGE_LOCAL_TAG = $(IMAGES_PREFIX)_nginx
NGINX_IMAGE_DOCKERFILE = ./docker/nginx/Dockerfile
NGINX_IMAGE_CONTEXT = ./docker/nginx

APP_CONTAINER_NAME := app
NODE_CONTAINER_NAME := node

docker_bin := $(shell command -v docker 2> /dev/null)
docker_compose_bin := $(shell command -v docker-compose 2> /dev/null)

include .env
export $(shell sed 's/=.*//' .env)

ifeq "$(docker_bin)" ""
	docker_message ?= "\n No docker installed"
	exit1
endif

ifeq "$(docker_compose_bin)" ""
	docker_message += "\n No docker-compose installed"
	exit1
endif

exit1: ## exit
	@echo $(docker_message)
	@echo "\n exiting"
	kill 2

up: ## Start all containers (in background) for development
	$(docker_compose_bin) up --no-recreate -d

laravel-install: up
	@echo "Installing fresh Laravel instance...\n"
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)"  sh -c "composer create-project --prefer-dist laravel/laravel ./laravel"
	@echo "Make: Clearing installation folder...\n"
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)"  sh -c "mv ./laravel/* ./ && rm -rf ./laravel"
	cp ./docker/example/.env.example ./src/.env

laravel-init: up
	@make -s init
	@make -s key-generate
	@make -s clean
	@echo "Laravel installation complete"

down: ## Stop all started for development containers
	$(docker_compose_bin) down

restart: up ## Restart all started for development containers
	$(docker_compose_bin) restart

clean:
	$(docker_bin) system prune --volumes --force

shell: up ## Start shell into application container
	@echo "$(APP_CONTAINER_NAME)"
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" /bin/sh

composer-install: up ## Install application dependencies into application container
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" composer install --no-interaction --ansi --no-suggest
	$(docker_compose_bin) run --rm "$(NODE_CONTAINER_NAME)" npm install

watch: up ## Start watching assets for changes (node)
	$(docker_compose_bin) run --rm "$(NODE_CONTAINER_NAME)" npm run watch

key-generate: ## Generate Laravel key
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" sh -c "php artisan key:generate"

helper-generate: ## Generate helper for IDE
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" sh -c "php artisan ide-helper:eloquent && php artisan ide-helper:generate && php artisan ide-helper:meta && php artisan ide-helper:models"

init: composer-install ## Make full application initialization (install, seed, build assets, etc)
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" php artisan migrate --force --no-interaction -vvv
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" php artisan db:seed --force -vvv

test: up ## Execute application tests
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" composer phpstan
	$(docker_compose_bin) exec "$(APP_CONTAINER_NAME)" composer test
