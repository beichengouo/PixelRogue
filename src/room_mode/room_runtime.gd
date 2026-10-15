class_name RoomRuntime
extends ExpeditionRuntime
var _room_receipts:Dictionary={}
func _apply_fields(node:Object,fields:Dictionary)->void:
	super._apply_fields(node,fields)
	if node is Player and is_instance_valid(node.stats):
		node.max_hp=maxf(0.0,node.stats.get_value(&"max_hp")-node.permanent_hp_loss())
		node.hp=clampf(node.hp,0.0,node.max_hp)
	if node is EnemyBase and not fields.has("balance_revision"):
		node.base_damage*=3;node.damage*=3;node.balance_revision=4
		if node.kind==&"guard":node.base_hp*=3;node.max_hp*=3;node.hp*=3
	if node is RoomEnemy and node.kind==&"treant":
		node.body_size=Vector2(29,32)
		if node.visual is AnimatedSprite2D:PixelEnemyArt.align(node.visual,node.kind,node.body_size)
	if node is RoomEnemy:
		# Old checkpoints may contain projectile affixes on weapon-bearing melee art.
		# Saved combat attributes are already applied; only normalize the affix list.
		node.affixes=EnemyCombatPolicy.filtered_affixes(node.kind,node.affixes)
		node.danger=EnemyAffixes.total_danger(node.affixes)
		if node.kind==&"bomber" and node.display_name=="自爆骷髅":node.display_name="烬骨法师"
	# Apply the current authored sizes, including saves made before size corrections.
	if node is RoomBoss:
		node.max_phase=int(BossRoster.get_data(node.boss_id).get("phases",3 if node.boss_id==&"tide" else 2));node.phase=mini(node.phase,node.max_phase)
		var roster:=BossRoster.get_data(node.boss_id)
		node.body_size=roster.size;node.art_scale=float(roster.scale)
		if node.visual is AnimatedSprite2D:PixelBossArt.align(node.visual,node.boss_id,node.body_size)
	elif node is HiredAlly and node.is_merc and is_instance_valid(node._sprite):
		# Older checkpoints carried the previous soldier-sheet origin. Align to
		# the new grounded atlas after restoring fields, preserving combat stats.
		node._sprite.sprite_frames=PixelHireArt.make_frames(node._merc_index)
		PixelHireArt.align(node._sprite,node._merc_index,node.navigation_body())
		node._sprite_origin=node._sprite.position
func _fields(node:Object)->Dictionary:
	var fields:=super._fields(node)
	# The graph owns room deltas; embedding the room inside its runtime recursively grows saves.
	fields.erase("room_record");fields.erase("_live_warnings")
	if node is RoomPlayer:fields.erase("_mouse_attack_blocked")
	return fields

func _node_record(node:Node)->Dictionary:
	var record:=super._node_record(node)
	if node is RoomEnemy and is_instance_valid(node.affix_runtime):
		record["affix_state"]=node.affix_runtime.snapshot()
	return record

func _ready()->void:
	motion=DefeatMotion.new();add_child(motion)
	loot=RoomLootDirector.new();loot.main=main;add_child(loot)
	loot.boss_loot.connect(motion.play);main.director.enemy_reward.connect(loot.reward)
	extraction=RoomExtraction.new();extraction.main=main;add_child(extraction);extraction.completed.connect(_complete)
	GameState.runtime_node=self;Outpost.checkpoint_requested.connect(checkpoint)

