class_name StageGate
extends Node2D
## A deliberate world interaction; clearing a boss never teleports or banks loot.
var main
var marker:ExtractionMarker
var panel:CanvasLayer
var root:Control
var heading:Label
var description:Label
var next:Button
var leave:Button
var cancel:Button
var confirm:GlassConfirmUI
var _open:=false
var _position_token:=-1

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;set_meta("blocking_screen",true)
	marker=preload("res://src/world/stage_transit_marker.gd").new();marker.caption="阶段星门";marker.model_width=144;main.actors_root.get_parent().add_child(marker)
	marker.z_index=0
	marker.remove_from_group("extraction_markers")
	panel=CanvasLayer.new();panel.layer=37;panel.process_mode=Node.PROCESS_MODE_ALWAYS;add_child(panel)
	root=UiFactory.full_rect();panel.add_child(root);root.add_child(UiFactory.dim_layer(.4))
	var frame:=StarUi.frame(root,Vector2(720,440));var column:=UiFactory.vbox(18);frame.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.offset_left=30;column.offset_top=28;column.offset_right=-30;column.offset_bottom=-28
	heading=PixelUi.title("阶段星门",30);column.add_child(heading)
	description=PixelUi.label("",20);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(description)
	next=PixelUi.button("前往下一阶段",20,0,48);column.add_child(next);next.pressed.connect(_next)
	leave=PixelUi.button("直接撤离 · 返回营地",20,0,48);column.add_child(leave);leave.pressed.connect(_leave)
	cancel=PixelUi.button("继续拾取与探索",20,0,48);column.add_child(cancel);cancel.pressed.connect(close)
	InteractionSkin.mount(root,"stage_gate",frame);root.hide()
	confirm=GlassConfirmUI.new();add_child(confirm);confirm.title="挑战第四阶段"
	confirm.dialog_text="这仍是同一次出征。携带材料尚未入库，死亡将失去全部未带回的物资。第四阶段常规战斗均为精英，终点为三位首领连战；也可以在途中沿原规则呼唤女神撤离。确定继续？"
	confirm.confirmed.connect(func()->void:main.advance_stage())

func available()->bool:
	return is_instance_valid(main.player) and main.graph.staged and main.graph.current==main.graph.stage_terminal and main.graph.stage_boss_cleared and bool(main.graph.rooms[main.graph.current].rewarded) and GameState.run_active

func _process(_dt:float)->void:
	marker.visible=available() and not main._navigation_pending
	if not marker.visible:return
	if _position_token!=main.room_token:
		_position_token=main.room_token
		var point:Vector2=main.level.nearest_clear(main.level.room_rect.get_center()+Vector2(0,-72),18)
		if point.distance_to(main.player.global_position)>24 and main.level.path_direction(main.player.global_position,point,12,false).is_zero_approx():point=main.player.global_position
		marker.global_position=point
	marker.caption="极限挑战完成" if main.graph.stage_index==4 else "归航 / 极限挑战" if main.graph.stage_index==3 else "下一阶段星门"

func in_range()->bool:
	return available() and is_instance_valid(main.player) and main.player.global_position.distance_to(marker.global_position)<=90
func try_interact()->bool:
	if not in_range() or main._navigation_pending or UIFlow.has_screen() or main.expedition.extraction.state!=ExtractionDirector.IDLE:return false
	open();return true
func open()->void:
	if _open or not available():return
	var stage:int=main.graph.stage_index
	heading.text="极限挑战完成" if stage==4 else "正常通关资格已获得" if stage==3 else "第%d阶段完成"%stage
	description.text="专属星誓辉印将在成功撤离时入库。可先拾取剩余战利品。" if stage==4 else "现在可以撤离，或继续挑战高风险第四阶段。全部材料仍随身携带，尚未入库。" if stage==3 else "已领取本房奖励。进入下一阶段后无法返回本阶段；等级、装备、生命、冷却与随身物资继续保留。"
	next.visible=stage<4;next.text="挑战特殊第四阶段" if stage==3 else "前往第%d阶段"%(stage+1)
	leave.text="直接撤离 · 正常通关" if stage==3 else "直接撤离 · 极限通关" if stage==4 else "直接撤离 · 返回营地"
	_open=true;root.show();UIFlow.push_screen(self);cancel.grab_focus()
func _next()->void:
	if not _open or not UIFlow.is_top(self):return
	var risky:bool=main.graph.stage_index==3;close()
	if risky:confirm.popup_centered()
	else:main.advance_stage()
func _leave()->void:
	if not _open or not UIFlow.is_top(self):return
	close();main.expedition.extraction.leave_stage_gate.call_deferred()
func close(_immediate:bool=true)->void:
	_open=false;root.hide();UIFlow.pop_screen(self)
func is_open()->bool:return _open
func _input(event:InputEvent)->void:
	if _open and UIFlow.is_top(self) and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		close();get_viewport().set_input_as_handled()
func _exit_tree()->void:
	if is_instance_valid(marker) and not marker.is_queued_for_deletion():marker.queue_free()
