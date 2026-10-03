#!/usr/bin/env bash
# Update Continuous-Tunes + infra on a running server and recreate containers.
# Usage:
#   ./scripts/deploy.sh                 # uses Host avedeus from .generated/ssh_config
#   ./scripts/deploy.sh deploy@HOST

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  if [[ -f "$ROOT/.generated/ssh_config" ]]; then
    SSH=(ssh -F "$ROOT/.generated/ssh_config" avedeus)
  else
    echo "Usage: $0 user@host   (or run terraform apply first to generate .generated/ssh_config)" >&2
    exit 1
  fi
else
  SSH=(ssh -o StrictHostKeyChecking=accept-new "$TARGET")
fi

"${SSH[@]}" bash -s <<'EOS'
set -euo pipefail
cd /opt/avedeus/app && git pull --ff-only
cd /opt/avedeus/infra && git pull --ff-only
cd /opt/avedeus/infra/deploy
docker compose up -d --build --remove-orphans
docker compose ps
curl -fsS http://127.0.0.1/healthz || curl -fsS https://127.0.0.1/healthz || true
EOS

echo "Deploy finished."
