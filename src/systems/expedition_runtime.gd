class_name ExpeditionRuntime
extends Node
var main
var loot: LootDirector
var extraction: ExtractionDirector
var motion: DefeatMotion
var _save_timer = 5.0
var _restoring = false
var _completion_cover_epoch := -1
var _restore_ids: Dictionary = {}
var _restore_receipts: Dictionary = {}

func checkpoint() -> void:
	if _restoring or not GameState.run_active or not is_instance_valid(main.player) or main.player.hp<=0:return
	if GameState.sortie_id!=Outpost.active_id():return
	SaveService.save_run(GameState.snapshot())

func _process(delta: float) -> void:
	if not GameState.run_active:return
	_save_timer-=delta
	if _save_timer<=0:
		_save_timer=5
		checkpoint()
	if not is_instance_valid(main.player): return
	var text = ""
	var distance = INF
	for node in get_tree().get_nodes_in_group("expedition_loot"):
		var d: float = node.global_position.distance_to(main.player.global_position)
		if d < minf(distance,85) and not node.contents.is_empty():
			distance=d
			var category:=GameState.bag_category(node.contents[0])
			var capacity:= "遗物不占格" if category=="relic" else "%s %d/24"%[{"gear":"装备","potion":"药剂","material":"物资"}.get(category,"物资"),GameState.bag_slots({},category)]
			text="%s 拾取 %s%s · %s" % [UIFlow.hint(&"interact"),str(node.contents[0].name),"等%d件"%node.contents.size() if node.contents.size()>1 else "",capacity]
	for group in ["mushrooms","chests"]:
		for node in get_tree().get_nodes_in_group(group):
			var d: float=node.global_position.distance_to(main.player.global_position)
			if bool(node.get("in_range")) and d < distance and (not bool(node.get("_harvested")) if group=="mushrooms" else not node.is_open):
				distance=d
				var caption:="采集发光蘑菇" if group=="mushrooms" else ("开启星赐宝箱（无需钥匙）" if node.required_keys()==0 else "打开补给箱（消耗%d把钥匙）"%node.required_keys())
				text="按 %s %s" % [UIFlow.hint(&"interact"),caption]
	var store=StorefrontInteraction.closest(get_tree(),main.player)
	if store!=null and store.global_position.distance_to(main.player.global_position)<distance:
		distance=store.global_position.distance_to(main.player.global_position)
		text=("按 %s 进入%s" % [UIFlow.hint(&"interact"),"商店" if store is ShopNPC else "酒馆"]) if store.is_open else "休整时营业"
	main.hud.set_prompt(text)

