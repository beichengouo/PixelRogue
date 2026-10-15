class_name RoomBoss
extends BossActor
## Serializable arena timelines; never mutate terrain or apply tide forces.
var room:RoomLevel
var owner_tag:=""
var room_windup:=0.0
var room_aim:=Vector2.RIGHT
var room_target:=Vector2.ZERO
var room_move:=Vector2.ZERO
var room_nav_cd:=0.0
var room_action:=0
var room_cooldown:=1.5
var room_summon_cd:=7.0
var room_warning:BossWarning
var pattern:=""
var recovery:=0.0
var vulnerability:=0.0
var wave_serial:=0
var active_wave:=0
var active_wave_kind:=""
var wave_broken:=false
var wave_required:=0
var wave_defeated:=0
var phase_seen:=1
var command_serial:=0
var timeline:Array[Dictionary]=[]
var _live_warnings:Dictionary={}
const KING_PATTERNS:=["枯冠剑舞","断骨飞矛","崩坏骨刺","亡骸征召","崩坏王令","枯骨环葬","骸王葬礼"]
const MAGE_PATTERNS:=["晶刺突生","棱镜折光","碎晶星雨","浮晶环阵","晶镜幻身","晶牢封界","终焉晶爆"]
const TIDE_PATTERNS:=["深根突袭","腐海孢雨","寄生根群","沧澜横潮","深渊涡眼","逆潮回响","根海绞杀","深海花葬","终潮·深渊归寂"]
func _ready()->void:
	add_to_group("bosses");uses_gravity=false;collides_with_world=true;max_phase=int(roster.get("phases",3 if boss_id==&"tide" else 2))
	if owner_tag.is_empty():owner_tag="%s:%s"%[boss_id,str(room.record.get("seed",0))]
	super._ready();motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	var radius:=24.0 if boss_id==&"tide" else 20.0
	for child in get_children():
		if child is CollisionShape2D:
			var shape:=CircleShape2D.new();shape.radius=radius;child.shape=shape
	room.register_unit_body(self,radius);(contact_area.get_child(0).shape as CircleShape2D).radius=radius+6
func _physics_process(dt:float)->void:
	if _dead or not is_instance_valid(player):return
	advance_slow(dt);_flash=maxf(0,_flash-dt);_contact_cd=maxf(0,_contact_cd-dt);_visual_release_left=maxf(0,_visual_release_left-dt)
	if _burn_time>0:
		_burn_time=maxf(0,_burn_time-dt);_burn_tick+=dt
		if _burn_tick>=.5:
			_burn_tick-=.5;take_damage(_burn_dps*.5,false,global_position,_burn_source.get_ref() if _burn_source!=null else null,false)
			if _dead:return
	phase=phase_for_health()
	if phase!=phase_seen:
		phase_seen=phase;cancel_attacks(true);recovery=1.5;room_cooldown=1.5
		Effects.text(_fx(),global_position-Vector2(0,65),"崩坏加深 · 第%d阶段"%phase,body_color,20)
	think(dt)
	if _slow_time>0:velocity*=1-_slow_strength
	move_and_slide();_check_contact();_update_visual();queue_redraw()
