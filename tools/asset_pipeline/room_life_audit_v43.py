"""Verify V43's local footprints and source provenance without rewriting artwork."""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCENE = "forest_clearing_v03"
ART = ROOT / "assets/room_illustrated" / SCENE
LIVE = ROOT / "assets/room_life_v43" / SCENE
SOURCE = ROOT / "art_src/room_life_v43" / SCENE


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    scene = json.loads((ART / "scene.json").read_text(encoding="utf-8"))
    config = json.loads((LIVE / "animation.json").read_text(encoding="utf-8"))
    assert config["canvas"] == scene["canvas"] == [4608, 2592]
    original = Image.new("RGBA", tuple(scene["canvas"]))
    inputs = {}
    for plane in scene["planes"]:
        path = ART / plane["path"]
        inputs[str(path.relative_to(ROOT))] = sha(path)
        box = plane.get("rect_px", [0, 0, *scene["canvas"]])
        original.alpha_composite(Image.open(path).convert("RGBA"), (int(box[0]), int(box[1])))
    entries = []
    texture_bytes = 0
    for patch in config["patches"]:
        name = patch["id"]
        receipt = json.loads((SOURCE / name / "receipt.json").read_text(encoding="utf-8"))
        x, y, w, h = patch["rect_px"]
        reference = Image.open(SOURCE / name / "reference.png").convert("RGBA")
        assert reference.tobytes() == original.crop((x, y, x+w, y+h)).tobytes(), (name, "source changed")
        assert receipt["scale_down_only"] <= 1
        assert all(receipt["generation_prompts"].get(key) for key in ["repair", "animation"])
        repair_path, atlas_path = LIVE / patch["repair"], LIVE / patch["atlas"]
        assert sha(repair_path) == receipt["repair_hash"] and sha(atlas_path) == receipt["atlas_hash"]
        repair = Image.open(repair_path).convert("RGBA")
        atlas = Image.open(atlas_path).convert("RGBA")
        assert repair.size == (w, h) and atlas.size == (w*4, h*2)
        texture_bytes += (repair.width*repair.height + atlas.width*atlas.height)*4
        report = []
        for index in range(8):
            frame = atlas.crop((index%4*w, index//4*h, (index%4+1)*w, (index//4+1)*h))
            assert hashlib.sha256(frame.tobytes()).hexdigest() == receipt["frames"][index]["rgba_sha256"]
            alpha = np.asarray(frame)[:,:,3]
            assert alpha.max() > 128 and min(alpha[0].min(), alpha[-1].min()) == 0
            assert max(alpha[0].max(),alpha[-1].max(),alpha[:,0].max(),alpha[:,-1].max()) < 32
            anchor = receipt["frames"][index]["source_anchor"]
            offset = receipt["frames"][index]["translation"]
            error = max(abs(anchor[j]*receipt["scale_down_only"]+offset[j]-receipt["target_anchor"][j]) for j in range(2))
            assert error <= .500001, (name, index, "attachment drift")
            report.append({"index":index,"alpha_edge_max":int(max(alpha[0].max(),alpha[-1].max(),alpha[:,0].max(),alpha[:,-1].max())),"registration_error_source_px":error})
        # A repair must be exactly transparent at the boundary, ensuring the
        # original map outside the declared local rectangle cannot be altered.
        a = np.asarray(repair)[:,:,3]
        assert max(a[0].max(),a[-1].max(),a[:,0].max(),a[:,-1].max()) == 0
        entries.append({"id":name,"rect_px":patch["rect_px"],"frame_size":patch["frame_size"],"layer":patch["layer"],"phase":patch["phase"],"atlas_sha256":sha(atlas_path),"repair_sha256":sha(repair_path),"frames":report})
    assert len(entries) == 8
    result = {"scene":SCENE,"sets":8,"frames":64,"fps":6,"generation":"built-in image_gen",
              "original_planes_sha256":inputs,"original_scene_sha256":sha(ART / "scene.json"),
              "original_template_sha256":sha(ROOT / "assets/room_templates/forest_clearing.json"),
              "rgba_texture_bytes":texture_bytes,"rgba_texture_mib":texture_bytes/1048576,
              "verification":"All source crops still exactly match original map pixels; no upscaling; 64 frame hashes and registered anchors verified; transparent repair boundaries.",
              "limitations":["New plants have slightly crisper outlines and more regular leaves than the original painted plants.","Source-sheet review and consumer tests do not replace the user's in-game visual acceptance.","Tiny sub-threshold alpha edge noise from generated source art is retained."],"patches":entries}
    report_path = SOURCE / "production.json"
    if report_path.exists():
        prior = json.loads(report_path.read_text(encoding="utf-8"))
        if "validation" in prior:result["validation"] = prior["validation"]
    report_path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"sets":8,"frames":64,"rgba_texture_mib":result["rgba_texture_mib"]}))


if __name__ == "__main__":
    main()
