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
var fan_spread:=1.6
var shot_offsets:Array[float]=[0.0]
var room:RoomLevel
func paint_point(at:Vector2,color:Color)->void:
	if is_instance_valid(room) and not room.bounds().grow(-3).has_point(global_position+at):return
	draw_rect(Rect2(at-Vector2.ONE*2,Vector2.ONE*4),Color(.05,.02,.03,.85))
	draw_rect(Rect2(at-Vector2.ONE,Vector2.ONE*2),color)

func _ready() -> void:
	z_index =800;z_as_relative=false
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
			paint_point(point,Color(color,0.85 if i%4==0 else 0.5))
		return
	var angle := direction.angle()
	if style in ["shot","bolt"]:
		var spreads := shot_offsets if style=="shot" else [0.0]
		for spread: float in spreads:
			for r in range(24,97,12):
				paint_point((Vector2.from_angle(angle+spread)*r).round(),Color(color,.85))
	elif style=="charge":
		for r in range(24,int(reach),24):
			var at := (direction*r).round()
			for j in range(-3,4):
				var pixel := at+Vector2(-abs(j)*2,j*2).rotated(angle)
				paint_point(pixel.round(),color)
	else:
		for i in 17:
			var point := (Vector2.from_angle(angle+lerpf(-fan_spread*.5,fan_spread*.5,i/16.0))*reach).round()
			paint_point(point,Color(color,.9))
