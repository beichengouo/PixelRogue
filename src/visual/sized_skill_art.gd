class_name SizedSkillArt
extends RefCounted
## Authored HD masters have 512/1024 variants; gameplay geometry stays with callers.
const ROOT:="res://assets/skill_detail_v15/"
const HOLY:=["pillar","cloud","bell","court","judgment","sanctuary","ring","step"]
const ELF:={"trap":"elf_trap","spread_vine":"elf_trap","zone":"elf_trap","wild_zone":"elf_trap","tree":"elf_tree","tree_end":"elf_tree_end","seed_burst":"elf_tree_end","wind_burst":"elf_wind_burst","ultimate_end":"elf_wind_burst"}
static var _cache:Dictionary={}
static var _order:Array[String]=[]
static func tier(pixels:float)->int:return 512 if pixels<=512 else 1024
static func screen_extent(canvas:CanvasItem,size_value:Vector2)->float:
	var transform:=canvas.get_global_transform_with_canvas()
	return maxf(size_value.x*transform.x.length(),size_value.y*transform.y.length())
static func texture(id:String,pixels:float=1024)->Texture2D:
	var key:="%d/%s"%[tier(pixels),id]
	if not _cache.has(key):
		var path:=ROOT+key+".png"
		if not ResourceLoader.exists(path):return null
		_cache[key]=load(path)
	_order.erase(key);_order.append(key)
	while _order.size()>16:_cache.erase(_order.pop_front())
	return _cache[key]
static func paint(canvas:CanvasItem,id:String,rect:Rect2,phase:float,opacity:float)->bool:
	var art:=texture(id,screen_extent(canvas,rect.size))
	if art==null:return false
	var pulse:=1.0 if ComicMotion.reduced() else .94+.06*sin(phase*TAU)
	canvas.draw_texture_rect(art,rect,false,Color(pulse,pulse,pulse,opacity));return true
static func material()->ShaderMaterial:
	var effect:=ShaderMaterial.new();effect.shader=preload("res://shaders/skill_detail_v15.gdshader")
	effect.set_shader_parameter("still",ComicMotion.reduced());return effect
static func warm()->void:
	var ids:Array=[]
	match Characters.current_id():
		&"sylphiette":
			for style:String in HOLY:ids.append("holy_"+style)
		&"ilyua":ids=["elf_trap","elf_tree","elf_tree_end","elf_wind_burst"]
		&"xixifu":ids=["contract_call","contract_burst"]
	for id:String in ids:
		texture(id,512);texture(id,1024)
