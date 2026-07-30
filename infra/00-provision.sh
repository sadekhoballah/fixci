#!/usr/bin/env bash
# Top-level sequencer for standing up the full Fix Pro stack on a fresh
# Ubuntu 24.04 server: fixci (backend + mobile/admin-panel), fix-pro-web,
# fix-pro-dashboard. Reuses each repo's own deploy script rather than
# duplicating them (backend/deploy/setup-prod.sh, fix-pro-web/deploy.sh,
# mobile/deploy_admin.sh) — this file only supplies what's missing:
# system/toolchain setup, repo cloning, secrets hand-off pauses, a new
# dashboard systemd unit, and the Cloudflare Tunnel move.
#
# Safe to re-run: every phase below only does work that isn't already done.
# See infra/README.md for the full walkthrough and the secrets hand-off
# commands to run from the OLD machine at each pause point.
set -euo pipefail
cd "$(dirname "$0")"
FIXCI_ROOT="$(cd .. && pwd)"          # .../fixci
HOME_ROOT="$(cd ../.. && pwd)"        # the siblings' common parent, e.g. ~

echo "###################################################################"
echo "# Phase 1/9: system packages, Docker, ufw"
echo "###################################################################"
./10-system-packages.sh

echo "###################################################################"
echo "# Phase 2/9: toolchains (Node 24, Flutter, Python venv)"
echo "###################################################################"
./20-toolchains.sh
# shellcheck source=/dev/null
source "$HOME/.nvm/nvm.sh"
export PATH="$HOME/flutter/bin:$PATH"

echo "###################################################################"
echo "# Phase 3/9: SSH deploy key + clone fix-pro-web / fix-pro-dashboard"
echo "###################################################################"
./30-clone-repos.sh
FIX_PRO_WEB="$HOME_ROOT/fix-pro-web"
FIX_PRO_DASHBOARD="$HOME_ROOT/fix-pro-dashboard"

echo "###################################################################"
echo "# Secrets hand-off #1 — backend .env, Firebase Admin JSON, dashboard .env"
echo "###################################################################"
if [ ! -f "$FIXCI_ROOT/backend/.env" ] || ! ls "$FIXCI_ROOT/backend/"*firebase-adminsdk*.json >/dev/null 2>&1; then
  echo
  echo "From the OLD machine, run:"
  echo "  scp /home/samoce/fixci/backend/.env $USER@<this-vps-ip>:$FIXCI_ROOT/backend/.env"
  echo "  scp \"/home/samoce/fixci/backend/\"*firebase-adminsdk*.json $USER@<this-vps-ip>:$FIXCI_ROOT/backend/"
  echo "  scp /home/samoce/fix-pro-dashboard/.env $USER@<this-vps-ip>:$FIX_PRO_DASHBOARD/.env"
  echo
  echo "Then edit $FIXCI_ROOT/backend/.env on THIS machine:"
  echo "  NODE_ENV=production"
  echo "  ALLOWED_ORIGINS=https://fix-pro.app"
  echo "  ALLOW_DEV_AUTH_BYPASS=        (blank/unset — never true in production)"
  echo "  ADMIN_JWT_SECRET=<fresh value, see .env.example for the generator one-liner>"
  echo "  WAVE_WEBHOOK_SECRET=<fresh value>"
  echo "  FIREBASE_SERVICE_ACCOUNT_PATH=<path to the copied JSON, on this machine>"
  echo
  echo "Press Enter once backend/.env, the Firebase JSON, and fix-pro-dashboard/.env are all in place."
  read -r _
else
  echo "==> backend/.env and Firebase Admin JSON already present, skipping pause"
fi

echo "###################################################################"
echo "# Phase 5/9: backend — Docker, migrations, build, systemd, Apache"
echo "###################################################################"
cd "$FIXCI_ROOT"
docker compose up -d
echo "==> Waiting for Postgres/Redis health checks..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' fixci-postgres)" = "healthy" ] \
   && [ "$(docker inspect -f '{{.State.Health.Status}}' fixci-redis)" = "healthy" ]; do
  sleep 2
done

cd "$FIXCI_ROOT/backend"
npm ci
npm run migration:run   # empty DB by design — no data migration, see infra/README.md

# Template the service unit's hardcoded dev-machine values before
# setup-prod.sh installs it — User=samoce, /home/samoce paths, and the
# exact nvm-resolved node binary (its patch version isn't guaranteed to
# match the dev machine's v24.18.0, since 20-toolchains.sh just installs
# "Node 24" via nvm).
NODE_BIN="$(nvm which 24)"
sed -i \
  -e "s#^User=samoce#User=$USER#" \
  -e "s#/home/samoce#$HOME_ROOT#g" \
  -e "s#^ExecStart=.*#ExecStart=$NODE_BIN dist/main.js#" \
  "$FIXCI_ROOT/backend/deploy/fixci-backend.service"

./deploy/setup-prod.sh

echo "###################################################################"
echo "# Phase 6/9: fix-pro-web (marketing site)"
echo "###################################################################"
cd "$FIX_PRO_WEB"
npm ci
./deploy.sh

echo "###################################################################"
echo "# Phase 7/9: admin panel (Flutter Web) — MUST run after fix-pro-web,"
echo "# since deploy.sh wipes /var/www/html/* and would erase admin-panel/"
echo "###################################################################"
cd "$FIXCI_ROOT/mobile"
flutter pub get
./deploy_admin.sh

echo "###################################################################"
echo "# Phase 8/9: fix-pro-dashboard (Streamlit, localhost-only)"
echo "###################################################################"
cd "$FIX_PRO_DASHBOARD"
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
./.venv/bin/pip install -r requirements.txt

sed \
  -e "s#__VPS_USER__#$USER#" \
  -e "s#__VPS_HOME__#$HOME_ROOT#g" \
  "$FIXCI_ROOT/infra/60-dashboard.service" | sudo tee /etc/systemd/system/fix-pro-dashboard.service >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now fix-pro-dashboard

echo "###################################################################"
echo "# Secrets hand-off #2 — Cloudflare Tunnel credentials"
echo "###################################################################"
echo "###################################################################"
echo "# Phase 9/9: Cloudflare Tunnel (same tunnel ID, moved from the old machine)"
echo "###################################################################"
cd "$FIXCI_ROOT/infra"
./50-cloudflared.sh

echo
echo "###################################################################"
echo "# All phases done. Run ./70-verify.sh (see infra/README.md) and,"
echo "# once confirmed, follow teardown-old-tunnel.md on the OLD machine."
echo "###################################################################"
