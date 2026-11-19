#!/usr/bin/env bash
# =============================================================================
# Enable Production Let's Encrypt SSL on VPS:
# - heygoodly:  https://heygoodly.com  + www.heygoodly.com
# - heyworthly: https://heyworthly.com + www.heyworthly.com
#
# Usage:
#   ./scripts/enable-vps-ssl.sh [email]                    # Cấp SSL cho cả 2 domain
#   ./scripts/enable-vps-ssl.sh [email] heyworthly.com     # Chỉ cấp SSL cho heyworthly.com
#   ./scripts/enable-vps-ssl.sh [email] heygoodly.com      # Chỉ cấp SSL cho heygoodly.com
# =============================================================================
set -euo pipefail

EMAIL="${1:-admin@heygoodly.com}"
TARGET_DOMAIN="${2:-all}"
INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$INFRA_DIR"

# 1. Ensure self-signed SSL exists for IP fallback (:443 / :8443)
if [ ! -f nginx/ssl/selfsigned.crt ] || [ ! -f nginx/ssl/selfsigned.key ]; then
  mkdir -p nginx/ssl
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout nginx/ssl/selfsigned.key \
    -out nginx/ssl/selfsigned.crt \
    -subj "/C=US/ST=CA/L=SF/O=HeyWorthly/CN=localhost"
fi

issue_and_activate() {
  local site_slug="$1"
  local domain="$2"

  if [ ! -f "nginx/certbot/conf/live/${domain}/fullchain.pem" ]; then
    echo "==> Issuing Let's Encrypt SSL certificate for ${domain} & www.${domain}..."
    docker run --rm \
      -v "${INFRA_DIR}/nginx/certbot/www:/var/www/certbot" \
      -v "${INFRA_DIR}/nginx/certbot/conf:/etc/letsencrypt" \
      certbot/certbot certonly --webroot \
      --webroot-path=/var/www/certbot \
      --email "${EMAIL}" \
      --agree-tos --no-eff-email \
      -d "${domain}" -d "www.${domain}"
  else
    echo "==> Let's Encrypt certificate for ${domain} already exists."
  fi

  cp "nginx/conf.vps/${site_slug}.conf" "nginx/conf.d/${site_slug}.conf"
  echo "==> Activated VPS SSL Nginx config for ${site_slug} (https://${domain})."
}

case "${TARGET_DOMAIN}" in
  all)
    issue_and_activate "heygoodly" "heygoodly.com"
    issue_and_activate "heyworthly" "heyworthly.com"
    ;;
  heygoodly.com|heygoodly)
    issue_and_activate "heygoodly" "heygoodly.com"
    ;;
  heyworthly.com|heyworthly)
    issue_and_activate "heyworthly" "heyworthly.com"
    ;;
  *)
    echo "ERROR: Unsupported target '${TARGET_DOMAIN}'. Use: all | heygoodly.com | heyworthly.com"
    exit 1
    ;;
esac

echo "==> Testing and reloading shared-nginx..."
docker exec shared-nginx nginx -t
docker exec shared-nginx nginx -s reload
echo "==> Ensuring shared-certbot auto-renew container is running..."
docker compose -f docker-compose.nginx.yml up -d certbot
echo "==> Done! SSL active + auto-renew enabled for target: ${TARGET_DOMAIN}"
