#!/bin/bash
clear

MODE="dev";  
IS_DARWIN=$([ -x "$(command -v sw_vers)" ] && echo true || echo false)

# Set RAID_X_HOME based on OS
if [ "$IS_DARWIN" = true ]; then
  RAID_X_HOME="$HOME/RaidX"
else
  RAID_X_HOME="/mnt/e/vms/macos/raidx/RaidX"
fi

if [[ "$MODE" == "dev" ]]; then
    echo "🔧 Running in development mode"
elif [[ "$MODE" == "build" ]]; then
    echo "🚀 Running in production mode"
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

set_header "Upload Project"

start=$(start_time)


# ================================
# CONFIG SETUP
# ================================
LOCAL_ZIP="project-backup.zip"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CLIENT_ID="TESTER"
BUILD_ID="UID_${CLIENT_ID}_${TIMESTAMP}"

# Mac VM
SERVER_IP="8.30.153.32"
SERVER_USER="Rafael"
SERVER_PASS="38nRWm1y"

# Remote Mac VM Paths
REMOTE_BASE_DIR="${RAIDX_PATH}/Clients"
REMOTE_DIR="${REMOTE_BASE_DIR}/${CLIENT_ID}/${BUILD_ID}"
REMOTE_TOOLS_DIR="${RAIDX_PATH}/Tools"
REMOTE_SCRIPT="main_build.sh"

# Android Certs
ANDROID_ACCOUNT_ID="7619593200483522519"
ANDROID_EMAIL="dev.apps@sweetrush.com"
ANDROID_KEYSTORE="${REMOTE_DIR}/certs/google/elsoapp.keystore.jks"
ANDROID_KEYSTORE_PASS="QHiH97VVlWRqR5ROMDn9"
ANDROID_ALIAS="key0"

# iOS Certs and Profile Paths
P12_PATH="${REMOTE_DIR}/certs/ios/iOS_Dist_Key.p12"
P12_PASSWORD="#SweetRush@"
PROVISION_ID="ELSO Staging AppStore/TestFlight"
PROVISION_NAME="ELSO_Staging_AppStoreTestFlight"
PROVISION_PATH="${REMOTE_DIR}/certs/ios/profiles/${PROVISION_NAME}.mobileprovision"
IS_UPLOADING="false"

# === Requirements check ===
if ! command -v sshpass >/dev/null 2>&1; then
    echo "❌ sshpass is not installed. Install it with: sudo apt-get install sshpass"
    exit 1
fi

# === Create remote folder ===
echo "📂 Creating remote folder: $REMOTE_DIR"
sshpass -p "$SERVER_PASS" ssh -t "$SERVER_USER@$SERVER_IP" "mkdir -p '$REMOTE_DIR'"

# === Upload zip file ===
echo "⬆️  Uploading $LOCAL_ZIP to $REMOTE_DIR ..."
sshpass -p "$SERVER_PASS" scp "$LOCAL_ZIP" "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/" &

pid=$!
spinner_progress $pid "uploading project $BUILD_ID"
wait $pid

if [ $? -ne 0 ]; then
    echo "❌ Upload failed"
    exit 1
fi

# === Extract zip file on VPS ===
echo "📦 Extracting $LOCAL_ZIP ..."
sshpass -p "$SERVER_PASS" ssh "$SERVER_USER@$SERVER_IP" "
  cd '$REMOTE_DIR' &&
  unzip -o '$LOCAL_ZIP' > /dev/null 2>&1 &&
  rm -f '$LOCAL_ZIP'
" &

pid=$!
spinner_progress $pid "extract project"
wait $pid

# === Run REMOTE_SCRIPT on the VPS ===
echo "🚀 Running $REMOTE_SCRIPT on $SERVER_IP ..."

sshpass -p "$SERVER_PASS" ssh -t "$SERVER_USER@$SERVER_IP" \
  "$REMOTE_TOOLS_DIR/$REMOTE_SCRIPT" \
    \"$MODE\" \
    \"$CLIENT_ID\" \
    \"$BUILD_ID\" \
    \"$P12_PATH\" \
    \"$P12_PASSWORD\" \
    \"$PROVISION_ID\" \
    \"$PROVISION_PATH\" \
    \"$PROVISION_NAME\"

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
else
    echo "❌ Build failed CLIENT_ID: $CLIENT_ID"
    echo "🆔 BUILD_ID: ${BUILD_ID}"
fi

# echo "👉  To remove this build:"
# echo "./removeBuild.sh $CLIENT_ID $BUILD_ID"
# REMOVE_CMD="./removeBuild.sh"
# if [[ ! -x "$REMOVE_CMD" ]]; then
#   echo "❌ Error: $REMOVE_CMD not found or not executable!"
#   exit 1
# fi
# # === Remove current build on the VPS ===
# "$REMOVE_CMD" "$CLIENT_ID" "$BUILD_ID"

echo "✅ Disposing build files..."
sshpass -p "$SERVER_PASS" ssh -t "$SERVER_USER@$SERVER_IP" \
  "$RAIDX_SCRIPTS_PATH/build_dispose.sh" \
    \"$MODE\" \
    \"$CLIENT_ID\" \
    \"$BUILD_ID\"

if [ $? -eq 0 ]; then
    echo "✅ Removed build files"
else
    echo "❌ Failed to remove build files"
    exit 1
fi

echo "👉  To remove this build:"
echo "./removeBuild.sh $CLIENT_ID $BUILD_ID"

echo "🎉 Build pipeline complete"

elapsed=$(end_time "$start")
echo "Elapsed: $elapsed"



