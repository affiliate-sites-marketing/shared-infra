#!/usr/bin/env bash
# =============================================================================
# Enable Production SSL on VPS:
# - heygoodly: Let's Encrypt SSL (domain heygoodly.com + www.heygoodly.com)
# - bestora:   Self-Signed SSL trên IP:8443 (không cần domain)
# Usage: ./scripts/enable-vps-ssl.sh [email@heygoodly.com]
# =============================================================================
set -euo pipefail

EMAIL="${1:-admin@heygoodly.com}"
DOMAIN="heygoodly.com"
INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$INFRA_DIR"

# 1. Ensure self-signed SSL exists for bestora (:8443) & IP fallback (:443)
if [ ! -f nginx/ssl/selfsigned.crt ] || [ ! -f nginx/ssl/selfsigned.key ]; then
  mkdir -p nginx/ssl
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout nginx/ssl/selfsigned.key \
    -out nginx/ssl/selfsigned.crt \
    -subj "/C=US/ST=CA/L=SF/O=Bestora/CN=localhost"
fi

# 2. Issue Let's Encrypt certificate for heygoodly.com if not already present
if [ ! -f "nginx/certbot/conf/live/${DOMAIN}/fullchain.pem" ]; then
  echo "==> Issuing Let's Encrypt SSL certificate for ${DOMAIN} & www.${DOMAIN}..."
  docker run --rm \
    -v "${INFRA_DIR}/nginx/certbot/www:/var/www/certbot" \
    -v "${INFRA_DIR}/nginx/certbot/conf:/etc/letsencrypt" \
    certbot/certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email "${EMAIL}" \
    --agree-tos --no-eff-email \
    -d "${DOMAIN}" -d "www.${DOMAIN}"
else
  echo "==> Let's Encrypt certificate for ${DOMAIN} already exists."
fi

# 3. Activate VPS Nginx config for heygoodly (bestora already uses Self-Signed :8443)
cp nginx/conf.vps/heygoodly.conf nginx/conf.d/heygoodly.conf

echo "==> Testing and reloading shared-nginx..."
docker exec shared-nginx nginx -t
docker exec shared-nginx nginx -s reload
echo "==> Done! heygoodly: https://${DOMAIN} (Let's Encrypt) | bestora: https://<VPS_IP>:8443 (Self-Signed)"
