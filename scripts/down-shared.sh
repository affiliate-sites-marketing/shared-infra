#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Stopping Shared Nginx Gateway..."
docker compose -f docker-compose.nginx.yml down

echo "==> Stopping Shared MinIO..."
docker compose -f docker-compose.minio.yml down

echo "==> Shared Infrastructure stopped (volumes & networks preserved)."
