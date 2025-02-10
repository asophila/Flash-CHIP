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

perform_upgrade() {
    local version=$1
    echo "Performing upgrade for $version..."
    
    # By default, go to buster from any older version
    if [ "$version" = "jessie" ] || [ "$version" = "stretch" ]; then
        cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian/ buster main contrib non-free
deb http://security.debian.org/ buster/updates main contrib non-free
EOF
        version="buster"
    else
        case $version in
            "buster")
                cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free
EOF
                ;;
            "bullseye")
                cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bookworm contrib main non-free-firmware
deb http://deb.debian.org/debian bookworm-updates contrib main non-free-firmware
deb http://deb.debian.org/debian bookworm-backports contrib main non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security contrib main non-free-firmware
EOF
                ;;
        esac
    fi

    # Perform upgrade
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes debian-keyring debian-archive-keyring || true
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --force-yes
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --force-yes

    # Version-specific tasks for older systems
    if [ "$version" = "jessie" ] || [ "$version" = "stretch" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes locales || true
        if command -v locale-gen >/dev/null 2>&1; then
            locale-gen en_US en_US.UTF-8
            dpkg-reconfigure locales
            dpkg-reconfigure tzdata
        fi
    fi
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
