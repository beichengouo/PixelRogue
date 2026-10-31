extends "res://tests/inventory_v17.gd"
const ROOT := "E:/CodexWorkspace/PixelRogue/work/v36-style-and-combo/combat-integration/"
const TIMES := [.24,.84,1.59,2.49,3.59]
var tested_form:=false

func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with(ROOT):get_tree().quit(2);return
	ErrorReporter.interactive=false;AchievementTracker.set_process(false);TransitionLayer.boot_played=true;SaveService.data.reduced_motion=true
	tested_form=OS.get_cmdline_user_args().has("--legendary")
	clock_checks()
	await begin(&"xixifu");main.gm_pilot.set_process(false)
	GameState.legendary_looks["xixifu"]={"set":tested_form};actor._refresh_legendary_visual()
	for enemy in main.enemies_root.get_children():enemy.queue_free()
	await frames(3)
	actor.stats.set_base(&"attack_speed",1);actor.stats.set_base(&"crit_chance",0);actor.stats.set_base(&"lifesteal",2)
	actor.aim_direction=Vector2.LEFT
	check(actor.uses_basic_chain(),"actual player factory activates matching five-stage outfit")
	resource_checks()
	await projectile_checks()
	await interruption_checks()
	await physics_checks()
	await pilot_checks()
	await settle_actor()
	AudioManager.shutdown();await get_tree().create_timer(.3,true,false,true).timeout
	print("XIXIFU_CHAIN_V36 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)

func clock_checks()->void:
	for haste:float in [.5,1.0,1.5,2.0]:
		for dt:float in [1.0/120,1.0/60,.23,4.8/haste]:
			var chain:=XixifuBasicChain.new();var events:Array=[]
			var callback:=func(stage:int,direction:Vector2)->bool:events.append([stage,chain.clock,direction]);return true
			var left:=4.8/haste
			while left>.000001:
				var step:=minf(dt,left);chain.advance(step,haste,true,Vector2.LEFT,callback);left-=step
			check(events.size()==5,"exactly five releases at haste/delta "+str([haste,dt]))
			for index in mini(5,events.size()):
				check(events[index][0]==index+1 and absf(events[index][1]-TIMES[index])<.00001,"ordered normalized release "+str(index))
	var chain:=XixifuBasicChain.new();var events:Array=[]
	var callback:=func(stage:int,direction:Vector2)->bool:events.append([stage,chain.clock,direction]);return true
	chain.request();chain.advance(.6,1,false,Vector2.LEFT,callback)
	check(events.size()==1 and not chain.active,"tap commits only one segment")
	chain.request();chain.advance(.25,1,false,Vector2.DOWN,callback)
	check(events.size()==2 and events[1][0]==2,"tap within window resumes second stage")
	chain.cancel();var debt:=chain.budget_until;chain.request();chain.advance(.01,1,false,Vector2.RIGHT,callback)
	check(events.size()==2 and chain.budget_until==debt,"cancel/repress cannot erase attack budget")
	chain.advance(2,1,false,Vector2.RIGHT,callback)
	chain.request();chain.advance(.24,1,false,Vector2.RIGHT,callback)
	check(events.back()[0]==1,"expired resume restarts first stage after debt")
	chain=XixifuBasicChain.new();events.clear()
	chain.advance(.17,1,true,Vector2.LEFT,callback)
	chain.advance(.08,1,true,Vector2.RIGHT,callback)
	check(events[0][2]==Vector2.LEFT,"final .08 of windup locks launch direction")
	chain.advance(.35,1,true,Vector2.RIGHT,callback);chain.advance(.24,1,true,Vector2.DOWN,callback)
	check(events[1][2]==Vector2.DOWN,"next segment can retarget")
	chain=XixifuBasicChain.new();events.clear()
	chain.advance(.3,.5,true,Vector2.LEFT,callback);chain.advance(.1,2,true,Vector2.LEFT,callback)
	check(events.size()==1 and is_equal_approx(chain.clock,.35),"live haste change advances existing phase without restart")
	chain=XixifuBasicChain.new();events.clear()
	chain.advance(4,1,true,Vector2.LEFT,func(stage:int,_dir:Vector2)->bool:events.append(stage);return false)
	check(events.size()==1 and not chain.active,"invalidated release stops stale coarse-frame catchup")
	# Explicitly resume each tap with a delay, including the final release.
	chain=XixifuBasicChain.new()
	for index in 5:
		chain.request();chain.advance(float(XixifuBasicChain.DURATIONS[index]),1,false,Vector2.LEFT,callback)
		if index<4:chain.advance(.3,1,false,Vector2.LEFT,callback)
	check(chain.remaining()<.00001,"resumed full finisher pays its complete recovery")
	# Repeated taps and cancels can never produce more shots than the reserved budget.
	for style in 3:
		chain=XixifuBasicChain.new();events.clear()
		for tick in 2400:
			chain.request()
			chain.advance(.01,1,false,Vector2.LEFT,callback)
			if style==1 and chain.released:chain.cancel()
			if style==2 and tick%23==0:chain.cancel()
		check(events.size()<=29,"tap/cancel spam respects 0.873 minimum average budget "+str(style))

func resource_checks()->void:
	var art:=actor._sprite.sprite_frames
	check(art.get_meta("hd_foot")==Vector2(224,392) and art.get_meta("core_height")==240.0,"production scale and pivot")
	check(art.get_meta("combo_release_times")==PackedFloat32Array(TIMES),"runtime preview release times follow current combat cadence")
	for direction:String in HanddrawnHeroArt.DIRECTIONS:
		for stage in range(1,6):
			for prefix:String in ["attack","move_attack"]:
				var name_value:=StringName(prefix+str(stage)+"_"+direction)
				check(art.get_frame_count(name_value)==4,"authored stage exists "+str(name_value))
				var seconds:=0.0
				for frame in 4:seconds+=art.get_frame_duration(name_value,frame)/art.get_animation_speed(name_value)
				check(is_equal_approx(seconds,XixifuBasicChain.DURATIONS[stage-1]),"preview and combat share segment duration")
				check(is_equal_approx(art.get_frame_duration(name_value,0)/art.get_animation_speed(name_value),XixifuBasicChain.RELEASE),"preview and combat share release pose timing")
				for index in 4:
					var tex:AtlasTexture=art.get_frame_texture(name_value,index)
					check(tex.atlas.resource_path.begins_with("res://assets/heroes_handdrawn_v37/" if tested_form else "res://assets/heroes_handdrawn_v36/") and tex.region.size==Vector2(448,448),"admitted runtime asset, no excluded art_src dependency")
	var retained:=art;HanddrawnHeroArt.clear()
	check(retained.get_frame_texture(&"attack5_w",3)!=null,"live resource survives cache release")
	for hero:StringName in [&"xixifu",&"ilyua",&"sylphiette"]:
		for form:bool in [false,true]:
			var other:=HanddrawnHeroArt.frames(form,hero)
			check(bool(other.get_meta("xixifu_chain",false))==(hero==&"xixifu"),"both Xixifu outfits opt into the same controller")

func bullets()->Array:
	var result:Array=[]
	for child in main.fx_root.get_children():
		if child is RoomProjectile and child.is_basic_attack and not child.is_queued_for_deletion():result.append(child)
	return result

func clear_bullets()->void:
	for child in main.fx_root.get_children():
		if child is RoomProjectile:child.get_parent().remove_child(child);child.queue_free()

func reset_chain()->void:
	actor.basic_chain=XixifuBasicChain.new();actor._attack_cd=0;actor._dash_timer=0;actor._dash_cd=0;actor.caster.cancel_cast();actor.extraction_pose=&"";actor.hp=maxf(actor.hp,1)

func projectile_checks()->void:
	reset_chain();clear_bullets();actor.request_attack()
	actor.advance_basic_chain(.23,false);check(bullets().is_empty(),"request no longer launches before windup")
	actor.advance_basic_chain(.01,false)
	var first:=bullets();check(first.size()==1,"first release emits one actual projectile")
	actor._update_animation();check(actor._sprite.frame==1,"launch event and authored release pose share one clock")
	var damage:float=first[0].damage
	clear_bullets();reset_chain();actor.advance_basic_chain(3.59,true)
	var all:=bullets();check(all.size()==7,"five releases emit 1+1+1+1+3 projectiles")
	var receipts:Dictionary={};var total:=0.0
	for bullet:RoomProjectile in all:
		receipts[bullet.attack_receipt.get_instance_id()]=true;total+=bullet.damage
	check(receipts.size()==5 and is_equal_approx(total,damage*5.5),"five attack receipts and 5.5D total budget")
	var finisher:BasicAttackReceipt=all[4].attack_receipt
	for index in range(4,7):
		var bullet:RoomProjectile=all[index]
		check(bullet.attack_receipt==finisher and is_equal_approx(bullet.damage,damage*.5),"finisher shares receipt and half damage")
		var degrees:=rad_to_deg(wrapf(bullet.velocity.angle()-Vector2.LEFT.angle(),-PI,PI))
		check(absf(degrees-[-10.0,0.0,10.0][index-4])<.001,"finisher uses designed spread")
	check(finisher.claim()>0 and finisher.claim()==0 and finisher.claim()==0,"lifesteal pays once across three shots")
	check(finisher.claim_effect(&"test_proc") and not finisher.claim_effect(&"test_proc"),"once-per-attack equipment key stays shared")
	# Existing empowered replacement fires once and inherits the finisher's multiplier.
	clear_bullets();reset_chain();actor.equipment_mechanics._counts[&"wind_branch"]=1
	actor.equipment_mechanics.wind_until=actor.equipment_mechanics.clock+10
	actor._emit_basic(5,Vector2.LEFT);all=bullets()
	check(all.size()==3 and actor.equipment_mechanics.wind_until==0,"wind branch consumes one empowerment, not three")
	for bullet:RoomProjectile in all:check(bullet.mechanic_tag==&"wind_fan" and is_equal_approx(bullet.damage,damage*1.5*.55),"empowered finisher keeps existing equipment rules")
	actor.equipment_mechanics._counts.clear()
	clear_bullets();reset_chain();actor.stats.set_base(&"crit_chance",1);actor.stats.set_base(&"crit_mult",2)
	actor._emit_basic(5,Vector2.LEFT);all=bullets()
	for bullet:RoomProjectile in all:check(bullet.attack_receipt.critical and is_equal_approx(bullet.damage,damage),"one critical roll applies consistently to all finisher bolts")
	actor.stats.set_base(&"crit_chance",0)
	# Existing snapshot path keeps the shared receipt, but never resumes an unfinished windup.
	clear_bullets();reset_chain();actor.advance_basic_chain(3.59,true)
	var saved_receipt:BasicAttackReceipt=bullets().back().attack_receipt
	saved_receipt.claim();saved_receipt.claim_effect(&"disk_proc")
	var before:=actor._attack_cd;var record:Dictionary=main.expedition.capture_room()
	check(not record.player.fields.has("basic_chain"),"controller is not serialized into save schema")
	var path:=OS.get_user_data_dir()+"/v36-room.json"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(record));file.close()
	record=JSON.parse_string(FileAccess.get_file_as_string(path))
	main.expedition.restore_room(record,true)
	check(not actor.basic_chain.active and is_equal_approx(actor._attack_cd,before),"disk roundtrip cancels windup and preserves debt")
	all=bullets();check(all.size()==7,"disk roundtrip restores all actual basic projectiles")
	receipts.clear()
	for bullet:RoomProjectile in all:receipts[bullet.attack_receipt.get_instance_id()]=true
	check(receipts.size()==5,"restored three-bolt volley keeps shared receipt")
	var paid:=0
	for bullet:RoomProjectile in all:
		if bullet.attack_receipt.claimed:
			paid+=1;check(bullet.attack_receipt.claim()==0 and not bullet.attack_receipt.claim_effect(&"disk_proc"),"disk restore cannot repay claimed finisher effects")
	check(paid==3,"all three restored finisher bolts retain consumed receipt")
	clear_bullets();await frames(3)

