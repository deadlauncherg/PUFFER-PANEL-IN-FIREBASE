#!/bin/bash

ROOTFS_DIR=$(pwd)
ARCH=$(uname -m)
max_retries=50
timeout=1

if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  echo "Unsupported CPU architecture: $ARCH"
  exit 1
fi

# Install Ubuntu rootfs if not installed
if [ ! -f "$ROOTFS_DIR/.installed" ]; then
  echo "#################### Installing Ubuntu RootFS ####################"
  read -p "Do you want to install Ubuntu? (YES/no): " confirm
  if [[ "$confirm" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
    wget --tries=$max_retries --timeout=$timeout -O /tmp/rootfs.tar.gz \
      "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-${ARCH_ALT}.tar.gz"
    mkdir -p "$ROOTFS_DIR/ubuntu"
    tar -xf /tmp/rootfs.tar.gz -C "$ROOTFS_DIR/ubuntu"
    rm /tmp/rootfs.tar.gz
  else
    echo "Skipping Ubuntu installation."
  fi

  echo "Downloading proot..."
  mkdir -p "$ROOTFS_DIR/ubuntu/usr/local/bin"
  wget --tries=$max_retries --timeout=$timeout -O "$ROOTFS_DIR/ubuntu/usr/local/bin/proot" \
    "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"
  chmod +x "$ROOTFS_DIR/ubuntu/usr/local/bin/proot"

  echo "nameserver 1.1.1.1" > "$ROOTFS_DIR/ubuntu/etc/resolv.conf"
  echo "nameserver 1.0.0.1" >> "$ROOTFS_DIR/ubuntu/etc/resolv.conf"
  touch "$ROOTFS_DIR/.installed"
fi

"$ROOTFS_DIR/ubuntu/usr/local/bin/proot" \
  --rootfs="$ROOTFS_DIR/ubuntu" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit /bin/bash << 'EOL'
clear
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

echo "
#######################################################################################
#
#                                  VPSFREE.ES SCRIPTS (Inside Ubuntu)
#
#######################################################################################"
echo "Select an option:"
echo "1) LXDE - XRDP"
echo "2) PufferPanel"
echo "3) Install Basic Packages"
echo "4) Install Node.js"
echo "5) Install Ngrok"
read option

if [ "$option" -eq 1 ]; then
    apt update && apt upgrade -y
    export SUDO_FORCE_REMOVE=yes
    apt remove sudo -y
    apt install -y lxde xrdp
    echo "lxsession -s LXDE -e LXDE" >> /etc/xrdp/startwm.sh
    read -p "Select RDP Port: " selectedPort
    sed -i "s/port=3389/port=$selectedPort/g" /etc/xrdp/xrdp.ini
    service xrdp restart
    echo -e "${GREEN}RDP setup complete on port $selectedPort"

elif [ "$option" -eq 2 ]; then
    apt update && apt upgrade -y
    export SUDO_FORCE_REMOVE=yes
    apt remove sudo -y
    apt install -y curl wget git python3
    curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | bash
    apt update
    curl -o /bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py
    chmod +x /bin/systemctl
    apt install -y pufferpanel
    read -p "Enter PufferPanel Port: " pufferPort
    sed -i "s/\"host\": \"0.0.0.0:8080\"/\"host\": \"0.0.0.0:$pufferPort\"/g" /etc/pufferpanel/config.json
    read -p "Admin username: " adminUser
    read -p "Admin password: " adminPass
    read -p "Admin email: " adminEmail
    pufferpanel user add --name "$adminUser" --password "$adminPass" --email "$adminEmail" --admin
    systemctl restart pufferpanel
    echo -e "${GREEN}PufferPanel started on port $pufferPort"

elif [ "$option" -eq 3 ]; then
    apt update && apt upgrade -y
    apt install -y git curl wget sudo lsof iputils-ping
    curl -o /bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py
    chmod +x /bin/systemctl
    echo -e "${GREEN}Basic packages installed."

elif [ "$option" -eq 4 ]; then
    echo "Choose Node.js version:"
    echo "1) 12.x  2) 13.x  3) 14.x  4) 15.x  5) 16.x  6) 17.x  7) 18.x  8) 19.x  9) 20.x"
    read -p "Enter choice: " choice
    version=$((11 + choice))
    apt remove --purge node* nodejs npm -y
    apt update && apt install curl -y
    curl -sL "https://deb.nodesource.com/setup_${version}.x" -o /tmp/node_setup.sh
    bash /tmp/node_setup.sh
    apt install -y nodejs
    echo -e "${GREEN}Node.js $version installed."

elif [ "$option" -eq 5 ]; then
    apt update && apt install -y curl gnupg ca-certificates lsb-release
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc -o ngrok.asc
    mkdir -p /etc/apt/trusted.gpg.d
    mv ngrok.asc /etc/apt/trusted.gpg.d/ngrok.asc
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
    apt update && apt install -y ngrok
    read -p "Enter your ngrok authtoken: " token
    ngrok config add-authtoken "$token"
    ngrok http http://localhost:8080
else
    echo -e "${RED}Invalid option."
fi
EOL
