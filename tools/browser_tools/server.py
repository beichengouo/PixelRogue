"""Loopback-only authoring UI. No third-party web services or packages required."""
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote
import argparse, base64, hashlib, io, json, os, secrets, subprocess, threading, time, webbrowser
from urllib.request import urlopen

WORK = Path('E:/CodexWorkspace/PixelRogue/work/browser-tools')
WORK.mkdir(parents=True, exist_ok=True)
LOCK = threading.Lock()

class Tools:
    def __init__(self, project, godot, work=WORK):
        self.project = Path(project).resolve()
        self.godot = godot
        self.work = Path(work)
        self.work.mkdir(parents=True, exist_ok=True)
        self.token = secrets.token_urlsafe(32)
        self.art = None
        self.bridge_lock = threading.Lock()
        self.worker = None
        self.worker_log = None
        self.mailbox = self.work / ("worker-"+secrets.token_hex(8)+".json")
        self.environment = os.environ.copy()

    def close(self):
        if self.worker is not None:
            self.worker.terminate()
            try: self.worker.wait(timeout=5)
            except subprocess.TimeoutExpired: self.worker.kill(); self.worker.wait()
            self.worker = None
        if self.worker_log is not None: self.worker_log.close(); self.worker_log = None
        for suffix in ['', '.result', '.tmp', '.result.tmp']:
            Path(str(self.mailbox)+suffix).unlink(missing_ok=True)

    def bridge(self, request):
        # Reuse one isolated codec process; serialize only its mailbox operations.
        with self.bridge_lock:
            if self.worker is None or self.worker.poll() is not None:
                self.close()
                self.worker_log = (self.work/'bridge.log').open('w', encoding='utf-8')
                self.worker = subprocess.Popen([self.godot, '--headless', '--path', str(self.project),
                    '--scene', 'res://tools/browser_tools/bridge.tscn', '--', '--room-editor',
                    '--browser-daemon', str(self.mailbox)], stdout=self.worker_log,
                    stderr=subprocess.STDOUT, env=self.environment,
                    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            result = Path(str(self.mailbox)+'.result')
            result.unlink(missing_ok=True)
            temp = Path(str(self.mailbox)+'.tmp')
            temp.write_text(json.dumps(request, ensure_ascii=False), encoding='utf-8'); temp.replace(self.mailbox)
            deadline = time.monotonic()+180
            while not result.exists():
                if self.worker.poll() is not None or time.monotonic()>deadline:
                    self.close()
                    raise ValueError('Godot 数据接口未响应，请查看 '+str(self.work/'bridge.log'))
                time.sleep(.01)
            try: return json.loads(result.read_text(encoding='utf-8'))
            finally: result.unlink(missing_ok=True)

    def story(self, request):
        if request.get('hero') not in ['sylphiette','xixifu','ilyua'] or not isinstance(request.get('id'),str):
            raise ValueError('角色或节点无效')
        path = self.project/'data/story_overrides.json'
        payload = path.read_bytes() if path.exists() else b'{}'
        fingerprint = hashlib.sha256(payload).hexdigest()
        data = json.loads(payload)
        key = str(request['id'])+'|'+str(request['hero'])+'|'+('repeat' if request.get('replay') else 'first')
        if request['action']=='save_story':
            if request.get('revision')!=fingerprint: raise ValueError('剧情已被其他窗口修改，请重新载入')
            scene = request.get('scene')
            if scene is None: data.pop(key, None)
            else:
                if not isinstance(scene,dict) or not isinstance(scene.get('title'),str) or not isinstance(scene.get('lines'),list): raise ValueError('剧情正文格式无效')
                choices=scene.get('choices',[])
                if not isinstance(choices,list) or len(choices)>3: raise ValueError('最多三个分支')
                for line in scene['lines']:
                    if not isinstance(line,dict) or not isinstance(line.get('text'),str): raise ValueError('每条正文必须包含text')
                for choice in choices:
                    if not isinstance(choice,dict) or not isinstance(choice.get('text'),str): raise ValueError('分支必须包含text')
                    if not isinstance(choice.get('reply',[]),list): raise ValueError('分支回复必须为数组')
                    for line in choice.get('reply',[]):
                        if not isinstance(line,dict) or not isinstance(line.get('text'),str): raise ValueError('回复必须包含text')
                    if not isinstance(choice.get('flags',{}),dict): raise ValueError('flags必须为对象')
                    if not isinstance(choice.get('requires',''),str): raise ValueError('requires必须为标记名称')
                    if not isinstance(choice.get('affinity',0),(int,float)): raise ValueError('好感变化必须为数字')
                for target in [scene.get('next','')]+[c.get('next','') for c in choices]:
                    if not isinstance(target,str): raise ValueError('后续节点必须为字符串')
                    if target and target!=request['id'] and not self.bridge({'action':'story_scene','id':target,'hero':request['hero'],'replay':request.get('replay',False)}).get('scene'):
                        raise ValueError('后续节点不存在：'+target)
                if request['id'].startswith('commission:'):
                    if scene.get('next') or choices:raise ValueError('委托阶段只编辑对白；触发、接取与交付沿用原事务')
                    scene={k:v for k,v in scene.items() if k in ['title','lines']}
                if request['id'].startswith('camp:'):
                    if scene.get('next') or any(c.get('next') for c in choices):raise ValueError('营地关系事件使用回复与关系选择，不支持主线节点跳转')
                    scene={k:v for k,v in scene.items() if k in ['title','lines','choices']}
                data[key]=scene
            with self.bridge_lock:
                if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()!=fingerprint: raise ValueError('剧情已变化，请重新载入')
                archive=self.work/'story-backups';archive.mkdir(exist_ok=True)
                backup=archive/(fingerprint+'.json')
                if not backup.exists():backup.write_bytes(payload)
                temp=path.with_suffix('.json.writing');temp.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(path)
            fingerprint=hashlib.sha256(path.read_bytes()).hexdigest()
        scene=self.bridge({'action':'story_scene','id':request['id'],'hero':request['hero'],'replay':request.get('replay',False)}).get('scene',{})
        return {'scene':scene,'revision':fingerprint,'overridden':key in data,'message':'剧情已保存，新打开的演出生效。'}

    def asset(self, value):
        if not isinstance(value, str) or not value.startswith('res://assets/'):
            raise ValueError('只允许读取工程素材')
        path = (self.project / value[6:]).resolve()
        if not path.is_relative_to(self.project/'assets') or path.suffix.lower() not in ['.png', '.jpg', '.webp', '.json']:
            raise ValueError('素材路径无效')
        return path

    def backup(self, path):
        folder = Path('E:/CodexWorkspace/PixelRogue/archive/browser-art')
        folder.mkdir(parents=True, exist_ok=True)
        return folder/(hashlib.sha256(str(path).encode()).hexdigest()+'.png')

    def original(self, path):
        # Honour baselines already saved by the previous native layer editor.
        relative='res://'+path.relative_to(self.project).as_posix()
        native=Path('E:/CodexWorkspace/PixelRogue/work/art-editor/originals')/(hashlib.sha256(relative.encode()).hexdigest()+'.png')
        if native.exists():return native
        return self.backup(path) if self.backup(path).exists() else path

    def alpha(self, request):
        from PIL import Image
        if self.art is None:
            self.art = self.bridge({'action':'art'})
        allowed = {row['path'] for doc in self.art.get('documents',[]) for row in doc['layers'] if not row['locked']}
        value = request.get('path','')
        if value not in allowed: raise ValueError('底图只读或该图层未注册')
        path = self.asset(value)
        if hashlib.sha256(path.read_bytes()).hexdigest() != request.get('fingerprint'):
            raise ValueError('图层被其他窗口修改，请重新载入')
        data = base64.b64decode(request.get('png','').split(',')[-1], validate=True)
        if len(data)>24*1024*1024: raise ValueError('图层过大')
        original = Image.open(path).convert('RGBA')
        edited = Image.open(io.BytesIO(data)).convert('RGBA')
        if edited.size!=original.size: raise ValueError('不允许改变图层尺寸')
        backup = self.backup(path)
        if not backup.exists(): backup.write_bytes(path.read_bytes())
        # Refinement changes transparency only; source colour and alignment survive.
        original.putalpha(edited.getchannel('A'))
        output = io.BytesIO(); original.save(output, format='PNG')
        payload = output.getvalue()
        temp = path.with_suffix('.png.browser-writing');temp.write_bytes(payload);temp.replace(path)
        return {'message':'透明边缘已保存，Godot 自动重新导入后生效。','fingerprint':hashlib.sha256(payload).hexdigest()}

def make_handler(service):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args): pass
        def reply(self, data, code=200, content_type='application/json; charset=utf-8'):
            if isinstance(data,(dict,list)):data=json.dumps(data,ensure_ascii=False).encode()
            if isinstance(data,str):data=data.encode()
            self.send_response(code);self.send_header('Content-Type',content_type)
            self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store')
            self.send_header('X-Content-Type-Options','nosniff');self.end_headers();self.wfile.write(data)
        def local(self):
            host=self.headers.get('Host','')
            return host in [f'127.0.0.1:{self.server.server_port}',f'localhost:{self.server.server_port}']
        def do_GET(self):
            if not self.local():self.reply({'error':'仅限本机'},403);return
            parsed=urlparse(self.path)
            if parsed.path=='/health':self.reply({'project':str(service.project),'protocol':4});return
            if parsed.path in ['/','/app.js','/story_graph.js','/style.css']:
                name={'/':'index.html'}.get(parsed.path,parsed.path[1:])
                mime={'html':'text/html; charset=utf-8','js':'text/javascript; charset=utf-8','css':'text/css; charset=utf-8'}[name.split('.')[-1]]
                self.reply((Path(__file__).parent/name).read_bytes(),content_type=mime);return
            if self.headers.get('X-Tool-Token','')!=service.token and parse_qs(parsed.query).get('token',[''])[0]!=service.token:
                self.reply({'error':'请使用开发工具启动入口'},403);return
            if parsed.path=='/asset':
                try:
                    args=parse_qs(parsed.query);path=service.asset(args.get('path',[''])[0])
                    if args.get('original')==['1']:path=service.original(path)
                    mime='image/png' if path.suffix.lower()=='.png' else 'image/webp' if path.suffix.lower()=='.webp' else 'image/jpeg'
                    self.reply(path.read_bytes(),content_type=mime)
                except (ValueError,OSError) as error:self.reply({'error':str(error)},400)
            else:self.reply({'error':'不存在的地址'},404)
        def do_POST(self):
            if not self.local() or self.headers.get('X-Tool-Token','')!=service.token:
                self.reply({'error':'请求已拒绝'},403);return
            origin=self.headers.get('Origin','')
            if origin and origin not in [f'http://127.0.0.1:{self.server.server_port}',f'http://localhost:{self.server.server_port}']:
                self.reply({'error':'不允许跨站调用'},403);return
            try:
                length=int(self.headers.get('Content-Length','0'))
                if length<1 or length>36*1024*1024:raise ValueError('请求过大或为空')
                request=json.loads(self.rfile.read(length))
                if not isinstance(request,dict):raise ValueError('请求应为对象')
                action=request.get('action')
                if action=='shutdown':
                    self.reply({'message':'开发服务已关闭'});threading.Thread(target=self.server.shutdown,daemon=True).start();return
                if action in ['story_scene','save_story']:result=service.story(request)
                elif action=='alpha':result=service.alpha(request)
                elif action=='fingerprint':result={'fingerprint':hashlib.sha256(service.asset(request['path']).read_bytes()).hexdigest()}
                elif action in ['story_bundle','story_catalog','catalog','map','validate','save_map','playtest','art','save_layout','save_units','load_save','grant']:
                    result=service.bridge(request)
                    if action=='art':service.art=result
                else:raise ValueError('未知操作')
                self.reply(result)
            except (ValueError,KeyError,OSError,subprocess.TimeoutExpired) as error:self.reply({'error':str(error)},400)
            except Exception as error:self.reply({'error':type(error).__name__+': '+str(error)},500)
    return Handler

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--project',required=True);parser.add_argument('--godot',required=True)
    parser.add_argument('--no-open',action='store_true');parser.add_argument('--port',type=int,default=0)
    parser.add_argument('--isolated',action='store_true',help='Use E-drive test userdata, never the developer/player profile')
    args=parser.parse_args();service=Tools(args.project,args.godot)
    if args.isolated:
        isolated=WORK/'isolated'/hashlib.md5(str(service.project).encode()).hexdigest()
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            folder=isolated/key;folder.mkdir(parents=True,exist_ok=True);service.environment[key]=str(folder)
    state=WORK/('session-'+hashlib.md5(str(service.project).encode()).hexdigest()+'.json')
    if state.exists() and not args.no_open:
        try:
            prior=json.loads(state.read_text(encoding='utf-8'));url=prior['url'];parsed=urlparse(url)
            if parsed.hostname!='127.0.0.1':raise ValueError('invalid loopback session')
            with urlopen(f'http://127.0.0.1:{parsed.port}/health',timeout=1) as response:health=json.load(response)
            if Path(health['project']).resolve()==service.project and health.get('protocol')==4:
                webbrowser.open(url);return
        except (ValueError,OSError,KeyError):pass
    server=ThreadingHTTPServer(('127.0.0.1',args.port),make_handler(service))
    url=f'http://127.0.0.1:{server.server_port}/#'+service.token
    state.write_text(json.dumps({'url':url,'pid':os.getpid(),'project':str(service.project)}),encoding='utf-8')
    if not args.no_open:webbrowser.open(url)
    print(url,flush=True)
    try:server.serve_forever()
    finally:server.server_close();service.close()

if __name__=='__main__':main()
