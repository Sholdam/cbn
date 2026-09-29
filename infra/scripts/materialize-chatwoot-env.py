#!/usr/bin/env python3
"""Build an isolated local Chatwoot environment from the protected Railway snapshot."""

import json
import os
import subprocess
from pathlib import Path
from urllib.parse import quote

root = Path('/srv/cbn-production')
if subprocess.check_output(['findmnt', '-n', '-o', 'SOURCE', '--target', str(root)], text=True).strip() != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

target = root / 'secrets/chatwoot-local.env'
if target.exists():
    raise SystemExit('Local Chatwoot environment already exists')

snapshot = json.loads((root / 'secrets/railway-vars.json').read_text())['services']
source = snapshot['Chatwoot']
redis_password = snapshot['Redis']['REDIS_PASSWORD']
garage = dict(line.split('=', 1) for line in (root / 'secrets/garage.env').read_text().splitlines() if '=' in line)

retained = (
    'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY',
    'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY',
    'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT',
    'SECRET_KEY_BASE', 'RAILS_ENV', 'NODE_ENV', 'INSTALLATION_ENV',
    'RAILS_LOG_TO_STDOUT', 'LOG_LEVEL', 'POSTGRES_DATABASE',
    'POSTGRES_USERNAME', 'POSTGRES_PASSWORD', 'MAILER_SENDER_EMAIL',
    'FB_APP_ID', 'FB_APP_SECRET', 'FB_VERIFY_TOKEN',
    'INSTAGRAM_APP_ID', 'IG_VERIFY_TOKEN',
)
values = {key: source[key] for key in retained if source.get(key)}
values.update({
    'POSTGRES_HOST': 'postgres-physical',
    'POSTGRES_PORT': '5432',
    'POSTGRES_SSLMODE': 'disable',
    'DATABASE_SSL_VERIFY': 'false',
    'REDIS_URL': f'redis://:{quote(redis_password, safe="")}@redis:6379',
    'ACTIVE_STORAGE_SERVICE': 's3_compatible',
    'STORAGE_ACCESS_KEY_ID': garage['GARAGE_DEFAULT_ACCESS_KEY'],
    'STORAGE_SECRET_ACCESS_KEY': garage['GARAGE_DEFAULT_SECRET_KEY'],
    'STORAGE_BUCKET_NAME': garage['GARAGE_DEFAULT_BUCKET'],
    'STORAGE_ENDPOINT': 'http://garage:3900',
    'STORAGE_REGION': 'garage',
    'STORAGE_FORCE_PATH_STYLE': 'true',
    'FRONTEND_URL': 'http://localhost:3000',
    'FORCE_SSL': 'false',
    'ENABLE_ACCOUNT_SIGNUP': 'false',
    'SMTP_ADDRESS': '127.0.0.1',
    'SMTP_PORT': '9',
})
for key, value in values.items():
    if not isinstance(value, str) or '\n' in value or '\r' in value or '${{' in value:
        raise SystemExit(f'Invalid value for {key}')

descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(descriptor, 'w') as output:
    for key, value in sorted(values.items()):
        output.write(f'{key}={value}\n')
    output.flush()
    os.fsync(output.fileno())
print(f'local_chatwoot_variables={len(values)}')
