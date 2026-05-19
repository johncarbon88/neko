#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  git \
  ufw \
  linux-headers-$(uname -r) \
  linux-modules-extra-$(uname -r)

# Docker
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable --now docker

# cloudflared
mkdir -p --mode=0755 /usr/share/keyrings

curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  > /etc/apt/sources.list.d/cloudflared.list

apt-get update
apt-get install -y cloudflared

# Webcam / virtual camera requirements
apt-get install -y \
  v4l2loopback-dkms \
  v4l2loopback-utils \
  v4l-utils \
  ffmpeg

echo v4l2loopback > /etc/modules-load.d/v4l2loopback.conf

cat > /etc/modprobe.d/v4l2loopback.conf <<'EOF'
options v4l2loopback video_nr=0 card_label="Webcam" exclusive_caps=1
EOF

modprobe v4l2loopback video_nr=0 card_label="Webcam" exclusive_caps=1 || true

# Neko ports, if using direct WebRTC to VPS
ufw allow OpenSSH
ufw allow 8080/tcp
ufw allow 52000:52100/udp
ufw --force enable

docker version
docker compose version
cloudflared --version
v4l2-ctl --list-devices || true

# Pull image
docker pull ghcr.io/johncarbon88/neko/webcam-google-chrome:webcam

docker run -p 80:8080 -d --name speedtest --rm ghcr.io/librespeed/speedtest