#!/usr/bin/env python3
"""Provision the explicitly authorized local WAHA integration without logging secrets."""
import argparse
import json
import os
import pathlib
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = pathlib.Path('/srv/cbn-production')
SECRETS = ROOT / 'secrets'
STATE = SECRETS / 'waha-chatwoot.json'
WEB = 'cbn-railway-clone-chatwoot-web-1'


def private_write(path, data):
    tmp = path.with_suffix(path.suffix + '.tmp')
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write(data)
    os.replace(tmp, path)


def api(method, path, payload=None):
    env = dict(line.split('=', 1) for line in (SECRETS / 'waha.env').read_text().splitlines() if '=' in line)
    req = urllib.request.Request('http://127.0.0.1:3003' + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'X-Api-Key': env['WAHA_API_KEY'], 'Content-Type': 'application/json'}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        # Do not print the body: validators can echo accountToken.
        raise RuntimeError(f'WAHA {method} {path}: HTTP {error.code}') from None


def isolate():
    path = SECRETS / 'chatwoot-local.env'
    original = path.read_text()
    lines = original.splitlines()
    matches = [i for i, line in enumerate(lines) if line.startswith('REDIS_URL=')]
    if len(matches) != 1:
        raise RuntimeError('Expected exactly one Chatwoot REDIS_URL')
    index = matches[0]
    url = urllib.parse.urlsplit(lines[index].split('=', 1)[1])
    if url.path == '/1':
        if not path.with_name(path.name + '.pre-waha').exists():
            raise RuntimeError('Queue isolation has no original environment snapshot')
        print('chatwoot_redis_db=1 (already isolated)')
        return
    if url.path not in ('', '/', '/0'):
        raise RuntimeError('Unexpected original Redis database')
    redis_check = subprocess.run(['docker', 'exec', '-e',
        'REDISCLI_AUTH=' + urllib.parse.unquote(url.password or ''),
        'cbn-railway-clone-redis-1', 'redis-cli', '-n', '1', 'dbsize'],
        capture_output=True, text=True, check=True)
    if redis_check.stdout.strip() != '0':
        raise RuntimeError('Target Redis database 1 must be empty before first isolation')
    backup = path.with_name(path.name + '.pre-waha')
    if not backup.exists():
        shutil.copy2(path, backup)
        backup.chmod(0o600)
    lines[index] = 'REDIS_URL=' + urllib.parse.urlunsplit(url._replace(path='/1'))
    private_write(path, '\n'.join(lines) + '\n')
    print('chatwoot_redis_db=1; original DB 0 preserved')


