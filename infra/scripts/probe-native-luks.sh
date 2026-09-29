#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

image=/var/lib/cbn-vault/probe.img
mount_path=/srv/cbn-probe
mapper=cbn_probe
key_file="$(mktemp /run/cbn-probe-key.XXXXXX)"
loop_device=''

cleanup() {
  if mountpoint -q "$mount_path"; then umount "$mount_path"; fi
  if cryptsetup status "$mapper" >/dev/null 2>&1; then cryptsetup close "$mapper"; fi
  if [[ -n "$loop_device" ]]; then losetup -d "$loop_device"; fi
  rm -f -- "$key_file"
}
trap cleanup EXIT

if [[ -e "$image" ]]; then
  printf 'Arquivo de prova ja existe; recusado.\n' >&2
  exit 2
fi

head -c 64 /dev/urandom > "$key_file"
mkdir -p -- "$(dirname "$image")" "$mount_path"
truncate -s 256M -- "$image"
loop_device="$(losetup --find --show -- "$image")"
cryptsetup luksFormat --batch-mode --type luks2 --key-file "$key_file" "$loop_device"
cryptsetup open --key-file "$key_file" "$loop_device" "$mapper"
mkfs.ext4 -q -F -E nodiscard,lazy_itable_init=1,lazy_journal_init=1 "/dev/mapper/$mapper"
mount "/dev/mapper/$mapper" "$mount_path"
printf 'cbn-probe-synthetic\n' > "$mount_path/probe.txt"
sync
umount "$mount_path"
cryptsetup close "$mapper"
cryptsetup open --key-file "$key_file" "$loop_device" "$mapper"
mount "/dev/mapper/$mapper" "$mount_path"
if [[ "$(cat "$mount_path/probe.txt")" != cbn-probe-synthetic ]]; then
  printf 'Falha de persistencia do cofre.\n' >&2
  exit 3
fi
printf 'native_luks_probe=passed\n'
