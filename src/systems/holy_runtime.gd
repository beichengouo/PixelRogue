class_name HolyRuntime
extends Node2D
## All derived damage is a character_proc: no equipment, lifesteal or recursive grants.
var actor:RoomPlayer
var clock:=0.0
var prayer:=0.0
var last_hit:=-99.0
var cooldowns:Dictionary={}
var marks:Dictionary={}
var songs:Dictionary={}
var judgment_hits:Dictionary={}
var fields:Array[Dictionary]=[]
var feathers:Array[Dictionary]=[]
var recent_target:=""
var room_id:=""
var cast_serial:=0
var fate_casts:Dictionary={}
var hit_serial:=0
var hit_skill:StringName=&""
var direct_events:Dictionary={}
var cloud_until:=0.0
var feathers_until:=0.0
var judgment_until:=0.0
var sanctuary_until:=0.0
var grace_until:=0.0
var afterlight_until:=0.0
var step_attack_until:=0.0
var hymn_until:=0.0
var devout_until:=0.0
var harmony_until:=0.0
var veil_until:=0.0
var grace_progress:=0
var basic_count:=0
var skill_count:=0
var dew_count:=0
var mark_count:=0
var prayer_cycles:=0
var last_direct_kind:=-1
var last_direct_skill:StringName=&""
var recent_skills:Dictionary={}
var echoes:Array[float]=[]
var afterglows:Dictionary={}
var feather_streak:Dictionary={}
var movement_time:=0.0
var rhythm_hit:=0.0
var rhythm_cast:=0.0
var _cloud_open:=false
var _judgment_open:=false
var _sanctuary_open:=false
var _cast_bonus:=1.0
var warning_serial:=0

func rank(id:StringName)->int:return GameState.talent_rank(id)
func attack()->float:return actor.stats.get_value(&"attack")
func ready(key:String)->bool:return clock>=float(cooldowns.get(key,0))
func start(key:String,seconds:float)->void:cooldowns[key]=clock+seconds
func enemy(id:String)->EnemyBase:
	var node:=instance_from_id(int(id)) if not id.is_empty() else null
	return node as EnemyBase if is_instance_valid(node) else null
func live(node:EnemyBase)->bool:return is_instance_valid(node) and not node._dead and not node.is_queued_for_deletion() and node.hp>0
func targets(at:Vector2,radius:float,count:int=100,excluded:EnemyBase=null)->Array[EnemyBase]:return actor.equipment_mechanics.nearest_enemies(at,radius,count,excluded)
func at(field:Dictionary)->Vector2:return Vector2(float(field.at[0]),float(field.at[1]))
func point(position_value:Vector2)->Array:return [position_value.x,position_value.y]
func combat_active()->bool:return not targets(actor.global_position,1000,1).is_empty()

func _ready()->void:
	room_id=str(actor.room.record.get("id",""));z_index=1
	HolyFX.warm();texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
func _process(delta:float)->void:
	if not is_instance_valid(actor) or actor.hp<=0:return
	clock+=delta
	var current:=str(actor.room.record.get("id",""))
	if current!=room_id:on_room_exit();room_id=current
	movement_time=movement_time+delta if actor.velocity.length()>20 else 0
	var idle_limit:=8.0 if rank(&"holy_flow")>0 and movement_time>0 else 5.0
	if clock-last_hit>idle_limit:prayer=maxf(0,prayer-delta*8)
	for key in cooldowns.keys():
		if float(cooldowns[key])<clock-10:cooldowns.erase(key)
	for key in direct_events.keys():
		if float(direct_events[key].until)<clock:direct_events.erase(key)
	for key in marks.keys():
		if not live(enemy(str(key))) or float(marks[key].until)<=clock:marks.erase(key)
	for key in songs.keys():
		if not live(enemy(str(key))) or float(songs[key].until)<=clock:songs.erase(key)
	for field:Dictionary in fields.duplicate():
		if _tick_field(field,delta):fields.erase(field)
	if _cloud_open and (clock>=cloud_until or actor.shield_hp<=0):
		_cloud_open=false;cloud_until=0;area(actor.global_position,72,.6);HolyFX.spawn(actor.get_parent(),actor.global_position,"cloud",72,.35)
	if veil_until>0 and (clock>=veil_until or actor.shield_hp<=0):
		veil_until=0
		if rank(&"holy_veil")>=3:area(actor.global_position,72,.25)
	if clock<feathers_until or not feathers.is_empty():_tick_feathers()
	if _judgment_open:
		if clock>=judgment_until:
			_judgment_open=false
			for target in targets(actor.global_position,1000,8):pillar(target.global_position,42,1.1,.45,false,null,0,false)
		elif ready("judgment_pillars"):
			start("judgment_pillars",1.2)
			for target in targets(actor.global_position,1000,2):pillar(target.global_position,54,.5,.55,false,target,0,false)
	if _sanctuary_open:
		if clock>=sanctuary_until:
			_sanctuary_open=false;area(actor.global_position,126,.9);shield(.06,3);afterlight_until=clock+3
		else:
			if ready("sanctuary_tick"):start("sanctuary_tick",.75);area(actor.global_position,126,.35);HolyFX.spawn(actor.get_parent(),actor.global_position,"ring",126,.35)
			if ready("sanctuary_purge"):start("sanctuary_purge",1);purge(actor.global_position,60,2)
	if _cloud_open and ready("cloud_purge"):start("cloud_purge",.75);purge(actor.global_position,46,1)
	queue_redraw()

