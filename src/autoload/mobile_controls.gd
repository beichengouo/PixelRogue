extends CanvasLayer
## Finger ownership is independent of mouse emulation used by ordinary menus.
const PHYSICS_ACTIONS := ["dash", "skill_1", "skill_2", "skill_3", "ultimate", "potion_1", "potion_2", "potion_3"]
const LABELS := {"pause_menu":"暂停", "room_map":"地图", "talents":"天赋", "inventory":"背包", "call_goddess":"撤离", "interact":"交互", "dash":"闪避", "skill_1":"技能一", "skill_2":"技能二", "skill_3":"技能三", "ultimate":"大招", "potion_1":"药剂一", "potion_2":"药剂二", "potion_3":"药剂三", "ui_cancel":"返回", "ui_accept":"确认"}
var move_radius:=104.0
var aim_radius:=104.0
var move_fixed:=false
var aim_fixed:=false
var move_vector := Vector2.ZERO
var aim_vector := Vector2.ZERO
var move_finger := -1
var aim_finger := -1
var move_center := Vector2.ZERO
var aim_center := Vector2.ZERO
var background := false
var _actor: WeakRef
var _surface: TouchSurface
var _buttons: Dictionary = {}
var _fingers: Dictionary = {}
var _release_after: Dictionary = {}
var _live := false
var _mode := ""
var _safe := Rect2()
var _last_safe := Rect2()
var _previous_fps := 60
var _previous_mute := false
var _icons:Dictionary = {}

func enabled() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or "--mobile-test" in OS.get_cmdline_user_args()

func _ready() -> void:
	if not enabled():set_process(false);set_process_input(false);return
	layer=18;process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit=false
	# GUI clicks remain emulated; gameplay consumes ScreenTouch before GUI dispatch.
	Input.emulate_mouse_from_touch=true
	_surface=TouchSurface.new();_surface.owner_controls=self;_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(_surface)
	UIFlow.stack_changed.connect(reset)
	Engine.max_fps=int(SaveService.data.get("mobile_fps",60))
	_apply_first_mobile_defaults()
	_process(0)

func _apply_first_mobile_defaults() -> void:
	# Do not change a returning player's chosen quality or combat mode.
	if bool(SaveService.data.get("mobile_initialized",false)):return
	SaveService.data.mobile_initialized=true
	SaveService.data.environment_quality=1
	SaveService.save_data()

func bind_actor(actor: Node2D) -> void:
	if not enabled():return
	reset();_actor=weakref(actor)

func actor() -> RoomPlayer:
	return _actor.get_ref() as RoomPlayer if _actor!=null else null

func attacking() -> bool:
	return _live and aim_finger>=0 and aim_vector.length_squared()>.0625

func direction() -> Vector2:
	if not attacking():return Vector2.ZERO
	return RoomInput.quantize(aim_vector) if str(SaveService.data.get("attack_mode","keyboard"))=="keyboard" else aim_vector.normalized()

func pointer_world(player:Node2D) -> Vector2:
	var vector:=direction()
	if vector.is_zero_approx() and player is RoomPlayer:vector=player.aim_direction
	var canvas:=player.get_canvas_transform()
	var origin:=player.get_global_transform_with_canvas().origin
	var screen_direction:=canvas.basis_xform(vector).normalized()
	var area:=safe_rect().grow(-24)
	var distance:=minf(area.size.x,area.size.y)*.32
	if absf(screen_direction.x)>.00001:distance=minf(distance,((area.end.x if screen_direction.x>0 else area.position.x)-origin.x)/screen_direction.x)
	if absf(screen_direction.y)>.00001:distance=minf(distance,((area.end.y if screen_direction.y>0 else area.position.y)-origin.y)/screen_direction.y)
	return canvas.affine_inverse()*(origin+screen_direction*maxf(0,distance))

