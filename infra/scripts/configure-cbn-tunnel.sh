#!/usr/bin/env bash
set -euo pipefail

server_addr=${1:?Railway TCP proxy host required}
server_port=${2:?Railway TCP proxy port required}
crm_domain=${3:?Railway HTTP domain required}
vault=/srv/cbn-production
target=$vault/secrets/frp/client.env

if [[ "$(findmnt -n -o SOURCE --target "$vault")" != /dev/mapper/cbn_production ]]; then
  echo 'CBN LUKS vault is not mounted' >&2
  exit 2
fi
if [[ ! "$server_addr" =~ ^[a-zA-Z0-9.-]+\.proxy\.rlwy\.net$ ]] ||
   [[ ! "$server_port" =~ ^[0-9]{2,5}$ ]] ||
   [[ "$server_port" -gt 65535 ]] ||
   [[ ! "$crm_domain" =~ ^[a-zA-Z0-9.-]+\.up\.railway\.app$ ]]; then
  echo 'Unexpected Railway endpoint or domain' >&2
  exit 3
fi
if [[ -e "$target" ]]; then
  echo 'Tunnel endpoint already configured; refusing to replace it' >&2
  exit 4
fi
bucket=$(sed -n 's/^GARAGE_DEFAULT_BUCKET=//p' "$vault/secrets/garage.env")
if [[ ! "$bucket" =~ ^[a-zA-Z0-9.-]+$ ]]; then
  echo 'Invalid local S3 bucket name' >&2
  exit 5
fi
preview_password=$(cat "$vault/secrets/frp/preview_password")
if [[ ! "$preview_password" =~ ^[a-f0-9]{48}$ ]]; then
  echo 'Invalid preview password' >&2
  exit 6
fi

umask 077
printf 'FRP_SERVER_ADDR=%s\nFRP_SERVER_PORT=%s\nFRP_CRM_DOMAIN=%s\nFRP_BUCKET_NAME=%s\nFRP_PREVIEW_PASSWORD=%s\n' \
  "$server_addr" "$server_port" "$crm_domain" "$bucket" "$preview_password" > "$target"
printf 'tunnel_endpoint=configured_inside_luks\n'
