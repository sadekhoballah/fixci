#!/usr/bin/env bash
# One-time setup: exposes the NestJS backend at https://fix-pro.app/api via
# the existing cloudflared tunnel + Apache. Run this yourself (needs sudo);
# nothing in this repo can run it automatically. Re-run safely any time
# after pulling backend changes — it rebuilds and restarts the service.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Before running this: edit backend/.env and make sure it has"
echo "    NODE_ENV=production"
echo "    ALLOWED_ORIGINS=https://fix-pro.app"
echo "    ADMIN_JWT_SECRET set to a real secret (see .env.example)"
echo "    Press Enter once that's done, or Ctrl-C to stop and edit it first."
read -r _

echo "==> Build"
npm run build

echo "==> Install/refresh systemd service"
sudo cp deploy/fixci-backend.service /etc/systemd/system/fixci-backend.service
sudo systemctl daemon-reload
sudo systemctl enable fixci-backend
sudo systemctl restart fixci-backend

echo "==> Apache reverse proxy (/api -> 127.0.0.1:3000)"
sudo cp deploy/apache-fixci-api.conf /etc/apache2/conf-available/fixci-api.conf
sudo a2enmod proxy proxy_http
sudo a2enconf fixci-api
sudo systemctl reload apache2

echo "==> Done. Check status with:"
echo "    sudo systemctl status fixci-backend"
echo "    curl https://fix-pro.app/api/admin-auth/login"
echo ""
echo "==> NOTE: while fixci-backend.service is running, it holds port 3000."
echo "    Stop it first (sudo systemctl stop fixci-backend) if you need to"
echo "    run 'npm run start:dev' locally against the same port."