func cast(slot:int)->bool:
	if UIFlow.has_screen() or actor.hp<=0 or (not GameState.run_active and not CampSession.active):return false
	var id:=GameState.skill_for_slot(slot)
	if id==&"" or not HolySkills.DATA.has(id):return false
	if not GameState.skill_ready(slot):
		if GameState.mp<GameState.skill_cost(id) and ready("mana_notice"):
			start("mana_notice",1)
			Effects.text(actor.get_parent(),actor.global_position-Vector2(0,54),"魔力不足",PixelUi.MUTED,14)
		return false
	var skill:Dictionary=HolySkills.DATA[id];var destination:=actor.caster.target(180)
	if id in [&"flame_nova",&"frost_nova"]:
		destination=field_destination(destination)
	if GameState.begin_skill_cast(slot)==&"":return false
	cast_serial+=1;var serial:=cast_serial;fate_casts[str(serial)]=FateRuntime.cast_factor();fate_casts.erase(str(serial-64));var empowered:bool=not bool(skill.ultimate) and prayer>=100
	if empowered:
		prayer=0;prayer_cycles+=1
		actor.equipment_mechanics.legendary.holy_empowered()
		if rank(&"holy_devout")>=2:devout_until=clock+4
		if rank(&"holy_devout")>=3 and prayer_cycles%3==0 and ready("devout_burst"):start("devout_burst",6);area(actor.global_position,96,.3)
	var hymn:bool=not bool(skill.ultimate) and clock<hymn_until
	if hymn:hymn_until=0
	var bonus:=actor.equipment_mechanics.on_skill_cast(id==&"blink",id)
	var perform:=func()->void:_release(id,destination,empowered,bonus,serial,hymn)
	if not UltimateCutin.present(actor,id,perform):perform.call()
	return true

func field_destination(requested:Vector2)->Vector2:
	# nearest_clear can return a point on the far side of an obstacle. Place
	# the field on the last reachable part of the aim ray instead of silently
	# rejecting an otherwise ready spell.
	var origin:=actor.global_position
	var destination:=actor.room.nearest_clear(requested,12)
	if actor.room.sight(origin,destination):return destination
	var last:=origin
	var distance:=origin.distance_to(requested)
	for index in range(1,ceili(distance/4.0)+1):
		var probe:=origin.move_toward(requested,minf(distance,index*4.0))
		if not actor.room.body_clear(probe,12) or not actor.room.sight(origin,probe):break
		last=probe
	return last

