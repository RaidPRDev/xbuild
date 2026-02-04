clear
echo "--- GATHERING CONFIG DETAILS FOR REMOTE CONNECTION---"
echo ""

# 1. Get the Username
CURRENT_USER=$(whoami)

# 2. Get the Tailscale IP (Looking for 100.x.x.x)
TS_IP=$(ifconfig | grep "inet 100." | awk '{print $2}' | head -n 1)

# 3. Get Local Wi-Fi IP (Fallback)
WIFI_IP=$(ipconfig getifaddr en0)

# 4. Check if Remote Login (SSH) is enabled
# Note: We check if port 22 is open locally
SSH_STATUS=$(nc -z -v -G 1 localhost 22 2>&1 | grep "succeeded")

if [[ "$SSH_STATUS" == *"succeeded"* ]]; then
    SSH_MSG="✅ SSH is ON (Ready to connect)"
else
    SSH_MSG="❌ SSH IS OFF! (Enable in System Settings > Sharing > Remote Login)"
fi

# OUTPUT
echo "----------------------------------------"
echo "COPY AND PASTE THE BELOW TO THE DEVELOPER:"
echo "----------------------------------------"
echo ""
echo "# --- Mac Config ---"
echo "# SSH Status: $SSH_MSG"
if [ -n "$TS_IP" ]; then
    echo "MAC_SERVER_IP=\"$TS_IP\" # (Tailscale)"
else
    echo "MAC_SERVER_IP=\"$WIFI_IP\" # (Local Wi-Fi - No Tailscale found)"
fi
echo "MAC_SERVER_PORT=\"22\""
echo "MAC_SERVER_USER=\"$CURRENT_USER\""
echo "MAC_SERVER_PASS=\"(Type your Mac Login Password here)\"" 
echo ""
echo "----------------------------------------"