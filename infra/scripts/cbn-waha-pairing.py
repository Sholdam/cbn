#!/usr/bin/env python3
"""Loopback-only QR view; credentials never enter the browser."""
import json
import pathlib
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

SECRET = pathlib.Path('/srv/cbn-production/secrets/waha.env')
env = dict(x.split('=', 1) for x in SECRET.read_text().splitlines() if '=' in x)
KEY = env['WAHA_API_KEY']

PAGE = '''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Conectar WhatsApp CBN</title>
<style>body{font:18px system-ui;background:#f6f7f8;color:#132a42;max-width:620px;margin:40px auto;padding:20px;text-align:center}img{width:min(90vw,400px);background:white;border-radius:12px}p{line-height:1.5}.hint{font-size:15px;color:#526170}</style>
<h1>Conectar WhatsApp CBN</h1>
<p>No celular do WhatsApp comercial, abra <b>Aparelhos conectados</b> e toque em <b>Conectar um aparelho</b>. Aponte a câmera para este código.</p>
<p id="status">Preparando código…</p><img id="qr" alt="QR Code para conectar o WhatsApp" hidden>
<p class="hint">O código se atualiza automaticamente. Mantenha esta página aberta até aparecer “Conectado”.</p>
<script>
const img=document.getElementById('qr'), statusEl=document.getElementById('status');
let lastQr=0,lastRenew=0,renews=0;
async function refresh(){try{const s=await fetch('/status',{cache:'no-store'}).then(r=>r.json());
if(s.status==='WORKING'){statusEl.textContent='Conectado. O WhatsApp já está pareado.';img.hidden=true;return;}
if(s.status==='FAILED'&&renews<10&&Date.now()-lastRenew>60000){lastRenew=Date.now();renews++;await fetch('/renew',{method:'POST'});statusEl.textContent='Renovando código…';img.hidden=true;}
else if(s.status==='SCAN_QR_CODE'){statusEl.textContent='Leia o QR Code com o celular.';img.hidden=false;if(Date.now()-lastQr>12000){img.src='/qr?t='+Date.now();lastQr=Date.now();}}
else{statusEl.textContent='Preparando conexão… ('+s.status+')';img.hidden=true;}}
catch(e){statusEl.textContent='Aguardando o serviço local…';}setTimeout(refresh,3000);}refresh();
</script></html>'''.encode()


def request(path, accept='application/json'):
    req = urllib.request.Request('http://127.0.0.1:3003' + path,
        headers={'X-Api-Key': KEY, 'Accept': accept})
    with urllib.request.urlopen(req, timeout=15) as response:
        return response.read()


class PairingView(BaseHTTPRequestHandler):
    last_renew = 0
    renew_count = 0
    def log_message(self, *_):
        pass

    def do_POST(self):
        if self.path != '/renew' or self.headers.get('Host') not in ('127.0.0.1:3004', 'localhost:3004') or \
                self.headers.get('Origin') not in ('http://127.0.0.1:3004', 'http://localhost:3004'):
            self.send_error(403)
            return
        try:
            state = json.loads(request('/api/sessions/default'))
            if state['status'] == 'FAILED' and time.monotonic() - self.last_renew > 60 and self.renew_count < 10:
                PairingView.last_renew = time.monotonic()
                PairingView.renew_count += 1
                req = urllib.request.Request('http://127.0.0.1:3003/api/sessions/default/restart',
                    data=b'{}', headers={'X-Api-Key': KEY, 'Content-Type': 'application/json'}, method='POST')
                with urllib.request.urlopen(req, timeout=30) as response:
                    response.read()
            self.send_response(204)
            self.end_headers()
        except urllib.error.URLError:
            self.send_error(503)

    def do_GET(self):
        if self.headers.get('Host') not in ('127.0.0.1:3004', 'localhost:3004') or \
                self.headers.get('Sec-Fetch-Site') == 'cross-site':
            self.send_error(403)
            return
        path = self.path.split('?', 1)[0]
        try:
            if path == '/':
                data, mime = PAGE, 'text/html; charset=utf-8'
            elif path == '/status':
                s = json.loads(request('/api/sessions/default'))
                data, mime = json.dumps({'status': s['status']}).encode(), 'application/json'
            elif path == '/qr':
                s = json.loads(request('/api/sessions/default'))
                if s['status'] != 'SCAN_QR_CODE':
                    self.send_error(409)
                    return
                data, mime = request('/api/default/auth/qr', 'image/png'), 'image/png'
            else:
                self.send_error(404)
                return
        except (urllib.error.URLError, KeyError):
            self.send_error(503)
            return
        self.send_response(200)
        self.send_header('Content-Type', mime)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Security-Policy', "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'")
        self.end_headers()
        self.wfile.write(data)


if __name__ == '__main__':
    print('pairing_view=http://127.0.0.1:3004/', flush=True)
    HTTPServer(('127.0.0.1', 3004), PairingView).serve_forever()
