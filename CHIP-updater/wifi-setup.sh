#!/bin/bash

# This script should be downloaded and run first on the CHIP through screen
# to establish initial WiFi connection

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo su -)"
    exit 1
fi

# Function to setup WiFi
setup_wifi() {
    echo "Setting up WiFi connection..."
    
    # Prompt for WiFi credentials
    read -p "Enter WiFi SSID: " SSID
    read -s -p "Enter WiFi password: " PASSWORD
    echo

    # Connect to WiFi
    nmcli device wifi connect "$SSID" password "$PASSWORD"
    
    if [ $? -eq 0 ]; then
        echo "Successfully connected to WiFi"
        # Set auto-connect
        nmcli c m "$SSID" connection.autoconnect yes
        
        # Get and display IP
        IP=$(ip addr | grep "inet " | awk 'NR==2{print $2}' | cut -d/ -f1)
        echo "================================================================"
        echo "Device IP: $IP"
        echo "Write down this IP address - you'll need it for SSH connection!"
        echo "Next steps:"
        echo "1. Exit screen (Ctrl+A, then press K, then press Y)"
        echo "2. From your computer, run: ssh chip@$IP"
        echo "3. When connected via SSH, run the upgrade script:"
        echo "   curl -s https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/upgrade-debian.sh -o upgrade-debian.sh"
        echo "   chmod +x upgrade-debian.sh"
        echo "   sudo ./upgrade-debian.sh"
        echo "================================================================"
    else
        echo "Failed to connect to WiFi. Please try again."
        setup_wifi
    fi
}

# Main execution
setup_wifi
