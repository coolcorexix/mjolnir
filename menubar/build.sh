#!/usr/bin/env bash

# MjolnirBar Build Script
# Compiles Swift source and creates .app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="MjolnirBar"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

echo "Building $APP_NAME..."
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create .app bundle directory structure
echo "Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile Swift source
echo "Compiling Swift source..."
swiftc \
    -O \
    -whole-module-optimization \
    -target arm64-apple-macos14.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework Cocoa \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "$SCRIPT_DIR/$APP_NAME.swift"

# Copy Info.plist
echo "Copying Info.plist..."
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Create PkgInfo file
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""

# Install to ~/Applications if requested
if [ "$1" = "--install" ] || [ "$1" = "-i" ]; then
    echo "Installing to $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"

    # Kill existing instance if running
    pkill -x "$APP_NAME" 2>/dev/null || true

    # Remove old installation
    rm -rf "$INSTALL_DIR/$APP_NAME.app"

    # Copy new build
    cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

    echo "Installed: $INSTALL_DIR/$APP_NAME.app"
    echo ""
fi

# Launch if requested
if [ "$1" = "--launch" ] || [ "$2" = "--launch" ]; then
    echo "Launching $APP_NAME..."
    if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
        open "$INSTALL_DIR/$APP_NAME.app"
    else
        open "$APP_BUNDLE"
    fi
fi

if [ "$1" != "--install" ] && [ "$1" != "-i" ] && [ "$1" != "--launch" ]; then
    echo "Usage:"
    echo "  ./build.sh              Build only"
    echo "  ./build.sh --install    Build and install to ~/Applications"
    echo "  ./build.sh --install --launch    Build, install, and launch"
fi
