class_name GlowMushroom
extends Node2D
## 原创八种菌光蘑菇：四帧贴地生长，成熟后可采集。
const FRAME := WorldPropArt.FRAME_SIZE
const GROW_SECONDS:=3.8
static var _frames:Dictionary={}
const ART_SCALE := 0.175
const SIT_OFFSET := 10.6875

## 八种颜色的菌光（从素材每帧的主色里取的）
const GLOW_COLORS := [
	Color("ff9a5c"), Color("ffb03c"), Color("4fd8d8"), Color("6ee06e"),
	Color("d07bd0"), Color("e08a3c"), Color("e06a8a"), Color("e8e8f0"),
]

const HARVEST_RANGE := 78.0

var kind := 0
var player: Node2D
var level: Level
var in_range := false

var _sprite: Sprite2D
var _glow: Sprite2D
var _light: PointLight2D
var _bob := 0.0
var _grow := 0.0
var _harvested := false
## 这一种蘑菇的光强倍率（稀有度越高越亮）
var _glow_scale := 1.0


func setup(level_node: Level, player_node: Node2D, kind_index: int) -> void:
	level = level_node
	player = player_node
	kind = clampi(kind_index, 0, GLOW_COLORS.size() - 1)


func _ready() -> void:
	z_index = 2
	add_to_group("mushrooms")
	var atlas := function_frame()
	_sprite = Sprite2D.new()
	_sprite.texture = atlas
	_sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	_sprite.position=Vector2(0,SIT_OFFSET-(60.0-FRAME*.5)*ART_SCALE)
	add_child(_sprite)
	_glow=Sprite2D.new();_glow.texture=function_frame(true);_glow.scale=Vector2.ONE*ART_SCALE
	_glow.position=_sprite.position
	var material:=CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;_glow.material=material
	_glow.modulate=Color(1,1,1,0.18);add_child(_glow)
	# 小范围菌光；Compatibility 下保留原有无阴影光源。
	var tint: Color = GLOW_COLORS[kind]
	# 范围收小、能量略降：只在蘑菇脚下一小圈，夜里的大片黑才留得住。
	# 稀有蘑菇的光更亮更大 —— 远处看见一团强光就知道捡到宝了。
	# 不投影（原因见 level.gd 里 MOON_CASTS_SHADOW 那段实测结论：
	# 一开投影，2D 光源就完全不出光了）。
	_glow_scale = ItemDB.mushroom_glow(kind)
	_light = LightUtil.make_point_light(tint, 1.35 * _glow_scale, 150.0 * _glow_scale, false)
	_light.position = Vector2(0.0, -6.0)
	add_child(_light)
	# Each explicit atlas frame shares the same ground baseline.
	_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	scale=Vector2.ONE

func function_frame(_glow_frame := false)->Texture2D:
	var frame:=clampi(int(_grow*WorldPropArt.MUSHROOM_FRAMES),0,WorldPropArt.MUSHROOM_FRAMES-1)
	return WorldPropArt.mushroom_texture(kind,frame)


func _process(delta: float) -> void:
	if _harvested:return
	_bob += delta * 1.6
	_grow = minf(1.0, _grow + delta/GROW_SECONDS)
	# 贴地生长，只用菌光明暗表现呼吸。
	var breathe := 0.85 + 0.15 * sin(_bob)
	var grow_scale := ART_SCALE
	var ground_anchor := Vector2(0,SIT_OFFSET-(60.0-FRAME*0.5)*grow_scale)
	if _sprite != null:
		_sprite.position = ground_anchor
		_sprite.scale = Vector2.ONE*grow_scale
		_sprite.texture=function_frame()
	if _glow != null:
		_glow.position = ground_anchor
		_glow.scale = Vector2.ONE*grow_scale
		_glow.texture=function_frame(true)
		_glow.modulate.a = 0.16+0.04*sin(_bob)
	if _light != null:
		_light.energy = 1.35 * _glow_scale * breathe * _grow
	# 采集范围判定（和商店/酒馆一样，用距离）
	if player != null and is_instance_valid(player):
		var near := _grow>=1.0 and global_position.distance_to(player.global_position) <= HARVEST_RANGE
		if near != in_range:
			in_range = near
			if in_range:
				EventBus.interact_prompt_show.emit("按 [%s] 采集%s（%s）" % [UIFlow.hint(&"interact"),str(ItemDB.mushroom_def(kind).name),ItemDB.rarity_name(int(ItemDB.mushroom_def(kind).rarity))])
			else:
				EventBus.interact_prompt_hide.emit()


func try_interact() -> bool:
	## 被主节点调用：在范围内就采集掉，返回 true 表示这次 E 被消化了
	if _harvested or _grow<1.0 or not in_range:
		return false
	if not GameState.can_add_item(ItemDB.mushroom_item(kind)):
		Effects.text(get_parent(),global_position+Vector2(0,-36),"容量或999堆叠已满，蘑菇留在原地",Palette.UI_ACCENT,16)
		return true
	_harvested = true
	if in_range:
		EventBus.interact_prompt_hide.emit()
	var tint: Color = GLOW_COLORS[kind]
	var def := ItemDB.mushroom_def(kind)
	var rarity_name := ItemDB.rarity_name(int(def["rarity"]))
	Effects.hit_spark(get_parent(), global_position + Vector2(0.0, -10.0), tint, 12)
	# 采到稀有菇的时候把稀有度和卖价一起弹出来，让玩家知道捡到好东西了
	Effects.text(get_parent(), global_position + Vector2(0.0, -34.0),
		"采到 %s（%s）" % [str(def["name"]), rarity_name], tint, 19)
	if int(def["rarity"]) >= 2:
		Effects.text(get_parent(), global_position + Vector2(0.0, -58.0),
			"稀有素材 · 撤回入库用于兑换", Color("ffd166"), 17)
	AudioManager.play(&"coin", -4.0)
	GameState.add_item(ItemDB.mushroom_item(kind))
	# 采集动画：缩下去 + 光收掉，然后消失
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	if _light != null:
		tween.tween_property(_light, "energy", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
	return true


func _exit_tree() -> void:
	if in_range:
		EventBus.interact_prompt_hide.emit()
