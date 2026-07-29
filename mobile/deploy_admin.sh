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

# Every static asset here is requested at the same URL on every deploy, and
# fix-pro.app sits behind Cloudflare's edge cache (observed: 4h max-age, HIT
# on repeat requests, unaffected by client-sent no-cache headers) — without
# this, a fresh deploy is invisible to real visitors for up to 4h even
# though the origin already has the new build. Query-string BOTH the
# loader (flutter_bootstrap.js, referenced from index.html, which Cloudflare
# does NOT cache — .html responses pass through dynamic) and the entrypoint
# it in turn loads (main.dart.js, referenced from inside the loader) with a
# build timestamp, so every deploy is a fresh cache key end to end. Apache
# ignores the query string and serves the same file regardless.
BUILD_STAMP="$(date +%s)"
sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$BUILD_STAMP\"/" \
  build/web/flutter_bootstrap.js
sed -i "s/flutter_bootstrap.js\" async/flutter_bootstrap.js?v=$BUILD_STAMP\" async/" \
  build/web/index.html

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
