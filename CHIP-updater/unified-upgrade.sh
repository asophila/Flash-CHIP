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
        "buster")
            # For Buster archive, include backports and correct security path
            cat > /etc/apt/sources.list <<EOF
deb [check-valid-until=no] http://archive.debian.org/debian buster main contrib non-free
deb [check-valid-until=no] http://archive.debian.org/debian buster-backports main contrib non-free
deb [check-valid-until=no] http://archive.debian.org/debian-security buster/updates main contrib non-free
EOF
            ;;
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
    
    # Force apt to accept archived repos without valid signatures
    if [ "$target" = "buster" ]; then
        # Create or modify apt configuration for archived repositories
        cat > /etc/apt/apt.conf.d/99archive-repos <<EOF
Acquire::Check-Valid-Until "false";
APT::Get::AllowUnauthenticated "true";
EOF
    fi
    
    # Replace occurrences in any remaining files but only for non-buster
    if [ "$target" != "buster" ]; then
        find /etc/apt -type f -name "*.list" -exec sed -i "s/$version/$target/g" {} +
    fi
}
