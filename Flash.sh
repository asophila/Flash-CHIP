#!/bin/bash

# ASCII Art Logo
echo "   #  #  #"
echo "  #########"
echo "###       ###"
echo "  # {#}   #"
echo "###  '\######"
echo "  #       #"
echo "###       ###"
echo "  ########"
echo "   #  #  #"

echo " Welcome to the C.H.I.P Flasher Tool " 

echo " Please enter your wanted flavour " 
echo " ++++++++++++++++++++++++++++++++++++++++++ "
echo " enter p for pocketchip Image "
echo " enter s for the headless Server Image "
echo " enter g for the Desktop Image "
echo " enter b for the Buildroot Image " 
echo " ++++++++++++++++++++++++++++++++++++++++++ "
echo " IMPORTANT INFO "
echo " If u suffer from Power Problems add a n "
echo " to your choice of flavour "
echo " Example: gn for the No-Limit Desktop Image "
echo " ++++++++++++++++++++++++++++++++++++++++++ "
echo " Other options " 
echo " ++++++++++++++++++++++++++++++++++++++++++ "
echo " enter f for Force Clean " 
echo " ++++++++++++++++++++++++++++++++++++++++++ "
echo " Then press enter please " 

read flavour

echo -e "\n Setting up environment"
sudo apt -y update
sudo apt -y install \
 git \
 fastboot \
 u-boot-tools \
 adb \
 android-tools-fastboot \
 curl \
 wget \
 sunxi-tools

echo -e "\n Adding current user to dialout group"
sudo usermod -a -G dialout $USER

echo -e "\n Adding current user to plugdev group"
sudo usermod -a -G plugdev $USER

echo -e "\n Adding udev rule for Allwinner device"
echo -e 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="efe8", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip"
SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="1010", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip-fastboot"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="1010", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip-fastboot"
SUBSYSTEM=="usb", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", GROUP="plugdev", MODE="0660" SYMLINK+="usb-serial-adapter"
' | sudo tee /etc/udev/rules.d/99-allwinner.rules
sudo udevadm control --reload-rules

echo -e "\n Installing CHIP-tools"
if [ -d CHIP-tools ]; then
    cd CHIP-tools 
    git pull 
else
    git clone https://github.com/Project-chip-crumbs/CHIP-tools.git
    cd CHIP-tools
fi

echo -e "\n Removing incompatible fastboot parameters"
find . -type f -name "*.sh" -exec sed -i 's/-i 0x1f3a//g' {} +
#find . -type f -name "*.sh" -exec sed -i 's///g' {} +
find . -type f -name "*.sh" -exec sed -i 's/\(fastboot\|${FASTBOOT}\)[[:space:]]*-u[[:space:]]*flash/\1 flash/g' {} +

echo -e "\n Installing screen"
sudo apt install screen -y

# Create a temporary directory for post-flash setup
mkdir -p post_flash_setup

# Copy setup scripts from CHIP-updater
cp ../CHIP-updater/wifi-setup.sh post_flash_setup/
cp ../CHIP-updater/unified-upgrade.sh post_flash_setup/
chmod +x post_flash_setup/*.sh

# Modify the UBI flashing script to include our setup files
# First, backup the original script
cp chip-update-firmware.sh chip-update-firmware.sh.backup

# Add our post-flash setup to the UBI creation
sed -i '/Creating UBI image/a\
# Copy setup scripts to rootfs\
sudo mkdir -p $TMPDIR/rootfs/home/chip/CHIP-updater\
sudo cp post_flash_setup/* $TMPDIR/rootfs/home/chip/CHIP-updater/\
sudo chown -R 1000:1000 $TMPDIR/rootfs/home/chip/CHIP-updater\
sudo chmod +x $TMPDIR/rootfs/home/chip/CHIP-updater/*.sh' chip-update-firmware.sh

# Run the flashing command
FEL='sudo sunxi-fel' FASTBOOT='sudo fastboot' SNIB=false ./chip-update-firmware.sh -$flavour

# Clean up
rm -rf post_flash_setup
mv chip-update-firmware.sh.backup chip-update-firmware.sh

echo -e "\n Flash complete!"
echo "================================================================"
echo "Next steps:"
echo "1. Remove FEL jumper"
echo "2. Unplug and replug your CHIP"
echo "3. Connect using: sudo screen /dev/ttyACM0 115200"
echo "4. Login with chip/chip"
echo "5. Run: sudo /home/chip/CHIP-updater/wifi-setup.sh"
echo "6. After WiFi setup, run: sudo /home/chip/CHIP-updater/unified-upgrade.sh"
echo "================================================================"
