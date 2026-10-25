class_name GMPilot
extends Node
## Shared GM / developer-test pilot. No virtual input, stat changes or privileged rewards.
var main
var _banner:HBoxContainer
var _banner_label:Label
var _elapsed:=0.0
var _menu_elapsed:=0.0
var _gear_elapsed:=0.0
var _last_room:=""
var _last_position:=Vector2.INF
var _stuck:=0.0
var _ignored:Dictionary={}
var _loot_target:WeakRef
var _loot_seconds:=0.0
var _exit_last_position:=Vector2.INF
var _exit_stalled:=0.0
var _orbit:=1.0
var _exit_ignored:Dictionary={}
var _exit_target:=""
var _exit_seconds:=0.0
var _rest_seconds:=0.0
var supplies=preload("res://src/room_mode/bot_supplies.gd").new()
const EQUIPMENT_WEIGHTS:={&"attack":150.0,&"max_hp":120.0,&"attack_speed":120.0,&"mp_regen":110.0,&"move_speed":90.0}

func _ready()->void:
	supplies.pilot=self
	process_mode=Node.PROCESS_MODE_ALWAYS
	var layer:=CanvasLayer.new();layer.layer=62;add_child(layer)
	var root:=UiFactory.full_rect();root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
	_banner=UiFactory.hbox(10);_banner.alignment=BoxContainer.ALIGNMENT_CENTER;root.add_child(_banner);_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_banner.offset_left=-190;_banner.offset_right=190;_banner.offset_top=-151;_banner.offset_bottom=-119
	var label:=PixelUi.label("GM正在操作你的角色",18,Color("f2d68b"));_banner_label=label;label.add_theme_constant_override("outline_size",3);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;_banner.add_child(label)
	var exit_button:=PixelUi.compact_button("×",22);exit_button.name="StopGMPilot";exit_button.custom_minimum_size=Vector2(36,32);exit_button.tooltip_text="结束 GM 代行";_banner.add_child(exit_button);exit_button.pressed.connect(stop)
	InteractionSkin.apply_button(exit_button,"gm_pilot");_banner.hide()

func activate()->bool:
	return _activate(false)
func activate_for_test()->bool:
	if not BotTestControl.available():return false
	return _activate(true)
func _activate(repeatable:bool)->bool:
	if not GameState.run_active or CampSession.active or GameState.gm_pilot_active or (GameState.gm_pilot_used and not repeatable) or not is_instance_valid(main) or not is_instance_valid(main.player) or main.player.hp<=0:return false
	GameState.gm_pilot_used=true;GameState.gm_pilot_active=true;_ignored.clear();_stuck=0;_last_room=""
	_elapsed=0;_menu_elapsed=0;_gear_elapsed=0
	supplies.reset()
	_banner_label.text="Bot 测试中 · B 或 × 停止" if repeatable else "GM正在操作你的角色"
	return true
func stop()->void:
	GameState.gm_pilot_active=false;_clear_controls();_banner.hide()
	if is_instance_valid(main.player) and RoomInput.using_mouse():main.player._mouse_attack_blocked=true
	if GameState.run_active:Outpost.request_checkpoint()
func _clear_controls()->void:
	if is_instance_valid(main.player):main.player.movement_override=Vector2.ZERO;main.player.aim_override=Vector2.ZERO
