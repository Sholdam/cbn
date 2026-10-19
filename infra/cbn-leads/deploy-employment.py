"""Narrow, authorized operational deploy. No credentials or customer data."""
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import sys

source = Path('/opt/cbn/builds/crm-leads-20261019/cbn_lead_capture.rb')
target = Path('/opt/cbn/infra/cbn-leads/cbn_lead_capture.rb')
config = Path('/srv/cbn-production/chatwoot_storage/cbn-lead-capture-config.json')
manifest = Path('/opt/cbn/builds/crm-leads-20261019/employment-deploy-manifest.json')
if sys.argv[1] == 'stage':
    if manifest.exists():
        raise SystemExit('Deploy manifest exists: inspect before retry')
    if hashlib.sha256(target.read_bytes()).hexdigest() != '0df2b67b2cd735ef50995491449db4cb9ee511bb3d095e19b234577488a56423':
        raise SystemExit('Production source differs from inspected baseline')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = target.parent / ('employment-backup-' + stamp)
    backup.mkdir(mode=0o700)
    shutil.copy2(target, backup / target.name)
    shutil.copy2(config, backup / config.name)
    settings = json.loads(config.read_text())
    if settings.get('employment_rule_id') or settings['rules'].get('11'):
        raise SystemExit('Employment already configured')
    # Write existing inode: the worker uses a single-file bind mount.
    target.write_bytes(source.read_bytes())
    manifest.write_text(json.dumps({'backup': str(backup), 'stage': 'code_staged', 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}))
    manifest.chmod(0o600)
    print(json.dumps({'code_staged': True, 'backup_created': True}))
elif sys.argv[1] == 'enable':
    record = json.loads(manifest.read_text())
    settings = json.loads(config.read_text())
    if hashlib.sha256(target.read_bytes()).hexdigest() != record['source_sha256']:
        raise SystemExit('Staged code changed')
    settings['rules']['11'] = 'vinculo'
    settings['employment_rule_id'] = 11
    pending = config.with_suffix('.tmp')
    pending.write_text(json.dumps(settings))
    pending.chmod(config.stat().st_mode & 0o777)
    pending.replace(config)
    record['stage'] = 'enabled'
    manifest.write_text(json.dumps(record))
    print(json.dumps({'employment_enabled': True, 'rule_id': 11, 'existing_activation_time_preserved': True}))
else:
    raise SystemExit('Use stage or enable')
