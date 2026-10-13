.PHONY: build all shell stop services api test typecheck check docs setup-python check-python
.DEFAULT_GOAL := all

VENV_PYTHON := $(CURDIR)/.venv/bin/python
PYTHON ?= python3

setup-python:
	$(PYTHON) -I -c 'import sys; sys.exit(0 if sys.version_info[:2] == (3, 14) else "Python 3.14 is required")'
	$(PYTHON) -I -m venv .venv
	$(VENV_PYTHON) -m pip install --upgrade pip
	$(VENV_PYTHON) -m pip install --group dev --group docs -e .
	$(VENV_PYTHON) -m pip check

check-python:
	@test -x "$(VENV_PYTHON)" || { echo "Run make setup-python first."; exit 1; }
	@$(VENV_PYTHON) -c 'import sys; assert sys.prefix != sys.base_prefix and sys.version_info[:2] == (3, 14), "Recreate .venv with Python 3.14"'


all:
	make api

build:
	docker compose build app

shell: build
	docker compose run --rm app bash

stop:
	docker compose down

services:
	docker compose -f docker-compose.yml up --remove-orphans -d index

api: build services
	docker compose up --remove-orphans app

test: check-python
	$(VENV_PYTHON) -m pytest --cov-report html --cov-report term --cov=yente -v tests

typecheck: check-python
	$(VENV_PYTHON) -m mypy --strict yente

check: typecheck test

docs: check-python
	$(VENV_PYTHON) -m mkdocs build -c -d site
