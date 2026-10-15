class_name WorldClockUI
extends Control
## Original small celestial dial: a rotating star hand over colored time sectors.
var world_clock:RoomWorldClock
var _last_minute:=-1
var _label:Label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(98,104);size=custom_minimum_size
	_label=Label.new();_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_label.position=Vector2(0,78);_label.size=Vector2(98,24)
	_label.add_theme_font_size_override("font_size",14)
	_label.add_theme_constant_override("outline_size",3)
	_label.add_theme_color_override("font_outline_color",Color("19243b"))
	_label.add_theme_color_override("font_color",Color("f6edce"))
	add_child(_label)
	queue_redraw()

func _process(_delta:float) -> void:
	if MobileControls.enabled():position=MobileControls.safe_rect().position+Vector2(12,6);scale=Vector2.ONE*.9
	visible=world_clock!=null and GameState.run_active
	if world_clock==null:return
	var minute:=floori(world_clock.minutes)
	if minute!=_last_minute:
		_last_minute=minute
		_label.text=world_clock.time_label()
		tooltip_text="世界时间 · "+world_clock.time_label()
		queue_redraw()

func _sector(center:Vector2,start:float,end:float,color:Color) -> void:
	var points:=PackedVector2Array([center])
	var steps:=maxi(2,ceili((end-start)/12.0))
	for index in range(steps+1):
		var angle:=lerpf(start,end,float(index)/steps)/1440.0*TAU-PI/2
		points.append(center+Vector2.RIGHT.rotated(angle)*31)
	draw_colored_polygon(points,color)

func _draw() -> void:
	var center:=Vector2(49,39)
	draw_circle(center,37,Color("19243b"))
	if world_clock!=null:
		_sector(center,0,world_clock.dawn_start,Color("404972"))
		_sector(center,world_clock.dawn_start,world_clock.day_start,Color("9bb9b8"))
		_sector(center,world_clock.day_start,world_clock.dusk_start,Color("e3c486"))
		_sector(center,world_clock.dusk_start,world_clock.night_start,Color("c88780"))
		_sector(center,world_clock.night_start,1440,Color("404972"))
	draw_arc(center,34,0,TAU,72,Color("e7d6a6"),1.5,true)
	for hour in 24:
		var direction:=Vector2.RIGHT.rotated(hour*TAU/24-PI/2)
		draw_line(center+direction*32,center+direction*(28 if hour%6==0 else 30),Color("f4e9cf"),1,true)
	if world_clock==null:return
	var direction:=Vector2.RIGHT.rotated(world_clock.minutes/1440*TAU-PI/2)
	draw_line(center-direction*6,center+direction*26,Color("fff4dc"),2,true)
	draw_circle(center,3,Color("fff4dc"))
	var tip:=center+direction*25
	var cross:=direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([tip+direction*5,tip+cross*3,tip-direction*5,tip-cross*3]),Color("fff4dc"))
