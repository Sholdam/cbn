"""CBN ad attribution. No message sends, personal contents, or Meta credentials."""
import argparse
import datetime as dt
import decimal
try:
    import fcntl
except ImportError:  # Windows synthetic tests; the VPS uses flock.
    fcntl = None
import json
import os
import pathlib
import re
import sqlite3
import subprocess

ACCOUNT = 1
INBOX = 5
STAGES = ('Novo contato', 'Em atendimento', 'Proposta enviada', 'Contratado', 'Perdido')
ID = re.compile(r'^[0-9]{10,25}$')
DATA = pathlib.Path(os.environ.get('CBN_ADS_DATA','/srv/cbn-production/ads-tracking'))
DB_CONTAINER = 'cbn-railway-clone-postgres-physical-1'


def ad_id_from_envelope(content):
    """For synthetic tests. Production extracts only the header inside PostgreSQL."""
    text = str(content or '').strip()
    if not re.match(r'^[^\r\n]*AN[ÚU]NCIO DO FACEBOOK', text, re.I):
        return None
    header = re.split(r'MENSAGEM DO CLIENTE', text, maxsplit=1, flags=re.I)[0]
    found = re.search(r'ID do An[úu]ncio:\*{0,2}\s*([0-9]{10,25})(?![0-9])', header, re.I)
    return found[1] if found else None


def amount(value):
    if value is None or isinstance(value, bool) or value == '':
        return None
    try:
        result = decimal.Decimal(str(value))
        if not result.is_finite() or result < 0 or result > 100_000_000:
            return None
        return float(result.quantize(decimal.Decimal('.01')))
    except decimal.InvalidOperation:
        return None


def open_db(folder=DATA):
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    conn = sqlite3.connect(folder / 'attribution.sqlite', timeout=20)
    conn.row_factory = sqlite3.Row
    conn.executescript('''
      PRAGMA journal_mode=DELETE;
      CREATE TABLE IF NOT EXISTS state(key TEXT PRIMARY KEY,value TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS touches(
        conversation_id INTEGER NOT NULL,contact_id INTEGER NOT NULL,ad_id TEXT NOT NULL,
        first_message_id INTEGER NOT NULL,last_message_id INTEGER NOT NULL,
        first_at TEXT NOT NULL,last_at TEXT NOT NULL,
        PRIMARY KEY(conversation_id,ad_id));
      CREATE TABLE IF NOT EXISTS catalog(ad_id TEXT PRIMARY KEY,data TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS metrics(
        account_id TEXT NOT NULL,ad_id TEXT NOT NULL,date TEXT NOT NULL,currency TEXT NOT NULL,
        spend REAL NOT NULL,clicks INTEGER NOT NULL,impressions INTEGER NOT NULL,
        PRIMARY KEY(account_id,ad_id,date));
      CREATE TABLE IF NOT EXISTS imports(account_id TEXT PRIMARY KEY,from_date TEXT NOT NULL,to_date TEXT NOT NULL,at TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outcomes(
        conversation_id INTEGER PRIMARY KEY,ad_id TEXT,stage TEXT NOT NULL,
        contracted REAL,commission REAL,observed_at TEXT NOT NULL);
    ''')
    return conn


def put_catalog(conn, rows):
    for item in rows:
        if not ID.fullmatch(str(item['ad_id'])):
            raise ValueError('Invalid ad ID')
        conn.execute('INSERT INTO catalog VALUES(?,?) ON CONFLICT(ad_id) DO UPDATE SET data=excluded.data',
                     (str(item['ad_id']), json.dumps(item, ensure_ascii=False)))


