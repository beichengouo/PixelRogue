"""V45 experiment: bake full frames from a single immutable master, not AI frame redraw."""
from pathlib import Path
import hashlib, json, math
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
im = Image.open(ROOT / 'master_native.png').convert('RGB')
base = np.asarray(im)
h, w = base.shape[:2]
assert (w, h) == (1672, 941), 'Review masks again if master changes'
# Hand-selected foliage crowns, in native master pixels. Bottom/root stays fixed.
# Do not include walls, trunks, entrance mouths or gravel path.
regions = [
    (400,207,40,35),(490,273,44,35),(574,214,32,30),
    (654,201,33,29),(624,351,32,29),(579,376,29,25),
    (391,289,31,27),(378,641,36,29),(402,534,34,28),
    (589,748,36,26),(857,542,39,31),
    (1047,735,34,29),(1105,622,41,34),
    (1211,624,31,27),(1312,705,39,32),(1293,576,35,29),
    (1303,391,37,30),(1281,306,38,32),(1248,245,39,32),
    (1171,358,32,29),(1074,508,39,30),
    (947,220,38,31),(982,443,35,29),
    (816,289,30,27),(745,410,34,26),
]
yy, xx = np.mgrid[:h,:w].astype(np.float32)
weights = []
annotated = im.copy()
draw = ImageDraw.Draw(annotated)
for i,(cx,cy,rx,ry) in enumerate(regions):
    # Compact smooth elliptical support. Displacement is zero at support boundary.
    r2 = ((xx-cx)/rx)**2 + ((yy-cy)/ry)**2
    crown = np.clip(1-r2, 0, 1)**2
    height = np.clip((cy+ry-yy)/(2*ry),0,1)
    weight = crown * height * 2
    weights.append(weight)
    draw.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),outline='#ff8b40',width=1)
    draw.text((cx-rx,cy-ry-12),str(i+1),fill='white',stroke_width=1,stroke_fill='black')
annotated.save(ROOT/'foliage_regions_review.png')
support = np.any(np.array(weights)>0,axis=0)
Image.fromarray(support.astype('uint8')*255).save(ROOT/'motion_support.png')

def bake(t):
    dx=np.zeros((h,w),np.float32)
    dy=np.zeros_like(dx)
    for i,weight in enumerate(weights):
        # Rational, fixed phases; one closed cycle every eight frames, no RNG.
        phase=(i*3 % 8)*math.tau/8
        wave=math.sin(t+phase)
        dx+=weight * (1.7*wave)
        dy+=weight * (0.25*math.sin(t+phase+0.45))
    # Sample immutable mother frame, never the preceding raster frame.
    sx=np.clip(xx-dx,0,w-1); sy=np.clip(yy-dy,0,h-1)
    x0=np.floor(sx).astype(int); y0=np.floor(sy).astype(int)
    x1=np.minimum(x0+1,w-1); y1=np.minimum(y0+1,h-1)
    fx=(sx-x0)[...,None]; fy=(sy-y0)[...,None]
    out=np.rint((base[y0,x0]*(1-fx)+base[y0,x1]*fx)*(1-fy)
                +(base[y1,x0]*(1-fx)+base[y1,x1]*fx)*fy).clip(0,255).astype('uint8')
    out[~support]=base[~support]  # exact static-region guarantee
    return out, float(np.hypot(dx,dy).max())

frames=[]; maximum=0
(ROOT/'frames').mkdir(exist_ok=True)
for i in range(8):
    out,displacement=bake(i*math.tau/8)
    assert np.array_equal(out[~support],base[~support])
    frames.append(out); maximum=max(maximum,displacement)
    Image.fromarray(out).save(ROOT/'frames'/f'frame_{i:02d}.png')
loop,_=bake(math.tau)
assert np.array_equal(loop,frames[0]), 'Analytic loop must close exactly'
hashes=[hashlib.sha256(f.tobytes()).hexdigest() for f in frames]
assert len(set(hashes)) == 8
steps=[float(np.abs(frames[(i+1)%8].astype(float)-f).mean()) for i,f in enumerate(frames)]
audit={
    'status':'native_resolution_style_and_motion_trial_not_runtime_admitted',
    'method':'one imagegen master, deterministic local inverse warp baked to eight full images',
    'native_size':[w,h], 'requested_size':[2560,1440], 'upscaled':False,
    'fps':6,'frame_count':8,'regions':regions,'maximum_displacement_px':maximum,
    'moving_support_fraction':float(support.mean()),'unchanged_outside_support':True,
    'frame_8_equals_frame_0':True,'unique_frames':len(set(hashes)),
    'adjacent_mean_absolute_rgb_difference_including_wrap':steps,
    'pixel_sha256':hashes,
    'master_file_sha256':hashlib.sha256((ROOT/'master_native.png').read_bytes()).hexdigest(),
    'rgba8_estimated_MiB':w*h*4*8/1024**2,
    'limitations':['native output is below requested 2K',
        'AI master preserves overall layout but is not proven pixel registered to original gameplay',
        'elliptical crowns include some adjacent grass; these are local deformations, not articulated leaf animation',
        'no formal-game replacement or GL performance validation'],
}
(ROOT/'audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in audit.items() if k not in ['pixel_sha256','regions','limitations']},indent=2))