func interruption_checks()->void:
	reset_chain();actor.request_attack();actor.advance_basic_chain(.1,false)
	check(actor.caster.cast(0),"default unlocked skill accepts a cast")
	check(not actor.basic_chain.active,"accepted skill cancels unreleased basic")
	actor.advance_basic_chain(.5,true);check(bullets().is_empty(),"busy skill cannot emit basic")
	actor.caster.cancel_cast();reset_chain();actor.advance_basic_chain(.25,true)
	var debt:=actor._attack_cd;clear_bullets();actor.request_dash_direction(Vector2.RIGHT)
	check(not actor.basic_chain.active and is_equal_approx(actor._attack_cd,debt),"dash cancels without erasing debt")
	actor.advance_basic_chain(.1,true);check(bullets().is_empty(),"dash cannot launch basic")
	for pose:StringName in [&"prayer",&"departing"]:
		reset_chain();actor.advance_basic_chain(.1,true);actor.set_extraction_pose(pose)
		actor.advance_basic_chain(1,true);check(not actor.basic_chain.active and bullets().is_empty(),"extraction cancels pending release "+str(pose))
	reset_chain();actor.advance_basic_chain(.25,true);clear_bullets();debt=actor._attack_cd;actor.stop_room_travel_motion()
	check(not actor.basic_chain.active and is_equal_approx(actor._attack_cd,debt),"room travel cancels without cooldown reset")
	reset_chain();actor.advance_basic_chain(.1,true);actor.hp=0;actor.advance_basic_chain(2,true)
	check(not actor.basic_chain.active and bullets().is_empty(),"dead actor cannot emit crossed events")
	reset_chain();actor.advance_basic_chain(.1,true);actor.set_physics_process(true)
	get_tree().paused=true;var frozen:=actor.basic_chain.clock
	await frames(8)
	check(actor.basic_chain.clock==frozen and bullets().is_empty(),"scene pause freezes windup and projectile creation")
	actor.advance_basic_chain(1,true);check(actor.basic_chain.clock==frozen,"explicit entry also respects pause")
	get_tree().paused=false;actor.set_physics_process(false);reset_chain()
	# Switching costume must cancel old activity without bypassing its reserved time.
	actor.advance_basic_chain(.25,true);clear_bullets();debt=actor._attack_cd
	GameState.legendary_looks["xixifu"]={"set":not tested_form};actor._refresh_legendary_visual()
	check(actor.uses_basic_chain() and not actor.basic_chain.active and is_equal_approx(actor._attack_cd,debt),"outfit change cancels pending stage and preserves debt")
	GameState.legendary_looks["xixifu"]={"set":tested_form};actor._refresh_legendary_visual()
	check(actor.uses_basic_chain() and is_equal_approx(actor._attack_cd,debt),"return to original outfit cannot reset budget")
	reset_chain()

