.PHONY: help help-build help-services help-modules help-webpanel help-dev help-docker help-test

# Default target
help:
	@echo "IRC Infrastructure Management"
	@echo "============================"
	@echo ""
	@echo "Available command groups:"
	@echo "  make help-build     - Building and compilation commands"
	@echo "  make help-services  - Service management commands"
	@echo "  make help-modules   - Module management commands"
	@echo "  make help-webpanel  - WebPanel management commands"
	@echo "  make help-dev       - Development and testing commands"
	@echo "  make help-docker    - Docker management commands"
	@echo ""
	@echo "Quick start:"
	@echo "  make quick-start    - Build and start all services"
	@echo "  make up             - Start all services"
	@echo "  make down           - Stop all services"
	@echo "  make status         - Check service status"
	@echo "  make logs           - View service logs"
	@echo ""
	@echo "Environment variables:"
	@echo "  NO_CACHE=1         - Build without cache"
	@echo "  TARGET=base|builder|runtime - Build specific stage"
	@echo "  MODULE=webpanel    - Target specific module for operations"

# Configuration
DOCKER_COMPOSE := docker compose
DOCKER := docker
SHELL := /bin/bash

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
NC := \033[0m # No Color

# ============================================================================
# BUILDING COMMANDS
# ============================================================================

help-build:
	@echo "Building Commands:"
	@echo "  build              - Build all services (default: runtime)"
	@echo "  build-base         - Build base stage only"
	@echo "  build-builder      - Build builder stage (includes compilation)"
	@echo "  build-runtime      - Build runtime stage (production image)"
	@echo "  build-webpanel     - Build webpanel service only"
	@echo ""
	@echo "Options:"
	@echo "  NO_CACHE=1         - Build without cache"
	@echo "  TARGET=base        - Build specific stage"
	@echo ""
	@echo "Usage examples:"
	@echo "  make build                    # Build all services"
	@echo "  make build-base               # Build base dependencies"
	@echo "  make build NO_CACHE=1        # Build without cache"
	@echo "  make build-webpanel          # Build only webpanel"

# Building operations
build:
	@echo -e "$(PURPLE)=== Building All Services ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Building IRC services..."
	$(DOCKER_COMPOSE) build
	@echo -e "$(GREEN)[SUCCESS]$(NC) All services built successfully!"

build-base:
	@echo -e "$(PURPLE)=== Building Base Stage ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Building base dependencies..."
	$(DOCKER) build --target base -t irc-atl-chat:base .
	@echo -e "$(GREEN)[SUCCESS]$(NC) Base stage built successfully!"

build-builder:
	@echo -e "$(PURPLE)=== Building Builder Stage ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Building with compilation..."
	$(DOCKER) build --target builder -t irc-atl-chat:builder .
	@echo -e "$(GREEN)[SUCCESS]$(NC) Builder stage built successfully!"

build-runtime:
	@echo -e "$(PURPLE)=== Building Runtime Stage ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Building production image..."
	$(DOCKER) build --target runtime -t irc-atl-chat:runtime .
	@echo -e "$(GREEN)[SUCCESS]$(NC) Runtime stage built successfully!"

build-webpanel:
	@echo -e "$(PURPLE)=== Building WebPanel ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Building webpanel service..."
	$(DOCKER_COMPOSE) build webpanel
	@echo -e "$(GREEN)[SUCCESS]$(NC) WebPanel built successfully!"

# ============================================================================
# SERVICE MANAGEMENT COMMANDS
# ============================================================================

help-services:
	@echo "Service Management Commands:"
	@echo "  up                 - Start all services in background"
	@echo "  down               - Stop and remove all services"
	@echo "  start              - Start services (alias for up)"
	@echo "  stop               - Stop services (alias for down)"
	@echo "  restart            - Restart all services"
	@echo "  status             - Show status of all services"
	@echo "  logs               - Show logs from all services"
	@echo "  logs-ircd          - Show UnrealIRCd logs"
	@echo "  logs-atheme        - Show Atheme logs"
	@echo "  logs-webpanel      - Show WebPanel logs"
	@echo ""
	@echo "Usage examples:"
	@echo "  make up             # Start all services"
	@echo "  make down           # Stop all services"
	@echo "  make status         # Check service status"
	@echo "  make logs-ircd      # View UnrealIRCd logs"

# Service operations
up:
	@echo -e "$(PURPLE)=== Starting Services ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Starting all services..."
	$(DOCKER_COMPOSE) up -d
	@echo -e "$(BLUE)[INFO]$(NC) Services started. Use 'make status' to check status."

down:
	@echo -e "$(PURPLE)=== Stopping Services ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Stopping all services..."
	$(DOCKER_COMPOSE) down
	@echo -e "$(GREEN)[SUCCESS]$(NC) All services stopped and removed."

start: ## Start services (alias for up)
	@$(MAKE) up

stop: ## Stop services (alias for down)
	@$(MAKE) down

restart:
	@echo -e "$(PURPLE)=== Restarting Services ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Restarting all services..."
	$(DOCKER_COMPOSE) restart
	@echo -e "$(GREEN)[SUCCESS]$(NC) Services restarted successfully!"

# Status and monitoring
status:
	@echo -e "$(PURPLE)=== Service Status ===$(NC)"
	$(DOCKER_COMPOSE) ps
	@echo ""
	@echo -e "$(BLUE)[INFO]$(NC) Health checks:"
	$(DOCKER_COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

logs:
	@echo -e "$(PURPLE)=== Service Logs ===$(NC)"
	$(DOCKER_COMPOSE) logs -f

logs-ircd:
	@echo -e "$(PURPLE)=== UnrealIRCd Logs ===$(NC)"
	$(DOCKER_COMPOSE) logs -f ircd

logs-atheme:
	@echo -e "$(PURPLE)=== Atheme Logs ===$(NC)"
	$(DOCKER_COMPOSE) logs -f atheme

logs-webpanel:
	@echo -e "$(PURPLE)=== WebPanel Logs ===$(NC)"
	$(DOCKER_COMPOSE) logs -f webpanel

# ============================================================================
# MODULE MANAGEMENT COMMANDS
# ============================================================================

help-modules:
	@echo "Module Management Commands:"
	@echo "  modules            - Show module management help"
	@echo "  modules-list      - List available contrib modules"
	@echo "  modules-info      - Show module information"
	@echo "  modules-install   - Install a module"
	@echo "  modules-remove    - Remove a module"
	@echo "  modules-update    - Update contrib repository"
	@echo "  modules-installed - Show installed modules"
	@echo ""
	@echo "Required variables:"
	@echo "  MODULE=webpanel   - Module name for install/remove operations"
	@echo ""
	@echo "Usage examples:"
	@echo "  make modules list                    # List available modules"
	@echo "  make modules install MODULE=webpanel # Install webpanel module"
	@echo "  make modules remove MODULE=webpanel  # Remove webpanel module"
	@echo "  make modules update                  # Update contrib repository"

# Module operations
modules:
	@echo -e "$(PURPLE)=== Module Management ===$(NC)"
	@echo "Available module commands:"
	@echo "  make modules list     # List available modules"
	@echo "  make modules info     # Show module information"
	@echo "  make modules install  # Install a module"
	@echo "  make modules remove   # Remove a module"
	@echo "  make modules update   # Update contrib repository"
	@echo ""
	@echo "Examples:"
	@echo "  make modules list"
	@echo "  make modules install MODULE=webpanel"
	@echo "  make modules remove MODULE=webpanel"

modules-list:
	@echo -e "$(PURPLE)=== Available Modules ===$(NC)"
	$(DOCKER_COMPOSE) exec ircd manage-modules list

modules-info:
	@echo -e "$(PURPLE)=== Module Information ===$(NC)"
	@if [ -z "$(MODULE)" ]; then \
		echo "Usage: make modules-info MODULE=<module-name>"; \
		echo "Example: make modules-info MODULE=webpanel"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) exec ircd manage-modules info $(MODULE)

modules-install:
	@echo -e "$(PURPLE)=== Installing Module ===$(NC)"
	@if [ -z "$(MODULE)" ]; then \
		echo "Usage: make modules-install MODULE=<module-name>"; \
		echo "Example: make modules-install MODULE=webpanel"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)[INFO]$(NC) Installing $(MODULE)..."
	$(DOCKER_COMPOSE) exec ircd manage-modules install $(MODULE)
	@echo -e "$(BLUE)[INFO]$(NC) Adding to configuration..."
	$(DOCKER_COMPOSE) exec ircd module-config add $(MODULE)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Module $(MODULE) installed and configured!"

