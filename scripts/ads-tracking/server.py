"""Private aggregate API. The collaborator portal authenticates and authorizes owners."""
import datetime as dt
import http.server
import json
import os
import pathlib
import sqlite3
import socketserver
import urllib.parse

from tracking import DATA, report

ORIGIN = 'https://cbncredito.tech'


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = 'CBN'

    def log_message(self, *args):
        pass  # No credential, query-string, or request-body logs.

    def reply(self, code, body, kind='application/json', headers=None):
        data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', kind + '; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        self.end_headers(); self.wfile.write(data)

    def authorized(self):
        # Only the portal's owner-gated backend can reach the private Unix socket.
        if getattr(self.server,'trusted_unix',False): return {}
        self.reply(401, {'error':'Acesso disponível somente pelo portal do colaborador.'})
        return None

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != '/ads-tracking/api/report': self.reply(404, {'error':'Não encontrado'}); return
        rotated = self.authorized()
        if rotated is None: return
        query = urllib.parse.parse_qs(parsed.query)
        today = dt.datetime.now(dt.timezone(dt.timedelta(hours=-3))).date()
        start, end = query.get('from',[today.replace(day=1).isoformat()])[0], query.get('to',[today.isoformat()])[0]
        try:
            if len(start) != 10 or len(end) != 10: raise ValueError()
            conn = sqlite3.connect(f'file:{DATA}/attribution.sqlite?mode=ro', uri=True, timeout=10)
            conn.row_factory = sqlite3.Row
            try:
                conn.execute('BEGIN')
                with conn: result = report(conn, start, end)
            finally: conn.close()
            result['metrics_sync'] = json.loads((DATA/'metrics-status.json').read_text()) if (DATA/'metrics-status.json').exists() else {'status':'requires_key'}
            self.reply(200, result, headers=rotated)
        except ValueError:
            self.reply(400, {'error':'Período inválido.'}, headers=rotated)
        except Exception:
            self.reply(503, {'error':'Base temporariamente indisponível.'}, headers=rotated)

    def do_POST(self):
        if self.path != '/ads-tracking/api/config': self.reply(404, {'error':'Não encontrado'}); return
        if self.headers.get('Origin') != ORIGIN or self.headers.get('Content-Type','').split(';')[0] != 'application/json':
            self.reply(403, {'error':'Origem não autorizada.'}); return
        rotated = self.authorized()
        if rotated is None: return
        try:
            size = int(self.headers.get('Content-Length','0'))
            if not 0 < size <= 2048: raise ValueError()
            payload = json.loads(self.rfile.read(size))
            key = payload.get('api_key','').strip()
            if not 12 <= len(key) <= 512 or not key.isascii() or any(c.isspace() for c in key): raise ValueError()
            # Only the integration credential is persisted; CRM session credentials never are.
            path = DATA/'credentials'/'windsor.json'
            temporary = path.with_suffix('.tmp')
            fd = os.open(temporary, os.O_WRONLY|os.O_CREAT|os.O_TRUNC, 0o600)
            with os.fdopen(fd,'w') as file: json.dump({'api_key':key},file)
            os.replace(temporary,path)
            self.reply(200, {'saved':True,'message':'Chave salva. A validação e a primeira atualização ocorrem em até 5 minutos.'}, headers=rotated)
        except Exception:
            self.reply(400, {'error':'Não foi possível salvar. Confira o valor da chave.'}, headers=rotated)


class UnixReportServer(socketserver.ThreadingMixIn, getattr(socketserver,'UnixStreamServer',socketserver.TCPServer)):
    trusted_unix = hasattr(socketserver,'UnixStreamServer')
    daemon_threads = True


if __name__ == '__main__':
    if not hasattr(socketserver,'UnixStreamServer'): raise RuntimeError('Private Unix socket required')
    socket=pathlib.Path('/run/cbn-ads-report/report.sock')
    socket.unlink(missing_ok=True)
    server=UnixReportServer(str(socket),Handler)
    os.chmod(socket,0o660)
    server.serve_forever()
