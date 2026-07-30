#!/usr/bin/env bash
# Phase 1: base apt packages, Docker, and a minimal ufw firewall. Idempotent —
# safe to re-run (apt/Docker installers and ufw rule-adds are all no-ops on a
# system that already has them).
set -euo pipefail

echo "==> apt update/upgrade"
sudo apt update
sudo apt -y upgrade

echo "==> Base packages"
sudo apt -y install git curl build-essential ca-certificates gnupg \
  apache2 ufw python3-venv

if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "    Added $USER to the docker group — log out/in (or 'newgrp docker')"
  echo "    before running docker commands without sudo in this shell."
else
  echo "==> Docker already installed, skipping"
fi

# Deliberately do NOT open 80/443: cloudflared only ever makes outbound
# connections to Cloudflare's edge, so nothing on this box needs to accept
# inbound web traffic directly. Apache only needs to be reachable from
# localhost, where cloudflared forwards decrypted requests.
echo "==> ufw: deny incoming by default, allow outgoing, allow SSH only"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw --force enable

echo "==> Phase 1 done."
