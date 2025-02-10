#!/bin/bash

# Upgrade from stretch to bullseye
echo "."
echo "*** Updating and upgrading Debian Bullseye to Bookworm. ***"
mv /etc/apt/sources.list /etc/apt/sources.list.bak
wget https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/bookworm_source_list.txt
mv bookworm_source_list.txt /etc/apt/sources.list

echo "."
echo "*** apt update & upgrade ***"
apt update
apt install linux-image-armmp -y --force-yes
apt full-upgrade -y --force-yes
sleep 5

apt autoremove -y --force-yes
echo "."
echo "*** Update to Buster finished. Reboot***"
