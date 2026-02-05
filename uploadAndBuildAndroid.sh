#!/bin/bash
clear

# ================================
# SOURCE ENVIRONMENT
# ================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
# INCLUDE GLOBALS (reuse iOS utility functions)
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

set_header "Upload & Build Android"

start=$(start_time)

# ================================
# CONFIG SETUP
# ================================
LOCAL_ZIP="project-backup.zip"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUILD_ID="UID_${CLIENT_ID}_${TIMESTAMP}"

# Cloud server (from .env)
SSH_KEY="$CLOUD_SSH_KEY"
CLOUD_BASE_PATH="/root/RaidX/Clients"
REMOTE_DIR="${CLOUD_BASE_PATH}/${CLIENT_ID}/${BUILD_ID}"
REMOTE_TOOLS_DIR="/root/RaidX/Tools/android"

# Android cert path (constructed at runtime)
ANDROID_KEYSTORE_REMOTE="${REMOTE_DIR}/certs/google/${ANDROID_KEYSTORE_FILENAME}"

echo "📋 Build Configuration:"
echo "  🔹 BUILD_ID=$BUILD_ID"
echo "  🔹 CLIENT_ID=$CLIENT_ID"
echo "  🔹 CLOUD_HOST=$CLOUD_HOST"
echo "  🔹 REMOTE_DIR=$REMOTE_DIR"

# ================================
# STEP 1: Create remote folders and sync tools
# ================================
echo ""
echo "📂 Creating remote folders..."
ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "mkdir -p '$REMOTE_DIR' '$REMOTE_TOOLS_DIR'"

echo "🔄 Syncing Android tools to server..."
LOCAL_TOOLS_DIR="$SCRIPT_DIR/RaidX/Tools/android"
ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "mkdir -p '$REMOTE_TOOLS_DIR/.docker' '$REMOTE_TOOLS_DIR/Support/Scripts'"
scp -i "$SSH_KEY" -r "$LOCAL_TOOLS_DIR/Dockerfile" "$LOCAL_TOOLS_DIR/main_build.sh" "$CLOUD_USER@$CLOUD_HOST:$REMOTE_TOOLS_DIR/"
scp -i "$SSH_KEY" -r "$LOCAL_TOOLS_DIR/.docker/"* "$CLOUD_USER@$CLOUD_HOST:$REMOTE_TOOLS_DIR/.docker/"
scp -i "$SSH_KEY" -r "$LOCAL_TOOLS_DIR/Support/globals.sh" "$CLOUD_USER@$CLOUD_HOST:$REMOTE_TOOLS_DIR/Support/"
scp -i "$SSH_KEY" -r "$LOCAL_TOOLS_DIR/Support/Scripts/"* "$CLOUD_USER@$CLOUD_HOST:$REMOTE_TOOLS_DIR/Support/Scripts/" &

pid=$!
spinner_progress $pid "syncing tools"
wait $pid

# ================================
# STEP 2: Upload zip file
# ================================
echo "⬆️  Uploading $LOCAL_ZIP to $REMOTE_DIR ..."
scp -i "$SSH_KEY" "$LOCAL_ZIP" "$CLOUD_USER@$CLOUD_HOST:$REMOTE_DIR/" &

pid=$!
spinner_progress $pid "uploading project $BUILD_ID"
wait $pid

if [ $? -ne 0 ]; then
    echo "❌ Upload failed"
    exit 1
fi

# ================================
# STEP 3: Extract zip on remote
# ================================
echo "📦 Extracting $LOCAL_ZIP ..."
ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "
  cd '$REMOTE_DIR' &&
  unzip -o '$LOCAL_ZIP' > /dev/null 2>&1 &&
  rm -f '$LOCAL_ZIP'
" &

pid=$!
spinner_progress $pid "extract project"
wait $pid

# ================================
# STEP 4: Build Docker image (cached after first build)
# ================================
echo "🐳 Preparing Docker build environment..."
ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "
  cd '$REMOTE_TOOLS_DIR' &&
  docker build -t raidx-android-builder:latest .
