class_name RoomExpansionController
extends Node
## The graph owns one-shot choices and scene clocks; this node only advances them.
var main
var record:Dictionary={}
var state:Dictionary={}
var panel:RoomEventUI
var validation_mode:=false
var visuals:Dictionary={}
const EVENTS:=["letter","pack","page"]
const TITLES:={"letter":"未寄出的信","pack":"散落的行囊","page":"星灯残页"}
const INTRO:={"letter":"林风翻开信纸，墨迹虽淡，最后一句仍能读清：如果你路过这里，请替我向星灯道一声晚安。","pack":"倒下的路牌旁，行囊仍系着完整的绳结。里面的补给被仔细分成两份，像是留给后来经过的旅人。","page":"残页压在石灯下。纸上不是咒文，而是一位旅人记下的星纹，以及一句话：别让下一盏灯独自熄灭。"}
const REPLIES:={
	"sylphiette":{"letter":"星光能照见墨迹，却不能替人送达心意。我们替她留个回应吧。","pack":"绳结没有被割断。这份行囊像是有人特意留下的。","page":"这些星纹不像咒式，更像一段旅程的记录。带走它的光，也该记住留下它的人。"},
	"xixifu":{"letter":"这封信没等到主人……那就由我们记住她走过的路。","pack":"给走不动的人留些补给，是很温柔的事。我会珍惜它。","page":"纸上画着一盏小灯……我想把它的光带到下一段路上。"},
	"ilyua":{"letter":"纸边还沾着嫩叶。写信的人，也许曾从我的林子走过。","pack":"箭袋的位置还空着。愿行囊的主人已经平安归家。","page":"猎人会在树上留下记号。她把记号留在了星灯里，我们就沿着光继续走吧。"}}

func configure(room_record:Dictionary)->void:
	if is_instance_valid(panel):panel.close(true)
	for visual in visuals.values():
		if is_instance_valid(visual):visual.queue_free()
	visuals.clear();record=room_record;state={}
	var scene:=str(record.get("terrain_layout",{}).get("scene_art",""))
	if record.kind not in ["altar","trial","event"] and scene not in RoomExpansionRules.MAP_IDS:return
	if not record.delta.has("expansion"):
		record.delta.expansion={"clock":0.0,"pulse_left":8.0 if scene=="elite_boneflags_v01" else 10.0,"fields":[],"serial":0,"wind_inside":false,"wind_ready":0.0,"event_started":false,"event_panel_open":false,"event_resolved":false,"event_id":"","dialogue":0,"offers":[],"pending":[],"altar_claimed":false}
	state=record.delta.expansion
	if record.kind=="event" and state.event_id.is_empty():
		var rng:=RandomNumberGenerator.new();rng.seed=int(record.seed)^0x82369;state.event_id=EVENTS[rng.randi_range(0,2)]
	_refresh_visuals()
func event_pending()->bool:return not state.is_empty() and record.kind=="event" and not bool(state.event_resolved)
func _ready_for_world()->bool:
	return is_instance_valid(main.player) and main.player.hp>0 and not TransitionLayer.busy and not get_tree().paused and not UIFlow.has_screen() and not bool(main.get("_navigation_pending")) and not bool(main.get("_room_transfer"))
func _process(dt:float)->void:
	if state.is_empty() or not (GameState.run_active or validation_mode) or not _ready_for_world():return
	state.clock=float(state.clock)+maxf(0,dt)
	if event_pending() and (not bool(state.event_started) or bool(state.get("event_panel_open",false))) and not is_instance_valid(panel) and main._story_queue.is_empty() and main._story_context.is_empty():
		state.event_started=true;open_event();return
	for reward in state.pending.duplicate():
		if not is_instance_valid(main.expedition):break
		state.pending.erase(reward)
		reward["coin_visual_scale"]=2.0/3.0
		main.expedition.loot.burst_reward(reward,main.level.nearest_clear(main.player.position+Vector2(0,40),8));_checkpoint()
	var scene:=str(record.get("terrain_layout",{}).get("scene_art",""))
	if scene=="normal_windbridge_v01":_wind_step()
	if record.cleared or main.director.phase!=WaveDirector.Phase.FIGHT or main.player.extraction_controls_locked():
		clear_danger_fields();return
	if record.kind=="trial" or scene in ["elite_boneflags_v01","elite_thorncourt_v01"]:
		state.pulse_left=float(state.pulse_left)-dt
		if float(state.pulse_left)<=0:
			state.pulse_left=8.0 if scene=="elite_boneflags_v01" else 10.0
			_spawn_field("thorn" if scene=="elite_thorncourt_v01" else ("bone" if scene=="elite_boneflags_v01" else "rune"))
	for field in state.fields.duplicate():
		field.age=float(field.age)+dt
		if float(field.age)>=0:_strike_field(field)
		if float(field.age)>float(field.life):state.fields.erase(field)
	_refresh_visuals()