func _release(id:StringName,destination:Vector2,empowered:bool,bonus:float,serial:int,hymn:bool=false)->void:
	if actor.hp<=0:return
	_cast_bonus=bonus;actor._cast_timer=.28;actor._cast_pose=&"cast";actor._animation_request+=1;rhythm_cast=clock
	HolyFX.spawn(actor.get_parent(),actor.global_position,"cloud",30,.3)
	match id:
		&"flame_nova":
			var near:=targets(destination,90,1);pillar(destination,64,1.4,.55,true,near[0] if not near.is_empty() else null,serial,true,bonus)
			if empowered:
				for i in 3:pillar(destination+Vector2.RIGHT.rotated(i*TAU/3)*64,36,.65,.8+i*.18,false,null,serial,false,bonus)
		&"fan_bolts":
			HolyFX.spawn(actor.get_parent(),actor.global_position,"feather",40,.45)
			feathers_until=clock+8;feathers.clear()
			for i in (6 if empowered else 3):feathers.append({"ready":clock,"end":clock+(3 if empowered and i>=3 else 8),"index":i,"guard":false,"enhanced":empowered,"bonus":bonus})
		&"blink":
			shield(.20,6);cloud_until=clock+6;_cloud_open=true
			if empowered:purge(actor.global_position,90,3);push(actor.global_position,90,24)
		&"flame_shield":
			bell(actor.global_position,.9,serial,true,bonus)
			if empowered:fields.append({"kind":"bell","at":point(actor.global_position),"delay":.45,"elapsed":0.0,"ratio":.55,"serial":serial,"bonus":bonus})
		&"frost_nova":
			fields.append({"kind":"court","at":point(destination),"remaining":6.0,"timer":0.0,"radius":90.0,"enhanced":empowered,"healed":0.0,"pulses":0,"serial":serial,"bonus":bonus});HolyFX.spawn(actor.get_parent(),destination,"court",90,.5)
		&"healing_light":
			var origin:=actor.global_position;var direction:=actor.velocity.normalized() if actor.velocity.length()>1 else actor.aim_direction.normalized();var end:=origin
			for i in range(1,37):
				var probe:=origin+direction*(i*3)
				if not actor.room.body_clear(probe,12):break
				end=probe
			for target in targets((origin+end)*.5,108):
				if Geometry2D.get_closest_point_to_segment(target.global_position,origin,end).distance_to(target.global_position)<=20:hit(target,.15,origin,serial,true,id,bonus);mark(target,serial)
			actor.global_position=end;actor._invuln=maxf(actor._invuln,.18);step_attack_until=clock+4;decoy(origin,3,empowered)
			var step_fx:=HolyFX.spawn(actor.get_parent(),(origin+end)*.5,"step",maxf(30,origin.distance_to(end)*.6),.5)
			if step_fx!=null:step_fx.facing=direction
		&"meteor":
			judgment_until=clock+8;_judgment_open=true;cooldowns.erase("judgment_pillars");judgment_hits.clear()
			HolyFX.spawn(actor.get_parent(),actor.global_position,"judgment",84,.7)
		&"starfall":
			sanctuary_until=clock+8;_sanctuary_open=true;shield(.12,4);cooldowns.erase("sanctuary_tick")
			HolyFX.spawn(actor.get_parent(),actor.global_position,"sanctuary",126,.7)
	if not HolySkills.DATA[id].ultimate:
		skill_count+=1
		if GameState.passive_id==&"sylphiette_grace" and combat_active():add_grace(1)
		if rank(&"holy_chorus")>0 and feathers.size()<8:feathers.append({"ready":clock,"end":clock+2,"index":feathers.size(),"guard":true,"enhanced":false})
		if rank(&"holy_veil")>0 and skill_count%3==0 and combat_active() and ready("veil"):
			start("veil",8)
			if shield(.06,3):veil_until=clock+3
		if rank(&"holy_flow")>=2 and movement_time>=1.2:
			for target in targets(actor.global_position,216,1):feather_at(actor.global_position,target,.2,1)
		if rank(&"holy_flow")>=3 and movement_time>0 and clock-rhythm_hit<4 and ready("flow_shadow"):start("flow_shadow",10);decoy(actor.global_position,4,false)
	if hymn:area(actor.global_position,80,.25)
	_cast_bonus=1;AudioManager.play(&"wave_clear",-12)

func hit(target:EnemyBase,ratio:float,origin:Vector2,serial:int=0,direct:bool=false,skill:StringName=&"",bonus:float=1)->bool:
	if not live(target):return false
	var hp_before:=target.hp;var shield_before:=target.affix_shield
	var amount:=attack()*ratio*bonus
	if direct:
		amount*=actor.equipment_mechanics.skill_multiplier(target)
		if skill!=&"frost_nova":amount*=float(fate_casts.get(str(serial),1.0))
	target.take_damage(amount,false,origin,(DamageContext.continuous(actor,&"skill_field") if skill==&"frost_nova" else DamageContext.skill(actor)) if direct else DamageContext.character_proc(actor),false)
	var effective:=is_instance_valid(target) and (target.hp<hp_before or target.affix_shield<shield_before)
	if effective and direct:
		hit_serial=serial;hit_skill=skill;actor.equipment_mechanics.on_skill_hit(target,true);hit_skill=&""
	return effective
