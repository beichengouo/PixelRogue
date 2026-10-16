class_name AffixRuntime
extends Node2D

## Room-only affix clocks. The enemy owns this node; death effects own themselves.
const PERIODS := {
	EnemyAffixes.MEND_CHANT:7.0, EnemyAffixes.HUNTER_LOCK:6.0,
	EnemyAffixes.SHOCK_RING:7.0, EnemyAffixes.VINE_SNARE:7.0,
	EnemyAffixes.GUARDIAN:4.0,
}
const WARNINGS := {
	EnemyAffixes.MEND_CHANT:1.2, EnemyAffixes.HUNTER_LOCK:0.8,
	EnemyAffixes.SHOCK_RING:0.9, EnemyAffixes.VINE_SNARE:0.8,
	EnemyAffixes.GUARDIAN:1.0, EnemyAffixes.ENRAGE:0.6,
}
var enemy:RoomEnemy
var clocks:Dictionary={}
var active_id:StringName=&""
var stage_left:=0.0
var locked_target:=Vector2.ZERO
var locked_origin:=Vector2.ZERO
var locked_aim:=Vector2.RIGHT
var front_open:=0.0
var echo_left:=0.0
var echo_cd:=0.0
var echo_origin:=Vector2.ZERO
var echo_aim:=Vector2.RIGHT
var echo_kind:StringName=&""
var trail_left:=0.0
var trail_anchor:=Vector2.ZERO
var enraged_left:=0.0
var fatigue_left:=0.0
var enrage_used:=false
var guardian_used:=false
var shield_left:=0.0
var banner_visual_left := 0.0
var mirror_hits:=0
var mirror_cd:=0.0

func _ready()->void:
	z_index=800;z_as_relative=false
	for id in PERIODS:
		if enemy.has_affix(id):clocks[str(id)]=float(PERIODS[id])*0.55
	trail_anchor=enemy.global_position
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink

func _physics_process(dt:float)->void:
	if not is_instance_valid(enemy) or enemy._dead:return
	mirror_cd=maxf(0,mirror_cd-dt)
	if enemy.has_affix(EnemyAffixes.WAR_BANNER):
		banner_visual_left=maxf(0,banner_visual_left-dt)
		if banner_visual_left<=0:
			banner_visual_left=2.0;HostileAttackFX.pulse(enemy._fx(),enemy.global_position,"affix","support",54,.55,0,enemy.room)
	front_open=maxf(0,front_open-dt)
	if shield_left>0:
		shield_left=maxf(0,shield_left-dt)
		if shield_left<=0:enemy.affix_shield=0;enemy.queue_redraw()
	if enraged_left>0:
		enraged_left=maxf(0,enraged_left-dt)
		if enraged_left<=0:
			enemy.move_speed/=1.2;enemy.set_meta("affix_enraged",false);fatigue_left=1.0
	if fatigue_left>0:fatigue_left=maxf(0,fatigue_left-dt)
	if echo_left>0:
		echo_left-=dt
		if echo_left<=0:_release_echo()
		else:queue_redraw()
	echo_cd=maxf(0,echo_cd-dt)
	if enemy.has_affix(EnemyAffixes.FIRE_TRAIL):_update_trail(dt)
	if active_id!=&"":
		stage_left-=dt
		if stage_left<=0:_finish_warning()
		queue_redraw()
		return
	for id in clocks.keys():clocks[id]=maxf(0,float(clocks[id])-dt)
	if echo_left>0:return
	if enemy.has_affix(EnemyAffixes.ENRAGE) and not enrage_used and enemy.hp>0 and enemy.hp<enemy.max_hp*0.4:
		if _start_warning(EnemyAffixes.ENRAGE):return
	if enemy._windup>0 or enemy._rush>0 or fatigue_left>0 or echo_left>0:return
	for id in [EnemyAffixes.MEND_CHANT,EnemyAffixes.HUNTER_LOCK,EnemyAffixes.SHOCK_RING,EnemyAffixes.VINE_SNARE,EnemyAffixes.GUARDIAN]:
		if not enemy.has_affix(id) or float(clocks.get(str(id),INF))>0:continue
		if id==EnemyAffixes.GUARDIAN and guardian_used:continue
		if id==EnemyAffixes.MEND_CHANT and _mend_target()==null:continue
		if id==EnemyAffixes.HUNTER_LOCK and enemy.attack_target()==null:continue
		if _start_warning(id):break