func _checkpoint()->void:
	if not validation_mode:Outpost.request_checkpoint()
func _save_transaction()->bool:return validation_mode or SaveService.save_run(GameState.snapshot())
func altar_offers()->Array[Dictionary]:
	if state.is_empty():configure(main.graph.rooms[main.graph.current])
	if state.offers.is_empty():state.offers=AltarBlessings.offers(GameState.altar_blessings,main.director.wave)
	var result:Array[Dictionary]=[];result.assign(state.offers);return result
func claim_altar(item:Dictionary)->bool:
	if state.is_empty() or record.kind!="altar" or not record.cleared or record.rewarded or bool(state.altar_claimed):return false
	var eligible:Array=state.offers.filter(func(offer:Dictionary)->bool:return str(offer.id)==str(item.get("id","")))
	if eligible.is_empty():return false
	var id:=str(eligible[0].altar_key);var old_ranks:=GameState.altar_blessings.duplicate(true);var old_coins:=GameState.coins;var old_remainder:=GameState.auto_coin_remainder
	var old_offers:Array=main._reward_offers.duplicate(true);var old_wave:int=main._reward_wave
	if id=="echo":GameState.add_reward_coins(roundi(roundi(WaveTable.coin_reward(main.director.wave)*.6)*.5))
	else:
		if not AltarBlessings.DEFINITIONS.has(id) or AltarBlessings.total(old_ranks)>=6 or int(old_ranks.get(id,0))>=3:return false
		GameState.altar_blessings[id]=int(old_ranks.get(id,0))+1;GameState._reset_stats();EventBus.player_stats_changed.emit()
	state.altar_claimed=true;main._reward_offers.clear();main._reward_wave=-1;main.director.start_rest()
	if not _save_transaction():
		GameState.altar_blessings=old_ranks;GameState.coins=old_coins;GameState.auto_coin_remainder=old_remainder;GameState._reset_stats();EventBus.player_stats_changed.emit();EventBus.coins_changed.emit(old_coins)
		state.altar_claimed=false;record.rewarded=false;main.level.doors_open=false;main.director.phase=WaveDirector.Phase.CLEARED;main._reward_offers=old_offers;main._reward_wave=old_wave
		main.choice_ui.open(old_offers);main.hud.show_banner("保存失败，誓约与金币未提交，请重试",2);return false
	main.hud.show_banner("祭坛回响已领取" if id=="echo" else str(AltarBlessings.DEFINITIONS[id].name)+" · 本次出征永久",2)
	return true
func _materials(count:int)->Array:
	var result:Array=[];var biome:=str(record.get("biome","forest"));var id:="forest_sample" if biome=="forest" else ("wetland_sample" if biome=="wetland" else "ruin_sample")
	for index in count:
		var item:=ExpeditionData.material(id);item.sale_value=roundi(float(item.cost)*RunDifficulty.material_value_multiplier(GameState.difficulty)*maxf(1,GameState.stats.get_value(&"coin_gain")));result.append(item)
	return result
