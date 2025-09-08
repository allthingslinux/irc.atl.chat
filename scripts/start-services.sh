#!/bin/bash

# Simple IRC Services Startup Script
# Just starts UnrealIRCd - Atheme runs in separate container

set -e

# Simple startup - just run UnrealIRCd
echo "Starting UnrealIRCd..."
exec /usr/local/bin/unrealircd -F
