class_name FateAltar
extends Node2D
var main:Node
var ui:FateUI
var _room_id:=""
var _label:Label
func _ready()->void:
	z_index=1000;_label=PixelUi.label("",15,Color("d9e9fb"));_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_label.position=Vector2(-150,-58);_label.size=Vector2(300,46);add_child(_label)
func _process(_delta:float)->void:
	var record:Dictionary=main.graph.rooms.get(main.graph.current,{})
	visible=FateService.eligible(record)
	if not visible:return
	if _room_id!=main.graph.current:
		_room_id=main.graph.current;global_position=main.level.nearest_clear(main.level.bounds().get_center()+Vector2(0,72),12)
	var nearby:=is_instance_valid(main.player) and global_position.distance_squared_to(main.player.global_position)<=8100
	_label.text=(UIFlow.hint(&"interact")+" · 命运祭坛") if nearby and not UIFlow.has_screen() else "命运祭坛"
	queue_redraw()
func try_interact()->bool:
	if not visible or UIFlow.has_screen() or not is_instance_valid(main.player) or global_position.distance_squared_to(main.player.global_position)>8100:return false
	ui.open_altar(FateService.record());return true
func _draw()->void:
	if not visible:return
	draw_arc(Vector2.ZERO,24,0,TAU,32,Color(.65,.8,1,.8),2,true);draw_arc(Vector2.ZERO,31,0,TAU,32,Color(.9,.8,.5,.5),1,true)
	for i in 8:
		var direction:=Vector2.UP.rotated(TAU*i/8);draw_line(direction*13,direction*24,Color("d6d9ef"),1,true)
