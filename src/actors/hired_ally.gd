class_name HiredAlly
extends CharacterBody2D
## 酒馆雇佣来的帮手（在"本局"内存在，死了就永久消失）。
##
## 两种行为：
##   怪物（merc = false）：按 HireOffers 的战斗分类近身攻击或保持距离发射弹丸。
##   佣兵（merc = true）：持剑、短弓、飞刀与双刃四个角色，RoomAlly 负责攻击规则。
##
## 属性 = 基础值 × 酒馆随机倍率 × 召唤师装备加成（GameState.ally_bonus()）。
## 它们不吃玩家的天赋/装备加成，只吃"召唤师"那一类道具。

const KEEP_DIST := 240.0

var uid := ""
var is_merc := false
var enemy_kind: StringName = &"walker"
var display_name := "佣兵"
var max_hp := 60.0
var hp := 60.0
var shield_hp := 0.0
var shield_time := 0.0
var attack := 10.0
var move_speed := 90.0
var body_color := Color("8fd3ff")
var icon_path := ""

var player: Node2D
var level: Level
var fx_root: Node

var _sprite: AnimatedSprite2D
var _sprite_origin:=Vector2.ZERO
var _merc_index:=0
var _base_values:Dictionary={}
var _release_left:=0.0
var _hurt_left:=0.0
var _hire_wave:=1
var _hp_drawn := -1.0
var _night_shelter_visual:NightShelterFX
var _cooldown := 0.0
var equipment_haste_time := 0.0
var equipment_haste := 0.0
var _slows: Array[Dictionary] = []

func apply_slow(strength: float, duration: float) -> void:
	var amount := clampf(strength, 0.0, 0.9)
	for effect in _slows:
		if is_equal_approx(float(effect.strength), amount):
			effect.left = maxf(float(effect.left), duration)
			return
	_slows.append({"strength": amount, "left": maxf(0.0, duration)})

func movement_slow_multiplier() -> float:
	var strongest := 0.0
	for effect in _slows: strongest = maxf(strongest, float(effect.strength))
	return 1.0 - strongest
var _poke_t := -1.0
var _poke_dir := Vector2.RIGHT
var _poke_dist := 60.0
var _facing := 1.0
var _bob := 0.0
var _uses_gravity := false
## 走位用的路径（和怪物同一套 A*），没有路径时退化成"朝目标直走"
var _path: Array[Vector2i] = []
var _path_index := 0
var _path_timer := 0.0
const PATH_INTERVAL := 0.45
var _selected_enemy: EnemyBase
var _target_timer := 0.0
var _path_goal := Vector2i(-99999,-99999)
var _drop_timer := 0.0
var _progress_time:=0.0
var _progress_anchor:=Vector2.ZERO
var _progress_misses:=0
var _return_cd:=0.0
var _search_offset:=0
var _awaiting_placement:=false

func visual_art_kind()->StringName:return enemy_kind
func visual_body()->Vector2:return navigation_body()

func navigation_body() -> Vector2:
	return Vector2(24,34) if is_merc else Vector2(26,36)

func navigation_profile() -> Dictionary:
	return {"speed":move_speed}


func setup(entry: Dictionary, from_player: Node2D, level_node: Level, fx: Node) -> void:
	player = from_player
	level = level_node
	fx_root = fx
	uid = str(entry.get("uid", ""))
	if uid.is_empty():
		uid="legacy_%d"%get_instance_id()
		entry["uid"]=uid
	is_merc = str(entry.get("kind", "monster")) == "merc"
	enemy_kind = StringName(entry.get("enemy_kind", &"walker"))
	if not is_merc and not PixelEnemyArt.supports(enemy_kind):
		enemy_kind=&"walker"
		entry["enemy_kind"]=enemy_kind
	display_name = str(entry.get("name", "佣兵"))
	icon_path = str(entry.get("icon", ""))
	_merc_index=clampi(int(entry.get("merc_index",0)),0,3)
	_hire_wave=maxi(1,int(entry.get("hire_wave",GameState.wave)))
	entry["hire_wave"]=_hire_wave
	_base_values=HireOffers.final_stats(entry,_hire_wave,{"hp":1.0,"attack":1.0,"speed":1.0})
	var bonus: Dictionary = GameState.ally_bonus()
	# 属性 = 基础值 × 当前波次倍率 × 本次雇佣品质 × 召唤师装备加成
	# （酒馆卡片上显示的就是这套数，雇佣前后不会对不上）
	var final := HireOffers.final_stats(entry, _hire_wave, bonus)
	max_hp = float(final["hp"])
	hp = max_hp*clampf(float(entry.get("hp_ratio",1.0)),0.0,1.0)
	attack = float(final["attack"])
	move_speed = float(final["speed"])
	body_color = final["color"]
	_uses_gravity = false
	_cooldown = 1.2


