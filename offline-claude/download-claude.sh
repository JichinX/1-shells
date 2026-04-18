#!/bin/bash

set -e

# Parse command line arguments
PLATFORM="$1"    # Optional: platform (e.g., linux-x64, linux-arm64, darwin-x64, darwin-arm64)
OUTPUT_DIR="$2"  # Optional: output directory (default: current directory)

# Default values
OUTPUT_DIR="${OUTPUT_DIR:-.}"

DOWNLOAD_BASE_URL="https://downloads.claude.ai/claude-code-releases"

# Check for required dependencies
DOWNLOADER=""
if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    echo "Either curl or wget is required but neither is installed" >&2
    exit 1
fi

# Check if jq is available (optional)
HAS_JQ=false
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=true
fi

# Download function that works with both curl and wget
download_file() {
    local url="$1"
    local output="$2"
    
    if [ "$DOWNLOADER" = "curl" ]; then
        if [ -n "$output" ]; then
            curl -fsSL -o "$output" "$url"
        else
            curl -fsSL "$url"
        fi
    elif [ "$DOWNLOADER" = "wget" ]; then
        if [ -n "$output" ]; then
            wget -q -O "$output" "$url"
        else
            wget -q -O - "$url"
        fi
    else
        return 1
    fi
}

# Simple JSON parser for extracting checksum when jq is not available
get_checksum_from_manifest() {
    local json="$1"
    local platform="$2"
    
    # Normalize JSON to single line and extract checksum
    json=$(echo "$json" | tr -d '\n\r\t' | sed 's/ \+/ /g')
    
    # Extract checksum for platform using bash regex
    if [[ $json =~ \"$platform\"[^}]*\"checksum\"[[:space:]]*:[[:space:]]*\"([a-f0-9]{64})\" ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    return 1
}

# Detect platform if not specified
if [ -z "$PLATFORM" ]; then
    # Detect OS
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        MINGW*|MSYS*|CYGWIN*) 
            echo "Windows is not supported by this script. Use: linux-x64 or download manually." >&2
            exit 1 
            ;;
        *) 
            echo "Unsupported operating system: $(uname -s)" >&2
            echo "Please specify platform manually (e.g., linux-x64, darwin-arm64)" >&2
            exit 1 
            ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64) arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) 
            echo "Unsupported architecture: $(uname -m)" >&2
            echo "Please specify platform manually (e.g., linux-x64, darwin-arm64)" >&2
            exit 1 
            ;;
    esac

    # Detect Rosetta 2 on macOS
    if [ "$os" = "darwin" ] && [ "$arch" = "x64" ]; then
        if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
            arch="arm64"
        fi
    fi

    # Check for musl on Linux
    if [ "$os" = "linux" ]; then
        if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ] || ldd /bin/ls 2>&1 | grep -q musl; then
            platform="linux-${arch}-musl"
        else
            platform="linux-${arch}"
        fi
    else
        platform="${os}-${arch}"
    fi
    
    PLATFORM="$platform"
    echo "Auto-detected platform: $PLATFORM"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get latest version
echo "Fetching latest version..."
version=$(download_file "$DOWNLOAD_BASE_URL/latest")
echo "Latest version: $version"

# Download manifest and extract checksum
echo "Downloading manifest..."
manifest_json=$(download_file "$DOWNLOAD_BASE_URL/$version/manifest.json")

# Use jq if available, otherwise fall back to pure bash parsing
if [ "$HAS_JQ" = true ]; then
    checksum=$(echo "$manifest_json" | jq -r ".platforms[\"$PLATFORM\"].checksum // empty")
else
    checksum=$(get_checksum_from_manifest "$manifest_json" "$PLATFORM")
fi

# Validate checksum format (SHA256 = 64 hex characters)
if [ -z "$checksum" ] || [[ ! "$checksum" =~ ^[a-f0-9]{64}$ ]]; then
    echo "Platform $PLATFORM not found in manifest for version $version" >&2
    echo "Available platforms:" >&2
    if [ "$HAS_JQ" = true ]; then
        echo "$manifest_json" | jq -r '.platforms | keys[]' >&2
    else
        echo "Install jq to see available platforms: apt install jq or brew install jq" >&2
    fi
    exit 1
fi

# Download binary
binary_name="claude-$version-$PLATFORM"
binary_path="$OUTPUT_DIR/$binary_name"

echo "Downloading binary..."
echo "  Platform: $PLATFORM"
echo "  Version:  $version"
echo "  Output:   $binary_path"

if ! download_file "$DOWNLOAD_BASE_URL/$version/$PLATFORM/claude" "$binary_path"; then
    echo "Download failed" >&2
    rm -f "$binary_path"
    exit 1
fi

# Verify checksum
echo "Verifying checksum..."
os=$(echo "$PLATFORM" | cut -d'-' -f1)
if [ "$os" = "darwin" ]; then
    actual=$(shasum -a 256 "$binary_path" | cut -d' ' -f1)
else
    actual=$(sha256sum "$binary_path" | cut -d' ' -f1)
fi

if [ "$actual" != "$checksum" ]; then
    echo "Checksum verification failed" >&2
    echo "  Expected: $checksum" >&2
    echo "  Actual:   $actual" >&2
    rm -f "$binary_path"
    exit 1
fi

echo "✅ Checksum verified"

# Make executable
chmod +x "$binary_path"

echo ""
echo "✅ Download complete!"
echo ""
echo "Binary saved to: $binary_path"
echo ""
echo "To install manually:"
echo "  mkdir -p ~/.local/bin"
echo "  mv $binary_path ~/.local/bin/claude"
echo "  claude --version"
echo ""