func phase_for_health()->int:return mini(max_phase,1+int((1-hp/max_hp)*max_phase))
func think(dt:float)->void:
	vulnerability=maxf(0,vulnerability-dt);recovery=maxf(0,recovery-dt);_check_wave_counter();_advance_commands(dt)
	if recovery>0 or main_pending():velocity=Vector2.ZERO;return
	attack_id=&"";room_windup=0;room_nav_cd-=dt
	if room_nav_cd<=0:
		room_nav_cd=.3;var target:=player.global_position
		if boss_id==&"mage" and target.distance_to(global_position)<160:target=room.nearest_clear(global_position+(global_position-target).normalized()*100,24)
		room_move=room.path_direction(global_position,target,26)
	velocity=room_move*move_speed*(.45 if boss_id==&"mage" else .65);_facing=1 if player.global_position.x>global_position.x else -1
	room_cooldown-=dt
	if room_cooldown>0:return
	room_aim=(player.global_position-global_position).normalized();room_target=player.global_position
	var choices:Array=_available_patterns()
	pattern=str(choices[room_action%choices.size()]);room_action+=1;attack_id=&"windup"
	Effects.text(_fx(),global_position-Vector2(0,72),pattern,body_color.lightened(.2),18);_boss_fx("cast",global_position,88,.8)
	match boss_id:
		&"king":_king_pattern(pattern)
		&"mage":_mage_pattern(pattern)
		&"tide":_tide_pattern(pattern)
	room_cooldown=attack_cd(2.8 if phase==1 else 2.2)
func _available_patterns()->Array:
	if boss_id==&"king":return ["断骨飞矛","枯冠剑舞","崩坏骨刺","亡骸征召","断骨飞矛","枯冠剑舞","枯骨环葬"] if phase==1 else KING_PATTERNS
	if boss_id==&"mage":return MAGE_PATTERNS.slice(0,6) if phase==1 else MAGE_PATTERNS
	return TIDE_PATTERNS.slice(0,3 if phase==1 else 6 if phase==2 else 9)
func _command(kind:String,delay:float,data:Dictionary={})->void:
	command_serial+=1;var event:=data.duplicate(true);event.type=kind;event.left=delay;event.key=command_serial
	if not event.has("at"):event.at=global_position
	if not event.has("dir"):event.dir=room_aim
	if not event.has("warning"):event.warning=minf(.85,delay)
	timeline.append(event);room_windup=maxf(room_windup,minf(delay,float(event.warning)))
func _advance_commands(dt:float)->void:
	room_windup=maxf(0,room_windup-dt)
	for event in timeline.duplicate():
		event.left=float(event.left)-dt
		if event.get("wave_sensitive",false) and wave_broken:_erase_warning(event);timeline.erase(event);continue
		if event.left<=float(event.warning) and event.left>0 and event.has("shape") and not _live_warnings.has(event.key):
			var warning:=BossPatternWarning.create(_fx(),room,event,float(event.left),body_color.lightened(.15));warning.set_meta("boss_owner",get_instance_id());_live_warnings[event.key]=warning
		if event.left>0:continue
		_erase_warning(event);timeline.erase(event);_execute(event)
	if not main_pending() and attack_id!=&"":attack_id=&"";begin_visual_release(.55);recovery=maxf(recovery,1.3 if boss_id==&"king" else 1.0)
func _erase_warning(event:Dictionary)->void:
	var warning:Node=_live_warnings.get(event.key)
	if is_instance_valid(warning):warning.queue_free()
	_live_warnings.erase(event.key)
func _execute(event:Dictionary)->void:
	var at:Vector2=event.at;var direction:Vector2=event.dir;
	if not bool(event.get("auxiliary",false)):begin_visual_release(.45)
	match str(event.type):
		"fan":_fan(at,direction,int(event.get("count",5)),float(event.get("spread",1)),float(event.get("speed",220)),float(event.get("ratio",.8)),event)
		"ring":_ring(at,int(event.get("count",18)),float(event.get("speed",170)),float(event.get("ratio",.6)),event.get("gap",direction),float(event.get("opening",1.05)))
		"circle","line","slash":
			if event.has("prism_at") and not _constructs().any(func(c:BossConstruct)->bool:return c.construct_kind=="prism" and c.global_position.distance_to(event.prism_at)<24):return
			_strike(event)
		"spear":_bullet(at,direction,float(event.get("speed",270)),float(event.get("ratio",.9)),event)
		"summon":_summon_wave(int(event.get("count",3)))
		"command":_royal_command()
		"construct":_spawn_construct(str(event.get("kind","crystal")),at,float(event.get("life",10)),bool(event.get("orbit",false)))
		"core_shot":
			var construct:=_find_construct(int(event.get("construct",0)))
			if is_instance_valid(construct):_fan(construct.global_position,direction,int(event.get("count",3)),.6,170,.4,{})
		"resonance":_begin_resonance(str(event.get("kind","core")),int(event.get("count",4)))
		"tracking_crack":_crack(.85,player.global_position-room_aim*90,room_aim,180,phase>=2)
		"counter":recovery=maxf(recovery,2.5 if wave_broken else 1.8)
