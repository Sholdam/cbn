#!/usr/bin/env python3
"""Count disk blob references present in each preserved Railway volume."""

import subprocess
from pathlib import Path

root = Path('/srv/cbn-production')
if subprocess.check_output(['findmnt', '-n', '-o', 'SOURCE', '--target', str(root)], text=True).strip() != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

raw = subprocess.check_output([
    'docker', 'exec', '-u', 'postgres', 'cbn-railway-clone-postgres-physical-1',
    'psql', '-d', 'railway', '-At', '-c',
    "select key from active_storage_blobs where service_name='local'",
], text=True)
keys = raw.splitlines()
locations = {
    'chatwoot': root / 'chatwoot_storage',
    'sidekiq': root / 'sidekiq_storage',
}
counts = {name: 0 for name in locations}
for key in keys:
    if not key.isalnum():
        raise SystemExit('Unexpected blob key')
    for name, directory in locations.items():
        path = directory / key[:2] / key[2:4] / key
        if path.is_file():
            counts[name] += 1

print(f'local_blob_rows={len(keys)}')
for name, count in sorted(counts.items()):
    print(f'{name}_volume_present={count}')
