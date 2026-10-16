class_name RoomHud
extends Hud
var graph:RoomGraph
var room_map:RoomMinimap
var weather:WeatherState
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
	_hp_bar.custom_minimum_size.x=180;_mp_bar.custom_minimum_size.x=180
	_resources_row.reparent(_hud_root);_resources_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
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
	_resources_row.position=area.position+Vector2(12,110);_resources_row.size=Vector2(290,26)
	_vitals.position=area.position+Vector2(112,18);_vitals.size=Vector2(200,55)
	_player_statuses.position=area.position+Vector2(12,144)
	var wave:=_wave_text.get_parent() as Control
	wave.set_anchors_preset(Control.PRESET_TOP_LEFT);wave.position=area.position+Vector2(300,14);wave.size=Vector2(maxf(100,area.size.x-330-map_size.x),88)
	if MobileControls.enabled():
		_dock.hide();_contract_text.hide();_prompt.offset_top=-370;_prompt.offset_bottom=-320;_acquired.offset_top=-325;_acquired.offset_bottom=-280
func bind_minimap(_level:Level,_player:Node2D)->void:pass
func _process(dt:float)->void:
	super._process(dt)
	var wave:=_wave_text.get_parent() as Control
	_layout_combat_hud()
	room_map.queue_redraw()
	var boss:Variant=director.boss if is_instance_valid(director) else null
	wave.visible=not (is_instance_valid(boss) and not boss.is_queued_for_deletion() and not boss._dead)
	var caption:="第 %d 场 · 已清 %d 房" % [maxi(1,GameState.wave),graph.cleared_count]
	var current:Dictionary=graph.rooms.get(graph.current,{})
	var shadow_room:=SpecialRoomController.is_shadow_room(current)
	var kind:=str(current.get("kind","spawn"))
	if kind in ["shop","tavern","reward","game","event"]:caption=RoomGraph.title(kind)+" · 安全休整"
	elif kind in ["elite","boss_rush","altar","trial"]:caption=RoomGraph.title(kind)+" · 第 %d 场"%maxi(1,GameState.wave)
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
				_status_text.text="追影已散 · 星赐宝箱即将降临" if bool(chase.get("done",false)) else ("黑影将在 %d 秒后苏醒"%ceili(float(chase.get("prepare",5))) if float(chase.get("prepare",5))>0 else "躲避自己的追影 · 坚持 %d 秒"%ceili(float(chase.get("remaining",30))))
			else:_status_text.text="靠近装置 · %s 交互 · 每台装置本房限用一次"%UIFlow.hint(&"interact")
		elif kind=="reward":_status_text.text="星赐宝箱将逐个降临 · %s 开启"%UIFlow.hint(&"interact")
		elif kind=="event":_status_text.text="靠近遗留物 · %s 继续异闻"%UIFlow.hint(&"interact") if not graph.rooms[graph.current].rewarded else "异闻已记录 · 房门已开"
	_forecast.hide()
