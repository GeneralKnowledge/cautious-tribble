#!/usr/bin/env bash
# Run ON the Hetzner server (root or sudo user).
# Path B — bootstrap existing CX22 / recreate after a wipe.
#
# One-liner (Hetzner Cloud Console → your server → Console, or SSH):
#
#   curl -fsSL https://raw.githubusercontent.com/GeneralKnowledge/cautious-tribble/main/scripts/install-on-server.sh \
#     | sudo env EMAIL=you@example.com DOMAIN=aveeus.ovh bash
#
# Env:
#   EMAIL          required — Let's Encrypt registration
#   DOMAIN         default avedeus.ovh
#   APP_REPO       default Continuous-Tunes GitHub URL
#   INFRA_REPO     default this repo
#   INFRA_BRANCH   default main

set -euo pipefail

EMAIL="${EMAIL:?Set EMAIL=you@example.com for Let's Encrypt}"
DOMAIN="${DOMAIN:-aveeus.ovh}"
APP_REPO="${APP_REPO:-https://github.com/GeneralKnowledge/Continuous-Tunes.git}"
INFRA_REPO="${INFRA_REPO:-https://github.com/GeneralKnowledge/cautious-tribble.git}"
INFRA_BRANCH="${INFRA_BRANCH:-main}"
DEPLOY_USER="${SUDO_USER:-${DEPLOY_USER:-root}}"

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing base packages"
apt-get update -y
apt-get install -y ca-certificates curl git ufw fail2ban unattended-upgrades qemu-guest-agent

echo "==> Installing Docker Engine"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable --now docker
systemctl enable --now qemu-guest-agent || true
systemctl enable --now fail2ban || true

if id "$DEPLOY_USER" >/dev/null 2>&1; then
  usermod -aG docker "$DEPLOY_USER" || true
fi

echo "==> Configuring UFW (22/80/443)"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> Layout under /opt/aveeus"
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" /opt/aveeus

if [[ ! -d /opt/aveeus/infra/.git ]]; then
  sudo -u "$DEPLOY_USER" git clone --branch "$INFRA_BRANCH" "$INFRA_REPO" /opt/aveeus/infra
else
  sudo -u "$DEPLOY_USER" git -C /opt/aveeus/infra fetch --all --prune
  sudo -u "$DEPLOY_USER" git -C /opt/aveeus/infra checkout "$INFRA_BRANCH"
  sudo -u "$DEPLOY_USER" git -C /opt/aveeus/infra pull --ff-only origin "$INFRA_BRANCH" || true
fi

if [[ ! -d /opt/aveeus/app/.git ]]; then
  sudo -u "$DEPLOY_USER" git clone "$APP_REPO" /opt/aveeus/app
else
  sudo -u "$DEPLOY_USER" git -C /opt/aveeus/app pull --ff-only || true
fi

cat >/opt/aveeus/infra/deploy/.env <<EOF
DOMAIN=${DOMAIN}
EMAIL=${EMAIL}
EOF
chown "$DEPLOY_USER:$DEPLOY_USER" /opt/aveeus/infra/deploy/.env

echo "==> Building and starting Continuous-Tunes + Caddy"
cd /opt/aveeus/infra/deploy
docker compose up -d --build --remove-orphans

echo "==> Enabling avedeus.service (restart stack on reboot)"
tee /etc/systemd/system/aveeus.service >/dev/null <<'UNIT'
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

systemctl daemon-reload
systemctl enable avedeus.service

echo
echo "Done."
echo "1) Cloudflare DNS: A  @  ->  $(curl -4 -fsS ifconfig.me || echo 204.168.213.152)  (DNS only / grey cloud)"
echo "2) CNAME www -> ${DOMAIN}"
echo "3) Open https://${DOMAIN}"
docker compose ps
