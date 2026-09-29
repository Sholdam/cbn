#!/usr/bin/env python3
"""Initialize private single-node Garage storage inside the mounted CBN vault."""

import json
import os
import secrets
import subprocess
from pathlib import Path

ROOT = Path('/srv/cbn-production')
if subprocess.check_output(['findmnt', '-n', '-o', 'SOURCE', '--target', str(ROOT)], text=True).strip() != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

manifest = json.loads((ROOT / 'media/railway-media-manifest.json').read_text())
bucket = manifest['bucket']
if not bucket or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-.' for c in bucket):
    raise SystemExit('Invalid source bucket name')

garage = ROOT / 'garage'
secrets_dir = ROOT / 'secrets'
for directory in (garage, garage / 'meta', garage / 'data', secrets_dir):
    directory.mkdir(mode=0o700, exist_ok=True)

config = secrets_dir / 'garage.toml'
env = secrets_dir / 'garage.env'
if config.exists() or env.exists():
    raise SystemExit('Garage config already exists; refusing to replace keys')

rpc_secret = secrets.token_hex(32)
admin_token = secrets.token_urlsafe(36)
metrics_token = secrets.token_urlsafe(36)
access_key = 'GK' + secrets.token_hex(16)
secret_key = secrets.token_hex(32)

configuration = f'''metadata_dir = "/var/lib/garage/meta"
data_dir = "/var/lib/garage/data"
db_engine = "sqlite"
replication_factor = 1
rpc_bind_addr = "[::]:3901"
rpc_public_addr = "127.0.0.1:3901"
rpc_secret = "{rpc_secret}"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.garage.localhost"

[admin]
api_bind_addr = "[::]:3903"
admin_token = "{admin_token}"
metrics_token = "{metrics_token}"
'''
environment = f'''GARAGE_DEFAULT_ACCESS_KEY={access_key}
GARAGE_DEFAULT_SECRET_KEY={secret_key}
GARAGE_DEFAULT_BUCKET={bucket}
'''

for path, data in ((config, configuration), (env, environment)):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        output.write(data)
        output.flush()
        os.fsync(output.fileno())

print('Garage vault config ready; credentials held only in LUKS')
