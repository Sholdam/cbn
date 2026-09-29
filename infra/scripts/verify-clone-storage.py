#!/usr/bin/env python3
"""Read-only checks for the restored Redis and S3 storage."""

import hashlib
import json
import os
import subprocess
from pathlib import Path

import boto3
from botocore.config import Config

root = Path('/srv/cbn-production')
if subprocess.check_output(['findmnt', '-n', '-o', 'SOURCE', '--target', str(root)], text=True).strip() != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

source = json.loads((root / 'secrets/railway-vars.json').read_text())['services']
env = os.environ.copy()
env['REDISCLI_AUTH'] = source['Redis']['REDIS_PASSWORD']
redis_response = subprocess.check_output([
    'docker', 'exec', '-e', 'REDISCLI_AUTH',
    'cbn-railway-clone-redis-1', 'redis-cli', 'DBSIZE',
], env=env, text=True).strip()
if not redis_response.isdigit() or int(redis_response) <= 0:
    raise SystemExit(f'Redis key count invalid: {redis_response[:80]}')

manifest = json.loads((root / 'media/railway-media-manifest.json').read_text())
settings = dict(line.split('=', 1) for line in (root / 'secrets/garage.env').read_text().splitlines() if '=' in line)
client = boto3.client(
    's3', endpoint_url='http://127.0.0.1:3900', region_name='garage',
    aws_access_key_id=settings['GARAGE_DEFAULT_ACCESS_KEY'],
    aws_secret_access_key=settings['GARAGE_DEFAULT_SECRET_KEY'],
    config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}),
)
bucket = manifest['bucket']
count = 0
total = 0
for item in manifest['objects']:
    body = client.get_object(Bucket=bucket, Key=item['key'])['Body'].read()
    if len(body) != item['size'] or hashlib.sha256(body).hexdigest() != item['sha256']:
        raise SystemExit('S3 object mismatch')
    count += 1
    total += len(body)

print(f'redis_keys={redis_response}')
print(f's3_verified_objects={count}')
print(f's3_verified_bytes={total}')