func area(origin:Vector2,radius:float,ratio:float,serial:int=0,direct:bool=false,skill:StringName=&"",bonus:float=1)->int:
	var hits:=0
	for target in targets(origin,radius):
		if hit(target,ratio,origin,serial,direct,skill,bonus):hits+=1
	return hits
func pillar(origin:Vector2,radius:float,ratio:float,delay:float,direct:bool=false,follow:EnemyBase=null,serial:int=0,branded:bool=false,bonus:float=1,hymn:bool=false)->void:
	if fields.size()>=48:return
	origin=origin.clamp(actor.room.bounds().position+Vector2.ONE*12,actor.room.bounds().end-Vector2.ONE*12)
	fields.append({"kind":"pillar","at":point(origin),"delay":delay,"elapsed":0.0,"radius":radius,"ratio":ratio,"direct":direct,"follow":str(follow.get_instance_id()) if live(follow) else "","serial":serial,"branded":branded,"bonus":bonus,"hymn":hymn})
	warning_serial+=1
	fields[-1]["warning_id"]="%s:%d"%[room_id,warning_serial]
	var warning:=HolyFX.spawn(actor.get_parent(),origin,"warning",radius,delay)
	if warning!=null:warning.warning_id=str(fields[-1].warning_id)
func _tick_field(field:Dictionary,delta:float)->bool:
	var origin:=at(field)
	if field.kind=="court":
		field.remaining-=delta;field.timer-=delta
		if field.timer<=0:
			field.timer+=1;var hits:=area(origin,90,.22,int(field.serial),int(field.get("pulses",0))==0,&"frost_nova",float(field.bonus));field.pulses=int(field.get("pulses",0))+1
			if hits>0 and actor.global_position.distance_to(origin)<=90 and actor.room.sight(origin,actor.global_position) and float(field.healed)<.06:
				var heal_ratio:=minf(.01,.06-float(field.healed));actor.heal_player(actor.max_hp*heal_ratio);field.healed+=heal_ratio
			HolyFX.spawn(actor.get_parent(),origin,"ring",90,.35)
		if field.remaining<=0:
			area(origin,90,.5)
			if field.enhanced:
				for target in targets(origin,216,3):feather_at(origin,target,.2,1)
				if actor.global_position.distance_to(origin)<=90:shield(.08,3);afterlight_until=clock+3
			return true
		return false
	field.elapsed+=delta
	if field.kind=="pillar" and float(field.elapsed)<=.25:
		var followed:=enemy(str(field.follow))
		if live(followed):
			origin=followed.global_position.clamp(actor.room.bounds().position+Vector2.ONE*12,actor.room.bounds().end-Vector2.ONE*12);field.at=point(origin)
			for warning in get_tree().get_nodes_in_group("holy_visuals"):
				if warning is HolyFX and warning.warning_id==str(field.get("warning_id","")):warning.global_position=origin
	field.delay-=delta
	if field.delay>0:return false
	match str(field.kind):
		"pillar":
			var victims:=targets(origin,float(field.radius));var hits:=0
			for target in victims:
				if hit(target,float(field.ratio),origin,int(field.serial),bool(field.direct),&"flame_nova",float(field.bonus)):hits+=1
				if field.branded and live(target):mark(target,int(field.serial))
			HolyFX.spawn(actor.get_parent(),origin,"pillar",float(field.radius),.4)
			if field.branded:fields.append({"kind":"burst","at":point(origin),"delay":.2,"elapsed":0.0,"radius":float(field.radius)+16,"ratio":.35})
			if field.hymn and hits>0:
				add_prayer(4);echoes.append(clock)
				while not echoes.is_empty() and echoes[0]<clock-4:echoes.pop_front()
				if echoes.size()>=3:hymn_until=clock+6;echoes.clear()
				if victims.any(func(target:EnemyBase)->bool:return is_instance_valid(target) and target._dead):
					for target in targets(origin,90,2):songs[str(target.get_instance_id())]={"count":mini(2,int(songs.get(str(target.get_instance_id()),{}).get("count",0))+1),"until":clock+6}
		"bell":bell(origin,float(field.ratio),int(field.serial),false,float(field.bonus))
		"burst":area(origin,float(field.radius),float(field.ratio));HolyFX.spawn(actor.get_parent(),origin,"ring",float(field.radius),.3)
	return true

func add_prayer(value:float)->void:prayer=minf(100,prayer+value);last_hit=clock
func mark(target:EnemyBase,serial:int)->void:
	if live(target):marks[str(target.get_instance_id())]={"until":clock+6,"serial":serial}
