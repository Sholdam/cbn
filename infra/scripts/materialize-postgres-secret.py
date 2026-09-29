#!/usr/bin/env python3
"""Prepare local PostgreSQL credentials from the protected Railway snapshot."""

import json
import os
from pathlib import Path

vault = Path('/srv/cbn-production')
source = vault / 'secrets/railway-vars.json'
target = vault / 'secrets/postgres_password'

with source.open('r', encoding='utf-8') as handle:
    snapshot = json.load(handle)
values = snapshot['services']['PgVector']
password = values.get('POSTGRES_PASSWORD')
username = values.get('POSTGRES_USER')
database = values.get('POSTGRES_DB')
if not all(isinstance(value, str) and value for value in (password, username, database)):
    raise SystemExit('Credenciais PostgreSQL incompletas no snapshot.')
if '${{' in password:
    raise SystemExit('Senha PostgreSQL nao foi resolvida pelo Railway CLI.')
if target.exists():
    raise SystemExit('Arquivo de senha ja existe; nao sera substituido.')

descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(descriptor, 'wb') as handle:
    handle.write(password.encode('utf-8'))

print(f'postgres_user={username}')
print(f'postgres_database={database}')
print('postgres_password_file=created_in_luks')