func safe_rect() -> Rect2:
	var viewport:=get_viewport().get_visible_rect()
	if not OS.has_feature("android") and not OS.has_feature("ios"):return viewport.grow(-16)
	var screen:=DisplayServer.screen_get_size()
	var safe:=DisplayServer.get_display_safe_area()
	if screen.x<=0 or screen.y<=0 or safe.size.x<=0 or safe.size.y<=0:return viewport.grow(-16)
	var factor:=viewport.size/Vector2(screen)
	return Rect2(Vector2(safe.position)*factor,Vector2(safe.size)*factor).intersection(viewport).grow(-12)

func _process(_dt:float) -> void:
	_safe=safe_rect()
	if _safe!=_last_safe:reset();_last_safe=_safe
	var player:=actor()
	var wanted:=is_instance_valid(player) and player.hp>0 and player.is_visible_in_tree() and not player.extraction_controls_locked() and not UIFlow.has_screen() and not get_tree().paused and not TransitionLayer.busy and not background
	var mode:=str(SaveService.data.get("attack_mode","keyboard"))
	if wanted!=_live or mode!=_mode:reset()
	_live=wanted;_mode=mode
	_layout()
	for action:String in _release_after.keys():
		if Engine.get_physics_frames()>int(_release_after[action]):
			Input.action_release(action);_release_after.erase(action)
	_surface.visible=_live or _can_go_back()
	layer=18 if _live else 70
	if _surface.visible:_surface.queue_redraw()

func _can_go_back() -> bool:
	var top:=UIFlow.top_screen()
	return not background and not TransitionLayer.busy and is_instance_valid(top) and not bool(top.get_meta("blocking_screen",false))

func _layout() -> void:
	_buttons.clear()
	if not _live:
		if _can_go_back():_buttons["ui_cancel"]=Rect2(Vector2(_safe.position.x+4,_safe.end.y-62),Vector2(100,58))
		return
	var saved:Dictionary=SaveService.data.get("mobile_layout",{})
	var boxes:=MobileControlLayout.decode(saved,_safe)
	move_radius=float(boxes.move.size.x)*.5;aim_radius=float(boxes.aim.size.x)*.5
	move_fixed=not saved.is_empty();aim_fixed=move_fixed
	if move_finger<0:move_center=boxes.move.get_center()
	if aim_finger<0:aim_center=boxes.aim.get_center()
	for key in boxes:
		if key in ["move","aim"]:continue
		if CampSession.active and key=="call_goddess":continue
		_buttons[key]=boxes[key]

