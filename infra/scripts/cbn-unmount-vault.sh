#!/usr/bin/env bash
set -Eeuo pipefail
mount_path=/srv/cbn-production
expected=/dev/mapper/cbn_production
docker_pid="$(systemctl show docker.service -p MainPID --value 2>/dev/null || true)"
for service_pid in "$docker_pid" 1; do
  [[ "$service_pid" =~ ^[1-9][0-9]*$ && -d "/proc/$service_pid" ]] || continue
  if nsenter -t "$service_pid" -m -- mountpoint -q "$mount_path"; then
    source="$(nsenter -t "$service_pid" -m -- findmnt -n -o SOURCE --target "$mount_path")"
    [[ "$source" == "$expected" ]] || { echo 'Montagem CBN inesperada no servico.' >&2; exit 2; }
    nsenter -t "$service_pid" -m -- umount "$mount_path"
  fi
done
if mountpoint -q "$mount_path"; then
  [[ "$(findmnt -n -o SOURCE --target "$mount_path")" == "$expected" ]] || exit 2
  umount "$mount_path"
fi
