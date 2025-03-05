#!/bin/bash

# Default values
DEFAULT_INTERFACE="eth0"
DEFAULT_GATEWAY="192.168.1.1"
DEFAULT_DNS="192.168.86.2 1.1.1.1"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if nmcli is installed
if ! command_exists nmcli; then
    echo "Error: nmcli is not installed. Please install NetworkManager (e.g., 'yum install NetworkManager')."
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)."
    exit 1
fi

# List available connections
echo "Available network connections:"
nmcli con show
echo

# Prompt for interface name
read -p "Enter the network interface name (default: $DEFAULT_INTERFACE): " INTERFACE
INTERFACE=${INTERFACE:-$DEFAULT_INTERFACE}

# Verify the interface exists
if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
    echo "Error: Interface '$INTERFACE' does not exist. Check 'ip link' for valid interfaces."
    exit 1
fi

# Get the connection name associated with the interface
CONNECTION=$(nmcli -t -f NAME,DEVICE con show | grep ":$INTERFACE$" | cut -d: -f1)
if [ -z "$CONNECTION" ]; then
    echo "Error: No active connection found for interface '$INTERFACE'. Check 'nmcli con show'."
    exit 1
fi
echo "Using connection: $CONNECTION for interface $INTERFACE"

# Prompt for IP address
while true; do
    read -p "Enter the static IP address (e.g., 192.168.1.100): " IPADDRESS
    # Basic IP validation (checks format like xxx.xxx.xxx.xxx)
    if [[ "$IPADDRESS" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r i1 i2 i3 i4 <<< "$IPADDRESS"
        if [ "$i1" -le 255 ] && [ "$i2" -le 255 ] && [ "$i3" -le 255 ] && [ "$i4" -le 255 ]; then
            break
        else
            echo "Error: Each octet must be between 0 and 255."
        fi
    else
        echo "Error: Invalid IP address format. Use xxx.xxx.xxx.xxx."
    fi
done

# Configure the static IP
echo "Configuring static IP: $IPADDRESS/24"
nmcli con mod "$CONNECTION" ipv4.addresses "$IPADDRESS/24"
nmcli con mod "$CONNECTION" ipv4.gateway "$DEFAULT_GATEWAY"
nmcli con mod "$CONNECTION" ipv4.dns "$DEFAULT_DNS"
nmcli con mod "$CONNECTION" ipv4.method manual

# Apply changes
echo "Applying changes..."
nmcli con down "$CONNECTION"
nmcli con up "$CONNECTION"

# Verify the configuration
echo "Verifying configuration..."
ip addr show "$INTERFACE"
echo "Gateway:"
ip route | grep default
echo "DNS:"
cat /etc/resolv.conf

echo "Static IP configuration complete!"
echo "If connectivity fails, check gateway ($DEFAULT_GATEWAY) and DNS ($DEFAULT_DNS) settings."
