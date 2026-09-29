#!/usr/bin/env bash
set -euo pipefail

vault=/srv/cbn-production
expected=/dev/mapper/cbn_production
mounted=$(findmnt -n -o SOURCE --target "$vault")
if [[ "$mounted" != "$expected" ]]; then
  echo 'Cofre CBN não está montado no dispositivo esperado.' >&2
  exit 1
fi

umask 077
mkdir -p "$vault/waha/sessions" "$vault/waha/media" "$vault/waha/redis" "$vault/secrets"
chmod 700 "$vault/waha" "$vault/waha/sessions" "$vault/waha/media" "$vault/waha/redis"
chown 999:999 "$vault/waha/redis"

env_file="$vault/secrets/waha.env"
redis_file="$vault/secrets/waha-redis.conf"
if [[ -e "$env_file" || -e "$redis_file" ]]; then
  if [[ ! -s "$env_file" || ! -s "$redis_file" ]]; then
    echo 'Configuração WAHA parcial; preservar e corrigir manualmente.' >&2
    exit 1
  fi
  chown 999:999 "$redis_file"
  chmod 600 "$env_file" "$redis_file"
  echo 'WAHA: configuração existente preservada.'
  exit 0
fi

api_key=$(openssl rand -hex 32)
dashboard_password=$(openssl rand -hex 24)
redis_password=$(openssl rand -hex 32)

cat > "$env_file" <<EOF
WAHA_API_KEY=$api_key
WAHA_API_KEY_PLAIN=$api_key
WAHA_DASHBOARD_ENABLED=true
WAHA_DASHBOARD_USERNAME=cbn
WAHA_DASHBOARD_PASSWORD=$dashboard_password
WHATSAPP_SWAGGER_ENABLED=false
WAHA_PRINT_QR=False
WHATSAPP_DEFAULT_ENGINE=GOWS
WAHA_APPS_ENABLED=True
WAHA_APPS_ON=chatwoot
REDIS_URL=redis://:$redis_password@waha-redis:6379
WHATSAPP_FILES_FOLDER=/app/.media
WHATSAPP_FILES_LIFETIME=604800
WAHA_CLIENT_DEVICE_NAME=CBN Local
WAHA_CLIENT_BROWSER_NAME=Chrome
EOF

cat > "$redis_file" <<EOF
appendonly yes
dir /data
requirepass $redis_password
EOF
chmod 600 "$env_file" "$redis_file"
chown 999:999 "$redis_file"
echo 'WAHA: segredos e diretórios locais criados no cofre.'
