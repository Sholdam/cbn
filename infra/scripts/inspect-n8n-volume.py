#!/usr/bin/env python3
"""Report counts from the inactive n8n volume without exposing its contents."""

import sqlite3
import subprocess
from pathlib import Path

vault = Path('/srv/cbn-production')
source = subprocess.check_output(
    ['findmnt', '-n', '-o', 'SOURCE', '--target', str(vault)], text=True
).strip()
if source != '/dev/mapper/cbn_production':
    raise SystemExit('Cofre LUKS CBN nao esta montado.')

database = vault / 'n8n/database.sqlite'
if not database.is_file():
    raise SystemExit('Banco SQLite do n8n nao encontrado no volume.')
connection = sqlite3.connect(f'file:{database}?mode=ro', uri=True)
try:
    tables = {row[0] for row in connection.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    )}
    print(f'n8n_tables={len(tables)}')
    for table in ('workflow_entity', 'credentials_entity', 'execution_entity'):
        if table in tables:
            count = connection.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
            print(f'{table}_count={count}')
    if 'workflow_entity' in tables:
        active = connection.execute(
            'SELECT count(*) FROM workflow_entity WHERE active = 1'
        ).fetchone()[0]
        print(f'active_workflows={active}')
finally:
    connection.close()
