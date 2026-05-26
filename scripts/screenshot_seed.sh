#!/usr/bin/env bash
# screenshot_seed.sh — build, install, and launch GameDrawer with --screenshots
# so ScreenshotSeeder fires on every run.
#
# Usage:
#   bash scripts/screenshot_seed.sh
#   bash scripts/screenshot_seed.sh "iPhone 16 Pro"   # optional device name override
#
# Prerequisites: Xcode, a booted iOS simulator.
# The script finds the first booted simulator automatically.

set -euo pipefail

DEVICE_NAME="${1:-}"
PROJECT="gamekit/gamekit.xcodeproj"
SCHEME="gamekit"
BUNDLE_ID="com.lauterstar.gamekit"
CONFIG="Debug"

# ── 1. Find booted simulator ─────────────────────────────────────────────────
if [[ -n "$DEVICE_NAME" ]]; then
    UDID=$(xcrun simctl list devices booted -j \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)['devices']
for runtime, devices in data.items():
    for d in devices:
        if d.get('state') == 'Booted' and '${DEVICE_NAME}' in d.get('name', ''):
            print(d['udid'])
            exit()
" | head -1)
else
    UDID=$(xcrun simctl list devices booted -j \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)['devices']
for runtime, devices in data.items():
    for d in devices:
        if d.get('state') == 'Booted':
            print(d['udid'])
            exit()
" | head -1)
fi

if [[ -z "$UDID" ]]; then
    echo "❌ No booted simulator found. Boot one in Simulator.app or with:"
    echo "   xcrun simctl boot 'iPhone 16 Pro'"
    exit 1
fi

echo "📱 Target simulator: $UDID"

# ── 2. Build ─────────────────────────────────────────────────────────────────
echo "🔨 Building $SCHEME ($CONFIG)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -configuration "$CONFIG" \
    -quiet \
    build

# ── 3. Locate the .app bundle ────────────────────────────────────────────────
APP=$(find ~/Library/Developer/Xcode/DerivedData \
    -name "gamekit.app" \
    -path "*/Debug-iphonesimulator/*" \
    | sort -t/ -k1,1 | tail -1)

if [[ -z "$APP" ]]; then
    echo "❌ Could not locate gamekit.app in DerivedData."
    exit 1
fi

echo "📦 App bundle: $APP"

# ── 4. Install & launch ───────────────────────────────────────────────────────
echo "📲 Installing…"
xcrun simctl install "$UDID" "$APP"

echo "🚀 Launching with --screenshots…"
xcrun simctl launch "$UDID" "$BUNDLE_ID" --screenshots

echo "✅ Done. The app will wipe + reseed on every launch while --screenshots is in the args."
