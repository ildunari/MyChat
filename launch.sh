#!/bin/bash
# Auto-generated hot reload launcher for NoteChat-swift-markdown
# Works with any editor: VS Code, Cursor, Xcode, etc.

set -e
set -o pipefail

SIMULATOR="NoteChat-MarkdownUI"
SCHEME="NoteChat"
PROJECT_DIR="/Users/kosta/Documents/ProjectsXcode/NoteChat-swift-markdown"

echo "🚀 Launching NoteChat-swift-markdown..."
echo "📱 Simulator: $SIMULATOR"
echo ""

# Boot ONLY the specific simulator we want
# This will open Simulator.app if needed
echo "⚙️  Booting simulator..."
xcrun simctl boot "$SIMULATOR" 2>/dev/null && echo "   ✓ Simulator booted" || echo "   ✓ Simulator already running"

# Give it a moment to fully initialize
sleep 1

# Surface the simulator window so hot reload feedback is visible
SIM_UDID=$(xcrun simctl list devices | awk -v name="$SIMULATOR" 'index($0, name" (")==1 {match($0, /\(([A-F0-9-]{36})\)/, m); if (m[1] != "") {print m[1]; exit}}')
echo "🪟 Opening Simulator.app..."
if [[ -n "$SIM_UDID" ]]; then
    open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 &
else
    open -a Simulator >/dev/null 2>&1 &
fi

# Build and run in the SPECIFIC simulator
echo "🔨 Building and running..."
cd "$PROJECT_DIR"
xcodebuild -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$PROJECT_DIR/build"

echo ""
echo "✅ NoteChat-swift-markdown is now running in $SIMULATOR"
echo "🔥 Hot reload is active - just save your files to see changes!"
echo ""
echo "💡 Keep this terminal open to see injection logs"
