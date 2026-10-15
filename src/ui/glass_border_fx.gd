class_name GlassBorderFX
extends Node2D
var _panel:Control
var _extent:=Vector2.ZERO
var _reduced:=false
func _ready()->void:
	_panel=get_parent() as Control
	var effect:=ShaderMaterial.new();effect.shader=preload("res://src/ui/release_notes_glow.gdshader");material=effect
	_panel.resized.connect(_resize);visibility_changed.connect(_visibility);_resize();_visibility();_set_motion()
func _resize()->void:
	_extent=_panel.size;material.set_shader_parameter("extent",_extent);queue_redraw()
func _visibility()->void:set_process(is_visible_in_tree())
func _set_motion()->void:
	_reduced=ComicMotion.reduced();material.set_shader_parameter("movement",0.0 if _reduced else 1.0)
func _process(_dt:float)->void:
	if _reduced!=ComicMotion.reduced():_set_motion()
func _draw()->void:
	if _extent.x>0 and _extent.y>0:draw_rect(Rect2(Vector2.ZERO,_extent),Color.WHITE)
