#!/usr/bin/env bash
# Phase 9: install cloudflared and wire up the SAME tunnel this stack has
# always used (same tunnel ID, same ingress rules, same fix-pro.app domain —
# no Cloudflare-dashboard or DNS changes needed, since routing is keyed by
# tunnel ID, not by host). This is a MOVE, not a new tunnel: the credentials
# JSON + config.yml must be copied in from the old machine before this runs
# (00-provision.sh pauses for that). Never run the same tunnel ID from two
# hosts at once — confirm the cutover here before decommissioning the old
# machine's tunnel (see teardown-old-tunnel.md).
set -euo pipefail

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "==> Installing cloudflared"
  sudo mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list
  sudo apt update
  sudo apt -y install cloudflared
else
  echo "==> cloudflared already installed, skipping"
fi

sudo mkdir -p /etc/cloudflared

if [ ! -f /etc/cloudflared/config.yml ] || ! ls /etc/cloudflared/*.json >/dev/null 2>&1; then
  echo
  echo "=================================================================="
  echo " Missing /etc/cloudflared/config.yml and/or the tunnel credentials"
  echo " JSON. From the OLD machine, run:"
  echo
  echo "   sudo scp /etc/cloudflared/*.json /etc/cloudflared/config.yml \\"
  echo "     \$USER@<this-vps-ip>:/tmp/"
  echo
  echo " Then on THIS machine:"
  echo "   sudo mv /tmp/*.json /tmp/config.yml /etc/cloudflared/"
  echo
  echo " Press Enter once both files are in /etc/cloudflared/."
  echo "=================================================================="
  read -r _
fi

# Tighter than the -rwxrwxrwx observed on the old machine — these are the
# tunnel's connector secret, no reason for group/other to read them.
sudo chown root:root /etc/cloudflared/*.json /etc/cloudflared/config.yml
sudo chmod 600 /etc/cloudflared/*.json /etc/cloudflared/config.yml

sudo cloudflared service install
sudo systemctl enable --now cloudflared
sudo systemctl enable --now cloudflared-update.timer

echo "==> Phase 9 done. Check: sudo systemctl status cloudflared"
echo "    Then from an EXTERNAL machine: curl -I https://fix-pro.app/"
echo "    Only decommission the OLD machine's tunnel once that succeeds —"
echo "    see teardown-old-tunnel.md."