func _event_offers()->void:
	if not state.offers.is_empty():return
	var rng:=RandomNumberGenerator.new();rng.seed=int(record.seed)^0x90472
	match str(state.event_id):
		"letter":state.offers=[{"name":"封存信件","desc":"将这份心意留给后来者。获得三份地区材料。","loot":{"kind":"bundle","items":_materials(3)}},{"name":"留下回信","desc":"写下新的祝愿。获得100基础金币，沿用冒险收益倍率。","loot":{"kind":"coins","amount":100}}]
		"pack":state.offers=[{"name":"整理补给","desc":"带走一瓶能量药剂，使用后回复40MP。","loot":{"kind":"item","item":ExpeditionData.resolve("potion_energy")}},{"name":"收集散物","desc":"收拾仍可使用的材料。获得两份地区材料。","loot":{"kind":"bundle","items":_materials(2)}}]
		"page":
			var pool:Array[Dictionary]=[]
			for item in ItemDB.all():
				if ItemDB.is_relic(item) and int(item.get("rarity",0))==1 and ItemDB.in_source(item,&"reward") and ItemDB.can_refresh(item):pool.append(item)
			var first:Dictionary={"name":"解读残页","desc":"没有可用精良遗物，改获三份地区材料。","loot":{"kind":"bundle","items":_materials(3)}}
			if not pool.is_empty():
				var item:Dictionary=pool[rng.randi_range(0,pool.size()-1)].duplicate(true);ItemDB.record_refresh(item)
				first={"name":"解读残页","desc":"获得精良遗物：%s\n%s"%[item.name,item.desc],"loot":{"kind":"item","item":item}}
			state.offers=[first,{"name":"保存残页","desc":"替它寻找下一位解读者。获得150基础金币，沿用冒险收益倍率。","loot":{"kind":"coins","amount":150}}]
func open_event()->void:
	if not event_pending() or is_instance_valid(panel) or not _ready_for_world():return
	_event_offers();state.event_panel_open=true;panel=RoomEventUI.new();panel.controller=self;add_child(panel);_checkpoint()
func claim_event(index:int)->bool:
	if not event_pending() or index<0 or index>=state.offers.size():return false
	var before:=state.duplicate(true);state.pending.append(state.offers[index].loot.duplicate(true));state.event_resolved=true;state.chosen=index;record.rewarded=true;main.level.doors_open=true
	var evidence:=AchievementTracker.stage("event")
	if not _save_transaction():
		AchievementTracker.finish_stage(evidence,false)
		record.delta.expansion=before;state=record.delta.expansion;record.rewarded=false;main.level.doors_open=false;return false
	AchievementTracker.finish_stage(evidence,true)
	if is_instance_valid(panel):panel.close()
	return true
func _unhandled_input(event:InputEvent)->void:
	if not event_pending() or not event.is_action_pressed("interact") or event.is_echo() or not _ready_for_world():return
	var polygon:PackedVector2Array=main.level.scene_polygons.get("event_relic",PackedVector2Array())
	if polygon.size()<3:return
	var closest:=RoomSceneGeometry.closest_boundary_point(main.player.global_position,polygon)
	if main.player.global_position.distance_to(closest)>82 or not main.level.sight(main.player.global_position,closest.move_toward(main.player.global_position,1)):return
	open_event();get_viewport().set_input_as_handled()
static func actor_center(actor:Node2D)->Vector2:
	for child in actor.get_children():
		if child is CollisionShape2D and not child.disabled:return child.global_position
	return actor.global_position
func _effect_anchor(key:String,fallback:Vector2)->Vector2:
	var pair:Array=record.get("terrain_layout",{}).get("scene_effects",{}).get(key,[fallback.x,fallback.y])
	return Vector2(float(pair[0]),float(pair[1]))
func _wind_step()->void:
	var at:=_effect_anchor("wind",main.level.bounds().get_center()+Vector2(90,0));var point:=actor_center(main.player)
	var polygon:PackedVector2Array=main.level.scene_polygons.get("wind_stone",PackedVector2Array())
	var boundary:=RoomSceneGeometry.closest_boundary_point(point,polygon) if polygon.size()>=3 else at
	var inside:bool=point.distance_to(boundary)<=36 and main.level.sight(point,boundary.move_toward(point,1))
	if inside and not bool(state.wind_inside) and float(state.clock)>=float(state.wind_ready):
		state.wind_ready=float(state.clock)+8;GameState.add_temp_buff(&"mp_regen",.15,4,"风铃回响","room_windbridge");_checkpoint()
	state.wind_inside=inside
