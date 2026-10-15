class_name EnemyTelegraph
extends Node2D
## 纯表现预警：像素轮廓、方向与蓄力进度，不参与命中或伤害。
var style := "melee"
var reach := 60.0
var duration := 0.4
var age := 0.0
var direction := Vector2.RIGHT
var head_y := -40.0
var active := false

func _ready() -> void:
	z_index = 8
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = ink
	visible = false

func begin(kind: String, seconds: float, distance: float, aim: Vector2, top: float) -> void:
	style = kind
	duration = maxf(0.01, seconds)
	reach = distance
	direction = aim.normalized() if aim.length_squared()>0.01 else Vector2.RIGHT
	head_y = top
	age = 0
	active = true
	visible = true
	queue_redraw()

func stop() -> void:
	active = false
	visible = false

func _process(delta: float) -> void:
	if not active: return
	age = minf(duration, age+delta)
	queue_redraw()

func _draw() -> void:
	if not active: return
	var progress := clampf(age/duration,0,1)
	var color := Color("ffb454") if style in ["melee","charge"] else Color("d79cff")
	if style=="blast": color=Color("ff796b")
	if style=="root": color=Color("a7df83")
	# 稳定轮廓与填充条，不依靠频闪；关闭法术特效也能辨认危险。
	draw_rect(Rect2(-19,head_y-3,38,8),Color("201a2d"))
	draw_rect(Rect2(-17,head_y-1,34,4),color.darkened(0.65))
	draw_rect(Rect2(-17,head_y-1,floorf(34*progress),4),color)
	if style=="blast" or style=="root":
		var radius := reach if style=="blast" else 34.0
		for i in 64:
			var point := (Vector2.from_angle(TAU*i/64.0)*radius).round()
			draw_rect(Rect2(point,Vector2(3,3)),Color(color,0.85 if i%4==0 else 0.5))
		return
	var angle := direction.angle()
	if style in ["shot","bolt"]:
		var spreads := [-0.28,0.0,0.28] if style=="shot" else [0.0]
		for spread: float in spreads:
			for r in range(24,97,12):
				draw_rect(Rect2((Vector2.from_angle(angle+spread)*r).round(),Vector2(3,3)),Color(color,0.7))
	elif style=="charge":
		for r: int in [32,56,80,104]:
			var at := (direction*r).round()
			for j in range(-3,4):
				var pixel := at+Vector2(-abs(j)*2,j*2).rotated(angle)
				draw_rect(Rect2(pixel.round(),Vector2(3,3)),color)
	else:
		for i in 17:
			var point := (Vector2.from_angle(angle+lerpf(-0.8,0.8,i/16.0))*reach).round()
			draw_rect(Rect2(point,Vector2(3,3)),Color(color,0.75))
