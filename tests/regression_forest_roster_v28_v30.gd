extends "res://tests/inventory_v17.gd"
const ROOT:="E:/CodexWorkspace/PixelRogue/work/v30-boss-phases/"
const GOBLINS:Array[StringName]=[&"goblin_scout",&"goblin_spearman",&"goblin_mage"]
const RETIRED:Array[StringName]=[&"moss_badger",&"bell_snail"]
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	AchievementTracker.set_process(false);ErrorReporter.interactive=false;SaveService.data.reduced_motion=true
	await begin(&"sylphiette")
	roster_checks();asset_checks();await combat_checks();await restore_checks()
	await settle_actor();AudioManager.shutdown();await frames()
	print("FOREST_ROSTER_V28 checks=",checks," failures=",failures);get_tree().quit(1 if failures else 0)
func roster_checks()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=2801;var encountered:Dictionary={}
	for biome:String in ["forest","wetland"]:
		for wave in range(1,31):
			for sample in 20:
				var units:=RoomEnemyComposer.compose(18,biome,wave,rng)
				var unique:Dictionary={};var valid:=units.size()==18
				for kind in units:
					valid=valid and kind not in RETIRED and str(kind) in ChapterCatalog.config(ChapterCatalog.FIRST).enemies
					unique[kind]=true;encountered[kind]=true
					if kind==&"goblin_spearman":valid=valid and wave>=3
					if kind==&"goblin_mage":valid=valid and wave>=6
				check(valid and unique.size()<=4,"legal roster count/stage/retirement "+biome+str(wave))
	for kind in GOBLINS:check(encountered.has(kind),"new species actually enters composer "+str(kind))
	for kind in RETIRED:
		check(str(kind) not in ChapterCatalog.config(ChapterCatalog.FIRST).enemies and kind not in EnemyCombatPolicy.NEW_KINDS,"retired species removed from active lists")
		var unit:=WaveDirector.create_enemy(kind);check(unit.kind==EnemyCombatPolicy.active_kind(kind),"old factory request resolves compatible active species");unit.free()
		for biome:String in ["forest","wetland","ruin"]:
			for i in 40:check(EnemyCombatPolicy.room_variant(kind,biome,rng,20) not in RETIRED,"legacy biome variant never returns retired species")
	var entries:=MonsterCodex.entries();var ids:Array=[]
	for entry:Dictionary in entries:ids.append(str(entry.id))
	for kind in RETIRED:check(str(kind) not in ids,"retired codex entry removed")
	for kind in GOBLINS:check(str(kind) in ids,"new codex entry present")
	check(AchievementCatalog.DATA.size()==125,"remove six retired mastery entries, add nine goblin mastery entries")
	var old:Dictionary=SaveService.data.achievements.duplicate(true);SaveService.data.achievements={}
	for kind in RETIRED:
		for goal in [100,500,1000]:
			var id:="slayer_%s_%d"%[kind,goal];check(not AchievementCatalog.DATA.has(id),"retired achievement removed");SaveService.data.achievements[id]=1
	check(AchievementCatalog.unlocked_count()==0,"historical retired unlocks excluded from active total")
	for kind in GOBLINS:
		for goal in [100,500,1000]:
			var id:="slayer_%s_%d"%[kind,goal];check(AchievementCatalog.DATA.has(id) and AchievementCatalog.icon(id)!=null,"goblin mastery entry and valid reused emblem")
	SaveService.data.achievements.first_room=1;check(AchievementCatalog.unlocked_count()==1 and SaveService.data.achievements.size()==7,"archive historical unlock keys without inflating UI count")
	SaveService.data.achievements=old
func asset_checks()->void:
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("E:/CodexWorkspace/PixelRogue/work/v27-forest-chibi/interface-baseline.json"))
	for kind:String in baseline:
		if StringName(kind) in RETIRED:continue
		var animation:=PixelEnemyArt.make_frames(StringName(kind));var expected:Dictionary=baseline[kind]
		check((animation.get_frame_texture(&"idle",0) as AtlasTexture).atlas.resource_path==str(expected.source),"original orc/city/detailed creature atlas restored "+kind)
		for action:String in expected.actions:
			var spec:Dictionary=expected.actions[action]
			check(animation.get_frame_count(action)==int(spec.count) and animation.get_animation_speed(action)==float(spec.speed) and animation.get_animation_loop(action)==bool(spec.loop),"unchanged existing animation "+kind+action)
	for kind in GOBLINS:
		var image:=Image.load_from_file(ProjectSettings.globalize_path(ForestUnitArt.path(kind)));var data:=ForestUnitArt.metadata(kind)
		check(image.get_size()==Vector2i(512,768) and int(data.palette_size)<=16,"compact pixel source "+str(kind))
		var animation:=PixelEnemyArt.make_frames(kind)
		for action:StringName in [&"idle",&"walk",&"windup",&"attack",&"hurt",&"death"]:check(animation.has_animation(action) and animation.get_frame_count(action)==4,"six complete action rows")
		check(animation.get_frame_count(&"spawn")==8 and animation.get_frame_count(&"charge")==3,"shared lifecycle aliases preserved")
		for i in 24:
			var box:=image.get_region(Rect2i(Vector2i(i%4,i/4)*128,Vector2i(128,128))).get_used_rect()
			check(box.has_area() and box.position.x>=4 and box.end.x<=124 and box.end.y==116,"complete grounded sprite frame")
		check(MonsterCodex.icon({"id":str(kind),"kind":str(kind),"type":"ordinary"})!=null,"goblin codex shares current art")
	check(HostileAttackFX.frames("goblin_spearman","flight").size()==4 and HostileAttackFX.frames("goblin_mage","flight").size()==4,"visible javelin and magic projectile resources")
	check(not EnemyCombatPolicy.ranged_affix_allowed(&"goblin_scout") and EnemyCombatPolicy.ranged_affix_allowed(&"goblin_spearman") and EnemyCombatPolicy.ranged_affix_allowed(&"goblin_mage"),"weapon roles and ranged affixes match")
