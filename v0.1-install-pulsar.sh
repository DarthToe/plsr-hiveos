#!/bin/bash

# install-pulsar.sh
#
# This script will setup a Pulsar Relay Node.
# Verified to work with: 
#	Ubuntu 20.04: hiveos-0.6-225-beta@240131.img.xz
#	Ubuntu 18.04: hiveos-0.6-222-stable@230512.img.xz
#
# It is not recommended to hold a balance or enable wallet PoS on this installation.
# Remember to enable port forwarding (5995 tcp) in your router to this machine.
# Or ensure that UPnP is enabled and operational in your router's settings.
#
# Check out: https://github.com/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/wiki/03-PLSR-Acquisition#xmrigcc
# If you intend on mining, consider using the following CPU configuration for XMRigCC:
#
# "cpu": {
#   "force-autoconfig": true,  
#   "huge-pages": true,
#   "huge-pages-jit": false,
#   "hw-aes": true,
#   "priority": null,
#   "max-cpu-usage": 50,
#   "max-threads-hint": 100,
#   "memory-pool": false,
#   "asm": true
# }

clear

# Function to calculate total RAM available on the system in MB
get_total_ram() {
    free -m | awk '/^Mem:/{print $2}'
}

# Colors and styles
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
RESET='\033[0m'

# Function to handle apt-get update and upgrade with retries
apt_get_update_upgrade() {
  local retries=5
  local wait_time=10
  while [ $retries -gt 0 ]; do
    if sudo apt-get update -y && sudo apt-get upgrade -y --allow-downgrades; then
      return 0
    else
      echo -e "${YELLOW}# Failed to acquire dpkg frontend lock. Retrying in ${wait_time} seconds...${RESET}"
      sleep $wait_time
      retries=$((retries - 1))
    fi
  done
  echo -e "${RED}# Failed to update and upgrade packages after multiple attempts.${RESET}"
  exit 1
}

# Intro
echo -e "${YELLOW}"
echo "HiveOS: Pulsar Node Installer"
echo -e "${RESET}"
echo ""

# Inform the user about the script's purpose
echo -e "${CYAN}> Preparing HiveOS for${RESET} ${MAGENTA}Pulsar Node${RESET} ${CYAN}installation${RESET}..."
echo ""

# Expand disk space (ignore errors if disk space is already expanded)
echo -e "${CYAN}> Expanding disk space...${RESET}"
disk-expand &> /dev/null || true
echo ""

# Force upgrade HiveOS
echo -e "${CYAN}Updating HiveOS to latest release...${RESET}"
selfupgrade --force
echo ""

# Update system packages and install necessary dependencies
echo -e "${CYAN}> Updating Ubuntu system packages and installing dependencies...${RESET}"
apt_get_update_upgrade
echo ""
echo -e "${CYAN}# Installing Pulsar dependencies...${RESET}"
sudo apt-get install -y libboost-all-dev libminiupnpc-dev libevent-dev libzmq5
echo ""

# Create directory for Pulsar and navigate into it
echo -e "${CYAN}> Creating directory for Pulsar installation...${RESET}"
mkdir -p /.pulsar && cd /.pulsar || exit
echo ""