func _start_warning(id:StringName)->bool:
	if get_tree().get_nodes_in_group("new_affix_warning").size()>=2:return false
	active_id=id;stage_left=float(WARNINGS[id]);locked_origin=enemy.global_position
	var target:=enemy.attack_target()
	locked_target=target.global_position if is_instance_valid(target) else enemy.global_position+Vector2(enemy._facing,0)*100
	locked_aim=(locked_target-locked_origin).normalized()
	if locked_aim.is_zero_approx():locked_aim=Vector2.RIGHT
	add_to_group("new_affix_warning")
	if id==EnemyAffixes.GUARDIAN:guardian_used=true
	if id==EnemyAffixes.ENRAGE:enrage_used=true
	if id==EnemyAffixes.ENRAGE:HostileAttackFX.pulse(enemy._fx(),enemy.global_position,"affix","rage",58,float(WARNINGS[id]),0,enemy.room)
	elif id in [EnemyAffixes.GUARDIAN,EnemyAffixes.MEND_CHANT]:HostileAttackFX.pulse(enemy._fx(),enemy.global_position,"affix","support" if id==EnemyAffixes.GUARDIAN else "regen",54,float(WARNINGS[id]),0,enemy.room)
	queue_redraw()
	return true

func _finish_warning()->void:
	var id:=active_id
	active_id=&"";stage_left=0;remove_from_group("new_affix_warning")
	if enemy._dead:return
	match id:
		EnemyAffixes.MEND_CHANT:
			var target:=_mend_target()
			if target!=null:
				target.hp=minf(target.max_hp,target.hp+target.max_hp*0.08)
				target.queue_redraw()
				Effects.cast_ring(enemy._fx(),target.global_position,Color("a8edc0"),30,0.3)
		EnemyAffixes.HUNTER_LOCK:_fire_hunter()
		EnemyAffixes.SHOCK_RING:_spawn_hazard(&"ring",enemy.global_position,locked_aim,enemy.damage*0.8)
		EnemyAffixes.VINE_SNARE:_spawn_hazard(&"line",enemy.global_position,locked_aim,enemy.damage*0.6)
		EnemyAffixes.GUARDIAN:
			if is_instance_valid(enemy.director) and enemy.director.has_method("spawn_guardian_children"):enemy.director.spawn_guardian_children(enemy)
		EnemyAffixes.ENRAGE:
			enraged_left=4.0;enemy.move_speed*=1.2;enemy.set_meta("affix_enraged",true)
	if PERIODS.has(id):clocks[str(id)]=float(PERIODS[id])
	queue_redraw()

func interrupt(direct_skill:bool,pushed:bool)->void:
	if active_id not in [EnemyAffixes.MEND_CHANT,EnemyAffixes.GUARDIAN]:return
	if not direct_skill and not pushed:return
	var id:=active_id
	active_id=&"";stage_left=0;remove_from_group("new_affix_warning")
	if id==EnemyAffixes.GUARDIAN:guardian_used=false
	clocks[str(id)]=float(PERIODS[id])
	queue_redraw()

func blocks_action()->bool:return active_id!=&"" or fatigue_left>0

