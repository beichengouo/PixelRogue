class_name RoomMapScreen
extends CanvasLayer
var graph:RoomGraph
var _root:Control
var _canvas:Control
var map:RoomMinimap
var _legend:Label
var _purpose_dialog:GlassConfirmUI
const PURPOSES:={"spawn":"安全整备与本次出征星象选择。","normal":"推进阶段，获取经验、清房奖励与地区材料。","elite":"敌人更强并携带残忍；清房逐个天降1—3个宝箱。","reward":"安全搜集逐个降落的宝箱；全部宝箱免费开启。","game":"查看机器投入与回报，或面对场景专属生存挑战。","shop":"补充构筑、购买物资，亦可使用战地炼金与刻印。","tavern":"雇佣同行者、整理补给，亦可使用战地工坊。","boss":"挑战章节首领，取得稀有以上三选一及首领素材。","boss_rush":"连续挑战三位首领，首领携带残忍；奖励与风险均更高。","altar":"守护命运祭坛；祭坛存活且清房后可互动，选择正逆命运牌。","trial":"完成三轮连战与机关考验，最后一轮后发放清房奖励及一个宝箱。","event":"与遗留物互动，读完故事后选择完整显示的收益。"}
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
		var entry:=UiFactory.hbox(3);types.add_child(entry);entry.tooltip_text=str(PURPOSES.get(kind,""))
		var icon:=TextureRect.new();icon.texture=SpecialRoomArt.room_icon(kind);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(20,20);entry.add_child(icon)
		entry.add_child(PixelUi.label(RoomGraph.title(kind),13))
		for child:Control in entry.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var legend:=PixelUi.label("金色：当前位置 · 深色：未进入 · 浅色：已进入 · 青色：已清房 · 滚轮缩放，拖动平移\n已探索房间及相邻房型自动揭示；换阶段前可返回拾取本阶段物品。",16);legend.position=Vector2(28,544);_canvas.add_child(legend)
	_legend=legend
	if MobileControls.enabled():
		close_button.text="关闭地图";legend.text=legend.text.replace("滚轮缩放，拖动平移","双指缩放，单指拖动平移")
	var forecast:=PixelUi.compact_button("星象预告",17);forecast.position=Vector2(680,18);forecast.size=Vector2(160,40);_canvas.add_child(forecast)
	var fate:=FateUI.new();add_child(fate);forecast.pressed.connect(fate.open_forecast)
	_purpose_dialog=GlassConfirmUI.new();add_child(_purpose_dialog);_purpose_dialog.title="探索路线 · 房间收益与风险"
	var notes:PackedStringArray=[]
	for kind in PURPOSES:notes.append(RoomGraph.title(kind)+" · "+str(PURPOSES[kind]))
	_purpose_dialog.dialog_text="\n\n".join(notes);_purpose_dialog.get_ok_button().text="知道了";_purpose_dialog.get_cancel_button().text="返回地图"
	_purpose_dialog.get_ok_button().set_meta("glass_danger",false);InteractionSkin.apply_button(_purpose_dialog.get_ok_button(),"confirm")
	var purposes:=PixelUi.compact_button("房型收益",17);purposes.position=Vector2(500,18);purposes.size=Vector2(160,40);_canvas.add_child(purposes);purposes.pressed.connect(func()->void:_purpose_dialog.popup_centered())
	_root.hide()
func is_open()->bool:return is_instance_valid(_root) and _root.visible
func open()->void:
	if is_open() or not UIFlow.can_open(self) or UIFlow.has_screen():return
	_legend.text="金色：当前位置 · 深色：未进入 · 浅色：已进入 · 青色：已清房 · "+("双指缩放，单指拖动平移" if MobileControls.enabled() else "滚轮缩放，拖动平移")+"\n"+("相邻房型自动揭示；本阶段房间和未拾取物品保留，换阶段后无法返回。" if graph.staged else "保留最近10间房；旧房及其中未拾取的物品会被清理。")
	map.pan=Vector2.ZERO;map.map_zoom=1.0;map._touches.clear();map.queue_redraw();_root.show();UIFlow.push_screen(self);ComicMotion.reveal(_canvas)
func close()->void:
	if not is_open():return
	if is_instance_valid(_purpose_dialog):_purpose_dialog.close()
	ComicMotion.cancel(_canvas);_root.hide();UIFlow.pop_screen(self)
func _input(event:InputEvent)->void:
	if not is_open() or not UIFlow.is_top(self):return
	if (event.is_action_pressed("room_map") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")) and not event.is_echo():
		close();get_viewport().set_input_as_handled()
