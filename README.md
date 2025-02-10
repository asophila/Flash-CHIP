# Revive an outdated C.H.I.P. to Debian Bookworm

This guide helps you upgrade your C.H.I.P. from factory OS to the latest Debian Bookworm using automated scripts.

## Part 1: Flash the C.H.I.P.
1. Hardware setup:
   - Remove C.H.I.P. from case (if using PocketC.H.I.P.)
   - Connect FEL to GND pin (using paperclip)
   - Connect C.H.I.P. to computer via USB cable (ensure good power supply)

2. Flash the device:
   ```bash
   git clone https://github.com/asophila/Flash-CHIP.git
   cd Flash-CHIP
   sudo chmod +x Flash.sh
   ./Flash.sh
   ```
   - Select desired image when prompted
   - Wait for flashing to complete

## Part 2: Initial Setup
1. After flashing:
   - Remove FEL jumper (paperclip)
   - Unplug for 3 seconds
   - Reconnect the C.H.I.P.

2. Connect and setup WiFi:
   ```bash
   sudo screen /dev/ttyACM0 115200
   ```
   - Login with: user `chip`, password `chip`
   - Setup WiFi: `sudo nmtui`
   - Get IP address: `ip addr | grep "inet " | awk 'NR==2{print $2}' | cut -d/ -f1`

## Part 3: Automated Upgrade
1. Connect via SSH:
   ```bash
   ssh chip@<CHIP_IP>
   ```

2. Run the upgrade script:
   ```bash
   sudo su -
   curl -s https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/upgrade-debian.sh -o upgrade-debian.sh
   chmod +x upgrade-debian.sh
   ./upgrade-debian.sh
   ```

3. Follow the prompts:
   - The script will automatically detect your current Debian version
   - It will perform the necessary upgrades in sequence
   - Reboot when prompted
   - After each reboot, reconnect via SSH and run the script again
   - Repeat until you reach Bookworm

## Optional: Install Enhancements
When you reach Bookworm, the script will offer to install quality-of-life enhancements:
- Select 'y' when prompted to install extras
- Enter a unique ntfy.sh channel name when asked
- Enter a hostname when asked

## Troubleshooting
- FEL timeout: Try different USB cable or replug before flashing
- Boot failure: Use better power source
- APT errors: Run `sudo apt-get install -f` and `sudo dpkg --configure -a`
- WiFi issues: After each reboot, verify connection with `nmcli c`