func on_attack_released(kind:StringName,origin:Vector2,aim:Vector2)->void:
	if enemy.has_affix(EnemyAffixes.FRONT_GUARD):front_open=0.8
	if enemy.has_affix(EnemyAffixes.ECHO_STRIKE) and echo_left<=0 and echo_cd<=0 and get_tree().get_nodes_in_group("new_affix_warning").size()<2:
		echo_left=0.9;echo_cd=6.0;echo_origin=origin;echo_aim=aim;echo_kind=kind
		add_to_group("new_affix_warning");queue_redraw()

func frontal_multiplier(from:Vector2,source:Node)->float:
	if not enemy.has_affix(EnemyAffixes.FRONT_GUARD) or front_open>0:return 1.0
	if enemy._windup>0 or enemy._classify_damage(source) not in [&"basic",&"skill",&"ally"] or from==Vector2.ZERO:return 1.0
	var incoming:Vector2=(from-enemy.global_position).normalized()
	var facing:=enemy._art_direction.normalized() if enemy._art_direction.length_squared()>.01 else Vector2(enemy._facing,0)
	return 0.6 if facing.dot(incoming)>=0.5 else 1.0

func on_other_enemy_died(other:EnemyBase)->void:
	if not enemy.has_affix(EnemyAffixes.DEVOUR) or enemy._dead or other==enemy:return
	if other is RoomBoss or other.loot_origin!="normal" or other._dead==false:return
	if enemy.global_position.distance_to(other.global_position)>144:return
	enemy.affix_shield=minf(enemy.max_hp*0.15,enemy.affix_shield+enemy.max_hp*0.05)
	shield_left=5.0;enemy.queue_redraw()
	HostileAttackFX.pulse(enemy._fx(),enemy.global_position,"affix","armor",48,.35,0,enemy.room)
	Effects.cast_ring(enemy._fx(),enemy.global_position,Color("98b4fa"),25,0.25)

func on_death()->void:
	remove_from_group("new_affix_warning")
	if enemy.has_affix(EnemyAffixes.EMBER_GRAVE):
		_spawn_hazard(&"grave",enemy.global_position,Vector2.RIGHT,enemy.damage*0.15)
	if enraged_left>0:enemy.move_speed/=1.2

func _mend_target()->RoomEnemy:
	var best:RoomEnemy
	var missing:=0.0
	if not is_instance_valid(enemy.director):return null
	for node in enemy.director.enemies_root.get_children():
		var other:=node as RoomEnemy
		if other==null or other==enemy or other._dead or other.loot_origin!="normal":continue
		if other.global_position.distance_to(enemy.global_position)>144:continue
		var ratio:float=(other.max_hp-other.hp)/maxf(other.max_hp,1)
		if ratio>missing:missing=ratio;best=other
	return best

func _fire_hunter()->void:
	if not EnemyCombatPolicy.ranged_affix_allowed(enemy.kind):return
	if not enemy.room.projectile_clear(locked_origin,locked_target):return
	for spread in [-0.10,0.0,0.10]:
		var dir:=locked_aim.rotated(spread)
		var bullet:=RoomProjectile.new();bullet.room=enemy.room;bullet.is_friendly=false;bullet.art_scale=0.48;bullet.range_limit=360
		bullet.hostile_effects=PlayerDebuffs.effects_for(enemy).duplicate(true)
		if enemy.kind in EnemyCombatPolicy.EXPANSION_KINDS:bullet.hostile_fx=str(enemy.kind)
		bullet.damage_owner=&"enemy"
		bullet.cruel_damage=enemy.has_affix(EnemyAffixes.CRUEL)
		enemy._fx().add_child(bullet)
		bullet.setup(enemy.global_position+dir*18,dir,enemy.damage*0.45,330,enemy.room,enemy.player,Color("ff8175"))

