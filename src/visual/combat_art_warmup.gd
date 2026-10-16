class_name CombatArtWarmup
extends RefCounted
static var _done:Dictionary={}
static func prepare(tree:SceneTree,boss_id:String="",valid:Callable=Callable())->bool:
	var inspector:=RoomSceneOcclusion.new();var packs:Array=[]
	for kind in PixelEnemyArt.KINDS+PixelEnemyArt.NEW_KINDS:
		var key:="enemy:"+str(kind)
		if _done.has(key):continue
		packs.append({"key":key,"frames":PixelEnemyArt.make_frames(kind)})
	if Characters.current_id()==&"xixifu":
		for variant:String in SpectralCompanionArt.VARIANTS:
			if not _done.has("contract:"+variant):packs.append({"key":"contract:"+variant,"frames":SpectralCompanionArt.frames(variant)})
	var hero:="hero:"+str(Characters.current_id())
	if not _done.has(hero):packs.append({"key":hero,"frames":RoomHeroArt.make_frames()})
	if not boss_id.is_empty() and not _done.has("boss:"+boss_id):packs.append({"key":"boss:"+boss_id,"frames":PixelBossArt.make_frames(StringName(boss_id))})
	var started:=Time.get_ticks_usec()
	for pack in packs:
		var frames:SpriteFrames=pack.frames
		for action in frames.get_animation_names():
			for index in frames.get_frame_count(action):
				inspector._painted_bounds(frames.get_frame_texture(action,index))
				if Time.get_ticks_usec()-started>=3000:
					await tree.process_frame;started=Time.get_ticks_usec()
					if not valid.is_null() and (not valid.is_valid() or not bool(valid.call())):return false
		_done[pack.key]=true
	for family in ["flyer","bomber","caster","lantern_toad","dusk_acolyte","bell_snail","glimmer_spider"]+([boss_id] if not boss_id.is_empty() else []):
		if _done.has("hostile:"+str(family)):continue
		for stage in ["cast","flight","impact","area","construct","summon","slash"]:HostileAttackFX.frames(family,stage)
		_done["hostile:"+str(family)]=true
		await tree.process_frame
		if not valid.is_null() and (not valid.is_valid() or not bool(valid.call())):return false
	var spells:="spells:"+str(Characters.current_id())
	if not _done.has(spells):
		if Characters.current_id()==&"sylphiette":HolyFX.warm()
		elif Characters.current_id()==&"ilyua":
			for kind in ["basic","wind_arrow","seed","mark","trap","tree","moon","decoy","arrow_hit"]:IlyuaFX.frames(kind)
		_done[spells]=true
	for effect in ["rune","bone","thorn","amber"]:RoomExpansionRules.field_texture(effect)
	return true
