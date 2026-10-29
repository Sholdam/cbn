import datetime as dt
import json
import pathlib
import tempfile
import unittest
import http.client
import http.server
import threading
from unittest.mock import patch
import tracking as t
from server import Handler

AD='123456789012345678'
OTHER='223456789012345678'


class TrackingTest(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.db=t.open_db(pathlib.Path(self.folder.name))
    def tearDown(self):
        self.db.close(); self.folder.cleanup()
    def touch(self,conversation=1,contact=10,ad=AD,message=1,when='2026-10-28T12:00:00Z'):
        self.db.execute('INSERT INTO touches VALUES(?,?,?,?,?,?,?)',(conversation,contact,ad,message,message,when,when));self.db.commit()
    def payload(self,**changes):
        row={'account_id':'464902005511455','ad_id':AD,'date':'2026-10-28','currency':'BRL','spend':30,'clicks':12,'impressions':100}
        row.update(changes)
        return {'period':{'from':'2026-10-01','to':'2026-10-29'},'data':[row]}
    def outcome(self,conversation,ad,stage,contracted=None,commission=None):
        self.db.execute('INSERT INTO outcomes VALUES(?,?,?,?,?,?)',(conversation,ad,stage,contracted,commission,'2026-10-29'));self.db.commit()
    def row(self,ad=AD):
        return next(r for r in t.report(self.db,'2026-10-01','2026-10-29')['rows'] if r['ad_id']==ad)
    def test_envelope_and_string_precision(self):
        self.assertEqual(t.ad_id_from_envelope('📢 ANÚNCIO DO FACEBOOK\n**ID do Anúncio:** '+AD+'\nMENSAGEM DO CLIENTE: oi'),AD)
        self.assertIsNone(t.ad_id_from_envelope('MENSAGEM DO CLIENTE: ID do Anúncio: '+AD))
        self.assertIsNone(t.ad_id_from_envelope('ANÚNCIO DO FACEBOOK\nMENSAGEM DO CLIENTE: ID do Anúncio: '+AD))
    def test_invalid_or_negative_money(self):
        for value in (True,'NaN','Infinity',-1,'1.000,00',''): self.assertIsNone(t.amount(value))
        self.assertEqual(t.amount('20.96'),20.96)
    def test_import_idempotence_and_missing_not_zero(self):
        t.import_metrics(self.db,self.payload());t.import_metrics(self.db,self.payload())
        self.assertEqual(self.row()['spend'],30)
        self.assertEqual(self.db.execute('SELECT count(*) FROM metrics').fetchone()[0],1)
        t.put_catalog(self.db,[{'ad_id':OTHER}]);self.assertIsNone(self.row(OTHER)['spend'])
    def test_invalid_import_does_not_mutate(self):
        for bad in ({'account_id':'123'},{'currency':'USD'},{'date':'2026-11-01'},{'clicks':-1},{'spend':None}):
            with self.assertRaises(ValueError):t.import_metrics(self.db,self.payload(**bad))
        self.assertEqual(self.db.execute('SELECT count(*) FROM metrics').fetchone()[0],0)
    def test_distinct_contacts_and_cohort(self):
        self.touch();self.touch(conversation=2,message=2)
        self.touch(conversation=3,contact=11,message=3,when='2026-10-01T01:00:00Z')
        row=self.row();self.assertEqual(row['contacts'],1);self.assertEqual(row['conversations'],2)
    def test_credit_is_not_commission(self):
        self.touch();self.outcome(1,AD,'Contratado',2000,100);t.import_metrics(self.db,self.payload())
        row=self.row();self.assertEqual(row['commission_less_spend'],70);self.assertEqual(row['contracted'],2000)
    def test_missing_commission_does_not_become_profit(self):
        self.touch();self.touch(conversation=2,contact=20,message=2)
        self.outcome(1,AD,'Contratado',2000,100);self.outcome(2,AD,'Contratado',2000,None)
        t.import_metrics(self.db,self.payload());row=self.row()
        self.assertEqual(row['contracts'],2);self.assertIsNone(row['commission']);self.assertIsNone(row['commission_less_spend'])
    def test_sales_not_multiplied_by_ads(self):
        self.touch();self.touch(ad=OTHER,message=2)
        self.outcome(1,OTHER,'Contratado',2000,100)
        self.assertEqual(self.row()['contracts'],0);self.assertEqual(self.row(OTHER)['contracts'],1)
    def test_sale_attribution_freezes(self):
        self.touch();self.touch(ad=OTHER,message=2)
        self.outcome(1,AD,'Contratado',2000,100)
        def fake(sql):
            return json.dumps([{'id':1,'stage':'Contratado','contracted':'2000','commission':'100'}]) if sql.startswith('SELECT') else ''
        with patch.object(t,'psql',side_effect=fake):t.projections(self.db)
        self.assertEqual(self.db.execute('SELECT ad_id FROM outcomes').fetchone()[0],AD)
    def test_capture_replays_do_not_duplicate(self):
        rows=[{'id':1,'conversation_id':1,'contact_id':10,'created_at':'2026-10-28T12:00:00Z','ad_id':AD}]
        with patch.object(t,'psql',return_value=json.dumps({'cursor':100,'rows':rows})):
            t.capture(self.db);t.capture(self.db)
        self.assertEqual(self.db.execute('SELECT count(*) FROM touches').fetchone()[0],1)


class HttpTest(unittest.TestCase):
    def setUp(self):
        self.server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
    def tearDown(self):
        self.server.shutdown();self.server.server_close();self.thread.join()
    def request(self,method,path,body=None,headers=None):
        connection=http.client.HTTPConnection('127.0.0.1',self.server.server_port)
        connection.request(method,path,body,headers or {})
        response=connection.getresponse();status=response.status;payload=response.read();headers=dict(response.getheaders());connection.close()
        return status,payload,headers
    def test_anonymous_and_wrong_origin_cannot_access(self):
        self.assertEqual(self.request('GET','/ads-tracking/api/report')[0],401)
        self.assertEqual(self.request('GET','/ads-tracking/api/report',headers={'api-access-token':'synthetic-rejected'})[0],401)
        self.assertEqual(self.request('POST','/ads-tracking/api/config','{}',{'Origin':'https://example.org','Content-Type':'application/json'})[0],403)
    def test_old_shell_is_not_served(self):
        status,body,headers=self.request('GET','/ads-tracking/')
        self.assertEqual(status,404);self.assertIn('no-store',headers['Cache-Control'])
        self.assertNotIn(AD.encode(),body);self.assertIn("frame-ancestors 'none'",headers['Content-Security-Policy'])


if __name__=='__main__':unittest.main()
