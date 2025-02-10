# Revive an outdated C.H.I.P. from factory OS to Debian Bookworm
This guide is based on community contributions and testing, particularly from Reddit user experiences with upgrading to newer Debian versions.

## Instructions
### Part 1: Prepare your Linux machine
1. Remove the C.H.I.P. from its case (in case you have a Pocket C.H.I.P.).
2. On your Linux machine, install the required dependencies:
    ```bash
    sudo apt install u-boot-tools fastboot git build-essential curl libusb-1.0-0-dev pkg-config
    ```
3. Add your user to required groups:
    ```bash
    sudo usermod -a -G dialout,plugdev $USER
    ```
4. Add udev rules for the CHIP:
    ```bash
    sudo tee /etc/udev/rules.d/99-allwinner.rules <<EOF
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="efe8", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="1010", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip-fastboot"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1f3a", ATTRS{idProduct}=="1010", GROUP="plugdev", MODE="0660" SYMLINK+="usb-chip-fastboot"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", GROUP="plugdev", MODE="0660" SYMLINK+="usb-serial-adapter"
    EOF
    ```
5. Install the correct version of sunxi-tools:
    ```bash
    git clone https://github.com/linux-sunxi/sunxi-tools -b v1.4 && cd sunxi-tools
    make && sudo make install-tools
    ```
6. Get the modified flashing tools:
    ```bash
    git clone https://github.com/Project-chip-crumbs/CHIP-tools && cd CHIP-tools
    ```

### Part 2: Flash and Connect
1. Connect the FEL and a GROUND pin of the C.H.I.P. (for example, with a paperclip)
2. Connect the C.H.I.P.'s micro USB port to your Linux machine. Make sure to use a good quality cable and power source
3. Run the flash command:
    ```bash
    FEL='sudo sunxi-fel' FASTBOOT='sudo fastboot' SNIB=false ./chip-update-firmware.sh -s
    ```
4. After flashing completes:
    - Remove the FEL connection (paperclip)
    - Unplug for 3 seconds
    - Plug the C.H.I.P. back in
5. Connect to the CHIP:
    ```bash
    screen /dev/ttyACM0 115200
    ```
6. Login with user: `chip` and password: `chip`
7. Set up WiFi:
    ```bash
    nmcli device wifi connect <YOUR_SSID> password <YOUR_PASSWORD>
    ```

### Part 3: Upgrade directly to Debian Bookworm
1. Connect via SSH:
    ```bash
    ssh chip@<CHIP_IP>
    ```
2. Switch to root:
    ```bash
    sudo su -
    ```
3. Update the package sources:
    ```bash
    sudo tee /etc/apt/sources.list <<EOF
    deb http://deb.debian.org/debian bookworm contrib main non-free-firmware
    deb http://deb.debian.org/debian bookworm-updates contrib main non-free-firmware
    deb http://deb.debian.org/debian bookworm-backports contrib main non-free-firmware
    deb http://deb.debian.org/debian-security bookworm-security contrib main non-free-firmware
    EOF
    ```
4. Perform the upgrade:
    ```bash
    sudo apt update
    sudo apt -y full-upgrade
    sudo apt -y autoremove
    ```
5. Reboot the C.H.I.P.

## Troubleshooting
- If you get FEL timeout errors: Try a different USB cable or replug right before flashing
- If flash succeeds but boot fails: Use a better power source
- If you get APT errors: Run `sudo apt-get install -f` and `sudo dpkg --configure -a`
- For Bluetooth issues: Disable if unused with `sudo systemctl disable bluetooth`
