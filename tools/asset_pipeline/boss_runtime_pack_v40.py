"""Build complete V40 boss stage atlases from four hand-drawn key poses.

The generated SpriteFrames deliberately reuse the four key poses in timed
slots. This does not produce or claim 48 separately drawn animation frames.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT / "art_src" / "boss_redraw_v40" / "poses"
AUDIT = SOURCE / "audit.json"
OUTPUT = PROJECT / "assets" / "boss_stages_v40"
LEGACY = PROJECT / "assets" / "boss_stages_v34"
POSES = ("idle", "move", "windup", "release")
CELL = 960
INSET = 72
ALPHA_THRESHOLD = 46
EXPECTED_STAGES = (
    "king_1", "king_2", "mage_1", "mage_2", "tide_1", "tide_2", "tide_3",
    "sephra_1", "sephra_2", "verena_1", "verena_2",
    "nameless_1", "nameless_2", "nameless_3",
)


def painted_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    mask = image.getchannel("A").point(lambda a: 255 if a >= ALPHA_THRESHOLD else 0)
    result = mask.getbbox()
    if result is None:
        raise ValueError("Empty painted pose")
    return result


def source_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(stage: str) -> None:
    old = json.loads((LEGACY / f"{stage}.json").read_text(encoding="utf-8"))
    audited = json.loads(AUDIT.read_text(encoding="utf-8"))["sets"][stage]
    images: dict[str, Image.Image] = {}
    source_bounds: dict[str, tuple[int, int, int, int]] = {}
    for pose in POSES:
        path = SOURCE / stage / f"{pose}.png"
        if source_sha(path) != audited[pose]["sha256"]:
            raise ValueError(f"{stage}/{pose}: source differs from approved audit SHA")
        image = Image.open(path).convert("RGBA")
        images[pose] = image
        source_bounds[pose] = painted_bounds(image)
        left, top, right, bottom = source_bounds[pose]
        if [left, top, right - left, bottom - top] != audited[pose]["used"]:
            raise ValueError(f"{stage}/{pose}: painted bounds differ from audit")
    # Trim only transparent canvas padding. Keep every painted pixel, including
    # weapons and capes, at a common phase scale and a common painted baseline.
    trims: dict[str, tuple[int, int, int, int]] = {}
    for pose, image in images.items():
        left, top, right, bottom = source_bounds[pose]
        trims[pose] = (max(0, left - 2), max(0, top - 2), min(image.width, right + 2), min(image.height, bottom + 2))
    max_extent = max(max(t[2] - t[0], t[3] - t[1]) for t in trims.values())
    factor = min(1.0, (CELL - 2 * INSET) / max_extent)
    atlas = Image.new("RGBA", (CELL * len(POSES), CELL), (0, 0, 0, 0))
    entries: dict[str, dict] = {}
    baseline = CELL - INSET
    for index, pose in enumerate(POSES):
        original = images[pose]
        trim = trims[pose]
        image = original.crop(trim)
        width = round(image.width * factor)
        height = round(image.height * factor)
        resized = image.resize((width, height), Image.Resampling.LANCZOS)
        # Source canvases differ between poses. Match the painted sole/bottom
        # to one baseline, then center the fully preserved painted extent.
        bounds = source_bounds[pose]
        x = index * CELL + (CELL - width) // 2
        y = baseline - round((bounds[3] - trim[1]) * factor)
        if x < index * CELL or x + width > (index + 1) * CELL or y < 0 or y + height > CELL:
            raise ValueError(f"{stage}/{pose}: scaled pose exceeds atlas cell")
        atlas.alpha_composite(resized, (x, y))
        left = x - index * CELL + round((bounds[0] - trim[0]) * factor)
        top = y + round((bounds[1] - trim[1]) * factor)
        right = x - index * CELL + round((bounds[2] - trim[0]) * factor)
        bottom = y + round((bounds[3] - trim[1]) * factor)
        entries[pose] = {
            "index": index,
            "source_sha256": source_sha(SOURCE / stage / f"{pose}.png"),
            "source_canvas": list(original.size),
            "trim": list(trim),
            "painted_bounds": [left, top, right, bottom],
        }
        if bottom != baseline:
            raise AssertionError("Painted baseline drifted")
    idle_bounds = source_bounds["idle"]
    body_height = (idle_bounds[3] - idle_bounds[1]) * factor
    if body_height < 400:
        raise ValueError(f"{stage}: native detail too low ({body_height:.1f}px)")
    out = {
        "revision": 40,
        "cell": CELL,
        "foot": [CELL // 2, baseline],
        "body_height": round(body_height, 3),
        "source_pose_count": 4,
        "animation_kind": "held_four_key_poses",
        "poses": entries,
        # Keep the V34 action contract exactly, including generic aliases.
        "animations": {
            name: {"fps": spec["fps"], "slots": len(spec["frames"])}
            for name, spec in old["animations"].items()
        },
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT / f"{stage}.png", optimize=True)
    (OUTPUT / f"{stage}.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"BOSS_RUNTIME {stage} {CELL}x{CELL * 4} body={body_height:.1f} actions={len(out['animations'])}")


def main() -> None:
    for stage in EXPECTED_STAGES:
        build(stage)
    print(f"BOSS_RUNTIME_PACK stages={len(EXPECTED_STAGES)} poses={len(EXPECTED_STAGES) * 4}")


if __name__ == "__main__":
    main()
