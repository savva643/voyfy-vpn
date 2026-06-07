#!/bin/bash
set -e

APP_NAME="Voyfy VPN"
BUNDLE_NAME="voyfy_vpn"
DESKTOP_ID="com.voyfy.vpn"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"

echo "Building release version..."
cd "$PROJECT_DIR"
flutter build linux --release

echo "Installing to /opt/$BUNDLE_NAME..."
sudo rm -rf "/opt/$BUNDLE_NAME"
sudo cp -r "$BUILD_DIR" "/opt/$BUNDLE_NAME"

echo "Installing icon..."
sudo mkdir -p /usr/share/pixmaps
sudo cp "$PROJECT_DIR/web/icons/Icon-512.png" "/usr/share/pixmaps/${DESKTOP_ID}.png"

echo "Creating .desktop entry..."
cat << EOF | sudo tee "/usr/share/applications/${DESKTOP_ID}.desktop"
[Desktop Entry]
Name=$APP_NAME
Comment=Secure VPN connection
Exec=/opt/$BUNDLE_NAME/$BUNDLE_NAME
Icon=$DESKTOP_ID
Type=Application
Categories=Network;Internet;
Terminal=false
StartupNotify=true
EOF

echo "Updating desktop database..."
sudo update-desktop-database /usr/share/applications

echo "Done! You can now launch '$APP_NAME' from the applications menu."
