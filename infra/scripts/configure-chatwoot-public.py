#!/usr/bin/env python3
"""Set public Chatwoot URLs without exposing the encrypted local environment."""

import os
import re
import subprocess
from pathlib import Path

vault = Path('/srv/cbn-production')
if subprocess.check_output(
    ['findmnt', '-n', '-o', 'SOURCE', '--target', str(vault)], text=True
).strip() != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

tunnel = dict(
    line.split('=', 1)
    for line in (vault / 'secrets/frp/client.env').read_text().splitlines()
    if '=' in line
)
domain = tunnel['FRP_CRM_DOMAIN']
if not re.fullmatch(r'[a-zA-Z0-9.-]+\.up\.railway\.app', domain):
    raise SystemExit('Unexpected Railway domain')

target = vault / 'secrets/chatwoot-local.env'
backup = vault / 'secrets/chatwoot-local.env.pre-tunnel'
if backup.exists():
    raise SystemExit('Previous environment snapshot exists; refusing second rewrite')

original = target.read_bytes()
lines = original.decode('utf-8').splitlines()
replacements = {
    'FRONTEND_URL': f'https://{domain}',
    'STORAGE_ENDPOINT': f'https://{domain}',
}
seen = set()
updated = []
for line in lines:
    key = line.partition('=')[0]
    if key in replacements:
        if key in seen:
            raise SystemExit(f'Duplicate {key}')
        seen.add(key)
        updated.append(f'{key}={replacements[key]}')
    else:
        updated.append(line)
if seen != replacements.keys():
    raise SystemExit('Required Chatwoot URL keys are missing')

os.umask(0o077)
with backup.open('xb') as stream:
    stream.write(original)
    stream.flush()
    os.fsync(stream.fileno())

temporary = target.with_name(target.name + '.new')
try:
    with temporary.open('xb') as stream:
        stream.write(('\n'.join(updated) + '\n').encode('utf-8'))
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(target)
finally:
    temporary.unlink(missing_ok=True)
print('chatwoot_public_urls=configured_inside_luks')
