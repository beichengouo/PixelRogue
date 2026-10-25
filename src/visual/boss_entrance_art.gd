class_name BossEntranceArt
extends RefCounted
## Bounded cache; active presentations retain their own pack.
const ROOT:="res://assets/boss_entrances_v01/"
const COLORS:={"king":"e9bd64","mage":"b88cff","tide":"74d7aa","sephra":"c5dce8","verena":"edc287","nameless":"83d5f4"}
static var _packs:Dictionary={}
static var _order:Array[String]=[]
static var _bounds:Dictionary={}
static var _warming:Dictionary={}
const SUBTITLE_ROOT:="res://assets/boss_subtitles_v15/"
static var _subtitle_bounds:Dictionary={}
static func subtitle_texture(id:String)->Texture2D:
	var path:=SUBTITLE_ROOT+id+".png"
	if not ResourceLoader.exists(path):return null
	if _subtitle_bounds.is_empty() and FileAccess.file_exists(SUBTITLE_ROOT+"bounds.json"):_subtitle_bounds=JSON.parse_string(FileAccess.get_file_as_string(SUBTITLE_ROOT+"bounds.json"))
	var source:=load(path) as Texture2D;var spec:Array=_subtitle_bounds.get(id,[])
	if spec.size()!=4:return source
	var art:=AtlasTexture.new();art.atlas=source;art.region=Rect2(spec[0],spec[1],spec[2],spec[3]).grow(4).intersection(Rect2(Vector2.ZERO,source.get_size()));art.filter_clip=true;return art
static func title_texture(id:String,path:String)->Texture2D:
	if not ResourceLoader.exists(path):return null
	var source:=load(path) as Texture2D
	if _bounds.is_empty() and FileAccess.file_exists(ROOT+"art_bounds.json"):_bounds=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"art_bounds.json"))
	var spec:Array=_bounds.get(id+"_title",[])
	if spec.size()!=4:return source
	var tile:=AtlasTexture.new();tile.atlas=source;tile.region=Rect2(spec[0],spec[1],spec[2],spec[3]).grow(12).intersection(Rect2(Vector2.ZERO,source.get_size()));tile.filter_clip=true;return tile
static func for_room(record:Dictionary,chapter:StringName)->String:
	return str(record.get("boss","")) if str(record.get("kind",""))!="boss_rush" or not str(record.get("boss","")).is_empty() else str(ChapterCatalog.bosses(chapter)[0])
static func paths(id:String)->Array[String]:return [ROOT+id+"_portrait.png",ROOT+id+"_title.png",ROOT+id+".wav",ROOT+id+"_motif.png",SUBTITLE_ROOT+id+".png"]
static func pack(id:String)->Dictionary:
	if not _packs.has(id):
		var files:=paths(id)
		var motif:Array[Texture2D]=[]
		if ResourceLoader.exists(files[3]):motif.append(load(files[3]) as Texture2D)
		else:motif.assign(HostileAttackFX.frames(id,"cast"))
		_packs[id]={"portrait":load(files[0]) if ResourceLoader.exists(files[0]) else PixelBossArt.icon(StringName(id)),"title":title_texture(id,files[1]),"sound":load(files[2]) if ResourceLoader.exists(files[2]) else null,"motif":motif,"foreground":motif,"color":Color(COLORS.get(id,"e9bd64"))}
		_packs[id]["subtitle"]=subtitle_texture(id)
	_order.erase(id);_order.append(id)
	while _order.size()>2:_packs.erase(_order.pop_front())
	return _packs[id]
static func warm_async(tree:SceneTree,id:String)->void:
	if not COLORS.has(id):return
	if _warming.has(id):
		while _warming.has(id):await tree.process_frame
		return
	_warming[id]=true
	var held:Array[Resource]=[]
	for path in paths(id):
		if not ResourceLoader.exists(path):continue
		if ResourceLoader.has_cached(path):held.append(load(path));continue
		if ResourceLoader.load_threaded_request(path)!=OK:continue
		var status:=ResourceLoader.load_threaded_get_status(path)
		while status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame;status=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:held.append(ResourceLoader.load_threaded_get(path))
	pack(id)
	_warming.erase(id)