func on_direct_hit(target:EnemyBase,kind:int,receipt:BasicAttackReceipt=null)->void:
	var serial:=hit_serial if kind==1 else int(receipt.get_instance_id()) if receipt!=null else 0
	var event_key:="%d:%d"%[kind,serial];var first:=receipt.claim_effect(&"holy_prayer") if kind==0 and receipt!=null else not direct_events.has(event_key)
	var event:Dictionary=direct_events.get(event_key,{"count":0,"until":clock+12})
	if int(event.count)<3:add_prayer(6 if kind==0 else 8);event.count+=1;direct_events[event_key]=event
	if first:
		rhythm_hit=clock;dew_count+=1
		if rank(&"holy_devout")>0 and last_direct_kind>=0 and last_direct_kind!=kind:add_prayer(4)
		last_direct_kind=kind
		if kind==0:
			basic_count+=1
			if GameState.passive_id==&"sylphiette_grace":add_grace(1)
			if live(target):recent_target=str(target.get_instance_id())
			if rank(&"holy_feather_birth")>0 and basic_count%4==0:feather_at(actor.global_position,target,.15,1,1 if rank(&"holy_feather_birth")>=2 else 0)
			if clock<step_attack_until or clock<devout_until:step_attack_until=0;devout_until=0;feather_at(actor.global_position,target,.18,1)
			if clock<harmony_until:harmony_until=0;area(target.global_position,60,.25);if_extra_harmony(target)
			if rank(&"holy_veil")>=2 and actor.shield_hp>0 and ready("veil_light"):start("veil_light",1);area(target.global_position,30,.1)
		else:
			if hit_skill!=&"" and last_direct_skill!=&"" and last_direct_skill!=hit_skill and rank(&"holy_harmony")>0:harmony_until=clock+4
			if hit_skill!=&"":last_direct_skill=hit_skill;recent_skills[str(hit_skill)]=clock
			if rank(&"holy_chorus")>=3 and recent_skills.size()>=2 and ready("feather_chorus"):start("feather_chorus",4);area(actor.global_position,108,.3)
			if rank(&"holy_word")>0 and ready("word_echo") and Rng.stream().randf()<.25:
				start("word_echo",2);area(actor.global_position,64,.12)
				if rank(&"holy_word")>=2:purge(actor.global_position,64,1);slow(actor.global_position,64,.2,1)
				if rank(&"holy_word")>=3 and recent_skills.size()>=3:bell(actor.global_position,.35,serial,false)
		if rank(&"holy_dew")>0 and dew_count>=(4 if rank(&"holy_dew")>=2 and in_field() else 5) and ready("dew_heal"):
			dew_count=0;start("dew_heal",3);actor.heal_player(actor.max_hp*.01)
		if rank(&"holy_dew")>=3 and actor.hp<actor.max_hp*.3 and ready("dew_danger"):start("dew_danger",20);shield(.12,3);afterlight_until=clock+3
	for key in recent_skills.keys():
		if float(recent_skills[key])<clock-6:recent_skills.erase(key)
	if not live(target):return
	var id:=str(target.get_instance_id())
	if marks.has(id) and int(marks[id].serial)!=serial and ready("mark_"+id):
		marks.erase(id);start("mark_"+id,1);mark_count+=1;area(target.global_position,42,.16)
		if rank(&"holy_brand")>=2:
			for other in targets(target.global_position,90,1,target):hit(other,.1,target.global_position)
		if rank(&"holy_brand")>=3 and mark_count%3==0:pillar(target.global_position,42,.4,.35)
	if rank(&"holy_brand")>0 and Rng.stream().randf()<.15:mark(target,serial)
	if GameState.passive_id==&"sylphiette_hymn":
		var song:Dictionary=songs.get(id,{"count":0,"until":clock+6});song.count+=1;song.until=clock+6;songs[id]=song
		if int(song.count)>=3 and ready("song_"+id):songs.erase(id);start("song_"+id,.8);pillar(target.global_position,46,.45,.3,false,null,0,false,1,true)
	if rank(&"holy_afterglow")>0 and ready("afterglow") and Rng.stream().randf()<.15:
		start("afterglow",.8);afterglows[id]=int(afterglows.get(id,0))+1
		if rank(&"holy_afterglow")>=3 and int(afterglows[id])%3==0:pillar(target.global_position,42,.22,.3)
		else:fields.append({"kind":"burst","at":point(target.global_position),"delay":.18,"elapsed":0.0,"radius":50.0 if rank(&"holy_afterglow")>=2 and marks.has(id) else 30.0,"ratio":.1})
	if _judgment_open:
		judgment_hits[id]=int(judgment_hits.get(id,0))+1
		if int(judgment_hits[id])>=(2 if marks.has(id) else 3) and ready("judgment_"+id):judgment_hits[id]=0;start("judgment_"+id,1);pillar(target.global_position,40,.6,.35)
	if _sanctuary_open and target.global_position.distance_to(actor.global_position)<=126 and ready("sanctuary_hit_"+id):start("sanctuary_hit_"+id,.8);area(target.global_position,50,.12)

