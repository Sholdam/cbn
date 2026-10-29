"""First installation on the existing CBN VPS. Run from /opt/cbn/ads-tracking.

Requires explicit production authorization. Never restarts CRM or WAHA.
"""
import datetime as dt
import argparse
import grp
import json
import os
import pathlib
import pwd
import subprocess
import sys
import socket
import http.client

ROOT=pathlib.Path('/opt/cbn/ads-tracking')
DATA=pathlib.Path('/srv/cbn-production/ads-tracking')
USER='cbn-ads'


def run(args,timeout=60):
    result=subprocess.run(args,capture_output=True,text=True,timeout=timeout)
    if result.returncode: raise RuntimeError('Failed operation: '+args[0]+' (details withheld)')
    return result.stdout.strip()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--resume',action='store_true');args=parser.parse_args()
    os.umask(0o027)
    if os.getuid()!=0 or pathlib.Path(__file__).resolve().parent!=ROOT:raise RuntimeError('Wrong installation context')
    if pathlib.Path('/etc/systemd/system/cbn-ads-report.service').exists() and not args.resume:raise RuntimeError('Already installed; follow update runbook')
    run(['python3','-m','unittest','discover','-s',str(ROOT),'-p','test_tracking.py'])
    try:pwd.getpwnam(USER)
    except KeyError:run(['useradd','--system','--user-group','--no-create-home','--shell','/usr/sbin/nologin',USER])
    uid,gid=pwd.getpwnam(USER).pw_uid,grp.getgrnam(USER).gr_gid
    DATA.mkdir(mode=0o750,parents=True,exist_ok=True);os.chown(DATA,0,gid);os.chmod(DATA,0o750)
    credentials=DATA/'credentials';credentials.mkdir(mode=0o700,exist_ok=True);os.chown(credentials,uid,gid)
    backup=DATA/'installation-backup';backup.mkdir(mode=0o700,exist_ok=True)
    sys.path.insert(0,str(ROOT));import tracking
    # Back up only the additive namespace; never copy customer message contents.
    sql="SELECT coalesce(json_agg(x),'[]'::json)::text FROM (SELECT c.id,(SELECT coalesce(jsonb_object_agg(key,value),'{}'::jsonb) FROM jsonb_each(coalesce(c.custom_attributes,'{}'::jsonb)) WHERE key LIKE 'cbn_ads_%') AS tracking_attributes FROM conversations c WHERE account_id=1 AND inbox_id=5) x"
    if not (backup/'conversation-ads-attributes.json').exists():(backup/'conversation-ads-attributes.json').write_text(tracking.psql(sql))
    run(['docker','cp',str(ROOT/'setup-fields.rb'),'cbn-railway-clone-chatwoot-web-1:/tmp/cbn-ads-setup.rb'])
    fields=run(['docker','exec','cbn-railway-clone-chatwoot-web-1','bundle','exec','rails','runner','/tmp/cbn-ads-setup.rb'],timeout=120)
    print(fields.splitlines()[-1])
    conn=tracking.open_db(DATA)
    tracking.put_catalog(conn,json.loads((ROOT/'catalog.json').read_text()))
    seed=ROOT/'initial-metrics.json'
    if seed.exists():
        tracking.import_metrics(conn,json.loads(seed.read_text(encoding='utf-8-sig')))
        seed.unlink() # Kept only in the private aggregate database.
    for _ in range(100):
        before=(conn.execute("SELECT value FROM state WHERE key='cursor'").fetchone() or ['0'])[0]
        tracking.capture(conn)
        after=conn.execute("SELECT value FROM state WHERE key='cursor'").fetchone()[0]
        if str(before)==str(after):break
    projected=tracking.projections(conn)
    conn.execute("INSERT INTO state VALUES('last_capture',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",(dt.datetime.now(dt.timezone.utc).isoformat(),));conn.commit();conn.close()
    for file in DATA.iterdir():
        if file.is_file():os.chown(file,0,gid);os.chmod(file,0o640)
    for file in ROOT.rglob('*'):
        if file.is_file():os.chmod(file,0o644)
        elif file.is_dir():os.chmod(file,0o755)
    report_service='''[Unit]
Description=CBN private ad attribution report
After=network-online.target
[Service]
User=cbn-ads
Group=cbn-ads
RuntimeDirectory=cbn-ads-report
RuntimeDirectoryMode=0750
RuntimeDirectoryPreserve=yes
BindReadOnlyPaths=/opt/cbn/ads-tracking:/run/cbn-ads-report/app
BindReadOnlyPaths=/srv/cbn-production/ads-tracking:/run/cbn-ads-report/data
BindPaths=/srv/cbn-production/ads-tracking/credentials:/run/cbn-ads-report/data/credentials
WorkingDirectory=/run/cbn-ads-report/app
Environment=CBN_ADS_DATA=/run/cbn-ads-report/data
ExecStart=/usr/bin/python3 /run/cbn-ads-report/app/server.py
Restart=on-failure
UMask=0027
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/run/cbn-ads-report/data/credentials
RestrictAddressFamilies=AF_UNIX
[Install]
WantedBy=multi-user.target
'''
    capture_service='''[Unit]
Description=CBN incoming ad metadata capture and daily Meta metrics
After=docker.service network-online.target
[Service]
Type=oneshot
User=root
Group=cbn-ads
WorkingDirectory=/opt/cbn/ads-tracking
ExecStart=/usr/bin/python3 /opt/cbn/ads-tracking/tracking.py sync
ExecStartPost=/usr/bin/python3 /opt/cbn/ads-tracking/sync-metrics.py
UMask=0027
TimeoutStartSec=300
'''
    capture_timer='''[Unit]
Description=Refresh CBN ad attribution every five minutes
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=10s
Persistent=true
[Install]
WantedBy=timers.target
'''
    for name,text in [('cbn-ads-report.service',report_service),('cbn-ads-capture.service',capture_service),('cbn-ads-capture.timer',capture_timer)]:
        pathlib.Path('/etc/systemd/system',name).write_text(text)
    run(['systemctl','daemon-reload'])
    run(['systemctl','reset-failed','cbn-ads-report.service'])
    run(['systemctl','enable','--now','cbn-ads-report.service'])
    # Only the private Unix socket is exposed to the owner-gated portal backend.
    import time
    for attempt in range(20):
        if pathlib.Path('/run/cbn-ads-report/report.sock').exists(): break
        if attempt==19: raise RuntimeError('Private report socket did not start')
        time.sleep(.25)
    connection=http.client.HTTPConnection('localhost')
    connection.sock=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
    connection.sock.connect('/run/cbn-ads-report/report.sock')
    connection.request('GET','/ads-tracking/api/report')
    response=connection.getresponse();response.read();assert response.status==200
    connection.close()
    run(['systemctl','start','cbn-ads-capture.service'],timeout=300)
    run(['systemctl','enable','--now','cbn-ads-capture.timer'])
    print(json.dumps({'installed':True,'conversations_projected':projected,'url':'https://cbncredito.tech/area/crm/anuncios/',
      'capture_timer':run(['systemctl','is-active','cbn-ads-capture.timer']),
      'report_service':run(['systemctl','is-active','cbn-ads-report.service'])}))


if __name__=='__main__':main()
