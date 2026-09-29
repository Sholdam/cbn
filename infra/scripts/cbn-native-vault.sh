#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

mode="${1:-}"
image=/var/lib/cbn-vault/cbn-production.img
mount_path=/srv/cbn-production
mapper=cbn_production
key_file="$(mktemp /run/cbn-native-vault-key.XXXXXX)"
trap 'rm -f -- "$key_file"' EXIT
cat > "$key_file"

if [[ "$(wc -c < "$key_file")" -ne 64 ]]; then
  printf 'Chave CBN com tamanho inesperado.\n' >&2
  exit 2
fi
if mountpoint -q "$mount_path"; then
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
chmod 0700 "$mount_path"
mkdir -p -- "$mount_path"/{backups,postgres,redis,chatwoot_storage,n8n,telegram,media}
printf 'vault_mounted=%s\n' "$mount_path"
