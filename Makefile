.PHONY: help

# Default target - comprehensive help
help:
	@echo "IRC Infrastructure Management"
	@echo "============================"
	@echo ""
	@echo "QUICK START:"
	@echo "  make quick-start    - Build and start all services"
	@echo "  make up             - Start all services"
	@echo "  make down           - Stop all services"
	@echo ""
	@echo "CORE COMMANDS:"
	@echo "  make build          - Build all services"
	@echo "  make up             - Start services"
	@echo "  make down           - Stop services"
	@echo "  make restart        - Restart services"
	@echo "  make status         - Check service status"
	@echo "  make logs           - View all logs"
	@echo ""
	@echo "SERVICE LOGS:"
	@echo "  make logs-ircd      - UnrealIRCd logs"
	@echo "  make logs-atheme    - Atheme logs"
	@echo "  make logs-webpanel  - WebPanel logs"
	@echo ""
	@echo "DEVELOPMENT:"
	@echo "  make dev-shell      - Access IRC container shell"
	@echo "  make test           - Run basic validation"
	@echo "  make lint           - Check code quality"
	@echo ""
	@echo "SSL MANAGEMENT:"
	@echo "  make ssl-setup      - One-command SSL setup"
	@echo "  make ssl-status     - Check SSL status"
	@echo "  make ssl-renew      - Force certificate renewal"
	@echo "  make ssl-logs       - View SSL logs"
	@echo "  make ssl-stop       - Stop SSL monitoring"
	@echo "  make ssl-clean      - Remove SSL certificates (CAUTION!)"
	@echo ""
	@echo "MAINTENANCE:"
	@echo "  make clean          - Clean containers and images"
	@echo "  make info           - System information"
	@echo ""
	@echo "ENVIRONMENT VARIABLES:"
	@echo "  NO_CACHE=1          - Build without cache"

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

# Building operations
build:
	@echo -e "$(PURPLE)=== Building All Services ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Building IRC services..."
	$(DOCKER_COMPOSE) build $(if $(NO_CACHE),--no-cache)
	@echo -e "$(GREEN)[SUCCESS]$(NC) All services built successfully!"

# ============================================================================
# SERVICE MANAGEMENT COMMANDS
# ============================================================================

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
# MODULE MANAGEMENT (Advanced)
# ============================================================================

modules-list:
	@echo -e "$(PURPLE)=== Available Modules ===$(NC)"
	$(DOCKER_COMPOSE) exec ircd manage-modules list

modules-installed:
	@echo -e "$(PURPLE)=== Installed Modules ===$(NC)"
	$(DOCKER_COMPOSE) exec ircd manage-modules installed

# ============================================================================
# WEBPANEL COMMANDS
# ============================================================================

webpanel:
	@echo -e "$(PURPLE)=== WebPanel Access ===$(NC)"
	@echo "WebPanel URL: http://localhost:8080"
	@echo "IRC Server: localhost:6667 (standard) / localhost:6697 (SSL)"
	@echo ""
	@echo "To access webpanel:"
	@echo "  1. Start services: make up"
	@echo "  2. Open browser: http://localhost:8080"

# ============================================================================
# DEVELOPMENT COMMANDS
# ============================================================================

dev-shell:
	@echo -e "$(PURPLE)=== Development Shell ===$(NC)"
	$(DOCKER_COMPOSE) exec ircd bash

dev-logs:
	@echo -e "$(PURPLE)=== All Logs with Timestamps ===$(NC)"
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
		hadolint Containerfile web/webpanel/Containerfile; \
		echo -e "$(GREEN)[SUCCESS]$(NC) Hadolint completed!"; \
	else \
		echo -e "$(YELLOW)[WARNING]$(NC) hadolint not found. Install it for Containerfile validation."; \
	fi

# ============================================================================
# MAINTENANCE
# ============================================================================