# Retrieve the latest version of Pulsar from GitHub
echo -e "${CYAN}> Fetching the latest version of Pulsar...${RESET}"
latest_pulsar_version=$(curl -sL https://api.github.com/repos/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/releases/latest | jq -r '.tag_name' | sed 's/^v//')
latest_pulsar_file=$(curl -sL https://api.github.com/repos/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/releases/latest | jq -r '.assets[] | select(.name | startswith("Pulsar")) | .name' | cut -d '-' -f1-2 | head -n1)
ubuntu_version=$(lsb_release -rs | cut -d'.' -f1) # Get major version of Ubuntu

if [ "$ubuntu_version" -ge 20 ]; then
    latest_pulsar_file+="-x86_64-linux.tar.gz"
else
    latest_pulsar_file+="-Ubuntu_${ubuntu_version}.tar.gz"
fi

echo -e "${CYAN}# Ubuntu Ver:${RESET} ${YELLOW}$ubuntu_version${RESET}"
echo -e "${CYAN}# Pulsar Ver:${RESET} ${YELLOW}$latest_pulsar_version${RESET}"
echo -e "${CYAN}# Binary Ver:${RESET} ${YELLOW}$latest_pulsar_file${RESET}"
echo ""

# Download the latest Pulsar Node binary
echo -e "${CYAN}> Downloading Pulsar binary...${RESET}"
cd /.pulsar
wget -q "https://github.com/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/releases/download/v${latest_pulsar_version}/${latest_pulsar_file}"
tar xzf "$latest_pulsar_file"
rm -f "$latest_pulsar_file"
chmod +x pulsar*
echo ""

# Retrieve the latest version of blocks_chainstate from GitHub
echo -e "${CYAN}> Fetching the latest version of Pulsar blocks_chainstate...${RESET}"
latest_blocks_chainstate_version=$(curl -s https://api.github.com/repos/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/releases/latest | grep -oP 'blocks_chainstate_\K[0-9.-]+.zip' | sort -V | tail -n 1)
echo -e "${CYAN}# Latest file version of blocks_chainstate:${RESET} ${YELLOW}blocks_chainstate_$latest_blocks_chainstate_version${RESET}\n"

# Download the latest blocks_chainstate file
echo -e "${CYAN}> Please wait:${RESET} ${YELLOW}Downloading blocks_chainstate_$latest_blocks_chainstate_version...${RESET}"
cd /.pulsar
wget -q "https://github.com/Pulsar-Coin/Pulsar-Coin-Cryptocurrency/releases/download/v${latest_pulsar_version}/blocks_chainstate_${latest_blocks_chainstate_version}"
echo -e "${CYAN}> Please wait:${RESET} ${YELLOW}Unpacking...${RESET}"
unzip -q "blocks_chainstate_${latest_blocks_chainstate_version}"
echo -e "${YELLOW}> Removing block_chainstate .zip file...${RESET}"
rm -f "blocks_chainstate_${latest_blocks_chainstate_version}"
echo ""

# Create configuration file for Pulsar Node in /.pulsar/pulsar.conf
echo -e "${CYAN}> Creating Pulsar configuration file in /.pulsar/pulsar.conf...${RESET}"
total_ram=$(get_total_ram)
dbcache=$((total_ram / 2)) # Use 50% of total RAM as dbcache
echo -e "${YELLOW}Total RAM available: $total_ram MB${RESET}"
echo -e "${YELLOW}Setting dbcache to $dbcache MB${RESET}"
tee /.pulsar/pulsar.conf > /dev/null <<EOF
# Pulsar Node Configuration
conf=/.pulsar/pulsar.conf
daemon=1
datadir=/.pulsar
dbcache=$dbcache
debugexclude=1
disablewallet=1
maxconnections=150
port=5995
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
rpcpassword=password
rpcport=5996
rpcuser=username
staking=0
upnp=1
EOF

# Set permissions for Pulsar Node configuration file
chmod +x /.pulsar/pulsar.conf
echo ""

# Create systemd service file for Pulsar Node
echo -e "${CYAN}> Creating systemd service file for Pulsar...${RESET}"
tee /etc/systemd/system/pulsar.service > /dev/null <<EOF
[Unit]
Description=pulsar
After=network.target

[Service]
Type=forking
User=root
Restart=on-failure
TimeoutStopSec=600

ExecStart=/.pulsar/pulsard -datadir=/.pulsar -conf=/.pulsar/pulsar.conf -rpcuser=username -rpcpassword=password

ExecStop=/bin/kill -15 $MAINPID

[Install]
WantedBy=multi-user.target
EOF
echo ""

# Check if required packages are installed, and install missing ones
required_packages=(
  "libboost-all-dev"
  "libminiupnpc-dev"
  "libevent-dev"
  "libzmq5"
)

echo -e "${CYAN}> Verifying required packages...${RESET}"
for package in "${required_packages[@]}"; do
  if ! dpkg -l | grep -q "^ii  $package"; then
    echo -e "${YELLOW}# Package ${package} is missing. Installing...${RESET}"
    sudo apt-get install -y "$package"
  else
    echo -e "${GREEN}# Package ${package} is already installed.${RESET}"
  fi
done
echo ""

# Reload systemd, enable and start the Pulsar service
echo -e "${CYAN}> Reloading systemd (systemctl daemon-reload)...${RESET}"
systemctl daemon-reload
echo ""
echo -e "${CYAN}> Enabling pulsar (systemctl enable pulsar)...${RESET}"
systemctl enable pulsar
echo ""
echo -e "${CYAN}> Starting pulsar (systemctl start pulsar)...${RESET}"
systemctl start pulsar
echo ""
echo -e "${CYAN}> Pulsar Status (systemctl status pulsar)...${RESET}"
systemctl status pulsar.service
echo ""

# Inform the user about completion of the installation process
echo -e "${MAGENTA}> Please reboot now.${RESET}"
echo ""
echo -e "${GREEN}> Pulsar Node installation completed successfully!${RESET}"
echo ""