func _process(delta:float)->void:
	var active:bool=GameState.gm_pilot_active and GameState.run_active and not CampSession.active and is_instance_valid(main.player) and main.player.hp>0
	_banner.visible=active
	if not active:
		if GameState.gm_pilot_active:GameState.gm_pilot_active=false;_clear_controls()
		return
	_elapsed+=delta;_menu_elapsed+=delta;_gear_elapsed+=delta
	if _elapsed<.08:return
	var step:=_elapsed;_elapsed=0
	if TransitionLayer.busy or main._navigation_pending or main._room_transfer:_clear_controls();return
	if UIFlow.has_screen():
		_clear_controls()
		if _menu_elapsed>=.7:_menu_elapsed=0;_advance_screen()
		return
	if get_tree().paused or main.player.extraction_controls_locked():_clear_controls();return
	var actor:RoomPlayer=main.player
	_use_capacity_potion(actor)
	if _last_room!=str(main.graph.current):_last_room=str(main.graph.current);_ignored.clear();_stuck=0;_last_position=actor.global_position;_loot_target=null;_loot_seconds=0;_exit_last_position=Vector2.INF;_exit_stalled=0;_exit_ignored.clear();_exit_target="";_exit_seconds=0;_rest_seconds=0
	_stuck=_stuck+step if actor.global_position.distance_to(_last_position)<2 and not actor.movement_override.is_zero_approx() else 0
	_last_position=actor.global_position
	if _gear_elapsed>=1:_gear_elapsed=0;_equip_upgrades();_develop_character()
	if _recover_footing():return
	if main.special_rooms.chase_running():
		_evade_shadow();return
	var enemies:=actor.equipment_mechanics.nearest_enemies(actor.global_position,1600,100)
	# A blocked enemy still needs to be approached, even without line of fire.
	var target:EnemyBase=_priority_summoner()
	if target==null and not enemies.is_empty():target=enemies[0]
	if target==null:
		var best:=INF
		for node in main.enemies_root.get_children():
			if node is EnemyBase and not node._dead and not node.is_queued_for_deletion() and node.hp>0:
				var distance:=actor.global_position.distance_squared_to(node.global_position)
				if distance<best:best=distance;target=node
	actor.aim_override=(target.global_position-actor.global_position).normalized() if target!=null else Vector2.ZERO
	if target!=null:
		_combat(target)
		return
	actor.movement_override=Vector2.ZERO
	if main.expansion.event_pending():
		var polygon:PackedVector2Array=main.level.scene_polygons.get("event_relic",PackedVector2Array())
		if polygon.size()>=3:
			var boundary:=RoomSceneGeometry.closest_boundary_point(actor.global_position,polygon)
			if actor.global_position.distance_to(boundary)<=78:main.expansion.open_event()
			else:actor.movement_override=main.level.path_direction(actor.global_position,main.level.nearest_clear(boundary.move_toward(actor.global_position,20),12),12,false)
		return
	if not main.safe_room():return
	if _collect_room_loot(step):return
	# Give scheduled deliveries and opened chest bursts time to resolve.
	for chest in main.chests_root.get_children():
		if chest is Chest and (not chest._landed or chest._opening):return
	for delivery in main.special_rooms.state.get("deliveries",[]):
		if not bool(delivery.delivered):return
	if supplies.visit(step):return
	if _prepare_departure(step):return
	# Loot collection can carry the pilot out of the terminal through an open
	# door. Third-stage completion still permits normal extraction elsewhere.
	var completed_third_elsewhere:bool=main.graph.staged and main.graph.stage_index==3 and main.graph.normal_clear_eligible
	if main.graph.staged and main.graph.stage_boss_cleared and (main.graph.current==main.graph.stage_terminal or completed_third_elsewhere):
		_clear_controls()
		if main.graph.stage_index<3:main.advance_stage()
		elif main.expedition.extraction.state==ExtractionDirector.IDLE:
			# Repeating request during prayer/waiting toggles the player's cancel action.
			main._request_chapter_exit()
		return
	_go_to_next_room(step)

func _prepare_departure(step:float)->bool:
	var actor:RoomPlayer=main.player
	if actor.hp<actor.max_hp*.65:_use_potion("heal")
	if GameState.mp<GameState.MAX_MP*.35:_use_potion("mana")
	var exits:=_frontier_exits()
	if exits.is_empty() or main.graph.rooms[exits[0]].kind!="boss":return false
	# Rest only on cleared ground, using normal regeneration and cooldowns.
	# Bound the wait so a mana-suppressing effect cannot halt exploration.
	if GameState.mp<70 and _rest_seconds<15:
		_rest_seconds+=step;actor.movement_override=Vector2.ZERO;return true
	return false

func _priority_summoner()->EnemyBase:
	var selected:EnemyBase;var nearest:=INF;var priority:=0
	for unit in main.level.tactics.enemies(main.level):
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit._dead or unit.hp<=0:continue
		var rank:=0
		if unit is RoomEnemy:
			var recurring:bool=unit.kind==&"caster"
			# Finish the summoner after its escort appears. Dropping its priority at
			# half health switches to the next guardian and releases another escort.
			var escort_summoner:bool=unit.has_affix(EnemyAffixes.GUARDIAN)
			if recurring or escort_summoner:rank=2
		elif unit is RoomBoss and not unit._minion_kinds.is_empty():rank=1
		if rank==0:continue
		var distance:float=main.player.global_position.distance_squared_to(unit.global_position)
		if rank==2:distance*=.5+.5*clampf(unit.hp/maxf(1,unit.max_hp),0,1)
		if rank>priority or (rank==priority and distance<nearest):selected=unit;nearest=distance;priority=rank
	return selected

func _recover_footing()->bool:
	var actor:RoomPlayer=main.player
	if actor._dash_timer>0 or main.level.body_clear(actor.global_position,12):return false
	# Physical boxes and navigation's circular clearance differ at prop edges.
	# Walk back onto valid ground before asking the pathfinder for another route.
	var clear:Vector2=main.level.nearest_clear(actor.global_position,12)
	var direction:Vector2=(clear-actor.global_position).normalized()
	actor.movement_override=direction;actor.aim_override=Vector2.ZERO
	if _stuck>1 and actor._dash_cd<=0 and not direction.is_zero_approx():actor.request_dash_direction(direction)
	return true