func _strike(event:Dictionary)->void:
	var at:Vector2=event.at;var direction:Vector2=event.dir;var shape:=str(event.get("shape","circle"));var radius:=float(event.get("radius",60))
	if shape=="line":
		var end:Vector2=event.end
		var stage:="slash" if PixelBossArt.city_boss(boss_id) else "area"
		var beam:=_boss_fx(stage,(at+end)*.5,96,.65,(end-at).angle())
		if beam!=null:
			beam.sprite.scale=Vector2(end.distance_to(at),float(event.get("width",18))*2)/HostileAttackFX.cell_size(str(boss_id),stage)
	else:_boss_fx("slash" if shape=="fan" else "area",at,radius*2,.65,direction.angle())
	for victim in [player]+get_tree().get_nodes_in_group("allies"):
		if not is_instance_valid(victim) or victim.hp<=0 or victim.is_queued_for_deletion():continue
		var delta:Vector2=victim.global_position-at;var hit:=delta.length()<=radius
		if shape=="fan":hit=hit and (delta.length()<10 or absf(direction.angle_to(delta))<=float(event.get("spread",1))*.5)
		elif shape=="line":
			var end:Vector2=event.end-at;var along:=delta.dot(end.normalized());hit=along>=0 and along<=end.length() and absf(delta.cross(end.normalized()))<=float(event.get("width",18))
		if hit and room.bounds().has_point(victim.global_position) and room.sight(at,victim.global_position):victim.take_damage(attack_damage()*float(event.get("ratio",.9)),at,self)
func _fan(at:Vector2,direction:Vector2,count:int,spread:float,speed_value:float,ratio:float,data:Dictionary)->void:
	for index in count:_bullet(at,direction.rotated((float(index)/maxi(1,count-1)-.5)*spread),speed_value,ratio,data)
func _ring(at:Vector2,count:int,speed_value:float,ratio:float,gap:Vector2,opening:float)->void:
	_boss_fx("radial",at,144,.65)
	for index in count:
		var direction:=Vector2.from_angle(index*TAU/count)
		if absf(direction.angle_to(gap))>=opening*.5:_bullet(at,direction,speed_value,ratio,{})
func _bullet(at:Vector2,direction:Vector2,speed_value:float,ratio:float,data:Dictionary)->void:
	# Freed Objects cannot enter a typed lambda; remove in place so the typed
	# ownership array also keeps its Array[Projectile] identity.
	for index in range(_owned_bullets.size()-1,-1,-1):
		if not is_instance_valid(_owned_bullets[index]) or _owned_bullets[index].is_queued_for_deletion():_owned_bullets.remove_at(index)
	if _owned_bullets.size()>=96:return
	var bullet:=BossPatternProjectile.new();bullet.room=room;bullet.is_friendly=false;bullet.damage_owner=&"enemy";bullet.hostile_fx=str(boss_id);bullet.hostile_width=32;bullet.range_limit=1400
	bullet.cruel_damage=has_affix(EnemyAffixes.CRUEL)
	bullet.pattern_family=str(boss_id);bullet.split_count=int(data.get("split",0));bullet.split_after=float(data.get("split_after",1.2));bullet.bounces=int(data.get("bounce",0));bullet.returning=bool(data.get("return",false));bullet.return_after=float(data.get("return_after",1.3));bullet.boss_tag=owner_tag
	_fx().add_child(bullet);bullet.setup(at+direction*22,direction,attack_damage()*ratio,speed_value,room,player,body_color);bullet.set_meta("boss_owner",get_instance_id());_owned_bullets.append(bullet)
