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

    # Set apt options based on version
    if [ "$version" = "jessie" ] || [ "$version" = "stretch" ] || [ "$version" = "buster" ]; then
        APT_OPTIONS="-y --force-yes"
    else
        APT_OPTIONS="-y --allow-downgrades --allow-remove-essential --allow-change-held-packages"
    fi

    get_best_mirror $version

    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS debian-keyring debian-archive-keyring || true
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade $APT_OPTIONS
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
    APT_OPTIONS="-y --allow-downgrades --allow-remove-essential --allow-change-held-packages"
    echo "Installing quality of life improvements..."
    
    ACTUAL_USER=$(logname || echo $SUDO_USER)
    
    # Install neofetch and basic packages
    DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS neofetch
    
    # Add backports repository for newer Go version
    if ! grep -q "bookworm-backports" /etc/apt/sources.list; then
        echo "deb http://deb.debian.org/debian bookworm-backports main" >> /etc/apt/sources.list
    fi
    apt-get update

    # Install wireguard tools and dependencies
    DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS \
        wireguard-tools \
        git \
        make \
        build-essential \
        openresolv

    # Install Go from backports
    DEBIAN_FRONTEND=noninteractive apt-get install -t bookworm-backports $APT_OPTIONS golang

    # Build and install wireguard-go from source
    echo "Building wireguard-go from source..."
    cd /tmp
    rm -rf wireguard-go
    git clone https://git.zx2c4.com/wireguard-go
    cd wireguard-go
    GOPROXY=direct make
    make install

    # Clean up build directory
    cd /
    rm -rf /tmp/wireguard-go
    echo "neofetch" >> /home/$ACTUAL_USER/.bashrc
    
    # Create startup script with proper permissions
    cat > /home/$ACTUAL_USER/startup.sh <<EOF
#!/bin/bash

# Wait for network to be fully up
for i in {1..30}; do
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

# Get IP and ensure we have one
IP=\$(ip addr | grep "inet " | awk 'NR==2{print \$2}' | cut -d/ -f1)
if [ -z "\$IP" ]; then
    echo "No IP address found" >&2
    exit 1
fi

HOSTNAME=\$(hostname)

# Try multiple times to send notification
for i in {1..3}; do
    if /usr/bin/curl -H "Content-Type: text/plain" --connect-timeout 10 -m 20 --data-raw "CHIP \$HOSTNAME online: \$IP" ntfy.sh/\$NTFY_CHANNEL; then
        exit 0
    fi
    sleep 5
done

exit 1
EOF
    
    # Set proper permissions immediately after creation
    chmod +x /home/$ACTUAL_USER/startup.sh
    chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/startup.sh
    
    # Ensure curl is installed
    DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS curl

    # Create and configure systemd service for startup script
    cat > /etc/systemd/system/chip-startup.service <<EOF
[Unit]
Description=CHIP Startup Service
After=network-online.target NetworkManager-wait-online.service
Wants=network-online.target NetworkManager-wait-online.service
StartLimitIntervalSec=0

[Service]
Type=oneshot
User=$ACTUAL_USER
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStartPre=/bin/sleep 45
ExecStart=/bin/bash /home/$ACTUAL_USER/startup.sh
RemainAfterExit=yes
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable chip-startup.service
    systemctl start chip-startup.service
    
    echo -n "Insert a name for the ntfy.sh channel (default: secret_ip): "
    read NTFY_CHANNEL
    NTFY_CHANNEL=${NTFY_CHANNEL:-secret_ip}
    sed -i "s/\$NTFY_CHANNEL/$NTFY_CHANNEL/g" /home/$ACTUAL_USER/startup.sh
    
    echo -n "Insert a name for this host (default: chip): "
    read HOSTNAME
    HOSTNAME=${HOSTNAME:-chip}
    
    # Set hostname properly using both methods for compatibility
    echo "$HOSTNAME" > /etc/hostname
    hostname "$HOSTNAME"
    # Update /etc/hosts file
    sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/g" /etc/hosts
    # Use hostnamectl if available
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "$HOSTNAME"
    fi
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
