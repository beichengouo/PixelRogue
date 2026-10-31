from pathlib import Path
import json, hashlib, shutil
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parent
project=Path('E:/GodotProjects/PixelRogue')
scene=project/'assets/room_illustrated/forest_clearing_v03'
data=json.loads((scene/'scene.json').read_text(encoding='utf-8-sig'))
mask=Image.new('RGBA',tuple(data['canvas']))
for plane in data['planes']:
    if plane.get('layer')=='walls':
        source=Image.open(scene/plane['path']).convert('RGBA')
        mask.alpha_composite(source,tuple(plane['rect_px'][:2]))
wall=np.asarray(mask.resize((1672,941),Image.Resampling.NEAREST))[...,3]>127
first=np.array(Image.open(root/'frames/frame_00.png').convert('RGBA'))
for i in range(1,8):
    wall &= np.all(np.array(Image.open(root/'frames'/f'frame_{i:02d}.png').convert('RGBA'))==first,axis=2)
dest=project/'assets/room_whole_v45/forest_clearing_v03'
dest.mkdir(parents=True,exist_ok=True)
for i in range(8):
    source=np.array(Image.open(root/'frames'/f'frame_{i:02d}.png').convert('RGBA'))
    ground=source.copy();ground[wall,3]=0
    Image.fromarray(ground).save(dest/f'ground_{i:02d}.png')
    if i==0:
        front=source.copy();front[~wall,3]=0
        Image.fromarray(front).save(dest/'walls.png')
    assert np.array_equal(np.array(Image.alpha_composite(Image.fromarray(ground),Image.fromarray(front))),source)
config={'version':1,'canvas':data['canvas'],'frame_size':[1672,941],'fps':6,'frames':[f'ground_{i:02d}.png' for i in range(8)],'walls':'walls.png'}
(dest/'animation.json').write_text(json.dumps(config,indent=2),encoding='utf-8')
art=project/'art_src/room_whole_v45/forest_clearing_v03';art.mkdir(parents=True,exist_ok=True)
for name in ['master_native.png','receipt.json','receipt_final.json','audit.json','bake.py','pack_runtime.py']:
    shutil.copy2(root/name,art/name)
receipt={'method':'single imagegen master with controlled local warp, full frame bake split by original wall mask for weather',
         'full_frames_source':str(root/'frames'),'pixel_exact_split':True,'size':[1672,941],
         'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.glob('*') if p.is_file()}}
(art/'production.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('Packed eight grounds + static walls; reconstruction matches all full frames exactly')