func _legal(at:Vector2,radius:=16.0)->Vector2:return room.nearest_clear(at,radius)
func _line(delay:float,at:Vector2,end:Vector2,width:=18.0,ratio:=.8)->void:
	_command("line",delay,{"at":at,"end":end,"dir":(end-at).normalized(),"shape":"line","width":width,"ratio":ratio})
func _crack(delay:float,at:Vector2,aim:Vector2,length:=216.0,branches:=false)->void:
	for index in 5:
		var point:=at+aim*(index+1)*length/5
		if room.bounds().grow(-18).has_point(point):_command("circle",delay+index*.14,{"at":point,"radius":25,"shape":"circle","ratio":.85})
	if branches:_line(delay+.7,at+aim*length*.5,at+aim*length*.5+aim.rotated(.8)*100,14,.55)
func _king_pattern(name:String)->void:
	match name:
		"枯冠剑舞":
			for index in 2:_command("slash",.85+index*.7,{"shape":"fan","radius":126,"spread":1.5,"dir":room_aim.rotated(.2 if index==0 else -.2),"ratio":.9})
			_command("fan",2.35,{"shape":"fan","radius":250,"count":7 if phase==2 else 5,"spread":1.15,"ratio":.65})
		"断骨飞矛":
			for index in (3 if phase==2 else 2):_command("spear",.85+index*.6,{"shape":"line","end":global_position+room_aim*360,"width":10,"split":3,"split_after":1.0,"ratio":1.0})
		"崩坏骨刺":_crack(.9,global_position,room_aim,240,phase==2)
		"亡骸征召":_command("summon",1.15,{"count":4 if phase==2 else 3,"shape":"circle","radius":55})
		"崩坏王令":_command("command",.9,{"shape":"circle","radius":70})
		"枯骨环葬":
			for index in (2 if phase==2 else 1):_command("ring",1+index*.9,{"shape":"ring","radius":120,"gap":room_aim.rotated(index*.6),"opening":1.2,"count":20,"speed":160,"ratio":.7})
		"骸王葬礼":
			_command("summon",.9,{"count":4});_command("fan",3.2,{"shape":"fan","radius":330,"warning":1.4,"spread":1.6,"count":11,"ratio":.9});_command("counter",3.5)
func _mage_pattern(name:String)->void:
	match name:
		"晶刺突生":
			_crack(.9,global_position,room_aim,252,phase==2)
			for index in 2:_command("construct",1.8+index*.2,{"at":_legal(global_position+room_aim.rotated(.7 if index==0 else -.7)*140),"kind":"crystal"})
		"棱镜折光":
			var pivot:=_legal(global_position+room_aim*130);_command("construct",.4,{"at":pivot,"kind":"prism"});_line(1.65,global_position,pivot,13,1.0)
			for side in [-1,1]:
				var direction:=room_aim.rotated(side*.65);_command("line",1.65,{"at":pivot,"end":pivot+direction*240,"dir":direction,"shape":"line","width":13,"ratio":1.0,"prism_at":pivot})
		"碎晶星雨":_command("fan",1,{"shape":"fan","radius":270,"count":3 if phase==1 else 4,"spread":1.2,"speed":130,"ratio":.7,"split":5,"split_after":1.35,"bounce":1 if phase==2 else 0})
		"浮晶环阵":
			for index in 4:_command("construct",.8+index*.35,{"at":global_position+Vector2.from_angle(index*TAU/4)*92,"kind":"orbit","orbit":true,"life":10})
			for index in 3:_command("fan",2+index*.7,{"count":3,"spread":.6,"speed":180,"ratio":.55})
		"晶镜幻身":_begin_resonance("clone",3);_command("fan",1.4,{"count":4,"spread":.8,"speed":170,"ratio":.55})
		"晶牢封界":
			for index in 3:
				var at:=_legal(room_target+Vector2.from_angle(room_aim.angle()+index*.65-.65)*132)
				_command("construct",1.0+index*.2,{"at":at,"kind":"prison","life":4,"shape":"circle","radius":20})
		"终焉晶爆":
			_command("resonance",.7,{"count":4,"kind":"energy"})
			for index in 3:_command("ring",1.8+index*.9,{"count":20,"gap":room_aim,"opening":1.35,"ratio":.45,"speed":140,"wave_sensitive":true})
			_command("ring",4.8,{"shape":"ring","radius":180,"warning":1.4,"count":28,"opening":1.45,"gap":room_aim,"speed":195,"ratio":1.0,"wave_sensitive":true});_command("counter",5.1)
