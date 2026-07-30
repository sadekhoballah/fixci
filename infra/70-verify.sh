#!/usr/bin/env bash
# Run manually after 00-provision.sh finishes — not auto-invoked, since some
# checks (the curl/nc lines) are only meaningful from an external network.
# Read-only: this script never changes anything.
set -uo pipefail

echo "=== systemd services ==="
for svc in fixci-backend fix-pro-dashboard cloudflared apache2; do
  systemctl status "$svc" --no-pager | head -3
  echo
done
systemctl is-active cloudflared-update.timer

echo
echo "=== ufw ==="
sudo ufw status verbose

echo
echo "=== Docker containers ==="
docker ps --filter "name=fixci-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "=== Public endpoints (only meaningful run from an EXTERNAL machine —"
echo "    from the VPS itself these bypass the tunnel entirely) ==="
echo "  curl -I https://fix-pro.app/"
echo "  curl -s https://fix-pro.app/api/admin-auth/login"
echo "  curl -I https://fix-pro.app/admin-panel/"

echo
echo "=== Ports that must NOT be reachable externally (run from a DIFFERENT"
echo "    machine against this VPS's public IP — expect refused/timeout) ==="
echo "  nc -zv -w3 <vps-ip> 5434   # Postgres"
echo "  nc -zv -w3 <vps-ip> 6380   # Redis"
echo "  nc -zv -w3 <vps-ip> 8501   # dashboard — reach it instead via:"
echo "                             #   ssh -L 8501:127.0.0.1:8501 $USER@<vps-ip>"
