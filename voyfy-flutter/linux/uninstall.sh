#!/bin/bash
set -e

BUNDLE_NAME="voyfy_vpn"
DESKTOP_ID="com.voyfy.vpn"

echo "Removing /opt/$BUNDLE_NAME..."
sudo rm -rf "/opt/$BUNDLE_NAME"

echo "Removing icon..."
sudo rm -f "/usr/share/pixmaps/${DESKTOP_ID}.png"

echo "Removing .desktop entry..."
sudo rm -f "/usr/share/applications/${DESKTOP_ID}.desktop"

echo "Updating desktop database..."
sudo update-desktop-database /usr/share/applications

echo "Done! Voyfy VPN has been uninstalled."
