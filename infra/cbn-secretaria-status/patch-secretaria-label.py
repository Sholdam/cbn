import json
from pathlib import Path

root = Path('/app/app/javascript/dashboard/i18n/locale/pt_BR')
changes = {
    'chatlist.json': [
        (['CHAT_LIST', 'CHAT_STATUS_FILTER_ITEMS', 'pending', 'TEXT'], 'Pendentes', 'Secretária'),
    ],
    'conversation.json': [
        (['CONVERSATION', 'RESOLVE_DROPDOWN', 'MARK_PENDING'], 'Deixar pendente', 'Enviar para Secretária'),
        (['CONVERSATION', 'CARD_CONTEXT_MENU', 'PENDING'], 'Deixar pendente', 'Enviar para Secretária'),
    ],
    'automation.json': [
        (['AUTOMATION', 'ACTIONS', 'PENDING_CONVERSATION'], 'Marcar conversa como pendente', 'Enviar conversa para Secretária'),
    ],
    'report.json': [
        (['OVERVIEW_REPORTS', 'ACCOUNT_CONVERSATIONS', 'PENDING'], 'Pendentes', 'Secretária'),
    ],
}
for name, replacements in changes.items():
    path = root / name
    data = json.loads(path.read_text())
    for keys, old, new in replacements:
        node = data
        for key in keys[:-1]:
            node = node[key]
        if node[keys[-1]] != old:
            raise RuntimeError('Unexpected translation at ' + name + ':' + '.'.join(keys))
        node[keys[-1]] = new
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

path = Path('/app/vite.config.ts')
source = path.read_text()
anchor = 'export default defineConfig({'
if 'build: { sourcemap: false }' not in source:
    if source.count(anchor) != 1:
        raise RuntimeError('Unexpected Vite config')
    path.write_text(source.replace(anchor, anchor + '\n  build: { sourcemap: false },', 1))