def import_metrics(conn, payload):
    start, end = payload['period']['from'], payload['period']['to']
    dt.date.fromisoformat(start); dt.date.fromisoformat(end)
    if start > end: raise ValueError('Invalid period')
    valid = []
    for r in payload['data']:
        account, ad, date = str(r['account_id']), str(r['ad_id']), r['date']
        if account not in ('997994236391969', '464902005511455') or not ID.fullmatch(ad):
            raise ValueError('Account or ad not allowed')
        dt.date.fromisoformat(date)
        if not start <= date <= end or r['currency'] != 'BRL': raise ValueError('Invalid metric date or currency')
        spend = amount(r['spend'])
        clicks, impressions = r['clicks'], r['impressions']
        if spend is None or any(isinstance(v, bool) or not isinstance(v, (int,float)) or v < 0 or int(v) != v for v in (clicks, impressions)):
            raise ValueError('Invalid metric value')
        valid.append((account, ad, date, 'BRL', spend, int(clicks), int(impressions)))
    # Sparse exports do not prove zero spend on missing rows or on unpublished ads.
    for r in payload['data']:
        existing = conn.execute('SELECT data FROM catalog WHERE ad_id=?', (str(r['ad_id']),)).fetchone()
        item = json.loads(existing[0]) if existing else {}
        item.update({k:r[k] for k in ('ad_id','account_id','campaign_id','campaign','adset_id','adset_name','ad_name') if k in r})
        put_catalog(conn, [item])
    conn.executemany('INSERT INTO metrics VALUES(?,?,?,?,?,?,?) ON CONFLICT(account_id,ad_id,date) DO UPDATE SET currency=excluded.currency,spend=excluded.spend,clicks=excluded.clicks,impressions=excluded.impressions', valid)
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    for account in {x[0] for x in valid}:
        conn.execute('INSERT INTO imports VALUES(?,?,?,?) ON CONFLICT(account_id) DO UPDATE SET from_date=excluded.from_date,to_date=excluded.to_date,at=excluded.at', (account,start,end,now))
    conn.commit()
    return len(valid)


def psql(sql):
    result = subprocess.run(['docker','exec',DB_CONTAINER,'psql','-U','postgres','-d','railway','-At','-v','ON_ERROR_STOP=1','-c',sql],
                            capture_output=True, text=True, timeout=35)
    if result.returncode:
        raise RuntimeError('CRM database operation failed; customer data omitted')
    return result.stdout.strip()


