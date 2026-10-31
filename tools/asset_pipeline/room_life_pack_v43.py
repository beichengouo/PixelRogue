"""Pack imagegen-authored repairs and animation sheets; never modify map sources."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = Path("E:/CodexWorkspace/PixelRogue/work/map-life-v43")
SCENE = "forest_clearing_v03"
RUNTIME = ROOT / "assets/room_life_v43" / SCENE
SOURCES = ROOT / "art_src/room_life_v43" / SCENE


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pack(item):
    name = item["id"]
    out = SOURCES / name
    out.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for kind in ["reference", "repair", "animation"]:
        original = Path(item[kind])
        target = out / (kind + ".png")
        target.write_bytes(original.read_bytes())
    ref = Image.open(out / "reference.png").convert("RGBA")
    repair = Image.open(out / "repair.png").convert("RGBA")
    size = ref.size
    assert size[0] == size[1] and size[0] in [256, 384]
    cell = size[0]
    assert repair.width >= size[0] and repair.height >= size[1]
    repair = repair.resize(size, Image.Resampling.NEAREST)
    # Authored inpainting is only admitted inside this local footprint. A short
    # blend margin retains every source pixel outside the footprint unchanged.
    x0, y0, x1, y1 = item["repair_inner"]
    yy, xx = np.mgrid[:cell, :cell]
    distance = np.minimum.reduce([xx-x0, x1-1-xx, yy-y0, y1-1-yy])
    alpha = np.uint8(np.clip(distance / 10.0, 0, 1) * 255)
    repair.putalpha(Image.fromarray(alpha))
    repair.save(RUNTIME / (name + "_repair.png"))
    sheet = Image.open(out / "animation.png").convert("RGBA")
    tiles = []
    for i in range(8):
        x, y = i % 4, i // 4
        tile = sheet.crop((round(x*sheet.width/4), round(y*sheet.height/2),
                           round((x+1)*sheet.width/4), round((y+1)*sheet.height/2)))
        a = np.asarray(tile.getchannel("A"))
        bounds = tile.getchannel("A").point(lambda v: 255 if v >= 32 else 0).getbbox()
        assert bounds, (name, i, "empty")
        # No visible leaf may cross into the adjacent authored cell.
        assert max(a[0].max(), a[-1].max(), a[:,0].max(), a[:,-1].max()) < 32, (name, i, "cross-cell")
        tiles.append((tile, bounds))
    max_w = max(b[2]-b[0] for _, b in tiles)
    max_h = max(b[3]-b[1] for _, b in tiles)
    scale = min(item["plant_size"][0]/max_w, item["plant_size"][1]/max_h)
    assert scale <= 1.0, (name, "would upscale")
    atlas = Image.new("RGBA", (cell*4, cell*2))
    frame_report = []
    # A fixed source-space attachment point is measured for each authored cell.
    # This registration translates the whole cell; it does not deform leaves.
    for i, (tile, bounds) in enumerate(tiles):
        anchor = item.get("anchors", [])[i] if item.get("anchors") else [(bounds[0]+bounds[2])/2, (bounds[1]+bounds[3])/2]
        resized = tile.resize((round(tile.width*scale), round(tile.height*scale)), Image.Resampling.NEAREST)
        offset = (round(item["target_anchor"][0]-anchor[0]*scale), round(item["target_anchor"][1]-anchor[1]*scale))
        frame = Image.new("RGBA", size)
        frame.paste(resized, offset)
        a = np.asarray(frame.getchannel("A"))
        assert max(a[0].max(), a[-1].max(), a[:,0].max(), a[:,-1].max()) < 32, (name,i,"clipped packing")
        atlas.paste(frame, ((i%4)*cell, (i//4)*cell))
        frame_report.append({"index":i,"source_bounds":bounds,"source_anchor":anchor,"translation":offset,
                             "bounds":frame.getchannel("A").getbbox(),
                             "rgba_sha256":hashlib.sha256(frame.tobytes()).hexdigest()})
    atlas.save(RUNTIME / (name + "_atlas.png"))
    assert len(set(x["rgba_sha256"] for x in frame_report)) == 8, name
    receipt = {**item, "generation":"built-in image_gen", "source_sheet_size":sheet.size,
               "scale_down_only":scale,"frame_size":list(size),"frames":frame_report,
               "source_hashes":{k:sha(out/(k+'.png')) for k in ['reference','repair','animation']},
               "repair_hash":sha(RUNTIME/(name+'_repair.png')),"atlas_hash":sha(RUNTIME/(name+'_atlas.png'))}
    receipt.pop("root_px", None)  # The final registration uses target_anchor.
    (out / "receipt.json").write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding="utf-8")
    return {"id":name,"rect_px":item["rect_px"],"layer":item["layer"],"repair":name+"_repair.png",
            "atlas":name+"_atlas.png","frames":8,"columns":4,"frame_size":list(size),"fps":6,"phase":item["phase"],
            "anchor_px":item["target_anchor"]}


if __name__ == "__main__":
    import sys
    jobs = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    patches = [pack(item) for item in jobs]
    config={"version":1,"scene_id":SCENE,"canvas":[4608,2592],"patches":patches}
    (RUNTIME / "animation.json").write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"patches":len(patches),"frames":len(patches)*8}))