func if_extra_harmony(target:EnemyBase)->void:
	if rank(&"holy_harmony")>=2:hit(target,.15,actor.global_position)
	if rank(&"holy_harmony")>=3 and ready("harmony_pillar"):start("harmony_pillar",3);pillar(target.global_position,40,.35,.3)
func on_feather_hit(target:EnemyBase,generation:int,split_left:int)->void:
	if not live(target):return
	var id:=str(target.get_instance_id())
	if generation==0 and ready("feather_prayer"):start("feather_prayer",2);add_prayer(4)
	if split_left>0:
		for other in targets(target.global_position,108,1,target):feather_at(target.global_position,other,.12,1)
	if generation==0 and marks.has(id) and ready("feather_mark_"+id):
		start("feather_mark_"+id,1);feather_at(actor.global_position,target,.12,1)
		if rank(&"holy_wings")>=2:area(target.global_position,42,.08)
	if rank(&"holy_feather_birth")>=3 and generation==1 and split_left>0:area(target.global_position,30,.08)
	if rank(&"holy_wings")>=3 and generation==0:
		feather_streak[id]=int(feather_streak.get(id,0))+1
		if int(feather_streak[id])%5==0:area(target.global_position,36,.3)
func feather_at(origin:Vector2,target:EnemyBase,ratio:float,generation:int=0,split:int=0)->HolyBolt:
	if not live(target) or get_tree().get_nodes_in_group("holy_derived").size()>=48:return null
	var bolt:=HolyBolt.new();bolt.feather=true;bolt.generation=generation;bolt.split_left=split;bolt.room=actor.room;bolt.damage_owner=&"player";bolt.is_friendly=true;bolt.mechanic_tag=&"character_proc";bolt.range_limit=420;bolt.homing_range=420;bolt.homing_turn=PI*2;bolt.homing_origin=origin;bolt.owner_aim=(target.global_position-origin).normalized();bolt.add_to_group("holy_derived")
	actor.get_tree().get_first_node_in_group("room_fx").add_child(bolt);bolt.setup(origin,bolt.owner_aim,attack()*ratio,380,actor.room,null,Color("ffe8a8"));return bolt
func _tick_feathers()->void:
	var preferred:=enemy(recent_target)
	for feather:Dictionary in feathers.duplicate():
		if clock>=float(feather.end):
			if feather.guard and rank(&"holy_chorus")>=2:
				for target in targets(actor.global_position,216,1):feather_at(actor.global_position,target,.15,1)
			feathers.erase(feather);continue
		if float(feather.ready)>clock:continue
		var target:=preferred if live(preferred) and actor.global_position.distance_to(preferred.global_position)<=216 and actor.room.sight(actor.global_position,preferred.global_position) else null
		if target==null:
			var nearby:=targets(actor.global_position,216,1)
			if not nearby.is_empty():target=nearby[0]
		if target!=null:
			var origin:=actor.global_position+Vector2(0,14)+Vector2.RIGHT.rotated(clock*2+float(feather.index)*TAU/maxi(1,feathers.size()))*30
			if not actor.room.body_clear(origin,2) or not actor.room.sight(actor.global_position,origin):origin=actor.global_position
			feather.ready=clock+2;feather_at(origin,target,.3*float(feather.get("bonus",1)),0,1 if feather.enhanced else 0)
func shield(ratio:float,seconds:float)->bool:
	var value:=actor.max_hp*ratio
	if value*FateCatalog.shield_factor()<actor.shield_hp:return false
	actor.equipment_mechanics.grant_player_shield(value,seconds);return true
