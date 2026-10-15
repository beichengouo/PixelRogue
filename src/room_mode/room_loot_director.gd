class_name RoomLootDirector
extends LootDirector
func _material(_at:Vector2)->Dictionary:
	var biome:=str(main.graph.rooms[main.graph.current].biome)
	var list:Array=["forest_sample","forest_resin","moss_cloth"] if biome=="forest" else (["wetland_sample","river_pearl"] if biome=="wetland" else ["ruin_sample","ruin_ore"])
	if GameState.wave>=10:list.append("storm_crystal")
	if GameState.wave>=20:list.append("ancient_seal")
	var id:String=list[0]
	var roll:=rng.randf()
	if roll<0.08:id="memory_gift"
	elif roll<0.35:id="star_dust"
	elif roll<0.6:id=list[rng.randi_range(1,list.size()-1)]
	if GameState.danger>=1 and GameState.wave>=10 and rng.randf()<0.2:id="deep_evidence"
	if GameState.danger>=2 and GameState.wave>=20 and rng.randf()<0.2:id="echo_evidence"
	var item:=ExpeditionData.material(id)
	item.sale_value=int(round(float(item.cost)*RunDifficulty.material_value_multiplier(GameState.difficulty)*maxf(1,GameState.stats.get_value(&"coin_gain"))))
	return item

func drop(items:Array,at:Vector2,impulse=Vector2(0,-230),force_new:=false)->LootDrop:
	var existing:=get_tree().get_nodes_in_group("expedition_loot").filter(func(n:Node)->bool:return not n.is_queued_for_deletion() and not n._collected)
	if not force_new and existing.size()>=64:
		var target:LootDrop=existing[0]
		for node in existing:
			if node.global_position.distance_squared_to(at)<target.global_position.distance_squared_to(at):target=node
		for item in items:target.contents.append(item.duplicate(true))
		target.refresh_visual();return target
	var node:=RoomLootDrop.new();node.level=main.level;node.player=main.player
	for item in items:node.contents.append(item.duplicate(true))
	main.fx_root.add_child(node)
	node.global_position=at
	node.velocity=Vector2(rng.randf_range(-100,100),rng.randf_range(-100,100)) if impulse.x==0 else impulse*0.4
	return node

