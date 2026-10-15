"""Embed developer-authored map overrides; never touch gameplay save files."""
from pathlib import Path
import hashlib,json,os
PROJECT=Path(__file__).resolve().parents[1]
USER=Path(os.environ.get('PIXELROGUE_AUTHORING_TEMPLATES','C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/PixelRogue/room_templates'))
def synchronize():
    result={}
    if not USER.exists():return result
    target=PROJECT/'assets/room_templates'
    for source in sorted(USER.glob('*.json')):
        content=source.read_bytes()
        document=json.loads(content.decode('utf-8-sig'))
        identifier=str(document.get('id',''))
        if document.get('format')!='pixelrogue.room' or identifier in ['illustrated_tavern_v01','illustrated_forest_v01']:continue
        if not identifier or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in identifier):raise ValueError('Invalid template identifier')
        destination=target/(identifier+'.json')
        # Runtime validation is advisory. Preserve collision contours verbatim.
        if not destination.exists() or destination.read_bytes()!=content:destination.write_bytes(content)
        result[identifier]={'revision':document.get('revision',1),'sha256':hashlib.sha256(content).hexdigest()}
    return result
if __name__=='__main__':
    entries=synchronize()
    print('Authored templates synchronized:',len(entries))
    print('Camp:',entries.get('camp_starlight_corridor',{}))
