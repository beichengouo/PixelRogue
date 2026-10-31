"""Audit native imagegen FX sources against their losslessly packed runtime cells.

Writes an inventory, not a claim of visual or gameplay approval. Requires Pillow.
"""
from pathlib import Path
import hashlib
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src/boss_fx_v42"
RUNTIME = ROOT / "assets/boss_fx_v42"
STAGES = {
    "king": ["cast", "impact"], "mage": ["cast", "impact", "construct"],
    "tide": ["cast", "impact", "construct"], "sephra": ["cast", "impact"],
    "verena": ["cast", "impact"], "nameless": ["cast", "impact"],
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit(family, stage):
    source = SOURCE / family / (stage + "_source.png")
    receipt = SOURCE / family / (stage + "_receipt.json")
    atlas = RUNTIME / (family + "_" + stage + ".png")
    missing = [str(p.relative_to(ROOT)) for p in [source, receipt, atlas] if not p.exists()]
    if missing:
        return {"status": "missing", "missing": missing}
    original = Image.open(source).convert("RGBA")
    runtime = Image.open(atlas).convert("RGBA")
    width, height = original.size
    cw, ch = width // 2, height // 2
    cell = max(width - cw, height - ch)
    assert runtime.size == (cell * 4, cell), atlas
    assert cell >= 512, (atlas, "resolution below contract")
    frames = []
    for index, (x, y) in enumerate([(0, 0), (cw, 0), (0, ch), (cw, ch)]):
        native = original.crop((x, y, cw if x == 0 else width, ch if y == 0 else height))
        tile_width, tile_height = native.size
        expected = Image.new("RGBA", (cell, cell))
        expected.paste(native, ((cell - tile_width) // 2, (cell - tile_height) // 2))
        actual = runtime.crop((index * cell, 0, (index + 1) * cell, cell))
        assert expected.tobytes() == actual.tobytes(), (atlas, index, "native pixels changed")
        alpha = actual.getchannel("A")
        assert alpha.getextrema()[0] == 0 and alpha.getextrema()[1] > 32, (atlas, index, "invalid alpha")
        edges = (list(native.getchannel("A").crop((0, 0, tile_width, 1)).tobytes())
                 + list(native.getchannel("A").crop((0, tile_height - 1, tile_width, tile_height)).tobytes())
                 + list(native.getchannel("A").crop((0, 0, 1, tile_height)).tobytes())
                 + list(native.getchannel("A").crop((tile_width - 1, 0, tile_width, tile_height)).tobytes()))
        frames.append({
            "index": index, "alpha_range": alpha.getextrema(), "bounds": alpha.getbbox(),
            "visible_bounds_alpha_32": alpha.point(lambda p: 255 if p >= 32 else 0).getbbox(),
            "native_cell_edge_alpha_max": max(edges),
            "native_cell_edge_fraction_alpha_16": sum(p >= 16 for p in edges) / len(edges),
            "rgba_sha256": hashlib.sha256(actual.tobytes()).hexdigest(),
        })
    assert len({f["rgba_sha256"] for f in frames}) == 4, (atlas, "repeated frame")
    logical = (96 if family in ["sephra", "verena", "nameless"] else 88) if stage == "cast" else 48 if stage == "construct" else 60
    return {"status": "native_pixels_verified", "source": str(source.relative_to(ROOT)),
            "receipt": str(receipt.relative_to(ROOT)), "source_sha256": sha(source),
            "atlas": str(atlas.relative_to(ROOT)), "atlas_sha256": sha(atlas),
            "source_size": original.size, "native_cell": cell, "logical_width_max": logical,
            "physical_width_at_2k": logical * 2, "frames": frames}


def main():
    results = {family + "_" + stage: audit(family, stage)
               for family, stages in STAGES.items() for stage in stages}
    missing = [name for name, item in results.items() if item["status"] == "missing"]
    result = {"batch": 42, "generation": "built-in image_gen",
              "packing": "native 2x2 cells to 1x4 square cells with transparent padding; no resampling",
              "expected_sets": 14, "expected_frames": 56,
              "verified_sets": 14 - len(missing), "pending": missing, "sets": results,
              "scope": "Six Boss cast/impact plus mage/tide construct. V40 geometry and attack rules retained.",
              "limitations": ["Pixel checks do not prove artistic continuity or in-game readability.",
                              "Low alpha edge haze is retained and measured; no alpha was erased."]}
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / "production.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"verified_sets": result["verified_sets"], "pending": missing}))
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
