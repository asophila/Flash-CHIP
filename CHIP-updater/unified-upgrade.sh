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

update_apt_sources() {
    local version=$1
    local target=$2
    echo "Updating APT sources from $version to $target..."
    
    # Backup current sources
    if [ -f "/etc/apt/sources.list" ]; then
        cp /etc/apt/sources.list "/etc/apt/sources.list.${version}.backup"
    fi
    
    # Clear out all old source lists
    rm -f /etc/apt/sources.list.d/*.list
    
    case $target in
        "bullseye")
            cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
EOF
            ;;
        "bookworm")
            cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian bookworm main contrib non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware
EOF
            ;;
        *)
            echo "Error: Unsupported target version $target"
            exit 1
            ;;
    esac
    
    # Replace occurrences in any remaining files
    find /etc/apt -type f -name "*.list" -exec sed -i "s/$version/$target/g" {} +
}

perform_upgrade() {
    local version=$1
    echo "Performing upgrade for $version..."
    
    # Set apt options
    APT_OPTIONS="-y --allow-downgrades --allow-remove-essential --allow-change-held-packages"

    # Fix extended states before proceeding
    fix_extended_states
    
    # Determine target version
    local target_version
    if [ "$version" = "buster" ]; then
        target_version="bullseye"
    elif [ "$version" = "bullseye" ]; then
        target_version="bookworm"
    else
        echo "Error: Unsupported version $version"
        exit 1
    fi
    
    # Update sources to target version
    update_apt_sources "$version" "$target_version"

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
    
    # Perform a minimal upgrade first
    echo "Performing minimal upgrade..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade $APT_OPTIONS --without-new-pkgs
    
    # Then do the full upgrade
    echo "Performing full dist-upgrade..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade $APT_OPTIONS; then
        echo "dist-upgrade failed, attempting to fix and retry..."
        dpkg --configure -a
        DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade $APT_OPTIONS --fix-broken
    fi
    
    DEBIAN_FRONTEND=noninteractive apt-get autoremove $APT_OPTIONS
}

install_extras() {
    # Extra installations if needed
    true
}

# Main script starts here
check_root

current_version=$(get_debian_version)
echo "Current Debian version: $current_version"

case $current_version in
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
Upgrade complete. Please reboot and run this script again to continue to the next version.
Next steps:
1. Reboot your system: sudo reboot
2. After reboot, run this script again to upgrade to the next version.
"
