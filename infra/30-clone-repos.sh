#!/usr/bin/env bash
# Phase 3: one read-only SSH deploy key PER REPO (GitHub rejects attaching
# the same public key as a deploy key to more than one repo, account-wide),
# then clone all three as siblings: ~/fixci, ~/fix-pro-web,
# ~/fix-pro-dashboard. Deliberately does NOT use the founder's personal SSH
# key — each deploy key is scoped read-only to one repo. Idempotent (skips
# key generation / clone if already done).
set -euo pipefail

REPOS="fixci fix-pro-web fix-pro-dashboard"

for repo in $REPOS; do
  KEY_PATH="$HOME/.ssh/${repo}_deploy_key"
  if [ ! -f "$KEY_PATH" ]; then
    echo "==> Generating deploy key for $repo"
    ssh-keygen -t ed25519 -C "${repo}-vps-deploy" -f "$KEY_PATH" -N ""
  fi

  if ! grep -q "Host github.com-$repo" "$HOME/.ssh/config" 2>/dev/null; then
    mkdir -p "$HOME/.ssh"
    {
      echo "Host github.com-$repo"
      echo "  HostName github.com"
      echo "  IdentityFile $KEY_PATH"
      echo "  IdentitiesOnly yes"
    } >> "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
  fi
done

echo
echo "=================================================================="
echo " Add each key as a read-only Deploy Key on its matching repo:"
echo
for repo in $REPOS; do
  echo "   https://github.com/sadekhoballah/$repo/settings/keys/new"
  cat "$HOME/.ssh/${repo}_deploy_key.pub"
  echo
done
echo " Press Enter once all three are added."
echo "=================================================================="
read -r _

# Accept github.com's host key non-interactively so the clone below doesn't
# hang on a "yes/no" prompt on a brand-new machine that's never SSH'd there.
ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

cd "$HOME"
for repo in $REPOS; do
  if [ -d "$repo/.git" ]; then
    # fixci in particular was bootstrapped with the founder's personal key
    # and a plain git@github.com URL — repoint it at its own deploy key so
    # future pulls don't depend on that (temporary) agent-forwarded access.
    echo "==> $repo already cloned, repointing origin to its dedicated deploy key"
    (cd "$repo" && git remote set-url origin "git@github.com-$repo:sadekhoballah/$repo.git")
  else
    echo "==> Cloning $repo"
    git clone "git@github.com-$repo:sadekhoballah/$repo.git"
  fi
done

echo "==> Phase 3 done."
