#!/bin/bash

# Setup Xray binaries from GitHub releases
# Run this on the server

set -e

XRAY_VERSION="v26.3.27"
BASE_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}"
BACKEND_DIR="/opt/voyfy-vpn/backend"
BINARIES_DIR="${BACKEND_DIR}/xray-binaries"

echo "=== Setting up Xray binaries ==="
echo "Version: ${XRAY_VERSION}"
echo "Target directory: ${BINARIES_DIR}"
echo ""

# Create directories
echo "Creating directories..."
mkdir -p "${BINARIES_DIR}/windows-amd64"
mkdir -p "${BINARIES_DIR}/windows-arm64"
mkdir -p "${BINARIES_DIR}/linux-amd64"
mkdir -p "${BINARIES_DIR}/linux-arm64"
mkdir -p "${BINARIES_DIR}/darwin-amd64"
mkdir -p "${BINARIES_DIR}/darwin-arm64"

# Temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

cd "${TEMP_DIR}"

# Download and extract function
download_and_extract() {
    local platform=$1
    local arch=$2
    local filename=$3
    local target_name=$4
    local url="${BASE_URL}/${filename}"
    local target_dir="${BINARIES_DIR}/${platform}-${arch}"
    
    echo ""
    echo "Downloading ${platform}-${arch}..."
    echo "URL: ${url}"
    
    if wget -q --show-progress "${url}" -O "${filename}"; then
        echo "Extracting ${filename}..."
        unzip -q "${filename}" -d "extracted_${platform}_${arch}"
        
        # Find xray binary in extracted folder
        local xray_binary=$(find "extracted_${platform}_${arch}" -type f \( -name "xray" -o -name "xray.exe" \) | head -1)
        
        if [ -n "${xray_binary}" ]; then
            echo "Found binary: ${xray_binary}"
            
            # Copy all files from extracted folder to target
            cp -r "extracted_${platform}_${arch}"/* "${target_dir}/"
            
            # Rename xray binary to target name if needed
            if [ -f "${target_dir}/xray" ] && [ "${target_name}" != "xray" ]; then
                mv "${target_dir}/xray" "${target_dir}/${target_name}"
                echo "Renamed xray -> ${target_name}"
            elif [ -f "${target_dir}/xray.exe" ] && [ "${target_name}" != "xray.exe" ]; then
                mv "${target_dir}/xray.exe" "${target_dir}/${target_name}"
                echo "Renamed xray.exe -> ${target_name}"
            fi
            
            # Make binary executable (for non-Windows)
            if [[ "${platform}" != "windows" ]]; then
                chmod +x "${target_dir}/${target_name}"
            fi
            
            echo "✓ ${platform}-${arch} installed successfully"
            
            # List installed files
            echo "Files in ${target_dir}:"
            ls -la "${target_dir}/"
        else
            echo "✗ Error: xray binary not found in ${filename}"
            return 1
        fi
    else
        echo "✗ Error: Failed to download ${filename}"
        return 1
    fi
}

# Download all platforms
download_and_extract "windows" "amd64" "Xray-windows-64.zip" "xray-windows-64.exe"
download_and_extract "windows" "arm64" "Xray-windows-arm64-v8a.zip" "xray-windows-arm64.exe"
download_and_extract "linux" "amd64" "Xray-linux-64.zip" "xray-linux-64"
download_and_extract "linux" "arm64" "Xray-linux-arm64-v8a.zip" "xray-linux-arm64-v8a"
download_and_extract "darwin" "amd64" "Xray-macos-64.zip" "xray-darwin-64"
download_and_extract "darwin" "arm64" "Xray-macos-arm64-v8a.zip" "xray-darwin-arm64"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Verifying installation:"
find "${BINARIES_DIR}" -type f -name "xray-*" | while read file; do
    size=$(du -h "${file}" | cut -f1)
    echo "  ${file} (${size})"
done

echo ""
echo "All files:"
find "${BINARIES_DIR}" -type f | sort

echo ""
echo "=== Done! Restart API container to apply changes ==="
echo "  docker compose restart api"
