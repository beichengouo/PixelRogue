class_name CombatArtWarmup
extends RefCounted
static var _done:Dictionary={}
static func clear()->void:_done.clear()
static func _valid(valid:Callable)->bool:return valid.is_null() or (valid.is_valid() and bool(valid.call()))
static func prepare(tree:SceneTree,boss_id:String="",valid:Callable=Callable(),enemy_kinds:Array=[])->bool:
	if not _valid(valid):return false
	if not _done.has("unit_health"):
		UnitHealthArt.profile("enemy");UnitHealthArt.profile("elite");UnitHealthArt.profile("ally")
		for level in range(1,RoomDirector.MAX_PRESSURE_LEVEL+1):UnitHealthArt.skull(level)
		_done["unit_health"]=true
	if not boss_id.is_empty():
		await BossEntranceArt.warm_async(tree,boss_id)
		if not _valid(valid):return false
		UnitHealthArt.profile(boss_id)
	var inspector:=RoomSceneOcclusion.new();var packs:Array=[]
	var kinds:Array=enemy_kinds.duplicate() if not enemy_kinds.is_empty() else ChapterCatalog.config(GameState.chapter_id).enemies.duplicate()
	if not boss_id.is_empty():
		for kind in BossRoster.get_data(StringName(boss_id)).minions:
			if not kinds.has(str(kind)):kinds.append(str(kind))
	for kind in kinds:packs.append({"key":"enemy:"+str(kind),"kind":str(kind)})
	if Characters.current_id()==&"xixifu":
		for variant:String in SpectralCompanionArt.VARIANTS:packs.append({"key":"contract:"+variant,"variant":variant})
	packs.append({"key":"hero:%s:%s"%[Characters.current_id(),LegendarySets.form_unlocked()],"hero":true})
	if not boss_id.is_empty():
		for stage in range(1,BossPhaseRules.thresholds(StringName(boss_id)).size()):packs.append({"key":"boss:%s:%d"%[boss_id,stage],"boss":boss_id,"stage":stage})
	var started:=Time.get_ticks_usec()
	for pack in packs:
		if _done.has(pack.key):continue
		if not _valid(valid):return false
		# Construct each atlas inside the frame budget, not before the first yield.
		var frames:SpriteFrames
		if pack.has("kind"):frames=PixelEnemyArt.make_frames(StringName(pack.kind))
		elif pack.has("variant"):frames=SpectralCompanionArt.frames(str(pack.variant))
		elif pack.has("boss"):
			frames=BossStageArt.frames(StringName(pack.boss),int(pack.stage))
			BossStageArt.icon(StringName(pack.boss),int(pack.stage))
		else:frames=RoomHeroArt.make_frames()
		for action in frames.get_animation_names():
			for index in frames.get_frame_count(action):
				inspector._painted_bounds(frames.get_frame_texture(action,index))
				if Time.get_ticks_usec()-started>=3000:
					await tree.process_frame;started=Time.get_ticks_usec()
					if not _valid(valid):return false
		_done[pack.key]=true
	var families:Array=[]
	for family in kinds:
		if family in ["flyer","bomber","caster","lantern_toad","dusk_acolyte","goblin_spearman","goblin_mage","glimmer_spider"]:families.append(str(family))
	if not boss_id.is_empty():families.append(boss_id)
	families.append("affix")
	for family in families:
		if _done.has("hostile:"+str(family)):continue
		if not _valid(valid):return false
		for stage in ["cast","flight","impact","area","construct","summon","slash","departure","arrival"]:HostileAttackFX.frames(str(family),stage)
		_done["hostile:"+str(family)]=true
		await tree.process_frame
		if not _valid(valid):return false
	var spells:="spells:"+str(Characters.current_id())
	if not _done.has(spells):
		SizedSkillArt.warm()
		CombatContactFX.bank("contract" if Characters.current_id()==&"xixifu" else "arrow" if Characters.current_id()==&"ilyua" else "holy")
		CombatContactFX.bank("shield")
		if Characters.current_id()==&"sylphiette":HolyFX.warm()
		elif Characters.current_id()==&"ilyua":
			for kind in ["basic","wind_arrow","seed","mark","trap","tree","moon","decoy","arrow_hit"]:IlyuaFX.frames(kind)
		_done[spells]=true
	for effect in ["rune","bone","thorn","amber"]:RoomExpansionRules.field_texture(effect)
	return _valid(valid)