func _release_echo()->void:
	echo_left=0
	remove_from_group("new_affix_warning")
	if not is_instance_valid(enemy) or enemy._dead:return
	Effects.slash_arc(enemy._fx(),echo_origin,echo_aim.angle(),75,Color("eaa0ff"),100,3,0.25)
	if EnemyCombatPolicy.ranged_affix_allowed(echo_kind) or enemy.has_affix(EnemyAffixes.RANGED):
		if not enemy.room.bounds().grow(-8).has_point(echo_origin):return
		var bullet:=RoomProjectile.new();bullet.room=enemy.room;bullet.is_friendly=false;bullet.art_scale=0.52;bullet.range_limit=360
		bullet.hostile_effects=PlayerDebuffs.effects_for(enemy).duplicate(true)
		if enemy.kind in EnemyCombatPolicy.EXPANSION_KINDS:bullet.hostile_fx=str(enemy.kind)
		bullet.damage_owner=&"enemy";enemy._fx().add_child(bullet)
		bullet.cruel_damage=enemy.has_affix(EnemyAffixes.CRUEL)
		bullet.setup(echo_origin+echo_aim*18,echo_aim,enemy.damage*0.5,240,enemy.room,enemy.player,Color("eaa0ff"))
		return
	for body in _targets():
		var offset:=body.global_position-echo_origin
		if offset.length()>(100 if echo_kind==&"bomber" else 80) or offset.length()<1:continue
		if echo_kind!=&"bomber" and echo_aim.dot(offset.normalized())<0.65:continue
		if not enemy.room.projectile_clear(echo_origin,body.global_position):continue
		body.take_damage(enemy.damage*0.5,echo_origin,enemy)

func _update_trail(dt:float)->void:
	trail_left=maxf(0,trail_left-dt)
	if enemy.global_position.distance_to(trail_anchor)<16 or trail_left>0:return
	trail_anchor=enemy.global_position;trail_left=0.14
	if enemy.room.body_clear(enemy.global_position,6,enemy.is_flying()):
		_spawn_hazard(&"trail",enemy.global_position,Vector2.RIGHT,enemy.damage*0.12)

func _spawn_hazard(mode:StringName,at:Vector2,aim:Vector2,amount:float)->void:
	if not enemy.room.bounds().grow(-8).has_point(at):return
	AffixHazard.create(enemy._fx(),enemy.room,mode,at,aim,amount,enemy)

func _targets()->Array[Node2D]:
	var out:Array[Node2D]=[]
	if is_instance_valid(enemy.player) and float(enemy.player.get("hp"))>0:out.append(enemy.player)
	for node in get_tree().get_nodes_in_group("allies"):
		if node is Node2D and is_instance_valid(node) and float(node.get("hp"))>0 and node.get("room")==enemy.room:out.append(node)
	return out

func _draw()->void:
	if echo_left>0:
		var offset:Vector2=echo_origin-global_position
		for i in 25:
			var p:Vector2=echo_aim*float(i)*4
			var world:=echo_origin+p
			if enemy.room.bounds().grow(-4).has_point(world) and enemy.room.projectile_clear(echo_origin,world):
				draw_rect(Rect2((offset+p).round(),Vector2(2,2)),Color("eaa0ff",0.72))
	if active_id==&"":return
	var color:=Color("ffbe70")
	if active_id==EnemyAffixes.MEND_CHANT:color=Color("a8edc0")
	if active_id==EnemyAffixes.VINE_SNARE:color=Color("b1e686")
	if active_id==EnemyAffixes.HUNTER_LOCK:color=Color("ff7d7d")
	var progress:=1.0-stage_left/float(WARNINGS[active_id])
	draw_rect(Rect2(Vector2(-18,-enemy.body_size.y*.5-24),Vector2(36,5)),Color("261b24"))
	draw_rect(Rect2(Vector2(-17,-enemy.body_size.y*.5-23),Vector2(34*progress,3)),color)
	if active_id==EnemyAffixes.SHOCK_RING:
		for radius in [72.0,144.0]:
			for i in 64:
				var p:Vector2=Vector2.from_angle(TAU*i/64)*radius
				if _visual_point(p):draw_rect(Rect2(p.round(),Vector2(3,3)),Color(color,0.65))
	elif active_id==EnemyAffixes.VINE_SNARE:
		for i in 19:
			for side in [-18.0,18.0]:
				var p:Vector2=locked_aim*float(i)*10+locked_aim.orthogonal()*side
				if _visual_point(p):draw_rect(Rect2(p.round(),Vector2(3,3)),Color(color,0.65))
	elif active_id==EnemyAffixes.HUNTER_LOCK:
		for i in 25:
			var p:Vector2=locked_aim*float(i)*12
			if _visual_point(p):draw_rect(Rect2(p.round(),Vector2(2,2)),Color(color,0.75))
	else:
		for i in 32:
			var p:Vector2=Vector2.from_angle(TAU*i/32.0)*36
			if _visual_point(p):draw_rect(Rect2(p.round(),Vector2(3,3)),Color(color,0.7))

