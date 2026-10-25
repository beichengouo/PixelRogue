class_name PlayerStatBar
extends StatBar

## Quiet, compact meter trim; interpolation and damage/scar data stay in StatBar.
var kind := "hp"
var _frame: StyleBoxFlat
var _liquid: Texture2D
var _gain_time := 0.0
var _loss_time := 0.0
var _delta_from := 0.0
var _amount_label:Label
var capacity_loss:=0.0
func set_capacity_loss(amount:float)->void:
	var value:=maxf(0,amount) if kind=="hp" else 0.0
	if not is_equal_approx(value,capacity_loss):capacity_loss=value;queue_redraw()

func configure(type: String) -> void:
	kind = type
	_frame=_box(Color("111a29"),3,Color("8d927f"),1)
	_liquid=preload("res://assets/hud_v23/liquid.png")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if _amount_label==null:
		_amount_label=Label.new();_amount_label.name="Value";_amount_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_amount_label)
		_amount_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_amount_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_amount_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		_amount_label.add_theme_font_size_override("font_size",16 if kind=="hp" else 14);_amount_label.add_theme_color_override("font_color",Color.WHITE);_amount_label.add_theme_color_override("font_outline_color",Color("141b2b"));_amount_label.add_theme_constant_override("outline_size",2)
	_update_amount()
	queue_redraw()

func set_max_value(amount:float)->void:
	super.set_max_value(amount);_update_amount()
func _update_amount()->void:
	if _amount_label!=null:_amount_label.text="%d / %d"%[roundi(_value),roundi(_max_value)]

func set_value(amount: float, instant := false) -> void:
	if _started and not instant and not is_equal_approx(_value, amount):
		_delta_from = _value / maxf(1.0, _max_value+capacity_loss)
		if amount > _value:
			_gain_time = 0.12 if ComicMotion.reduced() else 0.4
		else:
			_loss_time = 0.12 if ComicMotion.reduced() else 0.45
	super.set_value(amount, instant)
	_update_amount()

func level_up() -> void:
	_ghost = _value
	_shown = _value
	_gain_time = 0.12 if ComicMotion.reduced() else 0.45

func _process(delta: float) -> void:
	super._process(delta)
	if _gain_time > 0.0 or _loss_time > 0.0:
		_gain_time = maxf(0.0, _gain_time - delta)
		_loss_time = maxf(0.0, _loss_time - delta)
		queue_redraw()

func meter_rect()->Rect2:
	var inset:=Vector2(3,2)
	return Rect2(inset,Vector2(maxf(0,size.x-inset.x*2),maxf(0,size.y-inset.y*2)))

func _draw() -> void:
	if _frame==null or _liquid==null:return
	_frame.border_color=Color("ed8791") if kind=="hp" and _value/maxf(.001,_max_value)<=.32 else Color("8d927f")
	draw_style_box(_frame,Rect2(Vector2.ZERO,size))
	var inner:=meter_rect()
	var full:=maxf(.0001,_max_value+capacity_loss)
	var usable:=clampf(_max_value/full,0,1)
	var shown:=clampf(_shown/full,0,usable)
	var ghost:=clampf(_ghost/full,0,usable)
	_layer(inner,1.0,Color("737987") if capacity_loss>0 else Color("142133"))
	if capacity_loss>0:_layer(inner,usable,Color("142133"))
	if ghost>shown:_layer(inner,ghost,Color(1,.86,.76,.48),_liquid)
	if shown>0:_layer(inner,shown,fill_color,_liquid)
	if _gain_time>0 and shown>0:_layer(inner,shown,Color(1,1,.85,.18*minf(1,_gain_time/.25)),_liquid)
	if not ComicMotion.reduced() and (_gain_time>0 or _loss_time>0) and shown>0:
		var edge:=inner.position+Vector2(inner.size.x*shown,1)
		draw_line(edge,edge+Vector2(0,maxf(0,inner.size.y-2)),Color(1,1,1,.7),1)
	if capacity_loss>0:
		var scar:=inner.position+Vector2(inner.size.x*usable,0)
		draw_line(scar,scar+Vector2(0,inner.size.y),Color("b9bdc6"),1)
	# A small top highlight keeps the fill legible without jeweled endcaps.
	if shown>0:draw_line(inner.position+Vector2(2,1),inner.position+Vector2(maxf(2,inner.size.x*shown-2),1),Color(1,1,1,.22),1)

func _layer(rect:Rect2,ratio:float,color:Color,texture:Texture2D=null)->void:
	var width:=rect.size.x*clampf(ratio,0,1)
	if width<=0 or rect.size.y<=0:return
	var radius:=minf(2.0,minf(rect.size.y*.5,width*.5))
	var points:=PackedVector2Array();var uv:=PackedVector2Array()
	var centers:=[Vector2(radius,radius),Vector2(width-radius,radius),Vector2(width-radius,rect.size.y-radius),Vector2(radius,rect.size.y-radius)]
	for corner in 4:
		for step in 7:
			var point:Vector2=centers[corner]+Vector2.RIGHT.rotated(PI+corner*PI*.5+step*PI/12)*radius
			points.append(rect.position+point);uv.append(point/rect.size)
	if texture!=null:draw_polygon(points,PackedColorArray([color]),uv,texture)
	else:draw_colored_polygon(points,color)
