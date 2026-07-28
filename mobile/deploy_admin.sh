#!/usr/bin/env bash
# Builds the admin dashboard (lib/main_admin.dart) and deploys it to
# /var/www/html/admin-panel/, alongside (not replacing) the fix-pro-web
# static export that already lives at /var/www/html. Mirrors
# fix-pro-web/deploy.sh's shape. Run this yourself (needs sudo).
set -euo pipefail
cd "$(dirname "$0")"

API_BASE_URL="${API_BASE_URL:-https://fix-pro.app/api}"

echo "==> Build Flutter Web (admin target, API_BASE_URL=$API_BASE_URL)"
flutter build web --target=lib/main_admin.dart --base-href=/admin-panel/ \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo "==> Déploiement vers /var/www/html/admin-panel (sudo requis)"
sudo mkdir -p /var/www/html/admin-panel
sudo rm -rf /var/www/html/admin-panel/*
sudo cp -r build/web/. /var/www/html/admin-panel/
sudo chown -R root:root /var/www/html/admin-panel
sudo find /var/www/html/admin-panel -type d -exec chmod 755 {} \;
sudo find /var/www/html/admin-panel -type f -exec chmod 644 {} \;
sudo systemctl reload apache2

echo "==> Terminé. Panel disponible sur :"
echo "    https://fix-pro.app/admin-panel/"