func physics_checks()->void:
	GameState.gm_pilot_active=true
	actor.aim_override=Vector2.LEFT;actor.set_physics_process(true)
	var stages:Dictionary={};var moving_stages:Dictionary={};var phase_preserved:=false
	for tick in 250:
		await get_tree().physics_frame
		if actor.basic_chain.active:stages[actor.basic_chain.stage]=true
		if tick==10:
			actor.set_physics_process(false)
			var time:=actor.basic_chain.elapsed();actor.velocity=Vector2.RIGHT*90;actor._update_animation()
			phase_preserved=actor.basic_chain.elapsed()==time and str(actor._sprite.animation).begins_with("move_attack1_")
			actor.set_physics_process(true)
		actor.movement_override=Vector2.RIGHT*.2 if tick%80<40 else Vector2.LEFT*.2
		if str(actor._sprite.animation).begins_with("move_attack"):moving_stages[actor.basic_chain.stage]=true
	check(stages.size()==5 and moving_stages.size()==5,"production physics and bot aim drive all five authored moving stages")
	check(phase_preserved,"start moving preserves current attack phase")
	actor.set_physics_process(false);GameState.gm_pilot_active=false;actor.aim_override=Vector2.ZERO;actor.movement_override=Vector2.ZERO;actor.cancel_basic_chain()
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(2)
		for direction in 8:
			reset_chain();actor.aim_direction=Vector2.DOWN.rotated(direction*PI/4);actor.advance_basic_chain(3.66,true)
			for moving in [false,true]:
				actor.velocity=Vector2.LEFT*90 if moving else Vector2.ZERO;actor._update_animation()
				check(str(actor._sprite.animation).begins_with("move_attack5_" if moving else "attack5_"),"actual finisher pose at "+str(extent))
				var foot:=actor._sprite.to_global(Vector2(224,392)-Vector2.ONE*224)
				check(foot.distance_to(actor.global_position+Vector2(0,14))<.01,"fixed foot pivot through movement/facing/resolution")
		clear_bullets()
	reset_chain();actor.velocity=Vector2.ZERO

