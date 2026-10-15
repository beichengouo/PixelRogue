class_name RoomTemplateEditor
extends Control
var document: Dictionary = {}
var canvas: RoomEditorCanvas
var _preview: RoomTemplatePreview
var _preview_toggle: CheckButton
var _environment: OptionButton
var pool := RoomTemplatePool.new()
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _status: Label
var _templates: OptionButton
var _chapter_filter:OptionButton
var _collision_targets: OptionButton
var _collision_add: CheckButton
var _spawn_enemies: CheckBox
var _file_dialog: FileDialog
var _save_mode := false

func _ready() -> void:
	get_window().title="PixelRogue · 房间模板编辑器"
	get_window().min_size=Vector2i(1080,680)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RoomTemplatePool.USER))
	_build_ui();pool.reload();_refresh_templates()
	if not pool.templates.is_empty():
		document=pool.templates[0].duplicate(true);_templates.select(1)
	else:
		_status.text="模板池为空：请打开已有房间 JSON"
		return
	_sync();_changed()

func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new();button.text=label;button.pressed.connect(action);parent.add_child(button);return button

func _option(parent: Node, labels: Array) -> OptionButton:
	var option := OptionButton.new()
	for label in labels:option.add_item(str(label))
	parent.add_child(option);return option

func _build_ui() -> void:
	var margin := MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(key,12)
	add_child(margin)
	var root := VBoxContainer.new();margin.add_child(root)
	var toolbar := HFlowContainer.new();root.add_child(toolbar)
	_button(toolbar,"图层抠图 / 界面布局",func():var art:=LayerArtEditor.new();add_child(art);art.popup_centered())
	_button(toolbar,"打开 JSON",func():_open_dialog(false))
	_button(toolbar,"保存 JSON",func():_open_dialog(true))
	_button(toolbar,"存入模板池",_save_to_pool)
	_button(toolbar,"撤销 Ctrl+Z",_undo_edit)
	_button(toolbar,"重做 Ctrl+Y",_redo_edit)
	_button(toolbar,"验证",_validate)
	_button(toolbar,"游戏验证",_playtest)
	_spawn_enemies=CheckBox.new();_spawn_enemies.text="刷怪";toolbar.add_child(_spawn_enemies)
	_preview_toggle=CheckButton.new();_preview_toggle.text="渲染预览";toolbar.add_child(_preview_toggle)
	_preview_toggle.toggled.connect(func(value):
		if value and not _readable():_preview_toggle.button_pressed=false;return
		canvas.visible=not value;_preview.visible=value
		if value:_preview.set_document(document))
	_environment=_option(toolbar,["白天","黄昏","夜晚","雾中"])
	_environment.item_selected.connect(func(index):_preview.set_environment(index))
	_button(toolbar,"−",func():_zoom(-0.125))
	_button(toolbar,"＋",func():_zoom(0.125))
	var body := HSplitContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;root.add_child(body)
	var left_scroll := ScrollContainer.new();left_scroll.custom_minimum_size.x=270;body.add_child(left_scroll)
	var left := VBoxContainer.new();left.custom_minimum_size.x=254;left_scroll.add_child(left)
	var title := Label.new();title.text="模板池";left.add_child(title)
	var storage := Label.new();storage.text="自制模板："+ProjectSettings.globalize_path(RoomTemplatePool.USER)
	storage.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;storage.add_theme_font_size_override("font_size",13);left.add_child(storage)
	_chapter_filter=OptionButton.new();left.add_child(_chapter_filter)
	for label in ["全部章节","第一关 · 苏醒林地","第二关 · 失名星城","通用／营地"]:_chapter_filter.add_item(label)
	_chapter_filter.item_selected.connect(func(_index:int)->void:_refresh_templates())
	_templates=OptionButton.new();left.add_child(_templates);_templates.item_selected.connect(_load_from_pool)
	var info := Label.new();info.text="编辑碰撞、出生点与四个进出口。验证结果仅供参考，不阻止保存、存入模板池或游戏验证。";info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;left.add_child(info)
	var visibility := HFlowContainer.new();left.add_child(visibility)
	var views := {"background":"背景地板","water_bridge":"水面与桥","paths":"路径","walls":"墙体","roofs":"屋顶前景","lights":"灯光","objects":"物件","buildings":"建筑","doors":"门与进出口","collision":"碰撞","spawns":"出生/营地交互点"}
	for layer_name in views:
		var check := CheckBox.new();check.text=views[layer_name];check.button_pressed=true;check.add_theme_font_size_override("font_size",14);visibility.add_child(check)
		check.toggled.connect(func(value):
			canvas.visible_layers[layer_name]=value;canvas.queue_redraw()
			_preview.set_layer_visible(layer_name,value))
	var tools := _option(left,["编辑碰撞轮廓","出生/营地交互点","移动四个进出口"])
	tools.item_selected.connect(func(index):canvas.tool=["collision","spawn","port"][index];canvas.queue_redraw())
	var collision_panel := VBoxContainer.new();left.add_child(collision_panel)
	var collision_label := Label.new();collision_label.text="碰撞轮廓目标（场景 / 放置物件 / 水面）";collision_panel.add_child(collision_label)
	_collision_targets=OptionButton.new();collision_panel.add_child(_collision_targets)
	_collision_targets.item_selected.connect(func(index):canvas.collision_target=str(_collision_targets.get_item_metadata(index));canvas.queue_redraw())
	_collision_add=CheckButton.new();_collision_add.text="添加点：点击画布；关闭后拖动已有点";collision_panel.add_child(_collision_add)
	_collision_add.toggled.connect(func(value):canvas.collision_add_mode=value)
	var collision_actions := HFlowContainer.new();collision_panel.add_child(collision_actions)
	_button(collision_actions,"清空 / 禁用",_collision_clear)
	_button(collision_actions,"恢复默认",_collision_restore)
	_button(collision_actions,"新增水面",_collision_new_water)
	_button(collision_actions,"删除水面",_collision_delete_water)
	var collision_help := Label.new();collision_help.text="选择「地图外边界」可拖四边中点或四角，收紧玩家可走范围；贴图保持原位。其他轮廓黄色点可拖动；双击边添加点，右键点删除。勾选「添加点」可从空轮廓绘制。清空可禁用物件/水面碰撞；恢复默认读取原始轮廓。";collision_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;collision_panel.add_child(collision_help)
	var help := Label.new();help.text="碰撞：选目标后拖黄色点；双击线段加点，右键点删除。\n出生点：左键空处添加，拖黄色标记移动，右键标记删除。\n进出口：拖绿色方框沿所在边移动。\nCtrl+Z 撤销，Ctrl+Y 重做。";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;left.add_child(help)
	var scroll := ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	var stage := VBoxContainer.new();stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.add_child(stage)
	canvas=RoomEditorCanvas.new();stage.add_child(canvas);canvas.gesture.connect(_gesture);canvas.object_drag.connect(_move_entry);canvas.collision_edit.connect(_collision_edit)
	_preview=RoomTemplatePreview.new();stage.add_child(_preview);_preview.hide()
	_status=Label.new();_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;root.add_child(_status)
	_file_dialog=FileDialog.new();_file_dialog.access=FileDialog.ACCESS_FILESYSTEM;_file_dialog.filters=PackedStringArray(["*.json ; 房间模板 JSON"]);add_child(_file_dialog)
	_file_dialog.file_selected.connect(_file_selected)

