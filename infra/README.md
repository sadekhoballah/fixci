# Fix Pro — VPS provisioning

Cross-repo orchestration for standing up the full Fix Pro stack (`fixci`
backend + mobile/admin-panel, `fix-pro-web`, `fix-pro-dashboard`) on a fresh
Ubuntu 24.04 server. Reuses each repo's own deploy script rather than
duplicating them — this folder only supplies what doesn't already exist
per-repo: system packages, toolchains, repo cloning, the Cloudflare Tunnel
move, a new systemd unit for the dashboard, and ordering/secrets glue.

## Prerequisites

- A fresh Ubuntu 24.04 server, SSH access, a non-root sudo user.
- **2GB+ RAM** — `flutter build web` (used for the admin panel) reliably
  OOMs below that. `20-toolchains.sh` checks this and aborts if it's short.
- The three repos are private — you'll need to add a deploy key to each
  (script pauses and prints the exact URLs when it's time).
- Access to the **old** machine (this one) to `scp` secrets across — see
  "Secrets" below. None of these are ever committed to git.

## Run order

```bash
cd ~ && git clone git@github.com:sadekhoballah/fixci.git   # bootstrap: infra/ lives inside this repo
cd fixci/infra
./00-provision.sh
```

That first clone (only that one) needs the founder's **own** GitHub
credentials on the VPS, since `infra/`'s own deploy keys don't exist until
phase 3 runs. `30-clone-repos.sh` then generates a dedicated deploy key per
repo (GitHub won't let one key be a deploy key on more than one repo),
repoints `fixci`'s origin at its own key, and clones the other two — every
clone/pull *after* this first bootstrap one uses these deploy keys, not
the founder's personal credentials.

`00-provision.sh` sequences everything below and pauses at the two secrets
hand-off points. It's safe to re-run if it fails partway — each phase only
does work that's still needed (containers/services already up are left
alone, `git clone` is skipped if the directory exists, etc.).

1. `10-system-packages.sh` — apt packages, Docker, ufw (deny incoming by
   default, only SSH open — cloudflared makes outbound-only connections,
   so 80/443 never need to accept inbound traffic on the box itself).
2. `20-toolchains.sh` — nvm + Node 24, Flutter SDK (pinned to `3.44.6` to
   match the dev machine), Python venv tooling.
3. `30-clone-repos.sh` — generates one SSH deploy key *per repo* (GitHub
   rejects reusing the same public key as a deploy key across repos), pauses
   for you to add each one (read-only) to its matching repo, then clones
   all three as siblings: `~/fixci`, `~/fix-pro-web`, `~/fix-pro-dashboard`.
4. **Pause — secrets hand-off #1** (backend `.env`, Firebase Admin JSON,
   dashboard `.env`). See "Secrets" below.
5. Backend: `docker compose up -d` (empty DB — no data migration by
   design), `npm run migration:run`, then `backend/deploy/setup-prod.sh`
   (existing script, reused verbatim) for build + systemd + Apache.
6. `fix-pro-web`: `npm ci && ./deploy.sh` (existing script, reused
   verbatim) — static export to `/var/www/html`.
7. Admin panel: `flutter pub get && ./deploy_admin.sh` (existing script,
   reused verbatim). **Must run after step 6, never before** —
   `fix-pro-web/deploy.sh` does `sudo rm -rf /var/www/html/*`, which would
   wipe `/var/www/html/admin-panel/` if it ran second. This ordering
   matters for every future re-deploy too, not just first provisioning.
8. Dashboard: venv + `pip install`, installs `60-dashboard.service`
   (new — no dashboard unit exists anywhere yet). Binds to `127.0.0.1`
   only — Streamlit has no built-in auth, so it's deliberately **not**
   on the public Cloudflare ingress. Reach it via
   `ssh -L 8501:127.0.0.1:8501 <user>@<vps>` then browse `localhost:8501`.
   (If broader access is ever needed, put it behind Cloudflare Access —
   not built here.)
9. **Pause — secrets hand-off #2** (cloudflared credentials + config),
   then `50-cloudflared.sh` installs and starts the tunnel. Confirm
   `https://fix-pro.app` resolves via the **new** VPS before touching the
   old machine's tunnel — never run the same tunnel ID from two hosts at
   once.
10. Run `70-verify.sh` manually and read `teardown-old-tunnel.md` for the
    (manual, one-time) old-machine cleanup once the cutover is confirmed.

## Secrets (never via git)

Run from the **old** machine once the script pauses and asks:

```bash
scp /home/samoce/fixci/backend/.env <user>@<vps>:~/fixci/backend/.env
scp "/home/samoce/fixci/backend/"*firebase-adminsdk*.json <user>@<vps>:~/fixci/backend/
scp /home/samoce/fix-pro-dashboard/.env <user>@<vps>:~/fix-pro-dashboard/.env
```

Then edit `~/fixci/backend/.env` on the VPS: `NODE_ENV=production`,
`ALLOWED_ORIGINS=https://fix-pro.app`, `ALLOW_DEV_AUTH_BYPASS` unset (real
auth-bypass if left on), fresh `ADMIN_JWT_SECRET`/`WAVE_WEBHOOK_SECRET`
(generator one-liner is in `backend/.env.example`), and
`FIREBASE_SERVICE_ACCOUNT_PATH` pointed at the copied JSON's VPS path.

For the Cloudflare Tunnel (pause #2):

```bash
sudo scp /etc/cloudflared/*.json /etc/cloudflared/config.yml <user>@<vps>:/tmp/
# then on the VPS:
sudo mv /tmp/*.json /tmp/config.yml /etc/cloudflared/
sudo chown root:root /etc/cloudflared/* && sudo chmod 600 /etc/cloudflared/*
```

Same tunnel ID, same ingress rules, same domain — no Cloudflare-dashboard
or DNS changes needed, since routing is keyed by tunnel ID, not by host.
