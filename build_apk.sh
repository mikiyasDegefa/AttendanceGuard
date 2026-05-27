#!/usr/bin/env bash
# =============================================================================
#  WiFi Tracker — Flutter APK Build Script
#  Supports: Ubuntu / Debian / macOS
#  Usage:    chmod +x build_apk.sh && ./build_apk.sh
# =============================================================================

set -e  # exit on any error

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
FLUTTER_VERSION="3.22.0"
FLUTTER_CHANNEL="stable"
FLUTTER_INSTALL_DIR="$HOME/flutter"
ANDROID_SDK_DIR="$HOME/android-sdk"
ANDROID_BUILD_TOOLS_VERSION="34.0.0"
ANDROID_PLATFORM_VERSION="android-34"
CMDLINE_TOOLS_VERSION="11076708"   # latest stable command-line tools
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/output"
APK_NAME="wifi-tracker-release.apk"

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}[BUILD]${RESET} $1"; }
success() { echo -e "${GREEN}[  OK ]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[ WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; \
            echo -e "${BOLD} $1${RESET}"; \
            echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

# ── Detect OS ─────────────────────────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
    FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/${FLUTTER_ARCHIVE}"
    CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
      FLUTTER_ARCHIVE="flutter_macos_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
    else
      FLUTTER_ARCHIVE="flutter_macos_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
    fi
    FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/${FLUTTER_ARCHIVE}"
    CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-mac-${CMDLINE_TOOLS_VERSION}_latest.zip"
  else
    error "Unsupported OS: $OSTYPE. Use Linux or macOS, or run build_apk.bat on Windows."
  fi
  log "Detected OS: $OS"
}

