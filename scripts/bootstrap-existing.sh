#!/usr/bin/env bash
# SSH into an existing Hetzner box and run install-on-server.sh.
#
# Usage:
#   ./scripts/bootstrap-existing.sh root@204.168.213.152 you@example.com
#   ./scripts/bootstrap-existing.sh root@204.168.213.152 you@example.com avedeus.ovh

set -euo pipefail

TARGET="${1:?Usage: $0 user@host email [domain]}"
EMAIL="${2:?Usage: $0 user@host email [domain]}"
DOMAIN="${3:-avedeus.ovh}"
APP_REPO="${APP_REPO:-https://github.com/GeneralKnowledge/Continuous-Tunes.git}"
INFRA_REPO="${INFRA_REPO:-https://github.com/GeneralKnowledge/cautious-tribble.git}"
INFRA_BRANCH="${INFRA_BRANCH:-main}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SCRIPT="$ROOT/scripts/install-on-server.sh"

if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "Missing $INSTALL_SCRIPT" >&2
  exit 1
fi

# Prefer shipping the local script (works before the branch is pushed/merged).
# Fall back to curling from GitHub if scp is unavailable.
if scp -o StrictHostKeyChecking=accept-new "$INSTALL_SCRIPT" "${TARGET}:/tmp/avedeus-install.sh"; then
  ssh -o StrictHostKeyChecking=accept-new "$TARGET" \
    sudo env EMAIL="$EMAIL" DOMAIN="$DOMAIN" APP_REPO="$APP_REPO" \
    INFRA_REPO="$INFRA_REPO" INFRA_BRANCH="$INFRA_BRANCH" \
    bash /tmp/avedeus-install.sh
else
  ssh -o StrictHostKeyChecking=accept-new "$TARGET" \
    env EMAIL="$EMAIL" DOMAIN="$DOMAIN" APP_REPO="$APP_REPO" \
    INFRA_REPO="$INFRA_REPO" INFRA_BRANCH="$INFRA_BRANCH" \
    bash -s <<EOS
set -euo pipefail
curl -fsSL "https://raw.githubusercontent.com/GeneralKnowledge/cautious-tribble/${INFRA_BRANCH}/scripts/install-on-server.sh" \
  | sudo env EMAIL="$EMAIL" DOMAIN="$DOMAIN" APP_REPO="$APP_REPO" \
    INFRA_REPO="$INFRA_REPO" INFRA_BRANCH="$INFRA_BRANCH" bash
EOS
fi
