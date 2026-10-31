extends Node
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _ready()->void:call_deferred("run")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").begins_with("E:/CodexWorkspace/PixelRogue/"):get_tree().quit(2);return
	var legacy_warning:=BossWarning.new()
	check(legacy_warning.tint==Color("ff454f"),"legacy boss attack warning is red")
	legacy_warning.free()
	var attack_warning:=BossPatternWarning.create(self,null,{"at":Vector2.ZERO},.5,Color.BLUE)
	check(attack_warning.tint==Color("ff454f"),"boss attack warning ignores faction tint")
	attack_warning.queue_free()
	var safe_warning:=BossPatternWarning.create(self,null,{"at":Vector2.ZERO,"safe_corridor":true},.5,Color.BLUE)
	check(safe_warning.tint==Color("85ebbd"),"safe corridor remains green")
	safe_warning.queue_free()
	var legacy_stages:Dictionary={"king":["cast","impact"],"mage":["cast","construct","impact"],"tide":["cast","construct","impact"],"sephra":["cast","impact"],"verena":["cast","impact"],"nameless":["cast","impact"]}
	for family:String in legacy_stages:
		for stage:String in legacy_stages[family]:
			check(HostileAttackFX.frames(family,stage).size()==4,"remaining native boss FX "+family+"/"+stage)
	for id:String in HostileAttackFX.VECTOR_AREA_BOSSES:
		for stage:String in HostileAttackFX.VECTOR_BOSS_STAGES:
			var stem:=id+"_"+stage
			var source:="res://art_src/boss_fx_v40/"+stem+".svg"
			var svg:=FileAccess.get_file_as_string(source)
			check(svg.contains("id=\"pulse_core\"") or svg.contains("id=\"energy_body\""),"editable layered SVG "+stem)
			check(svg.contains("id=\"boss_glyphs\"") or svg.contains("id=\"boss_signature\""),"boss-specific paths "+stem)
			var frame:=Image.new()
			check(frame.load_svg_from_string(svg)==OK and frame.get_size()==Vector2i(1024,1024),"SVG native preview size "+stem)
			var preview_texture:=load("res://art_src/boss_fx_v40/"+stem+"_preview_1024.png") as Texture2D
			var preview:=preview_texture.get_image() if preview_texture!=null else null
			check(preview!=null and preview.get_size()==Vector2i(1024,1024) and preview.get_used_rect().size.x>500,"1024px preview content "+stem)
			var frames:=HostileAttackFX.frames(id,stage)
			check(frames.size()==4 and frames[0].get_width()==1024,"runtime four-frame atlas "+stem)
			var node:=HostileAttackFX.pulse(self,Vector2.ZERO,id,stage,240,.4)
			check(is_instance_valid(node) and node.sprite.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"runtime smooth vector "+stem)
			if is_instance_valid(node):node.queue_free()
	AudioManager.shutdown()
	await get_tree().process_frame
	print("BOSS_FX_VECTOR_V40 checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