func _tide_pattern(name:String)->void:
	match name:
		"深根突袭":_command("tracking_crack",.4)
		"腐海孢雨":
			for index in 3:
				var at:=_legal(room_target+Vector2.from_angle(index*TAU/3)*100)
				_command("circle",1.0+index*.55,{"at":at,"shape":"circle","radius":28,"ratio":.65});_command("ring",1.4+index*.55,{"at":at,"count":10,"gap":(room_target-at).normalized(),"opening":1.3,"ratio":.4,"speed":125})
		"寄生根群":_command("resonance",1,{"count":3,"kind":"bud"})
		"沧澜横潮":
			var bounds:=room.bounds().grow(-30);var dir:=Vector2.RIGHT if room_action%2==0 else Vector2.LEFT;var x:=bounds.position.x if dir.x>0 else bounds.end.x;var safe_y:=clampf(room_target.y,bounds.position.y+54,bounds.end.y-54)
			for y in range(int(bounds.position.y),int(bounds.end.y),32):
				if absf(y-safe_y)<56:continue
				_command("spear",1.25,{"at":Vector2(x,y),"dir":dir,"shape":"line","end":Vector2(bounds.end.x if dir.x>0 else bounds.position.x,y),"width":9,"speed":150,"ratio":.75})
		"深渊涡眼":
			var at:=_legal(room_target+room_aim.orthogonal()*100)
			for index in 7:_command("fan",1+index*.32,{"at":at,"dir":Vector2.from_angle(index*.65),"count":3,"spread":.55,"speed":145,"ratio":.5})
			_command("ring",3.65,{"at":at,"count":16,"gap":room_aim,"opening":1.4,"speed":130,"ratio":.5})
		"逆潮回响":_command("fan",1,{"shape":"fan","radius":280,"count":7,"spread":1.4,"speed":155,"ratio":.65,"return":true,"return_after":1.6})
		"根海绞杀":
			var bounds:=room.bounds().grow(-24)
			for index in 3:
				var y:=bounds.position.y+(index+1)*bounds.size.y/4;_line(1+index*.85,Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),18,.9)
			_command("resonance",3.8,{"kind":"core","count":3})
		"深海花葬":
			_command("resonance",.6,{"kind":"core","count":4})
			for index in 8:_command("fan",1.2+index*.3,{"dir":room_aim.rotated(index*.45),"count":3,"spread":.6,"speed":155,"ratio":.5})
			_command("fan",4,{"shape":"fan","radius":290,"count":7,"spread":1.6,"ratio":.8})
		"终潮·深渊归寂":
			for index in 2:_command("ring",1+index*.8,{"count":22,"gap":room_aim,"opening":1.4,"speed":135,"ratio":.5})
			_command("resonance",2.8,{"kind":"core","count":4})
			for index in 3:_command("ring",4+index*.8,{"count":24,"gap":room_aim,"opening":1.5,"speed":155,"ratio":.55,"wave_sensitive":true})
			_command("fan",6.7,{"shape":"fan","radius":330,"warning":1.5,"dir":room_aim,"spread":1.8,"count":13,"speed":205,"ratio":1.0,"wave_sensitive":true});_command("counter",7)