" &

pid=$!
spinner_progress $pid "building Docker image"
wait $pid

if [ $? -ne 0 ]; then
    echo "❌ Docker image build failed"
    exit 1
fi

# ================================
# STEP 5: Run Android build in Docker container
# ================================
echo "🚀 Running Android build in Docker container..."

ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "
  docker run --rm \
    -v '${REMOTE_DIR}:/workspace' \
    -v '${REMOTE_TOOLS_DIR}:/tools' \
    -v raidx-gradle-cache:/root/.gradle \
    -e MODE='$MODE' \
    -e CLIENT_ID='$CLIENT_ID' \
    -e BUILD_ID='$BUILD_ID' \
    -e ANDROID_KEYSTORE='/workspace/certs/google/${ANDROID_KEYSTORE_FILENAME}' \
    -e ANDROID_KEYSTORE_PASS='$ANDROID_KEYSTORE_PASS' \
    -e ANDROID_ALIAS='$ANDROID_ALIAS' \
    -e ANDROID_ACCOUNT_ID='$ANDROID_ACCOUNT_ID' \
    -e ANDROID_EMAIL='$ANDROID_EMAIL' \
    -w /workspace \
    raidx-android-builder:latest \
    bash /tools/main_build.sh
"

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
else
    echo "❌ Build failed CLIENT_ID: $CLIENT_ID"
    echo "🆔 BUILD_ID: ${BUILD_ID}"
    exit 1
fi

# ================================
# STEP 6: Copy artifacts to downloads directory
# ================================
DOWNLOADS_DIR="/root/RaidX/downloads/${CLIENT_ID}/${BUILD_ID}"
AAB_SRC="${REMOTE_DIR}/android/app/build/outputs/bundle/release/app-release.aab"
APK_SRC="${REMOTE_DIR}/android/app/build/outputs/apk/release/app-release.apk"

# Format app name: lowercase, spaces to underscores
APP_NAME_FMT=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
BUILD_DATE=$(date +%Y_%m_%d)
ARTIFACT_NAME="${APP_NAME_FMT}_${BUILD_DATE}"

echo "📦 Publishing build artifacts..."
ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "
  mkdir -p '$DOWNLOADS_DIR'
  [ -f '$AAB_SRC' ] && cp '$AAB_SRC' '$DOWNLOADS_DIR/${ARTIFACT_NAME}.aab' && echo 'Copied AAB'
  [ -f '$APK_SRC' ] && cp '$APK_SRC' '$DOWNLOADS_DIR/${ARTIFACT_NAME}.apk' && echo 'Copied APK'
"

# ================================
# STEP 7: Ensure file server is running
# ================================
echo "🌐 Ensuring xbuilds file server is running..."
ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "
  if ! docker stack ls | grep -q xbuilds; then
    echo 'Deploying xbuilds file server...'
    mkdir -p /root/RaidX/downloads
    docker stack deploy -c /root/RaidX/Tools/android/.docker/xbuilds.yml xbuilds
  else
    echo 'File server already running'
  fi
"

# ================================
# STEP 8: Cleanup remote build files
# ================================
echo "🧹 Disposing build files..."
ssh -i "$SSH_KEY" "$CLOUD_USER@$CLOUD_HOST" "
  rm -rf '${REMOTE_DIR}/node_modules'
  rm -rf '${REMOTE_DIR}/android/.gradle'
  echo 'Cleanup complete'
"

if [ $? -eq 0 ]; then
    echo "✅ Removed build files"
else
    echo "❌ Failed to remove build files"
fi

echo ""
echo "🎉 Android build pipeline complete"
echo ""
echo "📥 Download artifacts:"
echo "  AAB: https://xbuilds.raidpr.com/${CLIENT_ID}/${BUILD_ID}/${ARTIFACT_NAME}.aab"
echo "  APK: https://xbuilds.raidpr.com/${CLIENT_ID}/${BUILD_ID}/${ARTIFACT_NAME}.apk"

elapsed=$(end_time "$start")
echo "Elapsed: $elapsed"