modules-remove:
	@echo -e "$(PURPLE)=== Removing Module ===$(NC)"
	@if [ -z "$(MODULE)" ]; then \
		echo "Usage: make modules-remove MODULE=<module-name>"; \
		echo "Example: make modules-remove MODULE=webpanel"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)[INFO]$(NC) Removing $(MODULE) from configuration..."
	$(DOCKER_COMPOSE) exec ircd module-config remove $(MODULE)
	@echo -e "$(BLUE)[INFO]$(NC) Uninstalling $(MODULE)..."
	$(DOCKER_COMPOSE) exec ircd manage-modules uninstall $(MODULE)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Module $(MODULE) removed successfully!"

modules-update:
	@echo -e "$(PURPLE)=== Updating Contrib Repository ===$(NC)"
	$(DOCKER_COMPOSE) exec ircd manage-modules update

modules-installed:
	@echo -e "$(PURPLE)=== Installed Modules ===$(NC)"
	$(DOCKER_COMPOSE) exec ircd manage-modules installed

# ============================================================================
# WEBPANEL COMMANDS
# ============================================================================

help-webpanel:
	@echo "WebPanel Management Commands:"
	@echo "  webpanel           - Show webpanel access information"
	@echo "  webpanel-logs      - Show webpanel logs"
	@echo "  webpanel-shell     - Access webpanel container shell"
	@echo ""
	@echo "Usage examples:"
	@echo "  make webpanel           # Show access information"
	@echo "  make webpanel-logs      # View webpanel logs"
	@echo "  make webpanel-shell     # Access container shell"

