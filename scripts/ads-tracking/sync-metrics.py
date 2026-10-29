"""Fixed-account Windsor sync. Never print credentials or remote error bodies."""
import datetime as dt
import json
import os
import pathlib
import urllib.parse
import urllib.request
from tracking import DATA, open_db, import_metrics


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs): return None


def status(value):
    temporary=DATA/'metrics-status.tmp'
    temporary.write_text(json.dumps(value))
    os.chmod(temporary,0o640)
    temporary.replace(DATA/'metrics-status.json')


def main():
    credential=DATA/'credentials'/'windsor.json'
    if not credential.exists(): status({'status':'requires_key'}); return
    now=dt.datetime.now(dt.timezone.utc)
    previous=DATA/'metrics-status.json'
    old=json.loads(previous.read_text()) if previous.exists() else {}
    # A saved replacement credential retries promptly; regular pulls are daily.
    if old.get('status')=='ok' and credential.stat().st_mtime < dt.datetime.fromisoformat(old['updated_at']).timestamp() and (now-dt.datetime.fromisoformat(old['updated_at'])).total_seconds()<86400: return
    if old.get('status')=='error' and max(credential.stat().st_mtime,pathlib.Path(__file__).stat().st_mtime) < dt.datetime.fromisoformat(old['attempted_at']).timestamp() and (now-dt.datetime.fromisoformat(old['attempted_at'])).total_seconds()<3600: return
    today=now.astimezone(dt.timezone(dt.timedelta(hours=-3))).date()
    start=(today-dt.timedelta(days=29)).isoformat()
    try:
        key=json.loads(credential.read_text())['api_key']
        params={'api_key':key,'date_from':start,'date_to':today.isoformat(),
                'select_accounts':'464902005511455',
                'fields':'date,account_id,account_name,campaign_id,campaign,adset_id,adset_name,ad_id,ad_name,spend,clicks,impressions,currency'}
        request=urllib.request.Request('https://connectors.windsor.ai/facebook?'+urllib.parse.urlencode(params))
        with urllib.request.build_opener(NoRedirect()).open(request,timeout=90) as response:
            raw=response.read(10_000_001)
        if len(raw)>10_000_000: raise ValueError()
        result=json.loads(raw)
        rows=result['data'] if isinstance(result,dict) else result
        if not isinstance(rows,list): raise ValueError()
        # Do not accidentally import other accounts if the upstream ignores selection.
        if any(str(row.get('account_id'))!='464902005511455' for row in rows): raise ValueError()
        conn=open_db(); count=import_metrics(conn,{'period':{'from':start,'to':today.isoformat()},'data':rows}); conn.close()
        status({'status':'ok','updated_at':now.isoformat(),'rows':count,'frequency':'daily','account_id':'464902005511455'})
    except Exception:
        status({'status':'error','attempted_at':now.isoformat(),'updated_at':old.get('updated_at'),
                'message':'Windsor não concluiu a consulta. Confira chave, conexão da conta e limite do plano.'})


if __name__=='__main__': main()
