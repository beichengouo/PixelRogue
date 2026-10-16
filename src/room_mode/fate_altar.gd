class_name FateAltar
extends Node2D
var main:Node
var ui:FateUI
var _room_id:=""
var _label:Label
var _model:RoomLightProp
func _ready()->void:
	_model=RoomLightProp.new();_model.kind="crystal";_model.scene_texture=load("res://assets/fate_v01/altar/moonwell.png")
	_model.scene_width=66;_model.scene_bottom_anchor=true;_model.radius_override=120;_model.strength_override=.65;_model.light_color=Color("c4d8ff");add_child(_model)
	_label=PixelUi.label("",15,Color("d9e9fb"));_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_label.size=Vector2(300,46);_label.z_index=1000;_label.top_level=true;add_child(_label)
func _process(_delta:float)->void:
	var record:Dictionary=main.graph.rooms.get(main.graph.current,{})
	visible=FateService.eligible(record)
	if not visible:return
	var location_key:="%s:%s:%s"%[GameState.run_epoch,main.graph.current,main.level._load_generation]
	if _room_id!=location_key:
		_room_id=location_key;global_position=main.level.nearest_clear(main.level.bounds().get_center()+Vector2(0,72),12)
	var nearby:=is_instance_valid(main.player) and global_position.distance_squared_to(main.player.global_position)<=8100
	_label.global_position=global_position+Vector2(-150,-130)
	_label.text=(UIFlow.hint(&"interact")+" · 命运祭坛") if nearby and not UIFlow.has_screen() else "命运祭坛"
func try_interact()->bool:
	if not visible or UIFlow.has_screen() or not is_instance_valid(main.player) or global_position.distance_squared_to(main.player.global_position)>8100:return false
	ui.open_altar(FateService.record());return true