# WebPanel operations
webpanel:
	@echo -e "$(PURPLE)=== WebPanel Access ===$(NC)"
	@echo "WebPanel URL: http://localhost:8080"
	@echo "IRC Server: localhost:6667 (standard) / localhost:6697 (SSL)"
	@echo "JSON-RPC API: localhost:8600 (internal)"
	@echo ""
	@echo "Default RPC credentials:"
	@echo "  User: adminpanel"
	@echo "  Password: webpanel_password_2024"
	@echo ""
	@echo "To access webpanel:"
	@echo "  1. Start services: make up"
	@echo "  2. Open browser: http://localhost:8080"
	@echo "  3. Follow setup wizard"

webpanel-logs:
	@$(MAKE) logs-webpanel

webpanel-shell:
	@echo -e "$(PURPLE)=== WebPanel Shell ===$(NC)"
	$(DOCKER_COMPOSE) exec webpanel bash

# ============================================================================
# DEVELOPMENT COMMANDS
# ============================================================================

help-dev:
	@echo "Development Commands:"
	@echo "  dev-shell          - Access IRC container shell for development"
	@echo "  dev-logs           - Show all logs with timestamps"
	@echo "  test               - Run basic tests and validation"
	@echo "  lint               - Run linting checks on scripts"
	@echo ""
	@echo "Usage examples:"
	@echo "  make dev-shell     # Access container shell"
	@echo "  make dev-logs      # View development logs"
	@echo "  make test          # Run validation tests"
	@echo "  make lint          # Check code quality"

# Development operations
dev-shell:
	@echo -e "$(PURPLE)=== Development Shell ===$(NC)"
	$(DOCKER_COMPOSE) exec ircd bash

dev-logs:
	@echo -e "$(PURPLE)=== Development Logs ===$(NC)"
	$(DOCKER_COMPOSE) logs -f --timestamps

# Testing and validation
test:
	@echo -e "$(PURPLE)=== Running Tests ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Checking Docker Compose configuration..."
	$(DOCKER_COMPOSE) config --quiet
	@echo -e "$(GREEN)[SUCCESS]$(NC) Docker Compose configuration is valid!"
	@echo -e "$(BLUE)[INFO]$(NC) Checking service health..."
	@if $(DOCKER_COMPOSE) ps | grep -q "Up"; then \
		echo -e "$(GREEN)[SUCCESS]$(NC) Services are running!"; \
	else \
		echo -e "$(YELLOW)[WARNING]$(NC) No services are currently running."; \
		echo -e "$(BLUE)[INFO]$(NC) Start services with: make up"; \
	fi

lint:
	@echo -e "$(PURPLE)=== Linting Scripts ===$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo -e "$(BLUE)[INFO]$(NC) Running shellcheck..."; \
		shellcheck scripts/*.sh; \
		echo -e "$(GREEN)[SUCCESS]$(NC) Shellcheck completed!"; \
	else \
		echo -e "$(YELLOW)[WARNING]$(NC) shellcheck not found. Install it for script validation."; \
	fi
	@if command -v hadolint >/dev/null 2>&1; then \
		echo -e "$(BLUE)[INFO]$(NC) Running hadolint..."; \
		hadolint Dockerfile web/webpanel/Dockerfile; \
		echo -e "$(GREEN)[SUCCESS]$(NC) Hadolint completed!"; \
	else \
		echo -e "$(YELLOW)[WARNING]$(NC) hadolint not found. Install it for Dockerfile validation."; \
	fi

# ============================================================================
# DOCKER COMMANDS
# ============================================================================

