#!/bin/bash

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root"
        exit 1
    fi
}

fix_extended_states() {
    local extended_states="/var/lib/apt/extended_states"
    echo "Fixing extended states using apt-mark..."
    
    # Backup old extended_states if it exists
    if [ -f "$extended_states" ]; then
        mv "$extended_states" "${extended_states}.bak"
    fi

    # Get list of all packages
    packages=$(dpkg -l | grep '^ii' | awk '{print $2}')
    
    # Mark all existing packages as manually installed first
    echo "$packages" | xargs apt-mark manual >/dev/null 2>&1
    
    # Then mark dependencies as auto
    apt-mark auto $(apt-mark showauto) >/dev/null 2>&1
    
    echo "Package auto/manual states have been reconstructed."
}

get_debian_version() {
    grep -o "jessie\|stretch\|buster\|bullseye\|bookworm" /etc/os-release | head -n1 || echo "unknown"
}

get_best_mirror() {
    local version=$1
    
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
            DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS netselect-apt || true
            netselect-apt -n -a armhf $version
            if [ -f sources.list ]; then
                mv sources.list /etc/apt/sources.list
            else
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
    
    if [ "$version" = "jessie" ] || [ "$version" = "stretch" ]; then
        version="buster"
    fi

    # Set apt options
    APT_OPTIONS="-y --allow-downgrades --allow-remove-essential --allow-change-held-packages"

    # Fix extended states before proceeding
    fix_extended_states

    get_best_mirror $version

    # Prepare system for upgrade
    echo "Preparing for upgrade..."
    DEBIAN_FRONTEND=noninteractive apt-get clean
    
    # Update package lists
    echo "Updating package lists..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get update --fix-missing; then
        echo "Initial update failed, retrying after a short delay..."
        sleep 5
        if ! DEBIAN_FRONTEND=noninteractive apt-get update --fix-missing; then
            echo "ERROR: Unable to update package lists"
            exit 1
        fi
    fi
    
    # Install new keyrings first
    echo "Installing package keyrings..."
    DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS debian-keyring debian-archive-keyring || true
    
    # Update again after installing new keyrings
    DEBIAN_FRONTEND=noninteractive apt-get update
    
    # Perform the actual upgrade
    echo "Performing dist-upgrade..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade $APT_OPTIONS; then
        echo "dist-upgrade failed, attempting to fix and retry..."
        dpkg --configure -a
        DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade $APT_OPTIONS --fix-broken
    fi
    
    DEBIAN_FRONTEND=noninteractive apt-get autoremove $APT_OPTIONS

    if [ "$version" = "jessie" ] || [ "$version" = "stretch" ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS locales || true
        if command -v locale-gen >/dev/null 2>&1; then
            locale-gen en_US en_US.UTF-8
            dpkg-reconfigure locales
            dpkg-reconfigure tzdata
        fi
    fi
}

install_extras() {
    # Your existing install_extras function here
    true
}

# Main script starts here
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