func capture_room()->Dictionary:
	main.graph.rooms[main.graph.current].delta.experience_awarded=GameState.wave_exp_awarded
	var records:Array=[]
	var hazards:Array=[]
	for parent in [main.enemies_root,main.chests_root,main.fx_root,main.actors_root,main.level]:
		for node in parent.get_children():
			if node.is_queued_for_deletion():continue
			if node is EnemyBase and not node._dead:records.append(_node_record(node))
			elif node is AffixHazard:hazards.append(node.snapshot())
			elif node is RoomLootDrop:
				if not node._collected and not node.contents.is_empty():records.append(_node_record(node))
			elif node is Coin:
				if not node._collected and node.kind == &"coin":records.append(_node_record(node))
			elif node is GlowMushroom:
				if not node._harvested:records.append(_node_record(node))
			elif node is RoomChest:records.append(_node_record(node))
			elif (node is RoomProjectile and not node is IlyuaArrow) or node is RoomSkillField:records.append(_node_record(node))
	var allies:Array=[]
	for node in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():allies.append(_node_record(node))
	return {"entities":records,"hazards":hazards,"allies":allies,"director":_fields(main.director),
		"player":_node_record(main.player),"loot":loot.snapshot(),"spawn_rng":str(main.director.spawn_rng.state),
		"shop":_encode(main.shop_ui.expedition_snapshot()),"tavern":_encode(main.tavern_ui.expedition_snapshot())}

func persist_room()->void:
	if not is_instance_valid(main.player):return
	main.graph.rooms[main.graph.current].delta["runtime"]=capture_room()

func snapshot()->Dictionary:
	persist_room()
	var mechanics:Node=main.player.get_node_or_null("EquipmentMechanics") if is_instance_valid(main.player) else null
	return {"version":2,"graph":main.graph.snapshot(),"weather":main.room_weather.snapshot(),"clock":main.world_clock.snapshot(),"environment":main.environment_visual.snapshot(),
		"ilyua":main.player.ilyua_runtime.snapshot() if is_instance_valid(main.player.ilyua_runtime) else {},
		"holy":main.player.holy_runtime.snapshot() if is_instance_valid(main.player.holy_runtime) else {},
		"equipment_mechanics":mechanics.call("snapshot") if is_instance_valid(mechanics) and mechanics.has_method("snapshot") else {},
		"extraction":extraction.snapshot(),"motion":motion.snapshot(),"passive_units":PassiveRuntime.snapshot_units(main.player),
		"talent_view":main.talent_ui.expedition_snapshot(),
		"flow":_encode({"reward_pending":main._reward_pending,"offers":main._reward_offers,"reward_wave":main._reward_wave,"checkpoint":main._checkpoint_wave,"active_story":str(main._active_room_story),"dialogue":main.dialogue.expedition_snapshot(),"story_queue":main._story_queue,"story_context":main._story_context}),
		"environment_rng":str(main._room_rng.state),"mushroom_timer":main._mushroom_timer,
		"rng_seed":str(Rng.run_seed),"rng_state":str(Rng.stream().state)}

func restore(d:Dictionary)->void:
	if d.is_empty():return
	_restoring=true
	main.environment_visual.restore(d.get("environment",{}));main.world_clock.restore(d.get("clock",{}))
	restore_room(main.graph.rooms[main.graph.current].delta.get("runtime",{}),true)
	var mechanics:Node=main.player.get_node_or_null("EquipmentMechanics") if is_instance_valid(main.player) else null
	if is_instance_valid(mechanics) and mechanics.has_method("restore"):mechanics.call("restore",d.get("equipment_mechanics",{}),_restore_ids)
	if is_instance_valid(main.player.ilyua_runtime):main.player.ilyua_runtime.restore(d.get("ilyua",{}),_restore_ids)
	if is_instance_valid(main.player.holy_runtime):main.player.holy_runtime.restore(d.get("holy",{}),_restore_ids)
	PassiveRuntime.restore_units(main.player,d.get("passive_units",{}))
	main.talent_ui.expedition_restore(d.get("talent_view",{}))
	loot.restore(main.graph.rooms[main.graph.current].delta.get("runtime",{}).get("loot",{}))
	Rng.run_seed=int(d.get("rng_seed",Rng.run_seed));Rng.stream().state=int(d.get("rng_state",Rng.stream().state))
	main._room_rng.state=int(d.get("environment_rng",main._room_rng.state));main._mushroom_timer=float(d.get("mushroom_timer",45))
	extraction.restore(d.get("extraction",{}));motion.restore(d.get("motion",{}))
	_restoring=false