func _summon_wave(count:int)->void:
	if not is_instance_valid(director):return
	wave_serial+=1;active_wave=wave_serial;active_wave_kind="bones";wave_broken=false;wave_required=0;wave_defeated=0
	var living:=get_tree().get_nodes_in_group("enemies").filter(func(node:Node)->bool:return node is RoomEnemy and node.boss_wave_tag.begins_with(owner_tag) and not node._dead).size()
	for index in mini(count,maxi(0,8-living-director.room_pending.size())):
		var at:=room.spawn_point(Rng.stream(),player.global_position,14)
		if at.distance_to(player.global_position)<90:continue
		wave_required+=1
		director.room_pending.append({"kind":"walker" if index<2 else "guard" if phase==2 and index==2 else "flyer","at":at,"remaining":.9,"origin":"boss_minion","boss_wave_tag":owner_tag+":"+str(active_wave)});RoomSpawnFX.spawn(_fx(),at,.9)
func _royal_command()->void:
	var found:=false
	for unit in get_tree().get_nodes_in_group("enemies"):
		if not unit is RoomEnemy or unit._dead or not unit.boss_wave_tag.begins_with(owner_tag):continue
		found=true
		if unit.royal_command_left<=0:unit.move_speed*=1.2;unit._attack_scale*=1.2
		unit.royal_command_left=5;HostileAttackFX.pulse(_fx(),unit.global_position,"king","cast",48,.75,0,room)
	if not found:_ring(global_position,14,145,.55,room_aim,1.4)
func _begin_resonance(kind_value:String,count:int)->void:
	wave_serial+=1;active_wave=wave_serial;active_wave_kind=kind_value;wave_broken=false;wave_required=0;wave_defeated=0
	for index in count:
		var angle:=room_aim.angle()+TAU*(index+.5)/count;var point:=_legal(global_position+Vector2.from_angle(angle)*150)
		if point.distance_to(player.global_position)<60:point=_legal(point+Vector2.from_angle(angle)*50)
		var construct:=_spawn_construct(kind_value,point,9.5,false)
		if construct!=null:wave_required+=1;construct.wave_tag=active_wave;construct.resonance=true;construct.shooting_left=1.0+index*.7
func _constructs()->Array:
	return get_tree().get_nodes_in_group("boss_constructs").filter(func(node:Node)->bool:return is_instance_valid(node) and not node._dead and not node.is_queued_for_deletion() and node.owner_tag==owner_tag)
func _spawn_construct(kind_value:String,at:Vector2,seconds:float,orbit:bool)->BossConstruct:
	if not room.scene_navigation.spawn_reachable(room,at,12,false):return null
	var current:=_constructs()
	if current.size()>=6:current[0].retire()
	var construct:=BossConstruct.new();construct.room=room;construct._boss=self;construct.player=player;construct.level=room;construct.fx_root=_fx();construct.owner_tag=owner_tag;construct.boss_family=str(boss_id);construct.construct_kind=kind_value;construct.lifetime=seconds;construct.shield_orbit=orbit;construct.orbit_angle=(at-global_position).angle();construct.position=at;construct.base_hp=max_hp*(.025 if kind_value=="clone" else .04);construct.base_damage=0
	director.enemies_root.add_child(construct);return construct
func _find_construct(key:int)->BossConstruct:
	for construct in _constructs():
		if construct.shot_count==key:return construct
	return null
func can_construct_fire(construct:BossConstruct)->bool:return not _dead and recovery<=0 and construct.lifetime>.9
func warn_construct_shot(construct:BossConstruct)->void:
	command_serial+=1;construct.shot_count=command_serial;var direction:Vector2=(player.global_position-construct.global_position).normalized()
	_command("core_shot",.8,{"at":construct.global_position,"dir":direction,"construct":construct.shot_count,"shape":"fan","spread":.6,"radius":220,"count":2 if construct.construct_kind=="clone" else 3,"auxiliary":true})