func _sync() -> void:
	canvas.set_document(document);_refresh_collision_targets()

func _checkpoint(_update_metadata := true) -> void:
	_undo.append(document.duplicate(true));_redo.clear()
	if _undo.size()>100:_undo.pop_front()

func _changed() -> void:
	canvas.set_document(document)
	_refresh_collision_targets()
	if _preview.visible:_preview.set_document(document)
	_status.text="当前房间：%s · %d×%d · Ctrl+Z 撤销" % [document.name,document.grid.size[0],document.grid.size[1]]

func _undo_edit() -> void:
	if _undo.is_empty():return
	_redo.append(document.duplicate(true));document=_undo.pop_back();_sync();_changed()

func _redo_edit() -> void:
	if _redo.is_empty():return
	_undo.append(document.duplicate(true));document=_redo.pop_back();_sync();_changed()

func _refresh_collision_targets(preferred := "") -> void:
	if _collision_targets==null:return
	var selected: String = preferred if not preferred.is_empty() else canvas.collision_target
	_collision_targets.clear()
	for target in RoomEditorCollision.targets(document):
		var index := _collision_targets.item_count
		_collision_targets.add_item(str(target.label));_collision_targets.set_item_metadata(index,str(target.key))
		if str(target.key)==selected:_collision_targets.select(index)
	if _collision_targets.item_count==0:canvas.collision_target="";return
	if _collision_targets.selected<0:_collision_targets.select(0)
	canvas.collision_target=str(_collision_targets.get_item_metadata(_collision_targets.selected))
	canvas.queue_redraw()

