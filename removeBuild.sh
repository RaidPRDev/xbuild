#!/bin/bash

IS_DARWIN=$([ -x "$(command -v sw_vers)" ] && echo true || echo false)

# Set RAID_X_HOME based on OS
if [ "$IS_DARWIN" = true ]; then
  RAID_X_HOME="$HOME/RaidX"
else
  RAID_X_HOME="/mnt/e/vms/macos/raidx/RaidX"
fi

# ================================
# INCLUDE GLOBALS
# ================================
GLOBALS_FILE="$RAID_X_HOME/Tools/ios/Support/globals.sh"
if [ -f "$GLOBALS_FILE" ]; then
  # shellcheck source=/dev/null
  source "$GLOBALS_FILE"
  echo "✅ Loaded globals from $GLOBALS_FILE"
else
  echo "❌ globals.sh not found at $GLOBALS_FILE"
  exit 1
fi

set_header "Remove Build"


# ================================
# REMOTE BUILD CONFIGURATION
# ================================
REMOTE_DIR="${RAIDX_CLIENTS_PATH}"

# === Params check ===
if [ $# -ne 2 ]; then
    echo "Usage: $0 <CLIENT_ID> <BUILD_ID>"
    echo "Example: $0 TESTER ABC123_20250817130902"
    exit 1
fi


# ================================
# CLIENT PARMS
# ================================
CLIENT_ID="$1"
BUILD_ID="$2"

TARGET_DIR="$REMOTE_DIR/$CLIENT_ID/$BUILD_ID"

# === Check if path exists on VPS ===
sshpass -p "$SERVER_PASS" ssh "$SERVER_USER@$SERVER_IP" "if [ ! -d '$TARGET_DIR' ]; then echo '❌ Path does not exist or has been removed: $TARGET_DIR'; exit 1; fi" &

pid=$!
spinner_progress $pid "validating project $BUILD_ID"
wait $pid

if [ $? -ne 0 ]; then
    exit 1
fi

# === Remove directory silently on macOS VPS ===
sshpass -p "$SERVER_PASS" ssh "$SERVER_USER@$SERVER_IP" "rm -rf '$TARGET_DIR'" &

pid=$!
spinner_progress $pid "removing project $BUILD_ID"
wait $pid

if [ $? -eq 0 ]; then
    echo "✅ Project Removed $TARGET_DIR"
else
    echo "❌ Failed to remove $TARGET_DIR"
    exit 1
fi
