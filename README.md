# C.H.I.P. Debian Upgrade Guide

## Part 1: Flash Setup
1. Hardware preparation:
   - Remove C.H.I.P. from case (if PocketC.H.I.P.)
   - Connect FEL to GND (paperclip)
   - Connect to computer via USB

2. Flash the device:
   ```bash
   git clone https://github.com/asophila/Flash-CHIP.git
   cd Flash-CHIP
   sudo chmod +x Flash.sh
   ./Flash.sh
   ```

## Part 2: WiFi Setup
1. After flashing:
   - Remove FEL jumper
   - Unplug for 3 seconds
   - Reconnect C.H.I.P.

2. Set up WiFi (temporary screen connection):
   ```bash
   sudo screen /dev/ttyACM0 115200
   ```
   - Login: user `chip`, password `chip`
   - Setup WiFi:
   ```bash
   sudo nmcli device wifi connect <YOUR_SSID> password <YOUR_PASSWORD>
   ```
   ```bash
   sudo nmcli c m <YOUR SSID> connection.autoconnect yes
   ```
   ```bash
   ip addr | grep "inet " | awk 'NR==2{print $2}' | cut -d/ -f1 
   ```
   - Follow the prompts to enter your WiFi credentials
   - Write down the IP address displayed
   - Exit screen when done (Ctrl+A, then K, then Y)

## Part 3: Upgrade Process
1. Connect via SSH from your computer:
   ```bash
   ssh chip@<CHIP_IP>
   ```

2. Run the upgrade script:
   ```bash
   wget https://raw.githubusercontent.com/asophila/Flash-CHIP/refs/heads/master/CHIP-updater/upgrade-debian.sh
   chmod +x upgrade-debian.sh
   sudo ./upgrade-debian.sh
   ```

The upgrade script will:
- Automatically detect current Debian version
- Perform necessary upgrades in sequence
- Handle reboots automatically
- Install optional extras when complete

That's it! Just wait for the process to complete.
