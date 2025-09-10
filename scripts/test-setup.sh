#!/bin/bash

# Test script for UnrealIRCd Docker setup
# This script tests the rebuilt setup

# Don't use set -e for testing script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test functions
test_build() {
    log_info "Testing Docker build..."

    if docker build -f Containerfile -t irc-atl-chat-test .; then
        log_success "Docker build successful"
        return 0
    else
        log_error "Docker build failed"
        return 1
    fi
}

test_config() {
    log_info "Testing configuration..."

    # Check if config template exists
    if [ ! -f "unrealircd/conf/unrealircd.conf.template" ]; then
        log_error "Configuration template not found"
        return 1
    fi

    # Check if .env exists
    if [ ! -f ".env" ]; then
        log_warning ".env file not found, creating from example"
        if [ -f "env.example" ]; then
            cp env.example .env
            log_info "Created .env from template"
        else
            log_error "No .env template found"
            return 1
        fi
    fi

    log_success "Configuration check passed"
    return 0
}

test_directories() {
    log_info "Testing directory structure..."

    local required_dirs=(
        "unrealircd/conf"
        "unrealircd/logs"
        "unrealircd/data"
        "scripts"
    )

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory missing: $dir"
            return 1
        fi
    done

    log_success "Directory structure check passed"
    return 0
}

test_permissions() {
    log_info "Testing permissions..."

    # Check if scripts are executable
    local scripts=(
        "scripts/docker-entrypoint.sh"
        "scripts/health-check.sh"
        "scripts/init.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            log_warning "Making $script executable"
            chmod +x "$script"
        fi
    done

    log_success "Permissions check passed"
    return 0
}

# Main test function
main() {
    log_info "Testing UnrealIRCd Docker Setup"
    log_info "==============================="

    local tests_passed=0
    local total_tests=4

    # Run tests
    if test_directories; then
        ((tests_passed++))
    fi

    if test_permissions; then
        ((tests_passed++))
    fi

    if test_config; then
        ((tests_passed++))
    fi

    if test_build; then
        ((tests_passed++))
    fi

    # Results
    echo ""
    log_info "Test Results: $tests_passed/$total_tests tests passed"

    if [ $tests_passed -eq $total_tests ]; then
        log_success "All tests passed! Setup is ready."
        echo ""
        log_info "Next steps:"
        echo "  1. Edit .env file with your configuration"
        echo "  2. Run: ./scripts/init.sh"
        echo "  3. Run: docker compose up -d"
        return 0
    else
        log_error "Some tests failed. Please fix the issues above."
        return 1
    fi
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