func _input(event:InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch:=event as InputEventScreenTouch
		if touch.pressed and UIFlow.gamepad:UIFlow.gamepad=false;UIFlow.input_device_changed.emit()
		UIFlow.set_pointer_active(true)
		if not touch.pressed:
			if release_finger(touch.index):get_viewport().set_input_as_handled()
			return
		if begin_finger(touch.index,touch.position):get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag:=event as InputEventScreenDrag
		if drag_finger(drag.index,drag.position):get_viewport().set_input_as_handled()
	# Some platforms still emit emulated mouse events for a handled touch.
	elif _live and (event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()

func begin_finger(index:int,point:Vector2) -> bool:
	if UIFlow.has_screen() or get_tree().paused:_live=false;_layout()
	if background or not _safe.has_point(point):return false
	if _live:
		for strip in get_tree().get_nodes_in_group("player_status_strips"):
			if not strip.is_visible_in_tree():continue
			for cell in strip.get_children():
				if cell is Control and cell.get_global_rect().has_point(point):
					var lines:PackedStringArray=cell.tooltip_text.split("\n",true,1)
					show_description(lines[0],lines[1] if lines.size()>1 else lines[0]);return true
	for action:String in _buttons:
		if not _buttons[action].has_point(point):continue
		_fingers[index]=action
		if action in PHYSICS_ACTIONS:
			Input.action_press(action)
			_release_after.erase(action)
		else:_dispatch.call_deferred(action)
		return true
	if not _live:return false
	if move_finger<0 and ((point.distance_to(move_center)<=move_radius) if move_fixed else (point.x<_safe.position.x+_safe.size.x*.42 and point.y>_safe.position.y+_safe.size.y*.36)):
		move_finger=index
		if not move_fixed:move_center=Vector2(clampf(point.x,_safe.position.x+move_radius,_safe.end.x-move_radius),clampf(point.y,_safe.position.y+move_radius,_safe.end.y-move_radius))
		move_vector=((point-move_center)/move_radius).limit_length() if move_fixed else Vector2.ZERO;return true
	if _mode!="auto" and aim_finger<0 and ((point.distance_to(aim_center)<=aim_radius) if aim_fixed else (point.x>_safe.get_center().x and point.y>_safe.position.y+_safe.size.y*.36)):
		aim_finger=index
		if not aim_fixed:aim_center=Vector2(clampf(point.x,_safe.position.x+aim_radius,_safe.end.x-aim_radius),clampf(point.y,_safe.position.y+aim_radius,_safe.end.y-aim_radius))
		aim_vector=((point-aim_center)/aim_radius).limit_length() if aim_fixed else Vector2.ZERO;return true
	return true # World taps do not click hidden menus or start mouse attacks.

func drag_finger(index:int,point:Vector2) -> bool:
	if index==move_finger:
		move_vector=((point-move_center)/move_radius).limit_length();return true
	if index==aim_finger:
		aim_vector=((point-aim_center)/aim_radius).limit_length();return true
	return _fingers.has(index)

func release_finger(index:int) -> bool:
	if index==move_finger:move_finger=-1;move_vector=Vector2.ZERO;return true
	if index==aim_finger:aim_finger=-1;aim_vector=Vector2.ZERO;return true
	if not _fingers.has(index):return false
	var action:String=_fingers[index];_fingers.erase(index)
	if action in PHYSICS_ACTIONS and not _action_owned(action):_release_after[action]=Engine.get_physics_frames()
	return true

func _action_owned(action:String) -> bool:
	return action in _fingers.values()

func _dispatch(action:String) -> void:
	if background or TransitionLayer.busy:return
	if action!="ui_cancel" and (UIFlow.has_screen() or not _live):return
	var event:=InputEventAction.new();event.action=action;event.pressed=true;Input.parse_input_event(event)
	var release:=InputEventAction.new();release.action=action;Input.parse_input_event(release)

func reset() -> void:
	_live=false
	move_finger=-1;aim_finger=-1;move_vector=Vector2.ZERO;aim_vector=Vector2.ZERO
	for action:String in PHYSICS_ACTIONS:Input.action_release(action)
	_fingers.clear();_release_after.clear()

func icon_for(path:String) -> Texture2D:
	if path.is_empty():return null
	if not _icons.has(path):
		var icon:=UiFactory.texture_icon(path,48);_icons[path]=icon.texture;icon.free()
	return _icons[path]

func decorate_number(number:SpinBox) -> void:
	if not enabled():return
	var parent:=number.get_parent();var index:=number.get_index()
	parent.remove_child(number)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12)
	parent.add_child(row);parent.move_child(row,index)
	var decrease:=PixelUi.compact_button("−",24);decrease.custom_minimum_size=Vector2(64,60);row.add_child(decrease)
	number.custom_minimum_size=Vector2(160,60);row.add_child(number)
	number.get_line_edit().virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	var increase:=PixelUi.compact_button("＋",24);increase.custom_minimum_size=Vector2(64,60);row.add_child(increase)
	decrease.pressed.connect(func()->void:number.value-=number.step)
	increase.pressed.connect(func()->void:number.value+=number.step)

func show_description(caption:String,text:String) -> void:
	if not enabled():return
	var notice:=CampNotice.new();notice.title=caption;notice.message=text;get_tree().root.add_child(notice)

func _notification(what:int) -> void:
	if not enabled() or not is_inside_tree():return
	if what==NOTIFICATION_APPLICATION_PAUSED:set_background(true)
	elif what==NOTIFICATION_APPLICATION_RESUMED:set_background(false)
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if TransitionLayer.busy or background:return
		if UIFlow.has_screen():_dispatch.call_deferred("ui_cancel")
		elif _live:_dispatch.call_deferred("pause_menu")

func set_background(value:bool) -> void:
	if background==value:return
	reset()
	if value:
		# Capture synchronously before Android suspends the main loop.
		if GameState.run_active and not CampSession.active and is_instance_valid(GameState.runtime_node):
			if not SaveService.save_run(GameState.snapshot()):push_warning("后台保存未成功，本局仍保留在内存。")
		else:SaveService.save_data()
		_previous_fps=Engine.max_fps;_previous_mute=AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0,true);Engine.max_fps=1
	else:
		AudioServer.set_bus_mute(0,_previous_mute);Engine.max_fps=_previous_fps
	background=value;UIFlow.background_paused=value;UIFlow.refresh()
	if not value and is_instance_valid(actor()) and not UIFlow.has_screen():
		# Returning to combat requires dismissing the existing pause screen.
		_live=true;_dispatch.call_deferred("pause_menu")

