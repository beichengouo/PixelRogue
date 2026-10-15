class_name RoomWater
extends Node2D
var room
var clock:=0.0
var flow:ShaderMaterial
func _ready()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	flow=ShaderMaterial.new();flow.shader=load("res://src/room_mode/room_water_flow.gdshader");material=flow
func _process(dt:float)->void:
	clock+=dt*(.35 if ComicMotion.reduced() else 1)
	if flow!=null:flow.set_shader_parameter("flow_clock",clock)
	if is_instance_valid(room) and not room.deep_water.is_empty():queue_redraw()
func _draw()->void:
	if is_instance_valid(room):RoomWaterArt.draw_cells(self,room.deep_water,clock)