func on_shield_absorbed(amount:float)->void:
	if amount<=0:return
	if ready("shield_prayer"):start("shield_prayer",.35);add_prayer(12)
	if _cloud_open and ready("cloud_counter"):
		start("cloud_counter",.35)
		for target in targets(actor.global_position,250,1):feather_at(actor.global_position,target,.25,1)
func on_hurt()->void:
	if rank(&"holy_purity")<=0 or not ready("purity"):return
	start("purity",6);purge(actor.global_position,64,2);HolyFX.spawn(actor.get_parent(),actor.global_position,"ring",64,.3)
	if rank(&"holy_purity")>=2:area(actor.global_position,64,.2)
	if rank(&"holy_purity")>=3 and feathers.size()<8:feathers.append({"ready":clock+.75,"end":clock+1.5,"index":feathers.size(),"guard":true,"enhanced":false})
func add_grace(value:int)->void:
	grace_progress=mini(5,grace_progress+value)
	if grace_progress>=5 and ready("grace_ring") and grace_until<=clock:grace_progress=0;grace_until=clock+6;start("grace_ring",8)
func protect(amount:float,source:Node)->float:
	if amount<=0 or actor._invuln>0 or actor.bloodbath_active() or CruelDamage.applies(source) or actor.shield_hp>0 or grace_until<=clock:return amount
	grace_until=0;add_prayer(12);area(actor.global_position,72,.35);push(actor.global_position,72,18)
	for target in targets(actor.global_position,216,2):feather_at(actor.global_position,target,.18,1)
	return 0.0 if ordinary_bullet(source) else amount*.65
func ordinary_bullet(source:Node)->bool:
	return source is RoomProjectile and not source.is_friendly and source.damage_owner!=&"boss" and not source.cruel_damage
func purge(origin:Vector2,radius:float,count:int)->void:
	var removed:=0
	for bullet in get_tree().get_nodes_in_group("room_projectiles"):
		if removed>=count:break
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion() or not ordinary_bullet(bullet):continue
		if bullet.global_position.distance_to(origin)>radius or not actor.room.sight(origin,bullet.global_position):continue
		HolyFX.spawn(actor.get_parent(),bullet.global_position,"ring",12,.15);bullet.queue_free();removed+=1
func slow(origin:Vector2,radius:float,ratio:float,seconds:float)->void:
	for target in targets(origin,radius):target.apply_slow(ratio*.5 if target is BossBase else ratio,seconds)
func push(origin:Vector2,radius:float,distance:float)->void:
	for target in targets(origin,radius):
		if target is BossBase or target.is_elite() or target.training_target:continue
		var direction:Vector2=(target.global_position-origin).normalized()
		for i in ceili(distance/3):
			var probe:=target.global_position+direction*3
			if not actor.room.body_clear(probe,target.body_radius() if target.has_method("body_radius") else 12):break
			target.global_position=probe
func bell(origin:Vector2,ratio:float,serial:int,direct:bool,bonus:float=1)->void:
	area(origin,108,ratio,serial,direct,&"flame_shield",bonus);push(origin,108,54);purge(origin,108,3);HolyFX.spawn(actor.get_parent(),origin,"bell",108,.55)
	for target in targets(origin,108):target.apply_slow(.2 if target is BossBase else .3 if target.is_elite() else 1.0,1.2 if target is BossBase or target.is_elite() else .55)
func decoy(origin:Vector2,seconds:float,empowered:bool)->HolyDecoy:
	var unit:=HolyDecoy.new();unit.holy=self;unit.remaining=seconds;unit.empowered=empowered;actor.get_tree().get_first_node_in_group("room_fx").add_child(unit);unit.global_position=origin
	return unit
func in_field()->bool:
	if _sanctuary_open:return true
	return fields.any(func(field:Dictionary)->bool:return field.kind=="court" and actor.global_position.distance_to(at(field))<=90)
func on_room_exit()->void:
	marks.clear();songs.clear();judgment_hits.clear();fields.clear();feathers.clear();recent_target="";prayer=0;cloud_until=0;feathers_until=0;judgment_until=0;sanctuary_until=0;_cloud_open=false;_judgment_open=false;_sanctuary_open=false
	for unit in get_tree().get_nodes_in_group("holy_decoys"):
		if unit.holy==self:unit.empowered=false;unit.expire()
