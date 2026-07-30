#!/usr/bin/env bash
# Phase 2: nvm+Node 24 (matches the dev machine; the repo has no .nvmrc or
# engines field to pin this automatically), Flutter SDK pinned to 3.44.6 (the
# dev machine's version, for reproducible admin-panel builds), and
# python3-venv (apt package already installed in phase 1). Idempotent.
set -euo pipefail

# flutter build web reliably OOMs under ~2GB — the admin panel build is the
# heaviest single step this provisioning does, and by far the easiest to
# blame on "the script is broken" if it just hangs/gets OOM-killed instead
# of failing clearly up front.
total_mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if (( total_mem_kb < 1900000 )); then
  echo "ERROR: ${total_mem_kb}KB RAM detected — Flutter Web builds need 2GB+." >&2
  echo "        Resize the VPS before continuing, or this will hang/OOM in phase 7." >&2
  exit 1
fi

if [ ! -d "$HOME/.nvm" ]; then
  echo "==> Installing nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck source=/dev/null
source "$HOME/.nvm/nvm.sh"

echo "==> Installing Node 24 (nvm install is itself idempotent — no-ops if present)"
nvm install 24
nvm alias default 24

if [ ! -d "$HOME/flutter" ]; then
  echo "==> Cloning Flutter SDK (pinned to 3.44.6, matching the dev machine)"
  git clone -b stable --depth 1 https://github.com/flutter/flutter.git "$HOME/flutter"
  (cd "$HOME/flutter" && git fetch --tags --depth 1 origin 3.44.6 && git checkout 3.44.6)
else
  echo "==> Flutter SDK already present at ~/flutter, skipping clone"
fi

if ! grep -q 'flutter/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/flutter/bin:$PATH"

echo "==> flutter config --enable-web + precache"
flutter config --enable-web
flutter precache --web

echo "==> Phase 2 done. Node: $(node --version), Flutter: $(flutter --version | head -1)"
