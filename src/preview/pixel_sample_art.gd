class_name PixelSampleArt
extends RefCounted
## 图集只在引擎中取帧；保留生成原图与原角色文件。

const DIR := "res://assets/pixel_batch1/"
const HERO := DIR + "hero_sample_v1.png"
const MONSTER := DIR + "skeleton_sample_v1.png"
const UI := DIR + "ui_sample_v1.png"
static var _metadata: Dictionary = {}

static func cell(path: String, index: int) -> AtlasTexture:
	var source := load(path) as Texture2D
	var size := source.get_size() / 4.0
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(Vector2(index % 4, index / 4) * size, size)
	var regions: Array = metadata().get(path.get_file(), {}).get("regions", [])
	if index < regions.size():
		var rect: Array = regions[index]
		var ratio := source_ratio(path)
		atlas.region = Rect2(float(rect[0]) * ratio, float(rect[1]) * ratio, float(rect[2]) * ratio, float(rect[3]) * ratio)
	atlas.filter_clip = true
	return atlas

static func frames(path: String) -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	for spec in [[&"idle", 0, 4, 6.0, true], [&"run", 4, 8, 12.0, true], [&"cast", 12, 4, 12.0, false]]:
		var name := StringName(spec[0])
		result.add_animation(name)
		result.set_animation_speed(name, float(spec[3]))
		result.set_animation_loop(name, bool(spec[4]))
		for i in int(spec[2]):
			result.add_frame(name, cell(path, int(spec[1]) + i))
	return result

static func metadata() -> Dictionary:
	if not _metadata.is_empty():
		return _metadata
	var path := DIR + "atlas_metadata.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_metadata = parsed if parsed is Dictionary else {}
	return _metadata

static func world_scale(path: String, height: float) -> float:
	var data: Dictionary = metadata().get(path.get_file(), {})
	return height / (float(data.get("idle_height", 290.5)) * source_ratio(path))

static func source_ratio(path: String) -> float:
	var source := load(path) as Texture2D
	var original: Array = metadata().get(path.get_file(), {}).get("source_size", [source.get_width(), source.get_height()])
	return float(source.get_width()) / float(original[0])

static func frame_index(sprite: AnimatedSprite2D) -> int:
	return sprite.frame + (4 if sprite.animation == &"run" else 12 if sprite.animation == &"cast" else 0)

static func foot(path: String, index: int) -> float:
	var data: Dictionary = metadata().get(path.get_file(), {})
	var feet: Array = data.get("feet", [])
	return float(feet[index]) * source_ratio(path) if index < feet.size() else (load(path) as Texture2D).get_height() / 4.0 * 0.875
