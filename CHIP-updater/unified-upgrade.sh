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
    grep -o "jessie\|stretch\|buster\|bullseye\|bookworm" /etc/os-release | head -n1 || echo "unknown"
}

# Source lists for different Debian versions
JESSIE_SOURCES='deb [check-valid-until=no] http://archive.debian.org/debian/ jessie main contrib non-free
deb-src [check-valid-until=no] http://archive.debian.org/debian/ jessie main contrib non-free
deb http://chip.jfpossibilities.com/chip/debian/repo jessie main
deb http://chip.jfpossibilities.com/chip/debian/pocketchip jessie main'

STRETCH_SOURCES='deb http://ftp.us.debian.org/debian/ stretch main contrib non-free
deb-src http://ftp.us.debian.org/debian/ stretch main contrib non-free
deb http://security.debian.org/ stretch/updates main contrib non-free
deb-src http://security.debian.org/ stretch/updates main contrib non-free'

BUSTER_SOURCES='deb http://deb.debian.org/debian/ buster main contrib non-free
deb http://security.debian.org/ buster/updates main contrib non-free'

BULLSEYE_SOURCES='deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free'

BOOKWORM_SOURCES='deb http://deb.debian.org/debian bookworm contrib main non-free-firmware
deb http://deb.debian.org/debian bookworm-updates contrib main non-free-firmware
deb http://deb.debian.org/debian bookworm-backports contrib main non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security contrib main non-free-firmware'

# Function to update sources.list
update_sources() {
    local version=$1
    local sources_var="${version^^}_SOURCES"  # Convert to uppercase
    echo "Updating sources.list for $version..."
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "${!sources_var}" > /etc/apt/sources.list
}

# Function to handle X11 configuration
update_x11_config() {
    local version=$1
    echo "Updating X11 configuration for $version..."
    
    if [ -f /etc/X11/xorg.conf ]; then
        mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak
    fi
    
    # Different X11 configurations based on version
    if [ "$version" = "stretch" ]; then
        cat > /etc/X11/xorg.conf <<EOF
Section "Files"
        ModulePath "/usr/lib/arm-linux-gnueabihf/xorg/modules/"
        ModulePath "/usr/lib/xorg/modules/"
EndSection
Section "Monitor"
        Identifier      "VGA"
        Option         "PreferredMode" "1024x768_60.00"
EndSection
Section "Monitor"
        Identifier      "HDMI"
        Option         "PreferredMode" "1280x720_60.00"
EndSection
Section "Monitor"
        Identifier      "Composite"
        Option         "PreferredMode" "NTSC10"
EndSection
Section "Device"
        Identifier      "Allwinner sun4i DRM"
        Driver         "armsoc"
        Option         "Monitor-Composite-0"   "Composite"
        Option         "Monitor-VGA-0"         "VGA"
        Option         "Monitor-HDMI-A-0"      "HDMI"
EndSection
EOF
    elif [ "$version" = "buster" ]; then
        cat > /etc/X11/xorg.conf <<EOF
Section "Files"
        ModulePath "/usr/lib/arm-linux-gnueabihf/xorg/modules/"
        ModulePath "/usr/lib/xorg/modules/"
EndSection
Section "Device"
        Identifier      "Card0"
        Driver         "fbdev"
EndSection
EOF
    fi
}

# Function to perform upgrade
perform_upgrade() {
    local version=$1
    echo "Performing upgrade for $version..."
    
    # Backup sources
    cp /etc/apt/sources.list /etc/apt/sources.list.backup_$(date +%Y%m%d_%H%M%S)
    
    # Update sources.list
    update_sources $version
    
    # Update and upgrade
    apt update
    apt install -y debian-keyring debian-archive-keyring
    apt update
    apt install -y linux-image-armmp
    apt full-upgrade -y
    apt autoremove -y
    
    # Update X11 config if needed
    if [ "$version" = "stretch" ] || [ "$version" = "buster" ]; then
        update_x11_config $version
    fi
    
    # Version-specific tasks
    case $version in
        "jessie")
            # Jessie-specific tasks
            apt install -y locales
            locale-gen en_US en_US.UTF-8
            dpkg-reconfigure locales
            dpkg-reconfigure tzdata
            ;;
        "bookworm")
            # Final bookworm tasks
            echo "Upgrade to Bookworm complete!"
            echo "Would you like to install extra enhancements? (y/n)"
            read -r install_extras
            if [ "$install_extras" = "y" ]; then
                install_extras
            fi
            ;;
    esac
}

# Function to install extras
install_extras() {
    echo "Installing quality of life improvements..."
    
    # Get actual user
    ACTUAL_USER=$(logname || echo $SUDO_USER)
    
    # Install neofetch
    apt install -y neofetch
    echo "neofetch" >> /home/$ACTUAL_USER/.bashrc
    
    # Setup startup script
    cat > /home/$ACTUAL_USER/startup.sh <<EOF
#!/bin/bash
# Your startup script content here
IP=\$(ip addr | grep "inet " | awk 'NR==2{print \$2}' | cut -d/ -f1)
curl -d "CHIP IP: \$IP" ntfy.sh/\$NTFY_CHANNEL
EOF
    
    chmod +x /home/$ACTUAL_USER/startup.sh
    chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/startup.sh
    
    # Modify rc.local
    sed -i "\$i sh /home/$ACTUAL_USER/startup.sh\n" /etc/rc.local
    chmod +x /etc/rc.local
    
    # Get ntfy.sh channel name
    echo -n "Insert a name for the ntfy.sh channel (default: secret_ip): "
    read NTFY_CHANNEL
    NTFY_CHANNEL=${NTFY_CHANNEL:-secret_ip}
    sed -i "s/\$NTFY_CHANNEL/$NTFY_CHANNEL/g" /home/$ACTUAL_USER/startup.sh
    
    # Set hostname
    echo -n "Insert a name for this host (default: chip): "
    read HOSTNAME
    HOSTNAME=${HOSTNAME:-chip}
    hostnamectl set-hostname $HOSTNAME
}

# Main script
check_root

current_version=$(get_debian_version)
echo "Current Debian version: $current_version"

case $current_version in
    "jessie")
        echo "Starting upgrade path: jessie -> stretch -> buster -> bullseye -> bookworm"
        perform_upgrade "jessie"
        ;;
    "stretch")
        echo "Starting upgrade path: stretch -> buster -> bullseye -> bookworm"
        perform_upgrade "stretch"
        ;;
    "buster")
        echo "Starting upgrade path: buster -> bullseye -> bookworm"
        perform_upgrade "buster"
        ;;
    "bullseye")
        echo "Starting upgrade path: bullseye -> bookworm"
        perform_upgrade "bullseye"
        ;;
    "bookworm")
        echo "System is already running Debian Bookworm!"
        perform_upgrade "bookworm"
        ;;
    *)
        echo "Unable to determine current Debian version or unsupported version detected."
        exit 1
        ;;
esac

echo "
Upgrade complete. Please reboot and run this script again if needed.
Next steps:
1. Reboot your system: sudo reboot
2. After reboot, run this script again to continue the upgrade process.
"
