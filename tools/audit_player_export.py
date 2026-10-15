"""Conservative player-export audit; authoring files remain in the project.

Retain literal references, dynamic directory/prefix loads, resource dependencies,
JSON catalogues and their relative image paths. Only export exclusions change.
Run with --apply after reviewing the printed candidates.
"""
from pathlib import Path
import argparse
import json
import re

PROJECT = Path(__file__).resolve().parents[1]
DEVELOPMENT = [
    "tests/*", "tools/*", "docs/*", "art_src/*", "*.md", "AGENTS.md",
    "src/release_qa/*", "addons/pixelrogue_map_tools/*", "*.cs",
    "addons/dialogue_manager/*",
    "src/room_editor/editor.gd", "src/room_editor/canvas.gd",
    "src/room_editor/preview.gd", "src/room_editor/playtest*",
    "src/room_editor/invincible_player.gd", "assets/map_editor/*",
    "src/world/level_backup*.tscn",
    "src/world/level.tscn", "assets/environment/terrain_v2.tres",
    "addons/dialogue_manager/example_balloon/ExampleBalloon.tscn",
    "addons/dialogue_manager/example_balloon/SmallExampleBalloon.tscn",
    "addons/dialogue_manager/nodes/dialogue_label/DialogueLabel.tscn",
]
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".json", ".godot"}
REFERENCE = re.compile(r'res://([^\s\"\'<>\)\]\}]+)')


def audit():
    import fnmatch
    files = [p for p in PROJECT.rglob("*") if p.is_file()
             and ".godot" not in p.relative_to(PROJECT).parts]
    references, prefixes = set(), set()
    def excluded(path):
        return any(fnmatch.fnmatchcase(path, pattern) for pattern in DEVELOPMENT)
    def add(reference):
        reference = reference.rstrip(",;")
        if not reference or reference.startswith("%"): return
        if "%" in reference:
            prefixes.add(reference.split("%", 1)[0])
        elif (PROJECT / reference).is_file():
            references.add(reference)
        elif reference.endswith("/") or (PROJECT / reference).is_dir():
            prefixes.add(reference.rstrip("/") + "/")
        elif not Path(reference).suffix:
            prefixes.add(reference)
    def json_paths(value, folder):
        if isinstance(value, dict):
            for v in value.values(): json_paths(v, folder)
        elif isinstance(value, list):
            for v in value: json_paths(v, folder)
        elif isinstance(value, str):
            if value.startswith("res://"): add(value[6:])
            elif (folder / value).is_file():
                references.add((folder / value).relative_to(PROJECT).as_posix())
    for p in files:
        rel = p.relative_to(PROJECT).as_posix()
        if excluded(rel) or p.suffix not in TEXT_SUFFIXES: continue
        content = p.read_text(encoding="utf-8-sig", errors="replace")
        # A portrait path allow-list checks the namespace, not a dynamic load
        # of every asset. Concrete dialogue portrait paths are scanned below.
        content = content.replace('.begins_with("res://assets/")', '')
        for reference in REFERENCE.findall(content): add(reference)
        if p.suffix == ".json":
            try: json_paths(json.loads(content), p.parent)
            except ValueError: pass
    # Executable icons are export inputs, outside the runtime dependency graph.
    preset = (PROJECT / "export_presets.cfg").read_text(encoding="utf-8-sig")
    for reference in re.findall(r'^application/[^=]*icon="res://([^"]+)"', preset, flags=re.M):
        add(reference)
    candidates = []
    for p in files:
        rel = p.relative_to(PROJECT).as_posix()
        if not rel.startswith("assets/") or p.suffix in {".import", ".uid", ".json"}: continue
        if "license" in p.name.lower(): continue
        if excluded(rel): continue
        if rel not in references and not any(rel.startswith(prefix) for prefix in prefixes):
            candidates.append((rel, p.stat().st_size))
    return sorted(candidates), sorted(references), sorted(prefixes)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    candidates, references, prefixes = audit()
    print(f"Dynamic prefixes retained: {len(prefixes)}")
    for prefix in prefixes: print("KEEP", prefix)
    print(f"Unreferenced export candidates: {len(candidates)}")
    for path, size in sorted(candidates, key=lambda item: -item[1]):
        print(f"{size / 1048576:8.2f} MiB {path}")
    if args.report:
        args.report.write_text(json.dumps({"excluded_assets": candidates,
            "references": references, "dynamic_prefixes": prefixes}, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.apply:
        preset = PROJECT / "export_presets.cfg"
        text = preset.read_text(encoding="utf-8-sig")
        # Recompute managed exclusions so a later gameplay reference brings an
        # asset back into the export instead of silently retaining a stale rule.
        manifest = PROJECT / "tools" / "player_export_exclusions.json"
        previous = set(json.loads(manifest.read_text(encoding="utf-8"))) if manifest.exists() else set()
        def replace_filters(match):
            filters = list(dict.fromkeys([p for p in match[1].split(",") if p not in previous]
                + DEVELOPMENT + [p for p, _ in candidates]))
            return 'exclude_filter="' + ",".join(filters) + '"'
        text = re.sub(r'^exclude_filter="(.*)"$', replace_filters, text, flags=re.M)
        preset.write_text(text, encoding="utf-8")
        manifest.write_text(json.dumps([p for p, _ in candidates], ensure_ascii=False, indent=2), encoding="utf-8")
        print("Updated player export exclusions; source assets preserved.")


if __name__ == "__main__": main()
