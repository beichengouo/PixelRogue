class_name RoomMapScreen
extends CanvasLayer
var graph:RoomGraph
var _root:Control
var _canvas:Control
var map:RoomMinimap
func _ready()->void:
	layer=34;process_mode=Node.PROCESS_MODE_ALWAYS
	_root=UiFactory.full_rect();_root.theme=PixelUi.theme();add_child(_root)
	_root.add_child(UiFactory.dim_layer(0.72))
	_canvas=StarUi.frame(_root,Vector2(1080,630))
	var plate:=Panel.new();plate.size=Vector2(1080,630);plate.add_theme_stylebox_override("panel",PixelUi.style(Color(0.025,0.065,0.09,0.96),PixelUi.LINE,8,0,1));_canvas.add_child(plate)
	var title:=PixelUi.title("探索地图",28);title.position=Vector2(28,18);_canvas.add_child(title)
	var close_button:=PixelUi.compact_button("关闭 · M / Esc",17);close_button.position=Vector2(864,18);close_button.size=Vector2(184,40);close_button.pressed.connect(close);_canvas.add_child(close_button)
	map=RoomMinimap.new();map.graph=graph;map.expanded=true;map.position=Vector2(24,76);map.size=Vector2(1032,410);_canvas.add_child(map)
	var types:=UiFactory.hbox(8);types.position=Vector2(28,500);_canvas.add_child(types)
	for kind in ["spawn","normal","elite","reward","game","shop","tavern","boss","boss_rush","altar","trial","event"]:
		var entry:=UiFactory.hbox(3);types.add_child(entry)
		var icon:=TextureRect.new();icon.texture=SpecialRoomArt.room_icon(kind);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(20,20);entry.add_child(icon)
		entry.add_child(PixelUi.label(RoomGraph.title(kind),13))
	var legend:=PixelUi.label("金色：当前位置 · 青色：已清房 · 灰色：未清房 · 滚轮缩放，拖动平移\n保留最近10间房；旧房及其中未拾取的物品会被清理。",16);legend.position=Vector2(28,544);_canvas.add_child(legend)
	if MobileControls.enabled():
		close_button.text="关闭地图";legend.text=legend.text.replace("滚轮缩放，拖动平移","双指缩放，单指拖动平移")
	_root.hide()
func is_open()->bool:return is_instance_valid(_root) and _root.visible
func open()->void:
	if is_open() or not UIFlow.can_open(self) or UIFlow.has_screen():return
	map.pan=Vector2.ZERO;map.map_zoom=1.0;map._touches.clear();map.queue_redraw();_root.show();UIFlow.push_screen(self);ComicMotion.reveal(_canvas)
func close()->void:
	if not is_open():return
	ComicMotion.cancel(_canvas);_root.hide();UIFlow.pop_screen(self)
func _input(event:InputEvent)->void:
	if not is_open() or not UIFlow.is_top(self):return
	if (event.is_action_pressed("room_map") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")) and not event.is_echo():
		close();get_viewport().set_input_as_handled()
