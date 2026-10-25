extends ExtractionMarker
## Horizontal floor ellipse with a vertical light pillar; world origin is its base.
var _gate_light:PointLight2D
var _animated:=false
func _ready()->void:
	z_index=0;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var path:="res://assets/stage_v15/transit_pillar.png"
	_animated=ResourceLoader.exists(path);_model=load(path if _animated else "res://assets/stage_v10/transit_pillar.png")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
	_gate_light=LightUtil.make_point_light(Color("a1dfff"),1.0,288,false,"arcane");_gate_light.name="StageGateGlow";_gate_light.set_meta("day_glow",true);_gate_light.set_meta("priority_light",true);add_child(_gate_light)

func _process(delta:float)->void:
	if _gate_light!=null:_gate_light.enabled=opened and is_visible_in_tree()
	if not visible:return
	if not Engine.is_editor_hint() and (UIFlow.has_screen() or TransitionLayer.busy):return
	if not ComicMotion.reduced():_age+=delta
	queue_redraw()
func footprint_rect()->Rect2:
	return Rect2(Vector2(-model_width*.40,-model_width*.145),Vector2(model_width*.80,model_width*.29))
func _draw()->void:
	if _model==null:return
	var cell:=float(_model.get_height());var height:=model_width if _animated else model_width*cell/float(_model.get_width())
	var tint:=Color.WHITE if opened else Color(.45,.52,.6,.65)
	# The generated sigil center is at source y=0.765, not at the texture edge.
	var rect:=Rect2(-model_width*.5,-height*.765,model_width,height)
	if _animated:
		var frame:=0 if ComicMotion.reduced() else int(_age*6)%4
		draw_texture_rect_region(_model,rect,Rect2(frame*cell,0,cell,cell),tint)
	else:draw_texture_rect(_model,rect,false,tint)
	if opened:
		for index in 7:
			var phase:=fposmod(_age*.22+float(index)*.143,1.0)
			var point:=Vector2(sin(float(index)*2.4)*model_width*.16,-phase*height*.62)
			draw_rect(Rect2(point.round(),Vector2(1,3)),Color(1,.88,.55,sin(phase*PI)*.65))
	if not caption.is_empty():
		var font:=GameFonts.get_font();var width:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_string(font,Vector2(-width*.5,footprint_rect().end.y+18),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e8d6a1"))