func _base_stats() -> Dictionary:
	## 佣兵用一套固定偏高的属性；怪物直接照搬那种怪的基础值（但不带词条）
	if is_merc:
		return {"hp": 95.0, "attack": 15.0, "speed": 118.0, "color": Color("e0b64a"), "gravity": true}
	var probe := WaveDirector.create_enemy(enemy_kind)
	var out := {"hp": 50.0, "attack": 10.0, "speed": 90.0,
		"color": Color("8fd3ff"), "gravity": true}
	if probe != null:
		out["hp"] = probe.base_hp * 1.15
		out["attack"] = probe.base_damage * 0.8
		out["speed"] = maxf(70.0, probe.base_speed)
		out["color"] = probe.body_color
		out["gravity"] = probe.uses_gravity
		probe.free()
	return out


func _ready() -> void:
	# 站在玩家那一层：敌人的弹幕和贴身攻击就能打到你雇的帮手（不然它们永远不会死）
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("allies")
	_build_collider()
	_build_visual()
	EventBus.player_stats_changed.connect(_refresh_bonus)
	Effects.spawn_marker(_fx(), global_position, body_color)

func _process(delta:float)->void:
	equipment_haste_time=maxf(0.0,equipment_haste_time-delta)
	if equipment_haste_time<=0.0:equipment_haste=0.0
	for i in range(_slows.size() - 1, -1, -1):
		_slows[i].left = maxf(0.0, float(_slows[i].left) - delta)
		if float(_slows[i].left) <= 0.0: _slows.remove_at(i)
	if shield_time>0:
		shield_time=maxf(0.0,shield_time-delta)
		if shield_time<=0:shield_hp=0
	if shield_hp>0 and hp>0 and not is_instance_valid(_night_shelter_visual):
		_night_shelter_visual=NightShelterFX.new();add_child(_night_shelter_visual)


func _build_collider() -> void:
	## 没有碰撞体的话 move_and_slide() 根本撞不到地形，帮手会直接掉出地图消失
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = navigation_body()
	shape.shape = rect
	add_child(shape)


func _build_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if is_merc:
		_sprite.sprite_frames=PixelHireArt.make_frames(_merc_index)
		PixelHireArt.align(_sprite,_merc_index,navigation_body())
	else:
		_sprite.sprite_frames=PixelEnemyArt.make_frames(visual_art_kind())
		PixelEnemyArt.align(_sprite,visual_art_kind(),visual_body())
	_sprite_origin=_sprite.position
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	add_child(_sprite)
	_sprite.play(&"idle")
	# 头顶一条小血条，方便看它还剩多少


func _monster_strip() -> String:
	match enemy_kind:
		&"flyer": return "skull"
		&"caster": return "vampire"
		&"charger", &"guard": return "skeleton2"
		&"treant": return "treant"
		_: return "skeleton"


var _charge_time := 0.0
var _charge_cd := 0.0


func telegraph_flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.5, 1.2, 0.8)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.95), 0.25)


func _point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)




func _draw() -> void:
	# 标记跟随显示高度，脚底与碰撞/寻路体保持原来的位置。
	var visual_top := navigation_body().y*.5-PixelHireArt.WORLD_HEIGHT if is_merc else -visual_body().y*.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, visual_top - 15.0), Vector2(-4.0, visual_top - 21.0), Vector2(4.0, visual_top - 21.0),
	]), Color("72db8b"))
	## 头顶血条：让玩家看得出帮手还剩多少血（以前完全没有提示，死了像凭空消失）
	var width := 34.0
	var height := 4.0
	var origin := Vector2(-width * 0.5, visual_top - 10.0)
	draw_rect(Rect2(origin + Vector2(-1.0, -1.0), Vector2(width + 2.0, height + 2.0)),
		Color(0.05, 0.06, 0.10, 0.85), true)
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.16, 0.19, 0.26), true)
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var fill := Palette.ALLY_HEALTH
	draw_rect(Rect2(origin, Vector2(width * ratio, height)), fill, true)


