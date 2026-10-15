extends CanvasLayer
## The passing goddess conceals scene work at the opaque starfield midpoint.
signal covered
signal finished
var busy := false
var _root: Control
var _ink: GoddessPass
var _title: Label
var _tween: Tween
var _epoch := 0
var _progress_bar: ProgressBar
var _request_owner: WeakRef
var _owner_cleanup: Callable
const BOOT_DURATION := 3.0
const BOOT_CAST := ["goddess", "merchant", "tavern", "hero", "xixifu", "ilyua"]
var boot_played := false
var _boot_active := false
var _boot_order: Array = []
var _boot_index := -1

func _ready() -> void:
	if "--room-editor" in OS.get_cmdline_user_args():return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.clip_contents = true
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_ink = GoddessPass.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ink)
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = Label.new()
	_title.add_theme_font_override("font", GameFonts.get_font("title"))
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color("fff3d4"))
	_title.add_theme_color_override("font_outline_color", Color("101932"))
	_title.add_theme_constant_override("outline_size", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)
	_root.resized.connect(_layout_title)
	_layout_title()
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_progress_bar.offset_left = -240
	_progress_bar.offset_right = 240
	_progress_bar.offset_top = -42
	_progress_bar.offset_bottom = -34
	_root.add_child(_progress_bar)
	_progress_bar.hide()
	_root.hide()

func _layout_title() -> void:
	_title.position = Vector2(24, _root.size.y * 0.88)
	_title.size = Vector2(maxf(0, _root.size.x - 48), _root.size.y * 0.08)

func cover(caption := "新的旅途", effect := "goddess", request_owner: Node = null) -> bool:
	if busy: return false
	_epoch += 1
	var ticket := _epoch
	if request_owner != null:
		_request_owner = weakref(request_owner)
		_owner_cleanup = _on_owner_exit.bind(ticket)
		request_owner.tree_exiting.connect(_owner_cleanup, CONNECT_ONE_SHOT)
	busy = true
	_root.show()
	_title.text = caption
	_title.modulate.a = 0
	_progress_bar.hide()
	_ink.configure(effect)
	_ink.boot_mode = false
	_ink.manual_clock = false
	_ink.reduced = ComicMotion.reduced()
	_ink.exiting = false
	_ink.looping = false
	_ink.completed_passes = 0
	_ink.age = 0
	_ink.set_progress(0)
	UIFlow.push_screen(self)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	_tween.tween_method(_ink.set_progress, 0.0, 1.0, 0.10 if _ink.reduced else 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.10 if _ink.reduced else 0.20).set_delay(0.0 if _ink.reduced else 0.38)
	if not await _wait_motion(ticket): return false
	# Keep the original pass moving while the covered scene is prepared.
	_ink.looping = not _ink.reduced
	covered.emit()
	return true

func play_boot_sequence(caption := "正在准备菜单与旅途资源…", request_owner: Node = null) -> bool:
	if busy or boot_played: return false
	boot_played = true
	_epoch += 1
	var ticket := _epoch
	if request_owner != null:
		_request_owner = weakref(request_owner)
		_owner_cleanup = _on_owner_exit.bind(ticket)
		request_owner.tree_exiting.connect(_owner_cleanup, CONNECT_ONE_SHOT)
	busy = true
	_boot_active = true
	_root.show()
	_title.text = caption
	_title.modulate.a = 1
	_progress_bar.hide()
	_ink.reduced = ComicMotion.reduced()
	_ink.boot_mode = true
	_ink.manual_clock = true
	_ink.exiting = false
	_ink.looping = false
	_ink.completed_passes = 0
	_boot_order = BOOT_CAST.duplicate()
	# Cosmetic randomness is independent of run/loot RNG.
	var random := RandomNumberGenerator.new();random.randomize()
	for index in range(_boot_order.size()-1,0,-1):
		var other := random.randi_range(0,index)
		var previous:Variant = _boot_order[index]
		_boot_order[index] = _boot_order[other];_boot_order[other] = previous
	_boot_order.resize(3)
	UIFlow.push_screen(self)
	_boot_index = 0
	_ink.configure(str(_boot_order[0]))
	_ink.age = 0.0
	_ink.set_progress(1.0)
	# Prepare the menu immediately, then time all three passes from its first frame.
	await get_tree().process_frame
	if ticket != _epoch: return false
	var started := Time.get_ticks_usec()
	while ticket == _epoch:
		var elapsed := (Time.get_ticks_usec()-started)/1000000.0
		if elapsed >= BOOT_DURATION: break
		var index := mini(2,int(elapsed/(BOOT_DURATION/3)))
		if index != _boot_index:
			_boot_index = index
			_ink.configure(str(_boot_order[index]))
		_ink.age = elapsed-index*(BOOT_DURATION/3)
		_ink.set_progress(1.0)
		await get_tree().process_frame
	if ticket != _epoch: return false
	# Keep the menu covered until the real owner has had a chance to prepare it.
	_ink.exiting = true
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	_tween.tween_property(_title,"modulate:a",0.0,0.10)
	_tween.tween_method(_ink.set_progress,1.0,0.0,0.10)
	if not await _wait_motion(ticket): return false
	cancel()
	finished.emit()
	return true

