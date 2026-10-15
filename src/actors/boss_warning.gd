class_name BossWarning
extends Node2D
## 独立危险提示；时间由 Boss 攻击时间轴驱动，不受法术强度影响。
var style := "ring"
var radius := 100.0
var duration := 0.7
var age := 0.0
var aim := Vector2.RIGHT
var spread := 0.8
var tint := Color("ffd166")
var extent := Vector2(46,56)
var caption := ""

func _ready() -> void:
	z_index=12
	var ink:=CanvasItemMaterial.new()
	ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=ink
	if not caption.is_empty():
		var text:=Label.new()
		text.text=caption
		text.position=Vector2(-110,-radius-48)
		text.size=Vector2(220,32)
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_override("font",GameFonts.get_font("title"))
		text.add_theme_font_size_override("font_size",22)
		text.add_theme_color_override("font_color",tint)
		add_child(text)

func tick(value: float) -> void:
	age=value
	queue_redraw()

func dot(at: Vector2, alpha := 0.9, width := 3.0) -> void:
	draw_rect(Rect2(at.round()-Vector2.ONE,Vector2.ONE*width),Color(tint,alpha))

func _draw() -> void:
	var progress:=clampf(age/maxf(duration,0.01),0,1)
	var top:float=-radius-15 if style in ["ring","phase"] else -48
	draw_rect(Rect2(-27,top,54,8),Color("171829"))
	draw_rect(Rect2(-25,top+2,50,4),Color(tint,0.25))
	draw_rect(Rect2(-25,top+2,floorf(50*progress),4),tint)
	match style:
		"fan":
			for edge in [-0.5,0.0,0.5]:
				var dir:=aim.rotated(spread*edge)
				for r in range(24,int(radius),10): dot(dir*r,0.95 if edge!=0 else 0.55)
			for i in 36: dot(aim.rotated(lerpf(-spread/2,spread/2,i/35.0))*radius,0.6)
		"lane":
			for x in range(-260,261,12):
				dot(Vector2(x,-12),0.55)
				dot(Vector2(x,12),0.55)
			for x in range(-216,217,72):
				for j in range(-3,4): dot(Vector2(x-abs(j)*3*aim.x,j*3))
		"portal":
			var box:=Rect2(-extent*0.5-Vector2(8,8),extent+Vector2(16,16))
			draw_rect(box,Color(tint,0.06))
			for x in range(int(box.position.x),int(box.end.x),8):
				dot(Vector2(x,box.position.y));dot(Vector2(x,box.end.y))
			for y in range(int(box.position.y),int(box.end.y),8):
				dot(Vector2(box.position.x,y));dot(Vector2(box.end.x,y))
		_:
			var count:=maxi(48,int(radius*0.65))
			for i in count: dot(Vector2.from_angle(TAU*i/count)*radius,0.95 if i%3==0 else 0.55)
			if style!="phase":
				for i in 8:
					var direction:=Vector2.from_angle(TAU*i/8)
					dot(direction*(radius-8),0.65)
