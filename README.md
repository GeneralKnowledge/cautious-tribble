# AveDeus server (Continuous-Tunes)

Infrastructure-as-code for hosting [Continuous-Tunes](https://github.com/GeneralKnowledge/Continuous-Tunes) on a Hetzner CX22 at **aveeus.ovh**.

Delete the Hetzner server and recreate it from this repo in a few commands — Docker, Caddy (HTTPS), firewall, and DNS are all defined here.

```
Internet → Cloudflare DNS (aveeus.ovh)
        → Hetzner CX22 (floating IPv4)
        → Caddy :443 (Let's Encrypt)
        → continuous-tunes nginx :80 (static SPA)
```

## What's in this repo

| Path | Purpose |
|------|---------|
| `terraform/` | Hetzner server, firewall, optional floating IP, Cloudflare DNS, cloud-init |
| `deploy/` | `docker compose` stack: Continuous-Tunes + Caddy |
| `scripts/bootstrap-existing.sh` | Bootstrap the **current** server without Terraform |
| `scripts/deploy.sh` | Pull latest app/infra and recreate containers |

## Prerequisites

On your laptop:

1. [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
2. SSH key pair (`~/.ssh/id_ed25519` by default)
3. Secrets (shell env — never commit these):

```bash
export HCLOUD_TOKEN="…"          # Hetzner Cloud → Security → API tokens (Read & Write)
export CLOUDFLARE_API_TOKEN="…"  # Zone.DNS Edit on avedeus.ovh (skip if manage_dns = false)
```

Cloudflare token: create at https://dash.cloudflare.com/profile/api-tokens with **Zone → DNS → Edit** on `aveeus.ovh`.

## Path A — New / recreatable server (recommended)

Keeps a **floating IP** so destroying the VM does not change the public address or DNS.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit letsencrypt_email, keys, location, etc.

make init
make apply
make outputs
```

First boot runs cloud-init: installs Docker, clones this repo + Continuous-Tunes into `/opt/aveeus`, starts the compose stack, enables `aveeus.service`.

Then open **https://aveeus.ovh** → Play → Start evolution.

### Wipe and recreate

```bash
# Destroys the server (and DNS records if managed). Floating IP is destroyed too unless you
# remove the floating_ip resource from state first — see "Keep the floating IP" below.
make destroy
make apply
```

**Keep the floating IP across rebuilds** (stable DNS, no Cloudflare change):

```bash
cd terraform
terraform state rm hcloud_floating_ip_assignment.web[0]
terraform destroy -target=hcloud_server.web -auto-approve
# optionally destroy other disposable resources, then:
terraform apply -auto-approve   # reuses existing floating IP if still in state
```

Or set `use_floating_ip = true` once, note `public_ipv4` from `make outputs`, and never `destroy` the floating IP resource.

## Path B — Bootstrap the server you already have (`204.168.213.152`)

Use this if the CX22 already exists and you only want the app + HTTPS on it.

1. Merge this repo to `main` (cloud-init/bootstrap clones `main` by default), **or** run with `INFRA_BRANCH=your-branch`.
2. Point Cloudflare DNS:

   | Type | Name | Content | Proxy |
   |------|------|---------|-------|
   | A | `@` | `204.168.213.152` | DNS only (grey) for easiest Let's Encrypt |
   | CNAME | `www` | `aveeus.ovh` | same |

3. SSH as root (or a sudo user) and bootstrap:

```bash
chmod +x scripts/*.sh
# After this branch is on GitHub:
INFRA_BRANCH=main ./scripts/bootstrap-existing.sh root@204.168.213.152 YOU@EMAIL.com avedeus.ovh

# Or while testing this PR branch:
INFRA_BRANCH=cursor/hetzner-continuous-tunes-2aa7 \
  ./scripts/bootstrap-existing.sh root@204.168.213.152 YOU@EMAIL.com avedeus.ovh
```

4. Open https://aveeus.ovh

## Day-2 updates

```bash
# After terraform apply (uses .generated/ssh_config):
make deploy

# Or explicitly:
./scripts/deploy.sh root@204.168.213.152
```

## Local layout on the server

```
/opt/aveeus/
  app/     → Continuous-Tunes (git)
  infra/   → this repo (git)
    deploy/
      docker-compose.yml
      .env          # DOMAIN + EMAIL
      caddy/Caddyfile
```

## DNS notes

- Zone `aveeus.ovh` already uses Cloudflare nameservers (`alan` / `jill`).
- For Caddy HTTP-01 certificates, start with **DNS only** (`dns_proxied = false`). You can turn on the orange cloud later (may need Cloudflare Full SSL).
- If `manage_dns = false`, create the A/CNAME records yourself and point them at `public_ipv4` from `make outputs`.

## Security defaults

- UFW: 22, 80, 443 only  
- fail2ban enabled  
- unattended-upgrades installed  
- Tighten `allowed_ssh_cidrs` in `terraform.tfvars` to your IP when you can  

## Troubleshooting

| Symptom | Check |
|---------|--------|
| `docker compose` fails on first SSH | Re-login so `docker` group applies, or use `sudo docker compose` |
| HTTPS pending | DNS A must point at the server; wait for propagation; `docker compose logs caddy` |
| App 502 | `docker compose ps` — `web` must be healthy; `curl -s localhost` from inside the host network |
| Cloud-init still running | `ssh … 'cloud-init status --wait'` then `sudo journalctl -u cloud-final` |

Health endpoint (inside the `web` container / via Caddy): `GET /healthz` → `ok`.