func _collision_edit(key: String, action: String, index: int, world: Vector2) -> void:
	if key=="room_bounds":
		if action!="move" or index<0:return
		var changed_bounds := RoomEditorCollision.moved_bounds(document,index,world)
		var candidate := document.duplicate(true)
		candidate.room_bounds_override=changed_bounds
		var error := RoomEditorCollision.bounds_error(candidate)
		if not error.is_empty():_status.text="边界未应用："+error;canvas.queue_redraw();return
		if RoomEditorCollision.bounds(candidate)==RoomEditorCollision.bounds(document):return
		# Boundary and internal contours are editable drafts. Route validation
		# belongs to the explicit validation/save step, not each mouse release;
		# otherwise a temporarily blocked gate prevents repairing the geometry.
		_checkpoint();document.room_bounds_override=changed_bounds;_changed()
		_status.text="地图外边界已更新；Ctrl+Z 可撤销。调整完成后点击「验证」检查通路。";return
	var polygon := RoomEditorCollision.shape(document,key)
	var origin := RoomEditorCollision.origin(document,key)
	var local := world-origin
	var point := [snappedf(local.x,0.1),snappedf(local.y,0.1)]
	if action=="move":
		if index<0 or index>=polygon.size():return
		if polygon[index]==point:return
		polygon[index]=point
	elif action=="delete":
		if index<0 or index>=polygon.size():return
		polygon.remove_at(index)
		if polygon.size()<3:polygon=[]
	elif action=="insert":polygon.insert(clampi(index,0,polygon.size()),point)
	elif action=="add":polygon.append(point)
	else:return
	if polygon.size()>=3:
		var error := RoomEditorCollision.valid_polygon(polygon)
		if not error.is_empty():_status.text="碰撞编辑未应用："+error;canvas.queue_redraw();return
	_checkpoint();RoomEditorCollision.assign(document,key,polygon);_changed()
	_status.text="碰撞轮廓已更新；Ctrl+Z 撤销。保存前需至少三点，空轮廓表示禁用。"

func _collision_clear() -> void:
	var key := canvas.collision_target
	if key.is_empty():return
	if key=="room_bounds":_status.text="外边界不能禁用；可拖动边界或点击「恢复默认」";return
	_checkpoint();RoomEditorCollision.assign(document,key,[]);_changed();_status.text="已清空该目标碰撞；Ctrl+Z 可撤销"

func _collision_restore() -> void:
	var key := canvas.collision_target
	if key.is_empty():return
	if key=="room_bounds":
		if not document.has("room_bounds_override"):return
		_checkpoint();document.erase("room_bounds_override");_changed();_status.text="已恢复原始地图外边界；Ctrl+Z 可撤销";return
	_checkpoint();RoomEditorCollision.restore(document,key);_changed();_status.text="已恢复该目标默认碰撞；Ctrl+Z 可撤销"

func _collision_new_water() -> void:
	_checkpoint();var key := RoomEditorCollision.add_water(document);_changed();_refresh_collision_targets(key)
	_collision_add.button_pressed=true
	_status.text="新水面已建立：在画布点击至少三个点，然后关闭添加点"

