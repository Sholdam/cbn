#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

mode="${1:-}"
image=/var/lib/cbn-vault/cbn-production.img
mount_path=/srv/cbn-production
mapper=cbn_production

# WSL command sessions, systemd and Docker can have separate mount namespaces.
# Confirm the encrypted volume in each namespace before a service binds files.
ensure_service_mounts() {
  local service_pid source options
  options=",$(findmnt -n -o OPTIONS --target "$mount_path"),"
  if [[ "$options" == *,ro,* || "$options" == *,emergency_ro,* ]]; then
    printf 'Cofre CBN somente leitura; reparar antes de iniciar servicos.\n' >&2
    return 2
  fi
  for service_pid in 1 "$(systemctl show docker.service -p MainPID --value 2>/dev/null || true)"; do
    [[ "$service_pid" =~ ^[1-9][0-9]*$ && -d "/proc/$service_pid" ]] || continue
    if nsenter -t "$service_pid" -m -- mountpoint -q "$mount_path"; then
      source="$(nsenter -t "$service_pid" -m -- findmnt -n -o SOURCE --target "$mount_path")"
      if [[ "$source" != "/dev/mapper/$mapper" ]]; then
        printf 'Montagem CBN inesperada no namespace do servico.\n' >&2
        return 2
      fi
      options=",$(nsenter -t "$service_pid" -m -- findmnt -n -o OPTIONS --target "$mount_path"),"
      if [[ "$options" == *,ro,* || "$options" == *,emergency_ro,* ]]; then
        printf 'Cofre CBN somente leitura no namespace do servico.\n' >&2
        return 2
      fi
    else
      nsenter -t "$service_pid" -m -- mount "/dev/mapper/$mapper" "$mount_path"
    fi
  done
}

key_file="$(mktemp /run/cbn-native-vault-key.XXXXXX)"
trap 'rm -f -- "$key_file"' EXIT
cat > "$key_file"

if [[ "$(wc -c < "$key_file")" -ne 64 ]]; then
  printf 'Chave CBN com tamanho inesperado.\n' >&2
  exit 2
fi
if mountpoint -q "$mount_path"; then
  if [[ "$(findmnt -n -o SOURCE --target "$mount_path")" != "/dev/mapper/$mapper" ]]; then
    printf 'Cofre CBN montado em dispositivo inesperado.\n' >&2
    exit 2
  fi
  ensure_service_mounts
  printf 'vault_mounted=%s\n' "$mount_path"
  exit 0
fi

if [[ "$mode" == init ]]; then
  if [[ -e "$image" ]]; then
    printf 'A imagem nativa ja existe; init recusado.\n' >&2
    exit 2
  fi
  mkdir -p -- "$(dirname "$image")"
  truncate -s 50G -- "$image"
elif [[ "$mode" != mount || ! -f "$image" ]]; then
  printf 'Uso: cbn-native-vault.sh init|mount\n' >&2
  exit 2
fi

loop_device="$(losetup -j "$image" | head -n 1 | cut -d : -f 1)"
if [[ -z "$loop_device" ]]; then
  loop_device="$(losetup --find --show -- "$image")"
fi
if [[ "$mode" == init ]]; then
  cryptsetup luksFormat --batch-mode --type luks2 --key-file "$key_file" "$loop_device"
else
  cryptsetup isLuks "$loop_device"
fi
if ! cryptsetup status "$mapper" >/dev/null 2>&1; then
  cryptsetup open --key-file "$key_file" "$loop_device" "$mapper"
fi
if [[ "$mode" == init ]]; then
  mkfs.ext4 -q -F -E nodiscard,lazy_itable_init=1,lazy_journal_init=1 -L CBN_PRODUCTION "/dev/mapper/$mapper"
fi
mkdir -p -- "$mount_path"
mount "/dev/mapper/$mapper" "$mount_path"
ensure_service_mounts
chmod 0700 "$mount_path"
mkdir -p -- "$mount_path"/{backups,postgres,redis,chatwoot_storage,n8n,telegram,media}
printf 'vault_mounted=%s\n' "$mount_path"
