@tool
extends EditorPlugin
const CATALOG="res://assets/map_editor/catalog.json"
const AssetList=preload("res://addons/pixelrogue_map_tools/asset_list.gd")
var _dock:VBoxContainer
var _search:LineEdit
var _category:OptionButton
var _list:ItemList
var _description:Label
var _snap:CheckBox
var _entries:Array=[]
var _terrain:CampTerrain
var _drag_index=-1
var _before=PackedVector2Array()
var _visible=false

func _enter_tree() -> void:
	_dock=VBoxContainer.new()
	_dock.name="地图素材"
	_dock.custom_minimum_size=Vector2(260,360)
	var title=Label.new()
	title.text="PixelRogue · 地图素材"
	_dock.add_child(title)
	_search=LineEdit.new()
	_search.placeholder_text="搜索草木、水体、建筑…"
	_dock.add_child(_search)
	_category=OptionButton.new()
	_category.add_item("全部分类")
	_dock.add_child(_category)
	_list=AssetList.new()
	_list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_list.icon_mode=ItemList.ICON_MODE_TOP
	_list.fixed_icon_size=Vector2i(80,64)
	_list.fixed_column_width=126
	_list.max_columns=2
	_list.allow_reselect=true
	_dock.add_child(_list)
	_description=Label.new()
	_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y=64
	_description.text="拖入2D视口放置。双击打开原始场景或资源。"
	_dock.add_child(_description)
	_snap=CheckBox.new()
	_snap.text="地形点吸附 36px"
	_snap.button_pressed=true
	_dock.add_child(_snap)
	var guide=Label.new()
	guide.text="选中 CampTerrain：拖点改变草坡\nCtrl+左键加点 · 右键删点\nShift 临时自由拖动 · Esc 取消\n地形与碰撞同步，支持撤销/重做"
	guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(guide)
	var decoded=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if decoded is Array:_entries=decoded
	for data in _entries:
		var found=false
		for i in _category.item_count:
			if _category.get_item_text(i)==data.category:found=true;break
		if not found:_category.add_item(data.category)
	_search.text_changed.connect(func(_text:String):_refresh())
	_category.item_selected.connect(func(_index:int):_refresh())
	_list.item_selected.connect(_select_asset)
	_list.item_activated.connect(_open_asset)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL,_dock)
	_refresh()

func _exit_tree() -> void:
	_cancel_drag()
	_terrain=null
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()

func _refresh() -> void:
	_list.clear()
	var query=_search.text.strip_edges().to_lower()
	var category=_category.get_item_text(_category.selected)
	for data in _entries:
		if _category.selected>0 and data.category!=category:continue
		if not query.is_empty() and not (data.name+data.category+data.note).to_lower().contains(query):continue
		var icon:Texture2D
		# Cropped Sprite2D prefabs use their actual atlas region as the thumbnail.
		if data.path.ends_with(".tscn") and data.path.begins_with("res://assets/map_editor/"):
			var packed=load(data.path) as PackedScene
			if packed!=null:
				var state=packed.get_state()
				for p in state.get_node_property_count(0):
					if state.get_node_property_name(0,p)==&"texture":icon=state.get_node_property_value(0,p)
		if icon==null and not data.preview.is_empty() and ResourceLoader.exists(data.preview):icon=load(data.preview)
		var index=_list.add_item(data.name,icon)
		_list.set_item_metadata(index,data)
		_list.set_item_tooltip(index,data.category+"\n"+data.note+"\n"+data.path)

func _select_asset(index:int) -> void:
	var data:Dictionary=_list.get_item_metadata(index)
	_description.text=data.category+"\n"+data.note

func _open_asset(index:int) -> void:
	var data:Dictionary=_list.get_item_metadata(index)
	if data.path.ends_with(".tscn"):EditorInterface.open_scene_from_path(data.path)
	else:EditorInterface.inspect_object(load(data.path))

func _handles(object:Object) -> bool:
	return object is CampTerrain

func _edit(object:Object) -> void:
	_cancel_drag()
	_terrain=object as CampTerrain
	update_overlays()

func _make_visible(value:bool) -> void:
	_visible=value
	if not value:
		_cancel_drag()
		_terrain=null
	update_overlays()

