#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Ensure Docker daemon starts automatically after VPS reboot (Linux systemd only)
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files docker.service >/dev/null 2>&1; then
  if ! systemctl is-enabled --quiet docker.service 2>/dev/null; then
    echo "==> Enabling docker.service & containerd.service on boot..."
    systemctl enable docker.service containerd.service 2>/dev/null || true
  fi
fi

echo "==> Ensuring shared Docker networks exist..."
docker network inspect shared-minio-net >/dev/null 2>&1 || docker network create shared-minio-net
docker network inspect shared-gateway-net >/dev/null 2>&1 || docker network create shared-gateway-net

if docker ps --format '{{.Names}}' | grep -qx 'heygoodly-minio'; then
  echo "WARNING: Legacy container 'heygoodly-minio' is occupying ports 9000-9001."
  echo "Stop it first with: docker stop heygoodly-minio"
  exit 1
fi

# Auto-generate self-signed SSL cert if missing (used by heyworthly :8443 and IP fallback :443)
if [ ! -f nginx/ssl/selfsigned.crt ] || [ ! -f nginx/ssl/selfsigned.key ]; then
  echo "==> Generating self-signed SSL certificate in nginx/ssl/..."
  mkdir -p nginx/ssl
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout nginx/ssl/selfsigned.key \
    -out nginx/ssl/selfsigned.crt \
    -subj "/C=US/ST=CA/L=SF/O=AffiliateCluster/CN=localhost"
fi

echo "==> Starting Shared MinIO (S3 API: 9000, Console: 9001)..."
docker compose -f docker-compose.minio.yml up -d

echo "==> Starting Shared Nginx Gateway (heygoodly :80/:443 | heyworthly :81/:8443)..."
docker compose -f docker-compose.nginx.yml up -d

echo "==> Shared Infrastructure is UP!"
docker ps --filter "name=shared-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
