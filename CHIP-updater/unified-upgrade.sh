#!/bin/bash

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root"
        exit 1
    fi
}

get_debian_version() {
    grep -o "jessie\|stretch\|buster\|bullseye\|bookworm" /etc/os-release | head -n1 || echo "unknown"
}

get_best_mirror() {
    local version=$1
    
    # Check if version is archived
    case $version in
        "jessie"|"stretch"|"buster")
            cat > /etc/apt/sources.list <<EOF
deb [check-valid-until=no] http://archive.debian.org/debian/ $version main contrib non-free
deb-src [check-valid-until=no] http://archive.debian.org/debian/ $version main contrib non-free
EOF
            ;;
        "bullseye")
            cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free
EOF
            ;;
        "bookworm")
            cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bookworm contrib main non-free-firmware
deb http://deb.debian.org/debian bookworm-updates contrib main non-free-firmware
deb http://deb.debian.org/debian bookworm-backports contrib main non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security contrib main non-free-firmware
EOF
            ;;
        *)
            # For future versions, use netselect
            DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes netselect-apt || true
            netselect-apt -n -a armhf $version
            if [ -f sources.list ]; then
                mv sources.list /etc/apt/sources.list
            else
                # Fallback to main mirror if netselect fails
                cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian $version main contrib non-free
deb http://security.debian.org/debian-security $version-security main contrib non-free
EOF
            fi
            ;;
    esac
}

perform_upgrade() {
    local version=$1
    echo "Performing upgrade for $version..."
    
    # By default, go to buster from any older version
    if [ "$version" = "jessie" ] || [ "$version" = "stretch" ]; then
        version="buster"
    fi

    # Get best mirror for this version
    get_best_mirror $version

    # Update package lists and perform upgrade
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes debian-keyring debian-archive-keyring || true
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --force-yes

    # Version-specific tasks
    if [ "$version" = "jessie" ] || [ "$version" = "stretch" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes locales || true
        if command -v locale-gen >/dev/null 2>&1; then
            locale-gen en_US en_US.UTF-8
            dpkg-reconfigure locales
            dpkg-reconfigure tzdata
        fi
    fi
}

install_extras() {
    echo "Installing quality of life improvements..."
    
    # Get actual user
    ACTUAL_USER=$(logname || echo $SUDO_USER)
    
    # Install neofetch
    DEBIAN_FRONTEND=noninteractive apt-get install -y neofetch
    echo "neofetch" >> /home/$ACTUAL_USER/.bashrc
    
    # Setup startup script
    cat > /home/$ACTUAL_USER/startup.sh <<EOF
#!/bin/bash
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
    "jessie"|"stretch")
        echo "Starting upgrade path: -> buster -> bullseye -> bookworm"
        perform_upgrade $current_version
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
        install_extras
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
