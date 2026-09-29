#!/usr/bin/env python3
"""Restore the Railway media snapshot into the local private S3 bucket."""

import hashlib
import json
import subprocess
from pathlib import Path, PurePosixPath

import boto3
from botocore.config import Config

root = Path('/srv/cbn-production')
mounted = subprocess.check_output(
    ['findmnt', '-n', '-o', 'SOURCE', '--target', str(root)], text=True
).strip()
if mounted != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

manifest = json.loads((root / 'media/railway-media-manifest.json').read_text())
settings = dict(
    line.split('=', 1) for line in (root / 'secrets/garage.env').read_text().splitlines()
    if '=' in line
)
bucket = manifest['bucket']
if settings['GARAGE_DEFAULT_BUCKET'] != bucket:
    raise SystemExit('Bucket mismatch')

client = boto3.client(
    's3', endpoint_url='http://127.0.0.1:3900', region_name='garage',
    aws_access_key_id=settings['GARAGE_DEFAULT_ACCESS_KEY'],
    aws_secret_access_key=settings['GARAGE_DEFAULT_SECRET_KEY'],
    config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}),
)
client.head_bucket(Bucket=bucket)

count = 0
total = 0
for item in manifest['objects']:
    key = item['key']
    relative = PurePosixPath(key)
    if relative.is_absolute() or not relative.parts or any(p in ('.', '..') for p in relative.parts):
        raise SystemExit('Unsafe object key')
    path = (root / 'media' / bucket).joinpath(*relative.parts)
    contents = path.read_bytes()
    expected = item['sha256']
    if len(contents) != item['size'] or hashlib.sha256(contents).hexdigest() != expected:
        raise SystemExit('Source media checksum mismatch')

    client.put_object(
        Bucket=bucket, Key=key, Body=contents,
        ContentType=item['contentType'] or 'application/octet-stream',
        Metadata=item.get('metadata') or {},
    )
    response = client.get_object(Bucket=bucket, Key=key)
    received = response['Body'].read()
    if len(received) != item['size'] or hashlib.sha256(received).hexdigest() != expected:
        raise SystemExit('Destination media checksum mismatch')
    count += 1
    total += len(received)

listed = sum(len(page.get('Contents', [])) for page in client.get_paginator('list_objects_v2').paginate(Bucket=bucket))
if listed != count:
    raise SystemExit('Destination object count mismatch')

print(f'verified_objects={count}')
print(f'verified_bytes={total}')
