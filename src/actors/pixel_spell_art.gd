class_name PixelSpellArt
extends RefCounted
## 保留原创透明 PNG；使用导入尺寸和图集元数据定位，避免串帧。
const DIR := "res://assets/pixel_batch3/"
const LOGICAL_SIZE := 144.0
static var _cache: Dictionary = {}
static var _metadata: Dictionary = {}
static var _material: ShaderMaterial

static func frames(family: String) -> Array[Texture2D]:
	if _cache.has(family):
		return _cache[family]
	if _metadata.is_empty():
		_metadata = JSON.parse_string(FileAccess.get_file_as_string(DIR + "atlas_metadata.json"))
	var path := family + "_vfx_v1.png"
	var source := load(DIR + path) as Texture2D
	var info: Dictionary = _metadata[path]
	var ratio := float(source.get_width()) / float(info.source_size[0])
	var result: Array[Texture2D] = []
	for region: Array in info.regions:
		var start := Vector2(roundf(float(region[0]) * ratio), roundf(float(region[1]) * ratio))
		var end := Vector2(roundf(float(region[0] + region[2]) * ratio), roundf(float(region[1] + region[3]) * ratio))
		var texture := AtlasTexture.new()
		texture.atlas = source
		texture.region = Rect2(start, end - start)
		texture.margin = Rect2((Vector2.ONE * LOGICAL_SIZE - texture.region.size) * 0.5, Vector2.ONE * LOGICAL_SIZE - texture.region.size)
		texture.filter_clip = true
		result.append(texture)
	_cache[family] = result
	return result

static func tint(family: String) -> Color:
	return Color("8fdb9b") if family == "nature" else (Color("c4aaff") if family == "star" else Color("ffae65"))

static func strength() -> float:
	# The effect library also loads in editor/test previews without autoloads.
	# Resolve settings at call time to avoid retaining the SaveService script.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return 1.0
	var settings := tree.root.get_node_or_null("SaveService")
	if not is_instance_valid(settings): return 1.0
	return clampf(float(settings.data.get("spell_fx_strength", 1.0)), 0.0, 1.0)

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://src/actors/pixel_spell_material.gdshader")
	return _material