help-docker:
	@echo "Docker Management Commands:"
	@echo "  docker-build      - Build Docker images with options"
	@echo "  docker-clean      - Clean up Docker resources"
	@echo "  docker-clean-all  - Remove everything including volumes"
	@echo "  docker-info       - Show Docker system information"
	@echo ""
	@echo "Options:"
	@echo "  NO_CACHE=1        - Build without cache"
	@echo "  TARGET=base       - Build specific stage"
	@echo "  VOLUMES=1         - Remove volumes on cleanup"
	@echo ""
	@echo "Usage examples:"
	@echo "  make docker-build NO_CACHE=1    # Build without cache"
	@echo "  make docker-clean               # Clean containers and images"
	@echo "  make docker-clean-all VOLUMES=1 # Full cleanup with volumes"

# Docker operations
docker-build:
	@echo -e "$(PURPLE)=== Building Docker Images ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Building with options: $(if $(NO_CACHE),NO_CACHE=1) $(if $(TARGET),TARGET=$(TARGET))"
	$(DOCKER) build $(if $(NO_CACHE),--no-cache) $(if $(TARGET),--target $(TARGET)) -t irc-atl-chat:$(or $(TARGET),latest) .

docker-clean:
	@echo -e "$(PURPLE)=== Cleaning Up ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Removing containers and networks..."
	$(DOCKER_COMPOSE) down
	@echo -e "$(BLUE)[INFO]$(NC) Removing unused images..."
	$(DOCKER) image prune -f
	@echo -e "$(GREEN)[SUCCESS]$(NC) Cleanup completed!"

docker-clean-all:
	@echo -e "$(PURPLE)=== Full Cleanup ===$(NC)"
	@echo -e "$(YELLOW)[WARNING]$(NC) This will remove ALL data including volumes!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo -e "$(BLUE)[INFO]$(NC) Removing everything..."; \
		$(DOCKER_COMPOSE) down -v; \
		$(DOCKER) system prune -af; \
		echo -e "$(GREEN)[SUCCESS]$(NC) Full cleanup completed!"; \
	else \
		echo -e "$(BLUE)[INFO]$(NC) Cleanup cancelled."; \
	fi

docker-info:
	@echo -e "$(PURPLE)=== Docker System Information ===$(NC)"
	@echo "Docker version:"
	$(DOCKER) --version
	@echo ""
	@echo "Docker Compose version:"
	$(DOCKER_COMPOSE) --version
	@echo ""
	@echo "Available disk space:"
	df -h . | tail -1
	@echo ""
	@echo "Memory usage:"
	free -h

# ============================================================================
# QUICK ACTIONS
# ============================================================================

quick-start: ## Quick start with build and run
	@$(MAKE) build
	@$(MAKE) up
	@$(MAKE) status
	@echo -e "$(GREEN)[SUCCESS]$(NC) Quick start completed! Access webpanel at http://localhost:8080"

quick-stop: ## Quick stop and cleanup
	@$(MAKE) down
	@$(MAKE) docker-clean
	@echo -e "$(GREEN)[SUCCESS]$(NC) Quick stop completed!"

# ============================================================================
# INFORMATION COMMANDS
# ============================================================================

version: ## Show version information
	@echo -e "$(PURPLE)=== Version Information ===$(NC)"
	@echo "IRC Infrastructure: 1.0.0"
	@echo "UnrealIRCd: 6.1.10"
	@echo "Atheme: 7.2.12"
	@echo "WebPanel: Latest from GitHub"
	@echo "Base Image: Debian Bookworm Slim"
	@echo "PHP: 8.2 with FPM"
	@echo "Web Server: Nginx"

info: ## Show system information
	@echo -e "$(PURPLE)=== System Information ===$(NC)"
	@echo "Docker version:"
	$(DOCKER) --version
	@echo ""
	@echo "Docker Compose version:"
	$(DOCKER_COMPOSE) --version
	@echo ""
	@echo "Available disk space:"
	df -h . | tail -1
	@echo ""
	@echo "Memory usage:"
	free -h
	@echo ""
	@echo "Current directory:"
	pwd

# ============================================================================
# INTERNAL TARGETS
# ============================================================================

check-services: ## Check if services are running
	@$(DOCKER_COMPOSE) ps --format "{{.Status}}" | grep -q "Up" || (echo "Services are not running. Use 'make up' to start them." && exit 1)

check-module: ## Check if MODULE variable is set
	@if [ -z "$(MODULE)" ]; then \
		echo "Error: MODULE variable not set"; \
		echo "Usage: make <target> MODULE=<module-name>"; \
		exit 1; \
	fi