clean:
	@echo -e "$(PURPLE)=== Cleaning Up ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) Removing containers and networks..."
	$(DOCKER_COMPOSE) down
	@echo -e "$(BLUE)[INFO]$(NC) Removing unused images..."
	$(DOCKER) image prune -f
	@echo -e "$(GREEN)[SUCCESS]$(NC) Cleanup completed!"

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
	@$(MAKE) clean
	@echo -e "$(GREEN)[SUCCESS]$(NC) Quick stop completed!"


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

# ============================================================================
# SSL MANAGEMENT (Simple & Automatic)
# ============================================================================

ssl-setup: ## One-command SSL setup - sets up everything automatically
	@echo -e "$(PURPLE)=== SSL Setup - One Command to Rule Them All ===$(NC)"
	@echo -e "$(BLUE)[INFO]$(NC) This will:"
	@echo -e "$(BLUE)[INFO]$(NC)   1. Issue SSL certificates for your domain"
	@echo -e "$(BLUE)[INFO]$(NC)   2. Start automatic Docker monitoring"
	@echo -e "$(BLUE)[INFO]$(NC)   3. Configure daily renewal at 2 AM"
	@echo ""
	@./scripts/ssl-manager.sh issue
	@docker compose up -d ssl-monitor
	@echo ""
	@echo -e "$(GREEN)[SUCCESS]$(NC) SSL is now fully automated!"
	@echo -e "$(BLUE)[INFO]$(NC) Certificates will renew automatically every day at 2 AM"
	@echo -e "$(BLUE)[INFO]$(NC) Check status anytime with: make ssl-status"

ssl-status: ## Check SSL certificate status
	@echo -e "$(PURPLE)=== SSL Certificate Status ===$(NC)"
	@if [[ -f "unrealircd/conf/tls/server.cert.pem" ]]; then \
		./scripts/ssl-manager.sh check; \
		echo ""; \
		docker compose ps ssl-monitor | grep -q "Up" && echo -e "$(GREEN)[OK]$(NC) SSL monitoring is running" || echo -e "$(YELLOW)[WARNING]$(NC) SSL monitoring is not running"; \
	else \
		echo -e "$(YELLOW)[INFO]$(NC) No SSL certificates found. Run 'make ssl-setup' to get started."; \
	fi

ssl-renew: ## Force certificate renewal
	@echo -e "$(PURPLE)=== Forcing SSL Certificate Renewal ===$(NC)"
	@if [[ -f "unrealircd/conf/tls/server.cert.pem" ]]; then \
		./scripts/ssl-manager.sh renew; \
	else \
		echo -e "$(YELLOW)[WARNING]$(NC) No SSL certificates found. Run 'make ssl-setup' first."; \
	fi

ssl-logs: ## View SSL monitoring logs
	@echo -e "$(PURPLE)=== SSL Monitoring Logs ===$(NC)"
	@docker compose logs -f ssl-monitor --tail=50

ssl-stop: ## Stop SSL monitoring
	@echo -e "$(PURPLE)=== Stopping SSL Monitoring ===$(NC)"
	@docker compose down ssl-monitor
	@echo -e "$(GREEN)[SUCCESS]$(NC) SSL monitoring stopped"

ssl-clean: ## Remove SSL certificates and monitoring (CAUTION: destroys certificates!)
	@echo -e "$(RED)=== WARNING: This will DELETE your SSL certificates! ===$(NC)"
	@echo -e "$(YELLOW)This action cannot be undone.$(NC)"
	@echo ""
	@read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm && \
	if [[ "$$confirm" == "yes" ]]; then \
		echo -e "$(BLUE)[INFO]$(NC) Removing SSL certificates..."; \
		rm -rf data/letsencrypt unrealircd/conf/tls; \
		docker compose down ssl-monitor; \
		echo -e "$(GREEN)[SUCCESS]$(NC) SSL certificates and monitoring removed."; \
	else \
		echo -e "$(YELLOW)[CANCELLED]$(NC) SSL cleanup cancelled."; \
	fi

# ============================================================================
# UTILITIES
# ============================================================================

generate-password: ## Generate new IRC operator password hash
	@echo -e "$(PURPLE)=== Generating IRC Operator Password ===$(NC)"
	@./scripts/generate-oper-password.sh