func _evade_shadow()->void:
	var actor:RoomPlayer=main.player;var pursuer:RoomShadowChaser=main.special_rooms.shadow
	var pursuers:Array[RoomShadowChaser]=main.special_rooms.active_shadows()
	actor.aim_override=Vector2.ZERO;actor.movement_override=Vector2.ZERO
	if pursuers.is_empty():return
	for candidate in pursuers:
		if not is_instance_valid(pursuer) or candidate.global_position.distance_squared_to(actor.global_position)<pursuer.global_position.distance_squared_to(actor.global_position):pursuer=candidate
	var best:=-INF;var away:=actor.global_position-pursuer.global_position
	for index in 16:
		var direction:=Vector2.RIGHT.rotated(index*TAU/16)
		var goal:Vector2=main.level.nearest_clear(actor.global_position+direction*130,12)
		if goal.distance_to(actor.global_position)<45 or not main.level.segment_clear(actor.global_position,goal,12,false):continue
		var gap:=INF
		for candidate in pursuers:gap=minf(gap,goal.distance_to(candidate.global_position))
		var score:float=gap+direction.dot(away.normalized())*50
		if score>best:best=score;actor.movement_override=(goal-actor.global_position).normalized()
	if actor.movement_override.is_zero_approx():
		var goal:Vector2=main.level.nearest_clear(main.level.bounds().get_center()+away.normalized()*200,12)
		actor.movement_override=main.level.path_direction(actor.global_position,goal,12,false)
	if away.length()<85 and actor._dash_cd<=0:actor.request_dash_direction(actor.movement_override)

func _combat(target:EnemyBase)->void:
	supplies.use_buff()
	var actor:RoomPlayer=main.player;var offset:=target.global_position-actor.global_position;var distance:=offset.length()
	actor.aim_direction=offset.normalized()
	var clear_shot:bool=main.level.projectile_clear(actor.global_position,target.global_position)
	var threats:=_visible_threats()
	var danger:=_danger_at(actor.global_position,threats)
	var route:Vector2=Vector2.ZERO if clear_shot else main.level.path_direction(actor.global_position,main.level.nearest_clear(target.global_position,12),12,false)
	# Obstructed line of fire must not bypass projectile/windup avoidance.
	actor.movement_override=_combat_motion(target,threats,route)
	if (danger>150 or distance<65 or _stuck>2) and actor._dash_cd<=0:
		var direction:=_dash_escape(target,threats,actor.movement_override)
		actor.request_dash_direction(direction);_stuck=0
	if actor.hp<actor.max_hp*.5:_use_potion("heal")
	if GameState.mp<GameState.MAX_MP*.25:_use_potion("mana")
	var order:Array=[2,3,0,1] if actor.hp<actor.max_hp*.65 or danger>150 else [3,0,1,2]
	if Characters.current_id()==&"sylphiette":order=[2,1,3,0] if danger>0 or actor.hp<actor.max_hp*.65 else [1,3,0,2]
	for slot in order:
		if GameState.skill_ready(slot) and _should_cast(GameState.skill_for_slot(slot),distance,danger) and actor.caster.cast(slot):break