func _spawn_field(mode:String)->void:
	state.serial=int(state.serial)+1
	var fallback:Vector2=main.level.bounds().get_center()+Vector2(-108 if int(state.serial)%2==0 else 108,0)
	var at:=_effect_anchor("thorn" if mode=="thorn" else ("blade" if mode=="bone" else "rune"),fallback)
	var effects:Dictionary=record.get("terrain_layout",{}).get("scene_effects",{})
	var anchors:Array=effects.get(mode+"_anchors",[])
	if not anchors.is_empty():
		var pair:Array=anchors[posmod(int(state.serial)-1,anchors.size())];at=Vector2(float(pair[0]),float(pair[1]))
	var direction:Array=effects.get(mode+"_direction",[1,0])
	if not RoomExpansionRules.safe_point(main.level,at,12):return
	var unit:=WaveDirector.create_enemy(&"walker");var amount:float=unit.base_damage*main.director._damage_scale*main.director.pressure_attack_multiplier(main.director.room_pressure_step)*.35;unit.free()
	state.fields.append({"id":int(state.serial),"mode":mode,"at":[at.x,at.y],"direction":direction.duplicate(),"age":-1.0,"life":3.0 if mode=="thorn" else .25,"damage":amount,"pressure_step":main.director.room_pressure_step,"hits":[]})
	_refresh_visuals();_checkpoint()
func _field_legal(field:Dictionary,point:Vector2)->bool:
	var at:=Vector2(field.at[0],field.at[1])
	return main.level.bounds().grow(-6).has_point(point) and main.level.body_clear(point,4) and main.level.sight(at,point) and RoomExpansionRules.safe_point(main.level,point,4)
func _strike_field(field:Dictionary)->void:
	var at:=Vector2(field.at[0],field.at[1]);var targets:Array[Node2D]=[]
	if field.mode=="thorn":
		for actor in get_tree().get_nodes_in_group("room_units"):
			if actor is Node2D and actor.get("room")==main.level and actor.get("hp")!=null and float(actor.hp)>0 and not actor.is_queued_for_deletion():targets.append(actor)
	else:
		targets.append(main.player)
		for actor in get_tree().get_nodes_in_group("allies"):
			if actor is Node2D and actor.get("room")==main.level and float(actor.hp)>0 and not actor.is_queued_for_deletion():targets.append(actor)
	for actor in targets:
		var point:=actor_center(actor);var offset:=point-at
		var direction:=Vector2(float(field.direction[0]),float(field.direction[1])).normalized()
		if absf(offset.dot(direction))>72 or absf(offset.cross(direction))>18 or not _field_legal(field,point):continue
		if field.mode=="thorn":
			if actor.has_method("is_flying") and actor.is_flying():continue
			if actor is Player:PlayerDebuffs.apply(actor,{"id":"thorn_step","duration":2,"strength":.2})
			elif actor.has_method("apply_slow"):actor.apply_slow(.2,2)
		else:
			var key:="player" if actor is Player else str(actor.uid)
			if field.hits.has(key):continue
			var pressure:float=main.director.pressure_attack_multiplier(main.director.room_pressure_step)/main.director.pressure_attack_multiplier(int(field.get("pressure_step",main.director.room_pressure_step)))
			field.hits.append(key);actor.take_damage(float(field.damage)*pressure,at,null)
func clear_danger_fields()->void:
	if state.is_empty():return
	state.fields.clear();_refresh_visuals()
func _refresh_visuals()->void:
	var alive:Dictionary={}
	for field in state.get("fields",[]):
		var id:=str(field.id);alive[id]=true
		if not visuals.has(id) or not is_instance_valid(visuals[id]):
			var visual:=RoomExpansionField.new();visual.controller=self;visual.field=field;add_child(visual);visuals[id]=visual
		visuals[id].queue_redraw()
	for id in visuals.keys():
		if not alive.has(id):
			if is_instance_valid(visuals[id]):visuals[id].queue_free()
			visuals.erase(id)
