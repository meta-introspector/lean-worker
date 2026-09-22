.PHONY: help build test infra verify clean

help:
	@echo "Available targets:"
	@echo "  make build     - Build the project"
	@echo "  make test      - Run tests"
	@echo "  make infra     - Generate infrastructure files"
	@echo "  make verify    - Run comprehensive verification"
	@echo "  make clean     - Clean build artifacts"

build:
	LEAN_PATH=. lean --run GokujoMain.lean bootstrap -o lean-worker --backend system

test:
	LEAN_PATH=. lean --run GokujoMain.lean check minimal/RequestProject

infra:
	LEAN_PATH=. lean --run GokujoMain.lean infra

verify:
	LEAN_PATH=. lean --run GokujoMain.lean check minimal/RequestProject --stage full

clean:
	rm -rf .lake build