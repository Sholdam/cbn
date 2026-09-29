#!/usr/bin/env python3
"""Copy the Railway Chatwoot bucket into the mounted CBN LUKS vault."""

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

vault = Path('/srv/cbn-production')
source = subprocess.check_output(
    ['findmnt', '-n', '-o', 'SOURCE', '--target', str(vault)], text=True
).strip()
if source != '/dev/mapper/cbn_production':
    raise SystemExit('Cofre LUKS CBN nao esta montado.')

with (vault / 'secrets/railway-vars.json').open('r', encoding='utf-8') as handle:
    values = json.load(handle)['services']['Chatwoot']
required = (
    'STORAGE_ACCESS_KEY_ID', 'STORAGE_SECRET_ACCESS_KEY',
    'STORAGE_BUCKET_NAME', 'STORAGE_ENDPOINT', 'STORAGE_REGION',
)
if any(not isinstance(values.get(name), str) or not values[name] for name in required):
    raise SystemExit('Configuracao S3 da origem incompleta.')
if any('${{' in values[name] for name in required):
    raise SystemExit('Referencia S3 da origem nao foi resolvida.')
if urlparse(values['STORAGE_ENDPOINT']).scheme != 'https':
    raise SystemExit('Endpoint S3 da origem nao usa HTTPS.')

bucket = values['STORAGE_BUCKET_NAME']
destination = vault / 'media' / bucket
manifest_path = vault / 'media' / 'railway-media-manifest.json'
if manifest_path.exists():
    raise SystemExit('Manifesto S3 ja existe; exportacao nao sera repetida.')
destination.mkdir(mode=0o700, parents=True, exist_ok=True)
os.umask(0o077)

client = boto3.client(
    's3',
    endpoint_url=values['STORAGE_ENDPOINT'],
    region_name=values['STORAGE_REGION'],
    aws_access_key_id=values['STORAGE_ACCESS_KEY_ID'],
    aws_secret_access_key=values['STORAGE_SECRET_ACCESS_KEY'],
    config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}),
)

records = []
total_bytes = 0
try:
    paginator = client.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=bucket):
        for item in page.get('Contents', []):
            key = item['Key']
            relative = PurePosixPath(key)
            if relative.is_absolute() or not relative.parts or any(
                part in ('.', '..') for part in relative.parts
            ):
                raise RuntimeError('Nome de objeto S3 inseguro.')
            target = destination.joinpath(*relative.parts)
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            if target.exists():
                raise RuntimeError('Objeto S3 repetido no destino.')

            response = client.get_object(Bucket=bucket, Key=key)
            digest = hashlib.sha256()
            size = 0
            with target.open('xb') as handle:
                for chunk in response['Body'].iter_chunks(chunk_size=1024 * 1024):
                    if chunk:
                        handle.write(chunk)
                        digest.update(chunk)
                        size += len(chunk)
                handle.flush()
                os.fsync(handle.fileno())
            if size != int(item['Size']) or size != int(response['ContentLength']):
                raise RuntimeError('Tamanho de objeto S3 divergente.')
            total_bytes += size
            records.append({
                'key': key,
                'size': size,
                'sha256': digest.hexdigest(),
                'etag': response.get('ETag'),
                'contentType': response.get('ContentType'),
                'metadata': response.get('Metadata', {}),
            })
except (BotoCoreError, ClientError, OSError, RuntimeError) as error:
    print(f'Exportacao S3 interrompida: {type(error).__name__}.', file=sys.stderr)
    raise SystemExit(1)

with manifest_path.open('x', encoding='utf-8') as handle:
    json.dump({'bucket': bucket, 'objects': records}, handle, ensure_ascii=False)
    handle.flush()
    os.fsync(handle.fileno())

print(f's3_objects={len(records)}')
print(f's3_bytes={total_bytes}')
print('manifest=created_in_luks')
