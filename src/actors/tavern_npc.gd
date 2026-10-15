class_name TavernNPC
extends Area2D
## 地图上的酒馆：波间休整时开张，玩家走近按 E 雇佣怪物 / 佣兵。
## 和商人（ShopNPC）是同一套交互规则，只是卖的东西不一样。

const INTERACT_RADIUS := 95.0

var player: Node2D
var in_range := false
var is_open := false

## 摊位背景已去掉，只留这个 NPC 模型（开门/关门用明暗表示）
var _npc_sprite: Sprite2D


func _ready() -> void:
	add_to_group("storefronts")
	collision_layer = Layers.INTERACT
	collision_mask = Layers.PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	add_child(shape)
	_build_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.rest_started.connect(_on_rest_started)
	EventBus.rest_ended.connect(_on_rest_ended)
	# 和商人一样自带一盏灯（酒馆用偏暖偏红的色调，和商店区分开）
	_npc_light = LightUtil.make_point_light(Color(1.0, 0.72, 0.55), 1.0, 165.0, false)
	_npc_light.position = Vector2(0.0, -22.0)
	add_child(_npc_light)
	_set_open(false)


var _npc_light: PointLight2D


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		in_range = true
		_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		in_range = false
		StorefrontInteraction.refresh(self)


func _on_rest_started(_duration: float) -> void:
	_set_open(true)
	if in_range:
		_refresh_prompt()


func _on_rest_ended() -> void:
	_set_open(false)
	if in_range:
		StorefrontInteraction.refresh(self)


func try_interact() -> void:
	if not in_range:
		return
	if not is_open:
		Effects.text(get_parent(), global_position + Vector2(0.0, -76.0), "休整时间才开门", Palette.UI_TEXT_DIM, 19)
		return
	EventBus.tavern_opened.emit(HireOffers.roll_offers(Rng.stream()))


func _refresh_prompt() -> void:
	StorefrontInteraction.refresh(self)

func _process(_delta: float) -> void:
	if in_range: StorefrontInteraction.refresh(self)


func _set_open(value: bool) -> void:
	is_open = value
	if _npc_sprite != null:
		_npc_sprite.modulate = Color(1.0, 1.0, 1.0) if value else Color(0.55, 0.55, 0.62)
	if _npc_light != null:
		_npc_light.energy = 1.4 if value else 0.0


func _build_visual() -> void:
	var root := Node2D.new()
	root.name = "Visual"
	root.z_index = -1
	add_child(root)
	_npc_sprite = Sprite2D.new()
	_npc_sprite.name = "Building"
	_npc_sprite.texture = load("res://assets/round5/buildings/tavern.png")
	_npc_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_npc_sprite.centered = true
	# Spawn markers are body centers; the player's feet are 21px below them.
	_npc_sprite.position = Vector2(0, 21 - _npc_sprite.texture.get_height() * 0.5)
	root.add_child(_npc_sprite)
