#!/bin/bash
MNT="$1"
# Get the first active network interface name
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

if [ -z "$INTERFACE" ]; then
    echo "No active network interface found"
    exit 1
fi

echo "Found network interface: $INTERFACE"

# Backup current configuration
cp ${MNT}/etc/network/interfaces ${MNT}/etc/network/interfaces.bak

# Set to DHCP mode
cat > ${MNT}/etc/network/interfaces << EOF
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
