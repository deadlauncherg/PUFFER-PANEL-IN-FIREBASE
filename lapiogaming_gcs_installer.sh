#!/bin/bash

# ========== lapiogaming Auto PufferPanel + Ngrok Script for Google Cloud Shell ==========
# Removes menu — installs PufferPanel + Ngrok with authtoken prompt
# =========================================================================================

ROOTFS_DIR=$(pwd)
ARCH=$(uname -m | tr -d '[:space:]')

if [[ "$ARCH" == "x86_64" ]]; then
  ARCH_ALT="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH_ALT="arm64"
else
  echo "Unsupported CPU architecture: $ARCH"
  exit 1
fi

echo "Script by lapiogaming"

# Make sure essential packages are available with sudo
sudo apt update && sudo apt install -y wget curl tar bash gnupg ca-certificates sudo

# Rootfs setup
if [ ! -f "$ROOTFS_DIR/.installed" ]; then
  echo "Installing Ubuntu RootFS..."
  wget --tries=50 --timeout=10 -O /tmp/rootfs.tar.gz     "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-${ARCH_ALT}.tar.gz"
  mkdir -p "$ROOTFS_DIR/ubuntu"
  tar -xf /tmp/rootfs.tar.gz -C "$ROOTFS_DIR/ubuntu"
  rm /tmp/rootfs.tar.gz

  echo "Downloading proot..."
  mkdir -p "$ROOTFS_DIR/ubuntu/usr/local/bin"
  wget --tries=50 --timeout=10 -O "$ROOTFS_DIR/ubuntu/usr/local/bin/proot"     "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH_ALT}"
  chmod +x "$ROOTFS_DIR/ubuntu/usr/local/bin/proot"

  echo "nameserver 1.1.1.1" > "$ROOTFS_DIR/ubuntu/etc/resolv.conf"
  echo "nameserver 1.0.0.1" >> "$ROOTFS_DIR/ubuntu/etc/resolv.conf"
  touch "$ROOTFS_DIR/.installed"
fi

"$ROOTFS_DIR/ubuntu/usr/local/bin/proot"   --rootfs="$ROOTFS_DIR/ubuntu"   -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit /bin/bash << 'EOL'
clear
GREEN='[0;32m'
RED='[0;31m'

# Ensure all required tools are available in proot
apt update && apt install -y curl wget git python3 gnupg2 lsb-release sudo ca-certificates software-properties-common

# Install PufferPanel
curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | bash
apt update
curl -o /bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py
chmod +x /bin/systemctl
apt install -y pufferpanel

# Configure PufferPanel
read -p "Enter PufferPanel Port: " pufferPort
sed -i "s/\"host\": \"0.0.0.0:8080\"/\"host\": \"0.0.0.0:$pufferPort\"/g" /etc/pufferpanel/config.json

# Create admin user
read -p "Admin username: " adminUser
read -p "Admin password: " adminPass
read -p "Admin email: " adminEmail
pufferpanel user add --name "$adminUser" --password "$adminPass" --email "$adminEmail" --admin

systemctl restart pufferpanel
echo -e "${GREEN}PufferPanel started on port $pufferPort"

# Install Ngrok
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc -o ngrok.asc
mv ngrok.asc /etc/apt/trusted.gpg.d/ngrok.asc
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
apt update && apt install -y ngrok

read -p "Enter your ngrok authtoken: " token
ngrok config add-authtoken "$token"

echo -e "${GREEN}Starting ngrok tunnel for localhost:$pufferPort..."
ngrok http http://localhost:$pufferPort
EOL
