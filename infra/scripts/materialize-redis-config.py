#!/usr/bin/env python3
"""Write the original Railway Redis password into LUKS-backed config."""

import json
import os
from pathlib import Path

vault = Path('/srv/cbn-production')
source = vault / 'secrets/railway-vars.json'
target = vault / 'secrets/redis.conf'
with source.open('r', encoding='utf-8') as handle:
    values = json.load(handle)['services']['Redis']
password = values.get('REDIS_PASSWORD')
if not isinstance(password, str) or not password or '${{' in password:
    raise SystemExit('Senha Redis da origem indisponivel.')
if any(character in password for character in ('"', '\\', '\r', '\n')):
    raise SystemExit('Senha Redis exige escape nao implementado.')
if target.exists():
    raise SystemExit('Arquivo Redis ja existe; nao sera substituido.')

configuration = (
    'bind 0.0.0.0\n'
    'protected-mode yes\n'
    'port 6379\n'
    f'requirepass "{password}"\n'
    'save 60 1\n'
    'dir /data\n'
    'appendonly no\n'
)
descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(descriptor, 'w', encoding='utf-8') as handle:
    handle.write(configuration)
print('redis_config=created_in_luks')
