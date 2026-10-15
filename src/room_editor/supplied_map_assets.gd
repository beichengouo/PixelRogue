class_name SuppliedMapAssets
extends RefCounted
## User supplied art has stable IDs and remains decorative until a gameplay role is authored.
const CATALOG := "res://assets/supplied_20261011/editor_catalog.json"
const EXTRA_CATALOG := "res://assets/quality_20261011/editor/editor_catalog.json"
const CATEGORIES := ["新素材 · 树木", "新素材 · 花卉", "新素材 · 灌木", "新素材 · 营火", "新素材 · 云", "新素材 · 闪电", "新素材 · 动画", "新素材 · 火把", "地下城 · 地面", "地下城 · 障碍", "地下城 · 装饰"]
static var _entries: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _animations: Dictionary = {}
static var _textures: Dictionary = {}
static var _stamps: Dictionary = {}

static func clear_cache() -> void:
	_entries.clear();_by_id.clear();_animations.clear();_textures.clear();_stamps.clear()

static func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		for catalog in [CATALOG,EXTRA_CATALOG]:
			if not FileAccess.file_exists(catalog):continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog))
			if parsed is Array:
				for entry in parsed:
					if entry is Dictionary and not _by_id.has(str(entry.id)):
						_entries.append(entry)
						_by_id[str(entry.id)] = entry
	return _entries

static func get_entry(asset_id: String) -> Dictionary:
	entries()
	return _by_id.get(asset_id, {})

static func sprite_frames(asset_id: String) -> SpriteFrames:
	var entry := get_entry(asset_id)
	var path := str(entry.get("animation_path", ""))
	if path.is_empty():return null
	if not _animations.has(path):_animations[path] = load(path) as SpriteFrames
	return _animations[path] as SpriteFrames

static func texture(asset_id: String, seconds := 0.0) -> Texture2D:
	var entry := get_entry(asset_id)
	if entry.is_empty():return null
	var frames := sprite_frames(asset_id)
	if frames != null:
		var index := posmod(floori(seconds * frames.get_animation_speed(&"default")), frames.get_frame_count(&"default"))
		return _stamp(entry,frames.get_frame_texture(&"default", index),index)
	var path := str(entry.path)
	if not _textures.has(path):_textures[path] = load(path) as Texture2D
	return _stamp(entry,_textures[path] as Texture2D,0)

static func _stamp(entry:Dictionary,source:Texture2D,index:int)->Texture2D:
	if not bool(entry.get("repeat_cells",false)) or (int(entry.size[0])==1 and int(entry.size[1])==1):return source
	var key:=str(entry.id)+":%d"%index
	if _stamps.has(key):return _stamps[key]
	var original:=source.get_image()
	var cell:=original.get_width()
	var extra:=maxi(0,original.get_height()-cell)
	var image:=Image.create(cell*int(entry.size[0]),cell*int(entry.size[1])+extra,false,Image.FORMAT_RGBA8)
	for y in int(entry.size[1]):
		for x in int(entry.size[0]):
			image.blend_rect(original,Rect2i(Vector2i.ZERO,original.get_size()),Vector2i(x*cell,y*cell+maxi(0,cell-original.get_height())))
	var result:=ImageTexture.create_from_image(image)
	_stamps[key]=result
	return result
