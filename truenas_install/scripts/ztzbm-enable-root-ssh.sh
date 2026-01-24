#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Error: Please run as root or use sudo."
  exit 1
fi

echo "Configuring SSH for root access..."

# 1. Create a backup of the current config
CONF_FILE="/etc/ssh/sshd_config"
cp "$CONF_FILE" "${CONF_FILE}.bak.$(date +%Y%m%d_%H%M%S)"

# 2. Update PermitRootLogin to yes
# This regex handles commented (#) and uncommented lines
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$CONF_FILE"

# 3. Ensure PasswordAuthentication is enabled
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$CONF_FILE"

# 4. Validate the SSH configuration syntax
if sshd -t; then
    echo "Configuration syntax is valid. Restarting SSH service..."
    systemctl restart ssh || systemctl restart sshd
    echo "--------------------------------------------------------"
    echo "✅ SUCCESS: Root login is now enabled."
    echo "⚠️  REMOTE TIP: Ensure the root user has a strong password!"
    echo "--------------------------------------------------------"
else
    echo "❌ ERROR: Detected syntax errors in sshd_config. Reverting changes not recommended."
    exit 1
fi