func construct_destroyed(construct:BossConstruct)->void:
	if construct.resonance and construct.wave_tag==active_wave:wave_defeated+=1
	if construct.construct_kind=="clone" and phase==2:prison_expired(construct)
	_check_wave_counter()
func _check_wave_counter()->void:
	if active_wave==0 or wave_broken or wave_required==0 or wave_defeated<wave_required:return
	var any_live:=false
	if active_wave_kind=="bones":
		var tag:=owner_tag+":"+str(active_wave)
		for unit in get_tree().get_nodes_in_group("enemies"):
			if unit is RoomEnemy and not unit._dead and unit.boss_wave_tag==tag:any_live=true;break
		if is_instance_valid(director) and director.room_pending.any(func(event:Dictionary)->bool:return event.get("boss_wave_tag","")==tag):any_live=true
	else:
		for construct in _constructs():
			if construct.resonance and construct.wave_tag==active_wave:any_live=true;break
	if any_live:return
	wave_broken=true;vulnerability=3;recovery=maxf(recovery,1.8);Effects.text(_fx(),global_position-Vector2(0,64),"王令破绽" if boss_id==&"king" else "断根反噬" if boss_id==&"tide" else "晶核破绽",Color("e6ffca"),20)
func take_damage(amount:float,is_crit:=false,from:=Vector2.ZERO,source:Node=null,knockback:=true)->void:super.take_damage(amount*(1.3 if vulnerability>0 else 1.0),is_crit,from,source,knockback)
func _check_contact()->void:
	if recovery>0 or main_pending():return
	super._check_contact()
func cancel_attacks(clear_bullets:=true)->void:
	room_windup=0;timeline.clear()
	for warning in _live_warnings.values():
		if is_instance_valid(warning):warning.queue_free()
	_live_warnings.clear()
	if is_inside_tree():
		for effect in get_tree().get_nodes_in_group("hostile_attack_fx"):
			if int(effect.get_meta("boss_owner",0))==get_instance_id():effect.queue_free()
	super.cancel_attacks(clear_bullets)
func restore_warning()->void:
	_live_warnings.clear()
	if timeline.is_empty():room_windup=0;attack_id=&"";room_cooldown=maxf(room_cooldown,.8);return
	_advance_commands(0)
func _boss_fx(stage:String,at:Vector2,width:float,seconds:float,direction:=0.0)->HostileAttackFX:
	var effect:=HostileAttackFX.pulse(_fx(),at,str(boss_id),stage,width,seconds,direction,room)
	if effect!=null:effect.set_meta("boss_owner",get_instance_id())
	return effect
func _update_visual()->void:
	super._update_visual()
	if visual is AnimatedSprite2D:
		var animation:=&"release" if _visual_release_left>0 else &"windup" if main_pending() else &"move" if velocity.length()>8 else &"idle"
		if visual.animation!=animation:visual.play(animation)
		visual.speed_scale=.75 if animation==&"release" else 1.0
func visual_locomotion_state()->StringName:return &"walk" if velocity.length()>8 else &"idle"
func _die()->void:
	if _dead:return
	for construct in _constructs():construct.retire()
	super._die()

func main_pending()->bool:return timeline.any(func(event:Dictionary)->bool:return not bool(event.get("auxiliary",false)))
func on_minion_death(unit:RoomEnemy)->void:
	if active_wave_kind=="bones" and unit.boss_wave_tag==owner_tag+":"+str(active_wave):wave_defeated+=1
	_check_wave_counter()
func prison_expired(construct:BossConstruct)->void:
	var direction:Vector2=(player.global_position-construct.global_position).normalized()
	_command("fan",.85,{"at":construct.global_position,"dir":direction,"count":3,"spread":.7,"speed":170,"ratio":.45,"shape":"fan","radius":200,"auxiliary":true})
