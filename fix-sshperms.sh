#!/bin/bash
# sudo ./fix-sshperms.sh username

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Default to the current user's home directory if no user is specified
if [ -z "$1" ]; then
    echo "No user specified. Usage: $0 <username>"
    echo "Example: $0 k8s"
    exit 1
else
    TARGET_USER="$1"
fi

# Check if the user exists
if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "User '$TARGET_USER' does not exist. Aborting."
    exit 1
fi

# Get the user's home directory
HOME_DIR=$(getent passwd "$TARGET_USER" | cut -d: -f6)
SSH_DIR="$HOME_DIR/.ssh"

# Check if .ssh directory exists
if [ ! -d "$SSH_DIR" ]; then
    echo "No .ssh directory found for user '$TARGET_USER' at $SSH_DIR. Creating it."
    mkdir -p "$SSH_DIR"
    chown "$TARGET_USER:$TARGET_USER" "$SSH_DIR"
fi

# Set correct permissions recursively
echo "Setting permissions for $SSH_DIR and its contents..."

# Set .ssh directory to 700 (rwx------)
chmod 700 "$SSH_DIR"
chown "$TARGET_USER:$TARGET_USER" "$SSH_DIR"

# Set all files inside .ssh to 600 (rw-------)
find "$SSH_DIR" -type f -exec chmod 600 {} \;
find "$SSH_DIR" -type f -exec chown "$TARGET_USER:$TARGET_USER" {} \;

# Set any subdirectories inside .ssh to 700 (rare, but covering all bases)
find "$SSH_DIR" -type d -not -path "$SSH_DIR" -exec chmod 700 {} \;
find "$SSH_DIR" -type d -not -path "$SSH_DIR" -exec chown "$TARGET_USER:$TARGET_USER" {} \;

echo "Permissions corrected for $SSH_DIR:"
ls -ld "$SSH_DIR"
echo "Contents of $SSH_DIR:"
ls -l "$SSH_DIR"

echo "Done!"
