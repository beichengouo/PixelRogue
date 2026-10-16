class_name RoomChest
extends Chest
var free_opening := true
var luxury := false
var delivery_id := -1
func required_keys()->int:return 0
func _roll_loot()->Dictionary:
	var items:Array[Dictionary]=[];var rng:=Rng.stream()
	var gear:=BattleLootSelection.pick(rng)
	if not gear.is_empty():items.append(gear)
	var extra:=BattleLootSelection.pick(rng)
	if not extra.is_empty():items.append(extra)
	if is_instance_valid(GameState.runtime_node):
		for index in rng.randi_range(2,4):items.append(GameState.runtime_node.loot._material(global_position))
	return {"kind":&"bundle","items":items,"coins":rng.randi_range(60,140)}
