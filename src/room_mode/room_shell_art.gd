@tool
class_name RoomShellArt
extends Node2D
var room
func _process(_dt:float)->void:
	queue_redraw()
func _draw()->void:
	if is_instance_valid(room):room._draw_shell(self)
