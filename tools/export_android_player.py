"""Build the player APK in E:, leaving desktop texture imports and saves intact."""
from pathlib import Path
import hashlib, json, os, re, shutil, struct, subprocess, zipfile
from sync_authoring_templates import synchronize

PROJECT = Path(__file__).resolve().parents[1]
WORK = Path('E:/CodexWorkspace/PixelRogue/work/android-v030')
STAGE = WORK / 'project'
GODOT = Path('E:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
JAVA = Path(os.environ.get('PIXELROGUE_JAVA', 'E:/IntelliJ IDEA 2026.2.0.1/jbr'))
SDK = Path(os.environ.get('PIXELROGUE_ANDROID_SDK', str(WORK / 'sdk')))
LOGS = Path('E:/CodexWorkspace/PixelRogue/temp')
APK = Path('E:/CodexWorkspace/PixelRogue/outputs/RondoAtStarlightsEnd_V0.31_Android.apk')

def execute(arguments, environment, logfile):
    with logfile.open('w', encoding='utf-8') as output:
        subprocess.run([str(x) for x in arguments], env=environment, cwd=WORK,
                       stdout=output, stderr=subprocess.STDOUT, check=True)
    text = logfile.read_text(encoding='utf-8', errors='replace')
    if 'SCRIPT ERROR:' in text or re.search(r'^ERROR:', text, re.M):
        raise RuntimeError(f'Build diagnostics require attention: {logfile}')

def build():
    synchronize()
    for required in [GODOT, JAVA/'bin/java.exe', SDK/'build-tools/35.0.1/apksigner.bat', WORK/'private/signing.json']:
        if not required.exists(): raise FileNotFoundError(required)
    STAGE.mkdir(parents=True, exist_ok=True)
    for directory in ['src', 'data', 'assets']:
        for source in (PROJECT/directory).rglob('*'):
            if not source.is_file(): continue
            target = STAGE/source.relative_to(PROJECT)
            if target.exists() and target.stat().st_size == source.stat().st_size and target.stat().st_mtime_ns == source.stat().st_mtime_ns: continue
            target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(source, target)
    settings = (PROJECT/'project.godot').read_text(encoding='utf-8-sig')
    settings = re.sub(r'enabled=PackedStringArray\([^\n]*\)', 'enabled=PackedStringArray()', settings)
    # A fresh staging folder has no font import cache when the editor starts.
    # Bootstrap without the project theme, then restore it after imports finish.
    cold = not (STAGE/'.godot/imported').exists()
    bootstrap = re.sub(r'^theme/custom=.*$', 'theme/custom=""', settings, flags=re.M) if cold else settings
    (STAGE/'project.godot').write_text(bootstrap, encoding='utf-8')
    preset = (PROJECT/'export_presets.cfg').read_text(encoding='utf-8-sig')
    # Stage can be reused without exporting retired resources from an older build.
    extras = [p.relative_to(STAGE).as_posix() for folder in ['assets','src','data']
              for p in (STAGE/folder).rglob('*') if p.is_file()
              and not (PROJECT/p.relative_to(STAGE)).exists() and p.suffix not in {'.import','.uid'}]
    preset = re.sub(r'^exclude_filter="(.*)"$',
                    lambda m:'exclude_filter="'+m[1]+',addons/*'+(','+','.join(extras) if extras else '')+'"', preset, flags=re.M)
    (STAGE/'export_presets.cfg').write_text(preset, encoding='utf-8')
    for source in (STAGE/'assets').rglob('*.png'):
        with source.open('rb') as handle:
            header = handle.read(24)
        width, height = struct.unpack('>II', header[16:24])
        path = source.relative_to(STAGE).as_posix()
        if width*height < 1048576 or max(width,height) < 1024: continue
        if any(token in path for token in ['/hero','/monster','/fx/','/player_status','/skill','/pixel_batch']): continue
        imported = Path(str(source)+'.import')
        if imported.exists():
            text = imported.read_text(encoding='utf-8')
            text = re.sub(r'compress/mode=\d+', 'compress/mode=2', text)
            text = re.sub(r'compress/high_quality=(true|false)', 'compress/high_quality=false', text)
            imported.write_text(text, encoding='utf-8')
    env = os.environ.copy()
    env.update(APPDATA=str(WORK/'build-appdata'), JAVA_HOME=str(JAVA),
               ANDROID_USER_HOME=str(WORK/'android-user'), ANDROID_SDK_ROOT=str(SDK))
    execute([GODOT,'--headless','--path',STAGE,'--editor','--import'], env, LOGS/'android-build-import.log')
    (STAGE/'project.godot').write_text(settings, encoding='utf-8')
    editor = Path(env['APPDATA'])/'Godot/editor_settings-4.7.tres'
    text = editor.read_text(encoding='utf-8')
    for key, value in [('java_sdk_path',JAVA.as_posix()), ('android_sdk_path',SDK.as_posix())]:
        text = re.sub(r'^export/android/'+key+r' = .*$', f'export/android/{key} = "{value}"', text, flags=re.M)
    editor.write_text(text, encoding='utf-8')
    secret = json.loads((WORK/'private/signing.json').read_text())
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(WORK/'private/pixelrogue-release.keystore')
    env['GODOT_ANDROID_KEYSTORE_RELEASE_USER'] = secret['alias']
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD'] = secret['password']
    execute([GODOT,'--headless','--path',STAGE,'--export-release','Android V0.31'], env, LOGS/'android-build-export.log')
    compact(env, secret)

def compact(env, secret):
    unsigned, aligned, signed = [WORK/name for name in ['player-unsigned.apk','player-aligned.apk','player-signed.apk']]
    with zipfile.ZipFile(APK) as source, zipfile.ZipFile(unsigned,'w',allowZip64=False) as output:
        # Texture/font loading is sequential through AAssetManager. Keep audio and
        # video streaming entries unchanged, compress data without changing pixels.
        for entry in source.infolist():
            if entry.filename.startswith('META-INF/'): continue
            method = entry.compress_type
            if entry.filename.startswith('assets/') and entry.filename.endswith(('.ctex','.fontdata','.json','.csv','.gdc','.tres','.tscn')):
                method = zipfile.ZIP_DEFLATED
            record = zipfile.ZipInfo(entry.filename,entry.date_time)
            record.external_attr=entry.external_attr
            output.writestr(record,source.read(entry),compress_type=method,compresslevel=9)
    tools = SDK/'build-tools/35.0.1'
    execute([tools/'zipalign.exe','-f','-P','16','4',unsigned,aligned],env,LOGS/'android-build-align.log')
    env['PIXELROGUE_SIGNING_PASSWORD'] = secret['password']
    execute([tools/'apksigner.bat','sign','--ks',WORK/'private/pixelrogue-release.keystore',
             '--ks-key-alias',secret['alias'],'--ks-pass','env:PIXELROGUE_SIGNING_PASSWORD',
             '--key-pass','env:PIXELROGUE_SIGNING_PASSWORD','--out',signed,aligned],env,LOGS/'android-build-sign.log')
    execute([tools/'apksigner.bat','verify','--verbose',signed],env,LOGS/'android-build-verify.log')
    with zipfile.ZipFile(signed) as archive:
        assert archive.testzip() is None
        names=set(archive.namelist())
        assert not any(p.startswith(('assets/tests/','assets/tools/','assets/addons/')) for p in names)
        assert 'assets/assets/fonts/game_theme.tres.remap' in names
        camp=PROJECT/'assets/room_templates/camp_starlight_corridor.json'
        assert archive.read('assets/assets/room_templates/camp_starlight_corridor.json')==camp.read_bytes(), 'Camp template does not match the authored source'
        for name in names:
            if not name.endswith(('.import','.remap')): continue
            for reference in re.findall(r'^path="res://([^"]+)"',archive.read(name).decode('utf-8'),re.M):
                assert 'assets/'+reference in names, (name,reference)
    shutil.copy2(signed,APK)
    # Godot's intermediate v4 sidecar belongs to the pre-compaction APK.
    # The delivered APK is independently signed with v2/v3.
    sidecar=Path(str(APK)+'.idsig')
    if sidecar.exists():sidecar.unlink()
    digest=hashlib.file_digest(APK.open('rb'),'sha256').hexdigest()
    (WORK/'player-apk-verification.json').write_text(json.dumps({'bytes':APK.stat().st_size,'sha256':digest},indent=2),encoding='utf-8')
    print(f'Player APK verified: {APK} ({APK.stat().st_size/1048576:.1f} MiB)')

if __name__=='__main__': build()
