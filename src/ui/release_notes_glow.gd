class_name ReleaseNotesGlow
extends ColorRect
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader_material:=ShaderMaterial.new();shader_material.shader=preload("res://src/ui/release_notes_glow.gdshader");material=shader_material
	resized.connect(_resize);_resize();_process(0)
func _resize()->void:
	if material is ShaderMaterial:material.set_shader_parameter("extent",size)
func _process(_dt:float)->void:
	if material is ShaderMaterial:material.set_shader_parameter("movement",0.0 if ComicMotion.reduced() else 1.0)
