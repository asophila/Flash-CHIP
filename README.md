# Revive an outdated C.H.I.P. from factory OS to Debian Bookworm
This guide is based on community contributions and testing, particularly from Reddit user experiences with upgrading to newer Debian versions.

## Instructions
### Part 1: Prepare your Linux machine
1. Remove the C.H.I.P. from its case (in case you have a Pocket C.H.I.P.).
2. Connect the FEL and a GROUND pin of the C.H.I.P. (for example, with a paperclip).
3. Connect the C.H.I.P. its micro USB port to a USB port of your Linux machine. Make sure that the port and cable allow for plenty of power. If you get a FEL error, it may be because the C.H.I.P. is running under-voltage.
4. On the Linux machine:
    - run ` git clone https://github.com/asophila/Flash-CHIP.git` to clone this repository
    - `cd Flash-CHIP` into the location where you stored this repository
    - run `sudo chmod +x Flash.sh`
    - run `./Flash.sh`
    - Select the version you want to install
    - Wait until the installation finishes
    - All toghether:
    ```bash
    git clone https://github.com/asophila/Flash-CHIP.git
    cd Flash-CHIP
    sudo chmod +x Flash.sh
    ./Flash.sh
    ```

### Part 2: Connect
1. After flashing completes:
    - Remove the FEL connection (paperclip)
    - Unplug for 3 seconds
    - Plug the C.H.I.P. back in
2. Connect to the CHIP:
    ```bash
    screen /dev/ttyACM0 115200
    ```
3. Login with user: `chip` and password: `chip`
4. Set up WiFi:
   ```bash
   sudo nmtui
   ```
5. show your current connections:
   ```bash
   sudo nmcli c
   ```
6. Set autoconnection to your SSID Wifi
   ```bash
   sudo nmcli c m <YOUR SSID> connection.autoconnect yes
   ```
7. Get your IP Address (you'll need it for ssh connection)
   ```bash
   ip addr | grep "inet " | awk 'NR==2{print $2}' | cut -d/ -f1
   ```

### Part 3: upgrade debian jessie to debian stretch
1. Connect via SSH:
    ```bash
    ssh chip@<CHIP_IP>
    ```
2. Switch to root and upgrade:
    ```bash
    sudo su -
    bash <(curl -s https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/jessie-to-stretch.sh)
    ```
3. Reboot C.H.I.P. into Debian Stretch

### Part 4: upgrade from stretch to buster
1. Connect via SSH:
    ```bash
    ssh chip@<CHIP_IP>
    ```
2. Switch to root and upgrade:
    ```bash
    sudo su -
    bash <(curl -s https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/stretch-to-buster.sh)
    ```
3. Reboot C.H.I.P. into Debian Buster

### Part 5: upgrade from buster to bullseye
1. Connect via SSH:
    ```bash
    ssh chip@<CHIP_IP>
    ```
2. Switch to root and upgrade:
    ```bash
    sudo su -
    bash <(curl -s https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/buster-to-bullseye.sh)
    ```
3. Reboot C.H.I.P. into Debian Buster

### Part 6: upgrade from bullseye to bookworm
1. Connect via SSH:
    ```bash
    ssh chip@<CHIP_IP>
    ```
2. Switch to root and upgrade:
    ```bash
    sudo su -
    bash <(curl -s https://raw.githubusercontent.com/asophila/Flash-CHIP/master/CHIP-updater/bullseye-to-bookworm.sh)
    ```
3. Reboot C.H.I.P. into Debian Bookworm

 
### Part 4: Install QoL enhancements
1. Download and run enhancements. Define a unique and secret ntfy.sh channel to get your ip upon wifi connection.
   ```bash
   wget https://raw.githubusercontent.com/asophila/Flash-CHIP/refs/heads/master/CHIP-updater/install_extras.sh
   sudo chmod +x install_extras.sh
   sudo ./install_extras.sh
   ```

## Troubleshooting
- If you get FEL timeout errors: Try a different USB cable or replug right before flashing
- If flash succeeds but boot fails: Use a better power source
- If you get APT errors: Run `sudo apt-get install -f` and `sudo dpkg --configure -a`
- For Bluetooth issues: Disable if unused with `sudo systemctl disable bluetooth`
