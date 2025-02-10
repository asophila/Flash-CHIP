#!/bin/bash

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root (use sudo su -)"
        exit 1
    fi
}

# Function to get current Debian version
get_debian_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_CODENAME"
    else
        echo "unknown"
    fi
}

# Function to run upgrade script
run_upgrade() {
    local from=$1
    local to=$2
    echo "Upgrading from $from to $to..."
    
    # Backup sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.backup_$(date +%Y%m%d_%H%M%S)
    
    # Run the appropriate upgrade script
    bash <(curl -s "https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/${from}-to-${to}.sh")
    
    if [ $? -eq 0 ]; then
        echo "Upgrade to $to completed successfully. A reboot is required."
        echo "After reboot, run this script again to continue upgrading if needed."
    else
        echo "Error during upgrade. Please check the logs."
        exit 1
    fi
}

# Main script
check_root

current_version=$(get_debian_version)
echo "Current Debian version: $current_version"

case $current_version in
    "jessie")
        echo "Starting upgrade path: jessie -> stretch -> buster -> bullseye -> bookworm"
        run_upgrade "jessie" "stretch"
        ;;
    "stretch")
        echo "Starting upgrade path: stretch -> buster -> bullseye -> bookworm"
        run_upgrade "stretch" "buster"
        ;;
    "buster")
        echo "Starting upgrade path: buster -> bullseye -> bookworm"
        run_upgrade "buster" "bullseye"
        ;;
    "bullseye")
        echo "Starting upgrade path: bullseye -> bookworm"
        run_upgrade "bullseye" "bookworm"
        ;;
    "bookworm")
        echo "System is already running Debian Bookworm!"
        echo "Would you like to install extra enhancements? (y/n)"
        read -r install_extras
        if [ "$install_extras" = "y" ]; then
            wget https://raw.githubusercontent.com/asophila/Flash-CHIP/refs/heads/master/CHIP-updater/install_extras.sh
            chmod +x install_extras.sh
            ./install_extras.sh
        fi
        ;;
    *)
        echo "Unable to determine current Debian version or unsupported version detected."
        echo "This script supports upgrading from Jessie, Stretch, Buster, or Bullseye to Bookworm."
        exit 1
        ;;
esac

echo "
Next steps:
1. Reboot your system: sudo reboot
2. After reboot, run this script again to continue the upgrade process if needed.
"
