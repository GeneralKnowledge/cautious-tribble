#!/usr/bin/env bash
# Bootstrap an already-running Hetzner Ubuntu server (no Terraform).
#
# Usage:
#   ./scripts/bootstrap-existing.sh root@204.168.213.152 you@example.com
#   ./scripts/bootstrap-existing.sh root@204.168.213.152 you@example.com avedeus.ovh
#
# Optional env:
#   APP_REPO=https://github.com/GeneralKnowledge/Continuous-Tunes.git
#   INFRA_REPO=https://github.com/GeneralKnowledge/cautious-tribble.git
#   INFRA_BRANCH=main

set -euo pipefail

TARGET="${1:?Usage: $0 user@host email [domain]}"
EMAIL="${2:?Usage: $0 user@host email [domain]}"
DOMAIN="${3:-aveeus.ovh}"
APP_REPO="${APP_REPO:-https://github.com/GeneralKnowledge/Continuous-Tunes.git}"
INFRA_REPO="${INFRA_REPO:-https://github.com/GeneralKnowledge/cautious-tribble.git}"
INFRA_BRANCH="${INFRA_BRANCH:-main}"

ssh -o StrictHostKeyChecking=accept-new "$TARGET" \
  env EMAIL="$EMAIL" DOMAIN="$DOMAIN" APP_REPO="$APP_REPO" INFRA_REPO="$INFRA_REPO" INFRA_BRANCH="$INFRA_BRANCH" \
  bash -s <<'EOS'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git ufw fail2ban unattended-upgrades qemu-guest-agent

if ! command -v docker >/dev/null 2>&1; then
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

sudo install -d -o "$USER" -g "$USER" /opt/aveeus

if [[ ! -d /opt/aveeus/infra/.git ]]; then
  git clone --branch "$INFRA_BRANCH" "$INFRA_REPO" /opt/aveeus/infra
else
  git -C /opt/aveeus/infra fetch --all --prune
  git -C /opt/aveeus/infra checkout "$INFRA_BRANCH"
  git -C /opt/aveeus/infra pull --ff-only origin "$INFRA_BRANCH" || true
fi

if [[ ! -d /opt/aveeus/app/.git ]]; then
  git clone "$APP_REPO" /opt/aveeus/app
else
  git -C /opt/aveeus/app pull --ff-only || true
fi

cat >/opt/aveeus/infra/deploy/.env <<EOF
DOMAIN=${DOMAIN}
EMAIL=${EMAIL}
EOF

cd /opt/aveeus/infra/deploy
# Prefer docker without sudo once group membership applies; fall back to sudo.
if docker info >/dev/null 2>&1; then
  docker compose up -d --build --remove-orphans
else
  sudo docker compose up -d --build --remove-orphans
fi

sudo tee /etc/systemd/system/aveeus.service >/dev/null <<'UNIT'
[Unit]
Description=AveDeus Continuous-Tunes stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/aveeus/infra/deploy
ExecStart=/usr/bin/docker compose up -d --remove-orphans
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable avedeus.service

echo "Deployed. Ensure DNS A for ${DOMAIN} points here, then open https://${DOMAIN}"
EOS