func _profile_transform() -> Transform2D:
	return EditorInterface.get_editor_viewport_2d().global_canvas_transform*_terrain.global_transform

func _forward_canvas_draw_over_viewport(overlay:Control) -> void:
	if not _visible or not is_instance_valid(_terrain):return
	var transform=_profile_transform()
	var points=PackedVector2Array()
	for p in _terrain.top_line:points.append(transform*p)
	if points.size()>1:overlay.draw_polyline(points,Color(0.5,1.0,0.76),2,true)
	for i in points.size():
		overlay.draw_circle(points[i],7,Color(0.08,0.15,0.12))
		overlay.draw_circle(points[i],5,Color(1.0,0.83,0.4) if i==_drag_index else Color(0.55,1.0,0.8))

func _nearest_point(screen_position:Vector2) -> int:
	var transform=_profile_transform()
	var closest=-1
	var distance=12.0
	for i in _terrain.top_line.size():
		var d=(transform*_terrain.top_line[i]).distance_to(screen_position)
		if d<distance:distance=d;closest=i
	return closest

func _forward_canvas_gui_input(event:InputEvent) -> bool:
	if not _visible or not is_instance_valid(_terrain):return false
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and _drag_index>=0:
		_cancel_drag();return true
	if event is InputEventMouseMotion and _drag_index>=0:
		var point=_profile_transform().affine_inverse()*event.position
		if _snap.button_pressed and not event.shift_pressed:point=point.snapped(Vector2(36,36))
		var line=_terrain.top_line.duplicate()
		if _drag_index>0:point.x=maxf(point.x,line[_drag_index-1].x+1.0)
		if _drag_index<line.size()-1:point.x=minf(point.x,line[_drag_index+1].x-1.0)
		point.y=minf(point.y,_terrain.depth-1.0)
		line[_drag_index]=point
		_terrain.top_line=line
		update_overlays();return true
	if not event is InputEventMouseButton:return false
	if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _drag_index>=0:
		var previous=_before.duplicate()
		_drag_index=-1
		_record_edit(previous,_terrain.top_line,"调整营地地形")
		_before.clear();update_overlays();return true
	if not event.pressed:return false
	var index=_nearest_point(event.position)
	if event.button_index==MOUSE_BUTTON_RIGHT and index>=0:
		if _terrain.top_line.size()>2:
			var line=_terrain.top_line.duplicate()
			line.remove_at(index)
			_record_edit(_terrain.top_line,line,"删除地形轮廓点")
		return true
	if event.button_index!=MOUSE_BUTTON_LEFT:return false
	if index>=0:
		_drag_index=index
		_before=_terrain.top_line.duplicate()
		return true
	if event.ctrl_pressed:
		var transform=_profile_transform()
		var line=_terrain.top_line.duplicate()
		var insert_index=-1
		var candidate=Vector2.ZERO
		var distance=12.0
		for i in range(line.size()-1):
			var nearest=Geometry2D.get_closest_point_to_segment(event.position,transform*line[i],transform*line[i+1])
			var d=nearest.distance_to(event.position)
			if d<distance:distance=d;insert_index=i+1;candidate=transform.affine_inverse()*nearest
		if insert_index>=0:
			if _snap.button_pressed and not event.shift_pressed:candidate=candidate.snapped(Vector2(36,36))
			candidate.x=clampf(candidate.x,line[insert_index-1].x+1,line[insert_index].x-1)
			candidate.y=minf(candidate.y,_terrain.depth-1)
			line.insert(insert_index,candidate)
			_record_edit(_terrain.top_line,line,"增加地形轮廓点")
			return true
	return false

func _record_edit(previous:PackedVector2Array,next:PackedVector2Array,title:String) -> void:
	if previous==next:return
	var undo=get_undo_redo()
	undo.create_action(title,UndoRedo.MERGE_DISABLE,_terrain)
	undo.add_do_property(_terrain,&"top_line",next.duplicate())
	undo.add_undo_property(_terrain,&"top_line",previous.duplicate())
	undo.add_do_method(self,&"update_overlays")
	undo.add_undo_method(self,&"update_overlays")
	undo.commit_action()

func _cancel_drag() -> void:
	if _drag_index>=0 and is_instance_valid(_terrain):_terrain.top_line=_before.duplicate()
	_drag_index=-1
	_before.clear()
	update_overlays()
