# AveDeus server (Continuous-Tunes)

Deploy [Continuous-Tunes](https://github.com/GeneralKnowledge/Continuous-Tunes) on your Hetzner CX22 (`204.168.213.152`) at **aveeus.ovh**.

**Primary path (Path B):** install on the server you already have. The same script recreates the stack after a wipe.

```
Internet → Cloudflare DNS (aveeus.ovh → 204.168.213.152)
        → Caddy :443 (Let's Encrypt)
        → continuous-tunes nginx :80 (static SPA)
```

## Path B — existing CX22 (recommended)

### 1. DNS (Cloudflare)

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `@` | `204.168.213.152` | DNS only (grey cloud) |
| CNAME | `www` | `aveeus.ovh` | DNS only |

### 2. Install on the server

**Option A — Hetzner web console** (no SSH key sharing):

1. Hetzner Cloud → server → **Console**
2. Paste (replace the email):

```bash
curl -fsSL https://raw.githubusercontent.com/GeneralKnowledge/cautious-tribble/main/scripts/install-on-server.sh \
  | sudo env EMAIL=YOU@EMAIL.com DOMAIN=aveeus.ovh bash
```

Until this lands on `main`, use the PR branch in both the URL and `INFRA_BRANCH`:

```bash
curl -fsSL https://raw.githubusercontent.com/GeneralKnowledge/cautious-tribble/cursor/path-b-install-2aa7/scripts/install-on-server.sh \
  | sudo env EMAIL=YOU@EMAIL.com DOMAIN=aveeus.ovh INFRA_BRANCH=cursor/path-b-install-2aa7 bash
```

**Option B — from your laptop over SSH:**

```bash
chmod +x scripts/*.sh
./scripts/bootstrap-existing.sh root@204.168.213.152 YOU@EMAIL.com avedeus.ovh
```

### 3. Open the site

https://aveeus.ovh → **Play** → **Start evolution**

### Recreate after deleting the server

1. Create a new Ubuntu 24.04 CX22 at Hetzner  
2. Point the Cloudflare A record at the new IP (if it changed)  
3. Run the same install one-liner again  

## Day-2 updates

```bash
./scripts/deploy.sh root@204.168.213.152
```

Or on the server:

```bash
cd /opt/aveeus/app && git pull
cd /opt/aveeus/infra && git pull
cd /opt/aveeus/infra/deploy && docker compose up -d --build
```

## Layout on the server

```
/opt/aveeus/
  app/     → Continuous-Tunes
  infra/   → this repo
    deploy/
      docker-compose.yml
      .env          # DOMAIN + EMAIL
      caddy/Caddyfile
```

## What's in this repo

| Path | Purpose |
|------|---------|
| `scripts/install-on-server.sh` | **Path B** — run on the server (or via console) |
| `scripts/bootstrap-existing.sh` | SSH wrapper that runs the install script |
| `scripts/deploy.sh` | Pull + recreate containers |
| `deploy/` | Docker Compose: Continuous-Tunes + Caddy |
| `terraform/` | Optional Path A — provision a new Hetzner VM + DNS |

## Path A — Terraform (optional)

Use only if you want Terraform to create the CX22 / floating IP / Cloudflare records from scratch. Needs `HCLOUD_TOKEN`, `CLOUDFLARE_API_TOKEN`, and an SSH key.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# set letsencrypt_email
export HCLOUD_TOKEN=… CLOUDFLARE_API_TOKEN=…
make init && make apply
```

See `terraform/terraform.tfvars.example` for options (`use_floating_ip`, `allowed_ssh_cidrs`, …).

## Troubleshooting

| Symptom | Check |
|---------|--------|
| HTTPS stuck | A record must be grey-cloud to this server; `docker compose -f /opt/aveeus/infra/deploy/docker-compose.yml logs caddy` |
| App 502 | `docker compose -f /opt/aveeus/infra/deploy/docker-compose.yml ps` — `web` healthy? |
| Port blocked | `sudo ufw status` should allow 22, 80, 443 |

Health: `GET /healthz` → `ok`
