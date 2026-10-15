class_name WeaponBuildFX
extends Node2D
## Non-additive pixel animations; damage and collision remain in combat systems.
const ROOT := "res://assets/builds_vnext/weapons/"
const CELL := 96
const NEW_WEAPONS := ["staff_ember_flower","staff_star_weave","staff_wind_branch","staff_soul_command","staff_dusk_lantern"]
const LEGENDARY := ["staff_ember_flower","staff_star_weave","staff_wind_branch","staff_soul_command","staff_dusk_lantern","staff_starorbit","warhammer_gold"]
const EFFECT_WEAPONS := {"ember_flower":"staff_ember_flower","star_weave":"staff_star_weave","wind_branch":"staff_wind_branch","soul_command":"staff_soul_command","dusk_lantern":"staff_dusk_lantern"}
static var _frames: Dictionary = {}
var textures: Array[Texture2D] = []
var sprite: Sprite2D
var age := 0.0
var duration := 0.25
var strength := 1.0
var trail_mode := false

static func frames(id: String, phase: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var key := id + "_" + phase
	if _frames.has(key):return _frames[key]
	var path := ROOT + key + ".png"
	if not ResourceLoader.exists(path):return result
	var sheet := load(path) as Texture2D
	if sheet == null or sheet.get_size()!=Vector2(384,96):return result
	for index in 4:
		var frame := AtlasTexture.new()
		frame.atlas=sheet;frame.region=Rect2(index*CELL,0,CELL,CELL);frame.filter_clip=true
		result.append(frame)
	_frames[key]=result
	return result

static func pulse(parent: Node, at: Vector2, effect_id: String, phase := "proc", width := 72.0, angle := 0.0) -> WeaponBuildFX:
	var id: String = str(EFFECT_WEAPONS.get(effect_id,effect_id))
	if not is_instance_valid(parent) or not parent.is_inside_tree():return null
	if parent.get_tree().get_nodes_in_group("legendary_full_impact").size()>=24:
		if phase in ["impact","proc"]:Effects.hit_spark(parent,at,Color("c7aeff"),2)
		return null
	var selected := frames(id,phase)
	if selected.is_empty():return null
	var fx := WeaponBuildFX.new();fx.textures=selected
	fx.sprite=Sprite2D.new();fx.sprite.texture=selected[0];fx.sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	fx.sprite.scale=Vector2.ONE*width/CELL;fx.add_child(fx.sprite)
	parent.add_child(fx);fx.global_position=at;fx.rotation=angle;fx.z_index=6
	fx.add_to_group("legendary_full_impact")
	fx.strength=clampf(float(SaveService.data.get("spell_fx_strength",1.0)),0,1)
	fx.modulate.a=fx.strength*.8
	return fx

static func impact(parent: Node, at: Vector2, id: String, width: float, angle := 0.0) -> void:
	if id in LEGENDARY:pulse(parent,at,id,"impact",width,angle)

static func trail(parent: Node, at: Vector2, id: String, angle: float) -> void:
	if ComicMotion.reduced() or not is_instance_valid(parent) or parent.get_tree().get_nodes_in_group("legendary_trails").size()>=36:return
	var selected: Array[Texture2D] = frames(id,"flight") if id in NEW_WEAPONS else WeaponArt.frames(id+"_flight")
	if selected.is_empty():return
	var fx := WeaponBuildFX.new();fx.textures=selected;fx.trail_mode=true;fx.duration=.14
	fx.sprite=Sprite2D.new();fx.sprite.texture=selected[0];fx.sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	fx.sprite.scale=Vector2.ONE*20/selected[0].get_width();fx.add_child(fx.sprite)
	parent.add_child(fx);fx.global_position=at;fx.rotation=angle;fx.z_index=4
	fx.add_to_group("legendary_trails");fx.strength=clampf(float(SaveService.data.get("spell_fx_strength",1.0)),0,1)*.23
	fx.modulate.a=fx.strength

func _process(delta: float) -> void:
	age+=delta
	if age>=duration:queue_free();return
	sprite.texture=textures[mini(3,int(age*16))]
	modulate.a=strength*(1-age/duration) if trail_mode else strength*.8*(1-clampf((age/duration-.75)*4,0,1))