func set_loading_progress(value: float, caption: String) -> void:
	if not busy: return
	_title.text = caption
	_progress_bar.visible = value >= 0.0
	if value >= 0.0: _progress_bar.value = clampf(value * 100.0, 0.0, 100.0)

func _wait_motion(ticket: int) -> bool:
	# Killing a Tween never emits finished; cancellable polling releases every waiter.
	while ticket == _epoch and _tween != null and _tween.is_running():
		await get_tree().process_frame
	return ticket == _epoch and busy

func uncover() -> void:
	if not busy: return
	var ticket := _epoch
	_ink.looping = false
	# Let the current pass finish before revealing the prepared scene.
	while ticket == _epoch and not _ink.reduced and _ink.age < 1.08:
		await get_tree().process_frame
	if ticket != _epoch: return
	_ink.exiting = true
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	_tween.tween_property(_title, "modulate:a", 0.0, 0.10)
	_tween.tween_property(_progress_bar, "modulate:a", 0.0, 0.10)
	_tween.tween_method(_ink.set_progress, 1.0, 0.0, 0.10 if _ink.reduced else 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await _wait_motion(ticket): return
	cancel()
	finished.emit()

func cancel() -> void:
	_epoch += 1
	if _request_owner != null:
		var owner: Variant = _request_owner.get_ref()
		if is_instance_valid(owner) and owner.tree_exiting.is_connected(_owner_cleanup): owner.tree_exiting.disconnect(_owner_cleanup)
	_request_owner = null
	_owner_cleanup = Callable()
	if _tween != null and _tween.is_valid(): _tween.kill()
	_tween = null
	busy = false
	_boot_active = false
	if _root != null: _root.hide()
	if _ink != null: _ink.set_progress(0.0)
	if _ink != null:
		_ink.boot_mode = false
		_ink.manual_clock = false
		_ink.looping = false
		_ink.set_process(false)
	if _progress_bar != null: _progress_bar.modulate.a = 1.0
	UIFlow.pop_screen(self)

func _on_owner_exit(ticket: int) -> void:
	if ticket == _epoch: cancel()

func _exit_tree() -> void:
	cancel()

func _input(event: InputEvent) -> void:
	if busy and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()

class GoddessPass extends Control:
	const SILHOUETTE := "res://assets/ui_art/transitions/goddess_profile_v1.png"
	var effect := "goddess"
	var tint := Color("f6cb84")
	var progress := 0.0
	var reduced := false
	var exiting := false
	var age := 0.0
	var boot_mode := false
	var manual_clock := false
	var looping := false
	var completed_passes := 0
	var goddess: TextureRect
	var _sky: GradientTexture2D

	func _ready() -> void:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color("223358"), Color("111a35"), Color("070b1c")])
		_sky = GradientTexture2D.new()
		_sky.gradient = gradient
		_sky.fill = GradientTexture2D.FILL_RADIAL
		_sky.fill_from = Vector2(0.5, 0.4)
		_sky.fill_to = Vector2(1.0, 1.0)
		_sky.width = 256
		_sky.height = 256
		goddess = TextureRect.new()
		goddess.texture = load(SILHOUETTE)
		goddess.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		goddess.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		goddess.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		goddess.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var silhouette_shader := Shader.new()
		silhouette_shader.code = "shader_type canvas_item; uniform vec4 silhouette_color:source_color=vec4(1.0,0.85,0.55,1.0); uniform float motion_time=0.0; uniform float sway=1.0; varying vec4 tint; void vertex(){ tint=COLOR; VERTEX.x += sin(motion_time*5.0+UV.y*9.0)*2.5*sway*smoothstep(0.35,1.0,UV.y); } void fragment(){ float mask=smoothstep(0.55,0.85,texture(TEXTURE,UV).a); COLOR=vec4(silhouette_color.rgb*tint.rgb,tint.a*mask); }"
		var silhouette_material := ShaderMaterial.new()
		silhouette_material.shader = silhouette_shader
		goddess.material = silhouette_material
		add_child(goddess)
		resized.connect(_sync_motion)
		set_process(false)
		_sync_motion()

	func configure(kind: String) -> void:
		effect = kind if kind in ["goddess", "restart", "continue", "return", "chapter", "merchant", "tavern", "boss", "hero", "xixifu", "ilyua"] else "goddess"
		var path := SILHOUETTE
		tint = Color("f6cb84")
		match effect:
			"hero":
				path = HolySkills.ROOT+"profile_v2.png"
				tint = Color("f6cb84")
			"xixifu":
				path = "res://assets/ui_art/transitions/xixifu_profile_v1.png"
				if not ResourceLoader.exists(path):path = str(Characters.DATA[&"xixifu"].portrait)
				tint = Color("f6cb84")
			"ilyua":
				path = "res://assets/characters/ilyua/transition.png"
				if not ResourceLoader.exists(path):path = str(Characters.DATA[&"ilyua"].portrait)
				tint = Color("f6cb84")
			"merchant":
				path = "res://assets/round5/transitions/merchant.png"
				tint = Color("efcb7b")
			"tavern":
				path = "res://assets/round5/transitions/tavern.png"
				tint = Color("eba77c")
			"boss":
				path = "res://assets/ui_art/transitions/goddess_profile_v1.png"
				tint = Color("d87680")
			"restart":
				path = HolySkills.ROOT+"profile_v2.png" if Characters.current_id()==&"sylphiette" else Characters.portrait_path("determined")
				tint = Color("f4ba97")
			"continue":
				path = HolySkills.ROOT+"profile_v2.png" if Characters.current_id()==&"sylphiette" else Characters.portrait_path("playful")
				tint = Color("acd9f5")
			"return":
				path = "res://assets/characters/dialogue/goddess_welcome_pose_v1.png"
				tint = Color("d4b8fa")
			"chapter":
				path = "res://assets/characters/dialogue/goddess_regret_pose_v1.png"
		if not ResourceLoader.exists(path): path = SILHOUETTE
		goddess.texture = load(path)
		(goddess.material as ShaderMaterial).set_shader_parameter("silhouette_color", tint)

	func set_progress(value: float) -> void:
		progress = value
		set_process(not manual_clock and not reduced and (progress > 0 or not exiting))
		_sync_motion()

	func _sync_motion() -> void:
		if goddess == null or goddess.texture == null: return
		var height := size.y * (0.85 if boot_mode else 0.94)
		var width := height * goddess.texture.get_width() / float(goddess.texture.get_height())
		goddess.size = Vector2(width, height)
		(goddess.material as ShaderMaterial).set_shader_parameter("motion_time", age)
		(goddess.material as ShaderMaterial).set_shader_parameter("sway", 0.0 if reduced else 1.0)
		var center := (size.x - width) * 0.5
		var x := center
		if not reduced:
			x = lerpf(-width, size.x + width * 0.1, clampf(age / (1.0 if boot_mode else 1.2), 0.0, 1.0))
		var lift := 0.0
		if not reduced:
			if effect == "restart": lift = sin(clampf(age / 1.2, 0, 1) * PI) * -size.y * 0.055
			elif effect == "continue": lift = sin(age * 3.0) * size.y * 0.018
			elif effect == "return": lift = cos(age * 2.4) * 3.0
		goddess.position = Vector2(x, size.y * 0.02 + lift)
		goddess.modulate = Color(1.0, 0.93, 0.78, progress if reduced else minf(1.0, progress * 5.0))
		if boot_mode and reduced:
			goddess.modulate.a = progress*smoothstep(0.0,.18,age)*(1-smoothstep(.82,1.0,age))
		queue_redraw()

	func _process(delta: float) -> void:
		age += delta
		if looping and age >= 1.2:
			age = fposmod(age, 1.2)
			completed_passes += 1
		_sync_motion()

	func _draw() -> void:
		if progress <= 0 or _sky == null or goddess == null: return
		# Every gradient stop is opaque; replacement is safe at progress=1.
		var opacity := smoothstep(0.0, 1.0, progress)
		draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, opacity))
		var clock := 0.0 if reduced else age
		for i in 64:
			var pos := Vector2(fposmod(float(i)*0.6180339, 1.0)*size.x, fposmod(float(i)*0.4142136+0.13, 1.0)*size.y)
			var pulse := (0.55+sin(clock*2.2+float(i))*0.22)*opacity
			var radius := 2.6 if i % 7 == 0 else 1.2
			var tint := Color(0.96, 0.83, 0.57, pulse)
			draw_line(pos-Vector2(radius,0), pos+Vector2(radius,0), tint, 1, true)
			draw_line(pos-Vector2(0,radius*1.5), pos+Vector2(0,radius*1.5), tint, 1, true)
		if reduced or age > 1.65: return
		var lead := goddess.position.x + goddess.size.x * 0.58
		for i in 22:
			var behind := 40.0 + float(i)*18.0
			var x := lead-behind
			var y := size.y*(0.32+float(i%5)*0.09)+sin(clock*3+float(i))*12
			var tint := Color(0.99, 0.78, 0.40, opacity*(1.0-float(i)/22.0)*0.5)
			draw_line(Vector2(x-14,y+2), Vector2(x,y), tint, 2, true)
			draw_circle(Vector2(x,y), 1.8, tint)
		if effect == "merchant":
			for i in 8:
				var p := Vector2(lead-40-i*35, size.y*(0.30+fposmod(i*0.13,0.5)))
				draw_arc(p, 7, 0, TAU, 16, Color(tint, opacity*0.55), 2, true)
		elif effect == "tavern":
			for i in 6:
				var p := Vector2(lead-80-i*48, size.y*(0.3+fposmod(i*0.21,0.4)))
				draw_circle(p, 12, Color(tint, opacity*0.13))
		elif effect == "boss":
			for i in 5:
				var p := Vector2(lead-i*65,size.y*(0.15+i*0.13))
				draw_polyline(PackedVector2Array([p,p+Vector2(-48,36),p+Vector2(-25,66),p+Vector2(-80,96)]), Color(tint,opacity*0.4),2,true)
		elif effect == "restart":
			for i in 5:
				var y := size.y * (0.25 + i * 0.13)
				draw_line(Vector2(lead-360,y+60), Vector2(lead+70,y-60), Color(tint, opacity * 0.16), 2, true)
		elif effect == "continue":
			for i in 3:
				draw_arc(Vector2(lead,size.y*0.5), size.y*(0.20+i*0.08), PI*0.4, PI*1.5, 48, Color(tint,opacity*0.20), 1.5, true)
		elif effect in ["return", "chapter"]:
			for i in 8:
				var p := Vector2(lead-80-i*32, size.y*(0.23+fposmod(i*0.17,0.6)))
				draw_circle(p, 2.5, Color(tint, opacity*(1-i/8.0)*0.5))
		var halo := Vector2(lead, size.y*0.22)
		var radius := size.y*0.15
		draw_arc(halo, radius, clock*0.2, TAU+clock*0.2, 80, Color(0.88,0.71,0.43,opacity*0.22), 1.5, true)
		draw_arc(halo, radius*1.10, 0.4+clock*0.1, 2.6+clock*0.1, 40, Color(0.99,0.82,0.48,opacity*0.35), 2, true)
