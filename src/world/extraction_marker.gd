@tool
class_name ExtractionMarker
extends Marker2D
@export var point_id := "forest"
@export var caption := "林间回廊"
var opened := true
var stable := false
@export var model_width := 184.0
var _age=0.0
var _model:Texture2D

func _ready() -> void:
	z_index = -1
	_model=CampArt.texture("portal")
	add_to_group("extraction_markers")
	queue_redraw()
func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and not SaveService.data.get("reduced_motion",false):_age+=delta
	queue_redraw()

func _draw() -> void:
	var tint := Color("8af1d4") if opened else Color("74868c")
	if stable: tint = Color("ffd166")
	var width=model_width
	var height=width*0.91
	if _model!=null:
		height=width*_model.get_height()/_model.get_width()
		draw_texture_rect(_model,Rect2(-width*0.5,-height,width,height),false,Color.WHITE if opened else Color(0.48,0.55,0.6))
	if opened:
		for i in 7:
			var color=tint
			color.a=(0.018+0.004*sin(_age*1.6))*float(7-i)
			draw_circle(Vector2(0,-height*0.38),width*(0.07+i*0.015),color)
		for i in 9:
			var phase=fposmod(_age*0.17+i*0.137,1.0)
			var color=tint;color.a=sin(phase*PI)*0.7
			draw_circle(Vector2(sin(i*2.4+_age*0.4)*width*0.13,-height*0.15-phase*height*0.45),1.2,color)
	if not caption.is_empty():
		var text=caption+("" if opened else " · 关闭")
		var font=GameFonts.get_font()
		var w=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		draw_string(font,Vector2(-w*0.5,-height-10),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,tint)
