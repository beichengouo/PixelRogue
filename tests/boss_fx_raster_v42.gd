extends "res://tests/inventory_v17.gd"
## Checks the admitted raster atlases through their real battle consumers.
## The optional GL run renders at 2K without saving screenshots or recordings.
const FAMILIES := ["king", "mage", "tide", "sephra", "verena", "nameless"]

func run()->void:
	if not OS.get_user_data_dir().replace("\\", "/").begins_with("E:/CodexWorkspace/PixelRogue/test-userdata/"):
		push_error("V42 requires isolated E: user data")
		get_tree().quit(2)
		return
	if DisplayServer.get_name()!="headless":
		get_window().mode=Window.MODE_WINDOWED
		get_window().size=Vector2i(2560,1440)
		await frames(2)
		check(get_window().size==Vector2i(2560,1440),"2K physical GL window")
		check(get_viewport().get_visible_rect().size==Vector2(1280,720),"2x logical canvas")
	AchievementTracker.set_process(false)
	SaveService.data.reduced_motion=false
	TransitionLayer.boot_played=true
	await begin(&"sylphiette")
	var center:=main.level.bounds().get_center()
	for family:String in FAMILIES:
		var selected:=Array(OS.get_cmdline_user_args()).filter(func(value:String)->bool:return value.begins_with("family="))
		if not selected.is_empty() and not selected.has("family="+family):continue
		var boss:RoomBoss=CityBoss.new() if family in ["sephra","verena","nameless"] else RoomBoss.new()
		boss.configure(StringName(family))
		boss.room=main.level
		boss.setup(actor,main.level,1,1,1)
		boss.fx_root=main.fx_root
		boss.director=main.director
		boss.position=center
		main.enemies_root.add_child(boss)
		boss.set_physics_process(false)
		for stage:String in ["cast","impact","construct"]:
			if stage=="construct" and family not in ["mage","tide"]:continue
			_check_atlas(family,stage)
			if stage=="construct":continue
			var width:float=(96 if family in ["sephra","verena","nameless"] else 88) if stage=="cast" else 60
			var fx:=boss._boss_fx(stage,center,width,1.0)
			check(is_instance_valid(fx),family+"/"+stage+" battle factory")
			if not is_instance_valid(fx):continue
			fx.set_process(false)
			check(fx.sprite.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,family+"/"+stage+" smooth HD")
			check(is_equal_approx(fx.sprite.scale.x*fx.textures[0].get_width(),width),family+"/"+stage+" world size preserved")
			check(fx.sprite.material.get_shader_parameter("clip_arena")==true,family+"/"+stage+" arena clip")
			for index in 4:
				fx.age=float(index)*.25
				fx._process(.001)
				check(fx.sprite.texture==fx.textures[index],family+"/"+stage+" time slot "+str(index))
				await frames(2)
			fx.queue_free()
		var projectile:=BossPatternProjectile.new()
		projectile.room=main.level
		projectile.hostile_fx=family
		projectile.pattern_family=family
		projectile.position=center
		main.fx_root.add_child(projectile)
		projectile.set_physics_process(false)
		var before:=HostileAttackFX.active_count
		projectile._hit_effect(true)
		check(HostileAttackFX.active_count==before+1,family+" real projectile impact")
		var impact:=main.fx_root.get_children().back() as HostileAttackFX
		check(is_instance_valid(impact) and is_equal_approx(impact.sprite.scale.x*impact.textures[0].get_width(),40),family+" real projectile impact stays 40 logical pixels")
		if family in ["mage","tide"]:
			var construct:=boss._spawn_construct("crystal" if family=="mage" else "bud",center+Vector2(64,0),10,false)
			check(is_instance_valid(construct),family+" real construct spawned")
			if is_instance_valid(construct):
				construct.set_physics_process(false)
				check(construct._art.texture==HostileAttackFX.frames(family,"construct")[0],family+" construct uses admitted atlas")
				check(construct._art.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,family+" construct smooth HD")
				check(is_equal_approx(construct._art.scale.x*construct._art.texture.get_width(),48),family+" construct size preserved")
				for index in 5:
					construct._physics_process(0 if index==0 else 1.0/6.0+.00001)
					check(construct._art.texture==HostileAttackFX.frames(family,"construct")[index%4],family+" construct forward loop slot "+str(index))
				construct._die()
		if family in ["verena","nameless"]:
			var fallback:=boss._spawn_construct("page" if family=="verena" else "satellite",center+Vector2(64,0),10,false)
			check(is_instance_valid(fallback),family+" fallback construct spawned")
			if is_instance_valid(fallback):
				fallback.set_physics_process(false)
				check(fallback._art.texture==HostileAttackFX.frames(family,"cast")[0],family+" construct keeps cast fallback")
				check(is_equal_approx(fallback._art.scale.x*fallback._art.texture.get_width(),48),family+" fallback construct remains 48 logical pixels")
				check(fallback._art.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,family+" fallback construct smooth HD")
				fallback.queue_free()
		boss.queue_free()
		await get_tree().create_timer(.6).timeout
	SaveService.data.reduced_motion=true
	var reduced:=HostileAttackFX.pulse(main.fx_root,center,"king","cast",88,1.0)
	if is_instance_valid(reduced):
		reduced.set_process(false)
		for index in [0,1,3]:
			reduced.age=float(index)*.3
			reduced._process(.001)
			check(reduced.sprite.texture==reduced.textures[index],"reduced motion slot "+str(index))
		reduced.queue_free()
	await settle_actor()
	AudioManager.shutdown()
	await frames()
	print("BOSS_FX_RASTER_V42 checks=",checks," failures=",failures," renderer=",DisplayServer.get_name())
	get_tree().quit(1 if failures else 0)

func _check_atlas(family:String,stage:String)->void:
	var values:=HostileAttackFX.frames(family,stage)
	check(values.size()==4,family+"/"+stage+" four frames")
	if values.size()!=4:return
	var atlas:=values[0] as AtlasTexture
	check(atlas!=null and atlas.atlas.resource_path=="res://assets/boss_fx_v42/"+family+"_"+stage+".png",family+"/"+stage+" admitted source")
	if atlas!=null:check(atlas.atlas.get_image().has_mipmaps(),family+"/"+stage+" imported HD mipmaps")
	check(values[0].get_width()>=512,family+"/"+stage+" native resolution")
	for index in 4:
		var tile:=values[index] as AtlasTexture
		check(tile.filter_clip and tile.region==Rect2(index*tile.get_width(),0,tile.get_width(),tile.get_height()),family+"/"+stage+" isolated cell "+str(index))
