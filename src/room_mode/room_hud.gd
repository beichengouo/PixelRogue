class_name RoomHud
extends Hud
var graph:RoomGraph
var room_map:RoomMinimap
var weather:WeatherState
var world_clock:RoomWorldClock
var _portrait:TextureRect
var _hero_panel:Panel
var _portrait_frame:PanelContainer
var _portrait_id:StringName=&""
var _time_column:VBoxContainer
var _world_time_text:Label
var _last_world_minute:=-1
var _last_layout_area:=Rect2()
func _ready()->void:
	super._ready()
	_minimap.hide();_hint.hide()
	_top_backdrop.hide()
	_wave_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	_wave_text.add_theme_font_size_override("font_size",16);_wave_text.add_theme_constant_override("outline_size",2)
	_wave_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_status_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	_time_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	_wave_text.max_lines_visible=2;_wave_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_status_text.max_lines_visible=2
	_time_column=UiFactory.vbox(1);_time_column.name="JourneyAndWorldTime";_time_column.mouse_filter=Control.MOUSE_FILTER_IGNORE;_hud_root.add_child(_time_column)
	_time_text.reparent(_time_column)
	_world_time_text=_label("",14,Color("cad9e8"));_world_time_text.name="WorldTimeDigits";_world_time_text.mouse_filter=Control.MOUSE_FILTER_IGNORE;_world_time_text.tooltip_text="世界时刻，沿用本次出征昼夜进度";_time_column.add_child(_world_time_text)
	_hero_panel=Panel.new();_hero_panel.name="HeroStatusGroup";_hero_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var plate:=StyleBoxFlat.new();plate.bg_color=Color(.045,.065,.10,.78);plate.border_color=Color(.64,.62,.51,.45);plate.set_border_width_all(1);plate.set_corner_radius_all(8)
	_hero_panel.add_theme_stylebox_override("panel",plate);_hud_root.add_child(_hero_panel);_hud_root.move_child(_hero_panel,0)
	_portrait_frame=PanelContainer.new();_portrait_frame.name="HeroPortraitFrame";_portrait_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame:=StyleBoxFlat.new();frame.bg_color=Color("233044");frame.border_color=Color("9b947a");frame.set_border_width_all(1);frame.set_corner_radius_all(6);frame.set_content_margin_all(3)
	_portrait_frame.add_theme_stylebox_override("panel",frame);_hud_root.add_child(_portrait_frame)
	_portrait=TextureRect.new();_portrait.name="HeroChibiPortrait";_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;_portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;_portrait_frame.add_child(_portrait);_refresh_portrait()
	_resources_row.reparent(_hud_root);_resources_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Remove the old vertical stack after preserving its live value labels.
	var old_stack:=_vitals.get_child(0);var meters:=Control.new();meters.mouse_filter=Control.MOUSE_FILTER_IGNORE;_vitals.add_child(meters)
	for control:Control in [_hp_bar,_mp_bar,_exp_bar,_hp_text,_mp_text]:control.reparent(meters)
	old_stack.queue_free()
	for bar:StatBar in [_hp_bar,_mp_bar,_exp_bar]:bar.custom_minimum_size=Vector2.ZERO;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_hp_bar.position=Vector2.ZERO;_hp_bar.size=Vector2(230,28)
	_mp_bar.position=Vector2(0,34);_mp_bar.size=Vector2(230,22)
	_exp_bar.position=Vector2(0,62);_exp_bar.size=Vector2(230,10)
	var xp_amount:=(_exp_bar as PlayerStatBar)._amount_label
	xp_amount.reparent(_resources_row);xp_amount.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);xp_amount.size_flags_horizontal=Control.SIZE_EXPAND_FILL;xp_amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	xp_amount.add_theme_color_override("font_color",Color("b5b7b1"));xp_amount.tooltip_text="经验";xp_amount.mouse_filter=Control.MOUSE_FILTER_IGNORE
	xp_amount.clip_text=true;xp_amount.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;xp_amount.custom_minimum_size.x=72
	_dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dock.offset_left=-250;_dock.offset_right=250;_dock.offset_top=-108;_dock.offset_bottom=-16
	_dock.scale=Vector2.ONE
	room_map=RoomMinimap.new();room_map.graph=graph;add_child(room_map)
	get_viewport().size_changed.connect(_layout_combat_hud);_layout_combat_hud()
