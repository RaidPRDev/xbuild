#!/bin/bash
clear

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ================================
# SOURCE ENVIRONMENT
# ================================
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "❌ .env not found at $ENV_FILE"
  exit 1
fi

IS_DARWIN=$([ -x "$(command -v sw_vers)" ] && echo true || echo false)
if [ "$IS_DARWIN" = true ]; then
  RAID_X_HOME="$HOME/RaidX"
else
  RAID_X_HOME="$SCRIPT_DIR/RaidX"
fi

# ================================
# INCLUDE GLOBALS
# ================================
GLOBALS_FILE="$RAID_X_HOME/Tools/ios/Support/globals.sh"
if [ -f "$GLOBALS_FILE" ]; then
  # shellcheck source=/dev/null
  source "$GLOBALS_FILE"
else
  echo "❌ globals.sh not found at $GLOBALS_FILE"
  exit 1
fi

set_header "XBuild - Build Portal"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Select build platform:"
echo ""
echo "  1) iOS      - Build and deploy to App Store"
echo "  2) Android  - Build and deploy to Google Play"
echo "  3) Both     - Build for iOS and Android"
echo "  0) Exit"
echo ""
read -p "Enter choice [0-3]: " choice

case $choice in
  1)
    echo ""
    echo "🍎 Starting iOS build..."
    bash "$SCRIPT_DIR/uploadAndBuildiOS.sh"
    ;;
  2)
    echo ""
    echo "🤖 Starting Android build..."
    bash "$SCRIPT_DIR/uploadAndBuildAndroid.sh"
    ;;
  3)
    echo ""
    echo "🍎 Starting iOS build..."
    bash "$SCRIPT_DIR/uploadAndBuildiOS.sh"
    echo ""
    echo "🤖 Starting Android build..."
    bash "$SCRIPT_DIR/uploadAndBuildAndroid.sh"
    ;;
  0)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "❌ Invalid selection."
    exit 1
    ;;
esac
