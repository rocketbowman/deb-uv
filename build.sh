#!/bin/bash

UPSTREAM_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$UPSTREAM_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <uv_version> <build_version> [architecture]"
    echo "Example: $0 0.8.11 1 arm64"
    echo "Example: $0 0.8.11 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, armhf, ppc64el, s390x, riscv64, all"
    exit 1
fi

# Function to map Debian architecture to upstream release name
# get_upstream_release: architecture -> binary name is used to lookup 
# the name of the binary produced by the upstream repository. For 
# each architecture, echo the binary name with no file extension. 
get_upstream_release() {
    local arch=$1
    case "$arch" in
        "amd64")
            echo "uv-x86_64-unknown-linux-gnu"
            ;;
        "arm64")
            echo "uv-aarch64-unknown-linux-gnu"
            ;;
        "armhf")
            echo "uv-armv7-unknown-linux-gnueabihf"
            ;;
        "ppc64el")
            echo "uv-powerpc64-unknown-linux-gnu"
            ;;
        "s390x")
            echo "uv-s390x-unknown-linux-gnu"
            ;;
        "riscv64")
            echo "uv-riscv64gc-unknown-linux-gnu"
            ;;
        *)
            pass
            ;;
    esac
}

# build_architecture
# Function to build for a specific architecture
build_architecture() {
    local build_arch=$1
    local upstream_release
    local url
    
    upstream_release=$(get_upstream_release "$build_arch")
    url="https://github.com/astral-sh/uv/releases/download/${UPSTREAM_VERSION}/${upstream_release}.tar.gz"
    if [ -z "$upstream_release" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64, armhf, ppc64el, s390x, riscv64"
        return 1
    fi
    
    echo "Building for architecture: $build_arch using $upstream_release"
    
    # Clean up any previous builds for this architecture
    rm -rf "$upstream_release" || true
    rm -f "${upstream_release}.tar.gz" || true

    # Download and extract upstream binary for this architecture
    if ! wget "$url"; then
        echo "❌ Failed to download uv binary for $build_arch"
        return 1
    fi
    
    if ! tar -xf "${upstream_release}.tar.gz"; then
        echo "❌ Failed to extract uv binary for $build_arch"
        return 1
    fi
    
    rm -f "${upstream_release}.tar.gz"
    
    # Build packages for appropriate Debian distributions
    # riscv64 is only supported in trixie (v13) and later, not in bookworm (v12)
    if [ "$build_arch" = "riscv64" ]; then
        declare -a arr=("trixie" "forky" "sid")
    else
        declare -a arr=("bookworm" "trixie" "forky" "sid")
    fi
    
    for dist in "${arr[@]}"; do
        FULL_VERSION="$UPSTREAM_VERSION-${BUILD_VERSION}+${dist}_${build_arch}"
        echo "  Building $FULL_VERSION"
        
        if ! docker build . -t "uv-$dist-$build_arch" \
            --build-arg DEBIAN_DIST="$dist" \
            --build-arg UPSTREAM_VERSION="$UPSTREAM_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg UPSTREAM_RELEASE="$upstream_release"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi
        
        id="$(docker create "uv-$dist-$build_arch")"
        if ! docker cp "$id:/uv_$FULL_VERSION.deb" - > "./uv_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi
        
        if ! tar -xf "./uv_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done
    
    # Clean up extracted directory
    rm -rf "$upstream_release" || true
    
    echo "✅ Successfully built for $build_arch"
    return 0
}

# Main build logic
if [ "$ARCH" = "all" ]; then
    echo "🚀 Building uv $UPSTREAM_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""
    
    # All supported architectures
    ARCHITECTURES=("amd64" "arm64" "armhf" "ppc64el" "s390x" "riscv64")
    
    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="
        
        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi
        
        echo ""
    done
    
    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la "*.deb" || true
else
    # Build for single architecture
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