func spawn(kind:StringName)->RoomEnemy:
	var unit:=RoomEnemy.new();unit.configure(kind);unit.room=main.level;unit.setup(actor,main.level,1,1,1);unit.position=main.level.nearest_clear(actor.position+Vector2(75,0),12,false)
	main.director.enemies_root.add_child(unit);unit.set_physics_process(false);return unit
func combat_checks()->void:
	var units:Array[RoomEnemy]=[]
	for kind in GOBLINS:units.append(spawn(kind))
	var scout:RoomEnemy=units[0];scout._locked_direction=Vector2.RIGHT
	var original_position:=actor.global_position
	for offset:Vector2 in [Vector2(20,0),Vector2(-20,0),Vector2(70,0),Vector2(0,30)]:
		actor.global_position=scout.global_position+offset;actor.hp=actor.max_hp;actor._invuln=0;var health:=actor.hp;scout._release()
		check((actor.hp<health)==(offset==Vector2(20,0)),"knife attack respects short facing cone "+str(offset))
	actor.global_position=original_position;actor.hp=actor.max_hp
	for unit in [units[1],units[2]]:
		unit._locked_direction=Vector2.RIGHT
		var before:=get_tree().get_nodes_in_group("room_projectiles")
		unit.shoot();var added:Array=[]
		for node in get_tree().get_nodes_in_group("room_projectiles"):
			if node not in before:added.append(node)
		check(added.size()==1,"each ranged release emits one projectile")
		if added.size()==1:
			var bullet:RoomProjectile=added[0]
			check(bullet.hostile_fx==str(unit.kind) and not bullet._weapon_frames.is_empty(),"projectile appearance matches weapon")
			check(bullet.hostile_tracking==(unit.kind==&"goblin_mage"),"javelin straight, magic follows existing limited tracking")
			check(is_equal_approx(bullet.damage,unit.attack_damage()),"attack multiplier applied once")
			bullet.queue_free()
	for extent:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(800,1280)]:
		get_window().size=extent;await frames(5)
		for unit in units:
			var sprite:=unit.visual as AnimatedSprite2D
			check(sprite!=null and sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and unit.body_radius()==12,"pixel filter and gameplay collision "+str(extent))
			for action:StringName in [&"idle",&"walk",&"windup",&"attack",&"hurt",&"death"]:
				sprite.play(action);sprite.pause();sprite.frame=3;PixelEnemyArt.align(sprite,unit.kind,unit.body_size)
				var foot:=sprite.position+Vector2(0,52)*sprite.scale
				check(is_equal_approx(foot.y,unit.body_size.y*.5),"stable foot through all actions");await frames(1)
	# Resolve the static async helper after autoload initialization, avoiding
	# a cold-compiled dependency cycle in this broad test scene.
	var warmup:Script=load("res://src/visual/combat_art_warmup.gd")
	var warmed:bool=await warmup.prepare(get_tree(),"",Callable(),Array(GOBLINS));check(warmed,"new roster goes through existing prewarm")
	ForestUnitArt.clear();MonsterCodex._icons.clear();warmup.clear()
	for kind in GOBLINS:check(ForestUnitArt.frames(kind)!=null and not ForestUnitArt.metadata(kind).is_empty(),"goblin cache cold reload "+str(kind))
	for unit in units:unit.queue_free()
	await frames()
func restore_checks()->void:
	var runtime:=main.expedition
	for kind in RETIRED:
		var unit:=RoomEnemy.new()
		var fields:={"kind":str(kind),"hp":17.0,"max_hp":38.0,"base_hp":38.0,"damage":18.0,"base_damage":18.0,"move_speed":74.0,"base_speed":74.0,"_damage_scale":1.0,"_hp_scale":1.0,"_speed_scale":1.0,"balance_revision":4,"combat_balance_revision":25,"reward_uid":"legacy:receipt","_rush":.2}
		runtime._apply_fields(unit,fields);runtime._apply_fields(unit,fields)
		check(unit.kind==EnemyCombatPolicy.active_kind(kind) and unit.hp==17 and unit.max_hp==38 and unit.reward_uid=="legacy:receipt" and unit._rush==0,"old snapshot conversion preserves wounds/reward receipt and is repeatable")
		unit.free()
		var source:=spawn(EnemyCombatPolicy.active_kind(kind));source.hp=17;source.reward_uid="legacy:live_receipt"
		var record:Dictionary=JSON.parse_string(JSON.stringify(runtime._node_record(source)))
		record.fields.kind={"$name":str(kind)};record.fields.display_name="retired";record.fields._rush=.2
		source.free()
		var restored:=runtime._restore_room_node(record) as RoomEnemy;restored.set_physics_process(false)
		check(restored.kind==EnemyCombatPolicy.active_kind(kind) and restored.hp==17 and restored.reward_uid=="legacy:live_receipt" and restored._rush==0,"old room record restores live replacement without healing or changing receipt")
		check(restored.display_name==str(EnemyCombatPolicy.NEW_DATA[restored.kind].name) and (restored.visual as AnimatedSprite2D).sprite_frames==ForestUnitArt.frames(restored.kind),"restored model/name match the new species")
		restored.queue_free()
	for kind in GOBLINS:
		var unit:=spawn(kind);var before:=runtime._fields(unit);runtime._apply_fields(unit,before)
		check(unit.kind==kind and unit.hp>0 and unit.body_radius()==12,"new species snapshot roundtrip")
		unit.queue_free()
	await frames()
