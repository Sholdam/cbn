#!/usr/bin/env python3
"""Safely extract the copied Chatwoot volume into the mounted local vault."""

import subprocess
import tarfile
from pathlib import Path, PurePosixPath

root = Path('/srv/cbn-production')
if subprocess.check_output(['findmnt', '-n', '-o', 'SOURCE', '--target', str(root)], text=True).strip() != '/dev/mapper/cbn_production':
    raise SystemExit('CBN LUKS vault is not mounted')

archive = root / 'backups/chatwoot-storage-railway-20260928.tar.gz'
destination = root / 'chatwoot_storage'
destination.mkdir(mode=0o700, exist_ok=True)
if any(destination.iterdir()):
    raise SystemExit('Chatwoot destination is not empty')

with tarfile.open(archive, 'r:gz') as source:
    members = source.getmembers()
    for member in members:
        path = PurePosixPath(member.name)
        if path.is_absolute() or '..' in path.parts or not (member.isdir() or member.isfile()):
            raise SystemExit('Unsafe tar member')
    source.extractall(destination, members=members, filter='data')

print(f'extracted_entries={len(members)}')
