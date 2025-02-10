#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

# Installing extras
echo "."
echo "*** installing extras. ***"

# Install neofetch and modify bashrc for current user (note we preserve the actual user)
ACTUAL_USER=$(logname || echo $SUDO_USER)
apt install neofetch -y
echo "neofetch" >> /home/$ACTUAL_USER/.bashrc

# Download and setup startup script
wget https://raw.githubusercontent.com/asophila/headless/main/startup.sh
mv startup.sh /home/$ACTUAL_USER/
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/startup.sh
chmod +x /home/$ACTUAL_USER/startup.sh

# Modify rc.local
sed -i "\$i sh /home/$ACTUAL_USER/startup.sh\n" /etc/rc.local
chmod +x /etc/rc.local

# Get ntfy.sh group name
echo -n "Insert a name for the ntfy.sh group where the network IP will be posted (default: secret_ip): "
read group
group=${group:-secret_ip}
sed -i "s/SECRET_GROUP/$group/g" /home/$ACTUAL_USER/startup.sh

# Set hostname
echo -n "Insert a name for this host (default: chip): "
read hname
hname=${hname:-chip}
hostnamectl set-hostname $hname

echo "."
echo "*** Done ***"