def capture(conn):
    cursor = int((conn.execute("SELECT value FROM state WHERE key='cursor'").fetchone() or ['0'])[0])
    # Customer sections never leave PostgreSQL. Only IDs and times are returned.
    sql = f'''WITH batch AS (
       SELECT m.id,m.conversation_id,c.contact_id,m.created_at,m.content
       FROM messages m JOIN conversations c ON c.id=m.conversation_id
       WHERE m.account_id=1 AND m.inbox_id=5 AND c.account_id=1 AND m.message_type=0
         AND NOT m.private AND m.sender_type='Contact' AND m.id>{cursor}
       ORDER BY m.id LIMIT 1000), extracted AS (
       SELECT id,conversation_id,contact_id,created_at,
       CASE WHEN btrim(content) ~* '^[^\r\n]*AN[ÚU]NCIO DO FACEBOOK' THEN
       substring((regexp_split_to_array(content,'MENSAGEM DO CLIENTE','i'))[1]
         from '(?i)ID do An[úu]ncio:[*]{{0,2}}[[:space:]]*([0-9]{{10,25}})(?:[^0-9]|$)') END AS ad_id
       FROM batch)
       SELECT json_build_object('cursor',coalesce((SELECT max(id) FROM batch),{cursor}),
       'rows',coalesce((SELECT json_agg(x) FROM (SELECT id,conversation_id,contact_id,created_at,ad_id
       FROM extracted WHERE ad_id IS NOT NULL ORDER BY id) x),'[]'::json))::text'''
    batch = json.loads(psql(sql))
    with conn:
        for row in batch['rows']:
            conn.execute('''INSERT INTO touches VALUES(?,?,?,?,?,?,?) ON CONFLICT(conversation_id,ad_id)
                DO UPDATE SET first_message_id=min(first_message_id,excluded.first_message_id),
                last_message_id=max(last_message_id,excluded.last_message_id),
                first_at=min(first_at,excluded.first_at),last_at=max(last_at,excluded.last_at)''',
                (row['conversation_id'],row['contact_id'],row['ad_id'],row['id'],row['id'],row['created_at'],row['created_at']))
        conn.execute("INSERT INTO state VALUES('cursor',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (str(batch['cursor']),))
    return len(batch['rows'])


def projections(conn):
    catalog = {r['ad_id']:json.loads(r['data']) for r in conn.execute('SELECT * FROM catalog')}
    rows = conn.execute('SELECT * FROM touches ORDER BY first_message_id').fetchall()
    grouped = {}
    for r in rows: grouped.setdefault(r['conversation_id'], []).append(r)
    for conversation_id, touches in grouped.items():
        first = min(touches,key=lambda r:r['first_message_id'])
        last = max(touches,key=lambda r:r['last_message_id'])
        meta = catalog.get(last['ad_id'],{})
        attrs = {'cbn_ads_primeiro_anuncio_id':first['ad_id'],'cbn_ads_ultimo_anuncio_id':last['ad_id'],
                 'cbn_ads_campanha':meta.get('campaign','Não identificado'),
                 'cbn_ads_conjunto':meta.get('adset_name','Não identificado'),
                 'cbn_ads_anuncio':meta.get('ad_name','Anúncio '+last['ad_id']),
                 'cbn_ads_modalidade':meta.get('modality','Não identificada')}
        # Hex encoding makes SQL values inert, including arbitrary advertiser names.
        encoded = json.dumps(attrs,ensure_ascii=False).encode().hex()
        psql(f"UPDATE conversations SET custom_attributes=coalesce(custom_attributes,'{{}}'::jsonb)||convert_from(decode('{encoded}','hex'),'UTF8')::jsonb WHERE id={int(conversation_id)} AND account_id=1 AND inbox_id=5 AND NOT coalesce(custom_attributes,'{{}}'::jsonb) @> convert_from(decode('{encoded}','hex'),'UTF8')::jsonb")
    ids = ','.join(str(int(i)) for i in grouped)
    if not ids: return 0
    outcome_rows=json.loads(psql(f"SELECT coalesce(json_agg(x),'[]'::json)::text FROM (SELECT id,custom_attributes->>'cbn_ads_etapa' AS stage,custom_attributes->>'cbn_ads_valor_contratado' AS contracted,custom_attributes->>'cbn_ads_comissao' AS commission FROM conversations WHERE account_id=1 AND inbox_id=5 AND id IN ({ids})) x"))
    for r in outcome_rows:
        stage=r['stage'] if r['stage'] in STAGES else 'Não informado'
        existing=conn.execute('SELECT * FROM outcomes WHERE conversation_id=?',(r['id'],)).fetchone()
        # Freeze the sale's attribution so a later ad message does not move it.
        selected=existing['ad_id'] if existing and existing['stage']=='Contratado' and stage=='Contratado' else max(grouped[r['id']],key=lambda x:x['last_message_id'])['ad_id']
        conn.execute('INSERT INTO outcomes VALUES(?,?,?,?,?,?) ON CONFLICT(conversation_id) DO UPDATE SET ad_id=excluded.ad_id,stage=excluded.stage,contracted=excluded.contracted,commission=excluded.commission,observed_at=excluded.observed_at',
            (r['id'],selected,stage,amount(r['contracted']),amount(r['commission']),dt.datetime.now(dt.timezone.utc).isoformat()))
    conn.commit()
    return len(grouped)


def report(conn, start=None, end=None):
    start = start or '2000-01-01'; end = end or dt.date.today().isoformat()
    dt.date.fromisoformat(start); dt.date.fromisoformat(end)
    if start > end: raise ValueError('Invalid period')
    catalog={r['ad_id']:json.loads(r['data']) for r in conn.execute('SELECT * FROM catalog')}
    rows={}
    def base(ad):
        if ad not in rows:
            meta=catalog.get(ad,{})
            rows[ad]={**meta,'ad_id':ad,'ad_name':meta.get('ad_name','Anúncio '+ad),
                'contacts':0,'conversations':0,'proposals':0,'contracts':0,'stage_missing':0,'commission':None,'commission_missing':0,
                'contracted':None,'spend':None,'clicks':None,'impressions':None,'cost_per_contact':None,
                'cost_per_contract':None,'commission_less_spend':None}
        return rows[ad]
    for ad in catalog: base(ad)
    cohort={}
    for r in conn.execute('SELECT * FROM touches'):
        # Meta dates use the ad account's America/Sao_Paulo calendar.
        timestamp=dt.datetime.fromisoformat(r['first_at'].replace('Z','+00:00'))
        if timestamp.tzinfo is None: timestamp=timestamp.replace(tzinfo=dt.timezone.utc)
        date=timestamp.astimezone(dt.timezone(dt.timedelta(hours=-3))).date().isoformat()
        if start<=date<=end: cohort.setdefault(r['ad_id'], []).append(r)
    for ad,touches in cohort.items():
        out=base(ad); out['contacts']=len({r['contact_id'] for r in touches}); out['conversations']=len({r['conversation_id'] for r in touches})
    for r in conn.execute('SELECT ad_id,sum(spend) spend,sum(clicks) clicks,sum(impressions) impressions FROM metrics WHERE date BETWEEN ? AND ? GROUP BY ad_id',(start,end)):
        base(r['ad_id']).update({k:round(r[k],2) for k in ('spend','clicks','impressions')})
    # Outcome attribution belongs to the chosen ad's contact cohort, not every ad touched.
    for r in conn.execute('SELECT * FROM outcomes'):
        ad=r['ad_id']; valid={t['conversation_id'] for t in cohort.get(ad,[])}
        if r['conversation_id'] not in valid: continue
        out=base(ad)
        if r['stage']=='Não informado': out['stage_missing']+=1
        if r['stage']=='Proposta enviada': out['proposals']+=1
        if r['stage']=='Contratado':
            out['contracts']+=1
            if r['commission'] is None: out['commission_missing']+=1
            for field in ('commission','contracted'):
                if r[field] is not None: out[field]=round((out[field] or 0)+r[field],2)
    for row in rows.values():
        if row['commission_missing']: row['commission']=None
        if row['spend'] is not None:
            for key,denominator in [('cost_per_contact','contacts'),('cost_per_contract','contracts')]:
                if row[denominator]: row[key]=round(row['spend']/row[denominator],2)
            if row['commission'] is not None: row['commission_less_spend']=round(row['commission']-row['spend'],2)
    return {'period':{'from':start,'to':end},'imports':[dict(r) for r in conn.execute('SELECT * FROM imports')],
            'last_capture':(conn.execute("SELECT value FROM state WHERE key='last_capture'").fetchone() or [None])[0],
            'rows':list(rows.values()),'notes':['Contatos únicos por anúncio; a mesma pessoa pode aparecer em anúncios diferentes.',
              'Propostas e contratos dependem da etapa informada pela equipe. Não informado não significa zero.',
              'Valores ausentes da Meta são exibidos como não disponíveis, sem inferir gasto zero.',
              'Resultados comerciais são associados à coorte de entrada; não são a atribuição oficial da Meta.']}


def main():
    p=argparse.ArgumentParser(); p.add_argument('mode',choices=['sync','import','report']); p.add_argument('--file'); p.add_argument('--data',type=pathlib.Path,default=DATA); a=p.parse_args()
    a.data.mkdir(mode=0o700,parents=True,exist_ok=True)
    with (a.data/'sync.lock').open('a') as lock:
        try:
            if fcntl: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError: return
        conn=open_db(a.data)
        if a.mode=='import': print(json.dumps({'rows':import_metrics(conn,json.loads(pathlib.Path(a.file).read_text(encoding='utf-8-sig')))}))
        elif a.mode=='report': print(json.dumps(report(conn),ensure_ascii=False))
        else:
            put_catalog(conn,json.loads((pathlib.Path(__file__).parent/'catalog.json').read_text()))
            captured=capture(conn); projected=projections(conn)
            conn.execute("INSERT INTO state VALUES('last_capture',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",(dt.datetime.now(dt.timezone.utc).isoformat(),)); conn.commit()
            print(json.dumps({'captured':captured,'conversations':projected,'cursor':(conn.execute("SELECT value FROM state WHERE key='cursor'").fetchone() or [0])[0]}))


if __name__=='__main__': main()
