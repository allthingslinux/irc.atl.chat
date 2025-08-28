#!/bin/bash

# IRC Services Docker Build Script
# This script optimizes the Docker build process with proper caching and build arguments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
UNREALIRCD_VERSION=${UNREALIRCD_VERSION:-"6.1.10"}
ATHEME_VERSION=${ATHEME_VERSION:-"7.2.12"}
BUILD_TARGET=${BUILD_TARGET:-"runtime"}
PUSH_IMAGE=${PUSH_IMAGE:-false}
IMAGE_NAME=${IMAGE_NAME:-"irc-atl-chat"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
    -u, --unrealircd-version VERSION    UnrealIRCd version to build (default: $UNREALIRCD_VERSION)
    -a, --atheme-version VERSION        Atheme version to build (default: $ATHEME_VERSION)
    -t, --target TARGET                 Build target: base, builder, or runtime (default: $BUILD_TARGET)
    -n, --name NAME                     Image name (default: $IMAGE_NAME)
    -g, --tag TAG                       Image tag (default: $IMAGE_TAG)
    -p, --push                          Push image after build
    -h, --help                          Show this help message

Environment variables:
    UNREALIRCD_VERSION                  UnrealIRCd version
    ATHEME_VERSION                      Atheme version
    BUILD_TARGET                        Build target
    PUSH_IMAGE                          Push image flag
    IMAGE_NAME                          Image name
    IMAGE_TAG                           Image tag

Examples:
    $0                                    # Build with default settings
    $0 -u 6.1.11 -a 7.2.13              # Build specific versions
    $0 -t builder                        # Build only the builder stage
    $0 -p                                # Build and push image
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    -u | --unrealircd-version)
        UNREALIRCD_VERSION="$2"
        shift 2
        ;;
    -a | --atheme-version)
        ATHEME_VERSION="$2"
        shift 2
        ;;
    -t | --target)
        BUILD_TARGET="$2"
        shift 2
        ;;
    -n | --name)
        IMAGE_NAME="$2"
        shift 2
        ;;
    -g | --tag)
        IMAGE_TAG="$2"
        shift 2
        ;;
    -p | --push)
        PUSH_IMAGE=true
        shift
        ;;
    -h | --help)
        show_usage
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
done

# Validate build target
if [[ ! "$BUILD_TARGET" =~ ^(base|builder|runtime)$ ]]; then
    print_error "Invalid build target: $BUILD_TARGET. Must be one of: base, builder, runtime"
    exit 1
fi

# Print build configuration
print_status "Build Configuration:"
echo "  UnrealIRCd Version: $UNREALIRCD_VERSION"
echo "  Atheme Version: $ATHEME_VERSION"
echo "  Build Target: $BUILD_TARGET"
echo "  Image Name: $IMAGE_NAME:$IMAGE_TAG"
echo "  Push Image: $PUSH_IMAGE"
echo

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running or not accessible"
    exit 1
fi

# Build the image
print_status "Building Docker image..."
if docker build \
    --target "$BUILD_TARGET" \
    --build-arg "UNREALIRCD_VERSION=$UNREALIRCD_VERSION" \
    --build-arg "ATHEME_VERSION=$ATHEME_VERSION" \
    --tag "$IMAGE_NAME:$IMAGE_TAG" \
    --tag "$IMAGE_NAME:${IMAGE_TAG}-unrealircd-${UNREALIRCD_VERSION}-atheme-${ATHEME_VERSION}" \
    --cache-from "$IMAGE_NAME:latest" \
    --progress=plain \
    .; then
    print_success "Docker image built successfully!"

    # Show image information
    print_status "Image details:"
    docker images "$IMAGE_NAME:$IMAGE_TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

    # Push image if requested
    if [ "$PUSH_IMAGE" = true ]; then
        print_status "Pushing image to registry..."
        docker push "$IMAGE_NAME:$IMAGE_TAG"
        docker push "$IMAGE_NAME:${IMAGE_TAG}-unrealircd-${UNREALIRCD_VERSION}-atheme-${ATHEME_VERSION}"
        print_success "Image pushed successfully!"
    fi

    print_success "Build completed successfully!"
else
    print_error "Docker build failed!"
    exit 1
fi
