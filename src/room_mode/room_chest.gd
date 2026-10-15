class_name RoomChest
extends Chest
var free_opening := false
var luxury := false
var delivery_id := -1
func glow_color()->Color:return Color("8cebe1") if luxury else super.glow_color()
func glow_radius()->float:return 134.0 if luxury else super.glow_radius()
func required_keys()->int:return 0 if free_opening else super.required_keys()
func _roll_loot()->Dictionary:
	var items:Array[Dictionary]=[];var rng:=Rng.stream()
	var gear:=BattleLootSelection.pick(rng)
	if not gear.is_empty():items.append(gear)
	var extra:=BattleLootSelection.pick(rng)
	if not extra.is_empty():items.append(extra)
	if is_instance_valid(GameState.runtime_node):
		for index in rng.randi_range(2,4):items.append(GameState.runtime_node.loot._material(global_position))
	return {"kind":&"bundle","items":items,"coins":rng.randi_range(60,140)}
func set_art(state:String)->void:
	super.set_art(state)
	if not luxury or _sprite==null:return
	var frame:=clampi(int(_opening_elapsed/OPEN_STEP),0,3) if _opening else (4 if is_open else 0)
	var texture:=SpecialRoomArt.chest_frame(frame)
	if texture==null:return
	_sprite.texture=texture;_sprite.scale=Vector2.ONE*40.5/texture.get_width()
	_art_origin=GROUND_OFFSET-(Vector2(0,120)-texture.get_size()*.5)*_sprite.scale;_update_fall_visual()
func _refresh_prompt()->void:
	if free_opening and not is_open and _landed:EventBus.interact_prompt_show.emit("[%s] 开启星赐宝箱 · 无需钥匙"%UIFlow.hint(&"interact"));return
	super._refresh_prompt()
