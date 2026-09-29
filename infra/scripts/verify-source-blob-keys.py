#!/usr/bin/env python3
"""Compare restored ActiveStorage references with source and local S3 objects."""

import json
import subprocess
from pathlib import Path

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

root = Path('/srv/cbn-production')
if subprocess.check_output(['findmnt', '-n', '-o', 'SOURCE', '--target', str(root)], text=True).strip() != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

raw = subprocess.check_output([
    'docker', 'exec', '-u', 'postgres', 'cbn-railway-clone-postgres-physical-1',
    'psql', '-d', 'railway', '-At', '-c', 'select key from active_storage_blobs',
], text=True)
keys = raw.splitlines()
manifest = json.loads((root / 'media/railway-media-manifest.json').read_text())
exported = {item['key'] for item in manifest['objects']}
missing = sorted(set(keys) - exported)

source = json.loads((root / 'secrets/railway-vars.json').read_text())['services']['Chatwoot']
client = boto3.client(
    's3', endpoint_url=source['STORAGE_ENDPOINT'], region_name=source['STORAGE_REGION'],
    aws_access_key_id=source['STORAGE_ACCESS_KEY_ID'],
    aws_secret_access_key=source['STORAGE_SECRET_ACCESS_KEY'],
    config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}),
)
still_at_source = 0
absent_at_source = 0
for key in missing:
    try:
        client.head_object(Bucket=source['STORAGE_BUCKET_NAME'], Key=key)
        still_at_source += 1
    except ClientError as error:
        if error.response.get('Error', {}).get('Code') in ('404', 'NoSuchKey', 'NotFound'):
            absent_at_source += 1
        else:
            raise

print(f'blob_rows={len(keys)}')
print(f'unique_blob_keys={len(set(keys))}')
print(f'exported_bucket_objects={len(exported)}')
print(f'blob_keys_absent_from_export={len(missing)}')
print(f'absent_keys_still_at_source={still_at_source}')
print(f'absent_keys_also_missing_at_source={absent_at_source}')
