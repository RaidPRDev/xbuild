#!/bin/bash
set -euo pipefail

# ================================
# INCLUDE GLOBALS
# ================================
RAID_X_HOME=$([ "$(uname -s)" = "Darwin" ] && echo "$HOME/RaidX" || echo "E:/vms/macos/raidx/RaidX")
GLOBALS_FILE="$RAID_X_HOME/Tools/Support/globals.sh"

if [ -f "$GLOBALS_FILE" ]; then
  # shellcheck source=/dev/null
  source "$GLOBALS_FILE"
  echo "✅ Loaded globals from $GLOBALS_FILE"
else
  echo "❌ globals.sh not found at $GLOBALS_FILE"
  exit 1
fi

set_header "Preparing Build"

# ================================
# INPUTS (from params)
# ================================
MODE="${1:-}"
CLIENT_ID="${2:-}"
BUILD_ID="${3:-}"
P12_PATH="${4:-}"
P12_PASSWORD="${5:-}"
PROVISION_ID="${6:-}"
PROVISION_PATH="${7:-}"
PROVISION_NAME="${8:-}"

# ================================
# VALIDATE REQUIRED PARAMETERS
# ================================
if [[ -z "$MODE" || -z "$CLIENT_ID" || -z "$BUILD_ID" || -z "$P12_PATH" || -z "$P12_PASSWORD" || -z "${PROVISION_ID}" || -z "$PROVISION_PATH" || -z "$PROVISION_NAME" ]]; then
  echo "❌ Missing required parameters."
  echo "Usage: $0 MODE CLIENT_ID BUILD_ID P12_PATH P12_PASSWORD PROVISION_ID PROVISION_PATH PROVISION_NAME"
  exit 1
fi

echo "🔍 Initializing RaidX pipeline..."

# ================================
# DEBUG OUTPUT (optional)
# ================================

if [[ "$MODE" == "dev" ]]; then
    echo "🔹 MODE=$MODE"
    echo "🔹 CLIENT_ID=$CLIENT_ID"
    echo "🔹 BUILD_ID=$BUILD_ID"
    echo "🔹 P12_PATH=$P12_PATH"
    echo "🔹 PROVISION_ID=$PROVISION_ID"
    echo "🔹 PROVISION_PATH=$PROVISION_PATH"
    echo "🔹 PROVISION_NAME=$PROVISION_NAME"
    echo "🔹 Node version: $(node -v 2>/dev/null || echo 'Node not found')"
    echo "🔹 Ruby version: $(ruby -v 2>/dev/null || echo 'Ruby not found')"
    echo "🔹 rbenv version: $(rbenv -v 2>/dev/null || echo 'rbenv not found')"
    echo "🔹 CocoaPods version: $(pod --version 2>/dev/null || echo 'CocoaPods not found')"
fi




# ================================
# 1️⃣ Check Build Requirements
# ================================
check_requirements


# ================================
# 2️⃣ Build Code Sign Profile
# ================================
code_sign


# ================================
# 3️⃣ Build internal web app + sync
# ================================
build_internal_app


# ================================
# 4️⃣ Update PodFile Configuration
# ================================
build_update_podfile


# ================================
# 5️⃣ Build iOS app and Pods (Xcode)
# ================================
build_ios_app


# ================================
# 6️⃣ Uplooad iOS AppStore 
# ================================
XCARCHIVE_FILE="$RAIDX_CLIENTS_PATH/$CLIENT_ID/$BUILD_ID/$IOS_BUILD_PATH/$APP_XCARCHIVE_NAME"
IPA_FILE="$RAIDX_CLIENTS_PATH/$CLIENT_ID/$BUILD_ID/$IOS_BUILD_PATH/$APP_IPA_NAME"
PLATFORM_TYPE="ios"
APPLE_ID="apple_developer_program@sweetrush.com"
APP_SPECIFIC_PASSWORD="hutc-cpnv-vzbc-tbxr"

echo "📦 BUILD_ID: $BUILD_ID"
echo "📦 APPLE_ID: $APPLE_ID"
echo "📦 IPA_FILE: $IPA_FILE"
echo "📦 XCARCHIVE_FILE: $XCARCHIVE_FILE"

IOS_DEPLOY_CMD="${RAIDX_SCRIPTS_PATH}/build_deploy.sh"

if [[ ! -x "$IOS_DEPLOY_CMD" ]]; then
  echo "❌ Error: $IOS_DEPLOY_CMD not found or not executable!"
  exit 1
fi

"$IOS_DEPLOY_CMD" \
  "$IPA_FILE" \
  "$PLATFORM_TYPE" \
  "$APPLE_ID" \
  "$APP_SPECIFIC_PASSWORD" \
  ""
EXIT_CODE=$?
