# Decommissioning the Cloudflare Tunnel on the OLD machine

Run this **only** after confirming `https://fix-pro.app` is being served by
the **new** VPS — check from an external machine (`curl -I
https://fix-pro.app/`) or check the Cloudflare dashboard's tunnel connector
list shows the new host. Never run the same tunnel ID from two hosts at
once.

This is a one-time, human-supervised action — deliberately a doc, not a
script, since it's run exactly once and the consequences of running it
against the wrong machine (or too early) are immediate downtime.

```bash
sudo systemctl stop cloudflared
sudo systemctl disable cloudflared
sudo systemctl stop cloudflared-update.timer
sudo systemctl disable cloudflared-update.timer
```

## Do NOT touch anything else on this machine

Only the tunnel moves. Everything else on the old (dev) machine keeps
running as before, for continued local development:

- `fixci-backend.service` — stays up, still used for `npm run start:dev`-style
  local work against `localhost:3000`.
- `fixci-postgres` / `fixci-redis` (Docker) — stay up, dev data untouched.
- Apache, if it's serving anything locally for dev purposes — untouched.