func restore_room(d:Dictionary,with_player:=false)->void:
	if d.is_empty():return
	_restoring=true;_restore_ids.clear();_room_receipts.clear()
	if with_player and d.has("player"):_restore_ids[str(d.player.instance)]=main.player
	# Ground-plane fields are children of RoomLevel, outside the regular entity roots.
	for field in get_tree().get_nodes_in_group("spell_fields"):
		if is_instance_valid(field) and field.get("room")==main.level:
			field.get_parent().remove_child(field);field.queue_free()
	for parent in [main.enemies_root,main.chests_root,main.fx_root]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	main.director.boss=null
	for record in d.get("entities",[]):
		var node:Node=_restore_room_node(record)
		if node is BossBase:main.director.boss=node
	for hazard_data in d.get("hazards",[]):
		if hazard_data is Dictionary:
			var hazard:=AffixHazard.restore_hazard(main.fx_root,main.level,hazard_data)
			var source:Node=_restore_ids.get(str(hazard_data.get("source_key",0)))
			if is_instance_valid(source):hazard.source_ref=weakref(source);hazard.source_key=source.get_instance_id()
	# Rebind pierced-target IDs and shared basic-attack receipts after all bodies exist.
	for record in d.get("entities",[]):
		var node:Node=_restore_ids.get(str(record.instance))
		if node is EnemyBase and str(record.get("burn_owner","other"))=="player":
			node._burn_source=weakref(DamageContext.spread_burn(main.player) if str(record.get("burn_kind",""))=="spread_burn" else DamageContext.dot(main.player))
		if node is RoomSkillField:
			var prior:Dictionary=node.hit.duplicate();node.hit.clear()
			for old in prior:
				if _restore_ids.has(str(old)):node.hit[_restore_ids[str(old)].get_instance_id()]=true
		if node is RoomProjectile:
			if bool(record.get("boss_owned",false)) and is_instance_valid(main.director.boss):
				node.set_meta("boss_owner",main.director.boss.get_instance_id())
				main.director.boss._owned_bullets.append(node)
			for old in record.get("hit_ids",[]):
				if _restore_ids.has(str(old)):node._hit_ids[_restore_ids[str(old)].get_instance_id()]=true
			var saved:Dictionary=record.get("receipt",{})
			if not saved.is_empty():
				var id:=str(saved.id)
				if not _room_receipts.has(id):
					var receipt:=BasicAttackReceipt.new(main.player)
					receipt.claimed=bool(saved.get("claimed",false));receipt.critical=bool(saved.get("critical",false))
					for effect_key in saved.get("effects",[]):receipt.effects[StringName(effect_key)]=true
					_room_receipts[id]=receipt
				node.attack_receipt=_room_receipts[id]
	_apply_fields(main.director,d.get("director",{}))
	main.director.spawn_rng.state=int(d.get("spawn_rng",main.director.spawn_rng.state))
	main.director.room_record=main.graph.rooms[main.graph.current]
	GameState.wave_exp_multiplier=.6 if main.director.room_record.kind=="altar" else 1.0
	GameState.wave_exp_awarded=float(main.director.room_record.delta.get("experience_awarded",GameState.wave_exp_awarded))
	for pending in main.director.room_pending:
		var duration:=0.3 if pending.get("split",false) else (0.8 if pending.get("origin","")=="boss_minion" else 0.75)
		RoomSpawnFX.spawn(main.fx_root,pending.at,duration,float(pending.remaining))
	# Allies travel with the player; historical rooms must not rewind their health.
	for record in (d.get("allies",[]) if with_player else []):
		if bool(record.fields.get("is_contract",false)) and float(record.fields.get("remaining",0))>0 and str(record.get("script",""))=="res://src/room_mode/summoned_ally.gd":
			var found:=false
			for ally in get_tree().get_nodes_in_group("contracts"):
				if ally.uid==str(record.fields.get("uid","")):found=true;break
			if not found:
				var unit:=SummonedAlly.new();_apply_fields(unit,record.fields)
				unit.player=main.player;unit.room=main.level;unit.level=main.level;unit.fx_root=main.fx_root;unit.contract_epoch=GameState.run_epoch
				main.actors_root.add_child(unit);_apply_fields(unit,record.fields);unit.contract_epoch=GameState.run_epoch
		for ally in get_tree().get_nodes_in_group("allies"):
			if ally.uid==str(record.fields.get("uid","")):
				_restore_ids[str(record.instance)]=ally
				_apply_fields(ally,record.fields)
				if with_player:ally.global_position=Vector2(record.at[0],record.at[1])
				if ally is SummonedAlly:ally.contract_epoch=GameState.run_epoch
	if with_player and d.has("player"):
		_apply_fields(main.player,d.player.fields)
		main.player.global_position=Vector2(d.player.at[0],d.player.at[1])
		main.player.velocity=Vector2(d.player.velocity[0],d.player.velocity[1])
	main.shop_ui.expedition_restore(_decode(d.get("shop",{})));main.tavern_ui.expedition_restore(_decode(d.get("tavern",{})))
	for hazard in get_tree().get_nodes_in_group("affix_hazards"):
		if not hazard.is_queued_for_deletion() and hazard.room==main.level:hazard.restore_hit_cooldowns(_restore_ids)
	main.level.doors_open=bool(main.graph.rooms[main.graph.current].rewarded) or main.graph.rooms[main.graph.current].kind=="spawn"
	main.level.queue_redraw();_restoring=false

