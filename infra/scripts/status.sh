#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  printf 'Docker Compose indisponível neste host.\n' >&2
  exit 2
fi

rows="$(cd "$repo_root/infra" && docker compose --profile synthetic ps --all --format '{{.Service}}|{{.State}}|{{.Health}}')"

printf '%-20s %-24s %s\n' 'SERVIÇO' 'ESTADO' 'SAÚDE'
printf '%-20s %-24s %s\n' '--------------------' '------------------------' '----------------'

while IFS='|' read -r label service; do
  row="$(printf '%s\n' "$rows" | awk -F '|' -v wanted="$service" '$1 == wanted { print; exit }')"
  if [[ -z "$row" ]]; then
    printf '%-20s %-24s %s\n' "$label" 'NÃO INICIADO' 'PENDENTE'
    continue
  fi
  IFS='|' read -r _ state health <<< "$row"
  printf '%-20s %-24s %s\n' "$label" "${state:-desconhecido}" "${health:-sem healthcheck}"
done <<'SERVICES'
PostgreSQL|postgres
Redis|redis
Chatwoot|chatwoot-web
Sidekiq|chatwoot-sidekiq
n8n|n8n
WAHA|waha
MinIO/Storage|minio
Telegram Gateway|telegram-gateway
Gateway público|cbn-gateway
SERVICES
