#!/bin/bash

# Test script for GitHub Actions CI workflow
# This script tests the Docker linting workflows locally using act

set -e

echo "🚀 Testing GitHub Actions Docker Linting Workflow with act"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}📋 Available jobs:${NC}"
act --list

echo ""
echo -e "${YELLOW}🐳 Testing Containerfile Linting...${NC}"
echo "----------------------------------------"
if act push -j containerfile-lint --verbose; then
    echo -e "${GREEN}✅ Containerfile linting test PASSED${NC}"
else
    echo -e "${RED}❌ Containerfile linting test FAILED${NC}"
fi

echo ""
echo -e "${YELLOW}📦 Testing Docker Compose Linting...${NC}"
echo "----------------------------------------"
if act push -j docker-compose-lint --verbose; then
    echo -e "${GREEN}✅ Docker Compose linting test PASSED${NC}"
else
    echo -e "${RED}❌ Docker Compose linting test FAILED${NC}"
fi

echo ""
echo -e "${YELLOW}🔐 Testing Security Scanning (pull_request event)...${NC}"
echo "----------------------------------------"
if act pull_request -j docker-security-scan --verbose; then
    echo -e "${GREEN}✅ Security scanning test PASSED${NC}"
else
    echo -e "${RED}❌ Security scanning test FAILED${NC}"
fi

echo ""
echo -e "${YELLOW}🎯 Testing all jobs together...${NC}"
echo "----------------------------------------"
if act push --verbose; then
    echo -e "${GREEN}✅ Full workflow test PASSED${NC}"
else
    echo -e "${RED}❌ Full workflow test FAILED${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Testing complete!${NC}"
echo "To run individual tests:"
echo "  act push -j containerfile-lint"
echo "  act push -j docker-compose-lint"
echo "  act pull_request -j docker-security-scan"
echo "  act push  # run all push jobs"