func _layout_combat_hud()->void:
	var area:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
	if area==_last_layout_area:return
	_last_layout_area=area
	var map_size:=Vector2(160,160)
	if area.size.x<1000:map_size=Vector2.ONE*(200.0*2.0/3.0)
	room_map.position=Vector2(area.end.x-map_size.x-18,area.position.y+14);room_map.size=map_size;room_map.queue_redraw()
	_hero_panel.position=area.position+Vector2(12,12);_hero_panel.size=Vector2(342,116)
	_resources_row.position=area.position+Vector2(20,96);_resources_row.size=Vector2(326,28)
	_vitals.position=area.position+Vector2(100,20);_vitals.size=Vector2(230,72)
	_player_statuses.position=area.position+Vector2(16,136)
	var wave:=_wave_text.get_parent() as Control
	wave.set_anchors_preset(Control.PRESET_TOP_LEFT);wave.position=area.position+Vector2(356,18);wave.size=Vector2(maxf(100,area.size.x-392-map_size.x),80)
	_portrait_frame.position=area.position+Vector2(20,20);_portrait_frame.size=Vector2(72,72)
	_time_column.position=Vector2(room_map.position.x,room_map.position.y+map_size.y+8);_time_column.size=Vector2(map_size.x,44)
	if MobileControls.enabled():
		_dock.hide();_contract_text.hide();_prompt.offset_top=-370;_prompt.offset_bottom=-320;_acquired.offset_top=-325;_acquired.offset_bottom=-280
func bind_minimap(_level:Level,_player:Node2D)->void:pass
func _process(dt:float)->void:
	super._process(dt)
	var wave:=_wave_text.get_parent() as Control
	_layout_combat_hud()
	room_map.queue_redraw()
	var boss:Variant=director.boss if is_instance_valid(director) else null
	var boss_visible:bool=is_instance_valid(boss) and not boss.is_queued_for_deletion() and not boss._dead
	wave.visible=not boss_visible
	if _portrait_id!=Characters.current_id():_refresh_portrait()
	if world_clock!=null and floori(world_clock.minutes)!=_last_world_minute:
		_last_world_minute=floori(world_clock.minutes);_world_time_text.text=world_clock.time_label()
	var caption:="第 %d 场 · 已清 %d 房" % [maxi(1,GameState.wave),graph.cleared_count]
	var current:Dictionary=graph.rooms.get(graph.current,{})
	var shadow_room:=SpecialRoomController.is_shadow_room(current)
	var kind:=str(current.get("kind","spawn"))
	if kind in ["shop","tavern","reward","game","event"]:caption=RoomGraph.title(kind)+" · 安全休整"
	elif kind in ["elite","boss_rush","altar","trial"]:caption=RoomGraph.title(kind)+" · 第 %d 场"%maxi(1,GameState.wave)
	if graph.staged:caption="第%d阶段 · %s · 已清%d房"%[graph.stage_index,RoomGraph.title(kind),graph.cleared_count]
	if shadow_room:caption="风铃追影"
	if weather!=null:caption+=" · "+str(RoomWeatherVisual.NAMES.get(weather.kind,"晴夜"))
	caption+=" · "+RunDifficulty.title(GameState.difficulty)
	if _wave_text.text!=caption:_wave_text.text=caption
	if director!=null and director.phase==WaveDirector.Phase.REST:
		_status_text.text=director.phase_title()
		if kind in ["shop","tavern"]:
			_status_text.text=("靠近商铺选购补给" if kind=="shop" else "靠近酒馆雇佣同行者")+" · "+UIFlow.hint(&"interact")+" 交互"
		elif kind=="game":
			if shadow_room:
				var chase:Dictionary=current.delta.get("special",{}).get("chase",{})
				_status_text.text=SpecialRoomController.chase_hint(chase)
			else:_status_text.text="靠近装置 · %s 交互 · 每台装置本房限用一次"%UIFlow.hint(&"interact")
		elif kind=="reward":_status_text.text="星赐宝箱将逐个降临 · %s 开启"%UIFlow.hint(&"interact")
		elif kind=="event":_status_text.text="靠近遗留物 · %s 继续异闻"%UIFlow.hint(&"interact") if not graph.rooms[graph.current].rewarded else "异闻已记录 · 房门已开"
	_forecast.hide()

func _refresh_portrait()->void:
	_portrait_id=Characters.current_id()
	_portrait.texture=load("res://assets/hud_v24/avatar_%s.png"%str(_portrait_id)) as Texture2D
	_portrait.tooltip_text=Characters.current_name()
