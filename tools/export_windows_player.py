"""Export and smoke-check the player build using isolated E-drive save storage."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,zipfile
from sync_authoring_templates import synchronize
PROJECT=Path(__file__).resolve().parents[1]
WORK=Path('E:/CodexWorkspace/PixelRogue/work/release-v031')
OUTPUT=Path('E:/CodexWorkspace/PixelRogue/outputs/RondoAtStarlightsEnd_V0.31_Windows_x64')
EXE=OUTPUT/'RondoAtStarlightsEnd_V0.31.exe'
GODOT=Path('E:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
def execute(arguments,environment,name,timeout=600):
    path=WORK/name
    with path.open('w',encoding='utf-8') as output:
        result=subprocess.run([str(x) for x in arguments],cwd=WORK,env=environment,stdout=output,stderr=subprocess.STDOUT,timeout=timeout)
    content=path.read_text(encoding='utf-8',errors='replace')
    if result.returncode or 'SCRIPT ERROR:' in content or re.search(r'^ERROR:',content,re.M):raise RuntimeError(str(path))
    return content
def build():
    WORK.mkdir(parents=True,exist_ok=True);OUTPUT.mkdir(parents=True,exist_ok=True)
    synchronize()
    env=os.environ.copy()
    env.update(APPDATA=str(WORK/'build-appdata'),LOCALAPPDATA=str(WORK/'build-localappdata'),XDG_DATA_HOME=str(WORK/'build-xdg'),TEMP=str(WORK/'temp'),TMP=str(WORK/'temp'))
    for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME','TEMP']:Path(env[key]).mkdir(parents=True,exist_ok=True)
    if '--verify-only' not in sys.argv:
        execute([GODOT,'--headless','--path',PROJECT,'--editor','--import'],env,'import.log')
        execute([GODOT,'--headless','--path',PROJECT,'--export-release','Windows V0.31',EXE],env,'export.log')
    smoke=env.copy();smoke.update(APPDATA=str(WORK/'player-smoke-appdata'),LOCALAPPDATA=str(WORK/'player-smoke-localappdata'),XDG_DATA_HOME=str(WORK/'player-smoke-xdg'))
    for key in ['APPDATA','LOCALAPPDATA','XDG_DATA_HOME']:Path(smoke[key]).mkdir(parents=True,exist_ok=True)
    probe=WORK/'package_probe.gd'
    expected=hashlib.sha256((PROJECT/'assets/room_templates/camp_starlight_corridor.json').read_bytes()).hexdigest()
    probe.write_text('extends SceneTree\nfunc _initialize()->void:\n\tvar data:=OS.get_user_data_dir()\n\tif not data.begins_with("E:/CodexWorkspace/PixelRogue/work/release-v031/"):printerr("ERROR: Unsafe smoke save path");quit(1);return\n\tvar digest:=FileAccess.get_sha256("res://assets/room_templates/camp_starlight_corridor.json")\n\tif digest!="'+expected+'":printerr("ERROR: Packaged camp mismatch");quit(1);return\n\tif ProjectSettings.get_setting("application/config/version")!="0.31":printerr("ERROR: Packaged version mismatch");quit(1);return\n\tprint("PACKAGE_PROBE camp_sha256=",digest," version=0.31 isolated_userdata=",data)\n\tquit()\n',encoding='utf-8')
    # Running an external script is an editor-binary CLI feature. Load the
    # shipped embedded pack with that binary, then separately launch the EXE.
    text=execute([GODOT,'--headless','--main-pack',EXE,'--script',probe],smoke,'package-probe.log',120)
    if 'PACKAGE_PROBE' not in text:raise RuntimeError('Package probe did not run')
    execute([EXE,'--rendering-method','gl_compatibility','--position','32000,32000','--quit-after','180'],smoke,'player-start.log',120)
    archive=Path(str(OUTPUT)+'.zip')
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as target:
        target.write(EXE,EXE.name)
    with zipfile.ZipFile(archive) as target:assert target.testzip() is None
    (WORK/'verification.json').write_text(json.dumps({'exe_bytes':EXE.stat().st_size,'zip_bytes':archive.stat().st_size,'camp_sha256':expected,'sha256':hashlib.file_digest(EXE.open('rb'),'sha256').hexdigest()},indent=2),encoding='utf-8')
    print(f'Windows player verified: {archive} ({archive.stat().st_size/1048576:.1f} MiB)')
if __name__=='__main__':build()