def provision_chatwoot():
    if STATE.exists():
        state = json.loads(STATE.read_text())
        private_write(SECRETS / 'waha-chatwoot.env', 'CBN_WAHA_WEBHOOK_URL=' + state['webhookUrl'] + '\n')
        print('chatwoot_waha_config=already provisioned')
        return
    app_id = 'app_' + uuid.uuid4().hex
    webhook = 'http://waha:3000/webhooks/chatwoot/default/' + app_id
    ruby = r'''
Rails.logger.level = Logger::FATAL
raise 'Runtime queue not isolated' unless URI(ENV.fetch('REDIS_URL')).path == '/1'
account = Account.find(1)
raise 'Integration user already exists without state snapshot' if User.exists?(email: 'waha-integration@cbn.invalid')
result = ActiveRecord::Base.transaction do
  disabled = account.automation_rules.where(active: true).pluck(:id)
  account.automation_rules.where(id: disabled).update_all(active: false)
  user = User.new(email: 'waha-integration@cbn.invalid', name: 'Integração WAHA', password: 'Aa!1' + SecureRandom.hex(32))
  user.skip_confirmation!
  user.save!
  AccountUser.create!(account: account, user: user, role: :agent, availability: :offline)
  channel = Channel::Api.create!(account: account, webhook_url: WEBHOOK_VALUE, additional_attributes: {})
  inbox = Inbox.create!(account: account, channel: channel, name: 'CBN WhatsApp (WAHA)',
    enable_auto_assignment: false, greeting_enabled: false, enable_email_collect: false,
    csat_survey_enabled: false, lock_to_single_conversation: true)
  account.users.each { |member| InboxMember.find_or_create_by!(inbox: inbox, user: member) }
  { accountId: account.id, accountToken: user.access_token.token,
    userId: user.id, inboxId: inbox.id, inboxIdentifier: channel.identifier,
    disabledAutomationRuleIds: disabled }
end
puts 'CBN_WAHA_CONFIG=' + result.to_json
'''.replace('WEBHOOK_VALUE', json.dumps(webhook))
    process = subprocess.run(['docker', 'exec', '-i', WEB, 'bundle', 'exec', 'rails', 'runner', '-'],
        input=ruby, capture_output=True, text=True, timeout=120)
    if process.returncode:
        # Only error class/message, no raw Rails output or credentials.
        errors = [line for line in process.stderr.splitlines() if '(ActiveRecord::' in line or '(RuntimeError)' in line]
        raise RuntimeError('Chatwoot provisioning failed: ' + ('; '.join(errors[:2]) or str(process.returncode)))
    marked = [line[len('CBN_WAHA_CONFIG='):] for line in process.stdout.splitlines() if line.startswith('CBN_WAHA_CONFIG=')]
    if len(marked) != 1:
        raise RuntimeError('Chatwoot provisioning did not return its state marker')
    state = json.loads(marked[0])
    state.update(appId=app_id, session='default', webhookUrl=webhook)
    private_write(STATE, json.dumps(state, indent=2) + '\n')
    private_write(SECRETS / 'waha-chatwoot.env', 'CBN_WAHA_WEBHOOK_URL=' + state['webhookUrl'] + '\n')
    print(f'chatwoot_inbox_id={state["inboxId"]}; service_agent_created=true; automations_paused={len(state["disabledAutomationRuleIds"])}')


def provision_app():
    state = json.loads(STATE.read_text())
    sessions = api('GET', '/api/sessions?all=true')
    if not any(s['name'] == state['session'] for s in sessions):
        api('POST', '/api/sessions', {'name': state['session'], 'start': False,
            'config': {'ignore': {'groups': True, 'status': True, 'channels': True}}})
    apps = api('GET', '/api/apps?session=default')
    if not any(a['id'] == state['appId'] for a in apps):
        # WAHA initial attribute definitions require admin permissions. Restore
        # agent immediately afterwards; normal message processing uses agent.
        def set_role(role):
            ruby = f"Rails.logger.level = Logger::FATAL; AccountUser.find_by!(account_id: 1, user_id: {int(state['userId'])}).update!(role: :{role})"
            p = subprocess.run(['docker', 'exec', '-i', WEB, 'bundle', 'exec', 'rails', 'runner', '-'],
                input=ruby, capture_output=True, text=True, timeout=120)
            if p.returncode:
                raise RuntimeError('Could not set WAHA setup role: ' + role)
        set_role('administrator')
        try:
            api('POST', '/api/apps', {'id': state['appId'], 'session': state['session'],
            'app': 'chatwoot', 'enabled': True, 'config': {
                'url': 'http://chatwoot-web:3000', 'accountId': state['accountId'],
                'accountToken': state['accountToken'], 'inboxId': state['inboxId'],
                'inboxIdentifier': state['inboxIdentifier'], 'locale': 'pt-BR',
                'linkPreview': 'OFF', 'templates': {}, 'commands': {'server': True, 'queue': False},
                'conversations': {'sort': 'created_newest', 'status': [], 'markAsRead': False,
                    'syncMessageStatus': True, 'outgoing': 'private-note'}}})
        finally:
            set_role('agent')
    print(f'waha_app=chatwoot; inbox_id={state["inboxId"]}; session=default')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['isolate', 'chatwoot', 'app'])
    args = parser.parse_args()
    mounted = subprocess.run(['findmnt', '-n', '-o', 'SOURCE', '--target', str(ROOT)], capture_output=True, text=True)
    if mounted.stdout.strip() != '/dev/mapper/cbn_production':
        raise SystemExit('Encrypted CBN volume must be mounted')
    {'isolate': isolate, 'chatwoot': provision_chatwoot, 'app': provision_app}[args.stage]()