func interact() -> bool:
	if not is_instance_valid(main.player):return false
	var best: Node2D
	var distance=INF
	for node in get_tree().get_nodes_in_group("expedition_loot"):
		var d:float=node.global_position.distance_to(main.player.global_position)
		if d<85 and d<distance:best=node;distance=d
	# Respect the closest existing mushroom, chest or operating storefront.
	for group in ["mushrooms","chests"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.global_position.distance_to(main.player.global_position)<distance and bool(node.get("in_range")) and (not bool(node.get("_harvested")) if group=="mushrooms" else not node.is_open):return false
	var store=StorefrontInteraction.closest(get_tree(),main.player)
	if store!=null and store.global_position.distance_to(main.player.global_position)<distance:return false
	if best is LootDrop:return best.try_pickup()
	return false

func drop_inventory_item(item: Dictionary) -> void:
	loot.drop([item],main.player.global_position+Vector2(0,-14))

func _complete() -> void:
	if not extraction.can_complete(extraction.completion_ticket()): return
	main._settle_extraction(self, extraction.completion_ticket())

func _node_record(node: Node) -> Dictionary:
	var record: Dictionary = {"instance":str(node.get_instance_id()),"script":node.get_script().resource_path,"fields":_fields(node),"at":[node.global_position.x,node.global_position.y],"velocity":[node.velocity.x,node.velocity.y] if node is CharacterBody2D else [0,0]}
	if node is EnemyBase:
		var burn_source:Node=node._burn_source.get_ref() if node._burn_source!=null else null
		record["burn_kind"]=str(burn_source.owner_kind) if burn_source is DamageContext else ""
		record["burn_owner"]="player" if is_instance_valid(burn_source) and DamageContext.player_owned(burn_source) else "other"
	if node is Projectile:
		record["hit_ids"] = node._hit_ids.keys().map(func(id:Variant)->String:return str(id))
		record["boss_owned"] = node.has_meta("boss_owner")
		if node.attack_receipt!=null:
			var effect_keys:Array[String]=[]
			for key in node.attack_receipt.effects:effect_keys.append(str(key))
			record["receipt"]={"id":str(node.attack_receipt.get_instance_id()),"claimed":node.attack_receipt.claimed,"critical":node.attack_receipt.critical,"effects":effect_keys}
	if node is BossBase:
		record["warnings"] = []
		for warning in node._warnings:
			if is_instance_valid(warning): record.warnings.append({"fields":_fields(warning),"at":[warning.global_position.x,warning.global_position.y],"key":warning.get_meta("warning_key",""),"start":warning.get_meta("start",0)})
	return record

func _fields(node: Object) -> Dictionary:
	var result:Dictionary={}
	for property in node.get_property_list():
		if not (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE):continue
		var key=str(property.name)
		var value:Variant=node.get(key)
		# typeof is safe for dangling Godot references; `is` is not.
		if typeof(value)==TYPE_OBJECT:continue
		if key in ["_pending_spawns","_pending_minions","_path","_owned_bullets","_warnings","_hit_ids","_swing_hits","receipts","_art_state","_art_origin","_weapon_frames"]:continue
		result[key]=_encode(value)
	return result

func _apply_fields(node: Object, fields: Dictionary) -> void:
	var properties:Dictionary={}
	for p in node.get_property_list():properties[str(p.name)]=true
	for key in fields:
		if not properties.has(str(key)):continue
		var old:Variant=node.get(key)
		if typeof(old)==TYPE_OBJECT:continue
		var value:Variant=_decode(fields[key])
		if old is Array and value is Array:
			var array:Array=old.duplicate()
			array.clear()
			array.assign(value)
			node.set(key,array)
		else:node.set(key,value)

func _encode(value: Variant) -> Variant:
	if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE]:return null
	if value is Vector2:return {"$v2":[value.x,value.y]}
	if value is Vector2i:return {"$v2i":[value.x,value.y]}
	if value is Color:return {"$color":[value.r,value.g,value.b,value.a]}
	if value is Rect2:return {"$rect":[value.position.x,value.position.y,value.size.x,value.size.y]}
	if value is StringName:return {"$name":str(value)}
	if value is Array:
		var out:Array=[]
		for item in value:out.append(_encode(item))
		return out
	if value is Dictionary:
		var out:Dictionary={}
		for key in value:
			if typeof(key) in [TYPE_OBJECT,TYPE_CALLABLE] or typeof(value[key]) in [TYPE_OBJECT,TYPE_CALLABLE]:continue
			out[str(key)]=_encode(value[key])
		return out
	return value

func _decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$v2"):return Vector2(value["$v2"][0],value["$v2"][1])
		if value.has("$v2i"):return Vector2i(value["$v2i"][0],value["$v2i"][1])
		if value.has("$name"):return StringName(value["$name"])
		if value.has("$color"):return Color(value["$color"][0],value["$color"][1],value["$color"][2],value["$color"][3])
		if value.has("$rect"):return Rect2(value["$rect"][0],value["$rect"][1],value["$rect"][2],value["$rect"][3])
		var out:Dictionary={}
		for key in value:out[key]=_decode(value[key])
		return out
	if value is Array:
		var out:Array=[]
		for item in value:out.append(_decode(item))
		return out
	return value

func _exit_tree() -> void:
	if GameState.run_active and TransitionLayer.busy and TransitionLayer._epoch == _completion_cover_epoch:
		TransitionLayer.cancel()
	# Detached runtimes remain alive until queue_free; disconnect immediately.
	if is_instance_valid(main) and is_instance_valid(main.director) and is_instance_valid(loot):
		if main.director.enemy_reward.is_connected(loot.reward): main.director.enemy_reward.disconnect(loot.reward)
	if Outpost.checkpoint_requested.is_connected(checkpoint): Outpost.checkpoint_requested.disconnect(checkpoint)
	if is_instance_valid(GameState.runtime_node) and GameState.runtime_node==self:GameState.runtime_node=null

func snapshot()->Dictionary:return {}
func restore(_data:Dictionary)->void:pass