func _draw()->void:
	var gold:=Color(1,.86,.53,.7);var origin:=Vector2(0,14)
	var intensity:=clampf(float(SaveService.data.get("spell_fx_strength",1)),0,1)
	var phase:=.30 if ComicMotion.reduced() else fposmod(clock*.55,1.0)*.45+.15
	if prayer>=100:
		var center:=to_local(actor.global_position+Vector2(0,-2))
		draw_arc(center,36,0,TAU,64,gold,2);draw_arc(center,32,0,TAU,64,Color(.65,.84,1,.5),1)
	if grace_until>clock:draw_arc(origin,24,0,TAU,36,Color(.8,.9,1,.6),2)
	if _cloud_open:
		HolyFX.paint(self,"cloud",HolyFX.ground_rect("cloud",39,origin),phase,intensity*.95)
		draw_arc(origin,29,0,TAU,40,gold,1)
	if _judgment_open:HolyFX.paint(self,"judgment",HolyFX.ground_rect("judgment",22,origin),phase,intensity*.9)
	if _sanctuary_open:
		HolyFX.paint(self,"sanctuary",HolyFX.ground_rect("sanctuary",126,origin),phase,intensity*.45)
		draw_arc(origin,126,0,TAU,64,Color(1,.91,.67,.4),1)
	for feather:Dictionary in feathers:
		if float(feather.ready)>clock:continue
		var position_value:=origin+Vector2.RIGHT.rotated(clock*2+float(feather.index)*TAU/maxi(1,feathers.size()))*30
		HolyFX.paint(self,"feather",Rect2(position_value-Vector2(12,7),Vector2(24,14)),phase,intensity)
	for field in fields:
		if field.kind=="court":
			var location:=to_local(at(field))
			HolyFX.paint(self,"court",HolyFX.ground_rect("court",90,location+Vector2(0,14)),phase,intensity*.48)
			draw_arc(location,90,0,TAU,48,Color(1,.9,.6,.32),1)
	for id in marks:
		var target:=enemy(str(id))
		if live(target):
			var position_value:=to_local(target.global_position+Vector2(0,12))
			draw_arc(position_value,13,0,TAU,24,gold,1.5);draw_line(position_value+Vector2(0,-5),position_value+Vector2(0,5),gold,1.5)
func snapshot()->Dictionary:
	var result:Dictionary={}
	for property in get_property_list():
		var name_value:=str(property.name)
		if property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE and name_value not in ["actor"]:result[name_value]=get(name_value).duplicate(true) if get(name_value) is Array or get(name_value) is Dictionary else get(name_value)
	result["decoys"]=[]
	for unit in get_tree().get_nodes_in_group("holy_decoys"):
		if unit.holy==self and not unit.exploded:result.decoys.append({"at":point(unit.global_position),"remaining":unit.remaining,"empowered":unit.empowered,"fire_clock":unit.fire_clock})
	return result
func restore(saved:Dictionary,ids:Dictionary)->void:
	if saved.is_empty():return
	var allowed:Dictionary={}
	for property in get_property_list():
		if property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE:allowed[str(property.name)]=true
	for key in saved:
		if allowed.has(key) and key!="actor":
			if get(key) is Array:(get(key) as Array).assign(saved[key])
			else:set(key,saved[key])
	for table in [marks,songs,judgment_hits,afterglows,feather_streak]:
		for old_id in table.keys():
			var value:Variant=table[old_id];table.erase(old_id)
			if ids.has(str(old_id)):table[str(ids[str(old_id)].get_instance_id())]=value
	if ids.has(recent_target):recent_target=str(ids[recent_target].get_instance_id())
	else:recent_target=""
	for field in fields:
		if field.has("follow"):field.follow=str(ids[str(field.follow)].get_instance_id()) if ids.has(str(field.follow)) else ""
	for key in cooldowns.keys():
		for prefix in ["mark_","song_","judgment_","sanctuary_hit_","feather_mark_"]:
			if str(key).begins_with(prefix):
				var old_id:=str(key).trim_prefix(prefix);var value:float=float(cooldowns[key]);cooldowns.erase(key)
				if ids.has(old_id):cooldowns[prefix+str(ids[old_id].get_instance_id())]=value
				break
	for record in saved.get("decoys",[]):
		var unit:=decoy(Vector2(record.at[0],record.at[1]),float(record.remaining),bool(record.empowered));unit.fire_clock=float(record.get("fire_clock",.5))
	for field in fields:
		if field.kind=="pillar" and float(field.delay)>0:
			var warning:=HolyFX.spawn(actor.get_parent(),at(field),"warning",float(field.radius),float(field.delay))
			if warning!=null:warning.warning_id=str(field.get("warning_id",""))
