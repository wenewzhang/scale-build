#!/bin/bash

# Get the first active network interface name
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

if [ -z "$INTERFACE" ]; then
    echo "No active network interface found"
    exit 1
fi

echo "Found network interface: $INTERFACE"

# Backup current configuration
cp /mnt/etc/network/interfaces /mnt/etc/network/interfaces.bak

# Set to DHCP mode
cat > /mnt/etc/network/interfaces << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $INTERFACE
iface $INTERFACE inet dhcp
EOF

echo "Set $INTERFACE to DHCP mode"

# Restart network service
if systemctl is-active --quiet networking; then
    systemctl restart networking
elif 
    ifdown "$INTERFACE" && ifup "$INTERFACE"
fi

echo "Network service restarted, $INTERFACE now uses DHCP to get IP address"