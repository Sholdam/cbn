"""Inspect local/public CBN services, emitting no tokens, phones or signed URLs."""
import json
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

vault = Path('/srv/cbn-production')

def status(url, headers=None):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers or {}), timeout=4) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except (OSError, TimeoutError):
        return 0

result = {'local_crm': status('http://127.0.0.1:3000/'), 'local_site': status('http://127.0.0.1:3002/')}
try:
    mounted = subprocess.run(['findmnt', '-n', '-o', 'SOURCE', '--target', str(vault)],
                             capture_output=True, text=True, timeout=4, check=True)
    result['vault_mounted'] = mounted.stdout.strip() == '/dev/mapper/cbn_production'
    options = subprocess.run(['findmnt', '-n', '-o', 'OPTIONS', '--target', str(vault)],
                             capture_output=True, text=True, timeout=4, check=True)
    result['vault_writable'] = (result['vault_mounted'] and
                              not {'ro', 'emergency_ro'}.intersection(options.stdout.strip().split(',')))
except (OSError, subprocess.SubprocessError):
    result['vault_mounted'] = False
    result['vault_writable'] = False
containers = ['cbn-railway-clone-' + name + '-1' for name in
              ['postgres-physical', 'redis', 'garage', 'chatwoot-web', 'cbn-site',
               'waha-redis', 'waha', 'chatwoot-waha-worker']]
containers += ['cbn-outbound-tunnel-frpc-1', 'cbn-outbound-tunnel-site-preview-1']
try:
    check = subprocess.run(['docker', 'inspect', '--format', '{{json .State}}', *containers],
                           capture_output=True, text=True, timeout=8, check=True)
    states = [json.loads(line) for line in check.stdout.splitlines()]
    result['containers_running'] = len(states) == len(containers) and all(item.get('Running') for item in states)
except (OSError, ValueError, subprocess.SubprocessError):
    result['containers_running'] = False
try:
    client = dict(line.split('=', 1) for line in (vault / 'secrets/frp/client.env').read_text().splitlines() if '=' in line)
    domain = client['FRP_CRM_DOMAIN']
    if not domain.endswith('.up.railway.app') or not all(char.isalnum() or char in '.-' for char in domain):
        raise ValueError('Unexpected public domain')
    result['public_crm'] = status('https://' + domain + '/')
    result['private_api'] = status('https://' + domain + '/api/v1/accounts/1/inboxes')
    env = dict(line.split('=', 1) for line in (vault / 'secrets/waha.env').read_text().splitlines() if '=' in line)
    request = urllib.request.Request('http://127.0.0.1:3003/api/sessions/default', headers={'X-Api-Key': env['WAHA_API_KEY']})
    with urllib.request.urlopen(request, timeout=4) as response:
        result['whatsapp'] = json.load(response).get('status', 'UNKNOWN')
except (OSError, ValueError, KeyError, TimeoutError):
    result['whatsapp'] = 'UNAVAILABLE'
result['healthy'] = (result['vault_mounted'] and result['vault_writable'] and result['containers_running'] and result.get('local_crm') == 200 and result.get('local_site') == 200 and
                     result.get('public_crm') == 200 and result.get('private_api') == 401 and
                     result.get('whatsapp') == 'WORKING')
print(json.dumps(result))