class TouchSurface extends Control:
	var owner_controls:Node
	func _draw() -> void:
		var controls:=owner_controls
		if controls._live:
			_draw_stick(controls.move_center,controls.move_vector,"移动",false)
			if controls._mode!="auto":_draw_stick(controls.aim_center,controls.aim_vector,"瞄准连射",true)
			else:_draw_stick(controls.aim_center,Vector2.ZERO,"自动攻击",true)
		for action:String in controls._buttons:
			var rect:Rect2=controls._buttons[action]
			var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.07,.11,.72)
			style.border_color=Color(.72,.86,.81,.65);style.set_border_width_all(2);style.set_corner_radius_all(18)
			if controls._action_owned(action):style.bg_color=Color(.18,.36,.33,.88)
			draw_style_box(style,rect)
			var label:String=controls.LABELS.get(action,action)
			var texture:Texture2D
			var cooling:=0.0
			if action.begins_with("skill_") or action=="ultimate":
				var slot:=3 if action=="ultimate" else int(action.right(1))-1
				var skill:=Skills.get_skill(GameState.skill_for_slot(slot),"rooms")
				var path:=str(skill.get("icon",""))
				texture=controls.icon_for(path)
				label=str(skill.get("name",label))
				cooling=float(GameState.skill_cooldowns[slot])
			elif action.begins_with("potion_"):
				var slot:=int(action.right(1))-1
				var item:Dictionary=GameState.potion_hotbar[slot] if slot<GameState.potion_hotbar.size() else {}
				if not item.is_empty():texture=UiFactory.atlas_texture(ItemDB.icon_texture(item),ItemDB.icon_region(item))
				label="药剂%d"%(slot+1)
			if texture!=null:draw_texture_rect(texture,Rect2(rect.get_center()-Vector2(23,31),Vector2(46,46)),false)
			if cooling>0:
				draw_rect(rect,Color(0,0,0,.55));label="%.1f秒"%cooling
			var font:=GameFonts.get_font();var font_size:=17
			var extent:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
			draw_string(font,Vector2(rect.get_center().x-extent.x*.5,rect.end.y-12 if texture!=null else rect.get_center().y+6),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
	func _draw_stick(center:Vector2,vector:Vector2,label:String,aiming:bool) -> void:
		var radius:float=owner_controls.aim_radius if aiming else owner_controls.move_radius
		draw_circle(center,radius,Color(.02,.06,.09,.28))
		draw_arc(center,radius,0,TAU,64,Color(.68,.86,.78,.55),2,true)
		draw_circle(center+vector*radius*.7,radius*.36,Color(.72,.87,.82,.45))
		var font:=GameFonts.get_font();var extent:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,18)
		draw_string(font,center+Vector2(-extent.x*.5,radius+24),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		if aiming and vector.length()>.25:
			draw_line(center,center+vector.normalized()*radius*.85,Color("f3d19b"),3,true)
