#!/usr/bin/env bash
# Phase 3: one read-only SSH deploy key added to all three private repos,
# then clone them as siblings: ~/fixci, ~/fix-pro-web, ~/fix-pro-dashboard.
# Deliberately does NOT use the founder's personal SSH key — a deploy key is
# scoped read-only to these repos specifically. Idempotent (skips key
# generation / clone if already done).
set -euo pipefail

KEY_PATH="$HOME/.ssh/fixci_deploy_key"

if [ ! -f "$KEY_PATH" ]; then
  echo "==> Generating deploy key"
  ssh-keygen -t ed25519 -C "fixci-vps-deploy" -f "$KEY_PATH" -N ""
fi

if ! grep -q "IdentityFile $KEY_PATH" "$HOME/.ssh/config" 2>/dev/null; then
  mkdir -p "$HOME/.ssh"
  {
    echo "Host github.com"
    echo "  IdentityFile $KEY_PATH"
    echo "  IdentitiesOnly yes"
  } >> "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
fi

echo
echo "=================================================================="
echo " Add this key as a read-only Deploy Key on ALL THREE repos:"
echo
cat "$KEY_PATH.pub"
echo
echo "   https://github.com/sadekhoballah/fixci/settings/keys/new"
echo "   https://github.com/sadekhoballah/fix-pro-web/settings/keys/new"
echo "   https://github.com/sadekhoballah/fix-pro-dashboard/settings/keys/new"
echo
echo " Press Enter once all three are added."
echo "=================================================================="
read -r _

# Accept github.com's host key non-interactively so the clone below doesn't
# hang on a "yes/no" prompt on a brand-new machine that's never SSH'd there.
ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

cd "$HOME"
for repo in fixci fix-pro-web fix-pro-dashboard; do
  if [ -d "$repo/.git" ]; then
    echo "==> $repo already cloned, skipping"
  else
    echo "==> Cloning $repo"
    git clone "git@github.com:sadekhoballah/$repo.git"
  fi
done

echo "==> Phase 3 done."
