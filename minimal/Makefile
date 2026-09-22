.PHONY: help build test infra verify clean

help:
	@echo "Available targets:"
	@echo "  make build     - Build the project"
	@echo "  make test      - Run tests"
	@echo "  make infra     - Generate infrastructure files"
	@echo "  make verify    - Run comprehensive verification"
	@echo "  make clean     - Clean build artifacts"

build:
	./gokujo bootstrap -o lean-worker --backend system

test:
	./gokujo check minimal/RequestProject

infra:
	./gokujo infra

verify:
	./gokujo check minimal/RequestProject --stage full

clean:
	rm -rf .lake build
