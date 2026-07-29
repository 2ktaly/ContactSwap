#!/bin/bash

PROJECT_PATH=$(cd "$(dirname "$0")" && pwd)
XCODE_PROJECT="$PROJECT_PATH/ContactSwap.xcodeproj"

echo "🏗️  Contact-Swap – Build Test"
echo "=============================="
echo ""

# Baue für iOS Simulator
echo "Baue für Simulator..."
xcodebuild -project "$XCODE_PROJECT" \
  -scheme ContactSwap \
  -configuration Debug \
  -sdk iphonesimulator \
  -derivedDataPath "$PROJECT_PATH/build" \
  2>&1 | tail -20

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build erfolgreich!"
    echo ""
    echo "Nächster Schritt:"
    echo "  1. Öffne in Xcode: open '$XCODE_PROJECT'"
    echo "  2. Wähle Simulator (iPhone 15 oder ähnlich)"
    echo "  3. Klick auf Play (Cmd+R)"
else
    echo ""
    echo "❌ Build-Fehler! Siehe oben."
    echo ""
    echo "Typische Lösungen:"
    echo "  1. Product → Clean Build Folder (Cmd+Shift+K)"
    echo "  2. Alle Swift-Dateien ins Target: File → Add Files"
    echo "  3. macOS Berechtigungen: sudo xcode-select --install"
fi
