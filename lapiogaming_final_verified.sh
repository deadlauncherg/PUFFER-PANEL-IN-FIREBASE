#!/bin/bash

# ========== FINAL VERIFIED LAPIOTEST SCRIPT (Google Cloud Shell Ready) ==========
# Author: lapiogaming
# ===============================================================================

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

echo "🛠 Preparing environment..."

# Ensure required tools
sudo apt update && sudo apt install -y wget curl tar bash gnupg ca-certificates sudo

# Setup Ubuntu rootfs
if [ ! -f "$ROOTFS_DIR/.installed" ]; then
  echo "📦 Installing Ubuntu RootFS..."
  wget --tries=50 --timeout=10 -O /tmp/rootfs.tar.gz     "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-${ARCH_ALT}.tar.gz"
  mkdir -p "$ROOTFS_DIR/ubuntu"
  tar -xf /tmp/rootfs.tar.gz -C "$ROOTFS_DIR/ubuntu"
  rm /tmp/rootfs.tar.gz

  echo "📥 Downloading proot..."
  mkdir -p "$ROOTFS_DIR/ubuntu/usr/local/bin"
  wget --tries=50 --timeout=10 -O "$ROOTFS_DIR/ubuntu/usr/local/bin/proot"     "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH_ALT}"
  chmod +x "$ROOTFS_DIR/ubuntu/usr/local/bin/proot"

  echo "nameserver 8.8.8.8" > "$ROOTFS_DIR/ubuntu/etc/resolv.conf"
  echo "nameserver 1.1.1.1" >> "$ROOTFS_DIR/ubuntu/etc/resolv.conf"
  touch "$ROOTFS_DIR/.installed"
fi

"$ROOTFS_DIR/ubuntu/usr/local/bin/proot"   --rootfs="$ROOTFS_DIR/ubuntu"   -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit /bin/bash << 'EOL'
clear
GREEN='[0;32m'
RED='[0;31m'

echo -e "
${GREEN}🔥 Running inside proot Ubuntu... Fixing DNS"
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

echo -e "${GREEN}📦 Updating packages..."
apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo -e "${GREEN}🔧 Installing dependencies..."
apt install -y curl wget git python3 gnupg2 lsb-release sudo ca-certificates software-properties-common

echo -e "${GREEN}🧰 Installing PufferPanel..."
curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | bash
apt update
curl -o /bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py
chmod +x /bin/systemctl
apt install -y pufferpanel

read -p "📌 Enter PufferPanel Port: " pufferPort
sed -i "s/\"host\": \"0.0.0.0:8080\"/\"host\": \"0.0.0.0:$pufferPort\"/g" /etc/pufferpanel/config.json

read -p "👤 Admin username: " adminUser
read -p "🔑 Admin password: " adminPass
read -p "📧 Admin email: " adminEmail
pufferpanel user add --name "$adminUser" --password "$adminPass" --email "$adminEmail" --admin
systemctl restart pufferpanel

echo -e "${GREEN}✅ PufferPanel is running on port $pufferPort"

echo -e "${GREEN}🌐 Installing ngrok..."
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc -o ngrok.asc
mv ngrok.asc /etc/apt/trusted.gpg.d/ngrok.asc
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
apt update && apt install -y ngrok

read -p "🔐 Enter your ngrok authtoken: " token
ngrok config add-authtoken "$token"

echo -e "${GREEN}🚀 Starting ngrok tunnel for http://localhost:$pufferPort"
ngrok http http://localhost:$pufferPort
EOL
