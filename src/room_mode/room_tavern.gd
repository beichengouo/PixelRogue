class_name RoomTavern
extends TavernNPC
var main
func _build_visual()->void:
	if is_instance_valid(main.level.service_building):_npc_sprite=main.level.service_building.art
func _set_open(value:bool)->void:
	super._set_open(value)
	if is_instance_valid(_npc_light):_npc_light.energy=0.65 if value else 0.0
func try_interact()->void:
	if in_range and is_open:main.open_room_tavern()