func _visual_point(local_point:Vector2)->bool:
	var at:=global_position+local_point
	return enemy.room.bounds().grow(-4).has_point(at) and enemy.room.projectile_clear(global_position,at)

func snapshot()->Dictionary:
	return {"mirror_hits":mirror_hits,"mirror_cd":mirror_cd,"clocks":clocks.duplicate(true),"active":str(active_id),"stage":stage_left,
		"target":[locked_target.x,locked_target.y],"origin":[locked_origin.x,locked_origin.y],"aim":[locked_aim.x,locked_aim.y],
		"front":front_open,"echo":echo_left,"echo_cd":echo_cd,"echo_origin":[echo_origin.x,echo_origin.y],"echo_aim":[echo_aim.x,echo_aim.y],"echo_kind":str(echo_kind),
		"trail":trail_left,"trail_anchor":[trail_anchor.x,trail_anchor.y],"rage":enraged_left,"fatigue":fatigue_left,
		"rage_used":enrage_used,"guardian_used":guardian_used,"shield":enemy.affix_shield,"shield_left":shield_left}

func restore(data:Dictionary)->void:
	mirror_hits=clampi(int(data.get("mirror_hits",0)),0,3);mirror_cd=maxf(0,float(data.get("mirror_cd",0)))
	clocks=data.get("clocks",{}).duplicate(true)
	active_id=StringName(data.get("active",""));stage_left=float(data.get("stage",0))
	locked_target=_vec(data.get("target",[0,0]));locked_origin=_vec(data.get("origin",[0,0]));locked_aim=_vec(data.get("aim",[1,0]))
	front_open=float(data.get("front",0));echo_left=float(data.get("echo",0));echo_cd=float(data.get("echo_cd",0));echo_origin=_vec(data.get("echo_origin",[0,0]));echo_aim=_vec(data.get("echo_aim",[1,0]));echo_kind=StringName(data.get("echo_kind",""))
	trail_left=float(data.get("trail",0));trail_anchor=_vec(data.get("trail_anchor",[0,0]))
	enraged_left=float(data.get("rage",0));fatigue_left=float(data.get("fatigue",0));enrage_used=bool(data.get("rage_used",false));guardian_used=bool(data.get("guardian_used",false))
	enemy.affix_shield=float(data.get("shield",0));shield_left=float(data.get("shield_left",0))
	if active_id!=&"" or echo_left>0:add_to_group("new_affix_warning")
	if enraged_left>0:enemy.set_meta("affix_enraged",true)
	queue_redraw()

static func _vec(value:Array)->Vector2:return Vector2(float(value[0]),float(value[1]))

func on_direct_damage()->void:
	if not enemy.has_affix(EnemyAffixes.MIRROR_SHELL) or enemy._dead:return
	mirror_hits=mini(3,mirror_hits+1)
	if mirror_hits<3 or mirror_cd>0:return
	mirror_hits=0;mirror_cd=6;enemy.affix_shield=maxf(enemy.affix_shield,enemy.max_hp*.1);shield_left=3
	HolyFX.spawn(enemy._fx(),enemy.global_position,"cloud",28,.3);enemy.queue_redraw()