func _visible_threats()->Dictionary:
	var bullets:Array=[];var warnings:Array=[];var hazards:Array=[];var enemies:Array=[]
	var origin:Vector2=main.player.global_position
	for node in get_tree().get_nodes_in_group("room_projectiles"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():continue
		if node is RoomProjectile and not node.is_friendly and node.room==main.level and origin.distance_squared_to(node.global_position)<500*500:bullets.append(node)
	for node in get_tree().get_nodes_in_group("boss_pattern_warnings"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.room==main.level:warnings.append(node)
	for node in get_tree().get_nodes_in_group("affix_hazards"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.room==main.level and node.mode in [&"grave",&"trail"]:hazards.append(node)
	for node in main.level.tactics.enemies(main.level):
		if is_instance_valid(node) and not node._dead and not node.is_queued_for_deletion() and node.hp>0:enemies.append(node)
	return {"bullets":bullets,"warnings":warnings,"hazards":hazards,"enemies":enemies}

func _bullet_risk(origin:Vector2,motion:Vector2,bullets:Array)->float:
	var risk:=0.0
	for bullet:RoomProjectile in bullets:
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():continue
		var relative:=bullet.global_position-origin
		var velocity:=bullet.direction*bullet.speed-motion
		var time:=clampf(-relative.dot(velocity)/maxf(1,velocity.length_squared()),0,.6)
		var gap:float=(relative+velocity*time).length()
		var clearance:=bullet.hit_radius+22
		if gap<clearance:risk+=(600+(clearance-gap)*16)*(1-time*.5/.6)
	return risk

func _danger_at(point:Vector2,threats:Dictionary,include_bullets:=true)->float:
	var risk:=0.0
	for enemy:EnemyBase in threats.enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy._dead:continue
		var distance:=point.distance_to(enemy.global_position+enemy.velocity*.2)
		var clearance:=70.0 if enemy is BossBase else 48.0
		if distance<clearance:risk+=(clearance-distance)*14+100
		if enemy is RoomEnemy:
			# Read visible windups, not just already-fired projectiles. Charging
			# melee units also cover much more ground than their contact radius.
			if enemy._windup>0 or enemy._rush>0:
				var charging:=enemy.kind in [&"charger",&"treant",&"moss_badger"]
				if charging or EnemyCombatPolicy.ranged_affix_allowed(enemy.kind):
					var reach:=maxf(100,enemy.move_speed*1.35) if charging else 320.0
					var near:=Geometry2D.get_closest_point_to_segment(point,enemy.global_position,enemy.global_position+enemy._locked_direction*reach)
					var gap:=point.distance_to(near)
					if gap<36:risk+=900+(36-gap)*15
			risk+=_affix_warning_risk(point,enemy)
			for flame:Dictionary in enemy.flame_pending:
				if point.distance_to(flame.at)<float(flame.get("radius",72))+18:risk+=1200
	if include_bullets:risk+=_bullet_risk(point,Vector2.ZERO,threats.bullets)
	for warning:BossPatternWarning in threats.warnings:
		var spec:Dictionary=warning.spec;var offset:Vector2=point-warning.global_position
		# Green corridors describe visible safe space, so seek their center
		# instead of treating the same line as an incoming hostile beam.
		if bool(spec.get("safe_corridor",false)):
			var center:=Geometry2D.get_closest_point_to_segment(point,warning.global_position,spec.get("end",warning.global_position))
			var outside:=maxf(0,point.distance_to(center)-42)
			if outside>0:risk+=1200+outside*12
			continue
		var shape:=str(spec.get("shape","circle"));var radius:=float(spec.get("radius",60))+18
		var direction:Vector2=spec.get("dir",Vector2.RIGHT);var inside:=false
		if shape=="line":inside=Geometry2D.get_closest_point_to_segment(point,warning.global_position,spec.get("end",warning.global_position+direction*radius)).distance_to(point)<float(spec.get("width",18))+18
		elif shape=="fan":inside=offset.length()<radius and absf(direction.angle_to(offset))<float(spec.get("spread",1))*.5+.15
		elif shape=="ring":
			var gap:Vector2=spec.get("gap",direction)
			inside=offset.length()<radius and absf(gap.angle_to(offset))>float(spec.get("opening",.8))*.5
			if bool(spec.get("opposite_gap",false)) and absf((-gap).angle_to(offset))<float(spec.get("opening",.8))*.5:inside=false
		else:inside=offset.length()<radius
		if inside:
			# A flat penalty traps the pilot inside wide attacks: every sampled
			# point looks equally unsafe. Prefer progress toward the nearest edge.
			var depth:=maxf(0,radius-offset.length())
			if shape=="line":depth=maxf(0,float(spec.get("width",18))+18-Geometry2D.get_closest_point_to_segment(point,warning.global_position,spec.get("end",warning.global_position+direction*radius)).distance_to(point))
			elif shape=="fan":depth=minf(depth,maxf(0,(float(spec.get("spread",1))*.5+.15-absf(direction.angle_to(offset)))*offset.length()))
			risk+=1200+depth*12
	for hazard:AffixHazard in threats.hazards:
		if point.distance_to(hazard.global_position)<(90.0 if hazard.mode==&"grave" else 30.0):risk+=700
	return risk


func _affix_warning_risk(point:Vector2,enemy:RoomEnemy)->float:
	# Read only the already-visible affix windup, never clocks or future rolls.
	if not is_instance_valid(enemy) or enemy._dead or enemy.hp<=0 or enemy.is_queued_for_deletion():return 0.0
	var runtime:=enemy.affix_runtime
	if not is_instance_valid(runtime) or runtime.is_queued_for_deletion() or enemy.room!=main.level:return 0.0
	if not main.level.bounds().grow(-6).has_point(point):return 0.0
	var risk:=0.0
	if runtime.stage_left>0 and runtime.active_id in [EnemyAffixes.SHOCK_RING,EnemyAffixes.VINE_SNARE] and main.level.projectile_clear(enemy.global_position,point):
		# Releases create the effect at the enemy's current position, including knockback.
		var offset:=point-enemy.global_position
		if runtime.active_id==EnemyAffixes.SHOCK_RING:
			var distance:=offset.length()
			if distance>=72 and distance<=144:risk+=1200+minf(distance-72,144-distance)*12
		else:
			var forward:=offset.dot(runtime.locked_aim);var lateral:=absf(offset.cross(runtime.locked_aim))
			if forward>=0 and forward<=180 and lateral<=18:risk+=1200+minf(minf(forward,180-forward),18-lateral)*12
	if runtime.echo_left>0 and main.level.projectile_clear(runtime.echo_origin,point):
		var offset:=point-runtime.echo_origin;var distance:=offset.length()
		if EnemyCombatPolicy.ranged_affix_allowed(runtime.echo_kind) or enemy.has_affix(EnemyAffixes.RANGED):
			# Ranged echoes show a 100px line; normal bullet prediction takes over on release.
			var forward:=offset.dot(runtime.echo_aim);var lateral:=absf(offset.cross(runtime.echo_aim))
			if forward>=0 and forward<=100 and lateral<=22:risk+=900+minf(minf(forward,100-forward),22-lateral)*12
		elif runtime.echo_kind==&"bomber":
			if distance>=1 and distance<=100:risk+=900+(100-distance)*12
		elif distance>=1 and distance<=80 and runtime.echo_aim.dot(offset.normalized())>=.65:
			var edge:=maxf(0,(acos(.65)-absf(runtime.echo_aim.angle_to(offset)))*distance)
			risk+=900+minf(80-distance,edge)*12
	return risk

func _dash_escape(target:EnemyBase,threats:Dictionary,preferred:Vector2)->Vector2:
	var actor:RoomPlayer=main.player;var best:=INF;var result:=preferred
	var distance:=actor.stats.get_value(&"move_speed")*2.7*.16
	for index in 16:
		var direction:=Vector2.RIGHT.rotated(index*TAU/16)
		var point:=actor.global_position+direction*distance
		if not main.level.body_clear(point,12):continue
		if not main.level.unit_position_clear(point,12,actor):continue
		var score:=_danger_at(point,threats)-direction.dot(preferred)*30
		# Basic dashes may cross terrain and units, but land on valid ground.
		if score<best:best=score;result=direction
	return result if not result.is_zero_approx() else (actor.global_position-target.global_position).normalized()

func _combat_motion(target:EnemyBase,threats:Dictionary,route:=Vector2.ZERO)->Vector2:
	var actor:RoomPlayer=main.player;var origin:=actor.global_position
	var desired:=clampf(float(WeaponArt.profile().get("reach",540))*.46,170,250)
	if target is BossBase and Characters.current_id()==&"ilyua":desired=clampf(float(WeaponArt.profile().get("reach",540))*.65,260,340)
	elif target is BossBase and Characters.current_id()==&"sylphiette":
		var dawn_soon:bool=float(GameState.skill_cooldowns_by_id.get(&"flame_nova",0))<1.5 and GameState.mp>=GameState.skill_cost(&"flame_nova") and _should_cast(&"flame_nova",200,0)
		desired=220 if dawn_soon else 300
	var best:=-INF;var result:=Vector2.ZERO
	var tangent:Vector2=(target.global_position-origin).normalized().orthogonal()*_orbit
	for index in 18:
		var direction:Vector2=route if index==17 else Vector2.ZERO if index==16 else Vector2.RIGHT.rotated(index*TAU/16)
		var point:=origin+direction*maxf(55,actor.stats.get_value(&"move_speed")*.4)
		if not _walk_clear(origin,point):
			point=origin+direction*24
			if not _walk_clear(origin,point):continue
		var score:float=-absf(point.distance_to(target.global_position)-desired)*.7-_danger_at(point,threats,false)-_danger_at(origin.lerp(point,.5),threats,false)*.25-_bullet_risk(origin,direction*actor.stats.get_value(&"move_speed"),threats.bullets)+direction.dot(tangent)*12+direction.dot(route)*90
		var border:Rect2=main.level.bounds()
		var edge:=minf(minf(point.x-border.position.x,border.end.x-point.x),minf(point.y-border.position.y,border.end.y-point.y))
		if edge<60:score-=(60-edge)*2
		if not main.level.projectile_clear(point,target.global_position):score-=160
		if score>best:best=score;result=direction
	if result==Vector2.ZERO and _stuck>1:_orbit=-_orbit
	return result

func _walk_clear(origin:Vector2,point:Vector2)->bool:
	# Navigation uses a circle, while the playable body is a rectangle. Use
	# the real collider too, including units, before choosing a walking lane.
	return main.level.body_clear(point,12) and main.level.segment_clear(origin,point,12,false) and not main.player.test_move(main.player.global_transform,point-origin)

func _should_cast(id:StringName,distance:float,danger:float)->bool:
	var actor:RoomPlayer=main.player
	if Characters.current_id()==&"ilyua" and id!=&"ilyua_forest_step" and GameState.learned_skills.has(&"ilyua_forest_step") and float(GameState.skill_cooldowns_by_id.get(&"ilyua_forest_step",0))<2:
		if GameState.mp<GameState.skill_cost(id)+GameState.skill_cost(&"ilyua_forest_step"):return false
	if Characters.current_id()==&"sylphiette" and id!=&"blink" and GameState.unlocked_skills.has(&"blink") and actor.shield_hp<actor.max_hp*.08:
		var until_shield:float=maxf(0,GameState.skill_cooldowns_by_id.get(&"blink",0))
		if GameState.mp-GameState.skill_cost(id)+GameState.total_mp_regen(actor.stats)*until_shield<GameState.skill_cost(&"blink"):return false
	match id:
		&"homeward_light":
			if actor.hp<actor.max_hp*.88:return true
			for ally in actor.summons.companions():
				if ally.hp<ally.max_hp*.65:return true
			return false
		&"night_shelter":return actor.shield_hp<actor.max_hp*.08
		&"blink":return actor.shield_hp<actor.max_hp*.08 and (danger>0 or distance<180 or GameState.mp>GameState.MAX_MP*.8)
		&"ilyua_forest_step",&"healing_light":return danger>150 or distance<110
		&"flame_shield",&"shadow_step":return distance<120
		&"flame_nova":return distance<250
		&"ilyua_hunter_mark",&"ilyua_vine_trap":return distance<235
	return true

func _use_potion(kind:String)->void:
	if kind=="heal" and is_instance_valid(main) and is_instance_valid(main.player) and main.player.bloodbath_active():return
	for item in GameState.items.duplicate():
		if ItemDB.is_usable(item) and str(item.get("effect",{}).get("kind",""))==kind:
			GameState.use_item(item);return

func _use_capacity_potion(actor:RoomPlayer)->void:
	# Only consume an owned repair item when an actual scar can be restored.
	var full:=actor.stats.get_value(&"max_hp")
	if actor.permanent_hp_loss()>=full*.15 or (actor.permanent_hp_loss()>0 and actor.hp<full*.45):
		_use_potion("repair_capacity")

func _collect_room_loot(delta:float)->bool:
	var actor:RoomPlayer=main.player;var target:Node2D;var best:=INF
	for parent in [main.chests_root,main.fx_root]:
		for node in parent.get_children():
			if not node is Node2D or node.is_queued_for_deletion() or _ignored.has(node.get_instance_id()):continue
			var eligible:bool=node is Chest and not node.is_open and node._landed
			eligible=eligible or node is RoomLootDrop and not node._collected or node is Coin and not node._collected
			if not eligible:continue
			var distance:=actor.global_position.distance_squared_to(node.global_position)
			if distance<best:best=distance;target=node
	if target==null:_loot_target=null;_loot_seconds=0;return false
	if _loot_target==null or _loot_target.get_ref()!=target:_loot_target=weakref(target);_loot_seconds=0
	_loot_seconds+=delta
	if _loot_seconds>8:_ignored[target.get_instance_id()]=true;_loot_target=null;return true
	if target is Chest and target.in_range:target.try_interact();return true
	actor.movement_override=main.level.path_direction(actor.global_position,main.level.nearest_clear(target.global_position,12),12,false)
	if actor.movement_override.is_zero_approx() and _loot_seconds>1.5 and actor.global_position.distance_to(target.global_position)>40:
		_ignored[target.get_instance_id()]=true;_loot_target=null
	return true

func _frontier_exits()->Array[String]:
	var graph:RoomGraph=main.graph
	var pending:Array=[{"id":graph.current,"first":"","depth":0}];var seen:Dictionary={graph.current:true};var exits:Array[String]=[];var scores:Dictionary={}
	var index:=0
	while index<pending.size():
		var entry:Dictionary=pending[index];index+=1
		var record:Dictionary=graph.rooms.get(entry.id,{})
		var service_score:float=supplies.priority(str(entry.id))
		if entry.id!=graph.current and (service_score>0 or not bool(record.get("visited",true)) or not bool(record.get("cleared",false))):
			if not str(entry.first) in exits:exits.append(str(entry.first))
			var score:float=float({"boss":130,"normal":100,"reward":110,"altar":90,"event":80,"shop":55,"tavern":50,"trial":35,"elite":20,"game":10,"boss_rush":5}.get(str(record.get("kind","")),0))-float(entry.depth)*3
			score=maxf(score,service_score-float(entry.depth)*3)
			scores[str(entry.first)]=maxf(float(scores.get(str(entry.first),-INF)),score)
			continue
		for id in graph.rooms.get(entry.id,{}).get("doors",[]):
			if not graph.rooms.has(id) or seen.has(id) or RoomGraph.cell(str(id))-RoomGraph.cell(str(entry.id)) not in RoomGraph.DIRECTIONS:continue
			seen[id]=true;pending.append({"id":id,"first":id if entry.id==graph.current else entry.first,"depth":int(entry.depth)+1})
	exits.sort_custom(func(left:String,right:String)->bool:return float(scores.get(left,0))>float(scores.get(right,0)))
	return exits

func _go_to_next_room(step:=0.15)->void:
	var graph:RoomGraph=main.graph
	var exits:=_frontier_exits()
	for id in _exit_ignored.keys():
		_exit_ignored[id]=float(_exit_ignored[id])-step
		if float(_exit_ignored[id])<=0:_exit_ignored.erase(id)
	if not _exit_target.is_empty():
		_exit_seconds+=step
		if _exit_seconds>12:
			_exit_ignored[_exit_target]=8.0;_exit_target="";_exit_seconds=0
	if exits.is_empty():
		var protected:=graph._ensure_frontier()
		if not protected.is_empty():
			graph.prune_rooms(protected);Outpost.request_checkpoint();exits=_frontier_exits()
	main.level.sync_door_links(graph.rooms[graph.current])
	var actor:RoomPlayer=main.player
	_exit_stalled=_exit_stalled+step if actor.global_position.distance_to(_exit_last_position)<2 else 0.0
	_exit_last_position=actor.global_position
	for destination in exits:
		if _exit_ignored.has(destination):continue
		var direction:=RoomGraph.cell(destination)-RoomGraph.cell(graph.current)
		var point:Vector2=main.level.door_point(direction)
		if main.level.door_at(actor.global_position)==direction:actor.movement_override=Vector2.ZERO;return
		# Route into the real trigger disk, not to a wall-edge/grid approximation.
		var side:=Vector2(direction).orthogonal()
		var candidates:Array[Vector2]=[point,point-Vector2(direction)*10,point+side*14,point-side*14,point-Vector2(direction)*18+side*14,point-Vector2(direction)*18-side*14]
		var nearest:Vector2=main.level.nearest_clear(point,12)
		if nearest.distance_to(point)<32:candidates.append(nearest)
		for goal in candidates:
			if not main.level.body_clear(goal,12):continue
			var motion:Vector2=main.level.path_direction(actor.global_position,goal,12,false)
			if motion.is_zero_approx():continue
			if _exit_target!=destination:_exit_target=destination;_exit_seconds=0
			actor.movement_override=motion
			if _exit_stalled>1.0:
				var detour:Vector2=main.level.crowd_detour(actor.global_position,motion,12,actor)
				if not detour.is_zero_approx():actor.movement_override=detour
			if _exit_stalled>2.0 and actor._dash_cd<=0:
				actor.request_dash_direction(motion);_exit_stalled=0.0
			return
	actor.movement_override=Vector2.ZERO

func _advance_screen()->void:
	var current:Node=UIFlow.top_screen()
	if current is FateChoiceUI:supplies.choose_fate(current);return
	if current is GlassConfirmUI and current.get_parent() is FateChoiceUI:supplies.confirm_fate(current.get_parent());return
	if current is ShopUI or current is TavernUI:supplies.service_step(current);return
	if current is GlassConfirmUI and bool(current.get_parent().get_meta("starting_star_choice",false)):
		current._dismiss(true);return
	if is_instance_valid(current) and bool(current.get_meta("starting_star_choice",false)):
		current.choose(1 if Characters.current_id()==&"sylphiette" else 0);return
	if main.choice_ui.is_open() and UIFlow.is_top(main.choice_ui):
		var best:=-INF;var selected:=0
		for index in main.choice_ui.offers.size():
			var item:Dictionary=main.choice_ui.offers[index];var score:=20.0+int(item.get("rarity",0))*10
			if ItemDB.is_equippable(item):score=_equipment_score(item)
			elif ItemDB.is_relic(item):
				var copies:=0
				for held in GameState.items:
					if str(held.get("id",""))==str(item.get("id","")):copies+=1
				score-=mini(copies,2)*6
			if score>best:best=score;selected=index
		main.choice_ui._choose_from_input(selected,main.choice_ui._selection_epoch,true)
	elif main.chapter_end_ui.is_open() and UIFlow.is_top(main.chapter_end_ui):
		# Use the player's button path, including reveal completion and its
		# single-submit guard, rather than bypassing chapter settlement.
		for button in main.chapter_end_ui._root.find_children("*","Button",true,false):
			if button.is_visible_in_tree() and not button.disabled and button.text.begins_with("继续无尽"):
				button.pressed.emit();break
	elif main.dialogue.is_open() and UIFlow.is_top(main.dialogue):
		if main.dialogue._choosing:
			var options:Array=main.dialogue._choice_box.get_children();var button:Button
			for candidate in options:
				if candidate is Button and candidate.visible and not candidate.disabled:
					if button==null:button=candidate
					if candidate.text.contains("继续") or candidate.text.contains("深入"):button=candidate;break
			if button!=null:button.pressed.emit()
		else:main.dialogue._advance()
	elif is_instance_valid(main.expansion.panel) and UIFlow.is_top(main.expansion.panel):
		var panel:RoomEventUI=main.expansion.panel
		if int(main.expansion.state.dialogue)<2:panel._advance()
		else:panel._claim(0)

func _equipment_score(item:Dictionary)->float:
	if not ItemDB.can_equip(item):return -1000
	var stats:=GameState.preview_with(item)
	# Log ratios keep relative stat weights without valuing both directions of
	# the same trade as upgrades, which otherwise causes endless equipment swaps.
	var delta:=0.0
	for stat in EQUIPMENT_WEIGHTS:
		var before:=GameState.stats.get_value(stat)
		delta+=log(maxf(.1,stats.get_value(stat))/maxf(.1,before))*float(EQUIPMENT_WEIGHTS[stat])
	delta+=(stats.get_value(&"crit_chance")-GameState.stats.get_value(&"crit_chance"))*100
	delta+=(stats.get_value(&"lifesteal")-GameState.stats.get_value(&"lifesteal"))*150
	delta-=log(maxf(.1,stats.get_value(&"dash_cooldown"))/maxf(.1,GameState.stats.get_value(&"dash_cooldown")))*80
	var combat_value:bool=delta>0 or not item.get("mechanics",[]).is_empty()
	var fill:=50.0 if combat_value and GameState.equipped(ItemDB.slot_of(item)).is_empty() else 0.0
	var own_set:Dictionary=LegendarySets.DATA.get(Characters.current_id(),{})
	var set_piece:=str(item.get("id",""))==str(own_set.get(str(ItemDB.slot_of(item)),"missing"))
	return delta+fill+int(item.get("rarity",0))*3+5+(200 if set_piece else 0)

func _develop_character()->void:
	# Use the exact player APIs: earned points, prerequisites and per-ID cooldowns.
	while GameState.talent_points>0:
		var chosen:StringName=&"";var least:=4
		for skill:StringName in GameState.skill_loadout():
			for route:StringName in [&"link",&"power",&"shape"]:
				var id:=SkillTalentCatalog.route_id(skill,route)
				var current:=int(GameState.talents.get(id,0))
				if current<least and current<3:chosen=id;least=current
		if chosen==&"" or not GameState.spend_talent_point(chosen):break
	# Departure skills are fixed during a run; GM cannot bypass paid respec.
	if not CampSession.active:return
	var preferences:Array=[]
	match Characters.current_id():
		&"xixifu":preferences=[&"shadow_companions",&"ghost_lantern",&"night_shelter" if main.player.hp>main.player.max_hp*.75 else &"homeward_light",&"homeward_light",&"gatekeeper",&"shadow_step"]
		&"sylphiette":preferences=[&"flame_nova",&"fan_bolts",&"blink",&"frost_nova",&"flame_shield",&"healing_light"]
		&"ilyua":preferences=[&"ilyua_wind_arrow",&"ilyua_thorn_seed",&"ilyua_forest_step",&"ilyua_moon_arrows",&"ilyua_hunter_mark",&"ilyua_vine_trap"]
	var selected:Array[StringName]=[]
	for id:StringName in preferences:
		if GameState.unlocked_skills.has(id) and not selected.has(id):selected.append(id)
		if selected.size()==3:break
	for slot in selected.size():
		if GameState.skill_for_slot(slot)!=selected[slot]:GameState.equip_skill(selected[slot],slot)
	var ultimate:StringName=&"spirit_parade" if Characters.current_id()==&"xixifu" else &"meteor" if Characters.current_id()==&"sylphiette" else &"ilyua_thousand_winds"
	if GameState.unlocked_skills.has(ultimate) and GameState.ultimate_skill!=ultimate:GameState.equip_skill(ultimate,3)
func _equip_upgrades()->void:
	for slot in ItemDB.SLOTS:
		var best:Dictionary=GameState.equipped(slot);var score:=_equipment_score(best) if not best.is_empty() else 0.0
		var seen:Dictionary={}
		for item in GameState.items:
			if ItemDB.slot_of(item)!=slot or not ItemDB.can_equip(item):continue
			var id:=str(item.get("id",""))
			if seen.has(id):continue
			seen[id]=true
			var value:=_equipment_score(item)
			if value>score+.1:best=item;score=value
		if not best.is_empty() and not GameState.is_equipped(best):GameState.equip(best)

func _exit_tree()->void:_clear_controls()
