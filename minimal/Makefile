/-!
# Makefile for lean-worker project
-/

.PHONY: help build test infra verify clean

help:
	@echo "Available targets:"
	@echo "  make build     - Build the project"
	@echo "  make test      - Run tests"
	@echo "  make infra     - Generate infrastructure files"
	@echo "  make verify    - Run comprehensive verification"
	@echo "  make clean     - Clean build artifacts"

build:
	./minimal/Gokujo.lean bootstrap -o lean-worker --backend system

test:
	./minimal/Gokujo.lean check minimal/RequestProject

infra:
	./minimal/Gokujo.lean infra

verify:
	./minimal/Gokujo.lean check minimal/RequestProject --stage full

clean:
	rm -rf .lake build