func _collision_delete_water() -> void:
	var key := canvas.collision_target
	if not key.begins_with("water:"):return
	_checkpoint();RoomEditorCollision.delete_water(document,int(key.trim_prefix("water:")));canvas.collision_target="";_changed();_status.text="水面轮廓已删除；Ctrl+Z 可撤销"

func _gesture(tool: String, start: Vector2i, end: Vector2i, cells: Array[Vector2i]) -> void:
	if tool=="spawn" or tool=="erase":
		if document.room_kinds.has("camp"):_status.text="营地固定交互点只能拖动，不能新增或删除。";return
		var grid := Rect2i(Vector2i.ZERO,Vector2i(int(document.grid.size[0]),int(document.grid.size[1])))
		if not grid.has_point(start):return
		if tool=="erase":
			for entry in document.layers.markers:
				if str(entry.asset_id)=="spawn" and Vector2i(int(entry.at[0]),int(entry.at[1]))==start:
					_checkpoint();document.layers.markers.erase(entry);_changed();return
			return
		if document.layers.markers.any(func(entry):return Vector2i(int(entry.at[0]),int(entry.at[1]))==start):return
		var candidate := document.duplicate(true)
		candidate.layers.markers.append({"id":"spawn_%d" % Time.get_ticks_usec(),"asset_id":"spawn","at":[start.x,start.y]})
		_checkpoint();document=candidate;_changed();return
	if tool=="port":
		for index in document.ports.size():
			var port: Dictionary = document.ports[index]
			if Vector2i(int(port.at[0]),int(port.at[1])).distance_to(start)>1.5:continue
			var w := int(document.grid.size[0]);var h := int(document.grid.size[1])
			var candidate := document.duplicate(true)
			var moved: Dictionary = candidate.ports[index]
			moved.at=[clampi(end.x,2,w-3),0] if port.side=="north" else ([clampi(end.x,2,w-3),h-1] if port.side=="south" else ([0,clampi(end.y,2,h-3)] if port.side=="west" else [w-1,clampi(end.y,2,h-3)]))
			if moved.at==port.at:return
			_checkpoint();document=candidate;_changed();return
		return
	return
func _move_entry(layer: String, entry_id: String, offset: Vector2i) -> void:
	if layer!="markers" or not document.layers.has(layer):return
	for entry in document.layers[layer]:
		if str(entry.id)!=entry_id or (str(entry.asset_id)!="spawn" and not str(entry.asset_id).begins_with("camp:")):continue
		if offset==Vector2i.ZERO:
			_status.text="选中："+str(entry.asset_id)+" · 拖动中心点移动";return
		var candidate := document.duplicate(true)
		for moved in candidate.layers[layer]:
			if str(moved.id)==entry_id:moved.at=[int(moved.at[0])+offset.x,int(moved.at[1])+offset.y];break
		var moved: Dictionary = candidate.layers[layer].filter(func(value):return str(value.id)==entry_id)[0]
		var at := Vector2i(int(moved.at[0]),int(moved.at[1]))
		if not Rect2i(Vector2i.ZERO,Vector2i(int(document.grid.size[0]),int(document.grid.size[1]))).has_point(at):_status.text="出生点不能移出地图";return
		_checkpoint();entry.at=[int(entry.at[0])+offset.x,int(entry.at[1])+offset.y]
		_changed();_status.text="已移动："+str(entry.asset_id)+" · 保持整块占格 · Ctrl+Z 可撤销";return

func _zoom(change: float) -> void:
	canvas.zoom=clampf(canvas.zoom+change,0.5,2);canvas.set_document(document)

func _validate() -> bool:
	if document.is_empty():_status.text="请先打开房间 JSON";return false
	var errors := RoomTemplateValidator.validate(document)
	_status.text="验证通过：四入口、资源、多格占用与14/26半径通路正常" if errors.is_empty() else "验证提示（仍可保存及存入模板池）："+"；".join(errors.slice(0,5))
	return errors.is_empty()

func _readable() -> bool:
	var errors := RoomTemplateValidator.load_errors(document)
	if not errors.is_empty():_status.text="模板数据无法读取："+"；".join(errors.slice(0,5));return false
	return true