func pilot_checks()->void:
	clear_bullets();reset_chain();actor.hp=actor.max_hp;actor._hurt_timer=0;actor._flash=0
	actor.global_position=main.level.nearest_clear(main.level.bounds().get_center(),12)
	var target:=RoomEnemy.new();target.configure(&"walker");target.room=main.level;target.training_target=true
	target.setup(actor,main.level,1,1,1);main.enemies_root.add_child(target);target.set_physics_process(false)
	target.global_position=main.level.nearest_clear(actor.global_position+Vector2.RIGHT*200,12)
	target.max_hp=100000;target.hp=100000
	# Isolate basic-attack integration, without reporting this stationary target as a victory.
	GameState.mp=0;GameState.gm_pilot_used=false
	check(main.gm_pilot.activate(),"real pilot activation accepted")
	main.gm_pilot.set_process(true);actor.set_physics_process(true)
	var stages:Dictionary={};var aim_selected:=false
	for tick in 360:
		await get_tree().physics_frame
		aim_selected=aim_selected or not actor.aim_override.is_zero_approx()
		if actor.basic_chain.active:stages[actor.basic_chain.stage]=true
	check(aim_selected and stages.size()==5,"actual GMPilot selects target and drives full chain without test aim injection")
	check(target.hp<target.max_hp,"pilot projectiles reach and damage the target")
	main.gm_pilot.set_process(false);main.gm_pilot._clear_controls();GameState.gm_pilot_active=false;actor.set_physics_process(false)
	actor.cancel_basic_chain();target.queue_free();clear_bullets();await frames(3)
