#!/bin/sh
# Build Boop2 (Debug) and install it to /Applications so Spotlight
# always opens the latest build. Usage: ./install.sh
set -e
cd "$(dirname "$0")"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild -project Boop/Boop.xcodeproj -scheme Boop -configuration Debug \
    -destination 'platform=macOS' build

BUILT_PRODUCTS_DIR=$(xcodebuild -project Boop/Boop.xcodeproj -scheme Boop \
    -configuration Debug -showBuildSettings 2>/dev/null \
    | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p' | head -n 1)

rm -rf /Applications/Boop2.app
ditto "$BUILT_PRODUCTS_DIR/Boop2.app" /Applications/Boop2.app
mdimport /Applications/Boop2.app >/dev/null 2>&1 || true

echo "Installed Boop2.app - open it with Spotlight (type Boop2)."
