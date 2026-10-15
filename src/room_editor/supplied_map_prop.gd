class_name SuppliedMapProp
extends Node2D
## Same bottom anchor and scaling used by the map editor canvas; no collision or game state.
var asset_id := ""
var footprint := Vector2i.ONE
var _sprite: Sprite2D
var _frames: SpriteFrames
var _clock := 0.0

class SuppliedLight extends Node2D:
	var light_field:RoomLightField
	var kind:="torch"
	func _ready()->void:add_to_group("room_environment_lights")
	func light_config()->Dictionary:return RoomEnvironmentConfig.LIGHTS.get(kind,RoomEnvironmentConfig.LIGHTS.torch).duplicate()
	func _exit_tree()->void:
		if light_field!=null:light_field.unregister(self)

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_frames = SuppliedMapAssets.sprite_frames(asset_id)
	_sprite.texture = SuppliedMapAssets.texture(asset_id)
	if _sprite.texture != null:
		var factor := footprint.x * 36.0 / maxf(1, _sprite.texture.get_width())
		_sprite.scale = Vector2.ONE * factor
		_sprite.position = Vector2(0, -_sprite.texture.get_height() * factor * 0.5)
	set_process(_frames != null)
	var entry:=SuppliedMapAssets.get_entry(asset_id)
	if not str(entry.get("light_kind","")).is_empty():
		for y in footprint.y:
			for x in footprint.x:
				var emitter:=SuppliedLight.new();emitter.kind=str(entry.light_kind)
				emitter.position=Vector2((x+.5)*36-footprint.x*18,(y-footprint.y)*36+18)
				add_child(emitter)

func _process(delta: float) -> void:
	_clock += delta
	_sprite.texture = SuppliedMapAssets.texture(asset_id, _clock)
