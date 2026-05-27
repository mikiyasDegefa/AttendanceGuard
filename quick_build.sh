#!/usr/bin/env bash
# =============================================================================
#  quick_build.sh — Fast APK build (assumes Flutter + Android SDK installed)
#  Usage: ./quick_build.sh [debug|release|profile]
# =============================================================================

set -e

MODE="${1:-release}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; RESET='\033[0m'; BOLD='\033[1m'

log()   { echo -e "${CYAN}▶${RESET} $1"; }
ok()    { echo -e "${GREEN}✓${RESET} $1"; }
fail()  { echo -e "${RED}✗ ERROR:${RESET} $1"; exit 1; }

echo -e "\n${BOLD}WiFi Tracker — Quick Build (${MODE})${RESET}\n"

# Validate
[[ -f "$PROJECT_DIR/pubspec.yaml" ]] || fail "Not a Flutter project (no pubspec.yaml)"
command -v flutter &>/dev/null          || fail "Flutter not found. Run build_apk.sh first."

cd "$PROJECT_DIR"

log "Getting dependencies..."
flutter pub get

log "Building $MODE APK..."
case "$MODE" in
  debug)   flutter build apk --debug ;;
  profile) flutter build apk --profile ;;
  *)       flutter build apk --release --no-tree-shake-icons ;;
esac

# Copy to output/
mkdir -p "$OUTPUT_DIR"
SRC="$PROJECT_DIR/build/app/outputs/flutter-apk/app-${MODE}.apk"
DEST="$OUTPUT_DIR/wifi-tracker-${MODE}-${TIMESTAMP}.apk"
cp "$SRC" "$DEST"
SIZE=$(du -sh "$DEST" | cut -f1)

echo -e "\n${GREEN}${BOLD}✅ Build complete!${RESET}"
echo -e "   Mode : ${BOLD}$MODE${RESET}"
echo -e "   Size : $SIZE"
echo -e "   APK  : ${BOLD}$DEST${RESET}\n"

# ADB install if device connected
if command -v adb &>/dev/null && adb devices | grep -q "device$"; then
  log "Device found — installing via ADB..."
  adb install -r "$DEST" && ok "Installed on device!" || echo "⚠ ADB install skipped"
fi