func _update_sprite_pose() -> void:
	if _sprite == null:
		return
	_sprite.flip_h = _facing < 0.0
	var action:StringName=&"idle"
	if _hurt_left>0:action=&"hurt"
	elif _poke_t>=0 or _release_left>0:action=&"windup" if enemy_kind==&"bomber" else &"attack"
	elif enemy_kind==&"flyer" and not is_merc:action=&"fly"
	elif velocity.length()>5:action=&"walk"
	if _charge_time>0 and enemy_kind==&"charger" and _hurt_left<=0:action=&"charge"
	if not _sprite.sprite_frames.has_animation(action):action=&"idle"
	if _sprite.animation!=action:_sprite.play(action)
	_sprite.position=_sprite_origin
	# 浮游单位保留轻微漂浮；地面单位的脚底不再用旧模型整身前戳与上下摆动。
	if not is_merc and enemy_kind==&"flyer":_sprite.position.y+=sin(_bob)*1.0
	return


func _refresh_bonus()->void:
	if hp<=0.0 or _base_values.is_empty():return
	var ratio:=hp/maxf(max_hp,0.001)
	var bonus:=GameState.ally_bonus()
	max_hp=float(_base_values.hp)*float(bonus.hp)
	hp=max_hp*ratio
	attack=float(_base_values.attack)*float(bonus.attack)
	move_speed=float(_base_values.speed)*float(bonus.speed)
	queue_redraw()


func hire_snapshot()->Dictionary:
	return {"hire_wave":_hire_wave,"hp_ratio":clampf(hp/maxf(max_hp,0.001),0.0,1.0)}


func take_damage(amount: float, _from := Vector2.ZERO, _source: Node = null) -> void:
	if hp <= 0.0:
		return
	if shield_hp>0 and shield_time>0:
		var absorbed:=minf(shield_hp,maxf(0.0,amount))
		shield_hp-=absorbed;amount-=absorbed
		if amount<=0:
			queue_redraw();return
	hp -= amount
	_hurt_left=0.18
	Effects.damage_number(_fx(), global_position + Vector2(0.0, -26.0), amount, false, Palette.UI_DANGER)
	_sprite.modulate = Color.WHITE.lerp(Color(1.4, 0.7, 0.7),float(SaveService.data.get("flash_strength",1.0)))
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.95), 0.18)
	if hp <= 0.0:
		if self is SummonedAlly and player is RoomPlayer and is_instance_valid(player.equipment_mechanics):player.equipment_mechanics.on_contract_killed(self,_source)
		_die()
	elif not is_equal_approx(_hp_drawn, hp):
		_hp_drawn = hp
		queue_redraw()


func _die() -> void:
	if is_queued_for_deletion():return
	PixelEnemyArt.spawn_remains(_sprite,_fx())
	## 雇佣单位死了就永久消失：从本局名单里划掉
	Effects.death_burst(_fx(), global_position, body_color, 12)
	Effects.text(_fx(), global_position + Vector2(0.0, -46.0), "%s 阵亡" % display_name, Palette.UI_DANGER, 18)
	GameState.remove_hired(uid)
	queue_free()


func _fx() -> Node:
	if fx_root != null and is_instance_valid(fx_root):
		return fx_root
	return get_parent()



func place_near_player()->void:pass # RoomAlly owns body-aware placement.

func _throw_knife(dir: Vector2) -> void:
	_release_left=0.24
	## 飞刀：飞出去再飞回来（和玩家近战武器一个思路）
	var parent := fx_root if fx_root != null and is_instance_valid(fx_root) else get_parent()
	var knife := BoomerangKnife.new()
	knife.setup(global_position + dir * 18.0, dir, attack, self)
	parent.add_child(knife)
	AudioManager.play(&"swing", -10.0, 0.2)




