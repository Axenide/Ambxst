SHELL := /bin/bash

# Ambxst Go backend binary (repo root, gitignored)
BINARY := ambxst
BACKEND_DIR := backend

GO ?= go
GOFLAGS ?=

.PHONY: all build vet lint run nix clean dev

all: build

## build: compile the Go backend into $(BINARY) at the repo root
build:
	@cd $(BACKEND_DIR) && $(GO) build $(GOFLAGS) -o ../$(BINARY) ./cmd/ambxst
	@echo "Built ./$(BINARY)"

## vet: run go vet on the backend
vet:
	@cd $(BACKEND_DIR) && $(GO) vet ./...

## lint: go vet + QML lint (best effort)
lint: vet

## run: build and launch the shell via the Go binary (needs Hyprland + Quickshell)
run: build
	@./$(BINARY)

## dev: build then run with live QML reload (editing shell.qml restarts)
dev: build
	@./$(BINARY)

## nix: build the backend package via Nix (NixOS / Nix installs)
nix:
	@cd $(BACKEND_DIR) && git -C .. add backend 2>/dev/null; nix build '.#packages.$(shell uname -m)-linux.backend' --no-link --print-out-paths

## clean: remove the compiled binary
clean:
	@rm -f $(BINARY)
	@echo "Removed ./$(BINARY)"

## Rebuild binary and run the daemon (headless test)
daemon: build
	@./$(BINARY) daemon
