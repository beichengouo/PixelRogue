"""Isolated loopback transport / alpha-refinement tests; never opens player saves."""
import base64, hashlib, importlib.util, io, json, tempfile, threading, unittest
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from PIL import Image

spec=importlib.util.spec_from_file_location('tool_server',Path(__file__).with_name('server.py'))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class BrowserToolsTests(unittest.TestCase):
    def setUp(self):
        base=Path('E:/CodexWorkspace/PixelRogue/work/browser-tools-tests');base.mkdir(parents=True,exist_ok=True)
        self.temp=tempfile.TemporaryDirectory(dir=base)
        self.project=Path(self.temp.name);(self.project/'assets').mkdir()
        self.image=self.project/'assets/fixture.png'
        Image.new('RGBA',(4,4),(50,100,150,255)).save(self.image)
        self.tools=module.Tools(self.project,'unused',self.project/'work')
        self.tools.art={'documents':[{'layers':[{'path':'res://assets/fixture.png','locked':False},{'path':'res://assets/background.png','locked':True}]}]}
        self.tools.backup=lambda p:self.project/'baseline.png'
        self.server=module.ThreadingHTTPServer(('127.0.0.1',0),module.make_handler(self.tools))
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        self.url=f'http://127.0.0.1:{self.server.server_port}'
    def tearDown(self):
        self.server.shutdown();self.server.server_close();self.thread.join();self.temp.cleanup()
    def request(self,body,token=True,origin=None):
        headers={'Content-Type':'application/json'}
        if token:headers['X-Tool-Token']=self.tools.token
        if origin:headers['Origin']=origin
        return urlopen(Request(self.url+'/api',data=json.dumps(body).encode(),headers=headers),timeout=5)
    def test_transport_requires_token(self):
        with self.assertRaises(HTTPError) as error:self.request({'action':'fingerprint'},token=False)
        self.assertEqual(error.exception.code,403)
    def test_rejects_cross_origin(self):
        with self.assertRaises(HTTPError) as error:self.request({'action':'fingerprint'},origin='https://external.example')
        self.assertEqual(error.exception.code,403)
    def test_read_scope(self):
        for name in ['res://assets/../../project.godot','res://data/unit_balance.json','C:/secret.png']:
            with self.assertRaises(ValueError):self.tools.asset(name)
    def test_alpha_preserves_rgb_and_original(self):
        image=Image.new('RGBA',(4,4),(250,0,0,0));buffer=io.BytesIO();image.save(buffer,format='PNG')
        fingerprint=hashlib.sha256(self.image.read_bytes()).hexdigest()
        result=self.tools.alpha({'path':'res://assets/fixture.png','fingerprint':fingerprint,'png':base64.b64encode(buffer.getvalue()).decode()})
        edited=Image.open(self.image)
        self.assertEqual(edited.getpixel((0,0)),(50,100,150,0))
        self.assertEqual(Image.open(self.tools.backup(self.image)).getpixel((0,0)),(50,100,150,255))
        self.assertNotEqual(fingerprint,result['fingerprint'])
        with self.assertRaises(ValueError):self.tools.alpha({'path':'res://assets/fixture.png','fingerprint':fingerprint,'png':''})
    def test_background_is_readonly(self):
        with self.assertRaises(ValueError):self.tools.alpha({'path':'res://assets/background.png'})
    def test_fingerprint_api(self):
        with self.request({'action':'fingerprint','path':'res://assets/fixture.png'}) as response:value=json.load(response)
        self.assertEqual(value['fingerprint'],hashlib.sha256(self.image.read_bytes()).hexdigest())
    def test_story_revision_branches_restore(self):
        (self.project/'data').mkdir()
        base={'title':'原稿','lines':[{'who':'','text':'正文'}],'choices':[],'next':''}
        def bridge(r):
            edits=json.loads((self.project/'data/story_overrides.json').read_text(encoding='utf-8')) if (self.project/'data/story_overrides.json').exists() else {}
            return {'scene':edits.get(r['id']+'|'+r['hero']+'|first',base) if r['id'] in ['intro_wake','cp_10'] else {}}
        self.tools.bridge=bridge
        request={'action':'story_scene','id':'intro_wake','hero':'ilyua','replay':False}
        loaded=self.tools.story(request)
        scene={**base,'choices':[{'text':'走下一段','next':'cp_10','reply':[{'text':'好'}],'flags':{'asked':True},'affinity':1}]}
        save={**request,'action':'save_story','revision':loaded['revision'],'scene':scene}
        result=self.tools.story(save)
        self.assertEqual(result['scene']['choices'][0]['next'],'cp_10')
        with self.assertRaises(ValueError):self.tools.story(save)
        bad={**save,'revision':result['revision'],'scene':{**scene,'next':'missing_node'}}
        with self.assertRaises(ValueError):self.tools.story(bad)
        restored=self.tools.story({**save,'revision':result['revision'],'scene':None})
        self.assertEqual(restored['scene'],base)
        self.assertTrue(list((self.tools.work/'story-backups').glob('*.json')))

    def test_shutdown(self):
        with self.request({'action':'shutdown'}) as response:value=json.load(response)
        self.assertIn('关闭',value['message'])
        self.thread.join(timeout=2)
        self.assertFalse(self.thread.is_alive())

if __name__=='__main__':unittest.main()