# ── Check dependencies ────────────────────────────────────────────────────────
check_deps() {
  step "Checking system dependencies"
  local missing=()

  command -v curl  &>/dev/null || missing+=("curl")
  command -v unzip &>/dev/null || missing+=("unzip")
  command -v git   &>/dev/null || missing+=("git")
  command -v java  &>/dev/null || missing+=("java (JDK 17)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing: ${missing[*]}"
    if [[ "$OS" == "linux" ]]; then
      log "Installing missing packages..."
      sudo apt-get update -qq
      sudo apt-get install -y curl unzip git openjdk-17-jdk xz-utils wget 2>/dev/null || true
    elif [[ "$OS" == "mac" ]]; then
      command -v brew &>/dev/null || error "Homebrew not found. Install from https://brew.sh"
      brew install curl unzip git openjdk@17 2>/dev/null || true
    fi
  fi

  # Verify Java
  if ! command -v java &>/dev/null; then
    error "Java not found. Install JDK 17: https://adoptium.net"
  fi

  local java_ver
  java_ver=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
  if [[ "$java_ver" -lt 11 ]]; then
    error "Java 11+ required. Found Java $java_ver. Install JDK 17."
  fi
  success "Java $java_ver detected"
}

# ── Install Flutter ───────────────────────────────────────────────────────────
install_flutter() {
  step "Setting up Flutter $FLUTTER_VERSION"

  # Check if already installed and correct version
  if [[ -f "$FLUTTER_INSTALL_DIR/bin/flutter" ]]; then
    local installed_ver
    installed_ver=$("$FLUTTER_INSTALL_DIR/bin/flutter" --version 2>/dev/null | grep -oP 'Flutter \K[0-9.]+' | head -1)
    if [[ "$installed_ver" == "$FLUTTER_VERSION" ]]; then
      success "Flutter $FLUTTER_VERSION already installed"
      export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
      return
    else
      warn "Found Flutter $installed_ver, need $FLUTTER_VERSION — reinstalling"
      rm -rf "$FLUTTER_INSTALL_DIR"
    fi
  fi

  log "Downloading Flutter $FLUTTER_VERSION..."
  local tmp_dir
  tmp_dir=$(mktemp -d)

  if [[ "$OS" == "linux" ]]; then
    curl -L --progress-bar "$FLUTTER_URL" -o "$tmp_dir/$FLUTTER_ARCHIVE"
    log "Extracting Flutter..."
    mkdir -p "$(dirname "$FLUTTER_INSTALL_DIR")"
    tar xf "$tmp_dir/$FLUTTER_ARCHIVE" -C "$(dirname "$FLUTTER_INSTALL_DIR")"
  else
    curl -L --progress-bar "$FLUTTER_URL" -o "$tmp_dir/$FLUTTER_ARCHIVE"
    log "Extracting Flutter..."
    mkdir -p "$(dirname "$FLUTTER_INSTALL_DIR")"
    unzip -q "$tmp_dir/$FLUTTER_ARCHIVE" -d "$(dirname "$FLUTTER_INSTALL_DIR")"
  fi

  rm -rf "$tmp_dir"
  export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
  success "Flutter installed at $FLUTTER_INSTALL_DIR"
}

# ── Install Android SDK ───────────────────────────────────────────────────────
install_android_sdk() {
  step "Setting up Android SDK"

  export ANDROID_HOME="$ANDROID_SDK_DIR"
  export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
  export PATH="$ANDROID_SDK_DIR/cmdline-tools/latest/bin:$ANDROID_SDK_DIR/platform-tools:$PATH"

  # Check if sdkmanager is already available
  if command -v sdkmanager &>/dev/null; then
    success "Android SDK already configured"
  else
    log "Downloading Android command-line tools..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    curl -L --progress-bar "$CMDLINE_TOOLS_URL" -o "$tmp_dir/cmdtools.zip"

    log "Installing Android command-line tools..."
    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
    unzip -q "$tmp_dir/cmdtools.zip" -d "$tmp_dir"
    mv "$tmp_dir/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
    rm -rf "$tmp_dir"
    success "Android command-line tools installed"
  fi

  # Accept licenses
  log "Accepting Android SDK licenses..."
  yes | sdkmanager --licenses &>/dev/null || true

  # Install required SDK components
  local components=(
    "platform-tools"
    "platforms;$ANDROID_PLATFORM_VERSION"
    "build-tools;$ANDROID_BUILD_TOOLS_VERSION"
  )

  for component in "${components[@]}"; do
    if [[ ! -d "$ANDROID_SDK_DIR/${component/;/\/}" ]]; then
      log "Installing: $component"
      sdkmanager "$component" 2>/dev/null
    else
      success "Already installed: $component"
    fi
  done
}

# ── Configure Flutter ─────────────────────────────────────────────────────────
configure_flutter() {
  step "Configuring Flutter"

  # Disable analytics for CI
  flutter config --no-analytics &>/dev/null || true

  # Point Flutter to Android SDK
  flutter config --android-sdk "$ANDROID_SDK_DIR" &>/dev/null || true

  # Run doctor to verify setup
  log "Running flutter doctor..."
  flutter doctor -v 2>&1 | grep -E "(Flutter|Android|✓|✗|!|SDK)" || true

  success "Flutter configured"
}

# ── Build APK ────────────────────────────────────────────────────────────────
build_apk() {
  step "Building Flutter APK"

  cd "$PROJECT_DIR"

  # Verify this is a Flutter project
  [[ -f "pubspec.yaml" ]] || error "pubspec.yaml not found. Run this script from your Flutter project root."

  log "Fetching dependencies..."
  flutter pub get

  log "Building release APK (this takes 2–5 minutes)..."
  flutter build apk \
    --release \
    --no-tree-shake-icons \
    --verbose 2>&1 | tail -20

  # Copy output
  mkdir -p "$OUTPUT_DIR"
  local built_apk="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"

  if [[ -f "$built_apk" ]]; then
    cp "$built_apk" "$OUTPUT_DIR/$APK_NAME"
    local size
    size=$(du -sh "$OUTPUT_DIR/$APK_NAME" | cut -f1)
    success "APK built successfully!"
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════╗"
    echo -e "║         BUILD SUCCESSFUL ✅              ║"
    echo -e "╠══════════════════════════════════════════╣"
    echo -e "║  File : $APK_NAME          ║"
    echo -e "║  Size : $size                            ║"
    echo -e "║  Path : $OUTPUT_DIR/$APK_NAME"
    echo -e "╚══════════════════════════════════════════╝${RESET}\n"
  else
    error "APK not found at expected path: $built_apk"
  fi
}

# ── Install to connected Android device ──────────────────────────────────────
install_to_device() {
  if ! command -v adb &>/dev/null; then return; fi

  local devices
  devices=$(adb devices | grep -v "List" | grep "device$" | wc -l)

  if [[ "$devices" -gt 0 ]]; then
    log "Android device detected — installing APK..."
    adb install -r "$OUTPUT_DIR/$APK_NAME" && \
      success "APK installed on device!" || \
      warn "Device install failed (you can still copy the APK manually)"
  else
    log "No Android device connected — skipping device install"
    log "To install later:  adb install $OUTPUT_DIR/$APK_NAME"
  fi
}

# ── Print manual install instructions ────────────────────────────────────────
print_install_guide() {
  echo -e "${CYAN}${BOLD}"
  echo "  ┌─ HOW TO INSTALL ON YOUR PHONE ──────────────────────────┐"
  echo "  │                                                           │"
  echo "  │  1. Copy the APK to your phone:                          │"
  echo "  │     • USB cable  →  paste to Downloads folder            │"
  echo "  │     • OR: send via WhatsApp / Telegram to yourself       │"
  echo "  │     • OR: upload to Google Drive and open on phone       │"
  echo "  │                                                           │"
  echo "  │  2. On your Android phone:                               │"
  echo "  │     Settings → Security → Install unknown apps           │"
  echo "  │     → enable for Files / browser app                     │"
  echo "  │                                                           │"
  echo "  │  3. Open the APK file → tap Install                      │"
  echo "  │                                                           │"
  echo "  └───────────────────────────────────────────────────────────┘"
  echo -e "${RESET}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  echo -e "${BOLD}${CYAN}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║      WiFi Tracker — APK Builder           ║"
  echo "  ║      Flutter $FLUTTER_VERSION ($FLUTTER_CHANNEL)              ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${RESET}"

  detect_os
  check_deps
  install_flutter
  install_android_sdk
  configure_flutter
  build_apk
  install_to_device
  print_install_guide
}

main "$@"