func _saved_message(prefix: String, path: String) -> String:
	var errors := RoomTemplateValidator.validate(document)
	return prefix+path+(" · 验证未通过，已按你的决定保存；可点击「验证」查看提示" if not errors.is_empty() else "")

func _playtest() -> void:
	if not _readable():return
	var playtest_script := load("res://src/room_editor/playtest.gd") as GDScript
	if playtest_script==null:_status.text="游戏验证模块正在加载，请稍后重试";return
	var error: int = playtest_script.call("launch",document.duplicate(true),_spawn_enemies.button_pressed)
	_status.text="游戏验证已启动：当前未保存的编辑内容" if error==OK else "游戏验证启动失败："+error_string(error)

func _open_dialog(save: bool) -> void:
	_save_mode=save
	if save and not _readable():return
	_file_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.current_dir=ProjectSettings.globalize_path(RoomTemplatePool.USER)
	if save:_file_dialog.current_file=str(document.id)+".json"
	_file_dialog.popup_centered_ratio(0.75)

func _file_selected(path: String) -> void:
	if _save_mode:
		if not _readable():return
		var error := _write_with_revision(path)
		_status.text=_saved_message("已保存：",path) if error==OK else "保存失败："+error_string(error)
	else:
		var data := RoomTemplateCodec.read_file(path)
		var errors := RoomTemplateValidator.load_errors(data)
		if not errors.is_empty():_status.text="加载失败："+"；".join(errors.slice(0,5));return
		_checkpoint();document=data;_sync();_changed()

func _save_to_pool() -> void:
	if not _readable():return
	var safe_id := str(document.id)
	if safe_id.validate_filename()!=safe_id or safe_id.contains("/") or safe_id.contains("\\"):_status.text="模板ID不可包含路径字符";return
	var error := _write_with_revision(RoomTemplatePool.USER+"/"+safe_id+".json")
	if error!=OK:_status.text="保存失败："+error_string(error);return
	pool.reload();_refresh_templates();_status.text=_saved_message("已存入模板池：",ProjectSettings.globalize_path(RoomTemplatePool.USER+"/"+safe_id+".json"))

func _write_with_revision(path: String) -> Error:
	var previous_revision := int(document.revision)
	var existing := RoomTemplateCodec.read_file(path)
	var known_revision := int(existing.get("revision",0)) if str(existing.get("id",""))==str(document.id) else 0
	for item in pool.templates:
		if item.id==document.id:known_revision=maxi(known_revision,int(item.revision))
	if known_revision>0:document.revision=maxi(previous_revision,known_revision)+1
	var error := RoomTemplateCodec.write_file(path,document)
	if error!=OK:document.revision=previous_revision
	return error

func _refresh_templates() -> void:
	_templates.clear();_templates.add_item("选择模板（%d）" % pool.templates.size())
	for item in pool.templates:
		var owner:=ChapterCatalog.map_chapter(str(item.id))
		if item.room_kinds.has("boss"):
			for tag in item.tags:
				if str(tag).begins_with("boss:"):owner=ChapterCatalog.NEXT if str(tag).trim_prefix("boss:") in ChapterCatalog.bosses(ChapterCatalog.NEXT) else ChapterCatalog.FIRST
		if is_instance_valid(_chapter_filter) and _chapter_filter.selected>0:
			var wanted:StringName=[ChapterCatalog.FIRST,ChapterCatalog.NEXT,&""][_chapter_filter.selected-1]
			if owner!=wanted:continue
		var index := _templates.item_count;_templates.add_item(str(item.name));_templates.set_item_metadata(index,item.id)

func _load_from_pool(index: int) -> void:
	if index==0:return
	for item in pool.templates:
		if item.id==_templates.get_item_metadata(index):_checkpoint();document=item.duplicate(true);_sync();_changed();return

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.ctrl_pressed and event.keycode==KEY_Z:
		if event.shift_pressed:_redo_edit()
		else:_undo_edit()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode==KEY_Y:_redo_edit();get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode==KEY_S:_save_to_pool();get_viewport().set_input_as_handled()
