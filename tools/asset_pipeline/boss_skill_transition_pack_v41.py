"""Pack V41 boss skill-mid art; explicitly admit only complete runtime sets.

Each V41 stage atlas contains the four audited V40 whole-body poses plus one
new, independently drawn middle pose for every available skill index. Missing
skills remain explicit in metadata. The default manifest remains a candidate;
``--admit`` requires all 74 drawings and the V41 live loader.
"""

from __future__ import annotations

import hashlib
import argparse
import json
import math
import re
from pathlib import Path

from PIL import Image


PROJECT = Path(__file__).resolve().parents[2]
BASE_SOURCE = PROJECT / "art_src" / "boss_redraw_v40" / "poses"
BASE_AUDIT = BASE_SOURCE / "audit.json"
MID_SOURCE = PROJECT / "art_src" / "boss_redraw_v40" / "skill_transitions"
SELECTION = MID_SOURCE / "selection.json"
BASE_RUNTIME = PROJECT / "assets" / "boss_stages_v40"
OUTPUT = PROJECT / "assets" / "boss_stages_v41"
RUNTIME_LOADER = PROJECT / "src" / "visual" / "boss_stage_art.gd"
STAGES = (
    "king_1", "king_2", "mage_1", "mage_2", "tide_1", "tide_2", "tide_3",
    "sephra_1", "sephra_2", "verena_1", "verena_2",
    "nameless_1", "nameless_2", "nameless_3",
)
BASE_POSES = ("idle", "move", "windup", "release")
SKILL_MID_FILE = re.compile(r"skill_(\d+)_mid\.png")
SKILL_ACTION = re.compile(r"skill_(\d+)_(windup|release)")
CELL = 960
INSET = 72
COLUMNS_MAX = 8
ALPHA_THRESHOLD = 46


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def painted_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    mask = image.getchannel("A").point(lambda a: 255 if a >= ALPHA_THRESHOLD else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("empty painted pose")
    return bounds


def load_pose(path: Path, *, expected_sha: str = "", expected_used: list[int] | None = None) -> tuple[Image.Image, tuple[int, int, int, int], str]:
    digest = sha(path)
    if expected_sha and digest != expected_sha:
        raise ValueError(f"{path}: SHA differs from V40 source audit")
    with Image.open(path) as raw:
        if "A" not in raw.getbands() and "transparency" not in raw.info:
            raise ValueError(f"{path}: source has no alpha channel")
        image = raw.convert("RGBA")
    bounds = painted_bounds(image)
    left, top, right, bottom = bounds
    if expected_used is not None and [left, top, right - left, bottom - top] != expected_used:
        raise ValueError(f"{path}: painted bounds differ from V40 source audit")
    if min(left, top, image.width - right, image.height - bottom) < 1:
        raise ValueError(f"{path}: painted pose touches source canvas edge")
    if bottom - top < 600:
        raise ValueError(f"{path}: painted figure too small for a 2K model")
    for x, y in ((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)):
        if image.getpixel((x, y))[3] >= ALPHA_THRESHOLD:
            raise ValueError(f"{path}: opaque corner / likely background")
    return image, bounds, digest


def required_skills(animations: dict[str, dict]) -> list[int]:
    return sorted({int(match.group(1)) for name in animations if (match := SKILL_ACTION.fullmatch(name))})


def discovered_mids(stage: str, required: list[int]) -> dict[int, Path]:
    folder = MID_SOURCE / stage
    if not folder.exists():
        return {}
    found: dict[int, Path] = {}
    for path in sorted(folder.glob("*.png")):
        match = SKILL_MID_FILE.fullmatch(path.name)
        if match is None:
            raise ValueError(f"{stage}: unexpected PNG in accepted source directory: {path.name}")
        index = int(match.group(1))
        if index not in required:
            raise ValueError(f"{stage}: skill {index} has no action in V40 contract")
        if index in found:
            raise ValueError(f"{stage}: duplicate skill {index}")
        found[index] = path
    return found


def verify_admitted_selection() -> None:
    """Freeze the 74 approved skill drawings before changing admitted atlases."""
    selection = json.loads(SELECTION.read_text(encoding="utf-8"))
    if selection.get("revision") != 41 or selection.get("skill_count") != 74:
        raise ValueError("V41 accepted source selection has wrong revision or skill count")
    stages = selection.get("stages", {})
    if set(stages) != set(STAGES):
        raise ValueError("V41 accepted source selection does not list exactly 14 stages")
    seen = 0
    for stage in STAGES:
        expected = stages[stage]
        actual = {path.stem: sha(path) for path in (MID_SOURCE / stage).glob("skill_*_mid.png")}
        if actual != expected:
            raise ValueError(f"{stage}: accepted skill source set or SHA differs from selection.json")
        seen += len(actual)
    if seen != 74:
        raise ValueError(f"V41 accepted source count is {seen}, expected 74")


def sequence(action: str, slots: int, covered: set[int]) -> list[str]:
    match = SKILL_ACTION.fullmatch(action)
    if match and int(match.group(1)) in covered:
        mid = f"skill_{int(match.group(1))}_mid"
        if match.group(2) == "windup":
            return ["idle" if index == 0 else "windup" if index < max(2, slots // 2) else mid for index in range(slots)]
        return [mid if index == 0 else "idle" if index == slots - 1 else "release" for index in range(slots)]
    result: list[str] = []
    for index in range(slots):
        pose = "idle"
        if action == "move":
            pose = "move" if index > 0 else "idle"
        elif action == "transform":
            pose = "idle" if index < 2 or index >= slots - 2 else "windup" if index < slots / 2 else "release"
        elif action.endswith("windup"):
            pose = "windup" if index > 0 else "idle"
        elif action.endswith("release"):
            pose = "release" if index > 0 else "windup"
        result.append(pose)
    return result


def pack_stage(stage: str, audit: dict) -> dict:
    base = json.loads((BASE_RUNTIME / f"{stage}.json").read_text(encoding="utf-8"))
    if base["revision"] != 40 or base["cell"] != CELL:
        raise ValueError(f"{stage}: expected V40 960-cell base")
    required = required_skills(base["animations"])
    mid_files = discovered_mids(stage, required)
    names = list(BASE_POSES) + [f"skill_{index}_mid" for index in sorted(mid_files)]
    sources: dict[str, Image.Image] = {}
    bounds: dict[str, tuple[int, int, int, int]] = {}
    hashes: dict[str, str] = {}
    for pose in BASE_POSES:
        item = audit["sets"][stage][pose]
        path = BASE_SOURCE / stage / f"{pose}.png"
        sources[pose], bounds[pose], hashes[pose] = load_pose(path, expected_sha=item["sha256"], expected_used=item["used"])
    for index, path in sorted(mid_files.items()):
        name = f"skill_{index}_mid"
        sources[name], bounds[name], hashes[name] = load_pose(path)
    trims: dict[str, tuple[int, int, int, int]] = {}
    for name, image in sources.items():
        left, top, right, bottom = bounds[name]
        trims[name] = (max(0, left - 2), max(0, top - 2), min(image.width, right + 2), min(image.height, bottom + 2))
    max_extent = max(max(trim[2] - trim[0], trim[3] - trim[1]) for trim in trims.values())
    factor = min(1.0, (CELL - 2 * INSET) / max_extent)
    cols = min(COLUMNS_MAX, len(names))
    rows = math.ceil(len(names) / cols)
    atlas = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    baseline = CELL - INSET
    poses: dict[str, dict] = {}
    for index, name in enumerate(names):
        source = sources[name]
        trim = trims[name]
        left, top, right, bottom = bounds[name]
        cropped = source.crop(trim)
        width, height = round(cropped.width * factor), round(cropped.height * factor)
        image = cropped.resize((width, height), Image.Resampling.LANCZOS)
        col, row = index % cols, index // cols
        x = col * CELL + (CELL - width) // 2
        y = row * CELL + baseline - round((bottom - trim[1]) * factor)
        if x < col * CELL or x + width > (col + 1) * CELL or y < row * CELL or y + height > (row + 1) * CELL:
            raise ValueError(f"{stage}/{name}: scaled pose exceeds atlas cell")
        atlas.alpha_composite(image, (x, y))
        painted = [
            x - col * CELL + round((left - trim[0]) * factor),
            y - row * CELL + round((top - trim[1]) * factor),
            x - col * CELL + round((right - trim[0]) * factor),
            y - row * CELL + round((bottom - trim[1]) * factor),
        ]
        if painted[3] != baseline or min(painted[:2]) < 0 or max(painted[2:]) > CELL:
            raise ValueError(f"{stage}/{name}: packed painted bounds invalid")
        poses[name] = {
            "index": index, "column": col, "row": row,
            "source_sha256": hashes[name], "source_canvas": list(source.size),
            "source_used": [left, top, right - left, bottom - top],
            "trim": list(trim), "painted_bounds": painted,
        }
    body_height = (bounds["idle"][3] - bounds["idle"][1]) * factor
    if body_height < 500:
        raise ValueError(f"{stage}: idle painted height dropped below 500 in V41 cell")
    covered = sorted(mid_files)
    pending = [index for index in required if index not in mid_files]
    result = {
        "revision": 41, "base_revision": 40, "cell": CELL,
        "columns": cols, "rows": rows, "foot": [CELL // 2, baseline],
        "body_height": round(body_height, 3),
        "source_pose_count": len(names),
        "animation_kind": "skill_mid_key_poses_complete" if not pending else "skill_mid_key_poses_partial",
        "skill_transition_coverage": {
            "required": required, "covered": covered, "pending": pending,
            "complete": not pending,
        },
        "poses": poses,
        "animations": {
            name: {
                "fps": spec["fps"], "slots": spec["slots"],
                "pose_sequence": sequence(name, int(spec["slots"]), set(covered)),
            }
            for name, spec in base["animations"].items()
        },
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    png = OUTPUT / f"{stage}.png"
    temp_png = png.with_suffix(".png.tmp")
    atlas.save(temp_png, format="PNG", optimize=True)
    temp_png.replace(png)
    metadata = OUTPUT / f"{stage}.json"
    temp_json = metadata.with_suffix(".json.tmp")
    temp_json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp_json.replace(metadata)
    print(f"BOSS_V41 {stage} covered={len(covered)}/{len(required)} poses={len(names)} atlas={cols}x{rows}")
    return {"stage": stage, "covered": covered, "pending": pending, "pose_count": len(names), "atlas_sha256": sha(png), "metadata_sha256": sha(metadata)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--admit", action="store_true", help="mark the complete V41 atlas set as the live runtime set")
    args = parser.parse_args()
    if args.admit:
        verify_admitted_selection()
    audit = json.loads(BASE_AUDIT.read_text(encoding="utf-8"))
    stages = [pack_stage(stage, audit) for stage in STAGES]
    required_count = sum(len(item["covered"]) + len(item["pending"]) for item in stages)
    covered_count = sum(len(item["covered"]) for item in stages)
    if args.admit:
        if required_count != 74 or covered_count != required_count or any(item["pending"] for item in stages):
            raise ValueError(f"cannot admit incomplete V41 skill transitions: {covered_count}/{required_count}")
        loader = RUNTIME_LOADER.read_text(encoding="utf-8")
        if 'const ROOT:="res://assets/boss_stages_v41/"' not in loader:
            raise ValueError("cannot admit V41: BossStageArt runtime loader has not switched to V41")
    manifest = {
        "revision": 41,
        "candidate_only": not args.admit,
        "runtime_loader_switched": bool(args.admit),
        "stage_count": len(stages),
        "required_skill_transitions": required_count,
        "covered_skill_transitions": covered_count,
        "stages": stages,
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"BOSS_V41_PACK stages={manifest['stage_count']} covered={manifest['covered_skill_transitions']}/{manifest['required_skill_transitions']}")


if __name__ == "__main__":
    main()
