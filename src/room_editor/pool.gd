class_name RoomTemplatePool
extends RefCounted
const BUILTIN := "res://assets/room_templates"
const USER := "user://room_templates"
const RETIRED_IDS := ["illustrated_tavern_v01","illustrated_forest_v01"]

static func replacement_id(layout:Dictionary)->String:
	if str(layout.get("template_id",""))=="illustrated_tavern_v01" or str(layout.get("scene_art",""))=="tavern_v01":return "tavern_waterfront"
	if str(layout.get("template_id",""))=="illustrated_forest_v01" or str(layout.get("scene_art",""))=="forest_v01":return "forest_clearing"
	return ""
## Keep this relative to the launched project: the formal launcher shares the
## game's custom rooms, while the test project has an isolated user directory.
## Neither editor nor pool loads the player's save/story files.
var templates: Array[Dictionary] = []
var rejected: Dictionary = {}
var _loaded_signature:Dictionary={}
static var _cached_templates:Array[Dictionary]=[]
static var _cached_rejected:Dictionary={}
static var _cache_ready:=false
static var _cached_signature:Dictionary={}

static func _template_paths()->Array[String]:
	var paths:Array[String]=[]
	for root in [BUILTIN,USER]:
		var dir:=DirAccess.open(root)
		if dir==null:continue
		var files:=dir.get_files();files.sort()
		for filename in files:
			if filename.ends_with(".json"):paths.append(root+"/"+filename)
	return paths

static func _file_signature(path:String)->String:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return "missing"
	var length:=file.get_length()
	file.close()
	# Content hash catches edits made within a clock tick at the same size.
	return "%d:%d:%s"%[FileAccess.get_modified_time(path),length,FileAccess.get_md5(path)]

static func _signature(paths:Array[String])->Dictionary:
	var result:Dictionary={}
	for path in paths:result[path]=_file_signature(path)
	return result

static func _cache_matches(signature:Dictionary)->bool:
	return _cache_ready and _cached_signature==signature

func _use_cache(signature:Dictionary)->bool:
	if not _cache_matches(signature):return false
	templates.clear()
	for item in _cached_templates:templates.append(item.duplicate(true))
	rejected=_cached_rejected.duplicate(true)
	_loaded_signature=signature.duplicate(true)
	return true

func _store_cache(signature:Dictionary)->void:
	_cached_templates.clear()
	for item in templates:_cached_templates.append(item.duplicate(true))
	_cached_rejected=rejected.duplicate(true)
	_cached_signature=signature.duplicate(true)
	_loaded_signature=signature.duplicate(true)
	_cache_ready=true

func _accept_file(path:String)->void:
	var data := RoomTemplateCodec.read_file(path)
	# Also exclude old custom copies of a template removed from the game.
	if str(data.get("id","")) in RETIRED_IDS:return
	var errors := RoomTemplateValidator.load_errors(data)
	if not errors.is_empty():rejected[path]=errors;return
	for i in templates.size():
		if templates[i].id==data.id:templates[i]=data;return
	templates.append(data)

func reload() -> void:
	templates.clear();rejected.clear()
	var paths:=_template_paths()
	var signature:=_signature(paths)
	for path in paths:_accept_file(path)
	_store_cache(signature)

func ensure_loaded_async(tree:SceneTree, keep_loading:Callable=Callable())->bool:
	var paths:=_template_paths()
	var signature:Dictionary={}
	var frame_start:=Time.get_ticks_usec()
	for path in paths:
		if Time.get_ticks_usec()-frame_start>=3000:
			await tree.process_frame;frame_start=Time.get_ticks_usec()
		if not keep_loading.is_null() and (not keep_loading.is_valid() or not bool(keep_loading.call())):return false
		signature[path]=_file_signature(path)
	if _use_cache(signature):return true
	templates.clear();rejected.clear()
	for path in paths:
		# Validation can be expensive. Give the covering animation a frame
		# between templates, and keep all Resource/SceneTree work on this thread.
		if Time.get_ticks_usec()-frame_start>=3000:
			await tree.process_frame;frame_start=Time.get_ticks_usec()
		if not keep_loading.is_null() and (not keep_loading.is_valid() or not bool(keep_loading.call())):return false
		_accept_file(path)
	_store_cache(signature)
	return true

func select(seed_value: int, kind:String,theme:String,chapter:StringName=ChapterCatalog.FIRST,verify_changes:=true)->Dictionary:
	var signature:=_signature(_template_paths()) if verify_changes else _loaded_signature
	if not _cache_matches(signature):reload()
	elif templates.is_empty() or _loaded_signature!=signature:_use_cache(signature)
	var candidates: Array[Dictionary] = []
	var exact: Array[Dictionary] = []
	var boss_id := kind.trim_prefix("boss:") if kind.begins_with("boss:") else ""
	var room_kind := "boss" if not boss_id.is_empty() else kind
	for item in templates:
		if item.room_kinds.has("camp"):continue
		if not ChapterCatalog.allows(item,chapter,room_kind):continue
		if not item.room_kinds.has(room_kind):continue
		if not boss_id.is_empty() and not item.tags.has("boss:"+boss_id):continue
		candidates.append(item)
		if item.theme==theme:exact.append(item)
	if kind in ["shop","tavern"] and not exact.is_empty():candidates=exact
	if candidates.is_empty():return {}
	var total := 0.0
	for item in candidates:total+=selection_weight(item,kind)
	if total<=0:return {}
	var rng := RandomNumberGenerator.new();rng.seed=seed_value^0x46b3af
	var roll := rng.randf()*total
	for item in candidates:
		roll-=selection_weight(item,kind)
		if roll<=0:return item.duplicate(true)
	return candidates[-1].duplicate(true)

static func selection_weight(item:Dictionary,kind:String)->float:
	return maxf(0,float(item.get("selection_weight",1))) if kind in ["shop","tavern"] else 1.0
