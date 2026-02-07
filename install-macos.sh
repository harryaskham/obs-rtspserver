#!/bin/bash

# Exit on error
set -e

echo "Starting OBS RTSP Server plugin installation fix..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please do not run this script as root"
    exit 1
fi

# Check if OBS is running
if pgrep -x "obs" > /dev/null; then
    echo "Please quit OBS before running this script"
    exit 1
fi

# Define paths
export WORKSPACE=$(mktemp -d)
cd "$WORKSPACE"
echo "Working in $WORKSPACE"
ZIP_FILE="obs-rtspserver-v3.1.0-macos-arm64.zip"
ZIP_URL="https://github.com/iamscottxu/obs-rtspserver/releases/download/v3.1.0/$ZIP_FILE"
echo "Downloading $ZIP_URL"
wget "$ZIP_URL"
unzip $ZIP_FILE
PKG_NAME="obs-rtspserver"
PKG_DIR="$WORKSPACE/$PKG_NAME"

if [[ ! -d "$PKG_DIR" ]]; then
  echo "$PKG_DIR was not created"
  exit 1
fi

RTSP_PLUGIN_DIR="$WORKSPACE/obs-rtspserver.plugin"

echo "Creating plugin from $PKG_DIR at $RTSP_PLUGIN_DIR"


# Copy files from expanded package
echo "Copying plugin files..."
mkdir -p "$RTSP_PLUGIN_DIR/Contents/MacOS"
mkdir -p "$RTSP_PLUGIN_DIR/Contents/Resources"
cp "$PKG_DIR/bin/obs-rtspserver.so" "$RTSP_PLUGIN_DIR/Contents/MacOS/obs-rtspserver"
cp -r "$PKG_DIR/data/locale" "$RTSP_PLUGIN_DIR/Contents/Resources/"

# Create Info.plist
echo "Creating Info.plist..."
cat > "$RTSP_PLUGIN_DIR/Contents/Info.plist" << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>obs-rtspserver</string>
    <key>CFBundleIdentifier</key>
    <string>com.iamscottxu.obs-rtspserver</string>
    <key>CFBundleVersion</key>
    <string>3.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>3.1.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleExecutable</key>
    <string>obs-rtspserver</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
</dict>
</plist>
EOL

PLUGIN_DIR="$HOME/Library/Application Support/obs-studio/plugins"
RTSP_PLUGIN_DEST_DIR="$PLUGIN_DIR/obs-rtspserver.plugin"
if [[ -d "$RTSP_PLUGIN_DEST_DIR" ]]; then
  echo "Plugin already exists at"
  echo "$RTSP_PLUGIN_DEST_DIR"
  exit 1
fi

cp -r "$RTSP_PLUGIN_DIR" "$RTSP_PLUGIN_DEST_DIR"

# Update library paths
echo "Updating library paths..."
install_name_tool -change "UI/obs-frontend-api/obs-frontend-api.dylib" "@rpath/obs-frontend-api.dylib" \
    -change "libobs/libobs.framework/Versions/A/libobs" "@rpath/libobs.framework/Versions/A/libobs" \
    "$RTSP_PLUGIN_DEST_DIR/Contents/MacOS/obs-rtspserver"

# Sign the plugin
echo "Signing plugin..."
codesign --force --deep --sign - "$RTSP_PLUGIN_DEST_DIR"

echo "Installation complete!"
echo "Please start OBS and check if the RTSP server plugin appears in the Tools menu." 
