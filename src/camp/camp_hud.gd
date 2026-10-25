class_name CampHud
extends CanvasLayer
var world:Node
var _vitals:Label
var _damage:Label
var _hint:Label
var _skills:HBoxContainer
var _skill_labels:Array[Label]=[]
var _root:Control
var _player_statuses:PlayerStatusStrip
var _navigation_row:HBoxContainer
var _navigation_text:Label
func _ready()->void:
	layer=5;_root=UiFactory.full_rect();_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_root)
	_vitals=PixelUi.label("",18,Color.WHITE);_vitals.position=Vector2(20,16);_root.add_child(_vitals)
	_player_statuses=PlayerStatusStrip.new();_player_statuses.position=Vector2(20,74);_root.add_child(_player_statuses)
	_damage=PixelUi.label("",17,Color.WHITE);_damage.set_anchors_preset(Control.PRESET_TOP_RIGHT);_damage.position=Vector2(-330,16);_damage.size=Vector2(310,150);_damage.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;_root.add_child(_damage)
	for label in [_vitals,_damage]:label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_color_override("font_outline_color",Color("14211c"));label.add_theme_constant_override("outline_size",5)
	_skills=UiFactory.hbox(12);_skills.set_anchors_preset(Control.PRESET_BOTTOM_LEFT);_skills.position=Vector2(20,-100);_root.add_child(_skills)
	for slot in 4:
		var column:=UiFactory.vbox(3);column.custom_minimum_size=Vector2(82,80);_skills.add_child(column)
		var icon:=TextureRect.new();icon.custom_minimum_size=Vector2(42,42);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(icon)
		var label:=PixelUi.label("",14,Color.WHITE);column.add_child(label);_skill_labels.append(label)
	_hint=PixelUi.label("",16,Color.WHITE);_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT);_hint.position=Vector2(-650,-75);_hint.size=Vector2(630,65);_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;_root.add_child(_hint)
	_hint.add_theme_color_override("font_outline_color",Color("14211c"));_hint.add_theme_constant_override("outline_size",5);_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_navigation_row=UiFactory.hbox(12);_navigation_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);_navigation_row.position=Vector2(-190,-140);_root.add_child(_navigation_row)
	_navigation_text=PixelUi.label("自动寻路中",18,Color("a8deff"));_navigation_text.add_theme_constant_override("outline_size",4);_navigation_row.add_child(_navigation_text)
	_navigation_text.clip_text=true;_navigation_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;_navigation_text.custom_minimum_size.x=100;_navigation_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var stop:=PixelUi.compact_button("停止寻路 ×",18);stop.pressed.connect(func()->void:world.cancel_navigation());_navigation_row.add_child(stop);_navigation_row.hide()
	InteractionSkin.apply_tree(_navigation_row,"camp_navigation")
func _process(_dt:float)->void:
	if not is_instance_valid(world) or not is_instance_valid(world.player):return
	_navigation_row.visible=is_instance_valid(world.camp_navigation) and world.camp_navigation.active
	if _navigation_row.visible:
		_navigation_text.text="自动寻路中 · "+str(world.camp_navigation.title)
		var area:=MobileControls.safe_rect() if MobileControls.enabled() else get_viewport().get_visible_rect()
		_navigation_row.custom_minimum_size.x=minf(340 if MobileControls.enabled() else 460,area.size.x-32)
		_navigation_row.set_anchors_preset(Control.PRESET_TOP_LEFT);_navigation_row.position=Vector2(area.get_center().x-_navigation_row.size.x*.5,area.end.y-145)
	var width:=get_viewport().get_visible_rect().size.x
	_player_statuses.available_width=maxf(44,minf(336,width-40))
	_damage.position=Vector2(-330,maxf(78,_player_statuses.position.y+(_player_statuses.size.y if _player_statuses.visible else 0)+12) if width<900 else 16)
	_hint.position=Vector2(-minf(650,width-20),-175 if width<900 else -75);_hint.size.x=minf(630,width-40)
	_vitals.text="星辉回廊 · %s · 预览 Lv.%d\nHP %d/%d · MP %d/%d · 金库 %d"%[Characters.current_name(),GameState.level,world.player.hp,world.player.max_hp,GameState.mp,GameState.MAX_MP,Outpost.gold()]
	_damage.hide();_skills.hide()
	for slot in 4:
		var id:=GameState.skill_for_slot(slot);var info:=Skills.get_skill(id,"rooms")
		_skill_labels[slot].text="%s · %s\n%s"%[KeyBindings.label(["skill_1","skill_2","skill_3","ultimate"][slot]),str(info.get("name","未配装")),"%.1f秒"%float(GameState.skill_cooldowns[slot]) if GameState.skill_cooldowns[slot]>0 else "就绪"]
		var icon:=_skills.get_child(slot).get_child(0) as TextureRect
		var path:=str(info.get("icon",""))
		if str(icon.get_meta("path",""))!=path:
			var resolved:=UiFactory.texture_icon(path,42);icon.texture=resolved.texture;resolved.free();icon.set_meta("path",path)
	var target:String=world.nearest_facility()
	var npc:CampResident=world.nearest_resident()
	var caption:String=world.FACILITY_NAMES.get(target,"")
	if npc!=null and (target.is_empty() or world.player_collision_center().distance_to(world.level.to_local(npc.global_position))<world.facility_interaction_distance(target)):caption=str(CampResidents.DATA[npc.resident_id].name)
	_hint.text=("%s 交互 · %s\n"%[KeyBindings.label("interact"),caption] if not caption.is_empty() else "")+"背包调整配装 · 出发台直接启程"
	if MobileControls.enabled():
		var area:=MobileControls.safe_rect()
		_skills.hide();_damage.hide()
		_vitals.position=area.position+Vector2(8,0)
		_player_statuses.position=area.position+Vector2(8,70)
		_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hint.position=area.position+Vector2(400,0);_hint.size=Vector2(area.size.x-420,100)
		_hint.text=("点按交互 · "+caption+"\n" if not caption.is_empty() else "")+"背包调整配装 · 出发台直接启程"