func _restore_room_node(record:Dictionary)->Node:
	var path:=str(record.get("script",""))
	# Retired monster key drops must not return when an older room is resumed.
	if path=="res://src/room_mode/room_key.gd":return null
	if path=="res://src/actors/coin.gd" and str(_decode(record.get("fields",{}).get("kind","")))=="key":return null
	if not path.begins_with("res://src/room_mode/") and path!="res://src/actors/glow_mushroom.gd" and path!="res://src/actors/coin.gd":return null
	var node:Node=RoomEnemy.new() if path=="res://src/room_mode/room_ambush_enemy.gd" else load(path).new()
	_apply_fields(node,record.get("fields",{}))
	if node is RoomEnemy or node is RoomBoss or node is BossConstruct:node.room=main.level;node.director=main.director;node.fx_root=main.fx_root;node.player=main.player;node.level=main.level
	elif node is RoomProjectile:node.room=main.level;node.level=main.level;node.player=main.player
	elif node is RoomSkillField:node.room=main.level;node.caster=weakref(main.player)
	elif node is Coin or node is RoomChest or node is GlowMushroom:node.level=main.level;node.player=main.player
	node.position=Vector2(record.at[0],record.at[1])
	var parent:Node=main.enemies_root if node is EnemyBase else (main.level if node is RoomSkillField else (main.chests_root if node is RoomChest else main.fx_root))
	parent.add_child(node)
	if node is RoomEnemy:
		if not node.died.is_connected(main.director._on_unit_died):node.died.connect(main.director._on_unit_died)
		node.apply_affixes(node.affixes)
	_apply_fields(node,record.get("fields",{}))
	if node is RoomEnemy:
		if is_instance_valid(node.affix_runtime):
			var affix_state:Dictionary=record.get("affix_state",{}).duplicate(true)
			if not node.has_affix(EnemyAffixes.HUNTER_LOCK) and str(affix_state.get("active",""))=="hunter_lock":
				affix_state["active"]="";affix_state["stage"]=0
			node.affix_runtime.restore(affix_state)
	if node is RoomChest:
		node._art_state="";node.set_art(("empty" if node._open_timer<1 else "open") if node.is_open else "closed")
	if node is RoomBoss:node.restore_warning()
	if node is RoomEnemy:node.restore_flame_warnings()
	if node is RoomEnemy and node._windup>0:node.warn_attack("circle" if node.kind==&"bomber" else "arrow",node._windup,100)
	if node is RoomEnemy and node._teleport_left>0:
		HostileAttackFX.pulse(main.fx_root,node.global_position,"affix","departure",48,node._teleport_left,0,main.level)
		HostileAttackFX.pulse(main.fx_root,node._teleport_destination,"affix","arrival",72,node._teleport_left,0,main.level)
	if node is CharacterBody2D:node.velocity=Vector2(record.velocity[0],record.velocity[1])
	_restore_ids[str(record.instance)]=node
	return node
